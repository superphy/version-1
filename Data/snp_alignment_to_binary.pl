#!/usr/bin/env perl 

=head1 NAME

$0 - Convert SNP Fasta alignment into binary matrix required for Shiny

=head1 SYNOPSIS

  % snp_alignment_to_binary.pl --path filepath_prefix --config config_file [--pipeline --snp_order snp_order_file]

=head1 COMMAND-LINE OPTIONS

 --path           Prefix filepath for output of binary patterns, row names and column names and pattern-to-SNP ID mapping
 --rfile          Filename that R Data will be saved to
 --config         A *.conf file containing DB connection parameters and log directory
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
  5) Function-to-SNP mapping will have suffix: *_functions.txt
These data files are loaded into R, converted to R data objects and then saved to the file specified
by --rfile.  The R data objects generated are:
  1) snpm: A matrix of 1/0 values for presence absence of SNPs. Column names are genome IDs, rownames
       are pattern IDs
  2) pattern_to_snp: A list of lists mapping a pattern ID to SNP IDs that have that distribution pattern.
       Lists are named by pattern IDs.
  3) df_marker_meta: A data.frame of function descriptions for SNP regions. Row names are SNP IDs.

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
use Statistics::R;


# Get options
my ($config_filepath, 
	$filepre, $rfile, $pipeline, $snpo_file,
	$log_dir, $threshold
);

$pipeline = 0;

GetOptions(
    'config=s'  => \$config_filepath,
    'path=s' => \$filepre,
    'rfile=s' => \$rfile,
    'pipeline'  => \$pipeline,
    'snp_order=s' => \$snpo_file,

) or ( system( 'pod2text', $0 ), exit -1 );

croak "Error: missing argument. You must supply a output filepath.\n" . system ('pod2text', $0) unless $filepre;
croak "Error: missing argument. You must supply a output R data file.\n" . system ('pod2text', $0) unless $rfile;
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

# File names
$filepre .= '_' unless $filepre =~ m/\/$/;
my $binary_file = $filepre . 'binary.bin';
my $row_file = $filepre . 'rows.txt';
my $col_file = $filepre . 'columns.txt';
my $map_file = $filepre . 'mapping.txt';
my $snpf_file = $filepre . 'functions.txt';

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

# Connect to database
my $dbBridge = Data::Bridge->new(config => $config_filepath);
my $dbh = $dbBridge->dbh;

# Retrieve SNPs and associated function descriptions
my ($snp_order, $snp_functions) = snp_data($snpo_file);
	
# Do binary conversion
my $table = $pipeline ? 'pipeline_snp_alignment' : 'snp_alignment';
my $genome_order = binarize($dbh, $table, $snp_order);
$logger->info("Binary conversion complete");

# Write functions to file for SNPs that passed criteria
print_functions(\%pattern_mapping, $snp_functions);
$logger->info("Functions printed to file");

# Write patterns to file
print_patterns(\%unique_patterns, \%pattern_mapping, $genome_order);
$logger->info("Patterns printed to file");

# Save Rdata
rsave($binary_file, $row_file, $col_file, $map_file, $rfile);
$logger->info("R conversion complete");

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


# Get SNP IDs & functions
sub snp_data {
	my $snpo_file = shift;

	my @snp_order;
	my %snp_functions;

	if($snpo_file) {
		# Read snp order from file
		# Needed since new SNPs are added during loading pipeline and are not yet in DB

	} else {
		# Load SNP ID <-> column mapping from DB, include function
		my ($type_id) = $dbh->selectrow_array(q/SELECT cvterm_id FROM cvterm WHERE name = 'panseq_function'/);

		my $stmt1 = "WITH fps AS ( " .
			"SELECT feature_id, value FROM featureprop WHERE type_id = $type_id ".
			") ".
			"SELECT snp_core_id, pangenome_region_id, aln_column, p.value ".
			"FROM snp_core c, feature f ".
			"LEFT JOIN fps p ON f.feature_id = p.feature_id ".
		    "WHERE c.pangenome_region_id = f.feature_id AND ".
		    "c.aln_column IS NOT NULL ORDER BY c.aln_column";
		my $sth1 = $dbh->prepare($stmt1);
		$sth1->execute();

		while(my $snp_row = $sth1->fetchrow_arrayref) {
			my ($snp_id, $pg_id, $col, $func) = @$snp_row;

			push @snp_order, $snp_id;
			$snp_functions{$snp_id} = $func // 'NA';
		}

	}
	
	$logger->info("Number of snps: ".scalar(@snp_order).".");

	return(\@snp_order, \%snp_functions);
}


# Convert alignment to binary matrix
sub binarize {
	my $dbh = shift;
	my $snp_table = shift;
	my $snp_order = shift;
	
	my @genome_order;
	
	# Get alignment length
	my ($l) = $dbh->selectrow_array("SELECT aln_column FROM $snp_table LIMIT 1");
	$logger->info("Alignment length: $l.");

	# Get genome order
	my $stmt2 = qq/SELECT name FROM $snp_table WHERE name != 'core' ORDER BY name/;
	my $sth2 = $dbh->prepare($stmt2);
	$sth2->execute();
	while(my ($n) = $sth2->fetchrow_array()) {
		push @genome_order, $n;
	}
	$logger->info("Number of genomes: ".scalar(@genome_order).".");


	# Prepare statements for getting column data
	my $increment = 10000;
	my $stmt3 = qq/SELECT substring(alignment FROM ? FOR $increment) FROM $snp_table WHERE name != 'core' ORDER BY name/;
	my $col_sth = $dbh->prepare($stmt3);

	
	my $num_genomes = scalar @genome_order;
	my @starting_column = (0) x $num_genomes;

	# Iterate through columns in alignment, block at a time
	for(my $i = 1; $i <= $l; $i += $increment) {
		$col_sth->execute($i);

		$logger->debug("Fetching columns $i..".($i+$increment)."\n");

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

			my $s = $i+$j-1;
			my $snp_id = $snp_order->[$s];
			$logger->logdie("Error: SNP index out of bounds ($s)") unless $snp_id;

			binarize_column(\@freq, \@columns, $snp_id);

		}
		
		$logger->info("\tcolumns $i completed") if ($i-1) % 10000 == 0;
		last if $i > 100000;

	}

	return \@genome_order;
}


# Convert single alignment column to multiple binary columns
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


# Store unique compressed patterns, map pattern ID to SNP ID
sub store_patterns {
	my $ids = shift;
	my $columns = shift;

	my $i = 0;
	foreach my $col (@$columns) {
		my $binary_string = join('', @$col);
		my $packed_string = pack 'b*', $binary_string;

		my $lookup_id;
		if($unique_patterns{$packed_string}) {
			$lookup_id = $unique_patterns{$packed_string};

		}
		else {

			$unique_patterns{$packed_string} = $pattern_id;
			$pattern_mapping{$pattern_id} = [];
			$lookup_id = $pattern_id;

			$pattern_id++;
		}

		push @{$pattern_mapping{$lookup_id}}, $ids->[$i];

		$i++;
	}
}


# Print SNP function descriptions
sub print_functions {
	my $pattern_mapping = shift;
	my $snp_functions = shift;
	
	my %printed;
	open(my $out, '>', $snpf_file) or $logger->logdie("Error: unable to write to file $snpf_file ($!)");
	print $out join("\t", 'snp_id', 'function'),"\n";
	foreach my $snp_arrayref (values %$pattern_mapping) {
		foreach my $snp_string (@$snp_arrayref) {
			my ($snp_id) = ($snp_string =~ m/^(\d+)_/);
			$logger->logdie("Error: malformed SNP ID string $snp_string") unless $snp_id;
			next if $printed{$snp_id};
			$logger->logdie("Error: no function defined for SNP $snp_id") unless $snp_functions->{$snp_id};
			print $out join("\t", $snp_id, $snp_functions->{$snp_id}),"\n";
			$printed{$snp_id} = 1;
		}
	}

	close $out;
}


# Print patterns and pattern mapping to file
sub print_patterns {
	my $pattern_hashref = shift;
	my $pattern_mapping = shift;
	my $genome_order = shift;
	

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
	foreach my $packed_pattern (keys %$pattern_hashref) {
		# Print row name
		my $id = $pattern_hashref->{$packed_pattern};
		print $row $id,"\n";

		# Expand pattern string
		my @binary_array = split(//, unpack("b*", $packed_pattern));

		# Print binary string in 8-bit character encoding
		print $out map { pack('c', $_) } @binary_array;
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

	return ($binary_file, $row_file, $col_file, $map_file);
}


# Convert to R data file
sub rsave {
	my ($binary_file, $row_file, $col_file, $map_file, $rfile) = @_;

	my $R = Statistics::R->new();
	
	my @rcmds = (
		qq/row_names = readLines('$row_file', n=-1); rnum = length(row_names)/,
		qq/col_names = readLines('$col_file', n=-1); cnum = length(col_names)/,
		qq/x = readBin(con='$binary_file', what='raw', n=rnum*cnum)/,
		q/x = as.integer(x)/,
		q/snpm = matrix(x, ncol=cnum, nrow=rnum, byrow=TRUE)/,
		q/rm(x); gc()/,
		q/rownames(snpm) = row_names; colnames(snpm) = col_names/,
		qq/df_marker_meta = read.table('$snpf_file', header=TRUE, sep="\t", check.names=FALSE, row.names=1, colClasses=c('character','character'))/,
		qq/y = strsplit(readLines('$map_file', n=-1), "\t")/,
		q/pattern_to_snp = sapply(y, function(x) strsplit(x[2], ","))/,
		q/names(pattern_to_snp) = sapply(y, `[[`, 1)/,
		q/rm(y); gc()/,
		q/print('SUCCESS')/
	);

	# Load matrix and function files
	my $rs = $R->run(@rcmds);

	unless($rs =~ m'SUCCESS') {
		$logger->logdie("Error: R data loading failed ($rs).\n");
	} 
	else {
		$logger->info('Data loaded into R')
	}

	# Convert to R binary file
	my $rcmd = qq/save(snpm,df_marker_meta,pattern_to_snp,file='$rfile')/;
	my $rs2 = $R->run($rcmd, q/print('SUCCESS')/);

	unless($rs2 =~ m'SUCCESS') {
		$logger->logdie("Error: R save failed ($rs).\n");
	} else {
		$logger->info('R data saved')
	}

}