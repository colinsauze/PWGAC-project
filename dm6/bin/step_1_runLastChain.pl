#!/usr/bin/perl
#This is compiled with threading support
use strict;
use Thread;
use warnings;
use File::Path;
use Getopt::Long;
use Cwd;
use Cwd 'realpath';

my $USERNAME=$ENV{USER};
chomp($USERNAME);
my $db_dir= "";
my $conf_dir = "";
my $species = "";
my $target_species = "";
GetOptions
(
        "conf_dir=s" => \$conf_dir,
    "db_dir=s" => \$db_dir,
    "species=s" => \$species,
	"target_species=s" => \$target_species,
	
)

or die("-PAIRWISE STEP 1- Error in command line arguments\n");

#/home/software.builder/PARALLEL_LASTZ/insect/bin
my $bin = $ENV{basedir}."/bin";

my $dir = $ENV{basedir};
#."/".${species};

print "main dir $dir\n";
print "Starting Lastz managing program\n";
print "STEP 1 - species - $species\n";

my $hosts_list=$ENV{SLURM_JOB_NODELIST};

print "host list=".$hosts_list;
#my $hosts_list=$ENV{LSB_HOSTS};

my @hosts = split(' ',$hosts_list);
chomp(@hosts);

my $core_counter=scalar(@hosts);
print "-Step 1-\nHOSTS @hosts\n";
if (not defined $dir)
{
  die "-PAIRWISE STEP 1-Need a working directory\n";
}

#print $dir;
open (TARGET,"$conf_dir/TARGET.conf");
open (QUERY, "$conf_dir/QUERY.conf");
my @target_list = <TARGET>;
my @query_list = <QUERY>;
my $NUMBER_OF_PROCESS_PER_CORE = 3;
my $count=0;
my @threads=();
my @commands=();
foreach my $query (@query_list)
{  
    chomp $query;
	if (!-d $query) 
	{
		mkpath ("$dir/$query");
     	}
  
        foreach my $chrom (@target_list)
        {
		$count++;
		chomp $chrom;
        	if (!-d $chrom)
		{    
	 		mkpath ("$dir/$query/$chrom");
          	}
		my $cmd = "$bin/runLastzChain.sh $dir $dir/$query/$chrom $chrom $query $db_dir $target_species $species > $dir/log/runLastzChain_${query}_${chrom}.log 2>&1";
		push(@commands,$cmd);
	}
}
my $number_of_commands=scalar(@commands);
my $command_count=0;

while($command_count < $number_of_commands)
{
	@threads=();
	#for (my $nproc=0;$nproc<$NUMBER_OF_PROCESS_PER_CORE;$nproc++)
	{
		#foreach my $host (@hosts)
		{
				# sid -> this calls the subroutine and relinquishes the control
				if($command_count < $number_of_commands)
				{
					my $thread_command = $commands[$command_count];
					print "command_count = ".$command_count."\n";
					$command_count++;
					my $t = threads->new(\&submitThread,$thread_command,$count);
               				push(@threads,$t);
				}
				else
				{
					last;
				}
		}
	}		
	foreach  (@threads)
	{
        		my $num = $_->join;
        		my $tid = $_->tid();
        		print "-PAIRWISE STEP 1- Thread number $tid completed\n";
	}
my $existingdir = $dir;
open my $fileHandle, ">>", "$existingdir/filetocreate.txt" or die "Can't open '$existingdir/filetocreate.txt'\n";
print $fileHandle "GREAT JOB! :):):)\n";
close $fileHandle;
}		
sub submitThread
{
	my ($cmd,$number) = @_;
	print "-PAIRWISE STEP 1- Executing $cmd\n";
        print("system(\"srun ".$cmd."\");\n");
	system("srun $cmd");
}
