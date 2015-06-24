#!/usr/bin/env perl 

=head1 NAME

$0 - Convert SNP Fasta alignment into binary matrix required for Shiny

=head1 SYNOPSIS

  % snp_alignment_to_binary.pl --path filepath_prefix --config config_file [--pipeline --snp_order snp_order_file]

=head1 COMMAND-LINE OPTIONS

 --path           Prefix filepath for output of binary patterns, row names and column names and pattern-to-SNP ID mapping
 --config         Filepath to a .conf containing DB connection parameters and log directory
 --pipeline       Boolean indicating if SNP alignment should be retrieved from pipeline_snp_alignment table in DB
                    (tmp table used during the loading pipeline run) instead of snp_alignment table.
 [--snp_order]    File containing SNP IDs ordered by their corresponding columns in the snp alignment.

 
=head1 DESCRIPTION

Converts each column in the SNP alignment to corresponding set of binary
patterns.  Columns with >= 3 counts are printed.  If the snp variations
can represented by two columns, only one column is printed (since they are
inverse of each other). 

SNPs can have repeated presence/absence distributions. To reduce the search space
only unique binary patterns are stored and then SNP IDs that map to a particular
pattern are recorded. Binary patterns are determined by genome order and SNP presence/absence.

The binary matrix is printed as a single string of 1/0 in 8-bit format. Row names and column names
are print separately.  The argument --path specifies the filepath that will be appended to the
files:
  1) Binary string file will have suffix: *_binary.bin
  2) Row names or pattern IDs file will have suffix: *_rows.txt
  3) Column names or genome IDs file will have suffix: *_columns.txt
  4) Pattern-to-SNP ID mapping will have suffix: *_mapping.txt

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Carp qw/croak carp/;
use Config::Tiny;
use Log::Log4perl qw(get_logger);
use Bio::SeqIO;
use lib "$FindBin::Bin/../";
use Data::Bridge;
use Data::Dumper;
use List::Util qw/sum/;


# Get options
my ($config_filepath, 
	$filepre, $pipeline, $snpo_file,
	$log_dir, $threshold
);

$pipeline = 0;

GetOptions(
    'config=s'  => \$config_filepath,
    'path=s' => \$filepre,
    'pipeline'  => \$pipeline,
    'snp_order=s' => \$snpo_file,

) or ( system( 'pod2text', $0 ), exit -1 );

croak "Error: missing argument. You must supply a output filepath.\n" . system ('pod2text', $0) unless $filepre;
croak "Error: missing argument. You must supply a configuration filepath.\n" . system ('pod2text', $0) unless $config_filepath;
croak "Error: missing argument. You must supply file containing SNP ID order when using --pipeline mode.\n" . system ('pod2text', $0) if $pipeline && !$snpo_file;
if(my $conf = Config::Tiny->read($config_filepath)) {
	$log_dir = $conf->{dir}->{log};
	$threshold = $conf->{snp}->{significant_count_threshold};
} else {
	die Config::Tiny->error();
}

# Threshold for inclusion of snp alleles in binary matrix
$threshold = 3 unless $threshold;

# Setup logger
my $logger = init($log_dir);
$logger->info("<<BEGIN Superphy SNP data conversion");

# Nucleotide columns
my %nuc_col = (
	A => 0,
	T => 1,
	G => 2,
	C => 3,
	'-' => 4
);
my @col_nuc = qw(A T G C -);

# Pattern storage
my %unique_patterns;
my %pattern_mapping;
my $pattern_id = 1;

# Do binary conversion
my $table = $pipeline ? 'pipeline_snp_alignment' : 'snp_alignment';
my $genome_order = binarize($table);
$logger->info("Binary conversion complete.");

# Write patterns to file
print_patterns(\%unique_patterns, \%pattern_mapping, $genome_order, $filepre);
$logger->info("Patterns printed to file.");

$logger->info("END>>");

###############
## Subs
###############

# Setup logging
sub init {
	my $dir = shift;

    # config
    my $conf = q(
        log4perl.logger                    = INFO, FileApp
        log4perl.appender.FileApp          = Log::Log4perl::Appender::File
        log4perl.appender.FileApp.filename = ).$dir.q(snp_alignment_to_binary.log
        log4perl.appender.FileApp.layout   = PatternLayout
        log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n
    );

    # Initialize logging behaviour
    Log::Log4perl->init(\$conf);

    # Obtain a logger instance
    my $logger = get_logger();

   return $logger;
}



sub binarize {
	my $snp_table = shift;
	my $snpo_file = shift;

	my @genome_order;
	
	# Connect to database
	my $dbBridge = Data::Bridge->new(config => $config_filepath);

	# Get alignment length
	my $dbh = $dbBridge->dbh;
	my ($l) = $dbh->selectrow_array("SELECT aln_column FROM $snp_table LIMIT 1");

	$logger->info("Alignment length: $l.");


	# Get SNP IDs
	my @snp_order;
	if($snpo_file) {
		# Read snp order from file
		# Needed since new SNPs are added during loading pipeline and are not yet in DB

	} else {
		# Load SNP ID <-> column mapping from DB
		my $stmt1 = qq/SELECT snp_core_id FROM snp_core WHERE aln_column IS NOT NULL ORDER BY aln_column/;
		my $sth1 = $dbh->prepare($stmt1);
		$sth1->execute();
		while(my ($s) = $sth1->fetchrow_array()) {
			push @snp_order, $s;
		}
	}
	
	$logger->info("Number of snps: ".scalar(@snp_order).".");


	# Get genome order
	my $stmt2 = qq/SELECT name FROM $snp_table WHERE name != 'core' ORDER BY name/;
	my $sth2 = $dbh->prepare($stmt2);
	$sth2->execute();
	while(my ($n) = $sth2->fetchrow_array()) {
		push @genome_order, $n;
	}
	$logger->info("Number of genomes: ".scalar(@genome_order).".");


	# Prepare statements for getting column data
	my $increment = 1000;
	my $stmt3 = qq/SELECT substring(alignment FROM ? FOR $increment) FROM $snp_table WHERE name != 'core' ORDER BY name/;
	my $col_sth = $dbh->prepare($stmt3);

	
	my $num_genomes = scalar @genome_order;
	my @starting_column = (0) x $num_genomes;

	# Iterate through columns in alignment, block at a time
	for(my $i = 1; $i <= $l; $i += $increment) {
		$col_sth->execute($i);

		$logger->debug("Fetching columns $i..".($i+100)."\n");

		my @blocks;

		while(my ($block) = $col_sth->fetchrow_array()) {
			push @blocks, [ split(//, $block) ];
		}

		# Iterate through individual columns in block
		my $block_len = @{$blocks[0]};
		for(my $j = 0; $j < $block_len; $j++) {
			# Initialize arrays
			my @freq = (0,0,0,0,0);
			my @columns = ( 
				[ @starting_column ],
				[ @starting_column ],
				[ @starting_column ],
				[ @starting_column ],
				[ @starting_column ],
			);

			# Iterate through genome positions
			my $n = 0;
			for(my $n = 0; $n < @blocks; $n++) {
				my $c = $blocks[$n][$j];
				$logger->logdie("Error: missing position ".($i+$j)." in alignment for $n genome") unless $c;

				my $nt = uc($c);
				my $p = $nuc_col{$nt};
				$p = 4 unless defined $p; # Unknown characters set as '-'

				$freq[$p]++; # Increment counts
				$columns[$p][$n] = 1; # Set position to 'TRUE'
			}

			my $snp_id = $snp_order[$i+$j];
			binarize_column(\@freq, \@columns, $snp_id);

		}
		
		$logger->info("\tcolumns $i completed.") if ($i-1) % 10000 == 0;
		#last if $i > 100000;

	}

	return \@genome_order;
}


sub binarize_column {
	my $freqs = shift;
	my $columns = shift;
	my $snp_id = shift;

	my @final_columns;
	my $title = "$snp_id\_";
	my @titles;

	# Verify that counts are above significance threshold
	my @counts = sort {$b <=> $a} @$freqs;
	my $tot_variations = sum @counts[1..$#counts]; # Omit background allele from counts

	# If total variations are not above threshold, none of the possible binary columns will be significant
	return unless $tot_variations > $threshold;

	my $num_alleles = 0;
	map { $num_alleles++ if $_ > 0 } @$freqs;
	
	if($num_alleles == 2) {
		# Case 1: two snp alleles, only print one binary column

		my $title1 = '';
		my $title0 = '';
		foreach my $col (values %nuc_col) {
			if($freqs->[$col] > 0) {
				if($columns->[$col]->[0]) {
					# Select column with 1 in position 1 - for consistent pattern compression
					push @final_columns, $columns->[$col];
					$title1 = $col_nuc[$col];
				}
				else {
					$title0 = $col_nuc[$col];
				}
			}
		}

		$logger->logdie("Error: breakdown in binary SNP $snp_id") unless $title1 && $title0;
		push @titles, $title . "$title1=1&$title0=0";

	}
	else {
		# Case 2: Multiple alleles, only print columns with freq >= 3

		foreach my $col (values %nuc_col) {
			if($freqs->[$col] > $threshold) {
				# Above threshold

				if($columns->[$col]->[0]) {
					# Column with 1 in position 1, save as is - for consistent pattern compression
					push @final_columns, $columns->[$col];
					push @titles, $title.$col_nuc[$col].'=1';
				}
				else {
					# Flip binary pattern, so 1 in position 1 - for consistent pattern compression
					push @final_columns, invert($columns->[$col]);
					push @titles, $title.$col_nuc[$col].'=0';
				}
			}
		}
	}

	
	# Take final columns and do pattern compression
	# This saves binary columns and pattern <-> SNP ID mapping
	store_patterns(\@titles, \@final_columns);
	
	
}

# Flip binary 
sub invert {
	my $column = shift;

	for(my $i = 0; $i < @$column; $i++) {
		$column->[$i] = $column->[$i] ? 0 : 1;
	}

	return $column;
}

# Store unique patterns, map pattern ID to SNP ID
sub store_patterns {
	my $ids = shift;
	my $columns = shift;

	my $i = 0;
	foreach my $col (@$columns) {
		my $binary_string = join('', @$col);

		my $pattern_hash;
		if($unique_patterns{$binary_string}) {
			$pattern_hash = $unique_patterns{$binary_string};

		}
		else {
			$pattern_hash = {
				id => $pattern_id,
				column => $col
			};

			$unique_patterns{$binary_string} = $pattern_hash;
			$pattern_mapping{$pattern_id} = [];

			$pattern_id++;
		}

		push @{$pattern_mapping{$pattern_hash->{id}}}, $ids->[$i];

		$i++;
	}

}

# Print patterns and pattern mapping to file
sub print_patterns {
	my $pattern_hashref = shift;
	my $pattern_mapping = shift;
	my $genome_order = shift;
	my $filepre = shift;
	
	# File names
	my $binary_file = $filepre . '_binary.bin';
	my $row_file = $filepre . '_rows.txt';
	my $col_file = $filepre . '_columns.txt';
	my $map_file = $filepre . '_mapping.txt';

	# Print column names
	open(my $col, '>', $col_file) or $logger->logdie("Error: unable to write to file $col_file ($!)");
	print $col join("\n", @$genome_order),"\n";
	close $col;

	# Print patterns
	# 1/0 characters printed in 8-bit binary
	# Row names print to separate file 
	
	open(my $out, '>', $binary_file) or $logger->logdie("Error: unable to write to file $binary_file ($!)");
	open(my $row, '>', $row_file) or $logger->logdie("Error: unable to write to file $row_file ($!)");
	
	my $first = 1;
	foreach my $pattern (values %$pattern_hashref) {
		# Print row name
		print $row $pattern->{id},"\n";

		# Print binary string
		print $out map { pack('c', $_) } @{$pattern->{column}};
	}

	close $out;
	close $row;

	# Print mapping
	# Format:
	# pattern_id\tsnp_ids_comma_delim
	open(my $map, '>', $map_file) or $logger->logdie("Error: unable to write to file $map_file ($!)");
	foreach my $pattern_id (keys %$pattern_mapping) {
		print $map $pattern_id,"\t",join(',', @{$pattern_mapping{$pattern_id}}),"\n";
	}
	close $map;
}