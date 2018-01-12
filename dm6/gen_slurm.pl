#!/usr/bin/perl -w

use Getopt::Std;

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
#sbatch_* - These are the individual scripts to be invoked independently and submitted to the scheduler. These scripts contain the parameters that customize the run. 

#step3: The sbatch script itself, depending on the step chosen, invokes the perl scripts in the bin directory which perform the preperation and the actual alignment respectively

#finally: we get the result in the form of directories (for each target chromozome that contains sub directories with alignment files and chain files, .psl .lav and .chain files)
# you can revolutionize the world if you have this information, AMEN!

#***************************************************************************
#############RUNNING COMMAND##################
#./gen_bsub.pl <configuration folder path> <number of cores> <query species> <step1/step2> <target species>

my $USERNAME=$ENV{USER};
chomp($USERNAME);

my %options=();
getopts("d:c:j:s:i:t:", \%options);

#validate each option and make sure it exists
foreach $v ('d','c','j','s','i','t') {
    if(!exists($options{$v})) {
	help();
	die "missing argument -$v";
    }
}

my $conf_dir = $options{c};
my $conf_file = $conf_dir."/TARGET.conf";
my $db_dir = $options{d};


my $cores = $options{j};
my $species = $options{s};
my $step = $options{i};
my $target_species = $options{t};

my @chromes = `cat $conf_file`;
chomp(@chromes);

my $number_of_chromes = scalar(@chromes);
#SCW has a 75 job limit
if($number_of_chromes > 75)
{
	print("number of jobs exceeded limit\n");
	exit(1);
}

my $command = "";

`rm -rf ./sbatch_*`;
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

my $sbatch_file = <<"SBATCH_SCRIPT";
#!/bin/bash --login

#SBATCH -o runlog/V_${species}_${chrom_name}_${step}.out.%J     # Job output file
#SBATCH -e runlog/V_${species}_${chrom_name}_${step}.err.%J       #Job error output
#SBATCH -J V_${species}_${chrom_name}          # Job name
#SBATCH -n $cores

export bindir=$ENV{PWD}/bin

srun --ntasks-per-node=12 -n $cores time $command

SBATCH_SCRIPT

	open (RUNL, ">sbatch_${species}_${chrom_name}");
	print RUNL $sbatch_file;
	close(RUNL);


#	system("sbatch < sbatch_${species}_${chrom_name}");
}

#prints the help message if we get the args wrong
sub help {
    print("Usage: ./gen_sbatch.pl -d databasedir -c confdir -j cores -s species -i step -t target\n");
    print("\nWhere confdir = the config dir, cores is the number of cores to use, species is the name of the species, step is either step1 or step2, target is the target directory");
    print("Example: ./gen_sbatch.pl -d ../GENOMES_DB -c conf -j 8 -s dm6 -i step1 -t anoGam1\n");
}
