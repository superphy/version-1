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
$argv{feature_type}     = 'allele';

my $chado = Sequences::ExperimentalFeatures->new(%argv);

# Result files
my $allele_fasta_file = $ROOT . 'panseq_vf_amr_results/locus_alleles.fasta';
my $allele_pos_file = $ROOT . 'panseq_vf_amr_results/pan_genome.txt';
my $msa_dir = $ROOT . 'fasta/';
my $tree_dir = $ROOT . 'perl_tree/';
my $job_file = $ROOT . 'jobs.txt';


# BEGIN

# Lock table so no one else can upload
$chado->remove_lock() if $REMOVE_LOCK;
$chado->place_lock();
my $lock = 1;

# Prepare tmp files for storing upload data
$chado->file_handles();


# Save data for inserting into database

# Load locus locations
my %loci;
open(my $in, "<", $allele_pos_file) or croak "Error: unable to read file $allele_pos_file ($!).\n";
<$in>; # header line
while (my $line = <$in>) {
	chomp $line;
	
	my ($id, $locus, $genome, $allele, $start, $end, $header) = split(/\t/,$line);
	
	if($allele > 0) {
		# Hit
		
		# query gene
		my ($query_id, $query_name) = ($locus =~ m/(\d+)\|(.+)/);
		croak "Missing query gene ID in locus line: $locus\n" unless $query_id && $query_name;
		
		my ($contig) = $header =~ m/lcl\|\w+\|(\w+)/;
		$loci{$query_id}->{$genome} = {
			allele => $allele,
			start => $start,
			end => $end,
			contig => $contig
		};
	}
	
}

close $in;

# Load gene hits
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
	process_gene($query_id, $do_tree);
		
}

# Finalize and load into DB
$chado->load_data() unless $NOLOAD;

$chado->remove_lock();


exit(0);


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

sub process_gene {
	my ($query_id, $do_tree) = @_;
	
	# Load allele sequences
	my $num_ok = 0;  # Some allele sequences fail checks, so the overall number of sequences can drop making trees irrelevant
	my $msa_file = $msa_dir . "$query_id.ffn";
	my $has_new = 0;
	my %sequence_group;
		
	my $fasta = Bio::SeqIO->new(-file   => $msa_file,
                                -format => 'fasta') or die "Unable to open Bio::SeqIO stream to $msa_file ($!).";
    
	while (my $entry = $fasta->next_seq) {
		my $id = $entry->display_id;
			
		if($id =~ m/^upl_/) {
			# New, add
			# NOTE: will check if attempt to insert allele multiple times
			$num_ok++ if allele($query_id, $id, $entry->seq, \%sequence_group);	
			$has_new = 1;
		} else {
			# Already in DB, update
			# NOTE: DOES NOT CHECK IF SAME ALLELE GETS UPDATED MULTIPLE TIMES,
			# If this is later deemed necessary, need uniquename to track alleles
			update_allele_sequence($id, $entry->seq, \%sequence_group);
			# No non-fatal checks on done on update ops. i.e. checks where the program can discard sequence and continue.
			# So if you get to this point, you can count this updated sequence.
			$num_ok++; 
		}
	}
		
	die "Locus $query_id alignment contains no new genome sequences. Why was it run then? (likely indicates error)." unless $has_new;
	
	# Load tree
	load_tree($query_id, \%sequence_group) if $do_tree && $num_ok > 2;
	
}


=head2 allele


=cut

sub allele {
	my ($query_id, $header, $seq, $seq_group) = @_;
	
	# Parse input
	
	# Parse allele FASTA header
	my $tmp_label = $header;
	my ($tracker_id) = ($tmp_label =~ m/upl_(\d+)/);
	croak "Invalid allele label: $header\n" unless $tracker_id;
	
	# privacy setting
	my $is_public = 0;
	my $pub_value = 'FALSE';
	
	# location hash
	my $loc_hash = $loci{$query_id}->{$header};
	croak "Missing location information for locus allele $query_id in contig $header.\n" unless defined $loc_hash;
	
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
	my $type = $chado->feature_types('allele');
	
	# uniquename - based on contig location and query gene and so should be unique. Can't have duplicate alleles at same spot for a single query gene
	# however can have different query genes with hits at the same spot (if there is any redundancy in the VF or AMR gene sets).
	my $uniquename = "allele:$query_id.$contig_id.$min.$max.$is_public";
	
	# Check if this allele is already in DB
	my ($result, $allele_id) = $chado->validate_feature($query_id,$contig_collection_id,$uniquename,$pub_value);
	
	if($result eq 'new_conflict') {
		warn "Attempt to add gene allele multiple times. Dropping duplicate of allele $uniquename.";
		return 0;
	}
	if($result eq 'db_conflict') {
		warn "Attempt to update existing gene allele multiple times. Skipping duplicate allele $uniquename.";
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
	my $name = "$query_id allele";
	
	# Feature relationships
	$chado->handle_parent($curr_feature_id, $contig_collection_id, $contig_id, $is_public);
	$chado->handle_query_hit($curr_feature_id, $query_id, $is_public);
	
	# Additional Feature Types
	$chado->add_types($curr_feature_id, $is_public);
	
	# Sequence location
	$chado->handle_location($curr_feature_id, $contig_id, $min, $max, $strand, $is_public);
	
	# Feature properties
	my $upload_id = $is_public ? undef : $collection_info->{upload};
	$chado->handle_allele_properties($curr_feature_id, $allele_num, $is_public, $upload_id);
	
	# Print feature
	$chado->print_f($curr_feature_id, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $seq, $is_public, $upload_id);  
	$chado->nextfeature($is_public, '++');
	
	# Update cache
	$allele_id = $curr_feature_id;
	$chado->loci_cache('insert' => 1, feature_id => $allele_id, uniquename => $uniquename, genome_id => $contig_collection_id,
		query_id => $query_id, is_public => $pub_value);
	
	push @$seq_group,
		{
			genome => $contig_collection_id,
			allele => $allele_id,
			header => $header,
			#copy => $allele_num,
			public => $is_public,
			is_new => 1
		};
	
	return 1;
	
}


sub update_allele_sequence {
	my ($header, $seq, $seq_group) = @_;
	
	# IDs
	my ($access, $contig_collection_id, $allele_id) = ($header =~ m/(public|private)_(\d+)\|(\d+)/);
	croak "Invalid contig_collection ID format: $header\n" unless $access;
	
	# privacy setting
	my $is_public = $access eq 'public' ? 1 : 0;
	my $pub_value = $is_public ? 'TRUE' : 'FALSE';
	
	# alignment sequence
	my $residues = $seq;
	$seq =~ tr/-//;
	my $seqlen = length($seq);
	
	# type 
	my $type = $chado->feature_types('allele');
	
	# Only residues and seqlen get updated, the other values are non-null placeholders in the tmp table
	$chado->print_uf($allele_id,$allele_id,$type,$seqlen,$residues,$is_public);

	push @$seq_group,
		{
			genome => $contig_collection_id,
			allele => $allele_id,
			header => $header,
			#copy => 1,
			public => $is_public,
			is_new => 0
		};
}

sub load_tree {
	my ($query_id, $seq_group) = @_;
	
	my $tree_file = $tree_dir . "$query_id\_tree.perl";
	
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
	
	# store tree in tables
	$chado->handle_phylogeny($tree, $query_id, $seq_group);
	
}




