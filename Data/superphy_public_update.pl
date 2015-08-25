#!/usr/bin/env perl

=head1 NAME

  $0 - Updates all the pre-computed public data

=head1 SYNOPSIS

  % superphy_public_update.pl --config filename

=head1 COMMAND-LINE OPTIONS

 --config         Must specify a .conf containing DB connection parameters.
 

=head1 DESCRIPTION

Several JSON objects containing public data are pre-computed and stored for quick retrieval.
These include:
  - the 'perlpub' genome tree
  - The 'public_genomes' JSON object
  - The Shiny superphy-df_meta.RData file
  - The 'stdgrp-org' JSON group hiearchy object

These objects need to be updated after changes to the genome properties. This script calls
the necessary methods to update all public objects.

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2015

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Getopt::Long;
use Config::Tiny;
use Log::Log4perl qw/get_logger/;
use File::Basename qw< dirname >;
use IO::CaptureOutput qw(capture_exec);

# Globals
my ($config_filepath, $log_dir);
my $test = 0;
my $perl_interpreter = $^X;
my $root_directory = dirname (__FILE__) . "/../";


# Get options
GetOptions(
    'config=s'  => \$config_filepath,
    'test'      => \$test
) or ( system( 'pod2text', $0 ), exit -1 );


die "Error: missing argument. You must supply a configuration filepath: --config file.\n" . system ('pod2text', $0) unless $config_filepath;
if(my $conf = Config::Tiny->read($config_filepath)) {
	$log_dir = $conf->{dir}->{log};
} else {
	die Config::Tiny->error();
}

# Setup logger
my $logger = init($log_dir);
$logger->info("Initiating update of public data...");

# Setup logging
sub init {
	my $dir = shift;

    # config
    my $conf = q(
        log4perl.logger                    = INFO, FileApp
        log4perl.appender.FileApp          = Log::Log4perl::Appender::File
        log4perl.appender.FileApp.filename = ).$dir.q(send_group_data.log
        log4perl.appender.FileApp.layout   = PatternLayout
        log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n
    );

    # Initialize logging behaviour
    Log::Log4perl->init(\$conf);

    # Obtain a logger instance
    my $logger = get_logger();

    $logger->info("TEST MODE") if $test;
   
   return $logger;
}


# Update meta-data
run_script("$root_directory/Database/load_meta_data.pl", "--config $config_filepath");

# Update groups
run_script("$root_directory/Data/update_standard_strain_groups.pl", "--config $config_filepath");

# Update tree
run_script("$root_directory/Phylogeny/update_public_tree.pl", "--config $config_filepath");

# Update Shiny
run_script("$root_directory/Data/send_group_data.pl", "--config $config_filepath", "--meta");


sub run_script {
	my @program = @_;

	my $cmd = join(' ',@program);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		$logger->logdie("Running script $cmd failed ($stderr).");
	}

}