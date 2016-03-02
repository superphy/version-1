#!/usr/bin/env perl 
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;
use Modules::User;


=head1 NAME

$0 - Adds an entries to the organism, db and cvterm tables for the genodo application 

=head1 SYNOPSIS

  % genodo_add_ontology.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.

=head1 DESCRIPTION

This script will check or insert a number of entries into the Chado DB
needed by the Genodo application. These include:

1. E.coli entry in the organism table (if one already exists, this value 
will be updated to ensure consistency).
2. Genodo entry in the db table (if one already exists, this value 
will be updated to ensure consistency).
3. Entries in the cvterm table for the terms mol_type, keywords, description, 
finished, owner, comment from the SOFP feature_property ontology. We only check for 
their existence. If missing, please install ontology through the Chado 
installation scripts.
4. Entries in the cvterm table for the terms serotype, strain, isolation_host, 
isolation_location, isolation_date, isolation_source, isolation_latlng, severity
syndrome, isolation_age, pmid.  The xref DB is set to Genodo.

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI);

GetOptions(
    'config=s'      => \$CONFIG,
) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
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

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS) or croak "Could not connect to database.";


# Check existence of ontology terms used by Genodo.
# Add missing terms.
# Update fields of existing terms to keep consistent in all DB instances.

# System user
my $username = $DBUSER;
my $first_name = 'Superphy';
my $last_name = 'Administrator';
my $passwd = Modules::User::_encode_password($DBPASS);
my $email = 'NA';
my $row = $schema->resultset('Login')->update_or_new(
	{
		username => $username,
		password => $passwd,
		firstname => $first_name,
		lastname => $last_name,
		email => $email
	},
	{
		key => 'login_c1'
	});

unless($row->in_storage) {
	print "Adding user $username.\n";
	$row->insert;
	
}

# Organism
my $genus = 'Escherichia';
my $species = 'coli';
my $abbr = 'E.coli';
my $common_name = 'Escherichia coli';
my $comment = 'All species in Genodo are E.coli. Use feature properties strain and serotype to distinguish E.coli isolates.';
$row = $schema->resultset('Organism')->update_or_new(
	{
		genus => $genus,
		species => $species,
		abbreviation => $abbr,
		common_name => $common_name,
		comment => $comment
	},
	{
		key => 'organism_c1'
	});

unless($row->in_storage) {
	print "Adding organism $genus $species.\n";
	$row->insert;
	
}

# Genodo DB 
my $db_name = 'Genodo';
my $db_description = 'A DB reference for data stored in our database.';
$row = $schema->resultset('Db')->update_or_new(
	{
		name => $db_name,
		description => $db_description
	},
	{
		key => 'db_c1'
	});

unless($row->in_storage) {
	print "Adding database $db_name.\n";
	$row->insert;
}

# SOFP Feature properties

my $cv = $schema->resultset('Cv')->find({ name => 'feature_property' });

unless($cv) {
	croak "\n\nERROR: Cannot find the ontology feature_property. ".
		" The SOFP feature_property ontology should have been loaded during the CHADO DB installation.\n";
}

my $cv_id = $cv->cv_id;

my @sofp_terms = qw/mol_type keywords description finished owner comment/;
foreach my $term (@sofp_terms) {
	my $row = $schema->resultset('Cvterm')->find(
		{
			name => $term,
			cv_id => $cv_id
		});
	
	
	unless($row){
		croak "\n\nERROR: the SOFP feature property term $term is missing from the cvterm table.".
			" The SOFP feature_property ontology should have been loaded during the CHADO DB installation.\n";
	}
}

# Genodo Feature properties

$cv = $schema->resultset('Cv')->find({ name => 'local' });

unless($cv) {
	croak "\n\nERROR: Cannot find the default ontology local. ".
		" A local ontology should have been initialized during the CHADO DB installation.\n";
}

$cv_id = $cv->cv_id;

my $db_id = $schema->resultset('Db')->find({ name => $db_name })->db_id;


my @local_terms = qw/serotype strain isolation_host isolation_location isolation_date isolation_latlng
	syndrome severity isolation_source isolation_age pmid virulence_factor antimicrobial_resistance_gene
	source_organism publication pangenome panseq_function locus core_genome typing_sequence allele_fusion 
	stx1_subtype stx2_subtype ecoli_marker_region reference_pangenome_alignment/;
foreach my $term (@local_terms) {
	
	my $term_hash = {
			name => $term,
			cv_id => $cv_id,
			is_obsolete => 0,
			is_relationshiptype => 0,
			dbxref => {
				db_id => $db_id,
				accession => $term
			}
		};
	
	my $row = $schema->resultset('Cvterm')->find_or_new($term_hash, { key => 'cvterm_c1' });
	
	unless($row->in_storage) {
		print "Adding local ontology term $term\n";
		$row->insert;
	}
}

# Genodo Feature relationship types
my @local_rel_terms = qw/fusion_of aligned_sequence_of/;
foreach my $term (@local_rel_terms) {
	
	my $term_hash = {
			name => $term,
			cv_id => $cv_id,
			is_obsolete => 0,
			is_relationshiptype => 1,
			dbxref => {
				db_id => $db_id,
				accession => $term
			}
		};
	
	my $row = $schema->resultset('Cvterm')->find_or_new($term_hash, { key => 'cvterm_c1' });
	
	unless($row->in_storage) {
		print "Adding local ontology relationship term $term\n";
		$row->insert;
	}
}

exit(0);
