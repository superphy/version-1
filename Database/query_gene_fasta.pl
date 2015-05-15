#!/usr/bin/env perl 
=head1 NAME

$0 - Downloads all Antimicrobial Resistance Gene and Virulence Factor sequences from the db into multi-fasta files. 

=head1 SYNOPSIS

  % query_gene_fasta.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.
 
     --AND--
     
 --amr            Specify an amr output fasta file.
 --vf             Specify an vf output fasta file.
 
     --OR--
     
 --combined       Specify a single output fasta file for vf and amr

=head1 DESCRIPTION

Script to download all Antimicrobial Resistance Gene and Virulence Factor sequences from the database to separate multi-fasta files
to use for generating vir/amr data and the phylogenetic tree, etc.

Sequences will have the tag:
>[AMR|VF]_feature_id|<uniquename>|<name>

=head1 AUTHOR

Matt Whiteside

=cut

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Data::Bridge;

my $db_bridge = Data::Bridge->new();

my ($AMROUTPUT, $VFOUTPUT, $OUTPUT);

GetOptions(
	'amr=s'	=> \$AMROUTPUT,
	'vf=s'	=> \$VFOUTPUT,
	'combined=s' => \$OUTPUT,
) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
unless($OUTPUT || ($VFOUTPUT && $AMROUTPUT)) {
	croak "Missing argument. You must supply output file(s).\n" . system ('pod2text', $0);
}
if(($OUTPUT && $VFOUTPUT) || ($OUTPUT && $AMROUTPUT)) {
	croak "Invalid arguments. You must supply a single combined output file or separate output files for vf and amr genes.\n"
		. system ('pod2text', $0);
}


my $schema = $db_bridge->dbixSchema;

# Obtain all amr genes
my $amr_gene_rs = $schema->resultset('Feature')->search(
	{
        'type.name' => "antimicrobial_resistance_gene"
	},
	{
		column  => [qw/feature_id uniquename residues/],
		join    => ['type'],
	}
);

# Obtain all vf genes
my $vf_gene_rs = $schema->resultset('Feature')->search(
	{
        'type.name' => "virulence_factor"
	},
	{
		column  => [qw/feature_id uniquename name residues/],
		join    => ['type'],
	}
);

# Write to FASTA file
if($OUTPUT) {
	
	open(my $out, ">", $OUTPUT) or die "Error: unable to write to file $OUTPUT ($!)\n";
	
	while (my $gene = $amr_gene_rs->next) {
		print $out '>AMR_' . $gene->feature_id . '|' . $gene->uniquename . "\n" . $gene->residues . "\n";
	}
	while (my $gene = $vf_gene_rs->next) {
		print $out '>VF_' . $gene->feature_id . '|' . $gene->uniquename . '|'. $gene->name ."\n" . $gene->residues . "\n";
	}
	
	close $out;
	
} else {
	
	open(my $out, ">", $AMROUTPUT) or die "Error: unable to write to file $AMROUTPUT ($!)\n";
	
	while (my $gene = $amr_gene_rs->next) {
		print $out '>AMR_' . $gene->feature_id . '|' . $gene->uniquename . "\n" . $gene->residues . "\n";
	}
	
	close $out;
	
	open($out, ">", $VFOUTPUT) or die "Error: unable to write to file $VFOUTPUT ($!)\n";
	
	while (my $gene = $vf_gene_rs->next) {
		print $out '>VF_' . $gene->feature_id . '|' . $gene->uniquename . '|'. $gene->name ."\n" . $gene->residues . "\n";
	}
	
	close $out;
}
