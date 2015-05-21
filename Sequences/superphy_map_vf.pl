#!/usr/bin/env perl

use strict;
use warnings;
use IO::File;
use Bio::SeqIO;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Config::Simple;
use Carp qw/croak carp/;

my $path_to_fasta = $ARGV[0];
my $path_to_config = $ARGV[1];

my $seq_fh = Bio::SeqIO->new(-file => $path_to_fasta, -format => 'fasta');

my %vfs;

my $count = 0;
# Preapre vf sequences
while (my $seq = $seq_fh->next_seq()) {
	$seq->primary_id() =~ m/^(.*)\|VFO\:([\d]*)\|/;
	my ($seq_name, $uniquename, $seq_id) = ($1, $1, $2);

	if ($seq->desc() =~ m/\-\ (\()([\w\d\]*_?[\w\d]*)(\))/) {
		$uniquename = $2;
	}
	$vfs{$seq_name . "-" .$uniquename}{vfo_id} = $seq_id;
}

# Connect to database
my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI);

# Connect to DB and gen schema object
if(my $db_conf = new Config::Simple($path_to_config)) {
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

	my %vf_features;

	my $vf_features_rs = $schema->resultset('Feature')->search({
		'type.name' => 'virulence_factor'
		},
		{
			columns => [qw/me.feature_id me.name me.uniquename/],
			join => ['type']
		}
		);

	while (my $feature_row = $vf_features_rs->next) {
		$vfs{$feature_row->name."-".$feature_row->uniquename}{feature_id} = $feature_row->feature_id;
	}

	my $dbxref_rs = $schema->resultset('Dbxref')->search({
		'db.name' => 'VFO',
		},
		{
			columns => [qw\me.dbxref_id me.accession\],
			join => ['db']
		}
		);

	my %dbxrefs;

	while (my $dbxref_row = $dbxref_rs->next) {
		$dbxrefs{$dbxref_row->accession}{dbxref_id} = $dbxref_row->dbxref_id;
	}

	# Map vfs to dbxref_ids
	foreach (keys %vfs) {
		$vfs{$_}{dbxref_id} = $dbxrefs{$vfs{$_}{vfo_id}}{dbxref_id};
	}

# Update the relvant rows
foreach (keys %vfs) {
	my $row_to_update = $vf_features_rs->find({ feature_id => $vfs{$_}{feature_id}});
	$row_to_update->update({dbxref_id => $vfs{$_}{dbxref_id}});
}

#Retrieve common dbs
my $db_row = $schema->resultset('Db')->find({name => 'VFO'});
my $vfo_db_id = $db_row->db_id;
croak "ERROR: Virulence factor database (VFO) not found in db table\n" unless $vfo_db_id;

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
	biological_process => 'feature_property',
	comment => 'feature_property'
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

foreach (keys %vfs) {
#Create feature_cvterms for VFO terms
my $rank = 0;
my $accessionId = $vfs{$_}{vfo_id};
	#my $accId =~ s/VFO://;
	my $term_rs = $schema->resultset('Cvterm')->search(
	{
		'dbxref.accession' => $accessionId,
		'dbxref.db_id' => $vfo_db_id,
		},
		{
			join => 'dbxref'
		}
		);
	my @matching = $term_rs->all;
	die "ERROR: VFO term VFO:$accessionId not found in dbxref table." unless @matching;
	die "ERROR: Multiple VFO terms matching VFO:accessionId found in cvterm table." unless @matching == 1;

	my $term = shift @matching;

	#print $term->cvterm_id . "\n";

	$schema->resultset('FeatureCvterm')->create(
	{
		feature_id => $vfs{$_}{feature_id},
		cvterm_id => $term->cvterm_id,
		pub_id => $pub_id,
		rank => $rank
	}
	);
}

