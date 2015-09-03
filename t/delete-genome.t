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
my $config_file;

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
	# my $private_rs = PrivateFeature->search(
	# 	{
	# 		'type.name' => 'contig_collection'
	# 	},
	# 	{
	# 		join => ['type'],
	# 		rows => 1
	# 	}
	# );
	# ok $private_genome = $private_rs->first->feature_id, "Found private test genome";
	# $private_genome = 'private' . $private_genome;
	# diag "Private genome: ".$private_genome;

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
	
};


done_testing();


