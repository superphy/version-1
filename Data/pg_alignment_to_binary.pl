#!/usr/bin/env perl 

=head1 NAME

$0 - Prepare pangenome presence/absence alignment for input into Shiny

=head1 SYNOPSIS

  % pg_alignment_to_binary.pl --path filepath_prefix --config config_file [--pipeline --pg_order pg_order_file]

=head1 COMMAND-LINE OPTIONS

 --path           Prefix filepath for output of binary patterns, row names and column names and pattern-to-SNP ID mapping
 --rfile          Filename that R Data will be saved to
 --config         A *.conf file containing DB connection parameters and log directory
 --pipeline       Boolean indicating if PG alignment should be retrieved from pipeline_pg_alignment table in DB
                    (tmp table used during the loading pipeline run) instead of pg_alignment table.
 [--pg_order]     File containing Pangenome IDs ordered by their corresponding columns in the pg alignment.

 
=head1 DESCRIPTION

Filters columns in the pangenome (PG) alignment.  Columns with >= 3 counts are printed.

PG distributions can have repeated presence/absence patterns. To reduce the search space
only unique binary patterns are stored and then PG IDs that map to a particular
pattern are recorded. Binary patterns are determined by genome order and PG presence/absence.

The binary matrix is printed as a single string of 1/0 in 8-bit format. Row names and column names
are print separately.  The argument --path specifies the filepath that will be appended to the
files:
  1) Binary string file will have suffix: *_binary.bin
  2) Row names or pattern IDs file will have suffix: *_rows.txt
  3) Column names or genome IDs file will have suffix: *_columns.txt
  4) Pattern-to-PG ID mapping will have suffix: *_mapping.txt
  5) Function-to-PG mapping will have suffix: *_functions.txt
These data files are loaded into R, converted to R data objects and then saved to the file specified
by --rfile.  The R data objects generated are:
  1) pgm: A matrix of 1/0 values for presence absence of PGs. Column names are genome IDs, rownames
       are pattern IDs
  2) pattern_to_pg: A list of lists mapping a pattern ID to PG IDs that have that distribution pattern.
       Lists are named by pattern IDs.
  3) df_region_meta: A data.frame of function descriptions for PG regions. Row names are PG IDs.

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
	$filepre, $rfile, $pipeline, $pgo_file,
	$log_dir, $threshold
);

$pipeline = 0;

GetOptions(
    'config=s'  => \$config_filepath,
    'path=s' => \$filepre,
    'rfile=s' => \$rfile,
    'pipeline'  => \$pipeline,
    'pg_order=s' => \$pgo_file,

) or ( system( 'pod2text', $0 ), exit -1 );

croak "Error: missing argument. You must supply a output filepath.\n" . system ('pod2text', $0) unless $filepre;
croak "Error: missing argument. You must supply a output R data file.\n" . system ('pod2text', $0) unless $rfile;
croak "Error: missing argument. You must supply a configuration filepath.\n" . system ('pod2text', $0) unless $config_filepath;
croak "Error: missing argument. You must supply file containing pangneome ID order when using --pipeline mode.\n" . system ('pod2text', $0) 
	if $pipeline && !$pgo_file;
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
$logger->info("<<BEGIN Superphy PG data conversion");

# File names
$filepre .= '_' unless $filepre =~ m/\/$/;
my $binary_file = $filepre . 'binary.bin';
my $row_file = $filepre . 'rows.txt';
my $col_file = $filepre . 'columns.txt';
my $map_file = $filepre . 'mapping.txt';
my $pgf_file = $filepre . 'functions.txt';

# Pattern storage
my %unique_patterns;
my %pattern_mapping;
my $pattern_id = 1;

# Connect to database
my $dbBridge = Data::Bridge->new(config => $config_filepath);
my $dbh = $dbBridge->dbh;

# Retrieve PGs and associated function descriptions
my ($pg_order, $pg_functions) = pg_data($pgo_file);
	
# Do binary conversion
my $table = $pipeline ? 'pipeline_pg_alignment' : 'pg_alignment';
my $genome_order = binarize($dbh, $table, $pg_order);
$logger->info("Pattern compression complete");

# Write functions to file for SNPs that passed criteria
print_functions(\%pattern_mapping, $pg_functions);
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
        log4perl.appender.FileApp.filename = ).$dir.q(pg_alignment_to_binary.log
        log4perl.appender.FileApp.layout   = PatternLayout
        log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n
    );

    # Initialize logging behaviour
    Log::Log4perl->init(\$conf);

    # Obtain a logger instance
    my $logger = get_logger();

   return $logger;
}


# Get PG IDs & functions
sub pg_data {
	my $pgo_file = shift;

	my @pg_order;
	my %pg_functions;

	if($pgo_file) {
		# Read snp order from file
		# Needed since new SNPs are added during loading pipeline and are not yet in DB

	} else {
		# Load SNP ID <-> column mapping from DB, include function
		my ($type_id) = $dbh->selectrow_array(q/SELECT cvterm_id FROM cvterm WHERE name = 'panseq_function'/);

		my $stmt1 = "WITH fps AS ( " .
		"SELECT feature_id, value FROM featureprop WHERE type_id = $type_id ".
		") ".
		"SELECT c.pangenome_region_id, c.aln_column, p.value FROM core_region c ".
		"LEFT JOIN fps p ON c.pangenome_region_id = p.feature_id ".
		"ORDER by c.aln_column";
		my $sth1 = $dbh->prepare($stmt1);
		$sth1->execute();

		while(my $snp_row = $sth1->fetchrow_arrayref) {
			my ($pg_id, $col, $func) = @$snp_row;

			push @pg_order, $pg_id;
			$pg_functions{$pg_id} = $func // 'NA';
		}
	}
	
	$logger->info("Number of regions: ".scalar(@pg_order).".");

	return(\@pg_order, \%pg_functions);
}


# Convert alignment to binary matrix
sub binarize {
	my $dbh = shift;
	my $pg_table = shift;
	my $pg_order = shift;
	
	my @genome_order;
	
	# Get alignment length
	my ($l) = $dbh->selectrow_array("SELECT aln_column FROM $pg_table LIMIT 1");
	$logger->info("Alignment length: $l.");

	# Get genome order
	my $stmt2 = qq/SELECT name FROM $pg_table WHERE name != 'core' ORDER BY name/;
	my $sth2 = $dbh->prepare($stmt2);
	$sth2->execute();
	while(my ($n) = $sth2->fetchrow_array()) {
		push @genome_order, $n;
	}
	$logger->info("Number of genomes: ".scalar(@genome_order).".");


	# Prepare statements for getting column data
	my $increment = 10000;
	my $stmt3 = qq/SELECT substring(alignment FROM ? FOR $increment) FROM $pg_table WHERE name != 'core' ORDER BY name/;
	my $col_sth = $dbh->prepare($stmt3);

	my $num_genomes = scalar @genome_order;
	
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
			# Current pg column
			my @column;

			# Iterate through genomes, adding presence/absence
			for(my $n = 0; $n < @blocks; $n++) {
				my $c = $blocks[$n][$j];
				$logger->logdie("Error: missing position ".($i+$j)." in alignment for $n genome") unless defined $c;

				push @column, $c;
			}

			my $p = $i+$j-1;
			my $pg_id = $pg_order->[$p];
			$logger->logdie("Error: PG index out of bounds ($p)") unless $pg_id;

			# Verify that counts are above significance threshold
			my $pg_count = sum @column;
			next if($pg_count < $threshold || $pg_count > $num_genomes-$threshold);

			# Do compression on pangenome pattern
			if($column[0]) {
				# 1 in first position, save as it
				my $title = "$pg_id\_with=1";
				store_patterns($title, \@column);
			}
			else {
				# Invert to increase pattern re-use
				my $title = "$pg_id\_with=0";
				store_patterns($title, invert(\@column));
			}

		}
		
		$logger->info("\tcolumns $i completed") if ($i-1) % 10000 == 0;

	}

	return \@genome_order;
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
	my $id = shift;
	my $column = shift;

	
	my $binary_string = join('', @$column);
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

	push @{$pattern_mapping{$lookup_id}}, $id;

}


# Print PG function descriptions
sub print_functions {
	my $pattern_mapping = shift;
	my $pg_functions = shift;
	
	open(my $out, '>', $pgf_file) or $logger->logdie("Error: unable to write to file $pgf_file ($!)");
	print $out join("\t", 'pg_id', 'function'),"\n";
	foreach my $pg_arrayref (values %$pattern_mapping) {
		foreach my $pg_string (@$pg_arrayref) {
			my ($pg_id) = ($pg_string =~ m/^(\d+)_/);
			$logger->logdie("Error: malformed PG ID string $pg_string") unless $pg_id;
			$logger->logdie("Error: no function defined for PG $pg_id") unless $pg_functions->{$pg_id};
			print $out join("\t", $pg_id, $pg_functions->{$pg_id}),"\n";
		}
	}

	close $out;
}


# Print patterns and pattern mapping to file
sub print_patterns {
	my $pattern_hashref = shift;
	my $pattern_mapping = shift;
	my $genome_order = shift;
	
	my $pattern_length = scalar(@$genome_order)-1;

	# Print row names
	open(my $row, '>', $row_file) or $logger->logdie("Error: unable to write to file $row_file ($!)");
	print $row join("\n", @$genome_order),"\n";
	close $row;

	# Print patterns
	# 1/0 characters printed in 8-bit binary
	# Column names print to separate file 
	open(my $out, '>:raw', $binary_file) or $logger->logdie("Error: unable to write to file $binary_file ($!)");
	open(my $col, '>', $col_file) or $logger->logdie("Error: unable to write to file $col_file ($!)");
	
	my $first = 1;
	foreach my $packed_pattern (keys %$pattern_hashref) {
		# Print row name
		my $id = $pattern_hashref->{$packed_pattern};
		print $col $id,"\n";

		# Expand pattern string
		# Pattern may be padded with null values to fill bytes, cut this part off
		my @binary_array = split(//, unpack("b*", $packed_pattern));
		@binary_array = @binary_array[0..$pattern_length];

		foreach my $c (@binary_array) {
			print $out pack('c', $c);
		}
	}

	close $out;
	close $col;

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
		q/snpm = matrix(x, ncol=cnum, nrow=rnum, byrow=FALSE)/,
		q/rm(x); gc()/,
		q/rownames(pgm) = row_names; colnames(pgm) = col_names/,
		qq/df_region_meta = read.table('$pgf_file', header=TRUE, sep="\t", check.names=FALSE, row.names=1, colClasses=c('character','character'))/,
		qq/y = strsplit(readLines('$map_file', n=-1), "\t")/,
		q/pattern_to_pg = sapply(y, function(x) strsplit(x[2], ","))/,
		q/names(pattern_to_pg) = sapply(y, `[[`, 1)/,
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
	my $rcmd = qq/save(pgm,df_region_meta,pattern_to_pg,file='$rfile')/;
	my $rs2 = $R->run($rcmd, q/print('SUCCESS')/);

	unless($rs2 =~ m'SUCCESS') {
		$logger->logdie("Error: R save failed ($rs).\n");
	} else {
		$logger->info('R data saved')
	}

}