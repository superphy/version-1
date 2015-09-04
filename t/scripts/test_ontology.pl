#!/usr/bin/env perl

=pod

=head1 NAME

t::test_ontology.pl 

=head1 SNYNOPSIS

test_ontology.pl --config configfile > feature_file


=head1 COMMAND-LINE OPTIONS

 --config             Specify a .conf containing DB connection parameters.


=head1 DESCRIPTION

Retreive ontology from the PostgresDB to use in the test database.
The features are dumped as an array of hash-refs that can be fed directly into 
the DBIx::Class::ResultSet populate method.

The results are printed to STDOUT

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use Getopt::Long;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Data::Bridge;
use Carp;
use Data::Dumper;

# Commandline options
my ($CONFIG);

GetOptions(
    'config=s'         => \$CONFIG,
) or ( system( 'pod2text', $0 ), exit -1 );

croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;


# Connect to DB
my $bridge = Data::Bridge->new(config => $CONFIG);
my $schema = $bridge->dbixSchema;

# Grab All Cv and Cvterms
my $rs = $schema->resultset('Cv')->search(
	{
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   		prefetch => ['cvterms'],
	}
);

my $cvs = [$rs->all];

# Print to file
print Dumper($cvs);










