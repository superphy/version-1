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

$0 - Adds urlprefix entries to the db table for common DBs

=head1 SYNOPSIS

  % genodo_add_db_urls.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.

=head1 DESCRIPTION

This script will insert DB entries for genbank, BioProject and taxon
if they don't exist and will update the urlprefix with the proper value

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI);

GetOptions(
    'config=s'      => \$CONFIG,
) or ( system( 'pod2text', $0 ), exit -1 );

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

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS) or croak "Could not connect to database.";

my %urlprefixes = qw|
	genbank     http://www.ncbi.nlm.nih.gov/nuccore/
	BioProject  http://www.ncbi.nlm.nih.gov/bioproject/
	taxon       http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=
|;


foreach my $db (keys %urlprefixes) {
	my $db_row = $schema->resultset('Db')->find_or_create( { name => $db },{ key => 'db_c1' });
	croak "Error: $db not found in Db table and could not create it." unless $db_row;
	
	$db_row->urlprefix($urlprefixes{$db});
	$db_row->update;
	
	print "Added urlprefix for database $db.\n";
}

exit(0);