#!/usr/bin/perl

=head1
 Mitochondrial annotation script. Homologus annotation pipeline with tBLASTn, SOLAR and Genewise based on mitochondrial reference proteins on NCBI RefSeq. 
 Please cite: Xin Zhou et al, GigaScience, Ultra-deep sequencing enables high-fidelity recovery of biodiversity for bulk arthropod samples without PCR amplification. 
 
 Contact: Yiyuan Li, BGI, email: liyiyuan@genomics.org.cn.


=head1 Version
 New features:

 Version: 1.32
 1. Terminate the program if there is no hit
 2. It's dicoverd that e-value threshold (1e-5) for TBLASTN is better to avoid false positives

 Version: 1.31
 1. Compatible for nuclear gene annotation
 2. Add default database function

 Version: 1.3.
 1. Add options
 2. Add steps to bypass the tBLASTn step

 Version: 1.21.
 1. Add Reference position to cds names 

 Version: 1.2.
 1. Optimized ATP8 annotation, with reduced e-value threshold (1e-2) for TBLASTN;

 Version: 1.1. 
 1. Fix bugs for 1KITE data.
 2. The output results are identical to assembly file name



=head1 Usage:
Warm reminder: this program, character "|" is not allowed in protein database.
 perl MT_annotation_BGI.pl -i [assembly results] -d [MT database] -o [output direction]

 -s  1, for start from BLAST; 2, for bypass BLAST. Default 1
 -p  1, for mitochondrial gene annotation; 2, for nulcear gene annotation.  Default 1
 -d  By default most recent mitochondrial database (MitoProtein_RefSeq_130627_Arthropoda_604.fasta).
 -cpu thread number for blastall. default: 1.
 -g genetic code. default: 5

=cut


use strict;
use FindBin qw($Bin $Script);
use File::Basename qw(basename dirname); 
use Getopt::Long;


#die "Usage: perl $0 [assembly results] [MT database] [output direction]\n Warm reminder: this program, \"|\" protein database is not allowed.\n
#Please cite: Xin Zhou et al, GigaScience, Ultra-deep sequencing enables high-fidelity recovery of biodiversity for bulk arthropod samples without PCR amplification.

#If you have any problem with regards to the script, please contact: Yiyuan Li, BGI, email: liyiyuan\@genomics.org.cn.\n" unless (@ARGV == 3);


##get options from command line into variables and set default values
my ($Cpu,$Run,$Outdir);
my ($Blast_eval,$Align_rate,$Extend_len,$Step,$Filter, $Prog);
my ($Cpu,$Help,$Db_file,$Qr_file,$Outdir);
my $Queue;
my $Tophit;
my $genetic_code = 5;

GetOptions(
#        "lines:i"=>\$Line,
        "cpu:i"=>\$Cpu,
#        "run:s"=>\$Run,
#        "Filter:i"=>\$Filter,
#        "blast_eval:s"=>\$Blast_eval,
#        "align_rate:f"=>\$Align_rate,
#        "extend_len:i"=>\$Extend_len,
        "s:s"=>\$Step,
        "p:s"=>\$Prog,
#       "queue:s"=>\$Queue,
#       "tophit:i"=>\$Tophit,
        "i=s"=>\$Db_file,
	"d=s"=>\$Qr_file,
	"o=s"=>\$Outdir,
    'g=i'=>\$genetic_code,
        "help!"=>\$Help
);



$Align_rate = 0.25;
$Extend_len = 2000;
$Filter = 1;
$Step ||= '1';
$Prog ||= '1';
$Qr_file ||= "$Bin/MT_database/MitoProtein_RefSeq_140729_774.aas";
$Cpu ||= 1;
$genetic_code ||= 5;

#my $Db_file = shift;
#my $Qr_file = shift;
#my $Outdir = shift;

die `pod2text $0` if ((not defined $Db_file) || (not defined $Qr_file) || (not defined $Outdir) || $Help);


my %Pep_len;
read_fasta($Qr_file,\%Pep_len);

my %Chr_len;
read_fasta($Db_file,\%Chr_len);

$Outdir =~ s/\/$//;
mkdir($Outdir) unless(-d $Outdir);

#my $Db_file_basename = basename($Qr_file);
my $Db_file_basename = basename($Db_file);

my $genewise_dir = "$Outdir/$Db_file_basename.genewise";

my $tblastn_shell_file = "$Outdir/$Db_file_basename.tblastn.shell";
my $solar_shell_file = "$Outdir/$Db_file_basename.solar.shell";
my $genewise_shell_file = "$Outdir/$Db_file_basename.genewise.shell";

my @subfiles;

###
# Run blast or not?
##
if ($Step == 1){
##format the database for tblastn
# print STDERR  "\n\n$Bin/blast/formatdb -i $Db_file -p F\n";
print STDERR "\n\nmakeblastdb -in $Db_file -dbtype nucl\n";

# `$Bin/blast/formatdb -i $Db_file -p F` unless (-f $Db_file.".nhr");
`makeblastdb -in $Db_file -dbtype nucl` unless (-f $Db_file.".nhr");


## creat the shell file and run tblastn
open OUT,">$tblastn_shell_file" || die "fail $tblastn_shell_file";
print STDERR "run the tblastn shell file\n";

if($Prog == 1){
	# print OUT "$Bin/blast/blastall -a $Cpu -p tblastn -e 1e-5 -m 8 -F F -D 5 -d $Db_file -i $Qr_file -o $Outdir/$Db_file_basename.blast; \n";
    print OUT "tblastn -num_threads $Cpu -evalue 1e-5 -outfmt 6 -seg no -db_gencode $genetic_code -db $Db_file -query $Qr_file -out $Outdir/$Db_file_basename.blast; \n";

	#`$Bin/blast/blastall  -a $Cpu -p tblastn -e 1e-5 -m 8 -F F -D 5 -d $Db_file -i $Qr_file -o $Outdir/$Db_file_basename.blast`;
    `tblastn -num_threads $Cpu -evalue 1e-5 -outfmt 6 -seg no -db_gencode $genetic_code -db $Db_file -query $Qr_file -out $Outdir/$Db_file_basename.blast`;

}else{
	#print OUT "$Bin/blast/blastall  -a $Cpu  -p tblastn -e 1e-5 -m 8 -F F -d $Db_file -i $Qr_file -o $Outdir/$Db_file_basename.blast; \n";
    print OUT "tblastn -num_threads $Cpu -evalue 1e-5 -outfmt 6 -seg no -db $Db_file -query $Qr_file -out $Outdir/$Db_file_basename.blast; \n";
	#`$Bin/blast/blastall  -a $Cpu -p tblastn -e 1e-5 -m 8 -F F -d $Db_file -i $Qr_file -o $Outdir/$Db_file_basename.blast`;
    `tblastn -num_threads $Cpu -evalue 1e-5 -outfmt 6 -seg no  -db $Db_file -query $Qr_file -out $Outdir/$Db_file_basename.blast`;
}


close OUT;

filter_blast("$Outdir/$Db_file_basename.blast");
}


print STDERR "Run solar to conjoin HSPs and filter bad HSPs and redundance.\n";
open (OUT1,">$solar_shell_file") || die "fail $solar_shell_file";	## by minjiumeng
print OUT1 "perl $Bin/solar/solar.pl $Outdir/$Db_file_basename.blast.filter > $Outdir/$Db_file_basename.blast.solar";
`perl $Bin/solar/solar.pl $Outdir/$Db_file_basename.blast.filter > $Outdir/$Db_file_basename.blast.solar`;

sleep (10);

filter_solar("$Outdir/$Db_file_basename.blast.solar");
solar_to_table("$Outdir/$Db_file_basename.blast.solar.filter","$Outdir/$Db_file_basename.blast.solar.filter.table");
`perl $Bin/genomic_cluster.pl $Outdir/$Db_file_basename.blast.solar.filter.table > $Outdir/$Db_file_basename.blast.solar.filter.table.nonredundance`;
`perl $Bin/pick.pl $Outdir/$Db_file_basename.blast.solar.filter.table.nonredundance $Outdir/$Db_file_basename.blast.solar.filter > $Outdir/$Db_file_basename.blast.solar.filter.nr`;


print STDERR "preparing genewise input directories and files\n";
if($Prog == 1){
	&prepare_genewise("$Outdir/$Db_file_basename.blast.solar.filter.nr");
}else{
	&prepare_genewise_nuclear("$Outdir/$Db_file_basename.blast.solar.filter.nr");
}

print STDERR "run the genewise shell file\n";
print  STDERR "running genewise\n";
`sh $genewise_shell_file`;


print STDERR "convert result to gff3 format\n";

# Check whether the file exists
system "for i in $Outdir/$Db_file_basename.genewise/* ;do for j in \$i/*.genewise ;do cat \$j;done ;done >$Outdir/$Db_file_basename.solar.genewise;";

if($?){
	print "Sorry, the annotation finished with no result!\n";

}else{
`perl $Bin/fa_len.pl $Qr_file > $Outdir/$Db_file_basename.length`;
`perl $Bin/gw2gff.pl $Outdir/$Db_file_basename.solar.genewise $Outdir/$Db_file_basename.length >$Outdir/$Db_file_basename.solar.genewise.gff`;

`perl $Bin/getGene.pl $Outdir/$Db_file_basename.solar.genewise.gff $Db_file >$Outdir/$Db_file_basename.solar.genewise.gff.cds`;

if($Prog == 1){
	`perl $Bin/add_protein_position.pl $Outdir/$Db_file_basename.blast.solar.filter.nr $Outdir/$Db_file_basename.solar.genewise.gff.cds`;
	`perl $Bin/cds2aa_InverMito.pl $Outdir/$Db_file_basename.solar.genewise.gff.cds.position.cds  >$Outdir/$Db_file_basename.solar.genewise.gff.pep`;
}else{
	`perl $Bin/cds2aa_nuclear.pl $Outdir/$Db_file_basename.solar.genewise.gff.cds >$Outdir/$Db_file_basename.solar.genewise.gff.pep`;
}

print "Annotation finished\n";
}
##########################################################
################### Sub Routines ###################
#########################################################

#usage: Read_fasta($file,\%hash);
#############################################
sub Read_fasta{
        my $file=shift;
        my $hash_p=shift;

        my $total_num;
        open(IN, $file) || die ("can not open $file\n");
        $/=">"; <IN>; $/="\n";
        while (<IN>) {
#print;
                chomp;
                my $head = $_;
#print "$head\n";
                my $name = $1 if($head =~ /^(\S+)/);
                
                $/=">";
                my $seq = <IN>;
#print "!!!$seq\n";
                chomp $seq;
                $seq=~s/\s//g;
                $/="\n";
                
                if (exists $hash_p->{$name}) {
                        warn "name $name is not uniq";
                }

                $hash_p->{$name}{head} =  $head;
                $hash_p->{$name}{len} = length($seq);
                $hash_p->{$name}{seq} = $seq;

                $total_num++;
        }
        close(IN);
        
        return $total_num;
}


##OsB000025-PA    476     1       476     -       Chr07frag1M     1000000 154122  157515  8       924     1,149;150,184;182,205;205,23
sub solar_to_table{
	my $file = shift;
	
	my $output;
	open IN, $file || die "fail";
	while (<IN>) {
		chomp;
		my @t = split /\t/;
		my $len = $t[3]-$t[2]+1;
		$output .= "$t[0]\t$t[5]\t$t[4]\t$t[7]\t$t[8]\t$len\t$t[10]\n";
	}
	close IN;

	open OUT, ">$file.table" || die "fail";
	print OUT $output;
	close OUT;
}

##filter blast result, remove that  
##################################################
sub filter_blast {
	my $infile = shift;
	open IN, "$infile" || die "fail $infile";
	open OUT, ">$infile.filter" || die "fail $infile.filter";
	while (<IN>){
		chomp;
		my @c=split(/\t/);
		if ($c[2]>30){print OUT "$_\n"};

	}
	close IN;
	close OUT;
}

##filter solar result, get parameters from globle Param
##################################################
sub filter_solar {
	my $infile = shift;
	my %solardata;
	my $output;
	
	open IN, "$infile" || die "fail $infile";
	while (<IN>) {
		chomp;
		s/^\s+//;
		my @t = split /\s+/;
		my $query = $t[0];
		my $score = $t[10];
		next if($score < 25);
		my $query_size = $t[1];
		my $align_size;
		while ($t[11]=~/(\d+),(\d+);/g) {
			$align_size += abs($2 - $1) + 1;
		}
		next if($align_size / $query_size < 0.25);
	
		push @{$solardata{$query}},[$score,$_]; ## hits that better than cutoff
		
	}
	
	open OUT, ">$infile.filter" || die "fail $infile.filter";
	foreach my $query (sort keys %solardata) {
		my $pp = $solardata{$query};
		@$pp = sort {$b->[0] <=> $a->[0]} @$pp;
		for (my $i=0; $i<@$pp; $i++) {
			last if(defined $Tophit && $i>=$Tophit);
			my $query_Dup = "$query-D".($i+1);
			$pp->[$i][1] =~ s/$query/$query_Dup/ if ($i>0);
			print OUT $pp->[$i][1],"\n";
		}
	}
	close OUT;
	
}



##read sequences in fasta format and calculate length of these sequences.
sub read_fasta{
	my ($file,$p)=@_;
	open IN,$file or die "Fail $file:$!";
	$/=">";<IN>;$/="\n";
	while(<IN>){
		my ($id,$seq);
		#if ( /\S\s+\S/ ) {
		#	die "No descriptions allowed after the access number in header line of fasta file:$file!\n";
		#}
	#	if ( /\|/ ){
	#		die "No '|' allowed in the access number of fasta file:$file!\n";
	#	}
		
		if (/^(\S+)/){
			$id=$1;
		}else{
			die "No access number found in header line of fasta file:$file!\n";
		}
		if ( $id=~/\|/ ) {
			die "No '|' allowed in the access number of fasta file:$file!\n";
		}
		$/=">";
		$seq=<IN>;
		chomp $seq;
		$seq=~s/\s//g;
		$p->{$id}=length($seq);
		$/="\n";
	}
	close IN;
}


sub parse_config{
	my $conifg_file = shift;
	my $config_p = shift;
	
	my $error_status = 0;
	open IN,$conifg_file || die "fail open: $conifg_file";
	while (<IN>) {
		if (/(\S+)\s*=\s*(\S+)/) {
			my ($software_name,$software_address) = ($1,$2);
			$config_p->{$software_name} = $software_address;
			if (! -e $software_address){
				warn "Non-exist:  $software_name  $software_address\n"; 
				$error_status = 1;
			}
		}
	}
	close IN;
	die "\nExit due to error of software configuration\n" if($error_status);
}


##prepare data for genewise and make the qsub shell
####################################################


sub prepare_genewise{
	my $solar_file = shift;
	my @corr;

	open IN, "$solar_file" || die "fail $solar_file";
	while (<IN>) {
		s/^\s+//;
		my @t = split /\s+/;
		my $query = $t[0];
		my $strand = $t[4];
		my ($query_start,$query_end) = ($t[2] < $t[3]) ? ($t[2] , $t[3]) : ($t[3] , $t[2]);
		my $subject = $t[5];
#print "$subject\n";
		my ($subject_start,$subject_end) = ($t[7] < $t[8]) ? ($t[7] , $t[8]) : ($t[8] , $t[7]);
		push @corr, [$query,$subject,$query_start,$query_end,$subject_start,$subject_end,"","",$strand]; ## "query_seq" "subject_fragment"	
	}
	close IN;
	my %fasta;
	&Read_fasta($Qr_file,\%fasta);
	foreach my $p (@corr) {
		my $query_id = $p->[0];
		$query_id =~ s/-D\d+$//;
		if (exists $fasta{$query_id}) {
#print "!!!$fasta{$query_id}{seq}\n";
			$p->[6] = $fasta{$query_id}{seq};
		}
	}
	undef %fasta;
	my %fasta;
	&Read_fasta($Db_file,\%fasta);
	foreach my $p (@corr) {
#print "###$fasta{$p->[1]}{len}\n";
		if (exists $fasta{$p->[1]}) {
			my $seq = $fasta{$p->[1]}{seq};
			my $len = $fasta{$p->[1]}{len};
			$p->[4] -= 2000;
			$p->[4] = 1 if($p->[4] < 1);
			$p->[5] += 2000;
			$p->[5] = $len if($p->[5] > $len);
#
#print "!!!$seq\n";
#
			$p->[7] = substr($seq,$p->[4] - 1, $p->[5] - $p->[4] + 1); 
		}
	}
	undef %fasta;
	mkdir "$genewise_dir" unless (-d "$genewise_dir");
	my $subdir = "000";
	my $loop = 0;
	my $cmd;
	my $opt_genewise = "-genesf -gff -sum";
	foreach my $p (@corr) {
		if($loop % 200 == 0){
			$subdir++;
			mkdir("$genewise_dir/$subdir");
		}
		
		my $qr_file = "$genewise_dir/$subdir/$p->[0].fa";
		my $db_file = "$genewise_dir/$subdir/$p->[0]_$p->[1]_$p->[4]_$p->[5].fa";
		my $rs_file = "$genewise_dir/$subdir/$p->[0]_$p->[1]_$p->[4]_$p->[5].genewise";
		
		open OUT, ">$qr_file" || die "fail creat $qr_file";
		print OUT ">$p->[0]\n$p->[6]\n";
		close OUT;
		open OUT, ">$db_file" || die "fail creat $db_file";
		print OUT ">$p->[1]_$p->[4]_$p->[5]\n$p->[7]\n";
#
#print ">$p->[1]_$p->[4]_$p->[5]\n$p->[7]\n";
#
		close OUT;

		my $choose_strand = ($p->[8] eq '+') ? "-tfor" : "-trev";
####		$cmd .= "$Bin/genewise -codon /ifs1/ST_ENV/USER/liyiyuan/COI/Annotation/test/codon_InverMito.table $choose_strand $opt_genewise $qr_file $db_file > $rs_file 2> /dev/null;\n";
		$cmd .= "$Bin/genewise -codon $Bin/codon_InverMito.table $choose_strand $opt_genewise $qr_file $db_file > $rs_file\n";
		$loop++;
	}
	undef @corr;

	open OUT, ">$genewise_shell_file" || die "fail creat $genewise_shell_file";
	print OUT $cmd;
	close OUT;

}


sub prepare_genewise_nuclear{
        my $solar_file = shift;
        my @corr;

        open IN, "$solar_file" || die "fail $solar_file";
        while (<IN>) {
                s/^\s+//;
                my @t = split /\s+/;
                my $query = $t[0];
                my $strand = $t[4];
                my ($query_start,$query_end) = ($t[2] < $t[3]) ? ($t[2] , $t[3]) : ($t[3] , $t[2]);
                my $subject = $t[5];
#print "$subject\n";
                my ($subject_start,$subject_end) = ($t[7] < $t[8]) ? ($t[7] , $t[8]) : ($t[8] , $t[7]);
                push @corr, [$query,$subject,$query_start,$query_end,$subject_start,$subject_end,"","",$strand]; ## "query_seq" "subject_fragment"
        }
        close IN;
        my %fasta;
        &Read_fasta($Qr_file,\%fasta);
        foreach my $p (@corr) {
                my $query_id = $p->[0];
                $query_id =~ s/-D\d+$//;
                if (exists $fasta{$query_id}) {
#print "!!!$fasta{$query_id}{seq}\n";
                        $p->[6] = $fasta{$query_id}{seq};
                }
        }
        undef %fasta;
        my %fasta;
        &Read_fasta($Db_file,\%fasta);
        foreach my $p (@corr) {
#print "###$fasta{$p->[1]}{len}\n";
                if (exists $fasta{$p->[1]}) {
                        my $seq = $fasta{$p->[1]}{seq};
                        my $len = $fasta{$p->[1]}{len};
                        $p->[4] -= 2000;
                        $p->[4] = 1 if($p->[4] < 1);
                        $p->[5] += 2000;
                        $p->[5] = $len if($p->[5] > $len);
#
#print "!!!$seq\n";
#
                        $p->[7] = substr($seq,$p->[4] - 1, $p->[5] - $p->[4] + 1); 
                }
        }
        undef %fasta;
        mkdir "$genewise_dir" unless (-d "$genewise_dir");
        my $subdir = "000";
        my $loop = 0;
        my $cmd;
        my $opt_genewise = "-genesf -gff -sum";
        foreach my $p (@corr) {
                if($loop % 200 == 0){
                        $subdir++;
                        mkdir("$genewise_dir/$subdir");
                }

                my $qr_file = "$genewise_dir/$subdir/$p->[0].fa";
                my $db_file = "$genewise_dir/$subdir/$p->[0]_$p->[1]_$p->[4]_$p->[5].fa";
                my $rs_file = "$genewise_dir/$subdir/$p->[0]_$p->[1]_$p->[4]_$p->[5].genewise";

                open OUT, ">$qr_file" || die "fail creat $qr_file";
                print OUT ">$p->[0]\n$p->[6]\n";
                close OUT;
                open OUT, ">$db_file" || die "fail creat $db_file";
                print OUT ">$p->[1]_$p->[4]_$p->[5]\n$p->[7]\n";
#
#print ">$p->[1]_$p->[4]_$p->[5]\n$p->[7]\n";
#
                close OUT;

                my $choose_strand = ($p->[8] eq '+') ? "-tfor" : "-trev";
                $cmd .= "$Bin/genewise $choose_strand $opt_genewise $qr_file $db_file > $rs_file\n";
                $loop++;
        }
        undef @corr;

        open OUT, ">$genewise_shell_file" || die "fail creat $genewise_shell_file";
        print OUT $cmd;
        close OUT;

}

##conjoin the overlapped fragments, and caculate the redundant size
##usage: conjoin_fragment(\@pos);
##		 my ($all_size,$pure_size,$redunt_size) = conjoin_fragment(\@pos);
##Alert: changing the pointer's value can cause serious confusion.
sub Conjoin_fragment{
	my $pos_p = shift; ##point to the two dimension input array
	my $distance = shift || 0;
	my $new_p = [];         ##point to the two demension result array
	
	my ($all_size, $pure_size, $redunt_size) = (0,0,0); 
	
	return (0,0,0) unless(@$pos_p);

	foreach my $p (@$pos_p) {
			($p->[0],$p->[1]) = ($p->[0] <= $p->[1]) ? ($p->[0],$p->[1]) : ($p->[1],$p->[0]);
			$all_size += abs($p->[0] - $p->[1]) + 1;
	}
	
	@$pos_p = sort {$a->[0] <=>$b->[0]} @$pos_p;
	push @$new_p, (shift @$pos_p);
	
	foreach my $p (@$pos_p) {
			if ( ($p->[0] - $new_p->[-1][1]) <= $distance ) { # conjoin two neigbor fragements when their distance lower than 10bp
					if ($new_p->[-1][1] < $p->[1]) {
							$new_p->[-1][1] = $p->[1]; 
					}
					
			}else{  ## not conjoin
					push @$new_p, $p;
			}
	}
	@$pos_p = @$new_p;

	foreach my $p (@$pos_p) {
			$pure_size += abs($p->[0] - $p->[1]) + 1;
	}
	
	$redunt_size = $all_size - $pure_size;
	return ($pure_size);
}

