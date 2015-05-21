#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;
use DBIx::Class::ResultSet;
use DBIx::Class::Row;


use IO::File;
use IO::Dir;

=head1 NAME

$0 - Processes/Cleans tab delmited output files from loci and snp P/A analysis for uploading to the db.

=head1 SYNOPSIS

  % genodo_process_data_file.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --input_file         Specify a tab delimited input file.
 --data_type          Specify type of input (binary, snp).
 --output_dir		  Specify the full path to a directory to print out processed file to.
 --config 			  Specify the database name to check for presence of locus/snp id.

=head1 DESCRIPTION

Script to process tab delmited datafiles from loci and snp P/A analysis. Removes/cleans loci that are not currently present in the db to prevent foreign key constraint violations.

=head1 AUTHOR

Akiff Manji

=cut

my ($INPUTFILE, $DATATYPE, $OUTPUTDIR, $CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI);

GetOptions(
	'input_file=s'	=> \$INPUTFILE,
	'data_type=s'	=> \$DATATYPE,
	'output_dir=s'	=> \$OUTPUTDIR,
	'config=s'		=> \$CONFIG
	) or ( system( 'pod2text', $0 ), exit -1 );

croak "Missing argument. You must supply an input data file.\n" . system ('pod2text', $0) unless $INPUTFILE;
croak "Missing argument. You must supply an input data type (binary, snp).\n" . system ('pod2text', $0) unless $DATATYPE;
croak "Missing argument. You must specify an output directory.\n" . system ('pod2text', $0) unless $OUTPUTDIR;
croak "Missing argument. You must a configuration db connection parameters.\n" . system ('pod2text', $0) unless $CONFIG;

#DB Connection params
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

open my $datafile , '<' , $INPUTFILE;

my @genomeTemp;
my $genomes;
my @seqFeatureTemp;

while (<$datafile>) {
	$_ =~ s/\R//g;
	if ($. == 1) {
		$genomes = $_;
	}
	elsif ($. > 1) {
		my @tempRow = split(/\t/, $_);
		push (@seqFeatureTemp , \@tempRow);
	}
	else {
	}
}

open my $outfh , '>' , $OUTPUTDIR . "/" . $DATATYPE . "_cleaned_data.txt" or die "Cannot open file handle: $!\n";

#Print out the first line
print $outfh $genomes . "\n";

for (my $j = 0; $j < scalar(@seqFeatureTemp)-1 ; $j++) {
	my $locusID = $seqFeatureTemp[$j][0];
	#Checks the db and prints out to the clean file.
	checkIfLocusPresent($locusID, $j);
}

sub checkIfLocusPresent {
	my $_locusID = shift;
	my $_locusIndex = shift;

	my $locusRow = $schema->resultset('Loci')->find({locus_id => $_locusID});

	if (defined($locusRow)) {
		print $outfh join("\t", @{$seqFeatureTemp[$_locusIndex]}) . "\n";
	}
	else {
		print "$_locusID not found\n";
	}
}