#!/usr/bin/env perl

use strict;
use warnings;
use Bio::SeqIO;
use Getopt::Long;
use Pod::Usage;
use Carp;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;

=head1 NAME

$0 - Upload AMR genes and associated meta-data from CARD

=head1 SYNOPSIS

  % ar_genes_db_uploader [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.
 --fasta          AMR fasta file from the CARD download page.

=head1 DESCRIPTION

This script creates feature entries in the CHADO db for antimicrobial resistance
genes defined by the CARD database. Requires that the Antimicrobial resistance
ontology from the CARD db has been previously loaded (See script ../Database/genodod_add_aro.sh).

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $FASTAFILE);

GetOptions(
    'config=s'      => \$CONFIG,
    'fasta=s'       => \$FASTAFILE,
) or ( system( 'pod2text', $0 ), exit -1 );

croak "ERROR: Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
croak "ERROR: Missing argument. You must supply a fasta filename.\n" . system ('pod2text', $0) unless $FASTAFILE;

# Connect to DB and gen schema object
if(my $db_conf = new Config::Simple($CONFIG)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
} else {
	die Config::Simple->error();
}

my $dbsource = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dbsource . ';port=' . $DBPORT if $DBPORT;

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS) or croak "ERROR: Could not connect to database.";

# Add/check dummy organism
my $default_organism_row = $schema->resultset('Organism')->find_or_create(
	{
		genus => 'Unclassifed',
		species => 'Unclassifed',
		comment => 'A place-holder organism entry to represent features with no associated organism'
	},
	{
		key => 'organism_c1'
	}
);
my $organism_id = $default_organism_row->organism_id;

# Retrieve common cvterm IDs
# hash: name => cv
my %fp_types = (
	description => 'feature_property',
	synonym => 'feature_property',
	antimicrobial_resistance_gene => 'local',
	source_organism => 'local',
	publication => 'local',
);

my %cvterm_ids;
foreach my $type (keys %fp_types) {
	my $cv = $fp_types{$type};
	my $type_rs = $schema->resultset('Cvterm')->search(
		{
			'me.name' => $type,
			'cv.name' => $cv
		},
		{
			join => 'cv',
			columns => qw/cvterm_id/
		}
	);
	my $type_row = $type_rs->first;
	croak "Featureprop cvterm type $type not in database." unless $type_row;
	my ($cvterm_id) = $type_row->cvterm_id;
	$cvterm_ids{$type} = $cvterm_id;
}

# Add/check required pub
my $default_pub_rs = $schema->resultset('Pub')->find_or_create(
	{
		uniquename => 'The Comprehensive Antibiotic Resistance Database',
		miniref => q|McArthur AG, et al. The comprehensive antibiotic
resistance database. Antimicrob Agents Chemother. 2013 Jul;57(7):3348-57. doi:
10.1128/AAC.00419-13. Epub 2013 May 6. PubMed PMID: 23650175; PubMed Central
PMCID: PMC3697360|,
		type_id => $cvterm_ids{publication},
	},
	{
		key => 'pub_c1'
	}
);
my $pub_id = $default_pub_rs->pub_id;

# Add/check required db
my $default_db_rs = $schema->resultset('Db')->find_or_create(
	{
		name => 'CARD',
		description => 'The Comprehensive Antibiotic Resistance Database',
	},
	{
		key => 'db_c1'
	}
);
my $db_id = $default_db_rs->db_id;

# Retrieve common dbs
my $db_row = $schema->resultset('Db')->find({ name => 'ARO'});
my $aro_db_id = $db_row->db_id;
croak "ERROR: Antimicrobial resistance ontology database (ARO) not found in db table.\n" unless $aro_db_id;


# Add AR genes in fasta file
my $in = Bio::SeqIO->new(-file   => $FASTAFILE,
                         -format => 'fasta');

my $num_proc=0;                             
while (my $entry = $in->next_seq) {
	
	# Attempt to load single sequence.
	# If it fails, load step for gene will be rolled back
	$schema->txn_do(\&load_gene, $entry);
	
	$num_proc++;
	print "$num_proc loaded\n" if $num_proc % 100 == 0;
	
}
print "$num_proc loaded\n";

sub load_gene {
	my ($fasta_seq) = @_;
	
	my $card_accession = $fasta_seq->display_id;
	
	# Parse header, isolating key segments
	my ($header, $organism) = ($fasta_seq->desc =~ m/^(.+) \[(.+)\]$/);
	$header =~ s/E\. col/E\.col/g;
	my @columns = split(/\. /, $header); # Hopefully this is safe, header delimiting is really poor (. appear in words too!)
	my @ontology_annos;
	my @synonyms;
	my @descriptions;
	my $name = shift @columns;
	
	# Check if sequence is in database
	my $uniquename = "$name ($card_accession)";
	
	unless($schema->resultset('Feature')->find({uniquename => $uniquename})) {
		
		# Parse rest of header
		while(my $col_entry = pop @columns) {
			if($col_entry =~ m/ARO\:/) {
				next if $col_entry =~ m/ARO:1000001/; # Don't need to record term as being a part of the ARO ontology
				push @ontology_annos, $col_entry;
			} elsif($col_entry =~ m/\s|QUINOLONE/ || length($col_entry) > 10) {
				# Descriptions are longer strings often with spaces
				# This is what we have to resort to due to a poor FASTA header specification
				push @descriptions, $col_entry;
				
			} else {
				push @synonyms, $col_entry;
			}
		}
		
		# Create/retrieve organism
		# Store this as a featureprop, there isnt a good
		# system in the organism table for storing strain info
		# which is essential for identifying bacteria.
		# Currently all AR gene organisms are stored as 'Unclassified'
		# but this should be safe as they should all have uniquenames
		# and unique accessions with no collisions between the different
		# 'Unclassified' species.
		
		# Create/retrieve dbxref
		my $dbxref = $schema->resultset('Dbxref')->find_or_create(
			{
				accession => $card_accession,
				version => '',
				db_id => $db_id
			},
			{
				key => 'dbxref_c1'
			}
		);
		
		# Create feature
		my $feature = $schema->resultset('Feature')->create(
			{
				organism_id => $organism_id,
				dbxref_id => $dbxref->dbxref_id,
				name => $name,
				uniquename => $uniquename,
				residues => $fasta_seq->seq(),
				seqlen => $fasta_seq->length(),
				type_id => $cvterm_ids{antimicrobial_resistance_gene}
			}
		);
		
		# Create feature_cvterms for ARO terms
		my $rank=0;
		foreach my $term (@ontology_annos) {
			my ($acc) = ($term =~ m/ARO\:(\d+)/);
			
			# find cvterm matching the ARO temr
			my $term_rs = $schema->resultset('Cvterm')->search(
				{
					'dbxref.accession' => $acc,
					'dbxref.db_id' => $aro_db_id,
				},
				{
					join => 'dbxref'
				}
			);
			
			my @matching = $term_rs->all;
			die "ERROR: ARO term ARO:$acc not found in dbxref table." unless @matching;
			die "ERROR: Multiple ARO terms matching ARO:$acc found in cvterm table." unless @matching == 1;
			
			my $term = shift @matching;
			
			$schema->resultset('FeatureCvterm')->create(
				{
					feature_id => $feature->feature_id,
					cvterm_id => $term->cvterm_id,
					pub_id => $pub_id,
					rank => $rank
				}
			);
			
			$rank++;
			
		}
		
		# Create featureprops
		
		# Add source organism property
		$schema->resultset('Featureprop')->create(
			{
				feature_id => $feature->feature_id,
				type_id => $cvterm_ids{source_organism},
				value => $organism,
				rank => 0
			}
		);
		
		# Add description properties
		$rank = 0;
		foreach my $d (@descriptions) {
			$schema->resultset('Featureprop')->create(
				{
					feature_id => $feature->feature_id,
					type_id => $cvterm_ids{description},
					value => $d,
					rank => $rank
				}
			);
			$rank++;
		}
		
		# Add synonym properties
		$rank = 0;
		foreach my $s (@synonyms) {
			$schema->resultset('Featureprop')->create(
				{
					feature_id => $feature->feature_id,
					type_id => $cvterm_ids{synonym},
					value => $s,
					rank => $rank
				}
			);
			$rank++;
		}
		
	}
	
}
