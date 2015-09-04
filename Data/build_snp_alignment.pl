#!/usr/bin/env perl 
use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;
use Time::HiRes qw( time );


=head1 NAME

$0 - Builds the snp_alignment table containing the global strings of snps for each genome

=head1 SYNOPSIS

  % build_snp_alignment.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.

=head1 DESCRIPTION


=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


# Connect to DB
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

# Build reference snp alignment
my $block_size = 1000;
my %strings;
my $now = my $begin = time();

# Retrieve all snp info
my $core_rs = $schema->resultset('SnpCore')->search(
	{
		#'snp_variations.allele' => { '!=' => '-'}
	},
	{
		#prefetch => [qw/snp_variations/],
		columns => [qw/allele aln_block aln_column/],
		#order_by => [qw/aln_block aln_column/]
	}
);
elapsed_time('Core query');

# Retrieve list of genomes
my $genome_rs = $schema->resultset('Feature')->search(
	{
		'type.name' => 'contig_collection',
	},
	{
		join => [qw/type/],
		#prefetch => { snp_variation_contig_collections => 'snp' },
		columns => [qw/feature_id/]
	}
);
my @genomes = map { $_->feature_id } $genome_rs->all;
elapsed_time('Genome query');

# Iterate through each column
my $num = 0;
while(my $core = $core_rs->next) {
	
	#elapsed_time('Start of new column');
	
	my %variations;
	my $nuc = $core->allele;
	
	# Save variations in memory
	my $var_rs = $core->snp_variations;
	while (my $var = $var_rs->next) {
		$variations{$var->contig_collection} = $var->allele;
	}
	#elapsed_time('Recorded variations');
	
	# Print out 
	foreach my $g (@genomes) {
		
		my $this_nuc = $nuc;
		if($variations{$g}) {
			$this_nuc = $variations{$g};
		}
		
		$strings{$g} .= $this_nuc;
		
	}
	#elapsed_time('Printed column');
	$num++;
	elapsed_time("$num columns printed") if $num % 1000 == 0;
	
}

$now = time();
printf("TOTAL RUNTIME: %.2f\n", $now - $begin);

# Set core alignment string
#my @core_seq; 
##$core_seq[$max_b][$block_size] = 0;
#
#while(my $core_snp = $core_rs->next) {
#	$core_seq[$core_snp->aln_block][$core_snp->aln_column] = $core_snp->allele;
#	
#}
#
## Obtain list of genomes in DB and their variations
#my $genome_rs = $schema->resultset('Feature')->search(
#	{
#		'type.name' => 'contig_collection',
#		'snp_variation_contig_collections.allele' => ''
#	},
#	{
#		join => [qw/type/],
#		prefetch => { snp_variation_contig_collections => 'snp' },
#		#columns => [qw/feature_id/]
#	}
#);
#
#my $num_done = 0;
#while(my $genome_row = $genome_rs->next) {
#	my $genome_id = $genome_row->feature_id;
#	
#	my @seq = @core_seq;
#	
#	#my $num_this_vars = 0;
#	my $snp_var_rs = $genome_row->snp_variation_contig_collections;
#	while(my $var_row = $snp_var_rs->next) {
#		my $core_snp = $var_row->snp;
#		
#		$seq[$core_snp->aln_block][$core_snp->aln_column] = $var_row->allele;
#		
#		#$num_this_vars++;
#		#print "Number of variations loaded: $num_this_vars.\n" if $num_this_vars % 1000 == 0;
#	}
#	$num_done++;
#	print "$num_done genomes done.\n" if $num_done % 100 == 0;
#	#last;
#	
#}
#
#exit(0);
#
#
#sub load_alignment {
#	my $genome_id = shift;
#	my $aln_arrayref = shift;
#	my $block_size = shift;
#	my $max_block = shift;
#	my $max_col = shift;
#	
#	my @aln_array = @$aln_arrayref;
#	
#	# block
#	my $block_string;
#	my $second_last = $max_block-1;
#	for my $b (0..$second_last) {
#		$block_string = join('', @{$aln_array[$b]});
#	} 
#		
#	
#	
#}

sub elapsed_time {
	my ($mes) = @_;
	
	my $time = $now;
	$now = time();
	printf("$mes: %.2f\n", $now - $time);
	
}
 