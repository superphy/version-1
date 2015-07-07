#!/usr/bin/env perl

=pod

=head1 NAME

t::shiny.t

=head1 SNYNOPSIS

perl t/shiny.t

=head1 DESCRIPTION

Tests for Modules::Shiny

Must be run parent directory (directory above t/) so that Test::DBIx::Class can find
the etc directory.

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
use Test::Exception;
use Data::Bridge;
use Data::Grouper;
use Modules::FormDataGenerator;
use t::lib::App;
use t::lib::ShinyT qw(is_shiny_response);
use Config::Simple;
use JSON::MaybeXS;
use File::Temp qw/tempdir/;
use Test::DBIx::Class {}, 'GenomeGroup', 'FeatureGroup', 'PrivateFeatureGroup', 'Permission';

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


# Create test CGIApp and work environment
my $cgiapp;
lives_ok { $cgiapp = t::lib::App::relaunch(Schema, $ARGV[0]) } 'Test::WWW::Mechanize::CGIApp initialized';
BAIL_OUT('CGIApp initialization failed') unless $cgiapp;


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


# Perform anonymous GET request of meta-data
shiny_anon_get_request();

# Login
my $login_id = 1; 
my $username = Login->find(1)->username;
t::lib::App::login_ok($cgiapp, $username, 'password');


# Create two custom groups named group1 & group2
fixtures_ok \&custom_groups, 'Install custom group fixtures';


# RUN REST OF TESTS
my $get_response = shiny_get_request();


my ($post_response, $group_id) = shiny_post_request($get_response);


shiny_put_request($post_response, $group_id);


done_testing();

########
## SUBS
########

=head2 shiny_anon_get_request


=cut
sub shiny_anon_get_request {

	# Run GET request
	my $page = '/api/group';
	$cgiapp->get_ok($page);
	my $json = t::lib::App::json_ok($cgiapp);

	diag explain $json;

	is_shiny_response($json, 'Valid API Response');

	my @ordered_genomes = @{$json->{genomes}};

	my $pass = 1;
	$pass = 0 if $json->{groups} && %{$json->{groups}};
	$pass = 0 if $json->{group_ids} && %{$json->{group_ids}};
	ok $pass, 'Validate empty groups from GET /api/group for anonymous user';

	subtest 'Validate meta-data from GET /api/group for anonymous user' => sub {
		check_meta($json, \@ordered_genomes);
	};
}



=head2 shiny_get_request


=cut
sub shiny_get_request {

	# Run GET request
	my $page = '/api/group';
	$cgiapp->get_ok($page);
	my $json = t::lib::App::json_ok($cgiapp);

	is_shiny_response($json, 'Valid API Response');

	my @ordered_genomes = @{$json->{genomes}};

	subtest 'Validate groups from GET /api/group' => sub {
		check_groups($json, \@ordered_genomes);
	};

	subtest 'Validate meta-data from GET /api/group' => sub {
		check_meta($json, \@ordered_genomes);
	};

	return $json;
}

=head2 shiny_post_request


=cut
sub shiny_post_request {
	my $get_response_json = shift; # Response from GET request

	# Get the list of potential genomes from the GET response
	my @ordered_genomes = @{$get_response_json->{genomes}};
	my %indices;
	my $i = 0;
	map { $indices{$_} = $i; $i++ } @ordered_genomes;
	
	# Get some genome IDs for testset group
	my $public_rs = Feature->search(
		{
			'type.name' => 'contig_collection'
		},
		{
			join => ['type'],
			rows => 2,
			columns => ['feature_id'],
			offset => 10,
		}
	);

	my $private_rs = PrivateFeature->search(
		{
			'type.name' => 'contig_collection',
			'upload.login_id' => $login_id
		},
		{
			join => ['type','upload'],
			rows => 1,
			columns => ['feature_id'],
			offset => 10
		}
	);

	# Issue POST request
	my @test_group = (undef) x scalar(@ordered_genomes);
	my %test_group_set;
	my $group_name = 'new';
	my $post_request = {
		user => $get_response_json->{user},
		CGISESSID => $get_response_json->{CGISESSID},
		genomes => \@ordered_genomes
	};
	
	while(my $row = $public_rs->next) {
		my $n = 'public_'.$row->feature_id;
		$test_group[$indices{$n}] = 1;
		$test_group_set{$n} = 1;
	}

	while(my $row = $private_rs->next) {
		my $n = 'private_'.$row->feature_id;
		$test_group[$indices{$n}] = 1;
		$test_group_set{$n} = 1;
	}

	$post_request->{group}->{$group_name} = \@test_group;
	my $post_json = encode_json($post_request);

	my $rm = '/api/group';
	$cgiapp->post($rm,
		'Content' => $post_json,
		'Content_Type' => 'application/json'
	);
	ok($cgiapp->success, 'Shiny group creation POST');

	my $json = t::lib::App::json_ok($cgiapp);

	is_shiny_response($json, 'Valid API Response');

	# Check group in response
	ok my $group_presence = $json->{groups}->{$group_name} => 'New group added to API Response';
	ok my $group_id = $json->{group_ids}->{$group_name} => 'New group ID located in API Response';
	is_deeply($group_presence, \@test_group, 'New group matches group in API Response');

	# Check group in DB
	ok my $public_list = FeatureGroup->search(
			{ genome_group_id => $group_id },
			{ columns => [qw/feature_id/] }
		)
		=> 'New group public genomes retrieved from DB';

	ok my $private_list = PrivateFeatureGroup->search(
			{ genome_group_id => $group_id },
			{ columns => [qw/feature_id/] }
		)
		=> 'New group private genomes retrieved from DB';

	my %db_group_set;
	while(my $row = $public_list->next) {
		my $genome = 'public_' . $row->feature_id;
		
		$db_group_set{$genome} = 1;
	}

	while(my $row = $private_list->next) {
		my $genome = 'private_' . $row->feature_id;
		
		$db_group_set{$genome} = 1;
	}

	is_deeply(\%test_group_set, \%db_group_set, 'New group matches group in DB');


	ok my $group_rs = GenomeGroup->search(
			{
				genome_group_id => $group_id
			},
			{
				columns => [qw/name/]
			}
		)
		=> 'New group properties retrieved from DB';

	is($group_rs->first->name, $group_name, 'New group properties matches group properties in DB');

	return($json, $group_id);
}

=head2 shiny_put_request


=cut
sub shiny_put_request {
	my $post_response_json = shift; # Response from GET request
	my $group_id = shift;

	# Get the list of potential genomes from the GET response
	my @ordered_genomes = @{$post_response_json->{genomes}};
	my %indices;
	my $i = 0;
	map { $indices{$_} = $i; $i++ } @ordered_genomes;
	
	# Get some genome IDs for modified group
	my $private_rs = PrivateFeature->search(
		{
			'type.name' => 'contig_collection',
			'upload.login_id' => $login_id
		},
		{
			join => ['type','upload'],
			rows => 1,
			columns => ['feature_id'],
			offset => 10
		}
	);

	# Issue PUT request
	my @mod_group = (undef) x scalar(@ordered_genomes);
	my %mod_group_set;
	my $group_name = 'updated';
	my $put_request = {
		user => $post_response_json->{user},
		CGISESSID => $post_response_json->{CGISESSID},
		genomes => \@ordered_genomes
	};

	while(my $row = $private_rs->next) {
		my $n = 'private_'.$row->feature_id;
		$mod_group[$indices{$n}] = 1;
		$mod_group_set{$n} = 1;
	}

	$put_request->{group}->{$group_name} = \@mod_group;
	my $put_json = encode_json($put_request);

	my $rm = '/api/group/'.$group_id;
	$cgiapp->put($rm,
		'Content' => $put_json,
		'Content_Type' => 'application/json'
	);
	ok($cgiapp->success, 'Shiny group update PUT');

	my $json = t::lib::App::json_ok($cgiapp);

	is_shiny_response($json, 'Valid API Response');

	# Check group in response
	ok my $group_presence = $json->{groups}->{$group_name} => 'Updated group found in API Response';
	is($group_id, $json->{group_ids}->{$group_name}, 'Updated group ID matches group ID in API Response');
	is_deeply($group_presence, \@mod_group, 'Updated group matches group in API Response');

	# Check group in DB
	ok my $private_list = PrivateFeatureGroup->search(
			{ genome_group_id => $group_id },
			{ columns => [qw/feature_id/] }
		)
		=> 'Updated group private genomes retrieved from DB';

	my %db_group_set;
	while(my $row = $private_list->next) {
		my $genome = 'private_' . $row->feature_id;
		
		$db_group_set{$genome} = 1;
	}

	is_deeply(\%mod_group_set, \%db_group_set, 'Updated group matches group in DB');


	ok my $group_rs = GenomeGroup->search(
			{
				genome_group_id => $group_id
			},
			{
				columns => [qw/name/]
			}
		)
		=> 'Updated group properties retrieved from DB';

	is($group_rs->first->name, $group_name, 'Updated group properties matches group properties in DB');

}


=head2 check_groups

=cut
sub check_groups {
	my $json = shift;
	my $ordered_genomes = shift;

	# Get custom groups
	ok my $group1 = GenomeGroup->find({ name => 'group1' }) => 'Custom group 1 retrieved from DB';
	ok my $group2 = GenomeGroup->find({ name => 'group2' }) => 'Custom group 2 retrieved from DB';

	# Get genomes in group
	ok my $public_list1 = FeatureGroup->search(
			{ genome_group_id => $group1->genome_group_id },
			{ columns => [qw/feature_id/] }
		)
		=> 'Custom group 1 genome list retrieved from DB';

	ok my $public_list2 = FeatureGroup->search(
			{ genome_group_id => $group2->genome_group_id },
			{ columns => [qw/feature_id/] }
		)
		=> 'Custom group 2 genome list retrieved from DB';

	ok my $private_list1 = PrivateFeatureGroup->search(
			{ genome_group_id => $group1->genome_group_id },
			{ columns => [qw/feature_id/] }
		)
		=> 'Custom group 1 genome list retrieved from DB';

	ok my $private_list2 = PrivateFeatureGroup->search(
			{ genome_group_id => $group2->genome_group_id },
			{ columns => [qw/feature_id/] }
		)
		=> 'Custom group 2 genome list retrieved from DB';

	# Save group assignments
	my %group_lists;

	while(my $row = $public_list1->next) {
		my $genome = 'public_' . $row->feature_id;
		
		$group_lists{1}->{$genome} = 1;
	}

	while(my $row = $private_list1->next) {
		my $genome = 'private_' . $row->feature_id;
		
		$group_lists{1}->{$genome} = 1;
	}

	while(my $row = $public_list2->next) {
		my $genome = 'public_' . $row->feature_id;
		
		$group_lists{2}->{$genome} = 1;
	}

	while(my $row = $private_list2->next) {
		my $genome = 'private_' . $row->feature_id;
		
		$group_lists{2}->{$genome} = 1;
	}

	# Compare to Shiny data
	foreach my $group (1,2) {
		my $group_name = 'group'.$group;
		ok my $binary_array = $json->{groups}{$group_name}
			=> "Located group $group_name in Shiny JSON data.";
		
		my $i = 0;
		foreach my $value (@$binary_array) {
			my $genome = $ordered_genomes->[$i];

			if($value) {
				# Genome assigned to group
				ok defined $group_lists{$group}->{$genome}
					=> "Genome $genome correctly assigned to group $group.";
			} 
			else {
				ok !defined $group_lists{$group}->{$genome}
					=> "Genome $genome correctly not included in group $group.";
			}

			$i++;
		}
	}
}

=head2 check_meta

=cut
sub check_meta {
	my $json = shift;
	my $ordered_genomes = shift;

	my @meta_terms = keys %{$data->metaTerms};

	foreach my $term (@meta_terms) {
		# Get all term annotations
		ok my $cvterm = Cvterm->find({ name => $term }) => "Cvterm $term retrieved from DB";
		
		ok my $public_list = Featureprop->search(
				{ type_id => $cvterm->cvterm_id },
				{ 
					columns => [qw/feature_id value/],
					order_by => 'rank'
				}
			)
			=> "Public $term genome annotations retrieved from DB";

		ok my $private_list = PrivateFeatureprop->search(
				{ type_id => $cvterm->cvterm_id },
				{ 
					columns => [qw/feature_id value/],
					order_by => 'rank'
				}
			)
			=> "Private $term genome annotations retrieved from DB";

		# Save genome annotations
		my %meta_lists;
		while(my $row = $public_list->next) {
			my $genome = 'public_' . $row->feature_id;
			
			$meta_lists{$genome} = [] unless $meta_lists{$genome};
			push @{$meta_lists{$genome}}, $row->value;
		}

		while(my $row = $private_list->next) {
			my $genome = 'private_' . $row->feature_id;
			
			$meta_lists{$genome} = [] unless $meta_lists{$genome};
			push @{$meta_lists{$genome}}, $row->value;
		}

		# Compare to Shiny data
		ok my $binary_array = $json->{data}{$term}
			=> "Located data array $term in Shiny JSON data.";
		
		my $i = 0;
		foreach my $value (@$binary_array) {
			my $genome = $ordered_genomes->[$i];

			if($term eq 'isolation_date' && $value) {

				if($value) {
					my $year = $json->{data}{'isolation_year'}->[$i];
					my $mon = $json->{data}{'isolation_month'}->[$i];
					my $day = $json->{data}{'isolation_day'}->[$i];

					my $date = join('-', $year, $mon, $day);

					ok defined $meta_lists{$genome} && 
						$value eq $meta_lists{$genome}->[0] &&
						$date eq $meta_lists{$genome}->[0]
						=> "Genome $genome annotation for $term correct";
				}
				
			}
			elsif($term eq 'isolation_location' && $value) {

				# Only validate the presence of location stuff, too complex to really break down
				ok defined $meta_lists{$genome}
					=> "Genome $genome annotation for $term correct";

			}
			else {
				if($value) {
					# Genome assigned meta-data
					ok defined $meta_lists{$genome} && $value eq join(' ',@{$meta_lists{$genome}})
						=> "Genome $genome annotation for $term correct.";

				} 
				else {
					ok !defined($meta_lists{$genome})
						=> "No genome $genome annotation for $term.";
				}
			}

			$i++;
		}
	}
}

=head2 custom_groups

Fixture for inserting custom user-defined groups

=cut
sub custom_groups {
	my $schema = shift;

	# Get some genome IDs for groups
	my $public_rs = Feature->search(
		{
			'type.name' => 'contig_collection'
		},
		{
			join => ['type'],
			rows => 10,
			columns => ['feature_id']
		}
	);

	my $private_rs = PrivateFeature->search(
		{
			'type.name' => 'contig_collection',
			'upload.login_id' => $login_id
		},
		{
			join => ['type','upload'],
			rows => 10,
			columns => ['feature_id']
		}
	);

	# Form groups
	my @group1;
	my @group2;
	my $i = 0;
	while(my $row = $public_rs->next) {

		if($i < 5) {
			push @group1, 'public_'.$row->feature_id;
		}
		else {
			push @group2, 'public_'.$row->feature_id;
		}
		$i++;
	}
	$i = 0;
	while(my $row = $private_rs->next) {

		if($i < 5) {
			push @group1, 'private_'.$row->feature_id;
		}
		else {
			push @group2, 'private_'.$row->feature_id;
		}
		$i++;
	}

	# Send create requests to server
	my $page = "/collections/create";
	my $params1 = {
		name => 'group1',
		genome => \@group1
	};
	$cgiapp->post($page, $params1);
	
	my $params2 = {
		name => 'group2',
		genome => \@group2
	};
	$cgiapp->post($page, $params2);

	return 1;
}



