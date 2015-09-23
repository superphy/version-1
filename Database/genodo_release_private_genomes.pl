#!/usr/bin/env perl 

=head1 NAME

$0 - Make private genomes public that have passed release date 

=head1 SYNOPSIS

  % genodo_release_private_genomes.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.

=head1 DESCRIPTION

This script is to be run as a daily cron job. It checks for private
genomes that have been slated to be released as public on a specific
date. If the release date has passed, set genome as public.

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

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

# Connect to database
my $dbBridge = Data::Bridge->new(config => $config_filepath);
my $schema = $dbBridge->dbixSchema;


# Retrieve all 'release'-type genomes that have lapsed
my $pastdate = "<= now()";
 
my $release_rs = $schema->resultset('Upload')->search({
	release_date => \$pastdate,
	category => 'release'
});

$logger->info($release_rs->count ." private genomes found that need to be released as public.\n");

while(my $release_row = $release_rs->next) {
	$release_row->category('public');
	$release_row->update;
	$logger->info("Genome with upload_id ". $release_row->upload_id ." set as public (requested release date: ". $release_row->release_date .")");
}

# Update public meta-data
if($release_rs->count) {
	run_script("$root_directory/Data/superphy_update_public.pl", "--config $config_filepath");
	$logger->info('Updated public data');
}

$logger->info("Check complete.");

# Setup logging
sub init {
	my $dir = shift;

    # config
    my $conf = q(
        log4perl.logger                    = INFO, FileApp
        log4perl.appender.FileApp          = Log::Log4perl::Appender::File
        log4perl.appender.FileApp.filename = ).$dir.q(release_private_genomes.log
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



sub run_script {
	my @program = @_;

	my $cmd = join(' ',@program);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		$logger->logdie("Running script $cmd failed ($stderr).");
	}

}
