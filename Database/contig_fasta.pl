#!/usr/bin/env perl 
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;


=head1 NAME

$0 - Downloads all contigs into a single multi-fasta file. 

=head1 SYNOPSIS

  % contig_fasta.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.
 --output         Specify an output fasta file.

=head1 DESCRIPTION

Script to download all contig sequences from the database to a single multi-fasta file, 
to use for generating vir/amr data and the phylogenetic tree, etc.

Sequences will have the tag:
>lcl|contig_collection_feature_id|contig_feature_id

=head1 AUTHOR

Akiff Manji, Matt Whiteside

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $OUTPUT, $PUBLIC);
$PUBLIC = 0;

GetOptions(
	'config=s'  => \$CONFIG,
	'output=s'	=> \$OUTPUT,
	'nouploads' => \$PUBLIC
) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
croak "Missing argument. You must supply an output directory.\n" . system ('pod2text', $0) unless $OUTPUT;
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

my @rs;

# Obtain all contigs and contig collections in feature table
my $contig_rs = $schema->resultset('Feature')->search(
	{
        'type.name' => "contig",
        'type_2.name' => "part_of",
        
	},
	{
		column  => [qw/feature_id uniquename residues/],
		'+select' => [qw/feature_relationship_subjects.object_id/],
		'+as' => [qw/object_id/],
		join    => [
			'type',
			{'feature_relationship_subjects' => 'type'}
		],
	}
);

push @rs, $contig_rs;

# Obtain all uploaded contigs and contig collections in private
unless($PUBLIC) {
	my $contig_rs2 = $schema->resultset('PrivateFeature')->search(
		{
	        'type.name' => "contig",
	        'type_2.name' => "part_of",
	        
		},
		{
			column  => [qw/feature_id uniquename residues/],
			'+select' => [qw/private_feature_relationship_subjects.object_id/],
			'+as' => [qw/object_id/],
			join    => [
				'type',
				{'private_feature_relationship_subjects' => 'type'}
			],
		}
	);
	
	push @rs, $contig_rs2;
	
}

# Write to FASTA file
my @prefix = ('public_','private_');

open(my $out, ">", $OUTPUT) or die "Error: unable to write to file $OUTPUT ($!)\n";

foreach my $contigs (@rs) {
	my $p = shift @prefix;
	while (my $contig = $contigs->next) {
		print $out ">lcl|$p" . $contig->get_column('object_id') . "|$p" . $contig->feature_id . "\n" . $contig->residues . "\n";
	}
}

close $out;