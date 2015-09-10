#!/usr/bin/env perl

=pod

=head1 NAME

t::collections.t

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
use Modules::Dispatch;
use Modules::FormDataGenerator;
use Test::More;
use t::lib::App;
use t::lib::QuickDB;
use JSON::Any;
use Try::Tiny;

# Create Test Database instance
my $schema = t::lib::QuickDB::connect();

# Add test-specific data to database
try {
    t::lib::QuickDB::load_standard_groups( $schema );
}
catch {
    my $exception = $_;
    BAIL_OUT( 'Local test data creation failed: ' . $exception );
};

# Test global variables
# Test genomes
my ($good_genomes, $bad_genomes) = test_genomes($schema);
ok(@$good_genomes == 6, 'test genome retrieval, accessible set') or 
	BAIL_OUT('Cannot obtain test set of genomes');
ok(@$bad_genomes == 3, 'test genome retrieval, inaccessible set') or 
	BAIL_OUT('Cannot obtain test set of genomes');


my $login_crudentials = t::lib::QuickDB::login_crudentials();

# Create WWW::Mechanize CGIApp object
my $app = t::lib::App::relaunch($schema);

# Collections::create tests
subtest 'Collections::create - correct response to invalid parameters' => sub {
	my $fail = 0;

	diag "Not logged in";
	my $page = '/collections/create';
	$app->get_ok($page);
	my $json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $fail), 'returned valid JSON object');

	diag "Logged in, missing group name";
	t::lib::App::quickdb_login($app);
	$page = '/collections/create';
	$app->get_ok($page);
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $fail), 'returned valid JSON object');
	
	diag "Logged in, have group name, missing genome";
	$page = '/collections/create?name=TestGroup';
	$app->get_ok($page);
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $fail), 'returned valid JSON object');

};

subtest 'Collections::create - create genome group' => sub {

	# Test inputs
	my $success = 1;
	my $fail = 0;
	my $name = 'Test Group';
	my $description = 'A new group';
	my $collection = 'A new collection';
	my $user = t::lib::QuickDB::user();

	# Create DB interface object
	my $data = Modules::FormDataGenerator->new();
	$data->dbixSchema($schema);


	diag "Create group with no collection";
	my $page = "/collections/create";
	my $params = {
		name => $name,
		description => $description,
		genome => $good_genomes
	};
	$app->post_ok($page, $params, 'send create request to server');
	my $json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');
	
	my $group_id = $json->{group_id};
	validate_group($json, $user, $good_genomes, $group_id, $name, 'Individuals');

	diag "Attempt create group with inaccessible genomes";
	$params = {
		name => $name,
		description => $description,
		genome => [@$good_genomes, @$bad_genomes]
	};
	$app->post_ok($page, $params, 'send create request to server');
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $fail), 'returned valid JSON object');
	
};


subtest 'Collections::update - modify genome group' => sub {

	# Test inputs
	my $success = 1;
	my $fail = 0;
	my $name = 'Prepare for modification';
	my $name2 = 'Metamorphosis complete';
	my $description = 'A newer group';
	my $description2 = 'A re-invented group';
	my $collection = 'Individuals';
	my $collection2 = 'Stepping out of the shadow of Individuals';
	my $collection3 = 'Trying out a new name';
	my $user = t::lib::QuickDB::user();

	# Create DB interface object
	my $data = Modules::FormDataGenerator->new();
	$data->dbixSchema($schema);

	# Subsets of test genomes
	my @pregenomes = @{$good_genomes}[0..3];
	my @postgenomes = @{$good_genomes}[4..5];

	diag "Create group";
	my $page = "/collections/create";
	my $params = {
		name => $name,
		description => $description,
		genome => \@pregenomes,
		category => $collection
	};
	$app->post_ok($page, $params, 'send create request to server');
	my $json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');
	
	my $group_id = $json->{group_id};
	validate_group($json, $user, \@pregenomes, $group_id, $name, $collection);

	diag "Change genome set in group";
	$page = "/collections/update";
	$params = {
		group_id => $group_id,
		genome => \@postgenomes,
	};
	$app->post_ok($page, $params, 'send update request to server');
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');
	
	check_for_group($json, $user, $group_id, \@postgenomes, 0);
	check_for_group($json, $user, $group_id, \@pregenomes, 1);

	diag "Change group properties 1";
	$page = "/collections/update";
	$params = {
		group_id => $group_id,
		genome => $good_genomes,
		name => $name2,
		description => $description2
	};
	$app->post_ok($page, $params, 'send update request to server');
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');
	
	validate_group($json, $user, $good_genomes, $group_id, $name2, $collection);

	diag "Change group properties 2";
	$page = "/collections/update";
	$params = {
		group_id => $group_id,
		category => $collection2
	};
	$app->post_ok($page, $params, 'send update request to server');
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');
	
	my $group_json_object = check_group_properties($json, $user, $group_id, $name2, $collection2);
	diag explain $group_json_object->{custom};

	diag "Change group properties 3";
	$page = "/collections/update";
	$params = {
		group_id => $group_id,
		category => $collection3
	};
	$app->post_ok($page, $params, 'send update request to server');
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');
	
	$group_json_object = check_group_properties($json, $user, $group_id, $name2, $collection3);
	diag explain $group_json_object->{custom};
	
	diag "Change group properties 4";
	$page = "/collections/update";
	$params = {
		group_id => $group_id,
		category => $collection
	};
	$app->post_ok($page, $params, 'send update request to server');
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');
	
	$group_json_object = check_group_properties($json, $user, $group_id, $name2, $collection);
	diag explain $group_json_object->{custom};

};

subtest 'Collections::delete - delete genome group' => sub {

	# Test inputs
	my $success = 1;
	my $fail = 0;
	my $deleted = 1;
	my $user = t::lib::QuickDB::user();

	# Create DB interface object
	my $data = Modules::FormDataGenerator->new();
	$data->dbixSchema($schema);

	# Get list of groups
	my $groups = list_of_groups($data, $user);
	BAIL_OUT( 'Insufficient number of groups for test'.
		' There shouldve been at least 2 genome groups created from previous tests') unless(@$groups > 1);
	
	diag "Delete 1st group";
	my $page = "/collections/delete";
	my ($group_id, $group_name, $collection_name) = @{$groups->[0]};
	my $params = {
		group_id => $group_id
	};
	$app->post_ok($page, $params, 'send delete request to server');
	my $json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');

	check_for_group($json, $user, $group_id, $good_genomes, $deleted);
	my $group_json_object = check_group_properties($json, $user, $group_id, $group_name, $collection_name, $deleted);
	diag explain $group_json_object->{custom};

	diag "Delete 2nd group";
	$page = "/collections/delete";
	($group_id, $group_name, $collection_name) = @{$groups->[1]};
	$params = {
		group_id => $group_id
	};
	$app->post_ok($page, $params, 'send delete request to server');
	$json = t::lib::App::json_ok($app);
	ok(valid_collections_response($json, $success), 'returned valid JSON object');

	check_for_group($json, $user, $group_id, $good_genomes, $deleted);
	$group_json_object = check_group_properties($json, $user, $group_id, $group_name, $collection_name, $deleted);
	diag explain $group_json_object->{custom};


};





done_testing();


=head2 valid_collections_response

Checks that the json object sent
from Collections:: methods has the required
keys: success, error.

A successful create operations should return
a group_id key and have success = TRUE,
as well as public_genomes, private_genomes and groups
JSON objects

=cut

sub valid_collections_response {
	my $json = shift;
	my $was_successful = shift;

	return 0 unless defined $json->{success};
	
	if($was_successful) {
		return 0 unless defined $json->{group_id};
		return 0 unless $json->{success};
		return 0 unless defined $json->{groups};
		return 0 unless defined $json->{public_genomes};
		return 0 unless defined $json->{private_genomes};

	} else {
		return 0 unless defined $json->{error};
		return 0 if $json->{success};

	}

	return 1;
}

=head2 test_genomes

Get mix of public & private
genomes for the test user,
as well as set of genomes not
accessible to test user.

=cut
sub test_genomes {
	my $schema = shift;

	my $user = t::lib::QuickDB::user();
	my @genomes;

	# Public genomes
	my $public_rs = $schema->resultset('Feature')->search(
		{
			'type.name' => 'contig_collection'
		},
		{
			join => 'type',
			rows => 3,
			columns => ['feature_id']
		}
	);

	push @genomes, map { 'public_'.$_->feature_id } $public_rs->all;

	# Private genomes
	my $private_rs = $schema->resultset('PrivateFeature')->search(
		{
			'type.name' => 'contig_collection',
			'login.username' => $user
		},
		{
			join => ['type', { 'upload' => 'login' }],
			rows => 3,
			columns => ['feature_id']
		}
	);

	push @genomes, map { 'private_'.$_->feature_id } $private_rs->all;

	# Other user's private genomes
	my @bad_genomes;
	my $evil_user = t::lib::QuickDB::evil_user();
	my $bad_rs = $schema->resultset('PrivateFeature')->search(
		{
			'type.name' => 'contig_collection',
			'login.username' => $evil_user
		},
		{
			join => ['type', { 'upload' => 'login' }],
			rows => 3,
			columns => ['feature_id']
		}
	);

	push @bad_genomes, map { 'private_'.$_->feature_id } $bad_rs->all;

	return (\@genomes, \@bad_genomes);
}

=head2 validate_group

Check if submitted genomes
have group assigned in DB

=cut
sub validate_group {
	my $response = shift;
	my $user = shift;
	my $genomes = shift;
	my $group_id = shift;
	my $group_name = shift;
	my $collection_name = shift;

	
	#$schema->storage->debug(1);

	check_for_group($response, $user, $group_id, $genomes, 0);

	check_group_properties($response, $user, $group_id, $group_name, $collection_name, 0);

	return;
}

# Check group assignments in meta-data JSON object
sub check_for_group {
	my $data_json = shift; # perl-equivalent of JSON object from response
	my $user = shift; # Username
	my $group_id = shift; # Group ID in genome_group table
	my $genomes = shift; # Array-ref of genome labels (e.g. public_123456)
	my $deleted = shift; # Boolean indicating if should test for presence or absence of group


	my $public_json = $data_json->{public_genomes};
	my $private_json = $data_json->{private_genomes};
	ok($public_json && $private_json, 'retrieved meta-data JSON objects');
	#diag explain $public_json;

	
	my $all_assigned = 1;
	foreach my $g (@$genomes) {
		my $genome_json;
		if($g =~ m/^public/) {
			$genome_json = $public_json->{$g};
		} 
		else {
			$genome_json = $private_json->{$g};
		}

		
		unless($genome_json && defined $genome_json->{groups}) {
			next if $deleted; # Genome guaranteed not to have group if it has no groups array
			diag "$g genome does not have group array in meta-data object";
			diag explain $genome_json;
			$all_assigned = 0;
			last;
		}
		my $group_array = $genome_json->{groups};

		if($deleted) {
			if(grep(/^$group_id$/, @$group_array)) {
				diag "$g genome assigned group $group_id";
				diag explain $genome_json;
				$all_assigned = 0;
				last;
			}
		}
		else {
			unless(grep(/^$group_id$/, @$group_array)) {
				diag "$g genome not assigned group $group_id";
				diag explain $genome_json;
				$all_assigned = 0;
				last;
			}
		}
	}

	if($deleted) {
		ok($all_assigned, 'genomes not assigned group');
	}
	else {
		ok($all_assigned, 'genomes assigned proper group');
	}	
}

# Check group properties in groups JSON object
sub check_group_properties {
	my $data_json = shift; # perl-equivalent of JSON object from response 
	my $user = shift; # Username
	my $group_id = shift; # Group ID in genome_group table
	my $group_name = shift; # Group name
	my $collection_name = shift; # Collection name
	my $deleted = shift; # Boolean indicating if should test for presence or absence of group


	my $group_json = $data_json->{groups};
	ok($group_json, 'retrieved groups JSON object');
	#diag explain $public_json;

	my $found = 1;
	
	if($deleted) {
		if(defined($group_json->{custom}) && @{$group_json->{custom}} == 0) {
			pass('no custom groups found');
		}
	} else {
		ok(defined($group_json->{custom}) && @{$group_json->{custom}}, 'found custom genome groups');
	}
	
	# Check through custom groups
	if(defined($group_json->{custom}) && @{$group_json->{custom}}) {
		my $found_collection = 0;
		my $collection_json;
		foreach my $collection (@{$group_json->{custom}}) {
			if($collection->{name} eq $collection_name) {
				$found_collection = 1;
				$collection_json = $collection;
				last;
			}
		}
		if($deleted && !$found_collection) {
			ok(!$found_collection, 'group collection deleted');
			return;
		}
		else {
			ok($found_collection, 'found group collection');
		}
		
		my $found_group = 0;
		my $this_group_json;
		foreach my $group (@{$collection_json->{children}}) {
			if($group->{name} eq $group_name) {
				$found_group = 1;
				$this_group_json = $group;
				last;
			}
		}

		if($deleted) {
			ok(!$found_group, 'group deleted');
		}
		else {
			ok($found_group, 'found group');
			ok($this_group_json->{id} == $group_id, 'group IDs match');
		}
	}
	
	return $group_json;
}

# Retrieve group IDs currently in DB
sub list_of_groups {
	my $data = shift; # Modules::FormDataGenerator object-ref
	my $user = shift; # Username
	
	my ($group_string) = $data->userGroups($user);
	ok($group_string, 'retrieved groups objects');
	
	my $group_json = eval {
		JSON::Any->jsonToObj($group_string);
	};
	ok($group_json, 'got JSON group object');

	ok(defined($group_json->{custom}) && @{$group_json->{custom}}, 'found custom genome groups');

	my @groups;
	foreach my $collection_json (@{$group_json->{custom}}) {
		foreach my $group (@{$collection_json->{children}}) {
			push @groups, [$group->{id}, $group->{name}, $collection_json->{name}];
		}
	}

	return \@groups;
}







