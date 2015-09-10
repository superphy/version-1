#!/usr/bin/env perl

=pod

=head1 NAME

t::test_genome_features.pl 

=head1 SNYNOPSIS

test_genome_features.pl --config configfile --offset 1 > feature_file

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.
 --offset         Specify offset in DB query for the block of genomes retrieved

=head1 DESCRIPTION

Retreive genome features from the PostgresDB to use in the test database.
The features are dumped as an array of hash-refs that can be fed directly into 
the DBIx::Class::ResultSet populate method

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
my ($CONFIG, $OFFSET);

GetOptions(
    'config=s'      => \$CONFIG,
    'offset=i'      => \$OFFSET,
) or ( system( 'pod2text', $0 ), exit -1 );

croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
croak "Missing argument. You must supply a offset value.\n" . system ('pod2text', $0) unless defined $OFFSET;

# Connect to DB
my $bridge = Data::Bridge->new(config => $CONFIG);
my $schema = $bridge->dbixSchema;

# Grap 10 features
my $rs = $schema->resultset('Feature')->search(
	{
		'me.type_id' => $bridge->cvmemory('contig_collection')
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   		rows => 10,
   		offset => $OFFSET*10,
   		prefetch => ['featureprops'],
   		order_by => 'me.feature_id'
	}
);

my $features = [$rs->all];

# foreach my $feature (@$features) {
# 	print $feature->{uniquename},"\n";
# }
print Dumper($features);







