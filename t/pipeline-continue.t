#!/usr/bin/env perl

=pod

=head1 NAME

t::pipeline-continue.t

=head1 DESCRIPTION

Running t/pipeline.t with option keep_db => 1 creates test database. This script
can be used to connect an existing database and run the pipeline tests.

By default, this script will connect to a database named 'genodo'. To change the database
name, use environmental variable 'DBNAME'. E.g.

  DBNAME=testdbname prove t/pipeline-continue.t

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
use TestPgConnection;
use t::lib::App;
use Config::Simple;
use File::Temp qw/tempdir/;
use IO::CaptureOutput qw(capture_exec);
use t::lib::PipelineT;
use Test::DBIx::Class {
	schema_class => 'Database::Chado::Schema',
	deploy_db => 0,
	traits => [qw/TestPgConnection/],
	keep_db => 1,
}, 'PrivateFeature', 'PrivateFeatureprop','Cvterm', 'Login', 'Tracker';


# Create test CGIApp and work environment
my $cgiapp;
lives_ok { $cgiapp = t::lib::App::relaunch(Schema) } 'Test::WWW::Mechanize::CGIApp initialized';
BAIL_OUT('CGIApp initialization failed') unless $cgiapp;

# Retrieve feature ID for uploaded genome
ok(my $genome_row = genome_feature(PrivateFeature, genome_name()), 'Find genome in private_feature table');

# Make sure all genome properties match original submission
cmp_genome_properties(Schema, $genome_row->feature_id, upload_form(), 'Check genome properties in DB');

# Check tree
tree_contains(Schema, $genome_row->feature_id, 'Find genome in global phylogenetic tree');

# Check meta-data
metadata_contains(Schema, $genome_row->feature_id, 'testbot', 'Find genome in user\'s private meta-data JSON object');

# Retrieve needed data
my $login_id = Login->find({ username => 'testbot' })->login_id;


# Check genes

# Locate Panseq pan_genome.txt file
my $current_sandbox = sandbox_directory();
my $jobid = 
my $gene_panseq_file = "$current_sandbox/new_genomes/$job_id/vf/panseq_vf_amr_results/pan_genome.txt";
ok(-e $gene_panseq_file, "Panseq VF/AMR pan_genome.txt file found");


# Check pangenome


done_testing();

########
## SUBS
########
