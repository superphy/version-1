#!/usr/bin/env perl

=pod

=head1 NAME

t::testdbic_miner.pl 

=head1 SNYNOPSIS

$0 --config configfile

=head1 COMMAND-LINE OPTIONS

 --config             Specify a .conf containing DB connection parameters.

=head1 DESCRIPTION

Build a current t/etc/miner.pl config file for use in Test::DBIx::Class testing.

Retreives current data from the PostgresDB to use in the test database.
The features are dumped as an array of hash-refs that can be fed directly into 
the DBIx::Class::ResultSet populate method. See Test::DBIx::Class for more info
on use.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use Getopt::Long;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../";
use Modules::User;
use Data::Bridge;
use Carp;
use Data::Dumper;
use Path::Tiny qw( path );

# Commandline options
my ($CONFIG);

GetOptions(
    'config=s'         => \$CONFIG
) or ( system( 'pod2text', $0 ), exit -1 );

croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;

# DBIx::Class file
my $dbic_file = "$FindBin::Bin/../etc/miner.pl";

my %dbic;

# General initialization options

$dbic{'schema_class'} = 'Database::Chado::Schema';
# The method to load data into the DB, based on DBIx::Class::Schema::populate
$dbic{'fixture_class'} = '::Populate';
# These resultsets are imported into the namespace for easy access
# Others can be accessed using the Resultset method
$dbic{'resultsets'} = [
	'Host',
	'Source',
	'Syndrome',
	'HostCategory'
],

# Essential Database fixture data for testing      
# The inputs must be suitable for DBIx::Class::Schema::populate
my $fixture = 'miner';
my @fixtures;

# Connect to DB
my $bridge = Data::Bridge->new(config => $CONFIG);
my $schema = $bridge->dbixSchema;


# Add all Host, Source & Syndrome entries
my @tables = qw/Host Source Syndrome HostCategory/;
foreach my $resultset (@tables) {
	my $rs = $schema->resultset($resultset)->search(
		{
		},
		{
	   		result_class => 'DBIx::Class::ResultClass::HashRefInflator'
		}
	);

	my $cvs = [$rs->all];
	push @fixtures, { $resultset => $cvs };
}

$dbic{'fixture_sets'}{$fixture} = \@fixtures;


# Overwrite config file with new data
$Data::Dumper::Terse = 1;
my $dbic_string = Dumper(\%dbic);

path($dbic_file)->spew($dbic_string) or die "Error: config file write failed ($!)\n";







