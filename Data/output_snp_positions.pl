#!/usr/bin/env perl

=head1 NAME

$0 - Computes nucleotide position of SNP in each genome

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config      INI style config file containing DB connection parameters
 --job         Job ID in job_result table

=head1 DESCRIPTION

Computes SNP positions for all accessible genomes for a given user


=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Data::Snppy;
use JSON::MaybeXS qw(encode_json decode_json);


$|=1;
my $script = $0;

my $step = 0;
my @status = qw/Running Complete/;
my $error_status = 'Error occurred';

$SIG{__DIE__} = $SIG{INT} = 'fatal';

# Connect to database
my $data = Data::Snppy->new();

my $JOBID = -1;
GetOptions(
    'job=s' => \$JOBID
);


# Retrieve job data
unless($JOBID || $JOBID == -1) {
	fatal("Missing argument: job")
}

my $job = $data->dbixSchema->resultset('JobResult')->find($JOBID);
unless($job) {
	fatal("No record matching ID $JOBID in job_result table.")
}

my $username = undef;
$username = $job->username;

my $job_param_json = $job->user_config;
my $job_params = decode_json($job_param_json);
my $snp_id = $job_params->{snp_core_id};
unless($snp_id) {
	fatal("User config is missing 'snp_core_id' parameter.")
}

$job->job_result_status($status[$step++]);
$job->update();

my $results = $data->get($snp_id, $username);

$job->job_result_status($status[$step++]);
my $result_json = encode_json $results;
$job->result($result_json);

$job->update();

exit(0);

###########
## SUBS
###########


sub fatal {
	my $msg = shift;
	
	#$job->update(job_result_status => $error_status) if($job);
	
	my $err = "Error in $script (job ID $JOBID)";
	$err .= ": $msg" if $msg;
	print STDERR "$err\n";
	
	exit(1);
}