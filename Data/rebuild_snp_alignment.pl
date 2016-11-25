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
$stmt =
	"SELECT contig_collection_id, allele ".
	"FROM private_snp_variation ".
    "WHERE snp_id = ?";
$sql_sth{private_snp_variations} = $dbh->prepare($stmt);

# Retreive pangenome loci linked to reference pangenome region
$stmt =
	"SELECT f.feature_id, r2.object_id, f.residues ".
	"FROM private_feature f, pripub_feature_relationship r, private_feature_relationship r2 ".
	"WHERE r2.subject_id = f.feature_id AND ".
	" r2.type_id = ". $cvterms->{part_of} . " AND ".
	" r.subject_id = f.feature_id AND ".
	" r.object_id = ?";
$sql_sth{private_pangenome_loci} = $dbh->prepare($stmt);
$stmt =
	"SELECT f.feature_id, r2.object_id, f.residues ".
	"FROM feature f, feature_relationship r, feature_relationship r2 ".
	"WHERE r2.subject_id = f.feature_id AND ".
	" r2.type_id = ". $cvterms->{part_of} . " AND ".
	" r.subject_id = f.feature_id AND ".
	" r.object_id = ?";
$sql_sth{public_pangenome_loci} = $dbh->prepare($stmt);
	

fix_snps();
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
	my @types = ('private','public');
	foreach my $f_table ('private_feature', 'feature') {
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
		}
	}
	$logger->info("Total genomes: ".scalar(keys %genomes));

	# Retrieve SNP alignments
	my $stmt3 =
		"SELECT name, alignment ".
		"FROM snp_alignment ".
		"WHERE name != 'core'";
	my $sth3 = $dbh->prepare($stmt3);
	$sth3->execute();
	while(my ($name, $alignment) = $sth3->fetchrow_array()) {
		$snp_alignments{$name} = $alignment;
	}
	$logger->info("Total genomes in snp_alignment table: ".scalar(keys %snp_alignments));

	foreach my $pg_id (keys %pangenomes) {
		pangenome_alleles($pg_id, $pangenomes{$pg_id})
	}

	$logger->info("Number of snps: $nsnps.");

	return();
}

sub pangenome_alleles {
	my $pg_id = shift;
	my $snp_data = shift;

	# Collect pangenome sequences
	my %seqs;
	my $profile_file = $tmp_dir . "/profile.aln";
	open(my $pfh, '>', $profile_file) or die "Error: Unable to write to file $profile_file ($!).";
	
	my @types = ('private', 'public');
	foreach my $handle_name ('private_pangenome_loci', 'public_pangenome_loci') {

		my $type = shift @types;

		my $sth = $sql_sth{$handle_name};
		$sth->execute($pg_id);

		while(my ($loci_id, $genome_id, $seq) = $sth->fetchrow_array) {
			my $id = "genome|$type\_$genome_id|loci|$loci_id";
			print $pfh ">$id\n$seq\n";
			$seqs{$id} = [split //, $seq];
		}
	}

	close $pfh;

	# Get pangenome sequence
	my ($seq) = $dbh->selectrow_array("SELECT residues FROM feature WHERE feature_id = $pg_id");
	my $ref_file = $tmp_dir . "/reference.aln";
	open(my $rfh, '>', $ref_file) or die "Error: Unable to write to file $ref_file ($!).";
	print $rfh ">ref_$pg_id\n$seq\n";
	close $rfh;
	
	# Align
	my @loading_args = ($muscle, "-quiet -profile -in1 $ref_file -in2 $profile_file -out $profile_file");
	my $cmd = join(' ',@loading_args);
			
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
		
	unless($success) {
		croak "Muscle profile alignment failed for pangenome $pg_id ($stderr).";
	}

	# Load ref sequences
	my $fasta = Bio::SeqIO->new(-file   => $profile_file,
								-format => 'fasta') or croak "Unable to open Bio::SeqIO stream to $profile_file ($!).";
				
	my $aligned_ref_seq;					
	while (my $entry = $fasta->next_seq) {
		if($entry->display_id =~ m/^ref/) {
			$aligned_ref_seq = $entry->seq;
			last;
		}

	}

	croak "Error: pangenome reference sequence not found in muscle output" unless $aligned_ref_seq;

	$logger->info("Pangenome: $pg_id");

	# Validate each SNP in pangenome
	foreach my $snp_set (@$snp_data) {
		my $snp_id = $snp_set->{snp_id};
		my $col = $snp_set->{aln_col};
		my $allele	= $snp_set->{allele};
		my $pos = $snp_set->{pos};
		my $gapo = $snp_set->{gapo};
		my $freq =  $snp_set->{freq};

		# Aligned column for this SNP
		my %column = %genomes;

		# Find aligned columns corresponding to SNP
		my $p = 0;

		my @seq_array = split //, $aligned_ref_seq;
		my $i = 0;
		for(; $i < @seq_array; $i++) {
			if($seq_array[$i] ne '-') {
				$p++
			}

			if($p == $pos) {
				last;
			}
		}

		my $this_aln_column = $i+$gapo;
		my $ref_allele = uc $seq_array[$this_aln_column];

		$logger->info("Snp: $snp_id, allele: $allele, db position in alignment: $pos, gapoffset: $gapo, actual position in alignment: $this_aln_column, snp alignment column: $col");
		$logger->info(join('', @seq_array[($this_aln_column-3)..($this_aln_column+3)]));
		$logger->info('Frequency: '.Dumper($freq));
				
		if($ref_allele ne $allele) {
			$logger->warn("ERROR - ALLELE MISMATCH $snp_id\n");
		}

		# Retrieve variations for SNP in snp_variations table
		my %variations;
		my @types = ('private', 'public');
		foreach my $handle_name ('private_snp_variations', 'public_snp_variations') {

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
		);
		foreach my $id (keys %seqs) {
			my $seq_arr = $seqs{$id};

			my ($genome_id) = ($id =~ m/^genome\|((?:public|private)_\d+)\|/);

			my $this_allele = uc $seq_arr->[$this_aln_column];

			$logger->info("$genome_id: $this_allele vs $ref_allele");

			if($this_allele ne $ref_allele) {
				# Variation found
				# Check for entry in snp_variation table

				if($variations{$genome_id}) {
					if($variations{$genome_id} ne $this_allele) {
						$logger->warn("ERROR - genome $genome_id snp_variation table allele for SNP $snp_id ".
							"does not match alignment ($this_allele vs ".$variations{$genome_id}.").");
					}
				}
				else {
					$logger->warn("ERROR - genome $genome_id missing entry in snp_variation table for SNP $snp_id. ".
						"Aligned position does not match reference ($this_allele vs $ref_allele).");
				}

				$snp_freq{$this_allele}++;
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
		$logger->warn('aligned: '.Dumper(\%snp_freq));
		$logger->warn('db: '.Dumper($freq));
		$logger->info('Frequency check complete');
		$logger->info("COLUMN: $col");

		# Check alignment column
		my %error_record;
		foreach my $g (keys %column) {
			my $a = substr $snp_alignments{$g}, $col, 1;
			my $b = $column{$g};

			if($a ne $b) {
				$logger->warn("ERROR - aligned character mismatch for genome $g and snp $snp_id (".
					substr($snp_alignments{$g}, $col-3, 3)."_$a\_".substr($snp_alignments{$g}, $col+1, 3)." vs $b)");
				$error_record{$a}{$b}++
			}
		}

		if(%error_record) {
			foreach my $db_alignment (keys %error_record) {
				foreach my $re_alignment (keys %{$error_record{$db_alignment}}) {
					$logger->info("Database values $db_alignment mapped to $re_alignment: ".$error_record{$db_alignment}{$re_alignment})
				}
			}
		}
		
	}
	last;



}