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

$0 - Downloads all Virulence Factor sequences from the db into a single multifasta file. 

=head1 SYNOPSIS

  % genodo_AMR_multi_fasta_downloader.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.
 --output_dir         Specify an output directory to save the file.

=head1 DESCRIPTION

Script to download all Antimicrobial Resistance fasta sequences from the database to a single multi-fasta file, 
to use for generating vir/amr data and the phylogenetic tree, etc.


Sequences will have the tag:
>AMR_feature_id|<uniquename>


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
_getAMRSequenceFeatureIds();
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
sub _getAMRSequenceFeatureIds {
	my @AMRIds;
	my $AMRfeatureIDs = $schema->resultset('Feature')->search(
    {
        'type.name' => "antimicrobial_resistance_gene"
        },
        {
            column  => [qw/feature_id/],
            join        => ['type'],
        }
        );
	while (my $featureIDrow = $AMRfeatureIDs->next) {
		#print $featureIDrow->feature_id  . "\n";
		push(@AMRIds , $featureIDrow->feature_id);
	}
	print "Retrieved public sequence id's. Writing to file...\n";
	_getAMRSequences(\@AMRIds);

}

# Downloads all public sequences
sub _getAMRSequences {
	my $_AMRIds = shift;
	foreach my $_AMRID (@{$_AMRIds}) {
		my $AMRSequences = $schema->resultset('Feature')->search(
			{ 'me.feature_id' => "$_AMRID" },
			{
				columns => [ qw/me.feature_id me.residues me.name me.uniquename/ ]
			}
			);
		while (my $row = $AMRSequences->next) {
			_writeFastaSeqToFile($row , "AMR" , $_AMRID);
		}
		_aggregateHeaders($_AMRID , "AMR");
	}
}

sub _writeFastaSeqToFile {
	my $row = shift;
	my $AMRTag = shift;
	my $_AMRID = shift;	
	my $headerFile = $row->feature_id;
	open(OUT, '>' . "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/$headerFile") or croak "$!";
	print(OUT ">" . "$AMRTag" . "_" . $row->feature_id . "|" . $row->uniquename . "\n" . $row->residues . "\n") or croak "$!";
	close(OUT);
}

sub _aggregateHeaders {
	my $_AMRID = shift;
	my $AMRTag = shift;

	opendir (TEMP , "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/") or croak "$!";
	while (my $file = readdir TEMP)
	{
		open my $in, '<' , "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/$file" or croak "Can't read $file: $!";
		open my $out, '>>' , "$OUTPUTDIR/$tempFolder/$tempMultiFastaFiles/$AMRTag" . "_" . "$_AMRID" or croak "$!";
		while (<$in>) {
			print $out $_;
		}
		unlink "$OUTPUTDIR/$tempFolder/$tempSingleHeaders/$file";
	}
	closedir TEMP;
	print "File created for $AMRTag" . "_" . "$_AMRID\n";
}

sub _mergeFiles {
	opendir (TEMP2 , "$OUTPUTDIR/$tempFolder/$tempMultiFastaFiles/") or croak "$!";
	while (my $file = readdir TEMP2)
	{
		open my $in, '<' , "$OUTPUTDIR/$tempFolder/$tempMultiFastaFiles/$file" or croak "Can't read $file: $!";
		open my $out, '>>' , "$OUTPUTDIR/AMRmultiFasta$timeStamp.fasta" or croak "$!";
		while (<$in>) {
			print $out $_;
		}		
	}
	closedir TEMP2;
	print "AMRmultiFasta$timeStamp.fasta created in $OUTPUTDIR\n";
}