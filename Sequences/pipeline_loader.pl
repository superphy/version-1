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
use POSIX qw(strftime);
use Time::HiRes qw( time );
use BerkeleyDB;
use BerkeleyDB::Hash;
use JSON::MaybeXS;

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
    $VACUUM, $LOGFILE);

my $TEST = 0;
my $LOG = undef;

GetOptions(
	'config=s' => \$CONFIGFILE,
    'dir=s' => \$ROOT,
    'noload' => \$NOLOAD,
    'recreate_cache'=> \$RECREATE_CACHE,
    'remove_lock'  => \$REMOVE_LOCK,
    'save_tmpfiles'=>\$SAVE_TMPFILES,
    'manual' => \$MANPAGE,
    'debug' => \$DEBUG,
    'vacuum' => \$VACUUM,
    'test' => \$TEST,
    'log=s' => \$LOGFILE
) 
or pod2usage(-verbose => 1, -exitval => 1);
pod2usage(-verbose => 2, -exitval => 1) if $MANPAGE;


$SIG{__DIE__} = $SIG{INT} = 'cleanup_handler';

croak "You must supply the path to the top-level results directory" unless $ROOT;
$ROOT .= '/' unless $ROOT =~ m/\/$/;

# Initialize the chado adapter
my %argv;

$argv{config}           = $CONFIGFILE;
$argv{noload}           = $NOLOAD;
$argv{recreate_cache}   = $RECREATE_CACHE;
$argv{save_tmpfiles}    = $SAVE_TMPFILES;
$argv{vacuum}           = $VACUUM;
$argv{debug}            = $DEBUG;
$argv{use_cached_names} = 1; # Pull contig names from DB tmp table
$argv{feature_type}     = 'party_mix'; # Concurrently load pangenome, vfamr and genome features
$argv{test}             = 1 if $TEST; 

my $chado = Sequences::ExperimentalFeatures->new(%argv);

# SET UP LOGGER
if($LOGFILE) {

	open($LOG, ">", $LOGFILE) or croak "Unable to open $LOGFILE for write operation ($!)\n";

	print $LOG "****START OF pipeline_loader.pl LOG ENTRY****\n";
}


# BEGIN
my $vf_dir = $ROOT . '/vf/';
my $pg_dir = $ROOT . '/pg/';

# Lock table so no one else can upload
$chado->remove_lock() if $REMOVE_LOCK;
$chado->place_lock();
my $lock = 1;

logger("Initialization");

# Prepare tmp files for storing upload data
$chado->file_handles();

logger("Initialization complete.");
logger("Process genome meta-data");

# Load genome sequences and meta data
genomes();

logger("Genomes complete");
logger("Process pangenome data");

# Load the pangenome features
pangenome($pg_dir);

logger("Pangenomes complete");
logger("Process vfamr data");

# Load the vf/amr gene features
vfamr($vf_dir);

logger("Vfamr complete");
logger("Loading data");

# Finalize and load into DB
unless ($NOLOAD) {
	if($LOG) {
		my $curr_fh = select($LOG); # Set current filehandle to $LOG
		$chado->load_data($LOG);
		select($curr_fh);
	}
	else {
		$chado->load_data();
	}
	
}

logger("Loading complete");

$chado->remove_lock();

logger("pipeline_loader.pl complete");

exit(0);


=head2 cleanup_handler


=cut

sub cleanup_handler {
    warn "@_\nAbnormal termination, trying to clean up...\n\n" if @_;  
    #gets the message that the die signal sent if there is one
    if ($chado && $chado->dbh->ping) {
        
        if ($lock) {
            warn "Trying to remove the run lock (so that --remove_lock won't be needed)...\n";
            $chado->abort(); #remove any active locks, discard DB transaction
        }
        
        print STDERR "Exiting...\n";
    }
    exit(1);
}

=head2 genomes 

=cut

sub genomes {

	my $meta_dir = $ROOT . 'meta/';
	my $fasta_dir = $ROOT . 'fasta/';
	my $opt_dir = $ROOT . 'opt/';
	my $job_file = $ROOT . 'pending_uploads.txt';

	# Load tracking IDs and options files
	my @jobs;
	open(IN, "<$job_file") or croak "Error: unable to read job file $job_file ($!).\n";
	while(<IN>) {
		chomp;
		push @jobs, [split(/\t/, $_)];
	}
	close IN;

	foreach my $rec (@jobs) {
		my $tracking_id = $rec->[0];
		my $opt_file = $rec->[1];

		my $cfg = new Config::Simple($opt_file) or croak "Error: unable to read config file $opt_file";
		my $prop_file = $cfg->param('load.propfile') or croak "Error: missing parameter propfile in options file $opt_file.";
		my $fasta_file = $cfg->param('load.fastafile') or croak "Error: missing parameter fastafile in options file $opt_file.";

		my ($genome_feature_properties, $upload_params) = load_input_parameters($prop_file);

		# Validate genome parameters
		my ($f, $fp, $dx, $loc) = validate_genome_properties($genome_feature_properties);

		# Validate upload parameters
		validate_upload_parameters($upload_params);

		my $upload_id =	$chado->handle_upload(
			category     => $upload_params->{category},
        	upload_date  => $upload_params->{upload_date},
            login_id     => $upload_params->{login_id},
            release_date => $upload_params->{release_date},
            tag          => $upload_params->{tag},
        );

		# Contig collection feature
		my $is_public = 0;
	
		# Feature type of parent: contig_collection
		my $type = $chado->feature_types('contig_collection');
		
		# Feature_id 
		my $curr_feature_id = $chado->nextfeature($is_public);
		
		# Uniquename
		my $uniquename = $f->{'uniquename'};

		
		# Verifies if name is unique, otherwise modify uniquename so that it is unique
		# Note: this does not to be used for update-checks based on uniquename
		$uniquename = $chado->genome_uniquename($uniquename, $curr_feature_id, $is_public);
		    
		## Note uniquename may have changed and changed name will have been cached. Do we need to know original?
		
		# Name
		my $name = $f->{name};
		
		# Sequence Length
		my $seqlen = '\N';
		# Residues
		my $residues = '\N';
		
		
		# Properties
		if(%$fp) {
			$chado->handle_genome_properties($curr_feature_id, $fp, $is_public, $upload_id);
		}
		
		# Dbxref
		my $dbxref_id = '\N';
		if(%$dx) {
			$dbxref_id = $chado->handle_dbxref($curr_feature_id, $dx, $is_public);
		}

		# Location
		if(%$loc) {
			$chado->handle_genome_location($curr_feature_id, $loc, $is_public);
		}
		
		
		# Print  
		$chado->print_f($curr_feature_id, $chado->organism_id, $name, $uniquename, $type, $seqlen, 
			$dbxref_id, $residues, $is_public, $upload_id);  
		$chado->nextfeature($is_public, '++');

		# Load contigs
		my $fasta = Bio::SeqIO->new(-file   => $fasta_file, -format => 'fasta');
                              
		while (my $entry = $fasta->next_seq) {
			load_contig($entry, $tracking_id, $curr_feature_id, $uniquename, $upload_id);
		}

		# Save new genome feature in caches
		$chado->cache_genome_id($curr_feature_id, $is_public, $uniquename, $chado->organism_id,
			$upload_params->{category}, $upload_id);
	}

}

=head2 load_input_parameters

loads hash produced by Data::Dumper with genome properties and upload user settings.

=cut

sub load_input_parameters {
	my $file = shift;
	
	open(IN, "<$file") or die "Error: unable to read file $file ($!).\n";

    local($/) = "";
    my($str) = <IN>;
    
    close IN;
    
    my $contig_collection_properties;
    my $upload_parameters;
    eval $str;
    
    return ($contig_collection_properties, $upload_parameters);
}

=head2 validate_genome_properties

Examines data hash containing genome properties.
Makes sure keys are recognized and then splits data
into separate hashes corresponding to each DB table.

Returns

List of 3 data hashrefs contains key value pairs of:
1. Feature table properties
2. Featureprop table properties
3. Dbxref table properties

=cut

sub validate_genome_properties {
	my $hash = shift;
	
	my %valid_f_tags = qw/name 1 uniquename 1 organism 1 properties 1/;
	my %valid_fp_tags = qw/mol_type 1 serotype 1 strain 1 keywords 1 isolation_host 1 
		isolation_date 1 description 1 owner 1 finished 1 synonym 1
		comment 1 isolation_source 1 isolation_age 1 severity 1
		syndrome 1 pmid 1/;
	my %valid_dbxref_tags = qw/primary_dbxref 1 secondary_dbxref 1/;
	my %valid_l_tags = qw/isolation_location 1/; 
	
	# Make sure no unrecognized property types
	# Assign value to proper table hash
	my %f; my %fp; my %dx; my %loc;
	foreach my $type (keys %$hash) {
		
		if($valid_f_tags{$type}) {
			if(ref $hash->{$type} eq 'ARRAY') {
				# Some scripts return every value as arrayref
				# Feature values are always singletons, so this
				# should be safe
				# There is no logical option for multiple names
				$f{$type} = pop @{$hash->{$type}}
			} else {
		
				$f{$type} = $hash->{$type};
			}
			
		} elsif($valid_fp_tags{$type}) {
			$fp{$type} = $hash->{$type};
			
		} elsif($valid_dbxref_tags{$type}) {
			# Must supply hash with keys: acc, db
			# Optional: ver, desc
			
			my @entries;
			
			if(ref $hash->{$type} eq 'ARRAY') {
				@entries = @{$hash->{$type}}
			} else {
				@entries = ($hash->{$type});
			}
			
			foreach my $dbxref (@entries) {
				my $db = $dbxref->{db};
				croak 'Must provide a DB for foreign IDs.' unless $db;
				
				my $acc = $dbxref->{acc};
				croak 'Must provide a accession for foreign IDs.' unless $acc;
				
				my $ver = $dbxref->{ver};
				$ver ||= '';
				
				my $desc = $dbxref->{desc};
				$desc ||= '\N';
				
				if($type eq 'primary_dbxref') {
					croak 'Primary foreign ID re-defined.' if defined($dx{primary});
					$dx{primary} = { db => $db, acc => $acc, ver => $ver, desc => $desc };
				} else {
					$dx{secondary} = [] unless $dx{secondary};
					push @{$dx{secondary}}, { db => $db, acc => $acc, ver => $ver, desc => $desc };
				}
			}
			
		} elsif($valid_l_tags{$type}) {
			$loc{$type} = $hash->{$type};
			
		} else {
			croak "Invalid genome property type $type.";
		}
	}
	
	# Required types, no default values.
	croak 'Missing required genome property "uniquename".' unless $f{uniquename};
	croak 'Missing primary foreign ID (only required when secondary foreign ID defined)' if defined($dx{secondary}) && !defined($dx{primary});
	
	
	# Initialize other required properties with default values
	$f{name} = $f{uniquename} unless $f{name};
	if($f{organism}) {
		croak "Unexpected organism: $f{organism}.\n" unless $f{organism} eq 'Escherichia coli';
	} else {
		$f{organism} = 'Escherichia coli';
	}
	
	$fp{mol_type} = 'dna' unless $fp{mol_type};
	
	return(\%f, \%fp, \%dx, \%loc);
}


=head2 validate_upload_parameters

Examines data hash containing upload parameters.

Also initializes some required parameters
that have default values in the hash ref.

=cut

sub validate_upload_parameters {
	my $hash = shift;
	
	my @valid_parameters = qw/login_id tag release_date upload_date category/;
		
	my %valid;
	map { $valid{$_} = 1 } @valid_parameters;
	
	# Make sure no unrecognized parameters
	foreach my $type (keys %$hash) {
		croak "Invalid upload parameter $type." unless $valid{$type};
	}
	
	# Required parameters, no default values.
	croak 'Missing required upload parameter "category".' unless $hash->{category};
	my %valid_cats = (public => 1, private => 1, release => 1);
	croak "Invalid category: ".$hash->{category} unless $valid_cats{$hash->{category}};
	
	if($hash->{category} eq 'release') {
		croak 'Missing required upload parameter "release_date".' unless $hash->{release_date};
	}
	
	# Set default parameters
	$hash->{login_id} = 0 unless $hash->{login_id};
	
	unless($hash->{upload_date}) {
		my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
		$hash->{upload_date} = $date;
	}
	$hash->{tag} = 'Unclassified' unless $hash->{tag};
	
	return(1);
}

sub load_contig {
	my ($contig, $t, $cc_id, $cc_uniquename, $upload_id) = @_;

	my $is_public = 0;
	
	# Feature type of child: contig
	my $type = $chado->feature_types('contig');
	
	# Feature_id 
	my $curr_feature_id = $chado->nextfeature($is_public);
	
	# Get the user-submitted description and name from DB cache
	# Needed to over-write these values with place-holders recognized by program
	my $chr_num;
	
	my $tmp_id = $contig->display_id;
	(my $trk_id, $chr_num) = ($tmp_id =~ m/lcl\|upl_(\d+)\|(\d+)/);
	
	croak "Invalid temporary ID ($tmp_id) for contig." unless $trk_id && $chr_num;
	croak "Tracking ID in temporary ID does not match supplied tracking ID ($tmp_id, $t)" unless $trk_id == $t;
	
	my ($name, $desc) = $chado->retrieve_contig_meta($trk_id, $chr_num);

	# Sequence Length
	my $seqlen = $contig->length;
	# Residues
	my $residues = $contig->seq();
	
	
	# DBxref
	my $dbxref = '\N';
	
	
	# Contig properties
	my %contig_fp;
	
	# mol_type
	# if plasmid or chromosome is in header, change default
	my $mol_type = 'dna';
	
	# description
	if($desc) {
		# if plasmid or chromosome is in header, change default
		if($desc =~ m/plasmid/i || $name =~ m/plasmid/i) {
			$mol_type = 'plasmid';
		} elsif($desc =~ m/chromosome/i || $name =~ m/chromosome/i) {
			$mol_type = 'chromosome';
		}
	
		$contig_fp{description} = $desc;
	} else {
		if($name =~ m/plasmid/i) {
			$mol_type = 'plasmid';
		} elsif($name =~ m/chromosome/i) {
			$mol_type = 'chromosome';
		}
	}
	$contig_fp{mol_type} = $mol_type;
	
	$chado->handle_genome_properties($curr_feature_id, \%contig_fp, $is_public, $upload_id);
	
	# Create unique contig name derived from contig_collection uniquename
	# Since contig_collection uniquename is guaranteed unique, contig name should be unique.
	# Saves us from doing a DB query on the many contigs that could be in the fasta file.
	my $uniquename = $name;
	$uniquename .= "- part_of:$cc_uniquename";
	
	
	# Feature relationships
	$chado->handle_parent(subject => $curr_feature_id, genome => $cc_id, public => 0);
	
	
	# Print
	$chado->print_f($curr_feature_id, $chado->organism_id, $name, $uniquename, $type, $seqlen, $dbxref, $residues, $is_public, $upload_id); 
	$chado->nextfeature($is_public, '++');
	
	# Cache feature ID for newly loaded contig
	$chado->cache_contig_id($t, $cc_id, $curr_feature_id, $chr_num);
}


=head2 pangenome


=cut

sub pangenome {
	my $pg_root = shift;

	# Result files
	my $function_file = $pg_root . 'panseq_nr_results/anno.txt';
	my $allele_fasta_file = $pg_root . 'panseq_pg_results/locus_alleles.fasta';
	my $allele_pos_file = $pg_root . 'panseq_pg_results/pan_genome.txt';
	my $msa_dir = $pg_root . 'fasta/';
	my $tree_dir = $pg_root . 'perl_tree/';
	my $refseq_dir = $pg_root . 'refseq/';
	my $snp_pos_dbpath  = $pg_root . 'snp_positions.db';
	my $snp_var_dbpath  = $pg_root . 'snp_variations.db';
	my $snp_alignments_dir = $pg_root . 'snp_alignments/';
	my $job_file = $pg_root . 'jobs.txt';

	# Connect to BerkeleyDBs containing snp data
	my $env = new BerkeleyDB::Env(
    	-Cachesize => 4 * 1024 * 1024,
        -Flags     => (DB_CREATE()     |
                       DB_INIT_CDB()   |
                       DB_INIT_MPOOL()))
        or croak "Failed to create DB env: '$!' ($BerkeleyDB::Error)\n";

    my $posdb = new BerkeleyDB::Hash(
    	-Filename => $snp_pos_dbpath,
        -Env      => $env,
        -Flags    => DB_CREATE())
    or croak "Failed to open DBPATH: '$!' ($BerkeleyDB::Error)\n";

    my $vardb = new BerkeleyDB::Hash(
    	-Filename => $snp_var_dbpath,
        -Env      => $env,
        -Flags    => DB_CREATE())
    or croak "Failed to open DBPATH: '$!' ($BerkeleyDB::Error)\n";

	# Load function descriptions for newly detected pan-genome regions
	my %func_anno;
	if(-e $function_file && -s $function_file) {
		open IN, "<", $function_file or croak "Error: unable to read file $function_file ($!).\n";

		while(<IN>) {
			chomp;
			# BLAST Output tabular format: queryId, subjectId, percIdentity, alnLength, mismatchCount, gapOpenCount, queryStart, queryEnd, subjectStart, subjectEnd, eVal, bitScore
			my ($q, $qlen, $s, $slen, $t) = split(/\t/, $_);
			$func_anno{$q} = [$s,$t];
		}
		close IN;
	}

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
			
			$loci{$query_id}->{$header}->{$allele} = {
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

		my ($query_id, $do_tree, $do_snp, $add_seq, $in_core) = @$job;
		
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
			croak "Error: Core violation! Newly discovered pangenome region $query_id assigned core status" if $in_core;

			$pg_feature_id = $chado->handle_pangenome_segment($in_core, $func, $func_id, $seq);

		} else {
			# Pangenome fragment already in DB
			$pg_feature_id = $query_id;

			# Save core status
			$chado->cache('core', $pg_feature_id, $in_core);
		}
		
		# Load allele sequences
		my $num_ok = 0;  # Some loci sequences fail checks, so the overall number of sequences can drop making trees/snps irrelevant
		my $locus_name = $query_id;
		my $msa_file = $msa_dir . "$locus_name.ffn";
		my $has_new = 0;
		my @sequence_group;
			
		my $fasta = Bio::SeqIO->new(-file   => $msa_file,
	                                -format => 'fasta') or die "Unable to open Bio::SeqIO stream to $msa_file ($!).";
	    
		while (my $entry = $fasta->next_seq) {
			my $id = $entry->display_id;

			if($id =~ m/upl_/) {
				# New, add
				# NOTE: will check if attempt to insert allele multiple times
				$num_ok++ if add_pangenome_loci(\%loci, $locus_name, $pg_feature_id, $id, $entry->seq, \@sequence_group);
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
		if($do_tree && $num_ok > 2) {
			my $tree_file = $tree_dir . "$locus_name\_tree.perl";
			load_tree($tree_file, $pg_feature_id, \@sequence_group) 
		}
		
		# Load snps
		if($do_snp && $num_ok > 1) {
			my %snp_files = (
				aln => "$refseq_dir/$locus_name\_aln.ffn",
				snp => "$snp_alignments_dir/$locus_name\_snp.ffn",
			);
			load_snps(\%snp_files, $pg_feature_id, \@sequence_group, $vardb, $posdb);
		}
		
			
	}

}


=head2 add_pangenome_loci


=cut

sub add_pangenome_loci {
	my ($loci, $pg_key, $pg_id, $header, $seq, $seq_group) = @_;
	
	# Parse input
	
	# Parse allele FASTA header
	my $genome_ids = parse_loci_header($header);
	my $tracker_id = $genome_ids->{genome};
	
	# privacy setting
	my $is_public = 0;
	my $pub_value = 'FALSE';
	
	# location hash
	my $loc_hash = $loci->{$pg_key}->{$genome_ids->{position_file_header}}->{$genome_ids->{copy}};
	unless(defined $loc_hash) {
		warn "Missing location information for locus allele $pg_key ($pg_id) in contig $header (lookup details: ".
			$genome_ids->{position_file_header}.",".
			$genome_ids->{copy}.").\n" unless defined $loc_hash;
		return;
	}

	# Retrieve contig_collection and contig feature IDs
	my $contig_num = $loc_hash->{contig};
	my ($contig_collection_id, $contig_id) = $chado->retrieve_contig_info($tracker_id, $contig_num);
	croak "Missing feature IDs in pipeline cache for tracker ID $tracker_id and contig $contig_num.\n" unless $contig_collection_id && $contig_id;
	
	# contig sequence positions
	my $start = $loc_hash->{start};
	my $end = $loc_hash->{end};
	
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
	my ($result, $allele_id) = $chado->validate_feature(query => $pg_id, genome => $contig_collection_id, uniquename => $uniquename,
			public => $pub_value, feature_type => 'pangenome');
	
	if($result eq 'new_conflict') {
		warn "Attempt to add pangenome loci multiple times. Dropping duplicate of loci $uniquename.";
		return 0;
	}
	if($result eq 'db_conflict') {
		warn "Attempt to update existing pangenome loci multiple times. Skipping duplicate loci $uniquename.";
		return 0;
	}
	if($result eq 'db' || defined($allele_id)) {
		warn "Attempt to load pangenome loci already in database. Skipping duplicate loci $uniquename.";
		return 0;
	}
	
	# NEW
	# Create allele feature
	
	# ID
	my $curr_feature_id = $chado->nextfeature($is_public);

	# retrieve genome data
	my $collection_info = $chado->collection($contig_collection_id, $is_public);
	
	# organism
	my $organism = $collection_info->{organism};
	
	# external accessions
	my $dbxref = '\N';
	
	# name
	my $name = "loci derived from $pg_id";

	# Feature relationships
	$chado->handle_parent(subject => $curr_feature_id, genome => $contig_collection_id, contig => $contig_id, public => $is_public);
	$chado->handle_pangenome_loci($curr_feature_id, $pg_id, $is_public, $contig_collection_id);
	
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
	$chado->feature_cache('insert' => 1, feature_id => $allele_id, uniquename => $uniquename, genome_id => $contig_collection_id,
		query_id => $pg_id, is_public => $pub_value, feature_type => 'pangenome');
	
	push @$seq_group, {
		genome => $contig_collection_id,
		allele => $allele_id,
		header => $header,
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

	# upload id
	my $upl_id = $is_public ? 0 : $chado->placeholder_upload_id;
	
	# Only residues and seqlen get updated, the other values are non-null placeholders in the tmp table
	$chado->print_uf($locus_id,$locus_id,$type,$seqlen,$residues,$is_public,$upl_id);
		
	push @$seq_group, {
		genome => $contig_collection_id,
		allele => $locus_id,
		header => $header,
		public => $is_public,
		is_new => 0,
		seq => $residues
	};
}

sub load_tree {
	my ($tree_file, $query_id, $seq_group) = @_;
	
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
	
	my @replacements = sort {
		length $b <=> length $a ||
		$b cmp $a
	} keys %conversions;
	foreach my $old (@replacements) {
		my $new = $conversions{$old};
		my ($num_repl) = ($tree =~ s/\Q$old\E/\Q$new\E/g);
		warn "No replacements made in phylogenetic tree. $old not found." unless $num_repl;
		warn "Multiple replacements ($num_repl) made in phylogenetic tree. $old is not unique." if $num_repl > 1;
	}
	
	# add tree in tables
	$chado->handle_phylogeny($tree, $query_id, $seq_group);
	
}

sub load_snps {
	my ($files, $query_id, $sequence_group, $vardb, $posdb) = @_;

	my $aln_file = $files->{aln} or croak "Error in load_snps: missing aln argument.\n";
	my $snp_aln_file = $files->{snp} or croak "Error in load_snps: missing snp argument.\n";
	
	# Load the newly aligned reference pangenome sequence
	open(my $afh, '<', $aln_file) or croak "Error: unable to read reference pangenome alignment file $aln_file ($!).\n";
	<$afh>; # header
	my $refseq = <$afh>;
	close $afh; 
	
	
	# Regions in the reference pangenome sequence containing newly inserted gaps adjacent to existing gaps need to be
	# resolved.
	# At the end of handle_ambiguous_blocks, all gaps in these regions will be added as snp_core entries.
	my $ambiguous_regions = $chado->snp_audit($query_id, $refseq);
	if(@$ambiguous_regions) {
		
		my %snp_alignment_sequences;
		
		# Need to load new alignments into memory
		my $fasta = Bio::SeqIO->new(-file   => $snp_aln_file,
									-format => 'fasta') or croak "Error: unable to open Bio::SeqIO stream to $snp_aln_file ($!).";

		while (my $entry = $fasta->next_seq) {
			my $id = $entry->display_id;
			
			next if $id =~ m/^refseq/; # already have refseq in memory
			$snp_alignment_sequences{$id}->{seq} = $entry->seq;
		}
		
		$chado->handle_ambiguous_blocks($ambiguous_regions, $query_id, $refseq, \%snp_alignment_sequences);
	}
	
	# Retrieve SNP variations for this pangenome region from BerkeleyDB
	my $json;
	my $rv = $vardb->db_get($query_id, $json);
	if($rv) {
	    croak "Error: no snp variation data for pangenome region $query_id in BerkeleyDB\n";
	} 

	my $variations = decode_json($json);

	# Compute snps relative to the reference alignment for all new loci
	# Performed by parallel script, load data for each genome
	foreach my $genome_hash (@$sequence_group) {
		if($genome_hash->{is_new}) {
			my $g = $genome_hash->{header};
			my $genome_vars = $variations->{$g};
			croak "Error: Genome $g does not have any variations\n" unless @$genome_vars;
			find_snps($genome_vars, $query_id, $genome_hash);
		}
	}

	# Retrieve SNP positions for this pangenome region from BerkeleyDB
	$rv = $posdb->db_get($query_id, $json);
	if($rv) {
	    croak "Error: no snp position data for pangenome region $query_id in BerkeleyDB\n";
	} 

	my $positions = decode_json($json);

	# Load snp positions in each sequence
	# Must be run after all snps loaded into memory
	foreach my $genome_hash (@$sequence_group) {
		if($genome_hash->{is_new}) {
			my $g = $genome_hash->{header};
			my $genome_pos = $positions->{$g};
			croak "Error: Genome $g does not have any snp positions\n" unless @$genome_pos;
			locate_snps($genome_pos, $query_id, $genome_hash);
		}
	}


}


sub find_snps {
	my $genome_vars = shift;
	my $ref_id = shift;
	my $genome_info = shift;

	my $genome = $genome_info->{header};
	my $contig_collection = $genome_info->{genome};
	my $contig = $genome_info->{contig};
	my $locus = $genome_info->{allele};
	my $is_public = $genome_info->{public};
	
	foreach my $row (@$genome_vars) {
		my ($pos, $gap, $refc, $seqc) = @$row;
		croak "Error: invalid snp variation format." unless $seqc;
		$chado->handle_snp($ref_id, $refc, $pos, $gap, $contig_collection, $contig, $locus, $seqc, $is_public);
	}
}

sub locate_snps {
	my $genome_pos = shift;
	my $ref_id = shift;
	my $genome_info = shift;

	my $genome = $genome_info->{header};
	my $contig_collection = $genome_info->{genome};
	my $contig = $genome_info->{contig};
	my $locus = $genome_info->{allele};
	my $is_public = $genome_info->{public};

	foreach my $row (@$genome_pos) {
		my ($start1, $start2, $end1, $end2, $gap1, $gap2) = @$row;
		croak "Error: invalid snp position format." unless defined $gap2;
		$chado->handle_snp_alignment_block($contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public);
	}

}

=head2 vfamr

=cut

sub vfamr {
	my $vfamr_root = shift;

	my $allele_fasta_file = $vfamr_root . 'panseq_vf_amr_results/locus_alleles.fasta';
	my $allele_pos_file = $vfamr_root . 'panseq_vf_amr_results/pan_genome.txt';
	my $msa_dir = $vfamr_root . 'fasta/';
	my $tree_dir = $vfamr_root . 'perl_tree/';
	my $job_file = $vfamr_root . 'jobs.txt';

	# Load locus locations
	my %loci;
	open(my $in, "<", $allele_pos_file) or croak "Error: unable to read file $allele_pos_file ($!).\n";
	<$in>; # header line
	while (my $line = <$in>) {
		chomp $line;
		
		my ($id, $locus, $genome, $allele, $start, $end, $header) = split(/\t/,$line);

		if($allele > 0) {
			# Hit
			my ($query_id) = $locus =~ m/^(?:VF|AMR)_(\d+)\|/;
			my ($contig) = $header =~ m/lcl\|\w+\|(\w+)/;

			croak "Error: duplicate position entries found for pangenome reference $locus and loci $header.\n" if defined $loci{$query_id}->{$header};

			$loci{$query_id}->{$header} = {
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


	# Iterate through each gene
	foreach my $job (@jobs) {

		my ($query_id, $do_tree, $do_snp, $add_seq, 
			$throwaway) = @$job;

		# Load allele sequences
		my $num_ok = 0;  # Some allele sequences fail checks, so the overall number of sequences can drop making trees irrelevant
		my $msa_file = $msa_dir . "$query_id.ffn";
		my $has_new = 0;
		my @sequence_group;
		my $fasta = Bio::SeqIO->new(-file   => $msa_file,
	                                -format => 'fasta') or die "Unable to open Bio::SeqIO stream to $msa_file ($!).";
	    
		while (my $entry = $fasta->next_seq) {
			my $id = $entry->display_id;
				
			if($id =~ m/upl_/) {
				# New, add
				# NOTE: will check if attempt to insert allele multiple times
				$num_ok++ if allele(\%loci, $query_id, $id, $entry->seq, \@sequence_group);	
				$has_new = 1;
			} else {
				# Already in DB, update
				# NOTE: DOES NOT CHECK IF SAME ALLELE GETS UPDATED MULTIPLE TIMES,
				# If this is later deemed necessary, need uniquename to track alleles
				update_allele_sequence($id, $entry->seq, \@sequence_group);
				# No non-fatal checks on done on update ops. i.e. checks where the program can discard sequence and continue.
				# So if you get to this point, you can count this updated sequence.
				$num_ok++; 
			}
		}
			
		die "Locus $query_id alignment contains no new genome sequences. Why was it run then? (likely indicates error)." unless $has_new;
		
		# Load tree
		if($do_tree && $num_ok > 2) {
			my $tree_file = $tree_dir . "$query_id\_tree.perl";
			load_tree($tree_file, $query_id, \@sequence_group) 
		}
	}

}

=head2 allele


=cut

sub allele {
	my ($loci, $query_id, $header, $seq, $seq_group) = @_;
	
	# Parse input
	
	# Parse allele FASTA header
	my $genome_ids = parse_loci_header($header);
	my $tracker_id = $genome_ids->{genome};
	
	# privacy setting
	my $is_public = 0;
	my $pub_value = 'FALSE';

	# location hash
	my $allele_num = $genome_ids->{copy};
	my $loc_hash = $loci->{$query_id}->{$genome_ids->{position_file_header}};
	unless(defined $loc_hash) {
		warn "Missing location information for locus allele $query_id in contig $header (lookup details: ".
			$genome_ids->{position_file_header}.",".
			$allele_num.").\n" unless defined $loc_hash;
		croak;
	}
	
	# Retrieve contig_collection and contig feature IDs
	my $contig_num = $loc_hash->{contig};
	my ($contig_collection_id, $contig_id) = $chado->retrieve_contig_info($tracker_id, $contig_num);
	croak "Missing feature IDs in pipeline cache for tracker ID $tracker_id and contig $contig_num.\n" unless $contig_collection_id && $contig_id;
	
	# contig sequence positions
	my $start = $loc_hash->{start};
	my $end = $loc_hash->{end};
	
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
	
	# NEW
	# Create allele feature
	
	# ID
	my $curr_feature_id = $chado->nextfeature($is_public);

	# retrieve genome data
	my $collection_info = $chado->collection($contig_collection_id, $is_public);
	
	# organism
	my $organism = $collection_info->{organism};
	
	# external accessions
	my $dbxref = '\N';
	
	# name
	my $name = "$query_id allele";
	
	# Feature relationships
	$chado->handle_parent(subject => $curr_feature_id, genome => $contig_collection_id, contig => $contig_id, public => $is_public);
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
	$chado->feature_cache('insert' => 1, feature_id => $allele_id, uniquename => $uniquename, genome_id => $contig_collection_id,
		query_id => $query_id, is_public => $pub_value, feature_type => 'vfamr');
	
	my $allele_hash = {
		genome => $contig_collection_id,
		allele => $allele_id,
		header => $header,
		#copy => $allele_num,
		contig => $contig_id,
		public => $is_public,
		is_new => 1,
		seq => $seq,
		upload_id => $upload_id
	};
	print "UPLOAD ID FOR ALLELE $allele_id is $upload_id\n";
	push @$seq_group, $allele_hash;
		
	if($chado->is_typing_sequence($query_id)) {
		$chado->record_typing_sequences($query_id, $allele_hash);
	}
	
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

	# upload id
	my $upl_id = $is_public ? 0 : $chado->placeholder_upload_id;
	
	# Only residues and seqlen get updated, the other values are non-null placeholders in the tmp table
	$chado->print_uf($allele_id,$allele_id,$type,$seqlen,$residues,$is_public,$upl_id);

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


=head2 parse_loci_header

Extract genome ID and contig ID from locus_alleles.fasta header

=cut
sub parse_loci_header {
	my $header = shift;
	
	my ($access, $contig_collection_id, $contig_id, $allele_num) = ($header =~ m/^lcl\|(upl)_(\d+)\|(\d+)(?:_a(\d+))?$/);
	croak "Invalid contig_collection ID format: $header\n" unless $access;

	$allele_num = 1 unless $allele_num;
	$header =~ s/_a\d+$//;
	
	return {
		access => $access,
		genome => $contig_collection_id,
		feature => $contig_id,
		copy => $allele_num,
		position_file_header => $header
	};
}

=head2 log

Add entry with timestamp to log file

=cut
sub logger {
	my $msg = shift;

	if($LOG) {
		my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
		print $LOG "$date: $msg\n";
	}
	
}



