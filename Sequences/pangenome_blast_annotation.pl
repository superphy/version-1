#!/usr/bin/env perl

=head1 NAME

$0 - Runs blastx against proteogamma bacteria subset of the NR Blast database

=head1 SYNOPSIS
	
	% pangenome_blast_annotations.pl [options]

=head1 COMMAND-LINE OPTIONS

	--fasta             Input fasta file for blastx program
	--output 			Blast output filename

=head1 DESCRIPTION

Uses parallel function to run blastx across multiple cores

=head1 AUTHOR

Matt Whiteside

=cut

use strict;
use warnings;
$| = 1;

use Getopt::Long;
use Time::HiRes qw( time );

# Globals (set these to match local values)
my $blast_dir = '/home/matt/blast/bin/';
my $parallel_exe = '/usr/bin/parallel';
my $nr_location = '/home/matt/blast_databases/nr_gammaproteobacteria';
my $num_cores = 20;

# Parse command-line
my ($INPUT, $OUTPUT);

GetOptions(
	'fasta=s' => \$INPUT,
	'output=s' => \$OUTPUT
) or ( system( 'pod2text', $0 ), exit -1 );

die "[Error] missing argument. You must supply a valid fasta file\n" . system('pod2text', $0) unless $INPUT && -e $INPUT;
die "[Error] missing argument. You must supply a output filename\n" . system('pod2text', $0) unless $OUTPUT;

# Blast pangenome regions
my $blast_cmd = "$blast_dir/blastx -evalue 0.0001 -outfmt ".'\"6 qseqid qlen sseqid slen stitle\" '."-db $nr_location -max_target_seqs 1 -query -";

my $filesize = -s $INPUT;
my $blocksize = int($filesize/$num_cores);
my $parallel_cmd = "cat $INPUT | $parallel_exe --gnu -j $num_cores --block $blocksize --recstart '>' --pipe $blast_cmd > $OUTPUT";

print "\trunning blast on pangenome fragments...\n";
system($parallel_cmd) == 0 or die "[Error] BLAST failed.\n";
print "\tcomplete\n";
	




