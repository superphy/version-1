#!/usr/bin/env perl

=pod

=head1 NAME

t::pipeline.t

=head1 DESCRIPTION

Tests for Data/genodo_pipeline.pl

Creates clone of demo database for testing and uploads a single sequence.

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
use lib "$FindBin::Bin/lib/";
use TestPostgresDB;
use t::lib::App;
use Config::Simple;
use File::Temp qw/tempdir/;
use IO::CaptureOutput qw(capture_exec);
use Modules::User;
use t::lib::PipelineT; 
use Test::DBIx::Class {
	schema_class => 'Database::Chado::Schema',
	deploy_db => 0,
	keep_db => 1,
	traits => [qw/TestPostgresDB/]
}, 'Tracker', 'Login';


# Create test CGIApp and work environment
my $cgiapp;
my $cleanup_dir = 0;
lives_ok { $cgiapp = t::lib::App::launch(Schema, $cleanup_dir) } 'Test::WWW::Mechanize::CGIApp initialized';
BAIL_OUT('CGIApp initialization failed') unless $cgiapp;


my $config_file = $ENV{SUPERPHY_CONFIGFILE};
ok($config_file, "Retrieved config file");
diag("Config file: ".$config_file);

# Login as test user
fixtures_ok [
	'Login' => [
		[qw/username password firstname lastname email/],
	    ['testbot', Modules::User::_encode_password('password'), 'testbot', '3000', 'donotemailme@ever.com'],
	    ['eviltestbot', Modules::User::_encode_password('password'), 'eviltestbot', '4000', 'donotemailme@ever.com']
	]
], 'Inserted test users';
t::lib::App::login_ok($cgiapp, 'testbot', 'password');
ok(my $login_id = Login->find({ username => 'testbot' })->login_id, 'Retrieved login ID for test user');


# # Submit genome upload
my $genome_name = upload_genome($cgiapp);

# # Validate tracker table entry
my $tracking_id = tracker_table($login_id, $genome_name);

# # Initiate loading pipeline
run_pipeline();

# Perform tests on loaded data

# Retrieve feature ID for uploaded genome
ok(my $genome_row = genome_feature(PrivateFeature, genome_name()), 'Find genome in private_feature table');

# Make sure all genome properties match original submission
cmp_genome_properties(Schema, $genome_row->feature_id, upload_form(), 'Check genome properties in DB');

# Check tree
tree_contains(Schema, $genome_row->feature_id, 'Find genome in global phylogenetic tree');

# Check meta-data
metadata_contains(Schema, $genome_row->feature_id, 'testbot', 'Find genome in user\'s private meta-data JSON object');


done_testing();

########
## SUBS
########

=head2 upload_genome

Send request to server to upload genome

=cut
sub upload_genome {
	my $cgiapp = shift;

	# Genome properties
	my $genome_name = genome_name();
	my $form = upload_form();

	# Submit form
	my $rm = '/upload/upload_genome';
	$cgiapp->post($rm,
		$form,
		'Content_Type' => 'form-data'
	);
	ok($cgiapp->success, 'Genome upload POST');

	#diag $cgiapp->content(format => 'text');

	$cgiapp->content_contains('Status of Uploaded Genome', "Redirected to upload status page");
	$cgiapp->content_contains('Queued', "Genome queued for analysis") or 
		BAIL_OUT('Genome upload failed');

	return $genome_name;
}

=head2 tracking_table

Make sure tracking table contains uploaded genome details

=cut
sub tracker_table {
	my $login_id = shift;
	my $genome_name = shift;

	ok my $track = Tracker->find( { login_id => $login_id, feature_name => $genome_name })
    	=> 'Tracker table entry found';

    is_fields [qw/step access_category/], $track, [1, 'public'],
    	'Tracker entry valid';

    return $track->tracker_id;
}

=head2 run_pipeline

Run analysis pipeline and ensure that it completes successfully

=cut
sub run_pipeline {

	my $perl_interpreter = $^X;
	my @args = (
		"$perl_interpreter $FindBin::Bin/../Data/genodo_pipeline.pl",
		"--config $config_file",
		"--test"
	);
	my $cmd = join(' ', @args);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);

	ok($success, "Loading pipeline completed") or
		BAIL_OUT("Loading pipeline failed ($stderr)");
}

