#!/usr/bin/env perl

=pod

=head1 NAME

t::grouper.t

=head1 SNYNOPSIS



=head1 DESCRIPTION

Tests for Modules::Collections

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Test::More;
use Test::DBIx::Class;
use Data::Bridge;
use Data::Grouper;
use Modules::FormDataGenerator;

# Install DB data
fixtures_ok 'basic'
	=> 'Install basic fixtures from configuration files';

 # Initialize DB interface objects via Bridge module
ok my $dbBridge = Data::Bridge->new(schema => Schema), 
	'Create Data::Bridge object';

ok my $data = Modules::FormDataGenerator->new(dbixSchema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory), 
	'Create Module::FormDataGenerator object';

# Grouping object
ok my $grouper = Data::Grouper->new(schema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory), 
	'Create Data::Grouper object';

# Group genomes into standard groups
fixtures_ok sub {
	my $schema = shift;

	# Retrieve some user ID, just need a placeholder
	my $user = $schema->resultset('Login')->find(2);
	die "Error: no users loaded" unless $user;

    # Perform update / creation of standard groups
    $grouper->updateStandardGroups($data, $user->username);

    return 1;
  
}, 'Install standard group fixtures';

# Get the assignment hash
ok my $assignments = $grouper->group_assignments, "Retrieve group assignment hash";
my @meta_keys = keys %$assignments;

# Iterate through genome features
# Check assignments with hash vs DB

is_resultset my $genome_rs = Feature->search(
	{
		'me.type_id' => $dbBridge->cvmemory('contig_collection')
	},
	{
		prefetch => {'featureprops' => 'type'}
	}
);

while(my $genome = $genome_rs->next) {
	my $feature_id = $genome->feature_id;
	ok check_group_assignments($feature_id, $genome->featureprops), "Correct group assignments for genome $feature_id";
}




done_testing();

########

=head2 check_group_assignments

Compare group assignment for each type of featureprop using
assignment hash and the entry in the DB

=cut
sub check_group_assignments {
	my $feature_id = shift;
	my @featureprops = @_;

	# Save featureprop values for each meta-data type
	my %meta_data_values;
	foreach my $fp_row (@featureprops) {
		if($meta_data_values{$fp_row->type->name}) {
			push @{$meta_data_values{$fp_row->type->name}}, $fp_row->value;
		}
		else {
			$meta_data_values{$fp_row->type->name} = [$fp_row->value]
		}
	}

	# Get predicted groups based on assignment hash routine
	my %putative_groups;
	foreach my $k (@meta_keys) {
		my $unassigned = "$k\_na";
		my $other = "$k\_other";
		my $value;
		if($meta_data_values{$k}) {
			my @values = @{$meta_data_values{$k}};
			
			foreach my $v (@values) {
				if($assignments->{$k}->{$v}) {
					$value = $v;
				} else {
					# No matching group, assign to 'other' group
					$value = $other;
				}

				my $group_id = $assignments->{$k}->{$value};
				die "Error: no $k group for meta data value $value." unless $group_id;

				$putative_groups{$group_id} = $value;
			}
		}
		else {
			# No featureprop, assign to 'unassigned' group
			$value = $unassigned;

			my $group_id = $assignments->{$k}->{$value};
			die "Error: no $k group for meta data value $value." unless $group_id;

			$putative_groups{$group_id} = $value;
		}
	}

	# Get actual groups already in DB
	my %assigned_groups;
	my $group_rs = ResultSet('FeatureGroup', 
		{
			feature_id => $feature_id,
			'-bool' => 'genome_group.standard'
		},
		{
			prefetch => 'genome_group'
		}
	);

	while(my $group_row = $group_rs->next) {
		$assigned_groups{$group_row->genome_group->genome_group_id} = $group_row->genome_group->standard_value;
	}

	# Compare groups
	my $pass = 1;
	foreach my $g (keys %putative_groups) {
		unless($assigned_groups{$g}) {
			diag "$g representing value: $putative_groups{$g} predicted group not found.";
			$pass = 0;
		}
	}
	
	foreach my $g (keys %assigned_groups) {
		unless($putative_groups{$g}) {
			diag "$g representing value: $assigned_groups{$g} assigned group not found.";
			$pass = 0;
		}
	}

	return $pass;
}

