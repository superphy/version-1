#!/usr/bin/env perl 

=head1 NAME

$0 - Fix snp alignment to sync with snp_core table and pangenome sequences

=head1 SYNOPSIS

  % rebuild_snp_alignment.pl --config config_file

=head1 COMMAND-LINE OPTIONS

 --config         A *.conf file containing DB connection parameters and log directory
 
=head1 DESCRIPTION

The SNP alignment is a summary of the data in the snp_core, snp_variation and pangenome sequences.
This data became out of sync and this script re-writes the snp_alignment table by polling these
other sources

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
use IO::CaptureOutput qw(capture_exec);

# Genomes in DB
my %genomes;

# SNP alignments in DB
my %snp_alignments;
my $core_alignment = '';
my $current_column = 0;
my %alignment_columns;

# Config
my ($config_filepath, 
	$log_dir,
	$tmp_dir,
	$muscle
);

# Get options
GetOptions(
    'config=s'  => \$config_filepath

) or ( system( 'pod2text', $0 ), exit -1 );

croak "Error: missing argument. You must supply a configuration filepath.\n" . system ('pod2text', $0) unless $config_filepath;

if(my $conf = Config::Tiny->read($config_filepath)) {
	$log_dir = $conf->{dir}->{log};
	$tmp_dir = $conf->{tmp}->{dir};
	$muscle  = $conf->{ext}->{muscle};
} else {
	die Config::Tiny->error();
}


# Setup logger
my $logger = init($log_dir);
$logger->info("<<BEGIN Superphy SNP alignment repair");


# Connect to database
my $dbBridge = Data::Bridge->new(config => $config_filepath);
my $dbh = $dbBridge->dbh;
my $cvterms = $dbBridge->cvmemory;


# Prepare SQL statements
my %sql_sth;

# Retrieve snp_variations rows linked to snp_id
my $stmt =
	"SELECT contig_collection_id, allele ".
	"FROM snp_variation ".
    "WHERE snp_id = ?";
$sql_sth{public_snp_variations} = $dbh->prepare($stmt);
# $stmt =
# 	"SELECT contig_collection_id, allele ".
# 	"FROM private_snp_variation ".
#     "WHERE snp_id = ?";
# $sql_sth{private_snp_variations} = $dbh->prepare($stmt);

# Retreive pangenome loci linked to reference pangenome region
# $stmt =
# 	"SELECT f.feature_id, r2.object_id, f.residues ".
# 	"FROM private_feature f, pripub_feature_relationship r, private_feature_relationship r2 ".
# 	"WHERE r2.subject_id = f.feature_id AND ".
# 	" r2.type_id = ". $cvterms->{part_of} . " AND ".
# 	" r.subject_id = f.feature_id AND ".
#   " r.type_id = ". $cvterms->{derives_from} . " AND ".
# 	" r.object_id = ?";
# $sql_sth{private_pangenome_loci} = $dbh->prepare($stmt);
$stmt =
	"SELECT f.feature_id, r2.object_id, f.residues ".
	"FROM feature f, feature_relationship r, feature_relationship r2 ".
	"WHERE r2.subject_id = f.feature_id AND ".
	" r2.type_id = ". $cvterms->{part_of} . " AND ".
	" r.subject_id = f.feature_id AND ".
	" r.type_id = ". $cvterms->{derives_from} . " AND ".
	" r.object_id = ?";
$sql_sth{public_pangenome_loci} = $dbh->prepare($stmt);
	

fix_snps();
update();
$logger->info("Repair complete");


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
        log4perl.appender.FileApp.filename = ).$dir.q(rebuild_snp_alignment.log
        log4perl.appender.FileApp.layout   = PatternLayout
        log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n
        log4perl.appender.FileApp.mode     = write
    );

    # Initialize logging behaviour
    Log::Log4perl->init(\$conf);

    # Obtain a logger instance
    my $logger = get_logger();

   return $logger;
}


# Iterate through core snps that qualify as polymorphisms.
# Check against snp_variation table entries and positions
# in pangenome sequences.
# Save as alignment strings for each genome.
sub fix_snps {

	my $nsnps = 0;
		
	my $stmt1 =
		"SELECT snp_core_id, pangenome_region_id, aln_column, allele, position, gap_offset, ".
		" frequency_a, frequency_t, frequency_g, frequency_c, frequency_gap, frequency_other ".
		"FROM snp_core c ".
	    "WHERE c.is_polymorphism = TRUE";
	my $sth1 = $dbh->prepare($stmt1);
	$sth1->execute();

	my %pangenomes;
	while(my $snp_row = $sth1->fetchrow_arrayref) {
		# Next snp
		my ($snp_id, $pg_id, $col, $allele, $pos, $gapo, 
			$freq_a, $freq_t, $freq_g, $freq_c, $freq_gp, $freq_ot) = @$snp_row;

		$pangenomes{$pg_id} = [] unless defined $pangenomes{$pg_id};

		push @{$pangenomes{$pg_id}}, { 
			snp_id => $snp_id, 
			aln_col => $col, 
			allele => $allele, 
			pos => $pos, 
			gapo => $gapo, 
			freq => { A => $freq_a, T => $freq_t, G => $freq_g, C => $freq_c, '-' => $freq_gp, 'other' => $freq_ot }
		};

		$nsnps++;
	}

	$logger->info("Total snps: $nsnps");
	$logger->info("Total pangenomes with snps: ".scalar(keys %pangenomes));

	# Retrieve genomes
	#my @types = ('private','public');
	#foreach my $f_table ('private_feature', 'feature') {
	my @types = ('public');
	foreach my $f_table ('feature') {
		my $type = shift @types;
		my $stmt2 =
			"SELECT feature_id ".
			"FROM $f_table ".
		    "WHERE type_id = ?";
		my $sth2 = $dbh->prepare($stmt2);
		$sth2->execute($cvterms->{contig_collection});

		while(my ($id) = $sth2->fetchrow_array()) {
			$id = "$type\_$id";
			$genomes{$id} = '-';
			$snp_alignments{$id} = '';
		}
	}
	$logger->info("Total genomes: ".scalar(keys %genomes));

	# # Retrieve SNP alignments
	# my $stmt3 =
	# 	"SELECT name, alignment ".
	# 	"FROM snp_alignment ".
	# 	"WHERE name != 'core'";
	# my $sth3 = $dbh->prepare($stmt3);
	# $sth3->execute();
	# while(my ($name, $alignment) = $sth3->fetchrow_array()rf) {
	# 	$snp_alignments{$name} = $alignment;
	# }
	# $logger->info("Total genomes in snp_alignment table: ".scalar(keys %snp_alignments));

	foreach my $pg_id (keys %pangenomes) {
		#next unless $pg_id == 3157986;
		pangenome_alleles($pg_id, $pangenomes{$pg_id})
	}

	return();
}

sub pangenome_alleles {
	my $pg_id = shift;
	my $snp_data = shift;

	# Collect pangenome sequences
	my %seqs;
	
	#my @types = ('private', 'public');
	#foreach my $handle_name ('private_pangenome_loci', 'public_pangenome_loci') {
	my @types = ('public');
	foreach my $handle_name ('public_pangenome_loci') {

		my $type = shift @types;

		my $sth = $sql_sth{$handle_name};
		$sth->execute($pg_id);

		while(my ($loci_id, $genome_id, $seq) = $sth->fetchrow_array) {
			my $id = "genome|$type\_$genome_id|loci|$loci_id";
			$seqs{$id} = [split //, $seq];
		}
	}
	
	# Get aligned pangenome sequence
	my ($aligned_ref_id, $aligned_ref_seq) = $dbh->selectrow_array( 
	    qq/SELECT f.feature_id, f.residues
	    FROM feature f, feature_relationship r
	    WHERE f.type_id = / . $dbBridge->cvmemory('reference_pangenome_alignment') .
	    qq/ AND r.type_id = / . $dbBridge->cvmemory('aligned_sequence_of') . 
	    qq/ AND f.feature_id = r.subject_id AND r.object_id = $pg_id
	    /);

	croak "Error: pangenome reference sequence not found in database for $pg_id" unless $aligned_ref_seq;

	$logger->info("Pangenome: $pg_id");

	# Validate each SNP in pangenome
	foreach my $snp_set (@$snp_data) {
		my $snp_id = $snp_set->{snp_id};
		my $allele	= $snp_set->{allele};
		my $pos = $snp_set->{pos};
		my $gapo = $snp_set->{gapo};
		my $freq =  $snp_set->{freq};

		# next unless $snp_id == 160361;

		# Aligned column for this SNP
		my %column = %genomes;

		# Find aligned columns corresponding to SNP
		my $p = 0;

		my @seq_array = split //, $aligned_ref_seq;
		
		my $i = 0;
		for(; $i < @seq_array && $p != $pos; $i++) {
			if($seq_array[$i] ne '-') {
				$p++
			}
		}
		my $this_aln_column = $i+$gapo-1;
		
		my $ref_allele = uc $seq_array[$this_aln_column];

		$logger->debug("Snp: $snp_id, allele: $allele, db position in alignment: $pos, gapoffset: $gapo, actual position in alignment: $this_aln_column");
		my $min = $this_aln_column-3;
		my $spad = '';
		my $epad = '';
		if($min < 0) {
			my $n = $min * -1;
			$spad = ('#') x $n;
			$min = 0;
		}
		my $max = $this_aln_column+3;
		if($max > $#seq_array) {
			my $n = $max - $#seq_array;
			$epad = ('#') x $n;
			$max = $#seq_array;
		}
		my $seqstr = $spad . join('', @seq_array[$min..$max]) . $epad;
		$logger->debug($seqstr);
		$logger->debug('Frequency: '.Dumper($freq));
				
		if($ref_allele ne $allele) {
			$logger->warn("ERROR - ALLELE MISMATCH $snp_id\n");
		}

		# Retrieve variations for SNP in snp_variations table
		my %variations;
		# my @types = ('private', 'public');
		# foreach my $handle_name ('private_snp_variations', 'public_snp_variations') {
		my @types = ('public');
		foreach my $handle_name ('public_snp_variations') {

			my $type = shift @types;

			my $sth = $sql_sth{$handle_name};
			$sth->execute($snp_id);

			while(my ($genome_id, $var_allele) = $sth->fetchrow_array) {
				my $id = "$type\_$genome_id";
				$variations{$id} = $var_allele;
			}
		}


		# Iterate through the genomes, matching SNPs
		my %snp_freq = (
			A => 0,
			T => 0,
			G => 0,
			C => 0,
			'-' => 0,
			other => 0,
		);
		foreach my $id (keys %seqs) {
			my $seq_arr = $seqs{$id};

			my ($genome_id) = ($id =~ m/^genome\|((?:public|private)_\d+)\|/);

			my $this_allele = uc $seq_arr->[$this_aln_column];

			$logger->debug("$genome_id: $this_allele vs $ref_allele");
			my $prev = '#';
			if($this_aln_column > 0) {
				$prev = uc $seq_arr->[$this_aln_column-1]
			}
			my $post = '#';
			if($this_aln_column < $#seq_array) {
				$post = uc $seq_arr->[$this_aln_column+1]
			}
			$logger->debug("sequence neigbourhood $genome_id: $prev<$this_allele>$post");

			if($this_allele ne $ref_allele) {
				# Variation found
				# Check for entry in snp_variation table


				if($variations{$genome_id}) {
					if($variations{$genome_id} ne $this_allele) {
						
						$logger->warn("ERROR - genome $genome_id snp_variation table allele for SNP $snp_id ".
							"does not match alignment ($prev<$this_allele>$post vs ".$variations{$genome_id}.").");
					}
				}
				else {
					$logger->warn("ERROR - genome $genome_id missing entry in snp_variation table for SNP $snp_id. ".
						"Aligned position does not match reference ($prev<$this_allele>$post vs $ref_allele).");
				}

				if($this_allele =~ /[ACGT-]/) {
					$snp_freq{$this_allele}++;
				} else {
					$snp_freq{'other'}++;
				}
				
			}

			$column{$genome_id} = $this_allele;
		}

		# Check counting stats for this snp
		foreach my $n (keys %snp_freq) {
			if($snp_freq{$n} != $freq->{$n}) {
				$logger->warn("ERROR - snp_core frequency for $snp_id does not matched values observed in the alignment ".
					"($n: ".$snp_freq{$n}." vs ".$freq->{$n}.").");
				$logger->warn('aligned: '.Dumper(\%snp_freq));
				$logger->warn('db: '.Dumper($freq));
			}
		}
		$logger->debug('Frequency check complete');

		# Save alignment information
		$current_column += 1;
		$logger->debug("SNP assigned column $current_column.");
		$alignment_columns{$snp_id} = $current_column;

		# Save alignment column data
		foreach my $g (keys %column) {
			my $n = $column{$g};

			$snp_alignments{$g} .= $n
		}
		$core_alignment .= $ref_allele;
		$logger->debug('New snp alignment: '.$core_alignment);
		
	}
	#last;

}

sub update {

	# Check that all alignments have the same length
	my $len = length($core_alignment);
	foreach my $g (keys %snp_alignments) {
		my $aln = $snp_alignments{$g};
		my $this_len = length($aln);
		$logger->logdie("ERROR - Alignment length discrepancy for $g. Alignment has a length of $this_len") unless $this_len == $len
	}
	$logger->debug("Snp alignment length: $len");

	# Erase existing aln_column assignments
	my $stmt1 =
		"UPDATE snp_core SET aln_column = NULL;";
	my $sth1 = $dbh->prepare($stmt1);
	$sth1->execute();

	# Truncate snp_alignment table
	my $stmt2 = "TRUNCATE TABLE snp_alignment";
    $dbh->do($stmt2) or croak("Error when executing: $stmt2 ($!).\n");
    $logger->debug("Snp alignment table and aln_column cleared");

    # Populate snp_alignment table
    my $stmt3 = 'INSERT INTO snp_alignment (name, aln_column, alignment) VALUES ' .
		join ", ", ("( ?, ?, ?)") x 100;
	my $bulk_insert_sth = $dbh->prepare($stmt3);
	my @stack;
    foreach my $g (keys %snp_alignments) {
    	push @stack, [$g, $len, $snp_alignments{$g}];
    	#print "Adding to stack:".@stack;
    	if(scalar(@stack) == 100) {
    		my @values = map { @$_ } @stack;
    		$bulk_insert_sth->execute( @values );
    		@stack = ()
    	}
    	
    }
    if(@stack) {
    	my $values = join ", ", ("( ?, ?, ?)") x @stack;
		my $query  = "INSERT INTO snp_alignment (name, aln_column, alignment) VALUES $values";
		my $sth    = $dbh->prepare($query);
		$sth->execute( map { @$_ } @stack );
    }
    # Insert core alignment
    $dbh->do("INSERT INTO snp_alignment (name, aln_column, alignment) VALUES ('core',$len,'$core_alignment')");

    # Update aln_column field
    my $stack_size = 100;
    my $stmt4 = 'UPDATE snp_core SET aln_column = CAST(up.aln_column as int) FROM '.
	    '( VALUES '. join ", ", ("(?, ?)") x $stack_size;
	$stmt4 .= ') as up(snp_core_id, aln_column) '.
		'WHERE snp_core.snp_core_id = CAST(up.snp_core_id as int)';

	my $bulk_update_sth = $dbh->prepare($stmt4);
	@stack = ();
	foreach my $snp_id (keys %alignment_columns) {
		push @stack, [$snp_id, $alignment_columns{$snp_id}];

		if(scalar(@stack) == $stack_size) {
			my @values = map { @$_ } @stack;
    		$bulk_update_sth->execute( @values );
			@stack = ();
		}
		
	}

	if(@stack) {
		my $query = 'UPDATE snp_core SET aln_column = CAST(up.aln_column as int) FROM '.
	    	'( VALUES '. join ", ", ("(?, ?)") x @stack;
			$query .= ') as up(snp_core_id, aln_column) '.
			'WHERE snp_core.snp_core_id = CAST(up.snp_core_id as int)';

		my $sth = $dbh->prepare($query);
		my @values = map { @$_ } @stack;
		$sth->execute( @values );
	}
	

}
