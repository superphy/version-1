#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use IO::File;
use FindBin;
use lib "$FindBin::Bin/../";
use File::Basename;
use Config::Simple;
use Carp qw/croak carp/;
use DBI;

=head1 NAME

$0 - Updates annotations in the featureprop table of the database specified in the config file.

=head1 SYNOPSIS

		% genodo_update_pangenome_annotations.pl

=head1 COMMAND-LINE OPTIONS

		--annotation_file		Specify an annotation file to uppload.
		--config 				Specify a valid config file with db connection params.

=head1 DESCRIPTION

Perl script to update annotaions for panseq fragments in the featureprop table.
If the annotations dont exist in the featureprop table then new ones are created, provided that the sequences and feature_ids are available in the feature table.

The script will search for the feature_ids of the loaded panseq fragments using the ID from the annoation file.
If the feature_id is not found then the annotation is not added (The sequence and feature_id must be available to correctly populate the featureprop table)
All existing annotation descriptions will be kept as is, and new annotaions will be bulk inserted if they are not found in the featureprop table.

=head1 AUTHOR

Akiff Manji

=cut

my ($annotationFile, $CONFIGFILE);

GetOptions(
	'annotation_file=s' => \$annotationFile,
	'config=s' => \$CONFIGFILE
	) or ( system ('pod2text', $0), exit -1 );

croak "Missing argument. You must supply a panseq annotation file\n" . system('pod2text', $0) unless $annotationFile;
croak "Missing argument. You must supply a valid config file\n" . system('pod2text', $0) unless $CONFIGFILE;

#db connection params

my ($dbname, $dbuser, $dbpass, $dbhost, $dbport, $DBI, $TMPDIR);

if( my $db_conf = new Config::Simple($CONFIGFILE)) {
	$dbname = $db_conf->param('db.name');
	$dbuser = $db_conf->param('db.user');
	$dbpass = $db_conf->param('db.pass');
	$dbhost = $db_conf->param('db.host');
	$dbport = $db_conf->param('db.port');
	$DBI = $db_conf->param('db.dbi');
	$TMPDIR = $db_conf->param('tmp.dir');
} 
else {
	die Config::Simple->error();
}

die "Invalid configuration file.\n" unless $dbname;

my $dbh = DBI->connect(
	"dbi:Pg:dbname=$dbname;port=$dbport;host=$dbhost",
	$dbuser,
	$dbpass,
	{AutoCommit => 0, TraceLevel => 0}
	) or die "Unable to connect to database: " . DBI->errstr;

open my $annotationFH, "<", $annotationFile or die "Could not open $annotationFile: $!\n";

my $formattedTable = "$FindBin::Bin/panseqFeaturepropTable.txt";
open my $fwriter, ">", $formattedTable or die "$!";
#Split all lines into arrays
#Each line array has the indeces:

#$line[0] is panSeq name
#$line[1] is panSeq length
#$line[2] is annotated seq id
#$line[3] is annotated seq length
#$line[4] is seq annotation

my @annotations;
while (<$annotationFH>) {
	#Split off the carriage return. 
	$_ =~ s/\R//g;
	my @line = split(/\t/, $_);
	push(@annotations, \@line);
}

my $featurepropTypeID = getPangenomeTypeID('function');
die "Cvterm not found: $!\n" unless $featurepropTypeID; 

my %addedFeatureprops;

foreach my $line (@annotations) {
	my ($annotationID, $annotationName) = parseFragmentId($line->[0]);
	my $feature_id = findFeatureID($annotationID);
	next if (!$feature_id);
	my $featureprop_id = findFeaturepropID($feature_id);
	next if ($featureprop_id);
	next if (exists($addedFeatureprops{$annotationID}));
	writeOutNewAnnotaion($feature_id, $annotationID, $line->[4]);
	#need to store the new written ids to check agaisnt
}

close $annotationFH;
print $fwriter "\\.\n\n";
$fwriter->autoflush;
close $fwriter;

copyNewAnnos($formattedTable);

unlink $formattedTable;

sub getPangenomeTypeID {
	my $type = shift;
	my $cvTerm = 'panseq_'.$type;
	my $sth = $dbh->prepare('SELECT cvterm_id FROM cvterm WHERE name = ?')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($cvTerm) or die "Couldn't execute statement: " . $sth->errstr;
	my $_cvterm_id;
	while (my @data = $sth->fetchrow_array()) {
		$_cvterm_id = $data[0];
	}
	return $_cvterm_id;
}

sub parseFragmentId {
	my $seqHeader = shift;
	my ($fragId, $fragName) = "";
	$fragId = $1 if $seqHeader =~ /lcl\|([\d]*)\|/;
	$fragName = $1 if $seqHeader =~ /\|lcl\|(.*)/;
	return ($fragId, $fragName);
}

sub findFeatureID {
	my $_annotation_id = shift;
	my $sth = $dbh->prepare('SELECT feature_id FROM feature WHERE uniquename = ?')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_annotation_id) or die "Couldn't execute statement: " . $sth->errstr;
	my $_feature_id;
	while (my @data = $sth->fetchrow_array()) {
		$_feature_id = $data[0];
	}
	return $_feature_id;
}

sub findFeaturepropID {
	my $_feature_id = shift;
	my $sth = $dbh->prepare('SELECT featureprop_id FROM featureprop WHERE feature_id = ? AND type_id = ?')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($_feature_id, $featurepropTypeID) or die "Coudn't execute statement: " . $sth->errstr;
	my $_featureprop_id;
	while (my @data = $sth->fetchrow_array()) {
		$_featureprop_id = $data[0];
	}
	return $_featureprop_id;
}

sub writeOutNewAnnotaion {
	my ($_feature_id, $_annotation_id, $_annoatation) = @_;
	print $fwriter "$_feature_id\t$featurepropTypeID\t$_annoatation\n";
	$addedFeatureprops{$_annotation_id} = $_annoatation;
}

sub copyNewAnnos {
	my $_formattedTable = shift;

	$dbh->do('COPY featureprop(feature_id, type_id, value) FROM STDIN');

	open my $fh, "<", $_formattedTable or die "Cannot open $_formattedTable: $!";
	seek($fh,0 ,0);

	while (<$fh>) {
		if (! ($dbh->pg_putcopydata($_))) {
			$dbh->pg_putcopyend;
			$dbh->rollback;
			$dbh->disconnect;
			die "Error calling pg_putcopydata: $!";
		}
	}
	print "pg_putcopydata completed successfully";
	$dbh->pg_putcopyend() or die "Error calling pg_putcopyend: $!";
	$dbh->commit;
	$dbh->disconnect;
}
