#!/usr/bin/env perl

=head1 NAME

$0 - The pangenome data is often too big for memory. This script divides the data into manageable chucks.

=head1 SYNOPSIS
	
	% genodo_pangenome_loader.pl [options]

=head1 COMMAND-LINE OPTIONS

	--panseq            Specify a panseq results output directory.

=head1 DESCRIPTION



=head1 AUTHOR

Matt Whiteside

=cut

use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;
use File::Copy qw/copy/;
use Carp qw/croak carp/;


# Parse command-line
my ($panseq_dir, $output_root, $blocksize);
GetOptions(
	'panseq=s' => \$panseq_dir,
	'rootdir=s' => \$output_root,
	'blocksize=i' => \$blocksize
) or ( system( 'pod2text', $0 ), exit -1 );

croak "[Error] missing argument: panseq. You must supply the directory containing the panseq pangenome data.\n" . system('pod2text', $0) unless $panseq_dir;
croak "[Error] missing argument: rootdir. You must supply the directory root to output the data to.\n" . system('pod2text', $0) unless $output_root;
croak "[Error] missing argument: blocksize. You must supply the max number of pangenome fragments to include in each block.\n" . system('pod2text', $0) unless $blocksize;

# Load pangenome
my $core_fasta_file = 'coreGenomeFragments.fasta';
my $acc_fasta_file = 'accessoryGenomeFragments.fasta';
my $num_pg = 0;
my %b_assmt;
my $b = 1;
my @files = ($core_fasta_file, $acc_fasta_file);

my $curr_dir = $output_root . "$b/";
mkdir $curr_dir or croak "[Error] Unable to create directory $curr_dir ($!).\n";

# Don't bother splitting the loci positions file, just copy it whole
my $positions_file1 = $panseq_dir . 'pan_genome.txt';
my $positions_file2 = $curr_dir . 'pan_genome.txt';
copy($positions_file1, $positions_file2) or croak "[Error] unable to copy file $positions_file1 to $positions_file2 ($!).\n";

# Ditto annotations file
my $anno_file1 = $panseq_dir . 'anno_id_processed.txt';
my $anno_file2 = $curr_dir . 'anno_id_processed.txt';
copy($anno_file1, $anno_file2) or croak "[Error] unable to copy file $anno_file1 to $anno_file2 ($!).\n";


foreach my $i (0..$#files) {
	
	my $pan_file = $panseq_dir . $files[$i];
	
	my $fasta = Bio::SeqIO->new(-file   => $pan_file,
							    -format => 'fasta') or croak "Unable to open Bio::SeqIO stream to $pan_file ($!).";
							    
	my $out;
	my $input = $curr_dir . $files[$i];
	open($out, ">", $input) or croak "[Error] unable to write to file $input ($!).\n";							  
    
	while (my $entry = $fasta->next_seq) {
		my $id = $entry->display_id;
		my $seq = $entry->seq;
		
		my ($locus_id) = ($id =~ m/lcl\|(\d+)\|/);
		
		if($num_pg > $blocksize) {
			# Start new data block
			$b++;
			$num_pg = 0;
			$curr_dir = $output_root . "$b/";
			mkdir $curr_dir or croak "[Error] Unable to create directory $curr_dir ($!).\n";
			$input = $curr_dir . $files[$i];
			close $out;
			open($out, ">", $input) or croak "[Error] unable to write to file $input ($!).\n";
			
			# Don't bother splitting the loci positions file, just copy it whole
			$positions_file1 = $panseq_dir . 'pan_genome.txt';
			$positions_file2 = $curr_dir . 'pan_genome.txt';
			copy($positions_file1, $positions_file2) or croak "[Error] unable to copy file $positions_file1 to $positions_file2 ($!).\n";
			
			# Ditto annotations file
			my $anno_file1 = $panseq_dir . 'anno_id_processed.txt';
			my $anno_file2 = $curr_dir . 'anno_id_processed.txt';
			copy($anno_file1, $anno_file2) or croak "[Error] unable to copy file $anno_file1 to $anno_file2 ($!).\n";
		}
		
		$b_assmt{$locus_id} = $b;
		print $out ">$id\n$seq\n";
		
		$num_pg++;
	}
	close $out;
}

# Load loci
{
	# Slurp a group of fasta sequences for each locus.
	# This could be disasterous if the memory req'd is large (swap-thrashing yikes!)
	# otherwise, this should be faster than line-by-line.
	# Also assumes specific FASTA format (i.e. sequence and header contain no line breaks or spaces)
	my $fasta_file = $panseq_dir . 'locus_alleles.fasta';
	my %fh;
	open (my $in, "<", $fasta_file) or croak "Error: unable to read file $fasta_file ($!).\n";
	local $/ = "\nLocus ";
	
	while(my $locus_block = <$in>) {
		
		$locus_block =~ s/Locus //;
		my ($locus_id) = ($locus_block =~ m/^lcl\|(\d+)\|/);
		die "Error: cannot parse header ".substr($locus_block,0,60)."\n" unless defined $locus_id;
		
		my $locus_b = $b_assmt{$locus_id};
		
		croak "[Error] unknown pangenome locus $locus_id" unless $locus_b;
		#next unless $locus_b;
		
		unless($fh{$locus_b}) {
			my $newf = $output_root . "$locus_b/locus_alleles.fasta";
			open(my $newfh, ">", $newf) or croak "[Error] unable to write to file $newf ($!).\n";
			$fh{$locus_b} = $newfh;
		}
		
		print { $fh{$locus_b} } 'Locus '.$locus_block;
	}
	
	close $in;
	
}


exit(0);