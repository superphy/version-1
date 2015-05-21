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
use Phylogeny::Tree;
use Phylogeny::TreeBuilder;
use Time::HiRes qw( time );

=head1 NAME

$0 - loads panseq VF / AMR analysis into genodo's chado database. This program is written for use in the genodo_pipeline.pl script.

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --dir             Root directory containing subdirectories with BLAST file to load sequence from, MSA fasta files and Newick tree files.
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

my ($CONFIGFILE, $ROOT, $NOLOAD,
    $RECREATE_CACHE, $SAVE_TMPFILES,
    $MANPAGE, $DEBUG,
    $REMOVE_LOCK,
    $DBNAME, $DBUSER, $DBPASS, $DBHOST, $DBPORT, $DBI, $TMPDIR,
    $VACUUM);

GetOptions(
	'config=s' => \$CONFIGFILE,
    'dir=s' => \$ROOT,
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


croak "You must supply the path to the top-level results directory" unless $ROOT;
$ROOT .= '/' unless $ROOT =~ m/\/$/;

# Load database connection info from config file
die "You must supply a configuration filename" unless $CONFIGFILE;
if(my $db_conf = new Config::Simple($CONFIGFILE)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
	$TMPDIR    = $db_conf->param('tmp.dir');
} else {
	die Config::Simple->error();
}
croak "Invalid configuration file." unless $DBNAME;


# Initialize the chado adapter
my %argv;

$argv{dbname}           = $DBNAME;
$argv{dbuser}           = $DBUSER;
$argv{dbpass}           = $DBPASS;
$argv{dbhost}           = $DBHOST;
$argv{dbport}           = $DBPORT;
$argv{dbi}              = $DBI;
$argv{tmp_dir}          = $TMPDIR;
$argv{noload}           = $NOLOAD;
$argv{recreate_cache}   = $RECREATE_CACHE;
$argv{save_tmpfiles}    = $SAVE_TMPFILES;
$argv{vacuum}           = $VACUUM;
$argv{debug}            = $DEBUG;
$argv{use_cached_names} = 1; # Pull contig names from DB tmp table
$argv{feature_type}     = 'pangenome';

my $chado = Sequences::ExperimentalFeatures->new(%argv);

# Result files
my $function_file = $ROOT . 'panseq_nr_results/anno.txt';
#my $msa_dir = $ROOT . 'pg_msa/';
#my $tree_dir = $ROOT . 'pg_tree/';
my $allele_fasta_file = $ROOT . 'panseq_pg_results/locus_alleles.fasta';
my $allele_pos_file = $ROOT . 'panseq_pg_results/pan_genome.txt';
my $msa_dir = $ROOT . 'fasta/';
my $tree_dir = $ROOT . 'perl_tree/';
my $refseq_dir = $ROOT . 'refseq/';
my $snp_positions_dir  = $ROOT . 'snp_positions/';
my $snp_alignments_dir = $ROOT . 'snp_alignments/';
my $job_file = $ROOT . 'jobs.txt';


# BEGIN

# Lock table so no one else can upload
$chado->remove_lock() if $REMOVE_LOCK;
$chado->place_lock();
my $lock = 1;

# Prepare tmp files for storing upload data
$chado->file_handles();


# Save data for inserting into database

# Load function descriptions for newly detected pan-genome regions
my %func_anno;
open IN, "<", $function_file or croak "[Error] unable to read file $function_file ($!).\n";

while(<IN>) {
	chomp;
	my ($q, $qlen, $s, $slen, $t) = split(/\t/, $_);
	$func_anno{$q} = [$s,$t];
}
close IN;

# Load locus locations
my %loci;
open(my $in, "<", $allele_pos_file) or croak "Error: unable to read file $allele_pos_file ($!).\n";
<$in>; # header line
while (my $line = <$in>) {
	chomp $line;
	
	my ($id, $locus, $genome, $allele, $start, $end, $header) = split(/\t/,$line);
	
	if($allele > 0) {
		# Hit
		my ($contig) = $header =~ m/lcl\|\w+\|(\w+)/;
		my $query_id;
		
		if($locus =~ m/^nr_/) {
			$query_id = $locus;
		} elsif($locus =~ m/(pgcor_|pgacc_)(\d+)/) {
			$query_id = $2;
		} else {
			croak "Unrecognized locus name format $locus in pan_genome.txt file.";
		}
		
		$loci{$query_id}->{$genome} = {
			allele => $allele,
			start => $start,
			end => $end,
			contig => $contig
		};
	}
	
}

close $in;

# Load loci hits
my @jobs;
open(my $jfh, '<', $job_file) or croak "Error: unable to read file $job_file ($!).\n";

while(my $line = <$jfh>) {
	chomp $line;
	my @job = split(/\t/, $line);
	
	push @jobs, \@job;
}

close $jfh;

# Create DB entries
foreach my $job (@jobs) {

	my ($query_id, $do_tree, $do_snp, $add_seq) = @$job;
	
	my $pg_feature_id;
	if($query_id =~ m/^nr_/) {
		# Add new pangenome fragments to DB
		my $func = undef;
		my $func_id = undef;
		
		# Blast function
		if($func_anno{$query_id}) {
			($func_id, $func) = @{$func_anno{$query_id}};
		} else {
			warn "Novel pangenome fragment $query_id has no BLAST-based function prediction";
		}
		
		# Sequence
		my $refseq_file = $refseq_dir . "$query_id\_ref.ffn";
		open(my $rfh, '<', $refseq_file) or croak "Error: unable to read refseq file $refseq_file ($!).\n";
		
		<$rfh>; # header
		my $seq = <$rfh>; # sequence
		chomp $seq;
		
		close $rfh;
		
		$seq =~ tr/-//; # Remove gaps, store only raw sequence

		# Core status is always accessory for new pangenome fragments		
		my $in_core = 0;

		$pg_feature_id = $chado->handle_pangenome_segment($in_core, $func, $func_id, $seq);
	} else {
		# Pangenome fragment already in DB
		$pg_feature_id = $query_id;
	}
	
	process_locus($query_id, $pg_feature_id, $do_tree, $do_snp);
		
}

# Finalize and load into DB
unless ($NOLOAD) {
	$chado->load_data();
	build_genome_tree();
}

$chado->remove_lock();

exit(0);

=cut

=head2 cleanup_handler


=cut

sub cleanup_handler {
    warn "@_\nAbnormal termination, trying to clean up...\n\n" if @_;  #gets the message that the die signal sent if there is one
    if ($chado && $chado->dbh->ping) {
        
        if ($lock) {
            warn "Trying to remove the run lock (so that --remove_lock won't be needed)...\n";
            $chado->remove_lock; #remove the lock only if we've set it
        }
        
        print STDERR "Exiting...\n";
    }
    exit(1);
}

=head2 process_gene


=cut

sub process_locus {
	my ($locus_name, $pg_feature_id, $do_tree, $do_snp) = @_;
	
	# Load allele sequences
	my $num_ok = 0;  # Some loci sequences fail checks, so the overall number of sequences can drop making trees/snps irrelevant
	my $msa_file = $msa_dir . "$locus_name.ffn";
	my $has_new = 0;
	my @sequence_group;
		
	my $fasta = Bio::SeqIO->new(-file   => $msa_file,
                                -format => 'fasta') or die "Unable to open Bio::SeqIO stream to $msa_file ($!).";
    
	while (my $entry = $fasta->next_seq) {
		my $id = $entry->display_id;
			
		if($id =~ m/^upl_/) {
			# New, add
			# NOTE: will check if attempt to insert allele multiple times
			$num_ok++ if add_pangenome_loci($locus_name, $pg_feature_id, $id, $entry->seq, \@sequence_group);
			$has_new = 1;
		} else {
			# Already in DB, update
			# NOTE: DOES NOT CHECK IF SAME ALLELE GETS UPDATED MULTIPLE TIMES,
			# If this is later deemed necessary, need uniquename to track alleles
			update_pangenome_loci($id, $entry->seq, \@sequence_group, $do_snp);
			# No non-fatal checks on done on update ops. i.e. checks where the program can discard sequence and continue.
			# So if you get to this point, you can count this updated sequence.
			$num_ok++; 
		}
	}
		
	die "Locus $locus_name alignment contains no new genome sequences. Why was it run then? (likely indicates error)." unless $has_new;
	
	# Load tree
	load_tree($locus_name, $pg_feature_id, \@sequence_group) if $do_tree && $num_ok > 2;
	
	# Load snps
	load_snps($snp_positions_dir, $refseq_dir, $pg_feature_id, \@sequence_group) if $do_snp && $num_ok > 1;
	
}

=head2 add_pangenome_loci


=cut

sub add_pangenome_loci {
	my ($pg_key, $pg_id, $header, $seq, $seq_group) = @_;
	
	# Parse input
	
	# Parse allele FASTA header
	my $tmp_label = $header;
	my ($tracker_id) = ($tmp_label =~ m/upl_(\d+)/);
	croak "Invalid loci label: $header\n" unless $tracker_id;
	
	# privacy setting
	my $is_public = 0;
	my $pub_value = 'FALSE';
	
	# location hash
	my $loc_hash = $loci{$pg_key}->{$header};
	croak "Missing location information for pangenome region $pg_key in contig $header.\n" unless defined $loc_hash;
	
	# Retrieve contig_collection and contig feature IDs
	my $contig_num = $loc_hash->{contig};
	my ($contig_collection_id, $contig_id) = $chado->retrieve_contig_info($tracker_id, $contig_num);
	croak "Missing feature IDs in pipeline cache for tracker ID $tracker_id and contig $contig_num.\n" unless $contig_collection_id && $contig_id;
	
	# contig sequence positions
	my $start = $loc_hash->{start};
	my $end = $loc_hash->{end};
	my $allele_num = $loc_hash->{allele};
	
	# sequence
	my ($seqlen, $min, $max, $strand);
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
	
	# type 
	my $type = $chado->feature_types('locus');
	
	# uniquename - based on contig location and so should be unique (can't have duplicate loci at same spot) 
	my $uniquename = "locus:$contig_id.$min.$max.$is_public";
	
	# Check if this allele is already in DB
	my ($result, $allele_id) = $chado->validate_feature($pg_id,$contig_collection_id,$uniquename,$pub_value);
	
	if($result eq 'new_conflict') {
		#warn "Attempt to add new region multiple times. Dropping duplicate of pangenome region $uniquename.";
		return 0;
	}
	if($result eq 'db_conflict') {
		warn "Attempt to update existing region multiple times. Skipping duplicate pangenome region $uniquename.";
		return 0;
	}
	
	# NEW
	# Create allele feature
	
	# ID
	my $curr_feature_id = $chado->nextfeature($is_public);

	# retrieve genome data
	my $collection_info = $chado->collection($contig_collection_id, $is_public);
	#my $contig_info = $chado->contig($contig_id, $is_public);
	
	# organism
	my $organism = $collection_info->{organism};
	
	# external accessions
	my $dbxref = '\N';
	
	# name
	my $name = "$pg_id locus";
	
	# Feature relationships
	$chado->handle_parent($curr_feature_id, $contig_collection_id, $contig_id, $is_public);
	$chado->handle_pangenome_loci($curr_feature_id, $pg_id, $is_public);
	
	# Additional Feature Types
	$chado->add_types($curr_feature_id, $is_public);
	
	# Sequence location
	$chado->handle_location($curr_feature_id, $contig_id, $min, $max, $strand, $is_public);
	
	# Print feature
	my $upload_id = $is_public ? undef : $collection_info->{upload};
	$chado->print_f($curr_feature_id, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $seq, $is_public, $upload_id);  
	$chado->nextfeature($is_public, '++');
	
	# Record event in cache
	$allele_id = $curr_feature_id;
	$chado->loci_cache('insert' => 1, feature_id => $allele_id, uniquename => $uniquename, genome_id => $contig_collection_id,
		query_id => $pg_id, is_public => $pub_value);
	
	push @$seq_group, {
		genome => $contig_collection_id,
		allele => $allele_id,
		header => $header,
		#copy => $allele_num,
		public => $is_public,
		contig => $contig_id,
		is_new => 1,
		seq => $seq
	};
	
	return 1;
}


sub update_pangenome_loci {
	my ($header, $seq, $seq_group, $do_snp) = @_;
	
	# IDs
	my ($access, $contig_collection_id, $locus_id) = ($header =~ m/(public|private)_(\d+)\|(\d+)/);
	croak "Invalid contig_collection ID format: $header\n" unless $access && $locus_id;
	
	# privacy setting
	my $is_public = $access eq 'public' ? 1 : 0;
	my $pub_value = $is_public ? 'TRUE' : 'FALSE';
	
	# alignment sequence
	my $residues = $seq;
	$seq =~ tr/-//;
	my $seqlen = length($seq);
	
	# type 
	my $type = $chado->feature_types('locus');
	
	# Only residues and seqlen get updated, the other values are non-null placeholders in the tmp table
	$chado->print_uf($locus_id,$locus_id,$type,$seqlen,$residues,$is_public);
		
	push @$seq_group, {
		genome => $contig_collection_id,
		allele => $locus_id,
		header => $header,
		public => $is_public,
		is_new => 0
	};
}

sub load_tree {
	my ($tname, $query_id, $seq_group) = @_;
	
	my $tree_file = $tree_dir . "$tname\_tree.perl";
	
	# slurp tree
	open(my $tfh, '<', $tree_file) or croak "Error: unable to read tree file $tree_file ($!).\n";
	my $tree = <$tfh>;
	chomp $tree;
	close $tfh;
	
	# Swap the headers in the tree with consistent tree names
	# Assumes headers are unique
	my %conversions;
	foreach my $allele_hash (@$seq_group) {
		
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
	
	foreach my $old (keys %conversions) {
		my $new = $conversions{$old};
		my $num_repl = $tree =~ s/$old/$new/g;
		warn "No replacements made in phylogenetic tree. $old not found." unless $num_repl;
		warn "Multiple replacements made in phylogenetic tree. $old is not unique." unless $num_repl;
	}
	
	# add tree in tables
	$chado->handle_phylogeny($tree, $query_id, $seq_group);
	
}

sub load_snps {
	my ($snp_positions_dir, $refseq_dir, $query_id, $sequence_group) = @_;
	
	# Load the newly aligned reference pangenome sequence
	my $aln_file = "$refseq_dir/$query_id\_aln.ffn";
	open(my $afh, '<', $aln_file) or croak "Error: unable to read reference pangenome alignment file $aln_file ($!).\n";
	<$afh>; # header
	my $refseq = <$afh>;
	close $afh; 
	
	# Regions in the reference pangenome sequence containing newly inserted gaps adjacent to existing gaps need to be
	# resolved.
	# At the end of handle_insert_blocks, all gaps in these regions will be added as snp_core entries.
	my $ambiguous_regions = $chado->snp_audit($query_id, $refseq);
	if(@$ambiguous_regions) {
		
		my %snp_alignment_sequences;
		
		# Need to load new alignments into memory
		my $snp_aln_file = "$snp_alignments_dir/$query_id\_snp.ffn";
		my $fasta = Bio::SeqIO->new(-file   => $snp_aln_file,
									-format => 'fasta') or croak "Error: unable to open Bio::SeqIO stream to $snp_aln_file ($!).";

		while (my $entry = $fasta->next_seq) {
			my $id = $entry->display_id;
			
			next if $id =~ m/^refseq/; # already have refseq in memory
			$snp_alignment_sequences{$id}->{seq} = $entry->seq;
		}
		
		$chado->handle_insert_blocks($ambiguous_regions, $query_id, $refseq, \%snp_alignment_sequences);
	}
	

	# Compute snps relative to the reference alignment for all new loci
	# Performed by parallel script, load data for each genome
	foreach my $ghash (@$sequence_group) {
		if($ghash->{is_new}) {
			find_snps($snp_positions_dir, $query_id, $ghash);
		}
	}
}


sub find_snps {
	my $data_dir = shift;
	my $ref_id = shift;
	my $genome_info = shift;
	
	my $genome = $genome_info->{header};
	my $contig_collection = $genome_info->{genome};
	my $contig = $genome_info->{contig};
	my $locus = $genome_info->{allele};
	my $is_public = $genome_info->{public};
	
	# Add row in SNP alignment table for genome, if it doesn't exist
	$chado->add_snp_row($contig_collection,$is_public);
	
	# Load snp variations from file
	my $var_file = $data_dir . "/$ref_id\__$genome\__snp_variations.txt";
	open(my $in, "<", $var_file) or croak "Error: unable to read file $var_file ($!).\n";
	
	while(my $snp_line = <$in>) {
		chomp $snp_line;
		my ($pos, $gap, $refc, $seqc) = split(/\t/, $snp_line);
		croak "Error: invalid snp variation format on line $snp_line." unless $seqc;
		$chado->handle_snp($ref_id, $refc, $pos, $gap, $contig_collection, $contig, $locus, $seqc, $is_public);
	}
	
	close $in;
	
	# Load snp alignment positions from file
	my $pos_file = $data_dir . "/$ref_id\__$genome\__snp_positions.txt";
	open($in, "<", $pos_file) or croak "Error: unable to read file $pos_file ($!).\n";
	
	while(my $snp_line = <$in>) {
		chomp $snp_line;
		my ($start1, $start2, $end1, $end2, $gap1, $gap2) = split(/\t/, $snp_line);
		croak "Error: invalid snp position format on line $snp_line." unless defined $gap2;
		$chado->handle_snp_alignment_block($contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public);
	}
	
	close $in;
}

sub build_genome_tree {
	
	# Intialize the Tree building modules
	my $tree_builder = Phylogeny::TreeBuilder->new();
	my $tree_io = Phylogeny::Tree->new(config => $CONFIGFILE);
	
	# write alignment file
	my $tmp_file = $TMPDIR . 'genodo_genome_aln.txt';
	$tree_io->writeSnpAlignment($tmp_file);
	
	# clear output file for safety
	my $tree_file = $TMPDIR . 'genodo_genome_tree.txt';
	open(my $out, ">", $tree_file) or croak "Error: unable to write to file $tree_file ($!).\n";
	close $out;
	
	# build newick tree
	$tree_builder->build_tree($tmp_file, $tree_file) or croak "Error: genome tree build failed.\n";
	
	# Load tree into database
	my $tree = $tree_io->loadTree($tree_file);
	
}


