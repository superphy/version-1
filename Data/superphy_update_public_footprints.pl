#!/usr/bin/env perl

=head1 NAME

$0 - Creates or updates the contig_footprint table

=head1 SYNOPSIS

  % superphy_update_public_footprints.pl --config filename

=head1 COMMAND-LINE OPTIONS

 --config         Must specify a .conf containing DB connection parameters.
 

=head1 DESCRIPTION

Performs MD5 digests on the contigs of all public genomes, saving checksum string in contig_footprint
table.

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Modules::Footprint;
use Carp qw/croak carp/;
use Log::Log4perl qw/:easy/;
use Config::Simple;
use DBI;

# Initialize logger
Log::Log4perl->easy_init($INFO);


# Get cmd-line options
my ($CONFIG);
GetOptions(
    'config=s'      => \$CONFIG,
) or ( system( 'pod2text', $0 ), exit -1 );


my ($dbname, $dbport, $dbhost, $dbuser, $dbpass);
croak "Missing argument: config." unless $CONFIG;
if(my $conf = new Config::Simple($CONFIG)) {
	$dbname    = $conf->param('db.name');
	$dbuser    = $conf->param('db.user');
	$dbpass    = $conf->param('db.pass');
	$dbhost    = $conf->param('db.host');
	$dbport    = $conf->param('db.port');
} else {
	croak Config::Simple->error();
}

my $dbh = DBI->connect(
	"dbi:Pg:dbname=$dbname;port=$dbport;host=$dbhost",
	$dbuser,
	$dbpass,
	{AutoCommit => 0,
	 TraceLevel => 0}
) or croak "Unable to connect to database";

# Create footprint module
my $fp = Modules::Footprint->new(dbh => $dbh);

# Do footprint loading
$fp->loadPublicFootprints();


$dbh->disconnect();	
