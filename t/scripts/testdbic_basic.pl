#!/usr/bin/env perl

=pod

=head1 NAME

t::testdbic_basic.pl 

=head1 SNYNOPSIS

$0 --config configfile

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
	'Cvterm',
	'Tree'
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

# Add all Db and Dbxref terms
my $resultset = 'Db';
my $rs = $schema->resultset($resultset)->search(
	{
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   		prefetch => ['dbxrefs'],
	}
);

my $cvs = [$rs->all];
push @fixtures, { $resultset => $cvs };

# Add all Organisms
$resultset = 'Organism';
$rs = $schema->resultset($resultset)->search(
	{
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	}
);

$cvs = [$rs->all];
push @fixtures, { $resultset => $cvs };

# Add all Cv and Cvterms
$resultset = 'Cv';
$rs = $schema->resultset($resultset)->search(
	{
	},
	{
   		result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   		prefetch => ['cvterms'],
	}
);

$cvs = [$rs->all];
push @fixtures, { $resultset => $cvs };

# Grab A few genome features
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

	# Retrieve global tree
	my $tree_row = $schema->resultset('Tree')->find(
		{
			'me.name' => 'global'
		},
		{
	   		key => 'tree_c1'
		}
	);
	my $tree_string = $tree_row->tree_string;

	# Create 30 Upload and Permission rows
	my @upload_rows = (
		[qw/upload_id login_id category/]
	);
	my @perm_rows = (
		[qw/permission_id upload_id login_id can_modify can_share/]
	);

	# 10 Private rows
	my $p = 1;
	my $u = 1;
	for(my $i = 0; $i < 10; $i++) {
		push @upload_rows, [$u, 1, 'private']; # User 1
		push @perm_rows, [$p++, $u++, 1, 1, 1]; 
		push @upload_rows, [$u, 2, 'private']; # User 2
		push @perm_rows, [$p++, $u++, 2, 1, 1];
	}

	# 5 Public rows
	for(my $i = 0; $i < 5; $i++) {
		push @upload_rows, [$u, 1, 'public']; # User 1
		push @perm_rows, [$p++, $u++, 1, 1, 1]; 
		push @upload_rows, [$u, 2, 'public']; # User 2
		push @perm_rows, [$p++, $u++, 2, 1, 1];
	}

	push @fixtures, { Upload => \@upload_rows};

	push @fixtures, { Permission => \@perm_rows};

	# Update private features with upload_id
    my @private_features;
    $u = 1;
    while(my $feature = $rs->next) {
    	

    	$feature->{upload_id} = $u;
        foreach my $featureprop (@{$feature->{featureprops}}) {
            $featureprop->{upload_id} = $u;
        }
        $feature->{private_featureprops} = $feature->{featureprops};
        delete $feature->{featureprops};

        push @private_features, $feature;

        $u++;

        my $new = 'private_'.$feature->{feature_id};
        my $old = 'public_'.$feature->{feature_id};
        $tree_string =~ s/$old/$new/;
    }
  
    push @fixtures, { 'PrivateFeature' => \@private_features };

    push @fixtures, { 'Tree' => [
	    	['name', 'format', 'tree_string'],
	    	['global', 'perl', $tree_string]
    	]
    };

}










