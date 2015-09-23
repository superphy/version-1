#!/usr/bin/env perl

=pod

=head1 NAME

t::edit-genome.t

=head1 SNYNOPSIS



=head1 DESCRIPTION

Tests for update_genome_jm method in UpdateScheduler.pm

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use File::Basename;
use lib dirname (__FILE__) . "/../";
use Test::More;
use Test::Exception;
use IO::CaptureOutput qw(capture_exec);
use Data::Bridge;
use Data::Grouper;
use Modules::Update;
use Modules::UpdateScheduler;
use t::lib::App;
use JSON::MaybeXS;
use Modules::FormDataGenerator;
use Phylogeny::Tree;
use Statistics::R;
use Config::Tiny;
use Database::Chado::Schema;
use Test::PostgreSQL;
use Test::DBIx::Class
	{
		config_path => [
			[qw(t etc miner)],
			[qw(t etc location)],
			[qw(t etc pipeline)],
	        '+',
    	],
    	traits => [
	    	'Testpostgresql'
	    ]
	};

# Install basic DB data such as genome features
fixtures_ok 'basic'
	=> 'Install basic fixtures from configuration files';

# Install Host/Source data
fixtures_ok 'miner'
	=> 'Install host / source fixtures from configuration files';

# Install Location data
fixtures_ok 'location'
	=> 'Install location fixtures from configuration files';

# Install Pipeline tables
fixtures_ok 'pipeline'
	=> 'Install pipeline table fixtures from configuration files';

# Initialize DB interface objects via Bridge module
ok my $dbBridge = Data::Bridge->new(schema => Schema), 
	'Create Data::Bridge object';

# Grouping object
ok my $grouper = Data::Grouper->new(schema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory), 
	'Create Data::Grouper object';


# Create test CGIApp and work environment
my $cgiapp;
lives_ok { $cgiapp = t::lib::App::launch(Schema, $ARGV[0]) } 'Test::WWW::Mechanize::CGIApp initialized';
BAIL_OUT('CGIApp initialization failed') unless $cgiapp;


# Group genomes into standard groups
fixtures_ok sub {
	my $schema = shift;

	# Retrieve some user ID, just need a placeholder
	my $user = $schema->resultset('Login')->find(2);
	die "Error: no users loaded" unless $user;

    # Perform update / creation of standard groups
    $grouper->initializeStandardGroups($user->username);

    return 1;
  
}, 'Install standard group fixtures';

# Add locations

# Add tree

# Login as test user
t::lib::App::login_ok($cgiapp, 'testbot', 'password');



# Submit genome edits
my %edits;
subtest 'Submit genome edits' => sub {

	# Retrieve genome upload id to edit
	is_resultset my $genome_rs = PrivateFeature->search(
		{
			'me.type_id' => $dbBridge->cvmemory('contig_collection'),
			'upload.login_id' => 1, # testbot has login_id = 1
			'upload.category' => 'public'
		},
		{
			prefetch => {'private_featureprops' => 'type'},
			join => 'upload'
		}
	);
	my $genome_row = $genome_rs->first;
	ok my $upload_id = $genome_row->upload_id => "Selected genome ".$genome_row->feature_id." for edit operation";
	$edits{upload} = $upload_id;
	$edits{feature} = $genome_row->feature_id;

	# Retrieve some new values (to be safe fill in all required values since they might not be in the test DB)
	$edits{isolation_host_input} = 'mmusculus';
	$edits{isolation_host_value} = 'Mus musculus (mouse)';
	$edits{category} = 'mammal';
	my $source = (keys %{$dbBridge->sourceList->{$edits{category}}})[2];
	$edits{isolation_source_input} = $source;
	$edits{isolation_source_value} = $dbBridge->sourceList->{$edits{category}}{$source};
	my $syndrome = [ (keys %{$dbBridge->syndromeList->{$edits{category}}})[1..3] ];
	$edits{syndrome_input} = $syndrome;
	my @syndrome_values;
	foreach my $sk (@$syndrome) {
		push @syndrome_values, $dbBridge->syndromeList->{$edits{category}}{$sk};
	}
	$edits{syndrome_value} = \@syndrome_values;
	my $location_id = GeocodedLocation->first->geocode_id;
	$edits{location} = $location_id;
	$edits{serotype_input} = 'O157:H7';
	$edits{serotype_value} = 'O157:H7';
	$edits{isolation_date_input} = '1200-01-01';
	$edits{isolation_date_value} = '1200-01-01';
	
	diag explain %edits;

	# Get edit form
	$cgiapp->get_ok("/superphy/upload/edit_genome?upload_id=$upload_id");

	# Note: fields populated by javascript will be empty
	ok my $form = $cgiapp->form_id('genomeUploadForm') => "Retrieved edit form";

	# Make sure there are no surprises
	$cgiapp->untick('g_other_syndrome_cb', 'other');
	$cgiapp->untick('g_asymptomatic', 'asymptomatic');
	
	# Edit properties (the edits coincide with the empty required fields due to not running javascript)
	$cgiapp->field('g_host', $edits{isolation_host_input});
	$cgiapp->field('g_source', $edits{isolation_source_input});
	$cgiapp->field('g_syndrome', $edits{syndrome_input});
	$cgiapp->field('g_serotype', $edits{serotype_input});
	$cgiapp->field('g_date', $edits{isolation_date_input});
	$cgiapp->field('geocode_id', $edits{location});
	
	# Submit form
	$cgiapp->submit_form();
	ok($cgiapp->success, 'Submit Edit form');

	#diag $cgiapp->content(format => 'text');

	$cgiapp->content_contains('Genome update operation has been submitted to job queue', "Confirmation of submission recieved") or 
		BAIL_OUT('Genome edit submission failed');
};

# Run update
subtest 'Run update scheduler' => sub {

	# Locate pending_update row 
	is_resultset my $pending_rs = PendingUpdate->search(
		{
			upload_id => $edits{upload}
		}
	);
	my $pending_row = $pending_rs->first;
	ok  $pending_row && $pending_row->step == Modules::UpdateScheduler::status_id('pending')
		=> 'Edit job record found';

	# Run scheduler
	my $pipeline_cmd = dirname (__FILE__) . "/../Data/genodo_pipeline.pl";
	my $perl_interpreter = $^X;
	my @loading_args = ("$perl_interpreter $pipeline_cmd","--config",$ENV{SUPERPHY_CONFIGFILE},"--test_update");
		
	my $cmd = join(' ',@loading_args);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);

	ok $success => 'Return status from UpdateScheduler ok';
	BAIL_OUT("UpdateScheduler run failed ($stderr)") unless $success;

	is_resultset my $completed_rs = PendingUpdate->search(
		{
			upload_id => $edits{upload}
		}
	);
	my $completed_row = $completed_rs->first;
	ok  $completed_row && $completed_row->step == Modules::UpdateScheduler::status_id('completed')
		=> 'Edit job completed';

	
};

# Confirm edit results
subtest 'Confirm edits' => sub {

	# Compare single-value properties
	foreach my $data_type (qw/isolation_host isolation_source serotype isolation_date/) {
		
		my $data_value_name = "$data_type\_value";
		is_resultset my $property_rs = PrivateFeatureprop->search(
			{
				feature_id => $edits{feature},
				type_id => $dbBridge->cvmemory->{$data_type},
			}
		);
		ok my $property_row = $property_rs->first => "Retrieved $data_type private_featureprop entry.";
		diag "EXPECTING: ".$edits{$data_value_name};

		is_fields 'value', $property_row, [$edits{$data_value_name}], "private_featureprop entry contains updated value for $data_type";
	}

	# Compare location entry
	is_resultset my $location_rs = PrivateGenomeLocation->search(
		{
			feature_id => $edits{feature},
		}
	);
	ok my $location_row = $location_rs->first => "Retrieved private_genome_location entry.";
	diag "EXPECTING: ".$edits{'location'};

	is_fields 'geocode_id', $location_row, [$edits{'location'}], "private_genome_location entry contains updated value";


	# Compare multi-value entries for syndrome
	my %syndrome_count;
	is_resultset my $syndrome_rs = PrivateFeatureprop->search(
		{
			feature_id => $edits{feature},
			type_id => $dbBridge->cvmemory->{syndrome},
		}
	);
	while(my $syndrome_row = $syndrome_rs->next) {
		$syndrome_count{$syndrome_row->value}++;
	}
	
	foreach my $syndrome_value (@{$edits{syndrome_value}}) {
		$syndrome_count{$syndrome_value} += 2;
	}

	my $ok = 1;
	foreach my $k (keys %syndrome_count) {
		unless($syndrome_count{$k} == 3) {
			if($syndrome_count{$k} == 1) {
				diag "Unexpected syndrome $k in DB";
			}
			else {
				diag "Syndrome $k missing in DB";
			}
			$ok = 0;
		}
	}
	ok $ok => 'private_featureprop entry contains updated value(s) for syndrome';

	# Check updated meta-data groups
	my %expected_groups = (
		isolation_host => [$edits{isolation_host_value}],
		isolation_source => [$edits{isolation_source_value}],
		syndrome => $edits{syndrome_value},
		serotype => [$edits{serotype_value}]
	);
	ok my $expected_group_assignments = $grouper->match(\%expected_groups) => 'Retrieved group assignments for updated meta-data';
	my %expected_group_ids;
	foreach my $meta_data_type (keys %{$expected_group_assignments}) {
		foreach my $meta_data_value (keys %{$expected_group_assignments->{$meta_data_type}}) {
			$expected_group_ids{$expected_group_assignments->{$meta_data_type}{$meta_data_value}} = 1;
		}
	}
	diag explain $expected_group_assignments;

	is_resultset my $group_rs = ResultSet('PrivateFeatureGroup')->search(
		{
			feature_id => $edits{feature}
		}
	);
	while(my $group_row = $group_rs->next) {
		$expected_group_ids{$group_row->genome_group_id} += 2;
	}

	$ok = 1;
	foreach my $group_id (keys %expected_group_ids) {
		if($expected_group_ids{$group_id} == 1) {
			diag "Missing group assignment $group_id";
			$ok = 0;
		}
		elsif($expected_group_ids{$group_id} == 2) {
			diag "Found additional group assignment $group_id in DB";
		}
	}
	ok $ok => 'private_feature_group table contains group assignments for updated meta-data values';
	$edits{groups_value} = [keys %expected_group_ids];

	# Check for updated values in meta-data JSON
	is_result my $meta_row = ResultSet('Meta')->find(
		{
			name => 'upublic'
		},
		{
			key => 'meta_c1'
		}
	);

	ok my $meta = decode_json($meta_row->data_string) => 'Retrieved User-submitted public genome meta-data (in JSON format)';

	my $genome_meta= $meta->{'private_'.$edits{feature}};
	ok compare_meta($genome_meta) => 'public meta JSON object contains updated values';

	# Check for genome in tree
	ok check_tree() => 'Genome present in public phylogenetic tree';

	# Check for updated values in shiny matrix
	ok compare_shiny() => 'R/Shiny meta-data file contains updated values';
	
};



done_testing();

########
## SUBS
########

sub compare_meta {
	my $genome_meta = shift;

	my $ok = 1;

	# Compare single-value properties
	foreach my $data_type (qw/isolation_host isolation_source serotype isolation_date/) {
		my $data_value_name = $data_type . '_value';
		my $expected = $edits{$data_value_name};
		my $got = $genome_meta->{$data_type}->[0];

		if($expected ne $got) {
			$ok = 0;
			diag "$data_type property in meta JSON object do not match updated value (expected $expected, got: $got)";
		}
	}

	# Compare multi-value properties
	foreach my $data_type (qw/groups syndrome/) {
		my %expected;
		my $data_value_name = $data_type . '_value';
		foreach my $v (@{$edits{$data_value_name}}) {
			$expected{$v} = 1;
		}

		foreach my $v (@{$genome_meta->{$data_type}}) {
			$expected{$v} += 2;
		}

		# Ignores additional values in meta object since there are groups based on stx subtypes
		# which do not factor in these tests
		foreach my $v (keys %expected) {
			if($expected{$v} == 1) {
				$ok = 0;
				diag "Value $v for $data_type property missing in meta JSON object";
			}
		}

		diag explain \%expected;
	}

	return $ok;
}

sub check_tree {

	my $tree = Phylogeny::Tree->new(dbix_schema => $dbBridge->dbixSchema);

	my $tree_string = $tree->publicTree;
	my $genome_label = 'private_'.$edits{feature};

	return $tree_string =~ m/$genome_label/;

}

sub compare_shiny {

	# Genome data
	my $user_feature_id = $edits{feature};
	my $genome_label = 'private_'.$user_feature_id;

	# Find location of shiny data file
	my $conf = Config::Tiny->read($ENV{SUPERPHY_CONFIGFILE});
	my $shiny_file = $conf->{shiny}->{targetdir} . '/superphy-df_meta.RData';

	# Load meta-data object
	my $R = Statistics::R->new();
    
    # Compare a few nominal values to ensure edits have made it to the shiny file
    # There are miltple potential issues with the display of meta-data in this R format
    # but they should be tested elsewhere.
    my $ok = 1;
    my $host = $R->run(
    	qq/load('$shiny_file')/,
    	qq/genome_row <- lapply(df_meta['$genome_label',], as.character)/,
        q/cat(genome_row[['isolation_host']])/
    );

    if($host ne $edits{isolation_host_value}) {
    	$ok = 0;
    	diag "Unexpected isolation host in R/Shiny meta-data file $shiny_file (expected: ".$edits{isolation_host_value}.", got: $host)";
    }

    my $source = $R->run(
        q/cat(genome_row[['isolation_source']])/
    );

    if($source ne $edits{isolation_source_value}) {
    	$ok = 0;
    	diag "Unexpected isolation source in R/Shiny meta-data file $shiny_file (expected: ".$edits{isolation_source_value}.", got: $source)";
    }

    my $serotype = $R->run(
        q/cat(genome_row[['serotype']])/
    );

    if($serotype ne $edits{serotype_value}) {
    	$ok = 0;
    	diag "Unexpected serotype in R/Shiny meta-data file $shiny_file (expected: ".$edits{serotype_value}.", got: $serotype)";
    }

    return $ok;
}