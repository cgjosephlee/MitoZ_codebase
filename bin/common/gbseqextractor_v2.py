#!/usr/bin/python3
"""
Copyright (c) 2017-2018 Guanliang Meng <mengguanliang@foxmail.com>.

This file is part of MitoZ.

MitoZ is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MitoZ is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with MitoZ.  If not, see <http://www.gnu.org/licenses/>.

"""

import argparse
from Bio import SeqIO
import re
import os
import sys

def get_para():
	description = """
	extract any CDS or rNRA or tRNA DNA sequences of genes from Genbank file.

	Note: the position on ID line is 1-leftmost!

	Seqid will be the value of '/gene=' or '/product=', if they both were not
	present, the gene will not be output!

	v2: support for 'misc_feature'
	"""

	parser = argparse.ArgumentParser(description=description)

	parser.add_argument("-f", required=True, metavar="<STR>", help="Genbank file")


	parser.add_argument("-prefix", metavar="<STR>", required=True,
		help="prefix of output file.")

	parser.add_argument("-seqPrefix", metavar="<STR>", default="", 
		help="prefix of each seq id. default: None")

	parser.add_argument("-types", nargs="+", default="CDS", 
		choices=["CDS", "rRNA", "tRNA", "misc_feature", "wholeseq"], 
		help="what kind of genes you want to extract? wholeseq for whole fasta seq.[%(default)s]")

	parser.add_argument("-gi", default=False, action='store_true', 
		help="use gi number as sequence ID instead of accession number when " + \
			"gi number is present. (default: accession number)")

	parser.add_argument("-p", default=False, action='store_true', 
		help="output the position information on the ID line. 1-leftmost, same as in the Genbank file. [%(default)s]")

	parser.add_argument("-t", default=False, action='store_true', 
		help="output the taxonomy lineage on ID line [%(default)s]")

	parser.add_argument("-s", default=False, action='store_true', 
		help="output the species name on the ID line [%(default)s]")

	parser.add_argument("-l", default=False, action='store_true', 
		help="output the seq length on the ID line [%(default)s]")

	parser.add_argument("-rv", default=False, action='store_true', 
		help="reverse and complement the sequences if " + \
			"the gene is on minus strand [%(default)s]")

	parser.add_argument("-F", default=False, action='store_true', 
		help="only output full length genes [%(default)s]")


	if len(sys.argv) == 1:
		parser.print_help()
		sys.exit()
	else:
		args = parser.parse_args()

	return args


def to_1_leftmost(pos=None):
    m = re.search(r'(\d+)', str(pos))
    pos_old = int(m.group(1))
    pos_new = pos_old + 1

    pos_old = str(pos_old)
    pos_new = str(pos_new)

    return re.sub(pos_old, pos_new, str(pos))



def main():
	args = get_para()

	fh_cds = fh_prot = fh_rrna = fh_trrna = fh_misc = fh_wholeseq = ""
	if "CDS" in args.types:
		fh_cds = open(args.prefix+".cds", 'w')
		fh_prot = open(args.prefix+".prot", 'w')

	if "rRNA" in args.types:
		fh_rrna = open(args.prefix+".rrna", 'w')

	if "tRNA" in args.types:
		fh_trna = open(args.prefix+".trna", 'w')

	if "misc_feature" in args.types:
		fh_misc = open(args.prefix+".misc_feature", 'w')

	if "wholeseq" in args.types:
		fh_wholeseq = open(args.prefix + ".fasta", 'w')

	for rec in SeqIO.parse(args.f, 'gb'):
		ass_num = rec.id
		#print(rec.id)
		#print(rec.name)
		#print(rec.description)
		#print(rec.letter_annotations)
		#print(rec.annotations)

		# wholeseq
		if fh_wholeseq:
			if args.seqPrefix:
				wholeseq_idline = ">" + args.seqPrefix
			else:
				wholeseq_idline = ">"

			if args.gi:
				try:
					wholeseq_idline += rec.annotations['gi']
				except KeyError:
					wholeseq_idline += rec.id
			else:
				wholeseq_idline += rec.id

			if args.l:
				wholeseq_idline += " len="+str(len(rec))

			if args.s:
				species = str(rec.annotations['organism'])
				wholeseq_idline += " " + species

			if args.t:
				taxonomy = str(rec.annotations['taxonomy'])
				taxonomy = taxonomy.replace("'", "")
				wholeseq_idline += " "+ taxonomy

			wholeseq_idline += " topology={0}".format(rec.annotations['topology'])

			print(wholeseq_idline, file=fh_wholeseq)
			print(rec.seq, file=fh_wholeseq)

		# CDS, tRNA, rRNA, mis_feature
		for fea in rec.features:
			#print(fea.type)
			#print(fea.location) have .start and .end attributes
			#for qual in fea.qualifiers:
			if fea.type in args.types:
				if args.F:
					if '>' in str(fea.location)  or '<' in str(fea.location):
						continue


				start = begin = fea.location.start
				end = stop = fea.location.end
				strand = Strand= fea.location.strand  # is a number
				#print(rec[start:end].seq)
				#print(strand)
				#print(start)
					# fea.qualifiers['gene'] is a list!!
					#print(fea.qualifiers['gene'][0])
				gene = ""
				product = ""

				if 'gene' in fea.qualifiers:
					gene = fea.qualifiers['gene'][0]
				elif 'product' in fea.qualifiers:
					product = fea.qualifiers['product'][0]
					gene = product
				elif fea.type == 'misc_feature':
					if 'note' in fea.qualifiers and 'control region' in fea.qualifiers['note'][0]:
						gene = product = fea.qualifiers['note'][0]
						gene_seq = fea.location.extract(rec).seq
					else:
						continue
				else:
					print(ass_num, "Warning: NO gene or product tag! this gene is not output!\n")
					continue

				if args.seqPrefix:
					idline = ">" + args.seqPrefix
				else:
					idline = ">"

				if args.gi:
					try:
						idline += "%s;%s" % (rec.annotations['gi'], gene)
					except KeyError:
						idline += "%s;%s" % (rec.id, gene)
				else:
					idline += "%s;%s" % (rec.id, gene)

				if args.l:
					idline += ";len=" + str(len(rec[start:end]))

				if args.p:
					begin = to_1_leftmost(begin)
					# stop = to_1_leftmost(stop)

					if Strand == 1:
						Strand = '+'
					elif Strand == -1:
						Strand = '-'

					# idline += ";" + str(fea.location)
					idline += ';' + '[{0}:{1}]({2})'.format(begin, stop, Strand)


				if args.s:
					species = str(rec.annotations['organism'])
					idline += ";" + species

				if args.t:
					taxonomy = str(rec.annotations['taxonomy'])
					taxonomy = taxonomy.replace("'", "")
					idline += ";"+ taxonomy

				if fea.type != 'misc_feature':
					gene_seq = rec[start:end].seq

				if args.rv:
					if strand == -1:
						gene_seq = gene_seq.reverse_complement()

				prot_seq = ''
				if 'translation' in fea.qualifiers:
					prot_seq = fea.qualifiers['translation'][0]

				if fea.type == "CDS":
					print(idline, file=fh_cds)
					print(gene_seq, file=fh_cds)
					print(idline, file=fh_prot)
					print(prot_seq, file=fh_prot)
				elif fea.type == "rRNA":
					print(idline, file=fh_rrna)
					print(gene_seq, file=fh_rrna)
				elif fea.type == "tRNA":
					print(idline, file=fh_trna)
					print(gene_seq, file=fh_trna)
				elif fea.type == "misc_feature":
					print(idline, file=fh_misc)
					print(gene_seq, file=fh_misc)
			#print(rec[start:end].seq) Biopython will automatically inorge '>' and '<'

	if fh_cds:
		fh_cds.close()
		fh_prot.close()

	if fh_rrna:
		fh_rrna.close()

	if fh_trrna:
		fh_trrna.close()

	if fh_wholeseq:
		fh_wholeseq.close()

	if fh_misc:
		fh_misc.close()

if __name__ == '__main__':
    main()

