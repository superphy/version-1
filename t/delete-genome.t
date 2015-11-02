#!/usr/bin/env perl

=pod

=head1 NAME

t::delete-genomes.t

=head1 SNYNOPSIS

SUPERPHY_CONFIGFILE=filename TEMPLATE=db_template DBUSER=db_user prove -lv t/delete-genomes.t

=head1 DESCRIPTION

Tests for Data/delete_genome.pl script.

Requires environment variable SUPERPHY_CONFIGFILE to provide DB connection parameters. A production DB is ok,
no changes are made to the DB.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use Test::More;
use Test::Exception;
use FindBin;
use lib "$FindBin::Bin/../";
use lib "$FindBin::Bin/lib/";
use IO::CaptureOutput qw(capture_exec);
use t::lib::PipelineT;
use t::lib::App;
use TestPostgresDB;
use Test::DBIx::Class {
	schema_class => 'Database::Chado::Schema',
	deploy_db => 0,
	keep_db => 1,
	traits => [qw/TestPostgresDB/]
}, 'Feature', 'PrivateFeature';

my $public_genome;
my $private_genome;
my $private_genome_submitter;
my $config_file;
use constant VERIFY_TMP_TABLE => "SELECT count(*) FROM pg_class WHERE relname=? and relkind='r'";

# Run deletion on public genome
subtest 'Run delete_genome.pl script' => sub {

	my $cgiapp;
	my $cleanup_dir = 0;
	lives_ok { $cgiapp = t::lib::App::launch(Schema, $cleanup_dir) } 'Test::WWW::Mechanize::CGIApp initialized';
	BAIL_OUT('CGIApp initialization failed') unless $cgiapp;

	my $config_file = $ENV{SUPERPHY_CONFIGFILE};
	ok($config_file, "Retrieved config file");
	diag("Config file: ".$config_file);
	
	# Identify public genome for deletion
	my $public_rs = Feature->search(
		{
			'type.name' => 'contig_collection'
		},
		{
			join => ['type'],
			rows => 1
		}
	);
	ok $public_genome = $public_rs->first->feature_id, "Found public test genome";
	$public_genome = 'public_' . $public_genome;
	diag "Public genome: ".$public_genome;
	
	# Identify private genome for deletion
	my $private_rs = PrivateFeature->search(
		{
			'type.name' => 'contig_collection'
		},
		{
			join => [
				'type',
				{ 'upload' => 'login' }
	      	],
			rows => 1
		}
	);
    my $private_row = $private_rs->first;
	ok $private_genome = $private_row->feature_id, "Found private test genome";
	$private_genome = 'private_' . $private_genome;
	$private_genome_submitter = $private_row->upload->login->username;
	diag "Private genome: ".$private_genome;
	diag "Submitter: ".$private_genome_submitter;

	# Run deletion script on public genome
	my $perl_interpreter = $^X;
	my @args = (
		"$perl_interpreter $FindBin::Bin/../Data/delete_genome.pl",
		"--genome $public_genome",
		"--config $config_file",
		"--test"
	);
	my $cmd = join(' ', @args);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	diag $cmd;

	ok($success, "Deletion of public genome completed") or
		BAIL_OUT("Deletion of public genome failed ($stderr)");

	# Run deletion script on public genome
	@args = (
		"$perl_interpreter $FindBin::Bin/../Data/delete_genome.pl",
		"--genome $private_genome",
		"--config $config_file",
		"--test"
	);
	$cmd = join(' ', @args);
	($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	diag $cmd;

	ok($success, "Deletion of private genome completed") or
		BAIL_OUT("Deletion of private genome failed ($stderr)");
	
};

subtest 'Confirm deletion' => sub {

	db_scan($public_genome) if $public_genome;

	db_scan($private_genome) if $private_genome;

};


done_testing();


##########
##  SUBS
##########

# Scour DB for the feature
# to confirm its removal
sub db_scan {
	my $genome_label = shift;

	my $genome_id = -1;
	my $pub = -1;

	if($genome_label =~ m/private_(\d+)/) {
		$genome_id = $1;
		$pub = 0;
	}
	elsif($genome_label =~ m/public_(\d+)/) {
		$genome_id = $1;
		$pub = 1;
	}
	else {
		die "Error: invalid genome name $genome_label.\n";
	}

	my %common_tables_and_columns = (
		Feature => [qw/
			feature_id
		/],
		FeatureRelationship => [qw/
			subject_id
			object_id
		/],
		FeatureCvterm => [qw/
			feature_id
		/],
		FeatureGroup => [qw/
			feature_id
		/],
		FeatureDbxref => [qw/
			feature_id
		/],
		FeatureTree => [qw/
			feature_id
		/],
		Featureprop => [qw/
			feature_id
		/],
		Featureloc => [qw/
			feature_id
			srcfeature_id
		/],
		GenomeLocation => [qw/
			feature_id
		/],
		GapPosition => [qw/
			contig_id
			contig_collection_id
			locus_id
		/],
		SnpPosition => [qw/
			contig_id
			contig_collection_id
			locus_id
		/],
		SnpVariation => [qw/
			contig_id
			contig_collection_id
			locus_id
		/]

	);

	my %public_tables_and_columns = (
		ContigFootprint => [qw/
			feature_id
		/],
		FeatureSynonym => [qw/
			feature_id
		/],
		PubpriFeatureRelationship => [qw/
			subject_id
		/],
		PripubFeatureRelationship => [qw/
			object_id
		/],
	);

	my %private_tables_and_columns = (
		PubpriFeatureRelationship => [qw/
			object_id
		/],
		PripubFeatureRelationship => [qw/
			subject_id
		/],
	);

	my %cache_tables_and_columns = (
		TmpAlleleCache => [qw/
			genome_id
		/],
		TmpGffLoadCache => [qw/
			feature_id
		/],
		TmpLociCache => [qw/
			genome_id
		/]
	);

	my %alignment_tables_and_columns = (
		PangenomeAlignment => [qw/
			name
		/],
		SnpAlignment => [qw/
			name
		/],
	);

	my %upload_tables_and_columns = (
		Upload => [qw/
			upload_id
		/],
		PrivateFeature => [qw/
			upload_id
		/],
		PrivateFeatureprop => [qw/
			upload_id
		/],
		Permission => [qw/
			upload_id
		/],
	);


	my $found = 0;
	
	foreach my $table (keys %common_tables_and_columns) {

		my @cols = @{$common_tables_and_columns{$table}};
		$table = 'Private' . $table unless $pub;

		foreach my $col (@cols) {
			my $result = ResultSet($table, { $col => $genome_id });
			if($result->first) {
				diag "Found genome $genome_label in $table.$col. Not deleted.";
				$found = 1;
			}
		}
	}

	if($pub) {
		foreach my $table (keys %public_tables_and_columns) {
			my @cols = @{$public_tables_and_columns{$table}};

			foreach my $col (@cols) {
				my $result = ResultSet($table, { $col => $genome_id });
				if($result->first) {
					diag "Found genome $genome_label in $table.$col. Not deleted.";
					$found = 1;
				}
			}
		}
	}

	foreach my $table (keys %alignment_tables_and_columns) {
		my @cols = @{$alignment_tables_and_columns{$table}};

		foreach my $col (@cols) {
			my $result = ResultSet($table, { $col => $genome_label });
			if($result->first) {
				diag "Found $genome_label genome in $table.$col. Not deleted.";
				$found = 1;
			}
		}
	}

	my $dbh = Schema->storage->dbh;
	my $sth = $dbh->prepare(VERIFY_TMP_TABLE);
	foreach my $table (keys %cache_tables_and_columns) {

		$sth->execute($table);
		my ($exists) = $sth->fetchrow_array();
		if($exists) {
			my @cols = @{$cache_tables_and_columns{$table}};

			foreach my $col (@cols) {
				my $result = ResultSet($table, { $col => $genome_id, pub => $pub });
				if($result->first) {
					diag "Found $genome_label genome in $table.$col. Not deleted.";
					$found = 1;
				}
			}
		}
	}

	ok(!$found, "Genome $genome_label removed from DB");
	
}

# Scour supporting precomputed data files for genome
# to verify its removal
sub fs_scan {
	my $genome_label = shift;

	my $genome_id = -1;
	my $pub = -1;

	if($genome_label =~ m/private_(\d+)/) {
		$genome_id = $1;
		$pub = 0;
	}
	elsif($genome_label =~ m/public_(\d+)/) {
		$genome_id = $1;
		$pub = 1;
	}
	else {
		die "Error: invalid genome name $genome_label.\n";
	}

	# Tree object
	tree_doesnt_contain(Schema, $genome_id, "Genome $genome_label removed from global tree", $pub);

	# Metadata JSON object
	my ($user) = ($pub ? undef : $private_genome_submitter);
	metadata_doesnt_contain(Schema, $genome_id, "Genome $genome_label removed from meta_data JSON object", $user, $pub);

	# Shiny RData file
	#shiny_rdata_doesnt_contain($genome_label, "Genome $genome_label removed from meta_data JSON object");
}