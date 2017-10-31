#!/usr/bin/perl
#This is compiled with threading support
use strict;
use Thread;
use warnings;
use File::Path;
print "Semding the final jobs to the cluster\n";
my $dir = $ARGV[0];
if (not defined $dir)
{
  die "Need a working directory\n";
}
open (TARGET,"$dir/TARGET.conf");
open (QUERY, "$dir/QUERY.conf");
my @target_list = <TARGET>;
my @query_list = <QUERY>;
foreach my $query (@query_list)
{
    chomp $query;

        foreach my $chrom (@target_list)
        {
                chomp $chrom;
		my $sub_specs = "bsub -q q_ab_mpc_work -e $dir/error.e -o $dir/out.o -J step2 ";


		`$sub_specs \"perl /home/sid.kashyap/VASILIS-LASTZ/testing-4/step_2_runLastChain.pl  -target_dir /home/sid.kashyap/VASILIS-LASTZ/testing-4 -config_dir /home/sid.kashyap/VASILIS-LASTZ/testing-4 $chrom $query\"`;
	}
}
#bsub -q q_ab_mpc_work -o /home/sid.kashyap/VASILIS-LASTZ/HowTo/lastzOuts-28/`basename $i .fa`-`basename $j .fa`.o -e /home/sid.kashyap/VASILIS-LASTZ/HowTo/lastzOuts-28/`basename $i .fa`-`basename $j .fa`.e -J `basename $i .fa`-`basename $j .fa`

