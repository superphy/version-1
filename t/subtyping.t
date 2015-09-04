#!/usr/bin/env perl

=pod

=head1 NAME

t::subtyping.t

=head1 SNYNOPSIS



=head1 DESCRIPTION

Tests the Stx subtyping methods in ExperimentalFeatures.pm

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
use List::MoreUtils qw(all);
use Sequences::ExperimentalFeatures;
use lib "$FindBin::Bin/lib/";
use App;
use TestPostgresDB;
use Test::DBIx::Class {
	schema_class => 'Database::Chado::Schema',
	deploy_db => 0,
	keep_db => 0,
	traits => [qw/TestPostgresDB/]
}, 'Feature', 'PrivateFeature';

# Create test CGIApp and work environment
my $cgiapp;
my $cleanup_dir = 1;
lives_ok { $cgiapp = t::lib::App::launch(Schema, $cleanup_dir) } 'Test::WWW::Mechanize::CGIApp initialized';
BAIL_OUT('CGIApp initialization failed') unless $cgiapp;


my $config_file = $ENV{SUPERPHY_CONFIGFILE};
ok($config_file, "Retrieved config file");
diag("Config file: ".$config_file);

my $chadoObj = new_ok ('Sequences::ExperimentalFeatures' => [
		config => $config_file,
		feature_type => 'vfamr',
		assign_groups => 1,
	]
);

# Test data

# Locate Stx1 subunit genes
my $stx1_rs = Feature->search(
	{
		uniquename => 'stx1_subunit',
		'type.name' => 'fusion_of' 
	},
	{
		join => {'feature_relationship_subjects' => 'type' },
		'+columns' => [
			qw'feature_relationship_subjects.subject_id feature_relationship_subjects.object_id feature_relationship_subjects.rank'
		]
	}
);

is_resultset($stx1_rs);

my @reference_stx1_genes = (undef, undef);
while(my $stx1_row = $stx1_rs->next) {

	my $stx1_su_rs = $stx1_row->feature_relationship_subjects;

	while(my $stx1_su_row = $stx1_su_rs->next) {
		my $unit = $stx1_su_row->rank;
		my $gene_id = $stx1_su_row->object_id;
		$reference_stx1_genes[$unit] = $gene_id;
	}
}

my @stx1_alleles = (
	{
		genome => 1,
		allele => 3,
		header => 'placeholder',
		contig => 2,
		public => 0,
		is_new => 1,
		seq => 'ATGAAAATAATTATTTTTAGAGTGCTAACTTTTTTCTTTGTTATCTTTTCAGTTAATGTGGTGGCGAAGGAATTTACCTTAGACTTCTCGACTGCAAAGACGTATGTAGATTCGCTGAATGTCATTCGCTCTGCAATAGGTACTCCATTACAGACTATTTCATCAGGAGGTACGTCTTTACTGATGATTGATAGTGGCACAGGGGATAATTTGTTTGCAGTTGATGTCAGAGGGATAGATCCAGAGGAAGGGCGGTTTAATAATCTACGGCTTATTGTTGAACGAAATAATTTATATGTGACAGGATTTGTTAACAGGACAAATAATGTTTTTTATCGCTTTGCTGATTTTTCACATGTTACCTTTCCAGGTACAACAGCGGTTACATTGTCTGGTGACAGTAGCTATACCACGTTACAGCGTGTTGCAGGGATCAGTCGTACGGGGATGCAGATAAATCGCCATTCGTTGACTACTTCTTATCTGGATTTAATGTCGCATAGTGGAACCTCACTGACGCAGTCTGTGGCAAGAGCGATGTTACGGTTTGTTACTGTGACAGCTGAAGCTTTACGTTTTCGGCAAATACAGAGGGGATTTCGTACAACACTGGATGATCTCAGTGGGCGTTCTTATGTAATGACTGCTGAAGATGTTGATCTTACATTGAACTGGGGAAGGTTGAGTAGCGTCCTGCCTGACTATCATGGACAAGACTCTGTTCGTGTAGGAAGAATTTCTTTTGGAAGCATTAATGCAATTCTGGGAAGCGTGGCATTAATACTGAATTGTCATCATCATGCATCGCGAGTTGCCAGAATGGCATCTGATGAGTTTCCTTCTATGTGTCCGGCAGATGGAAGAGTCCGTGGGATTACGCACAATAAAATATTGTGGGATTCATCCACTCTGGGGGCAATTCTGATGCGCAGAACTATTAGCAGTTGA'
	},
	{
		genome => 1,
		allele => 4,
		header => 'placeholder',
		contig => 2,
		public => 0,
		is_new => 1,
		seq => 'ATGAAAAAAACATTATTAATAGCTGCATCGCTTTCATTTTTTTCAGCAAGTGCGCTGGCGACGCCTGATTGTGTAACTGGAAAGGTGGAGTATACAAAATATAATGATGACGATACCTTTACAGTTAAAGTGGGTGATAAAGAATTATTTACCAACAGATGGAATCTTCAGTCTCTTCTTCTCAGTGCGCAAATTACGGGGATGACTGTAACCATTAAAACTAATGCCTGTCATAATGGAGGGGGATTCAGCGAAGTTATTTTTCGTTGA'
	}
);
my $all_there = all { defined($_) } @reference_stx1_genes;
ok( $all_there, "Found Stx1 subunit reference genes");

# Locate Stx2 subunit genes
my $stx2_rs = Feature->search(
	{
		uniquename => 'stx2_subunit',
		'type.name' => 'fusion_of' 
	},
	{
		join => {'feature_relationship_subjects' => 'type' },
		'+columns' => [
			qw'feature_relationship_subjects.subject_id feature_relationship_subjects.object_id feature_relationship_subjects.rank'
		]
	}
);

is_resultset($stx2_rs);

my @reference_stx2_genes = (undef, undef);
while(my $stx2_row = $stx2_rs->next) {

	my $stx2_su_rs = $stx2_row->feature_relationship_subjects;

	while(my $stx2_su_row = $stx2_su_rs->next) {
		my $unit = $stx2_su_row->rank;
		my $gene_id = $stx2_su_row->object_id;
		$reference_stx2_genes[$unit] = $gene_id;
	}
}

my @stx2_alleles = (
	{
		genome => 1,
		allele => 5,
		header => 'placeholder',
		contig => 2,
		public => 0,
		is_new => 1,
		seq => 'ATGAAGTGTATATTGTTTAAATGGGTACTGTGCCTGTTACTGGGCTTTTCTTCGGTATCCTATTCCCGGGAATTTACGATAGACTTTTCGACTCAACAAAGTTATGTATCTTCGTTAAATAGTATACGGACAGAGATATCGACCCCTCTTGAACACATATCTCAGGGGACCACATCGGTGTCTGTTATTAACCACACCCCACCGGGAAGTTATTTTTCTGTGGATATACGAGGGCTTGATGTCTATCAGGCGCG-TTTTGACCATCTTCGTCTGATTATTGAGCAAAATAATTTATATGTGGCCGGGTTCGTTAATACGGCAACAAATACTTTCTACAGATTTTCAGATTTTACACATATATCAGTGCCCGGTGTGACAACGGTTTCCATGACAACGGACAGCAGTTATACCACTCTGCAACGTGTCGCAGCGCTGGAACGTTCCGGAATGCAAATCAGTCGTCACTCACTGGTTTCATCATATCTGGCGTTAATGGAGTTCAGTGGTAATACAATGACCAGAGATGCATCCAGAGCAGTTCTGCGTTTTGTCACTGTCACAGCAGAAGCCTTACGCTTCAGGCAGATACAGAGAGAATTTCGTCAGGCACTGTCTGAAACTGCTCCTGTGTATACGATGACGCCGGG-AGACGTGGACCTCACTCTGAACTGGGGGCGAATCAGCAATGTGCTT-CCGGAGTATCAGGGAGAGGATGGTGTCAGAGTGGGGAGAATATCCTTTAATAATATATCGGCGATACTGGGCACTGTGGCCGTTATACTGAATTGTCATCATCA-GGGGGCGCGTTCTGTTCGCGCCGTGAATGAAGATAGTCAACCAGAATGTCAGATAACTGGCGACAGG-CCAGTTATAAAAATAAACAATACATTATGGGAAAGTAATACAGCAGCAGCGTTTCTGAACAGAAAGTCACAGTCTTTATATACAACGGGTGAATAA'
	},
	{
		genome => 1,
		allele => 6,
		header => 'placeholder',
		contig => 2,
		public => 0,
		is_new => 1,
		seq => 'ATGAAGAAGATGTTTATGGCGGTTTTATTTGCATTAGTTTCTGTTAATGCAATGGCGGCGGATTGTGCTAAAGGTAAAATTGAGTTTTCCAAGTATAATGAGAACGATACATTCACAGTAAAAGTGGCCGGGAAAGAGTACTGGACTAACCGCTGGAATCTGCAACCGCTACTGCAAAGTGCACAGTTAACAGGAATGACAGTCACAATCAAGTCCAGTACCTGTGCATCAGGCTCCGGATTTGCTGAAGTGCAGTTTAATAATGACTGA'
	}
);
my $all_there = all { defined($_) } @reference_stx2_genes;
ok( $all_there, "Found Stx2 subunit reference genes");


# Record Stx1 alleles
for(my $i = 0; $i < 2; $i++) {
	my $query_gene_id = $reference_stx1_genes[$i];

	if($chadoObj->is_typing_sequence($query_gene_id)) {
		$chadoObj->record_typing_sequences($query_gene_id, $stx1_alleles[$i]);
	}
}

# Record Stx2 alleles
for(my $i = 0; $i < 2; $i++) {
	my $query_gene_id = $reference_stx2_genes[$i];

	if($chadoObj->is_typing_sequence($query_gene_id)) {
		$chadoObj->record_typing_sequences($query_gene_id, $stx2_alleles[$i]);
	}
}

# Perform typing
lives_ok { $chadoObj->typing($chadoObj->tmp_dir()) } 'Peform Stx subtyping';

# Check results


done_testing();