#!/usr/bin/perl

use strict;
use warnings;
use Bio::SeqIO;
use Getopt::Long;
use Pod::Usage;
use autodie qw/:default :system/;

=head1 NAME

  $0 - selects representative AMR sequences from BLASTClust clusters to use as query genes

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

  --fasta       Fasta file to load sequence from
  --output      Output fasta file to write sequences to

=head1 DESCRIPTION

  AMR genes from the ARPCARD database have multiple copies of equivalent genes
  in various species. To group AMR/VF genes under a set of non-redundant query genes,
  this script runs BLASTClust to identify highly similar groups of sequences and then
  selects a single representative (preferably from the Escherichia genus). 

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($FASTAFILE,$OUTPUT,
    $MANPAGE, $DEBUG
    );

print GetOptions(
    'fasta=s'=> \$FASTAFILE,
    'output=s'=>\$OUTPUT,
    'manual'   => \$MANPAGE,
    'debug'   => \$DEBUG,
) or pod2usage(-verbose => 1, -exitval => -1);

pod2usage(-verbose => 1, -exitval => 1) if $MANPAGE;

die "Missing argument: --fastafile.\n" unless $FASTAFILE;

my @genus_rank = reverse('Escherichia', 'Shigella', 'Samonella', 'Citrobacter', 'Enterobacter', 'Klebsiella');

# Remove really short sequences
my $tmp_fasta = '/tmp/genodo_amr_genes.ffn';
filterSequences($FASTAFILE, $tmp_fasta);

# Run BLASTClust
my $cmd = 'blastclust';
my $tmpfile = '/tmp/genodo_blastclust_results.txt';
# Use default thresholds: 90% overlap and 1.75/length score threshold - fairly conservative
my @opts = ('-p f', '-b f', "-o $tmpfile", "-i $tmp_fasta");

system(join(' ', $cmd, @opts));

# Load clusters
my ($clusters, $c_assignments) = loadBlastClust($tmpfile);

# Load fasta sequences into hash
my $seqs = loadFasta($tmp_fasta);

# Select representative for each cluster
# Priority goes to sequences that are 1. from closely related genera 2. longer
open(my $out, ">", $OUTPUT);
selectReps($clusters, $seqs, $out);
close $out;

=head2 loadBlastClust

Load the BLASTClust groupings into array of arrayrefs
and an assignment hash that list the group of each genome.

=cut

sub loadBlastClust {
	my $file = shift;
	
	my @groups;
	my %assignments;
	my $i = 0;
	
	open(my $fh, "<", "$file");
	
	while(my $row = <$fh>) {
		chomp $row;
		
		my @g = split(/\s+/, $row);
		push @groups, \@g;
		
		foreach my $n (@g) {
			$assignments{$n} = $i
		}
		
		$i++;
	}
	
	close $fh;
	
	return(\@groups, \%assignments);
}

=head2 loadFasta

Load the FASTA file from the ARPCARD database into hash.

=cut

sub loadFasta {
	my $file = shift;
	
	my %seqs;
	
	my $seqio_object = Bio::SeqIO->new(-file => $file);

	while(my $seq = $seqio_object->next_seq) {
		
		my $id = $seq->id();
		#my @fields = split(/\. /, $seq->desc());
		#my $gname = $fields[0];
		#my @tmp = ($seq->desc() =~ m/(ARO:\d+)/g);
		
		#my @aro = grep(!/^ARO:1000001/, @tmp);
		
		my ($spc) = ($seq->desc() =~ m/ \[(.+)\]$/);

		unless(defined $spc){
			$spc = "Escherichia coli";
		}
		
		die "Sequence $id has no defined species" unless $spc;
		
		$seqs{$id} = {
			header => $id . ' ' . $seq->desc,
			#aro_terms => \@aro,
			seq => $seq->seq(),
			spc => $spc
		};	
	}
	
	return(\%seqs);
}

=head2 filterSequences

The AMR genes have some suspect sequences. Remove any genes
with less than 50 nt.

=cut

sub filterSequences {
	my ($file, $outfile) = @_;
	
	open(my $fh, ">", $outfile);
	
	my $seqio_object = Bio::SeqIO->new(-file => $file);

	while(my $seq = $seqio_object->next_seq) {
		
		my $id = $seq->id();
		my $desc = $seq->desc();
		my $dna = $seq->seq();
		
		if(length($dna) >= 51) {
			print $fh ">$id $desc\n$dna\n\n";
		}
	}
	
	close $fh;
}

=head2 selectReps

Select representative for each BLASTClust cluster
Priority goes to sequences that are  1. from closely 
related genera 2. longer

=cut

sub selectReps {
	my ($clusters, $seqs, $fh) = @_;

	foreach my $c_ref (@$clusters) {
		my @cluster = @$c_ref;
		
		my $id = $cluster[0];
		my $best = betterRep($seqs->{$id});
		foreach my $n (@cluster[1..$#cluster]) {
			$best = betterRep($seqs->{$n}, $best);
		}
		
		# Save best representative
		#print "For this cluster of size ".(scalar @cluster).", rep " . $best->{header} . ' with length ' . length($best->{seq}) . " was selected.\n";
		print $fh ">" . $best->{header} . "\n" . $best->{seq} . "\n\n";
	}	
}

sub betterRep {
	my ($seq, $curr) = @_;
	
	die "Error: undefined sequence hash (arg 1)" unless $seq;
	
	# Check if new sequence is from one of the priority genera
	$seq->{genus_rank} = -1;
	for(my $i = 0; $i < @genus_rank; $i++) {
		my $g = $genus_rank[$i];
		
		if($seq->{spc} =~ m/$g/) {
			$seq->{genus_rank} = $i;
		}
	}
	
	return $seq unless $curr;
	
	if($seq->{genus_rank} > $curr->{genus_rank}) {
		return $seq;
	} elsif($seq->{genus_rank} == $curr->{genus_rank} && length($seq->{seq}) > length($curr->{seq})) {
		return $seq;
	} else {
		return $curr;
	}
}
