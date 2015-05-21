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

$0 - Uploads the annotations for panseq fragments in featureprop table of the database specified in the config file.

=head1 SYNOPSIS

	% genodo_pangenome_annotation_bulk_loader.pl

=head1 COMMAND-LINE OPTIONS

	--annotation_file 		Specify an annotation file.
	--config 				Specify a valid config file with db connection params.

=head1 DESCRIPTION

Perl script to upload annotation data for panseq fragments into the featureprop table of the database specified in the config file.

The script will search for the feature_ids of the loaded panseq fragments using the ID from the annoation file and use this to populate the correct format
and foreign key constraints for the featureprop table.

NOTE: This script should only be run to upload panseq annotations for the first time after they are loaded using genodo_pangenome_bulk_loader.pl into the database.
It will not check if the annotations are already present in the database.

=head1 AUTHOR

Akiff Manji

=cut

my ($annotationFile, $CONFIGFILE);

GetOptions(
	'annotation_file=s' => \$annotationFile,
	'config=s' => \$CONFIGFILE
	) or ( system( 'pod2text', $0 ), exit -1 ); 

croak "Missing argument. You must supply a panseq annotation file\n" . system('pod2text', $0) unless $annotationFile;
croak "Missing argument. You must supply a valid config file\n" . system('pod2text', $0) unless $CONFIGFILE;

#db connection params

my ($dbname, $dbuser, $dbpass, $dbhost, $dbport, $DBI, $TMPDIR);

if(my $db_conf = new Config::Simple($CONFIGFILE)) {
	$dbname    = $db_conf->param('db.name');
	$dbuser    = $db_conf->param('db.user');
	$dbpass    = $db_conf->param('db.pass');
	$dbhost    = $db_conf->param('db.host');
	$dbport    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
	$TMPDIR    = $db_conf->param('tmp.dir');
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

open my $annotationFileReader, '<', $annotationFile or die "Coundn't open $annotationFile: $!\n";

my $formattedTable = "$FindBin::Bin/panseqAnnoFeaturePropTable.txt";
open my $annotationFeaturePropTable, '>', $formattedTable or die "$!";

my $featurepropTypeID = getPangenomeTypeId('function');
die "Cvterm not found: $!\n" unless $featurepropTypeID;

annotationFeatureIds();
close $annotationFileReader;
copyDataToDb($formattedTable);

unlink($formattedTable);

sub annotationFeatureIds {
	while (<$annotationFileReader>) {
		$_ =~ s/\R//g;
		my @lineRow = split("\t", $_);
		my $name = $lineRow[0];
		my $id = $lineRow[1];
		my $function = $lineRow[2];
		my $feature_id = findFeatureId($id);
		next if !defined($feature_id);
		writeOutFeaturepropTableFormat($name, $id, $function, $feature_id, $featurepropTypeID, $annotationFeaturePropTable);
	}
	print $annotationFeaturePropTable "\\.\n\n";
	$annotationFeaturePropTable->autoflush;
	close $annotationFeaturePropTable;
}

sub findFeatureId{
	my $_anno_id = shift;
	my $sth = $dbh->prepare('SELECT feature_id FROM feature WHERE uniquename = ?')
	or die "Could't prepare statement: " . $dbh->errstr;
	$sth->execute($_anno_id) or die "Couldn't execute statement: " . $sth->errstr;
	my $_feature_id;
	while (my @data = $sth->fetchrow_array()) {
		$_feature_id = $data[0];
	}
	return $_feature_id;
}

sub getPangenomeTypeId {
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

sub writeOutFeaturepropTableFormat {
	my ($anno_name, $anno_id, $anno_function, $anno_feature_id, $anno_featurepropTypeID, $fh) = @_;
	print $fh "$anno_feature_id\t$anno_featurepropTypeID\t$anno_function\n" or die "Couldn't write to file: $!";
}

sub copyDataToDb {
	my $_formattedTable = shift;

	$dbh->do('COPY featureprop(feature_id, type_id, value) FROM STDIN');

	open my $fh, '<', $_formattedTable or die "Cannot open $_formattedTable: $!";
	seek($fh, 0, 0);

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
