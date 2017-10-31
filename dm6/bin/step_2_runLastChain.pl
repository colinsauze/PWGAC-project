#!/usr/bin/perl


#This is compiled with threading support
 
use strict;
use warnings;
use Thread;
use Getopt::Long;
#print "Starting Lastz split program\n";

my $target_dir_parent;
my $config_dir;
my $count = 0;


my $USERNAME=$ENV{USER};
chomp($USERNAME);

GetOptions
  (
          "target_dir=s" => \$target_dir_parent,
          "config_dir=s"   => \$config_dir,
  );


my @target_list = `cat $config_dir/TARGET.conf`;
my @query_list = `cat $config_dir/QUERY.conf`;
 
my @threads;


my $hosts_list=$ENV{LSB_HOSTS};
my @hosts = split(' ',$hosts_list);
chomp(@hosts);
my $core_count=scalar(@hosts);
my $NUMBER_OF_PROCESS_PER_CORE = 3;
my $chain_count = 0;

chomp(@query_list);
chomp(@target_list);

my @commands=();
foreach my $query (@query_list)
{

	foreach my $chrom (@target_list) 
	{
		chomp($chrom);
		chomp($query);



		my $target_dir=$target_dir_parent."/".$query."/".$chrom;
		
		my $NUMBER_OF_PROCESS_PER_CORE = 3;
		my @threads=();

		#sid -> we need to create these many number of threads a*b*c*d
		#a = number of queries in query.conf
		#b = number of chromosomes in target.conf
		#c = Chunk of the choromosome in <chromosome>.list
		#d = chunk of the query in query.list

		#the foreach loop below will open the query.list file
		my @QUERY_LIST=`cat $target_dir/query.list`;
		my @CHROM_LIST=`cat $target_dir/target.list`;
		foreach my $query_chunk (@QUERY_LIST)
		{
			foreach my $chrom_chunk(@CHROM_LIST)
			{

				$count++;	
				chomp($chrom_chunk);
				chomp($query_chunk);
        			my $lavCmd = lavCommand($chrom, $query,$query_chunk,$chrom_chunk,$target_dir,$count);
				push(@commands,$lavCmd);
		
			}
		}
	}
}
		my $number_of_commands=scalar(@commands);
		my $command_count=0;
		while($command_count < $number_of_commands)
		{
        		@threads=();
			my $thread_counter = 0;
       			for (my $nproc=0;$nproc<$NUMBER_OF_PROCESS_PER_CORE;$nproc++)
       			{
              			foreach my $host (@hosts)
				{
                                # sid -> this calls the subroutine and relinquishes the control
                               		if($command_count < $number_of_commands)
                             		{


						if($thread_counter >= 1024)
						{
							#print "Launch Halted as we need to complete 1024\n";
							last;
						}
						$thread_counter++;
                                       		my $thread_command = $commands[$command_count];
                                     		$command_count++;
                                       		my $t = threads->new(\&submitThread,$thread_command,$count,$host);
                                       		push(@threads,$t);
                              		}
                              		else
                               		{
                                       		last;
                               		}
                		}
        		}


			foreach (@threads)
			{
        			my $num = $_->join;
				my $tid = $_->tid();
        			#print "LAV2PSL done with $tid\n";
			}

		}

my @chain_threads=();
$count = 0;
my @chain_commands=();
foreach my $query (@query_list)
{
        foreach my $chrom (@target_list)
        {
                chomp($chrom);
                chomp($query);
	                my $target_dir=$target_dir_parent."/".$query."/".$chrom;
			if(!-d "$target_dir/chain")
        		{
               		 	mkdir "$target_dir/chain";
        		}
			$count++;
			my $cmdChain="perl $target_dir\/chainJobs_${chrom}_${query}.csh";
			push(@chain_commands,$cmdChain);
	}
}		
my $number_of_chain_commands=scalar(@chain_commands);
my $chain_command_count=0;

while($chain_command_count < $number_of_chain_commands)
{
        @chain_threads=();
        for (my $nproc=0;$nproc<$NUMBER_OF_PROCESS_PER_CORE;$nproc++)
        {
                foreach my $host (@hosts)
                {
			if($chain_command_count < $number_of_chain_commands)
                                {
                                        my $thread_command = $chain_commands[$chain_command_count];
                                        $chain_command_count++;

					my $chain_thread=threads->new(\&submitChainThread,$thread_command,$count,$host);
        	                	push(@chain_threads,$chain_thread);
				 }
				else
                               	{
                                        last;
                                }
                 }
        }
	
	foreach (@chain_threads)
	{
        	my $num = $_->join;
       		my $tid = $_->tid();

       		#print "chaining done with $tid\n";
	}
}




sub submitChainThread()
{
	my ($cmd,$number,$host) = @_;
        #print "picked this host for chaining $host\n";
	#print "-Step 2- Executin chain commands $cmd\n";
        system("blaunch $host $cmd");
}
sub lavCommand 
{


        #my $t=threads->new(&submitThread,$chrom, $query,$query_chunk,$chrom_chunk,$target_dir,$count);
	my ($target_name,$query_name,$query_chunk,$target_chunk,$target_dir,$number)=@_;
	my $host_number=$number%$core_count;
        #print "picked this host $hosts[$host_number] at the index $host_number $core_count $number\n";
	chmod 0777,"$target_dir\/runLastz_${target_name}_${query_name}";
	
	my $index_t=index($target_chunk,':');
        my $length=length($target_chunk);
        my $target_split_var=substr($target_chunk,$index_t+1,$length-$index_t);
       
        chdir $target_dir;

	my $index_q=index($query_chunk,':');
	$length=length($query_chunk);
        my $query_split_var=substr($query_chunk,$index_q+1,$length-$index_q);

	my $LAV_FILE=$target_split_var.".".$query_split_var;
	my $cmd = "$target_dir\/runLastz_${target_name}_${query_name} $target_name $query_name $query_chunk $target_chunk $LAV_FILE";
	return $cmd;
}	
sub submitThread
{
	my ($cmd,$number,$host) = @_;
	#my $host_number=$number%$core_count;
	print "-PAIRWISE STEP 2- picked this host $host\n";
	print "-Step 2- Executing $cmd\n";
        #system("blaunch $hosts[$host_number] $cmd");
	system("blaunch $host $cmd");
	#chmod 0777,"$target_dir\/chainJobs_${target_name}_${query_name}.csh";
}
