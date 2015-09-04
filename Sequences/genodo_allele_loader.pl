#!/usr/bin/env perl

use strict;
use warnings;
use Bio::SeqIO;
use Getopt::Long;
use Pod::Usage;
use Carp;
use Sys::Hostname;
use Config::Simple;
use FindBin;
use lib "$FindBin::Bin/..";
use Sequences::ExperimentalFeatures;
use Time::HiRes qw( time );
use IO::CaptureOutput qw(capture_exec);

=head1 NAME

$0 - loads multi-fasta file into a genodo's chado database. Fasta file contains genomic or shotgun contig sequences.

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --fasta           BLAST file to load sequence from
 --config          INI style config file containing DB connection parameters
 --noload          Create bulk load files, but don't actually load them.
 --recreate_cache  Causes the uniquename cache to be recreated
 --remove_lock     Remove the lock to allow a new process to run
 --save_tmpfiles   Save the temp files used for loading the database
 --manual          Detailed manual pages

=head1 DESCRIPTION

A contig_collection is the parent label used for a set of DNA sequences belonging to a 
single project (which may be a WGS or a completed whole genome sequence). Global properties 
such as strain, host etc are defined at the contig_collection level.  The contig_collection 
properties are defined in a hash that is written to file using Data::Dumper. Multiple values
are permitted for any data type with the exception of name or uniquename.  Multiple values are
passed as an array ref. The first item on the list is assigned rank 0, and so on.

Each sequence in the fasta files is labelled as a contig (whether is its a chromosome or true contig). 
The contig properties are obtained from the fasta file. Names for the contigs are obtained from 
the accessions in the fasta file.  The fasta file header lines are also used to define the mol_type 
as chromosome or plasmid.
  
=head2 Properties

	

=head2 NOTES

=over

=item Transactions

This application will, by default, try to load all of the data at
once as a single transcation.  This is safer from the database's
point of view, since if anything bad happens during the load, the 
transaction will be rolled back and the database will be untouched.

=item The run lock

The loader is not a multiuser application.  If two separate
bulk load processes try to load data into the database at the same
time, at least one and possibly all loads will fail.  To keep this from
happening, the bulk loader places a lock in the database to prevent
other processes from running at the same time.
When the application exits normally, this lock will be removed, but if
it crashes for some reason, the lock will not be removed.  To remove the
lock from the command line, provide the flag --remove_lock.  Note that
if the loader crashed necessitating the removal of the lock, you also
may need to rebuild the uniquename cache (see the next section).

=item The uniquename cache

The loader uses the chado database to create a table that caches
feature_ids, uniquenames, type_ids, and organism_ids of the features
that exist in the database at the time the load starts and the
features that will be added when the load is complete.  If it is possilbe
that new features have been added via some method that is not this
loader (eg, Apollo edits or loads with XORT) or if a previous load using
this loader was aborted, then you should supply
the --recreate_cache option to make sure the cache is fresh.

=item single allele per genome

There is no way to map information in the pan_genome.txt file to the sequences
in the locus_alleles.fasta if there are multiple alleles per genome for a single
locus. Allele sequences in the fasta file are labelled by genome ID only, they need
a allele copy # to distinguish between multiple copies in one genome or contig.

The code relies on this assumption and in several places, caches allele information
such as start, stop coords by genome ID and locus ID. This would need to change
if multiple alleles per genome are allowed.

=back

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Adapted from original package developed by 
Allen Day E<lt>allenday@ucla.eduE<gt>, Scott Cain E<lt>scain@cpan.orgE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# Globals (set these to match local values)
my $muscle_exe = '/usr/bin/muscle';
my $mummer_dir = '/home/matt/MUMmer3.23/';
my $blast_dir = '/home/matt/blast/bin/';
my $parallel_exe = '/usr/bin/parallel';
my $panseq_exe = '/home/matt/workspace/c_panseq/live/Panseq/lib/panseq.pl';
my $align_script = "$FindBin::Bin/parallel_tree_builder.pl";

my ($CONFIGFILE, $PANSEQDIR, $NOLOAD,
    $RECREATE_CACHE, $SAVE_TMPFILES,
    $MANPAGE, $DEBUG,
    $REMOVE_LOCK,
    $VACUUM);

GetOptions(
	'config=s' => \$CONFIGFILE,
    'panseq=s' => \$PANSEQDIR,
    'noload' => \$NOLOAD,
    'recreate_cache'=> \$RECREATE_CACHE,
    'remove_lock'  => \$REMOVE_LOCK,
    'save_tmpfiles'=>\$SAVE_TMPFILES,
    'manual' => \$MANPAGE,
    'debug' => \$DEBUG,
    'vacuum' => \$VACUUM
) 
or pod2usage(-verbose => 1, -exitval => 1);
pod2usage(-verbose => 2, -exitval => 1) if $MANPAGE;

$SIG{__DIE__} = $SIG{INT} = 'cleanup_handler';

# Initialize the chado adapter
my %argv;

$argv{config}         = $CONFIGFILE;
$argv{noload}         = $NOLOAD;
$argv{recreate_cache} = $RECREATE_CACHE;
$argv{save_tmpfiles}  = $SAVE_TMPFILES;
$argv{vacuum}         = $VACUUM;
$argv{debug}          = $DEBUG;
$argv{feature_type}   = 'vfamr';

my $chado = Sequences::ExperimentalFeatures->new(%argv);

# BEGIN
my $now = my $start = time();

unless($PANSEQDIR) {
	print "Running panseq...\n";
	
	my $root_dir = $chado->tmp_dir . 'panseq_alleles/';
	unless (-e $root_dir) {
		mkdir $root_dir or croak "[Error] unable to create directory $root_dir ($!).\n";
	}
	
	# Download all genome sequences
	print "\tdownloading genome sequences...\n";
	my $fasta_dir = $root_dir . '/fasta/';
	unless (-e $fasta_dir) {
		mkdir $fasta_dir or croak "[Error] unable to create directory $fasta_dir ($!).\n";
	}
	my $fasta_file = $fasta_dir . 'genomes.ffn';
	
	my $cmd = "perl $FindBin::Bin/../Database/contig_fasta.pl --config $CONFIGFILE --output $fasta_file";
	system($cmd) == 0 or croak "[Error] download of contig sequences failed (syscmd: $cmd).\n";
	print "\tcomplete\n";
	
	# Download all query gene sequences
	print "\tdownloading query gene sequences...\n";
	my $qg_dir = $root_dir . '/query_genes/';
	unless (-e $qg_dir) {
		mkdir $qg_dir or croak "[Error] unable to create directory $qg_dir ($!).\n";
	}
	my $query_file = $qg_dir . 'query_genes.ffn';
	
	$cmd = "perl $FindBin::Bin/../Database/query_gene_fasta.pl --config $CONFIGFILE --combined $query_file.";
	system($cmd) == 0 or croak "[Error] download of query gene sequences failed (syscmd: $cmd).\n";
	print "\tcomplete\n";
	$query_file = "/home/matt/workspace/a_genodo/data/typing/stx/fasta/genodo_query_genes.ffn";
	
	# Run panseq
	print "\tpreparing panseq input...\n";
	$PANSEQDIR = $root_dir . 'panseq/';
	if(-e $PANSEQDIR) {
		remove_tree $PANSEQDIR or croak "[Error] unable to delete directory $PANSEQDIR ($!).\n";
	}
	
	my $pan_cfg_file = $root_dir . 'vf.conf';
	my $core_threshold = 3;
	
	open(my $out, '>', $pan_cfg_file) or die "[Error] cannot write to file $pan_cfg_file ($!).\n";
	print $out 
qq|queryDirectory	$fasta_dir
queryFile	$query_file
baseDirectory	$PANSEQDIR
numberOfCores	8
mummerDirectory	$mummer_dir
blastDirectory	$blast_dir
minimumNovelRegionSize	0
novelRegionFinderMode	no_duplicates
muscleExecutable	$muscle_exe
fragmentationSize	0
percentIdentityCutoff	90
coreGenomeThreshold	0
runMode	pan
storeAlleles	1
allelesToKeep	5
nameOrId	name
|;
	close $out;

	print "\tcomplete\n";
	
	my @loading_args = ($panseq_exe,
	$pan_cfg_file);
	
	print "\trunning panseq...\n";
	$cmd = join(' ', @loading_args);
	system($cmd) == 0 or croak "[Error] Panseq analysis failed.\n";
	print "\tcomplete\n";
	
}

# Lock table so no one else can upload
$chado->remove_lock() if $REMOVE_LOCK;
$chado->place_lock();
my $lock = 1;

# Prepare tmp files for storing upload data
$chado->file_handles();

# Save data for inserting into database
elapsed_time('db init');

# Build alignments and trees in parallel

# Output to file
my $alndir = File::Temp::tempdir(
	"chado-alignments-XXXX",
	CLEANUP  => $SAVE_TMPFILES ? 0 : 1, 
	DIR      => $chado->tmp_dir,
);
chmod 0755, $alndir;

# Make subdirectories for each file type (do #files never grows too large)
my $fastadir = $alndir . '/fasta';
my $treedir = $alndir . '/tree';
my $perldir = $alndir . '/perl_tree';
my $refdir = $alndir . '/refseq';
foreach my $d ($fastadir, $treedir, $perldir, $refdir) {
	mkdir $d or croak "[Error] unable to create directory $d ($!).\n";
}
	
# Chop up giant fasta file into parts
my @tasks;
# Load loci
{
	# Slurp a group of fasta sequences for each locus.
	# This could be disasterous if the memory req'd is large (swap-thrashing yikes!)
	# otherwise, this should be faster than line-by-line.
	# Also assumes specific FASTA format (i.e. sequence and header contain no line breaks or spaces)
	my $locus_file = $PANSEQDIR . 'locus_alleles.fasta';
	open (my $in, "<", $locus_file) or croak "Error: unable to read file $locus_file ($!).\n";
	local $/ = "\nLocus ";
	
	while(my $locus_block = <$in>) {

		$locus_block =~ s/^Locus //;
		my ($locus) = ($locus_block =~ m/^(\S+)/);
		next unless $locus;
		
		# query gene
		my ($query_id, $query_name) = ($locus =~ m/(\d+)\|(.+)/);
		croak "Missing query gene ID in locus line: $locus\n" unless $query_id && $query_name;
		
		my $num_seqs = ($locus_block =~ tr/>/>/);
		my $do_tree = 0;
		
		$do_tree = 1 if $num_seqs > 2; # only build trees for groups of 3 or more
		
		push @tasks, [$query_id, $query_name, $do_tree];
		
		open my $out1, '>', $fastadir . "/$query_id.ffn" or croak "Error: unable to open file $fastadir/$query_id.ffn ($!).";
	
		while($locus_block =~ m/\n>(\S+)\n(\S+)/g) {
			my $header = $1;
			my $seq = $2;
			$seq =~ tr/-// if $do_tree; # Remove gaps
			print $out1 ">$header\n$seq\n";
		}
		close $out1;
		
	}
	close $in;
}


# Print tasks to file
my $jobfile = $alndir . "/jobs.txt";
open my $out, '>', $jobfile or croak "Error: unable to open file $jobfile ($!).";
foreach my $t (@tasks) {
	# Only need alignment or tree if do_tree is true
	if($t->[2]) {
		print $out join("\t",$t->[0],$t->[2],0,0),"\n";
	}
}
close $out;
elapsed_time('Fasta file printing');

# Run alignment script
my @loading_args = ('perl', $align_script, "--dir $alndir");
my $cmd = join(' ',@loading_args);
my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
unless($success) {
	croak "Alignment script $cmd failed ($stderr).";
}
elapsed_time('Parallel alignment');

# Load locus locations
my $pan_file = $PANSEQDIR . '/pan_genome.txt';
my %loci;
open(my $in, "<", $pan_file) or croak "[Error] unable to read file $pan_file ($!).\n";
<$in>; # header line
while (my $line = <$in>) {
	chomp $line;
	
	my ($id, $uniquename, $genome, $allele, $start, $end, $header) = split(/\t/,$line);
	
	if($allele > 0) {
		# Hit
		my ($query_id) = $uniquename =~ m/^(?:VF|AMR)_(\d+)\|/;
		my ($contig) = $header =~ m/lcl\|\w+\|(\w+)/;

		croak "Error: duplicate position entries found for pangenome reference $uniquename and loci $header.\n" if defined $loci{$query_id}->{$header};

		$loci{$query_id}->{$header} = {
			start => $start,
			end => $end,
			contig => $contig
		};		
	}
	
}
elapsed_time("Loci locations");


# Iterate through each pangenome segment and load it
foreach my $tarray (@tasks) {
	my ($query_gene_id, $query_gene_name, $do_tree) = @$tarray;

	# Load sequences from file
	my $num_ok = 0;  # Some locus sequences fail checks, so the overall number of sequences can drop making trees/snps irrelevant
	my @sequence_group;
	my $fasta_file = $fastadir . "/$query_gene_id.ffn";
	my $fasta = Bio::SeqIO->new(-file   => $fasta_file,
								-format => 'fasta') or die "Unable to open Bio::SeqIO stream to $fasta_file ($!).";
	while(my $entry = $fasta->next_seq()) {
		my $header = $entry->display_id;
		my $seq = $entry->seq;
		$num_ok++ if allele($query_gene_id,$query_gene_name,$header,$seq,\@sequence_group);
	}
	
	if($do_tree && $num_ok > 2) {
		my $tree_file = $perldir . "/$query_gene_id\_tree.perl";
		open my $in, '<', $tree_file or croak "Error: tree file not found $tree_file ($!).\n";
		my $tree = <$in>;
		chomp $tree;
		close $in;
		
		# Swap the headers in the tree with consistent tree names
		# Assumes headers are unique
		my %conversions;
		foreach my $allele_hash (@sequence_group) {
			
			my $header = $allele_hash->{header};
			my $displayId = $allele_hash->{public} ? 'public_':'private_';
			$displayId .= $allele_hash->{genome} . '|' . $allele_hash->{allele};
			
			# Many updated sequences will have the correct headers,
			# but just in case, update the tree if they do not match
			next if $header eq $displayId; 
			
			if($conversions{$header}) {
				warn "Duplicate headers $header. Headers must be unique in locus_alleles.fasta.";  # Already looked up new Id
				next;
			}
		
			$conversions{$header} = $displayId;
		}
		
		# Make sure longer strings get converted before substrings
		my @replacements = sort {
				length $b <=> length $a ||
				$b cmp $a
			} keys %conversions;
		foreach my $old (@replacements) {
			my $new = $conversions{$old};
			print "REPLACING $old with $new\n";
			my ($num_repl) = ($tree =~ s/\Q$old\E/\Q$new\E/g);
			warn "No replacements made in phylogenetic tree for query sequence $query_gene_id. $old not found." unless $num_repl;
			warn "Multiple replacements ($num_repl) made in phylogenetic tree for query sequence $query_gene_id. $old is not unique." if $num_repl > 1;
		}
		
		$chado->handle_phylogeny($tree, $query_gene_id, \@sequence_group);
	}
	
}
elapsed_time("Data parsed");

unless ($NOLOAD) {
	$chado->load_data();
}

$chado->remove_lock();
elapsed_time("Data loaded");

my $rt = time() - $start;
printf("Full runtime: %.2f\n", $rt);

exit(0);

=cut

=head2 cleanup_handler

=over

=item Usage

  cleanup_handler

=item Function

Removes table lock and any entries added to the uniquename change in tmp table.

=item Returns

void

=item Arguments

filename of Data::Dumper file containing data hash.

=back

=cut

sub cleanup_handler {
    warn "@_\nAbnormal termination, trying to clean up...\n\n" if @_;  #gets the message that the die signal sent if there is one
    if ($chado && $chado->dbh->ping) {
        
        if ($lock) {
            warn "Trying to remove the run lock (so that --remove_lock won't be needed)...\n";
            $chado->abort(); #remove any active locks, discard DB transaction
        }
        
        print STDERR "Exiting...\n";
    }
    exit(1);
}

=head2 allele


=cut

sub allele {
	my ($query_id, $query_name, $header, $seq, $seq_group) = @_;
	
	# Parse input
	my $genome_ids = parse_loci_header($header);
	
	# privacy setting
	my $is_public = $genome_ids->{access} eq 'public' ? 1 : 0;
	my $pub_value = $is_public ? 'TRUE' : 'FALSE';;
	
	# location hash
	my $allele_num = $genome_ids->{copy};
	my $loc_hash = $loci{$query_id}->{$genome_ids->{position_file_header}};
	unless(defined $loc_hash) {
		warn "Missing location information for locus allele $query_name ($query_id) in contig $header (lookup details: ".
			$genome_ids->{position_file_header}.",".
			$allele_num.").\n" unless defined $loc_hash;
		croak;
	}
	
	# contig
	my $contig = $loc_hash->{contig};
	my ($access2, $contig_id) = ($contig =~ m/(public|private)_(\d+)/);
	
	# contig sequence positions
	my $start = $loc_hash->{start};
	my $end = $loc_hash->{end};
	
	# sequence
	my ($seqlen, $residues, $min, $max, $strand);
	if($start > $end) {
		# rev strand
		$max = $start+1; #interbase numbering
		$min = $end;
		$strand = -1;
	} else {
		# forward strand
		$max = $end+1; #interbase numbering
		$min = $start;
		$strand = 1;
	}
	
	$seqlen = $max - $min;
	$residues = $seq;
	
	# type 
	my $type = $chado->feature_types('allele');
	
	# uniquename - based on contig location and query gene and so should be unique. Can't have duplicate alleles at same spot for a single query gene
	# however can have different query genes with hits at the same spot (if there is any redundancy in the VF or AMR gene sets).
	my $uniquename = "allele:$query_id.$contig_id.$min.$max.$is_public";
	
	# Check if this allele is already in DB
	my ($result, $allele_id) = $chado->validate_feature(query => $query_id, genome => $genome_ids->{genome}, uniquename => $uniquename,
			public => $pub_value, feature_type => 'vfamr');
	
	if($result eq 'new_conflict') {
		warn "Attempt to add gene allele multiple times. Dropping duplicate of allele $uniquename.";
		return 0;
	}
	if($result eq 'db_conflict') {
		warn "Attempt to update existing gene allele multiple times. Skipping duplicate allele $uniquename.";
		return 0;
	}
	if($result eq 'db' || defined($allele_id)) {
		warn "Attempt to load gene allele already in database. Skipping duplicate allele $uniquename.";
		return 0;
	}
	
	
	
	# Create new allele feature
	
	# ID
	my $curr_feature_id = $chado->nextfeature($is_public);

	# retrieve genome data
	my $collection_info = $chado->collection($genome_ids->{genome}, $is_public) unless $is_public;
	
	# organism - assume ecoli
	my $organism = $chado->organism_id();
	
	# external accessions
	my $dbxref = '\N';
	
	# name
	my $name = "$query_name allele";
	
	# Feature relationships
	$chado->handle_parent(subject => $curr_feature_id, genome => $genome_ids->{genome}, contig => $contig_id, public => $is_public);
	$chado->handle_query_hit($curr_feature_id, $query_id, $is_public);
	
	# Additional Feature Types
	$chado->add_types($curr_feature_id, $is_public);
	
	# Sequence location
	$chado->handle_location($curr_feature_id, $contig_id, $min, $max, $strand, $is_public);
	
	# Feature properties
	my $upload_id = $is_public ? undef : $collection_info->{upload};
	$chado->handle_allele_properties($curr_feature_id, $allele_num, $is_public, $upload_id);
	
	# Print feature
	$chado->print_f($curr_feature_id, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $residues, $is_public, $upload_id);  
	$chado->nextfeature($is_public, '++');
	
	$allele_id = $curr_feature_id;
		
	# Record event in cache
	
	$chado->feature_cache('insert' => 1, feature_id => $allele_id, uniquename => $uniquename, genome_id => $genome_ids->{genome},
		query_id => $query_id, is_public => $pub_value);
	
	my $allele_hash = {
		genome => $genome_ids->{genome},
		header => $header,
		allele => $allele_id,
		copy => $allele_num,
		contig => $contig_id,
		public => $is_public,
		is_new => 1,
		seq => $seq,
	};
	push @$seq_group, $allele_hash;
		
	if($chado->is_typing_sequence($query_id)) {
		$chado->record_typing_sequences($query_id, $allele_hash);
	}
	
	return 1;
}

sub elapsed_time {
	my ($mes) = @_;
	
	my $time = $now;
	$now = time();
	printf("$mes: %.2f\n", $now - $time);
	
}

sub parse_loci_header {
	my $header = shift;
	
	my ($access, $contig_collection_id, $access2, $contig_id, $allele_num) = ($header =~ m/^(?:lcl\|)?(public|private)_(\d+)\|(public|private)_(\d+)(?:_a(\d+))?$/);
	croak "Invalid contig_collection ID format: $header\n" unless $access;
	croak "Invalid contig ID format: $header\n" unless $access2;
	croak "Invalid header: $header" unless $access eq $access2;

	$allele_num = 1 unless $allele_num;
	$header =~ s/_\-a\d+$//;
	
	return {
		access => $access,
		genome => $contig_collection_id,
		feature => $contig_id,
		copy => $allele_num,
		position_file_header => $header
	};
}

