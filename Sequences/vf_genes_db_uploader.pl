#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use IO::File;
use IO::Dir;
use Bio::SeqIO;
use FindBin;
use lib "$FindBin::Bin/../";
use Config::Simple;
use Database::Chado::Schema;
use Carp qw/croak carp/;

=head1 NAME

	$0 - Upload VF genes and associated meta-data from VFDB and newly compiled (in-house) list of VF genes.

=head1 SYNOPSIS

	%  vf_genes_db_uploader [options]

=head1 COMMAND-LINE OPTIONS 

	--config 	Sepcify a .conf containing DB connection parameters.
	--fasta		VF fasta file (Should be in Sequences folder).

=head1 DESCRIPTION

This script creates feature entries in the CHADO db for virulence factors deifned by VFDB and a combination of in-house identified genes. Requires that the virulence factor ontology (VFO) has previously been loaded.

=head1 AUTHOR

Akiff Manji akiff.manji@gmail.com

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBPASS, $DBHOST, $DBPORT, $DBI, $FASTAFILE);

GetOptions(
	'config=s'	=> \$CONFIG,
	'fasta=s'	=> \$FASTAFILE,
	) or ( system( 'pod2text', $0 ), exit -1 );


croak "ERROR: Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
croak "ERROR: Missing argument. You must supply a fasta filename.\n" . system ('pod2text', $0) unless $FASTAFILE;

#Connect to DB and generate schema object
if (my $db_conf = new Config::Simple($CONFIG)) {
	$DBNAME = $db_conf->param('db.name');
	$DBUSER = $db_conf->param('db.user');
	$DBPASS = $db_conf->param('db.pass');
	$DBHOST = $db_conf->param('db.host');
	$DBPORT = $db_conf->param('db.port');
	$DBI = $db_conf->param('db.dbi');
} 
else {
	die Config::Simple->error();
}

my $dbsource  = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dbsource . ';port=' . $DBPORT if $DBPORT;

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS) or croak "ERROR: Could not connect to database.";

#Get Organism ID for E.coli
my $organism_row = $schema->resultset('Organism')->find({
	genus => 'Escherichia',
	species => 'coli'
	});

my $organism_id = $organism_row->organism_id;

# Retrieve common cvterm IDs
# hash: name => cv
my %fp_types = (
	description => 'feature_property',
	synonym => 'feature_property',
	virulence_factor => 'local',
	source_organism => 'local',
	publication => 'local',
	uniquename => 'feature_property',
	virulence_id => 'feature_property',
	keywords => 'feature_property',
	mol_type => 'feature_property',
	plasmid => 'feature_property',
	organism => 'feature_property',
	strain => 'local',
	biological_process => 'feature_property'
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

# Add/Check required pub
my $default_pub_rs = $schema->resultset('Pub')->find_or_create(
{
	uniquename => 'Virulence Factor Database',
	miniref => 'http://www.mgc.ac.cn/cgi-bin/VFs/genus.cgi?Genus=Escherichia',
	type_id => $cvterm_ids{publication},
	},
	{
		key =>'pub_c1'
	}
	);

my $pub_id = $default_pub_rs->pub_id;

#Add/Check required db
my $default_db_rs = $schema->resultset('Db')->find_or_create(
{
	name => 'VFDB',
	description => 'Virulence Factor Database',
	},
	{
		key => 'db_c1'
	}
	);

my $db_id = $default_db_rs->db_id;

#Retrieve common dbs
my $db_row = $schema->resultset('Db')->find({name => 'VFO'});
my $vfo_db_id = $db_row->db_id;
croak "ERROR: Virulence factor database (VFO) not found in db table\n" unless $vfo_db_id;

# Add VF genes in fasta file
my $in = Bio::SeqIO->new(-file => $FASTAFILE,
	-fasta => 'fasta');

my $num_proc = 0;
while (my $entry = $in->next_seq) {
	my $seqId = $entry->id();
	my $seqHeader = $entry->desc();
	my $headerAttrs = parseHeader($seqId , $seqHeader);
	$schema->txn_do(\&load_gene, $entry, $headerAttrs);
	$num_proc++;
	print "$num_proc loaded\n" if $num_proc % 100 == 0;
}

print "$num_proc loaded\n";

sub load_gene {
	my ($fasta_seq, $_headerAttrs) = @_;

	#Create/retrieve dbxref
	my $dbxref = $schema->resultset('Dbxref')->find_or_create(
	{
		accession => $_headerAttrs->{'VIRULENCE_ID'},
		version => '',
		db_id => $db_id
		},
		{
			key => 'dbxref_c1'
		}
		);

	#Create feature
	my $feature = $schema->resultset('Feature')->create(
	{
		organism_id => $organism_id,
		dbxref_id => $dbxref->dbxref_id,
		name => $_headerAttrs->{'NAME'},
		uniquename => $_headerAttrs->{'UNIQUENAME'},
		residues => $fasta_seq->seq(),
		seqlen => $fasta_seq->length(),
		type_id => $cvterm_ids{virulence_factor}
	}
	);

	#Create feature_cvterms for VFO terms
	my $rank = 0;
	my $accessionIds = $_headerAttrs->{'VFOID'};
	foreach my $accId (@$accessionIds) {
		$accId =~ s/VFO://;
		my $term_rs = $schema->resultset('Cvterm')->search(
		{
			'dbxref.accession' => $accId,
			'dbxref.db_id' => $vfo_db_id,
			},
			{
				join => 'dbxref'
			}
			);
		my @matching = $term_rs->all;
		die "ERROR: VFO term VFO:$accId not found in dbxref table." unless @matching;
		die "ERROR: Multiple VFO terms matching VFO:accId found in cvterm table." unless @matching == 1;

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

	# Add FeatureProps:

	# uniquename
	if ($_headerAttrs->{'UNIQUENAME'}) {
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{uniquename},
			value => $_headerAttrs->{'UNIQUENAME'},
			rank => 0
		}
		);
	}

	# virulence_id
	if ($_headerAttrs->{'VIRULENCE_ID'}) {
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{virulence_id},
			value => $_headerAttrs->{'VIRULENCE_ID'},
			rank => 0
		}
		);
	}

	# keywords
	if ($_headerAttrs->{'KEYWORDS'}) {
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{keywords},
			value => $_headerAttrs->{'KEYWORDS'},
			rank => 0
		}
		);
	}

	# mol_type
	if ($_headerAttrs->{'MOLTYPE'}) {
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{mol_type},
			value => $_headerAttrs->{'MOLTYPE'},
			rank => 0
		}
		);
	}

	# plasmid
	if ($_headerAttrs->{'PLASMID'}) {
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{plasmid},
			value => $_headerAttrs->{'PLASMID'},
			rank => 0
		}
		);
	}

	# organism
	if ($_headerAttrs->{'ORGANISM'}) {
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{organism},
			value => $_headerAttrs->{'ORGANISM'},
			rank => 0
		}
		);
	}

	# strain
	if ($_headerAttrs->{'STRAIN'}) {
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{strain},
			value => $_headerAttrs->{'STRAIN'},
			rank => 0
		}
		);
	}

	# biological_process
		$schema->resultset('Featureprop')->create(
		{
			feature_id => $feature->feature_id,
			type_id => $cvterm_ids{biological_process},
			value => 'pathogenesis',
			rank => 0
		}
		);

}

sub parseHeader {
	my $_seqId = shift;
	my $_seqHeader = shift;
	my $_seqTag = "$_seqId $_seqHeader";
	my %_seqHeaders;
	
	my @vfo_ids = $_seqId =~ m/VFO:\d{7}/g;
	$_seqHeaders{'VFOID'} = \@vfo_ids;

	if ($_seqTag =~ m/^(R\d{6})(\|VFO:\d{7}\|?)*\s([\w\d\/]+)/) {
		my $name = $3;
		my $virulence_id = $1;
		$_seqHeaders{'VIRULENCE_ID'} = $virulence_id;
		$_seqHeaders{'NAME'} = $name;
		$_seqHeaders{'UNIQUENAME'} = $name;
	}
	if ($_seqTag =~ m/(\()([\w\d\]*_?[\w\d]*)(\))/) {
		my $uniquename = $2;
		$_seqHeaders{'UNIQUENAME'} = $uniquename;
	}
	if ($_seqTag =~ m/\[(Escherichia coli)\s(str\.)\s([\w\d\W\D]*)\s(\()([\w\d\W\D]*)(\))\]/){
		my $organism = $1;
		$_seqHeaders{'ORGANISM'} = $organism;
		my $strain = $3;
		$_seqHeaders{'STRAIN'} = $strain;
		my $comment = $5;
		$_seqHeaders{'COMMENT'} = $comment;
	}
	if ($_seqTag =~ m/\s\-\s([w\d\W\D]*)\s(\[)/) {
		my $desc = $1;
		$_seqHeaders{'DESCRIPTION'} = $desc;
	}
	if ($_seqTag =~ m/(str\.)\s([\w\d\W\D]*)\s(\()([\w\d\W\D]*)(\))\s(plasmid)\s(.*)\]/) {
		my $plasmid = $7;
		my $strain = $2;
		$_seqHeaders{'MOLTYPE'} = "plasmid";
		$_seqHeaders{'PLASMID'} = $plasmid;
		$_seqHeaders{'ORGANISM'} = "Escherichia coli";
		$_seqHeaders{'STRAIN'} = $strain;
	}
	else {
		$_seqHeaders{'MOLTYPE'} = "dna";
		$_seqHeaders{'PLASMID'} = "none";
	}
	$_seqHeaders{'KEYWORDS'} = "Virulence Factor";

	$_seqHeaders{'UNIQUENAME'} = $_seqHeaders{'NAME'} if $_seqHeaders{'UNIQUENAME'} eq '';

	# foreach my $key (keys %_seqHeaders) {
	# 	print "$key: " . $_seqHeaders{$key} . "\n";
	# }
	# print "\n";
	return \%_seqHeaders;
}
