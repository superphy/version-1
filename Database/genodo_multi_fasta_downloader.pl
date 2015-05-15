#!/usr/bin/env perl 
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;

use IO::File;
use IO::Dir;
umask 0000;

=head1 NAME

$0 - Downloads all sequences from the db into a single multifasta file. 

=head1 SYNOPSIS

  % genodo_multi_fasta_downloader.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.
 --output_dir         Specify an output directory to save the file.

=head1 DESCRIPTION

Script to download all fasta sequences from the database to a single multi-fasta file, 
to use for generating vir/amr data and the phylogenetic tree, etc.


Sequences will have the tag:
>public/private_feature_id #contig# public/private_feature_id #contig_collection#

Contigs will have unique feature id's but will be appended with the parent id to classify
which collection they belong to (hashed comments will not be shown).

=head1 AUTHOR

Akiff Manji

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $OUTPUTDIR);

GetOptions(
	'config=s'      => \$CONFIG,
	'output_dir=s'	=> \$OUTPUTDIR,
	) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
croak "Missing argument. You must supply an output directory.\n" . system ('pod2text', $0) unless $OUTPUTDIR;
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

# Create a timestamp that is a unique identifier for the temp files
my $timeStamp = localtime(time);
$timeStamp =~ s/ /_/g;
$timeStamp =~ s/:/_/g;

my $tempFolder = "tempFasta_$timeStamp";
my $tempSingleHeaders = "tempSingleHeaders";
my $tempMultiFastaFiles = "tempMultiFastaFiles";

_prepareTempFolders();
_getPublicSequenceCollections();
_getPrivateSequenceCollections();
_mergeFiles();
	system("rm -r $OUTPUTDIR/$tempFolder/") == 0 or croak "$!";

#Makes temp folders in the specified user specified $OUTPUT dir 
sub _prepareTempFolders  {
	my $systemLine1 = "mkdir $OUTPUTDIR/$tempFolder/";
	my $systemLine2 = "mkdir $OUTPUTDIR/$tempFolder/$tempSingleHeaders/";
	my $systemLine3 = "mkdir $OUTPUTDIR/$tempFolder/$tempMultiFastaFiles/";

	system($systemLine1) == 0 or croak "$!";
	system($systemLine2) ==0 or croak "$!";
	system($systemLine3) ==0 or croak "$!";
}

#Gets a list of all the names of the public contig collections from the feature table
sub _getPublicSequenceCollections {
	my @publicContigCollectionIDs;
	my $publicFeatureIDs = $schema->resultset('Feature')->search(
		{	'type.name' => 'contig_collection'	},
		{
			join => [ 'type' ],
			columns => [ qw/feature_id/ ]
		}
		);
	while (my $featureIDrow = $publicFeatureIDs->next) {
		push(@publicContigCollectionIDs , $featureIDrow->feature_id);
	}
	print "Retrieved public sequence id's. Writing to file...\n";
	_getPublicSequences(\@publicContigCollectionIDs);

}

# Downloads all public sequences
sub _getPublicSequences {
	my $_publicSequenceCollectionIDs = shift;
	foreach my $_collectionID (@{$_publicSequenceCollectionIDs}) {
		my $publicSequences = $schema->resultset('FeatureRelationship')->search(
			{ 'me.object_id' => "$_collectionID" },
			{
				join => [ 'subject' ],
				columns => [ qw/subject.feature_id subject.residues subject.name/ ]
			}
			);
		while (my $row = $publicSequences->next) {
			_writeFastaSeqToFile($row , "public" , $_collectionID);
		}
		_aggregateHeaders($_collectionID , "public");
	}
}

#Gets a list of all the names of the private contig collections from the feature table
sub _getPrivateSequenceCollections {
	my @privateContigCollectionIDs;
	my $privateFeatureIDs = $schema->resultset('PrivateFeature')->search(
		{	'type.name' => 'contig_collection'	},
		{
			join => [ 'type' ],
			columns => [ qw/feature_id/ ]
		}
		);
	while (my $featureIDrow = $privateFeatureIDs->next) {
		push(@privateContigCollectionIDs , $featureIDrow->feature_id);
	}
	_getPrivateSequences(\@privateContigCollectionIDs);
}

# Downloads all private sequences
sub _getPrivateSequences {
	my $_privateSequenceCollectionIDs = shift;
	foreach my $_collectionID (@{$_privateSequenceCollectionIDs}) {
		my $privateSequences = $schema->resultset('PrivateFeatureRelationship')->search(
			{ 'me.object_id' => "$_collectionID" },
			{
				join => [ 'subject' ],
				columns => [ qw/subject.feature_id subject.residues subject.name/ ]
			}
			);
		while (my $row = $privateSequences->next) {
			_writeFastaSeqToFile($row , "private" , $_collectionID);
		}
	}
}

sub _writeFastaSeqToFile {
	my $row = shift;
	my $pubPriTag = shift;
	my $_collectionID = shift;	
	my $headerFile = $row->subject->feature_id;
	open(OUT, '>' . "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/$headerFile") or croak "$!";
	print(OUT '>lcl|' . $pubPriTag . '_' . $_collectionID . '|' . $pubPriTag . "_" . $row->subject->feature_id . "\n" . $row->subject->residues . "\n") or croak "$!";
	close(OUT);
	#print "Writing out sequence for " . $row->subject->name . "\n";
}

sub _aggregateHeaders {
	my $_collectionID = shift;
	my $pubPriTag = shift;

	opendir (TEMP , "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/") or croak "$!";
	while (my $file = readdir TEMP)
	{
		open my $in, '<' , "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/$file" or croak "Can't read $file: $!";
		open my $out, '>>' , "$OUTPUTDIR/$tempFolder/$tempMultiFastaFiles/$pubPriTag" . "_" . "$_collectionID" or croak "$!";
		while (<$in>) {
			print $out $_;
		}
		unlink "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/$file";
	}
	closedir TEMP;
	print "File created for $pubPriTag" . "_" . "$_collectionID\n";
}

sub _mergeFiles {
	opendir (TEMP2 , "$OUTPUTDIR/$tempFolder/$tempMultiFastaFiles/") or croak "$!";
	while (my $file = readdir TEMP2)
	{
		open my $in, '<' , "$OUTPUTDIR/$tempFolder/$tempMultiFastaFiles/$file" or croak "Can't read $file: $!";
		open my $out, '>>' , "$OUTPUTDIR/multiFasta$timeStamp.fasta" or croak "$!";
		while (<$in>) {
			print $out $_;
		}		
	}
	closedir TEMP2;
	print "multiFasta$timeStamp.fasta created in $OUTPUTDIR\n";
}