#!/usr/bin/python
"""
rRNA_ft.py

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

import sys

usage = """
To prepare the feature table for l-rRNA and s-rRNA genes from cmsearch result file (tblout).

Only output the cmsearch result with significant evalue (inc column is '!').

bug fixed: if no result in inputfile, then the outfile is empty.

bug fixed 20180131: if there are multiple gene results (same s-rRNA or same l-rRNA) in tbl-file, the second and later ones must have length >100bp and the position with the first one is larger thant 5000bp.

bug fixed 20180131_2:

python3 %s <tbl-file> <outfile>

""" % sys.argv[0]

if len(sys.argv) != 3:
	print(usage)
	sys.exit(0)

first_gene_on_seq_name = ''
first_gene_from = 0

fh_in = open(sys.argv[1], 'r')
fh_out = open(sys.argv[2], 'w')

fh_in.readline()
fh_in.readline()
firstline = 1
gene_num = 0
for i in fh_in:
	i = i.rstrip()
	if i == '#':
		break
	if firstline and i.startswith("#"):
		firstline = 0
		if 'l-rRNA' in sys.argv[1]:
			print("Can not find l-rRNA!")
			sys.exit(0)
		else:
			print("Can not find s-rRNA!")
			sys.exit(0)

	line = i.split()
	seq_name = line[0]
	try:
		seq_from, seq_to, seq_dire = line[7:10]
	except ValueError:
		sys.exit(i)
	significant_result = line[16]

	if significant_result != "!":
		break

	if abs(int(seq_from)-int(seq_to)) <= 100:
		continue

	gene_num += 1
	if gene_num > 1:
		if first_gene_on_seq_name == seq_name:
			if abs(first_gene_from-int(seq_from)) < 5000:
				break
		else:
			first_gene_on_seq_name = seq_name
			
	elif gene_num == 1:
		first_gene_from = int(seq_from)
		first_gene_on_seq_name = seq_name
		firstline = 0

	print(">Feature %s" % seq_name, file=fh_out)

	print(seq_from, seq_to, "gene", sep="\t", file=fh_out)

	if 'l-rRNA' in sys.argv[1]:
		print("\t\t\tgene\tl-rRNA", file=fh_out)
	else:
		print("\t\t\tgene\ts-rRNA", file=fh_out)

	print(seq_from, seq_to, "rRNA", sep="\t", file=fh_out)

	if 'l-rRNA' in sys.argv[1]:
		print("\t\t\tproduct\t16S ribosomal RNA", file=fh_out)
	else:
		print("\t\t\tproduct\t12S ribosomal RNA", file=fh_out)

fh_in.close()
fh_out.close()
