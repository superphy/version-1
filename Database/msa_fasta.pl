#!/usr/bin/env perl 
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;


=head1 NAME

$0 - Downloads all gene allele MSA fasta sequences. 

=head1 SYNOPSIS

  msa_fasta.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.
 --msa            Specify a file to print the fasta sequences to.

=head1 DESCRIPTION

This script will download the MSA alignment strings in fasta format for a experimental 
features in the database; public or private.

Sequences will have the header:
>[public|private]_contig_collection_feature_id|allele_feature_id|query_gene_feature_id

=head1 AUTHOR

Matt Whiteside

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $OUTPUT);

GetOptions(
	'config=s'  => \$CONFIG,
	'msa=s'	=> \$OUTPUT,
) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
croak "Missing argument. You must supply an output file.\n" . system ('pod2text', $0) unless $OUTPUT;
if(my $db_conf = new Config::Simple($CONFIG)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
} 
else {
	die Config::Simple->error();
}

my $dbsource = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dbsource . ';port=' . $DBPORT if $DBPORT;

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS) or croak "Could not connect to database.";

# Obtain all public genes
my $allele_rs = $schema->resultset('Feature')->search(
	{
        'type.name' => "allele",
        'type_2.name' => "similar_to",
        'type_3.name' => "part_of",
	},
	{
		columns   => [qw/feature_id residues md5checksum/],
		'+select' => [qw/feature_relationship_subjects.object_id feature_relationship_subjects_2.object_id/],
		'+as'     => [qw/query_gene contig_collection/],
		join      => 
			[
				'type', 
				{'feature_relationship_subjects' => 'type'},
				{'feature_relationship_subjects' => 'type'}
			],
		order_by => ['feature_id']
	}
);

my $allele_rs2 = $schema->resultset('PrivateFeature')->search(
	{
        'type.name' => "allele",
        'type_2.name' => "similar_to",
        'type_3.name' => "part_of",
	},
	{
		columns   => [qw/feature_id residues/],
		'+select' => [qw/private_feature_relationship_subjects.object_id private_feature_relationship_subjects_2.object_id/],
		'+as'     => [qw/query_gene contig_collection/],
		join      => 
			[
				'type', 
				{'private_feature_relationship_subjects' => 'type'},
				{'private_feature_relationship_subjects' => 'type'}
			],
		order_by => ['feature_id']
	}
);

# Group alleles by query gene
my %alleles;
while(my $allele = $allele_rs->next) {
	
	my $a_id = $allele->feature_id;
	my $seq = $allele->residues;
	my $cc_id = $allele->get_column('contig_collection');
	my $qg_id = $allele->get_column('query_gene');
	
	$alleles{$qg_id}{$a_id} =  {
		genome => 'public_'.$cc_id,
		seq => $seq
	}
}
while(my $allele = $allele_rs2->next) {
	
	my $a_id = $allele->feature_id;
	my $seq = $allele->residues;
	my $cc_id = $allele->get_column('contig_collection');
	my $qg_id = $allele->get_column('query_gene');
	
	$alleles{$qg_id}{$a_id} =  {
		genome => 'private_'.$cc_id,
		seq => $seq
	}
}

# Print out FASTA files
$OUTPUT .= '/' unless $OUTPUT =~ m/\/$/;
foreach my $query_gene (keys %alleles) {
	
	my $query_file = $OUTPUT . $query_gene . '.ffn';
	
	open(my $out, ">", $query_file) or die "[Error] unable to write to file $query_file ($!).\n";
	
	foreach my $allele_gene (keys %{$alleles{$query_gene}}) {
		my $allele_hash = $alleles{$query_gene}{$allele_gene};
		
		print $out '>' . $allele_hash->{genome} . '|' . $allele_gene . '|' . $query_gene . "\n" 
			. $allele_hash->{seq} ."\n";
	}
	
	close $out;	
}
