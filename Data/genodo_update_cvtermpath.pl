#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use IO::File;
use IO::Dir;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;
use DBIx::Class::ResultSet;
use DBIx::Class::Row;
use List::MoreUtils qw/ uniq /;
use DBI;

=head1 NAME

$0 - Updates the cvtermpath table with relfexive transitive closures of cvterms of the database specified in the config file.

=head1 SYNOPSIS 

	% genodo_update_cvtermpath.perl

=head1 COMMAND-LINE OPTIONS

	--data_type		Specify whether cvterms coorespond to vir or amr.
	--config 		Specify a valid config file with db connection params.

=head1 DESCRIPTION

=head1 AUTHOR

Akiff Manji

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $dataType);

GetOptions(
	'data_type=s'   => \$dataType,
	'config=s'      => \$CONFIG,
	) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
croak "Missing argument. You must supply a data type (vir, amr)\n" . system ('pod2text', $0) unless $dataType;

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

#Categories will have the form:

# 	%categores = (
# 		'unclassified' => {
# 			{ 
# 				type_id => {
#						parent_ids => [], start off with its own id
#						feature_ids => [feature_id..], here the type_id is the cvterm_id of the gene.
#					}
# 			}
# 		},
#

# Initially the categories hash will be empty:

#	'parent_id' => {
#		parent_name => 'ABCC',
#		'subcategories' => {
#			cvterm_id* => {
#			cvterm_name => '###',
#			type_ids => []
#			}
#		..*}
#		}
# 	)

# After the hash is populated:

#	'parent_id' => {
#		parent_name => 'ABCC',
#		'subcategories' => {
#			cvterm_id* => {
#			cvterm_name => '###',
#			type_ids => { 
#					##These will come from the unclassified types:
#					type_id => {
#					parent_id => cvterm_id* 
#					feature_ids => [feature_ids..*]
#					}
#				..*}
#			}
#		..*}
#		}
# 	)

my (%categories, %unclassifiedIds, %categoryIds, $id, $dbh);

if ($dataType eq 'amr') {
	my $cvterm = $schema->resultset('Cvterm')->find({'me.name' => 'antimicrobial_resistance_gene'});
	$id = $cvterm->cvterm_id;
	die unless $id;

	my @wantedCategories = (
		'antibiotic molecule',
		'determinant of antibiotic resistance',
		'antibiotic target',
		);

	#Need the correct pub_id to grab the correct sequences

	my $pub_rs = $schema->resultset('Pub')->find({uniquename => 'The Comprehensive Antibiotic Resistance Database'});
	my $pub_id = $pub_rs->pub_id;

	die "Pub id could not be found for \'The Comprehensive Antibiotic Resistance Database\'" unless $pub_id;

#Populate the initial hashes;
getFeatureCvtermIds($pub_id);
getAmrCategoryIds(\@wantedCategories);
#appendBroadCategory('process or component of antibiotic biology or chemistry');

print "Generated categories...\n";
print "\t...Begin mapping terms\n";

while (keys %{$categories{'unclassified'}} != 0) {
	findParents();
}

print "Printing mapped terms to file\n";

my $filePath = $dataType . "_categoies.txt";
printToFile($filePath);

#Disconnect the schema, I prefer to use DBI to copy all the data into the file;
$schema->storage->dbh->disconnect;

print "Reconnecting database for data copy...\n";

# #Can use the existing config creds to connect to the db with DBI
$dbh = DBI->connect(
	"dbi:Pg:dbname=$DBNAME;port=$DBPORT;host=$DBHOST",
	$DBUSER,
	$DBPASS,
	{AutoCommit => 0, TraceLevel => 0}
	) or die "Unable to reconnect to database: " . DBI->errstr;

print "\t...Connected\n";

copyAmrDataToDB($filePath);

unlink($filePath);

}

elsif ($dataType eq 'vir') {
	my $cvterm = $schema->resultset('Cvterm')->find({'me.name' => 'virulence_factor'});
	$id = $cvterm->cvterm_id;
	die unless $id;

	my @wantedCategories = (
		'pathogenesis'
		);

	#Need the correct pub_id to grab the correct sequences

	my $pub_rs = $schema->resultset('Pub')->find({'me.uniquename' => 'Virulence Factor Database'});
	my $pub_id = $pub_rs->pub_id;

	die "Pub id could not be found for \'Virulence Factor Database\'" unless $pub_id;

#Populate the initial hashes;
getFeatureCvtermIds($pub_id);
getVFCategoryIds(\@wantedCategories);
#appendBroadCategory('process or component of antibiotic biology or chemistry');

print "Generated categories...\n";
print "\t...Begin mapping terms\n";

while (keys %{$categories{'unclassified'}} != 0) {
	findParents();
}

print "Printing mapped terms to file\n";

my $filePath = $dataType . "_categoies.txt";
printToFile($filePath);

#Disconnect the schema, I prefer to use DBI to copy all the data into the file;
$schema->storage->dbh->disconnect;

print "Reconnecting database for data copy...\n";

# #Can use the existing config creds to connect to the db with DBI
$dbh = DBI->connect(
	"dbi:Pg:dbname=$DBNAME;port=$DBPORT;host=$DBHOST",
	$DBUSER,
	$DBPASS,
	{AutoCommit => 0, TraceLevel => 0}
	) or die "Unable to reconnect to database: " . DBI->errstr;

print "\t...Connected\n";

copyVFDataToDB($filePath);

unlink($filePath);

}

##				    ##
## Helper Functions ## 
##				    ##

sub findParents {
	#print "There are: " . scalar(keys %unclassifiedIds) . " unclassified ids\n";
	#print "Matches\n" if scalar(keys %$unclassifiedIds) == scalar(keys %unclassifiedIds);

	#First look up the parent_id (as a subject) for the unclassified in the list, since on the first iteration it will be the types own id,
	#If the object of the parent is found in the %categoryIds list, update the parent_id, put type into the subcategory of the correct super category in %categories
	#(can use the parent_id to figure this out), delete the entry from %unclassifiedIds and from the 'unclassified' sub hash in the %categories list.
	#If the object of the parent_id does not belong to any of the ids in %categoryIds, then it must be a sub category. Just update the parent_id in the 'unclassified' sub hash
	#Else do nothing and move to the next iteration. Eventually all genes will be categorizd under the broader classification of "process or component of antibiotic biology or chemistry"

	foreach my $key (keys %{$categories{'unclassified'}}) {
		my $parent_ids = $categories{'unclassified'}->{$key}->{'parent_ids'};
		#print $key . "\n";
		#sleep(1);

		my $_parentResuts = $schema->resultset('CvtermRelationship')->search(
			{'me.subject_id' => $parent_ids},
			{
				select => ['object_id'],
				as => ['parent']
			}
			);

		my $newParents = [];
		while (my $row = $_parentResuts->next) {
			if (exists $categoryIds{$row->get_column('parent')}) {
				#print "Found parent: " . $row->get_column('parent') . " ...updating \%categories.\n";

				my %newSubCategory;
				$newSubCategory{'parent_id'} = $row->get_column('parent');
				$newSubCategory{'feature_ids'} = $categories{'unclassified'}->{$key}->{'feature_ids'};

				my $superClassID = $categoryIds{$row->get_column('parent')};
				$categories{$superClassID}->{'subcategories'}->{$row->get_column('parent')}->{'type_ids'}->{$key} = \%newSubCategory;
			}
			else {
				push(@{$newParents}, $row->get_column('parent'));
			}
		}
		if (scalar(@{$newParents}) != 0){
			$categories{'unclassified'}->{$key}->{'parent_ids'} = [];
			$categories{'unclassified'}->{$key}->{'parent_ids'} = $newParents;
		}
		else {
				#All parents were found, delete from the $unclassified ids list and 'unclassified' subhash in %categories;
				delete $categories{'unclassified'}->{$key};
				delete $unclassifiedIds{$key};
			}
		}
		return;
	}

#Bottom -> Up:
sub getFeatureCvtermIds {
	my $_pub_id = shift;
	my $geneResults = $schema->resultset('FeatureCvterm')->search(
		{'me.pub_id' => $_pub_id},
		{

			select => ['me.feature_id', 'me.cvterm_id'],
			as => ['feature_id', 'type_id']
		}
		);

	$categories{'unclassified'} = {};


	while (my $row = $geneResults->next) {
		$categories{'unclassified'}->{$row->get_column('type_id')} = {} unless exists $categories{'unclassified'}->{$row->get_column('type_id')};
		#Set parent id initially as itself
		$categories{'unclassified'}->{$row->get_column('type_id')}->{'parent_ids'} = [];
		push(@{$categories{'unclassified'}->{$row->get_column('type_id')}->{'parent_ids'}}, $row->get_column('type_id'));
		$categories{'unclassified'}->{$row->get_column('type_id')}->{'feature_ids'} = [] unless exists $categories{'unclassified'}->{$row->get_column('type_id')}->{'feature_ids'};
		push(@{$categories{'unclassified'}->{$row->get_column('type_id')}->{'feature_ids'}}, $row->get_column('feature_id'));
		#An additional list to make it easier for iteration
		$unclassifiedIds{$row->get_column('type_id')} = undef;
	}
	return;
}

sub getAmrCategoryIds {
	my $wantedCategories = shift;
	my $amrCategoryResults = $schema->resultset('Cvterm')->search(
		{'dbxref.accession' => '1000001', 'subject.name' => $wantedCategories},
		{
			join => [
			'dbxref',
			{'cvterm_relationship_objects' => {'subject' => [{'cvterm_relationship_objects' => 'subject'}, 'dbxref']}}
			],
			select => ['me.dbxref_id', 'subject.cvterm_id', 'subject.name', 'subject_2.cvterm_id', 'subject_2.name', 'dbxref_2.accession'],
			as => ['parent_dbxref_id', 'broad_category_id', 'broad_category_name', 'refined_category_id', 'refined_category_name', 'accession']
		}
		);

	while (my $row = $amrCategoryResults->next) {
		my %subcategory;
		$subcategory{$row->get_column('refined_category_id')} = {} unless exists $subcategory{$row->get_column('refined_category_id')};
		$subcategory{$row->get_column('refined_category_id')}->{'cvterm_name'} = $row->get_column('refined_category_name');
		$subcategory{'type_ids'} = {} unless exists $subcategory{'type_ids'};
		
		$categories{$row->get_column('broad_category_id')}->{'subcategories'} = {} unless exists $categories{$row->get_column('broad_category_id')}->{'subcategories'};
		$categories{$row->get_column('broad_category_id')}->{'subcategories'}->{$row->get_column('refined_category_id')} = \%subcategory;
		$categories{$row->get_column('broad_category_id')}->{'parent_name'} = $row->get_column('broad_category_name');
		#Additional list to make iteration easier
		$categoryIds{$row->get_column('refined_category_id')} = $row->get_column('broad_category_id');
	}
	return;
}

sub getVFCategoryIds {
	my $wantedCategories = shift;
	my $vfCategoryResults = $schema->resultset('Cvterm')->search(
		{'me.name' => $wantedCategories},
		{
			join => [{'cvterm_relationship_objects' => {'subject' => {'cvterm_relationship_objects' => 'subject'}}}],
			select => ['me.cvterm_id', 'me.name', 'subject.cvterm_id', 'subject.name', 'subject_2.cvterm_id', 'subject_2.name'],
			as => ['matriarch_category_id', 'matriarch_category_name', 'broad_category_id', 'broad_category_name', 'refined_category_id', 'refined_category_name']
		}
		);

	while (my $row = $vfCategoryResults->next) {
		my %subcategory;
		$subcategory{$row->get_column('refined_category_id')} = {} unless exists $subcategory{$row->get_column('refined_category_id')};
		$subcategory{$row->get_column('refined_category_id')}->{'cvterm_name'} = $row->get_column('refined_category_name');
		$subcategory{'type_ids'} = {} unless exists $subcategory{'type_ids'};
		
		$categories{$row->get_column('broad_category_id')}->{'subcategories'} = {} unless exists $categories{$row->get_column('broad_category_id')}->{'subcategories'};
		$categories{$row->get_column('broad_category_id')}->{'subcategories'}->{$row->get_column('refined_category_id')} = \%subcategory;
		$categories{$row->get_column('broad_category_id')}->{'parent_name'} = $row->get_column('broad_category_name');
		#Additional list to make iteration easier
		$categoryIds{$row->get_column('refined_category_id')} = $row->get_column('broad_category_id');
	}
	return;
}

sub appendBroadCategory {
	my $term = shift;
	#Get the  term id and append it both to the %categoryIds list and the %categories list
	my $_categoryRow = $schema->resultset('Cvterm')->find({'me.name' => $term});

	my %subcategory;
	$subcategory{$_categoryRow->cvterm_id} = {} unless exists $subcategory{$_categoryRow->cvterm_id};
	$subcategory{$_categoryRow->cvterm_id}->{'cvterm_name'} = $_categoryRow->name;
	$subcategory{'type_ids'} = {} unless exists $subcategory{'type_ids'};

	$categories{$_categoryRow->cvterm_id}->{'subcategories'} = {} unless exists $categories{$_categoryRow->cvterm_id}->{'subcategories'};
	$categories{$_categoryRow->cvterm_id}->{'subcategories'}->{$_categoryRow->cvterm_id} = \%subcategory;
	$categories{$_categoryRow->cvterm_id}->{'parent_name'} = $_categoryRow->name;

	$categoryIds{$_categoryRow->cvterm_id} = $_categoryRow->cvterm_id;
}

sub printToFile{
	my $_filePath = shift;
	open my $fh, ">", "$_filePath" or die "Could not open file: $!\n";

	#The categories table currently has the columns:
	#	gene_cvterm_id (type_id) | category_id (subcategory id) | feature_id (gene feature_id) | amr/vf_category_id (generated automatically since its a serial type)

	foreach my $x (keys %categories) {
		foreach my $y (keys %{$categories{$x}->{'subcategories'}}) {
			foreach my $z (keys %{$categories{$x}->{'subcategories'}->{$y}->{'type_ids'}}) {
				#print "$z\t$y\t$_\n" foreach(@{$categories{$x}->{'subcategories'}->{$y}->{'type_ids'}->{$z}->{'feature_ids'}});
				foreach my $feature_id (@{$categories{$x}->{'subcategories'}->{$y}->{'type_ids'}->{$z}->{'feature_ids'}}) {
					print $fh "$x\t$y\t$z\t$feature_id\n";
				}
			}
		}
	}

	close $fh;
}

sub copyAmrDataToDB {
	my $_filePath = shift;

	#need a dbh do statement
	$dbh->do("COPY amr_category(parent_category_id, category_id, gene_cvterm_id, feature_id) FROM STDIN");

	open my $copyfh, "<", $_filePath or die "Cannot open $_filePath: $!";

	while (<$copyfh>) {
		if (! ($dbh->pg_putcopydata($_))) {
			$dbh->pg_putcopyend();
			$dbh->rollback;
			$dbh->disconnect;
			die "Error calling pg_putcopydata: $!";
		}
	}
	print "pg_putcopydata completed sucessfully.\n";
	$dbh->pg_putcopyend() or die "Error calling pg_putcopyend: $!";
	$dbh->commit;
	$dbh->disconnect;
	print "Data copy completed\n";
}

sub copyVFDataToDB {
	my $_filePath = shift;

	#need a dbh do statement
	$dbh->do("COPY vf_category(parent_category_id, category_id, gene_cvterm_id, feature_id) FROM STDIN");

	open my $copyfh, "<", $_filePath or die "Cannot open $_filePath: $!";

	while (<$copyfh>) {
		if (! ($dbh->pg_putcopydata($_))) {
			$dbh->pg_putcopyend();
			$dbh->rollback;
			$dbh->disconnect;
			die "Error calling pg_putcopydata: $!";
		}
	}
	print "pg_putcopydata completed sucessfully.\n";
	$dbh->pg_putcopyend() or die "Error calling pg_putcopyend: $!";
	$dbh->commit;
	$dbh->disconnect;
	print "Data copy completed\n";
}
