#!/usr/bin/env perl 
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;


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

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $LOGFILE);

GetOptions(
    'config=s'      => \$CONFIG,
    'log=s'         => \$LOGFILE
) or ( system( 'pod2text', $0 ), exit -1 );

# Open logfile
croak "Missing argument. You must supply a log filename.\n" . system ('pod2text', $0) unless $LOGFILE;
open(LOG, ">>$LOGFILE") or die "Error: unable to append to log file $LOGFILE ($!).\n";

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
if(my $db_conf = new Config::Simple($CONFIG)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
} else {
	die Config::Simple->error();
}

my $dbsource = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dbsource . ';port=' . $DBPORT if $DBPORT;

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS) or croak "Error: could not connect to database.";

# Retrieve all 'release'-type genomes that have lapsed
my $pastdate = "<= now()";
 
my $release_rs = $schema->resultset('Upload')->search({
	release_date => \$pastdate,
	category => 'release'
});

print LOG "Start of record for job initiated " . localtime . "\n";
print LOG "\t". $release_rs->count ." private genomes found that need to be released as public.\n";

while(my $release_row = $release_rs->next) {
	$release_row->category('public');
	$release_row->update;
	print LOG "\tGenome with upload_id ". $release_row->upload_id ." released as public (requested release date: ". $release_row->release_date .").\n";
}

print LOG "End job record.\n\n";
close LOG;
