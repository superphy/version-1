#!/usr/bin/env perl

=pod

=head1 NAME

t::testdbic_basic.pl 

=head1 SNYNOPSIS

test_ontology.pl --config configfile

=head1 COMMAND-LINE OPTIONS

 --config             Specify a .conf containing DB connection parameters.

=head1 DESCRIPTION

Build a current t/etc/schema.pl config file for use in Test::DBIx::Class testing.

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
my $dbic_file = "$FindBin::Bin/../etc/schema.pl";

my %dbic;

# General initialization options

$dbic{'schema_class'} = 'Database::Chado::Schema';
# The method to load data into the DB, based on DBIx::Class::Schema::populate
$dbic{'fixture_class'} = '::Populate';
# These resultsets are imported into the namespace for easy access
# Others can be accessed using the Resultset method
$dbic{'resultsets'} = [
	'Feature',
	'Featureprop',
	'PrivateFeatureprop',
	'PrivateFeature',
	'Login',
	'Cv',
	'Cvterm'
],

# Essential Database fixture data for testing      
# The inputs must be suitable for DBIx::Class::Schema::populate
my $fixture = 'basic';
my @fixtures;

# Connect to DB
my $bridge = Data::Bridge->new(config => $CONFIG);
my $schema = $bridge->dbixSchema;

# Add test users
push @fixtures, {'Login' => [
	[qw/login_id username password firstname lastname email/],
    [1, 'testbot', Modules::User::_encode_password('password'), 'testbot', '3000', 'donotemailme@ever.com'],
    [2, 'eviltestbot', Modules::User::_encode_password('password'), 'eviltestbot', '4000', 'donotemailme@ever.com']
]};

# Add all Cv and Cvterms
my $resultset = 'Cv';
my $rs = $schema->resultset($resultset)->search(
	{
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   		prefetch => ['cvterms'],
	}
);

my $cvs = [$rs->all];
push @fixtures, { $resultset => $cvs };

# # Grab A few genome features
$resultset = 'Feature';
$rs = $schema->resultset($resultset)->search(
	{
		'me.type_id' => $bridge->cvmemory('contig_collection')
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   		rows => 30,
   		prefetch => ['featureprops'],
   		order_by => 'me.feature_id'
	}
);

my $feats = [$rs->all];
push @fixtures, { $resultset => $feats };

# Convert a few public genome features to convert into private ones
$resultset = 'Feature';
$rs = $schema->resultset($resultset)->search(
	{
		'me.type_id' => $bridge->cvmemory('contig_collection')
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   		rows => 30,
   		offset => 30,
   		prefetch => ['featureprops'],
   		order_by => 'me.feature_id'
	}
);

create_private_genome_features($rs);

$dbic{'fixture_sets'}{$fixture} = \@fixtures;

# Overwrite config file with new data
$Data::Dumper::Terse = 1;
my $dbic_string = Dumper(\%dbic);

path($dbic_file)->spew($dbic_string) or die "Error: config file write failed ($!)\n";



########
## SUBS
########


=head2 create_private_genome_features

Add some private genome features and associated featureprops

=cut
sub create_private_genome_features {
    my $rs = shift; # DBICx schema object

    unless($rs->count() == 30) {
		croak "Error: expecting 30 features.";
	}

	push @fixtures, { Permission => [
		[qw/permission_id upload_id login_id can_modify can_share/],
		[1, 1, 1, 1, 1],
		[2, 2, 1, 1, 1],
		[3, 3, 1, 1, 1]
	]};

	push @fixtures, { Upload => [
		[qw/upload_id login_id category/],
		[1, 1, 'public'],
		[2, 1, 'private'],
		[3, 2, 'private'],
	]};

    my @private_features;

    my $c = 0;
    my $u = 0;
    while(my $feature = $rs->next) {
    	$u = int($c / 10)+1;

    	$feature->{upload_id} = $u;
        foreach my $featureprop (@{$feature->{featureprops}}) {
            $featureprop->{upload_id} = $u;
        }
        $feature->{private_featureprops} = $feature->{featureprops};
        delete $feature->{featureprops};

        push @private_features, $feature;

        $c++;
    }
  
    push @fixtures, { 'PrivateFeature' => \@private_features };

}










