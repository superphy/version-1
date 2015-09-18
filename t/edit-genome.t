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
#use Modules::FormDataGenerator;
use Database::Chado::Schema;
use Test::DBIx::Class
	'-config_path' => [
		[qw(t etc miner)],
		[qw(t etc location)],
		[qw(t etc pipeline)],
        '+',
    ];

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
			'me.type_id' => $dbBridge->cvmemory('contig_collection')
		},
		{
			prefetch => {'private_featureprops' => 'type'}
		}
	);
	my $genome_row = $genome_rs->first;
	ok my $upload_id = $genome_row->upload_id => "Selected genome ".$genome_row->feature_id." for edit operation";
	$edits{upload} = $upload_id;

	# Retrieve some new values (to be safe fill in all required values since they might not be in the test DB)
	$edits{host} = 'Mus musculus (mouse)';
	$edits{category} = 'mammal';
	my $source = (values %{$dbBridge->sourceList->{$edits{category}}})[2];
	$edits{source} = $source;
	my $syndrome = [ (values %{$dbBridge->syndromeList->{$edits{category}}})[1..3] ];
	$edits{syndrome} = $syndrome;
	my $location_id = GeocodedLocation->first->geocode_id;
	$edits{location} = $location_id;
	$edits{serotype} = 'O157:H7';
	$edits{date} = '1200-01-01';
	
	diag explain %edits;

	# Get edit form
	$cgiapp->get_ok("/superphy/upload/edit_genome?upload_id=$upload_id");

	# Note: fields populated by javascript will be empty
	ok my $form = $cgiapp->form_id('genomeUploadForm') => "Retrieved edit form";
	
	# Edit properties (the edits coincide with the empty required fields due to not running javascript)
	$cgiapp->field('g_host', $edits{host});
	$cgiapp->field('g_source', $edits{source});
	$cgiapp->field('g_syndrome', $edits{syndrome});
	$cgiapp->field('g_serotype', $edits{serotype});
	$cgiapp->field('g_date', $edits{date});
	$cgiapp->field('geocode_id', $edits{location});

	# Make sure there are no surprises
	$cgiapp->untick('g_other_syndrome_cb', 'other');
	$cgiapp->untick('g_asymptomatic', 'asymptomatic');


	# Submit form
	$cgiapp->submit();
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
	
	if($success) {
		diag "Panseq VF/AMR analysis completed successfully.";
	} else {
		die "Panseq VF/AMR analysis failed ($stderr).";
	}
	
};




done_testing();

########
## SUBS
########

