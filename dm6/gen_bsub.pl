#!/usr/bin/perl -w


#*****************************************************************
#Parallel LastZ pipeline - Synopsys
#Authors: Sidharth Kashyap &  Vasilis Lenis - University of Aberystwyth
#Date: 09/04/2015



# the lastZ pipeline involves many tools (and those are available in the bin directory)
# the problem being solved through this code is as below

# the Target - is a genome that needs to be aligned with another genome called _Query_
# we have the list of targets and the list of queries in the conf directory 
# refer to Target.conf and Query.conf in the conf directory for reference 

#The TARGET.conf contains - the chromosomes and the QUERY.conf contains the species genome 
#the actual data for this is to be presented by the user, in our case the sample is put into GENOMES_DB directory

#The alignment process itself is both computationally and spatially intensive
#for this reason we will have to split the comparison process and invoke the tools at the least granular level


#for this reason we use the HPC services to get the requisite number of machines and perform the alignment in parallel


#the algorithm is as below

#step 1: Invoke this script with the configuration directory, the number of cores to be allocated for each granular execution, species and the step (1 or 2)
#example: 

#step 2: This script creates a series of directories and files
#conf_* - contains the configuration required for each chromosome
#bsub_* - These are the individual scripts to be invoked independently and submitted to the scheduler. These scripts contain the parameters that customize the run. 

#step3: The bsub script itself, depending on the step chosen, invokes the perl scripts in the bin directory which perform the preperation and the actual alignment respectively

#finally: we get the result in the form of directories (for each target chromozome that contains sub directories with alignment files and chain files, .psl .lav and .chain files)
# you can revolutionize the world if you have this information, AMEN!

#***************************************************************************
#############RUNNING COMMAND##################
#./gen_bsub.pl <configuration folder path> <number of cores> <query species> <step1/step2> <target species>

my $USERNAME=$ENV{USER};
chomp($USERNAME);


my $conf_dir = $ARGV[0];
my $conf_file = $conf_dir."/TARGET.conf";
my $db_dir = "/home/${USERNAME}/PARALLEL_LASTZ/GENOMES_DB";


my $cores = $ARGV[1];
my $species = $ARGV[2];
my $step = $ARGV[3];
my $target_species = $ARGV[4];

my @chromes = `cat $conf_file`;
chomp(@chromes);

my $number_of_chromes = scalar(@chromes);
if($number_of_chromes > 100)
{
	print("number of jobs exceeded limit\n");
	exit(1);
}

my $command = "";

`rm -rf ./bsub_*`;
`rm -rf ./conf_*`;


foreach my $chrom_name(@chromes)
{

	next if($chrom_name=~/^\s*$/);
	my $command = "perl \$bindir/step_2_runLastChain_process_template.pl -target_dir $ENV{PWD} -config_dir conf_${chrom_name}";
	if($step eq "step1")
	{
		$command="perl \$bindir/step_1_runLastChain.pl -conf_dir conf_${chrom_name} -db_dir $db_dir -species $species -target_species $target_species";
	}

	chomp($chrom_name);
	`cp -rf $conf_dir conf_${chrom_name}`;
	`echo $chrom_name > conf_${chrom_name}/TARGET.conf`;

my $bsub_file = <<"BSUB_SCRIPT";
#!/bin/bash --login

#BSUB -o runlog/V_${species}_${chrom_name}_${step}.out.%J     # Job output file
#BSUB -e runlog/V_${species}_${chrom_name}_${step}.err.%J       #Job error output
#BSUB -J V_${species}_${chrom_name}          # Job name
#BSUB -n $cores
#BSUB -q q_cf_htc_large
#BSUB -x



export bindir=$ENV{PWD}/bin

time $command

wait
BSUB_SCRIPT

	open (RUNL, ">bsub_${species}_${chrom_name}");
	print RUNL $bsub_file;
	close(RUNL);


	system("bsub < bsub_${species}_${chrom_name}");
}

