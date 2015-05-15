#!/usr/bin/env perl

=head1 NAME

$0 - Processes a fasta file of pangenome sequence fragments and uploads into the feature table of the database specified in the config file.

=head1 SYNOPSIS

    % genodo_pangenome_loader.pl [options]

=head1 COMMAND-LINE OPTIONS

    --panseq            Optionally, specify a panseq results output directory. If not provided, script will download genomes from DB.
    --config            Specify a valid config file with db connection params.

=head1 DESCRIPTION



=head1 AUTHOR

Matt Whiteside

=cut

use strict;
use warnings;
$| = 1;

use Getopt::Long;
use Bio::SeqIO;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Sequences::ExperimentalFeatures;
use Config::Simple;
use Carp qw/croak carp/;
use File::Path qw/remove_tree/;
use IO::CaptureOutput qw(capture_exec);
use Time::HiRes qw( time );

# Globals (set these to match local values)
my $muscle_exe = '/usr/bin/muscle';
my $mummer_dir = '/home/matt/MUMmer3.23/';
my $blast_dir = '/home/matt/blast/bin/';
my $parallel_exe = '/usr/bin/parallel';
my $nr_location = '/home/matt/blast_databases/nr_gammaproteobacteria';
my $panseq_exe = '/home/matt/workspace/c_panseq/live/Panseq/lib/panseq.pl';
my $align_script = "$FindBin::Bin/parallel_tree_builder.pl";
my $blocksize = 2000;
my $partial_load = 0;

$SIG{__DIE__} = $SIG{INT} = 'cleanup_handler';

# Parse command-line
my ($panseq_dir, $config_file,
	$NOLOAD, $RECREATE_CACHE, $SAVE_TMPFILES, $DEBUG, $OVERRIDE,
    $REMOVE_LOCK,
    $VACUUM, $LOGFILE);

my $SLICE = undef;

GetOptions(
	'panseq=s' => \$panseq_dir,
	'config=s' => \$config_file,
	'noload' => \$NOLOAD,
	'recreate_cache'=> \$RECREATE_CACHE,
	'remove_lock'  => \$REMOVE_LOCK,
	'save_tmpfiles'=>\$SAVE_TMPFILES,
	'debug' => \$DEBUG,
	'vacuum' => \$VACUUM,
	'slice=i' => \$SLICE,
	'override' => \$OVERRIDE,
	'log=s' => \$LOGFILE
) or ( system( 'pod2text', $0 ), exit -1 );

croak "[Error] missing argument. You must supply a valid config file\n" . system('pod2text', $0) unless $config_file;

# To reduce disk footprint, a portion of the pangenome can be loaded at the time
# in segments of $block_size. $SLICE determines which segment to load.
my $start_region;
my $end_region;
if(defined $SLICE) {
	$partial_load = 1;
	croak "Error: panseq directory must be specified when the partial load option 'slice' is given." unless $panseq_dir;

	$start_region = $SLICE * $blocksize;
	$end_region = (($SLICE+1) * $blocksize) - 1;
}

my $logger = undef;
if($LOGFILE) {
	open($logger, ">$LOGFILE") or croak "Error: unable to write to file $LOGFILE ($!).\n";
	print "Writing to log $LOGFILE\n";
}


# Initialize the chado adapter
my %argv;

$argv{config}         = $config_file;
$argv{noload}         = $NOLOAD;
$argv{recreate_cache} = $RECREATE_CACHE;
$argv{save_tmpfiles}  = $SAVE_TMPFILES;
$argv{vacuum}         = $VACUUM;
$argv{debug}          = $DEBUG;
$argv{override}       = $OVERRIDE;
$argv{feature_type}   = 'pangenome';

my $chado = Sequences::ExperimentalFeatures->new(%argv);


# BEGIN
my $now = my $start = time();

# Lock table so no one else can upload
$chado->remove_lock() if $REMOVE_LOCK;
$chado->place_lock();
my $lock = 1;

# Prepare tmp files for storing upload data
$chado->file_handles();
elapsed_time("Initialization complete");

# Run pan-seq
unless($panseq_dir) {
	print "Running panseq...\n";
	
	my $root_dir = $chado->tmp_dir . 'panseq_pangenome/';
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
	
	my $cmd = "perl $FindBin::Bin/../Database/contig_fasta.pl --config $config_file --output $fasta_file";
	system($cmd) == 0 or croak "[Error] download of contig sequences failed (syscmd: $cmd).\n";
	print "\tcomplete\n";
	
	# Run panseq
	print "\tpreparing panseq input...\n";
	$panseq_dir = $root_dir . 'panseq/';
	if(-e $panseq_dir) {
		remove_tree $panseq_dir or croak "[Error] unable to delete directory $panseq_dir ($!).\n";
	}
	
	my $pan_cfg_file = $root_dir . 'pg.conf';
	my $core_threshold = 1633;
	
	open(my $out, '>', $pan_cfg_file) or die "Cannot write to file $pan_cfg_file ($!).\n";
	print $out
qq|queryDirectory	$fasta_dir
baseDirectory	$panseq_dir
numberOfCores	8
mummerDirectory	$mummer_dir
blastDirectory	$blast_dir
minimumNovelRegionSize	1000
novelRegionFinderMode	no_duplicates
muscleExecutable	$muscle_exe
fragmentationSize	1000
percentIdentityCutoff	90
coreGenomeThreshold	$core_threshold
runMode	pan
nameOrId	name
storeAlleles	1
allelesToKeep	1
|;
	close $out;
	
	my @loading_args = ($panseq_exe,
	$pan_cfg_file);
	print "\tcomplete\n";
	
	print "\trunning panseq...\n";
	$cmd = join(' ', @loading_args);
	system($cmd) == 0 or croak "[Error] Panseq analysis failed.\n";
	print "\tcomplete\n";
	
	# Blast pangenome regions
	my $input_fasta = $panseq_dir . 'panGenomeFragments.fasta';
	my $input_fasta1 = $panseq_dir . 'coreGenomeFragments.fasta';
	my $input_fasta2 = $panseq_dir . 'accessoryGenomeFragments.fasta';
	`cat $input_fasta1 $input_fasta2 > $input_fasta`;
	my $blast_file = $panseq_dir . 'anno.txt';
	my $blast_cmd = "$blast_dir/blastx -evalue 0.0001 -outfmt ".'\"6 qseqid qlen sseqid slen stitle\" '."-db $nr_location -max_target_seqs 1 -query -";
	my $num_cores = 8;
	my $filesize = -s $input_fasta;
	my $blocksize = int($filesize/$num_cores);
	my $parallel_cmd = "cat $input_fasta | $parallel_exe --gnu -j $num_cores --block $blocksize --recstart '>' --pipe $blast_cmd > $blast_file";
	
	print "\trunning blast on pangenome fragments...\n";
	system($parallel_cmd) == 0 or croak "[Error] BLAST failed.\n";
	print "\tcomplete\n";
	
}

# Finalize and load into DB

# Load functions
my %anno_functions;
my $anno_file = $panseq_dir . 'anno.txt';
open IN, "<", $anno_file or croak "[Error] unable to read file $anno_file ($!).\n";

while(<IN>) {
	chomp;
	my ($q, $qlen, $s, $slen, $t) = split(/\t/, $_);
	# my ($panseq_name, $locus_id, $desc) = split(/\t/, $_);
	# $anno_functions{$locus_id} = [undef,$desc];
	$anno_functions{$q} = [$s,$t];
}
close IN;
elapsed_time('Annotation loading complete');
print $logger scalar(keys %anno_functions)." annotations loaded.\n" if $logger;

# Load pangenome
my %in_block;
my $core_fasta_file = $panseq_dir . 'coreGenomeFragments.fasta';
my $acc_fasta_file = $panseq_dir . 'accessoryGenomeFragments.fasta';
my @core_status = (1,0);
my $num_pg = 0;
my $i = -1;

foreach my $pan_file ($core_fasta_file, $acc_fasta_file) {

	my $in_core = shift @core_status;
	
	my $fasta = Bio::SeqIO->new(-file   => $pan_file,
							    -format => 'fasta') or die "Unable to open Bio::SeqIO stream to $pan_file ($!).";
    
	while (my $entry = $fasta->next_seq) {
		my $id = $entry->display_id;
		my $func = undef;
		my $func_id = undef;
		
		my ($locus_id, $uniquename) = ($id =~ m/^lcl\|(\d+)\|(lcl\|.+)$/);
		croak "Error: unable to parse header $id in pangenome fasta file $pan_file.\n" unless $uniquename && $locus_id;

		$i++;
		if($partial_load) {
			if($i >= $start_region && $i <= $end_region) {
				$in_block{$uniquename} = 1;
			} else {
				next;
			}
		}
		
		if($anno_functions{$id}) {
			($func_id, $func) = @{$anno_functions{$id}};
		}
		
		my $seq = $entry->seq;
		$seq =~ tr/-//; # Remove gaps, store only raw sequence
		
		my $pg_feature_id = $chado->handle_pangenome_segment($in_core, $func, $func_id, $seq);
		$num_pg++;
	}
	
	my $data_type = ($in_core) ? 'Core':'Accessory';
	elapsed_time("$data_type pangenome fragments processed");
}

print $logger  "$num_pg regions processed.\n" if $logger;

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
my $snpdir = $alndir . '/snp_alignments';
my $posdir = $alndir . '/snp_positions';
foreach my $d ($fastadir, $treedir, $perldir, $snpdir, $posdir, $refdir) {
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
	my $fasta_file = $panseq_dir . 'locus_alleles.fasta';
	open (my $in, "<", $fasta_file) or croak "Error: unable to read file $fasta_file ($!).\n";
	local $/ = "\nLocus ";
	
	while(my $locus_block = <$in>) {

		$locus_block =~ s/^Locus //;
		my ($locus) = ($locus_block =~ m/^(\S+)/);
		next unless $locus;
		#my ($locus_id, $uniquename) = ($locus =~ m/^lcl\|(\w+)\|(lcl\|.+)$/);
		my ($uniquename) = ($locus =~ m/^(lcl\|.+)$/);
		croak "Error: unable to parse header $locus in the locus alleles fasta file.\n" unless $uniquename;

		if($partial_load) {
			next unless $in_block{$uniquename};
		}
		
		# pangenome reference region feature ID
		my $query_id = $chado->cache('feature', $uniquename);
		croak "Pangenome reference segment $locus has no assigned feature ID ($uniquename)\n" unless $query_id;
		
		my $num_seqs = ($locus_block =~ tr/>/>/);
		my $do_tree = 0;
		my $do_snps = 0;
	
		$do_tree = 1 if $num_seqs > 2; # only build trees for groups of 3 or more
		$do_snps = 1 if $chado->cache('core',$query_id) && $num_seqs > 1; # need 2 or more sequences for snps
		
		push @tasks, [$query_id, $uniquename, $do_tree, $do_snps];
		
		open my $out1, '>', $fastadir . "/$query_id.ffn" or croak "Error: unable to open file $fastadir/$query_id.ffn ($!).";
	
		while($locus_block =~ m/\n>(\S+)\n(\S+)/g) {
			my $header = $1;
			my $seq = $2;
			$seq =~ tr/-//; # Remove gaps
			print $out1 ">$header\n$seq\n";
		}
		close $out1;
		
		if($do_snps) {
			my $refseq = $chado->cache('sequence',$query_id);
			croak "No sequence found for reference pangenome segment $query_id." unless $refseq;
			
			open my $out2, '>', $refdir . "/$query_id\_ref.ffn" or croak "Error: unable to open file $refdir/$query_id\_snps.ffn ($!).";
			my $refheader = "refseq_$query_id";
			print $out2 ">$refheader\n$refseq\n";
			close $out2;
		}
	}
	close $in;
}

# Print tasks to file
my $jobfile = $alndir . "/jobs.txt";
open my $out, '>', $jobfile or croak "Error: unable to open file $jobfile ($!).";
foreach my $t (@tasks) {
	# Only need alignment or tree if do_snps or do_tree is true
	print $out join("\t",$t->[0],$t->[2],$t->[3],0),"\n";
	
}
close $out;
elapsed_time('Fasta file printing complete');

# Run alignment script
my @loading_args = ('perl', $align_script, ,"--fast", "--dir $alndir");
my $cmd = join(' ',@loading_args);
my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
unless($success) {
	croak "Alignment script $cmd failed ($stderr).";
}
elapsed_time('Parallel alignment & tree building complete');


# Load loci positions
my %loci;
my $positions_file = $panseq_dir . 'pan_genome.txt';
open(my $in, "<", $positions_file) or croak "Error: unable to read file $positions_file ($!).\n";
<$in>; # header line
while (my $line = <$in>) {
	chomp $line;
	
	my ($id, $uniquename, $genome, $allele, $start, $end, $header) = split(/\t/,$line);
	
	if($allele > 0) {
		# Hit

		if($partial_load) {
			next unless $in_block{$uniquename};
		}
		
		# pangenome reference region feature ID
		my $query_id = $chado->cache('feature', $uniquename);
		croak "Pangenome reference segement $id has no assigned feature ID\n" unless $query_id;
	
		my ($contig) = $header =~ m/lcl\|\w+\|(\w+)/;
		$loci{$query_id}->{$header}->{$allele} = {
			start => $start,
			end => $end,
			contig => $contig
		};		
	}
}
elapsed_time("Loci location loaded");


# Iterate through each pangenome segment and load it
foreach my $tarray (@tasks) {
	my ($pg_id, $pg_name, $do_tree, $do_snps) = @$tarray;

	
	# Load sequences from file
	my $num_ok = 0;  # Some locus sequences fail checks, so the overall number of sequences can drop making trees/snps irrelevant
	my @sequence_group;
	my $fasta_file = $fastadir . "/$pg_id.ffn";
	my $fasta = Bio::SeqIO->new(-file   => $fasta_file,
								-format => 'fasta') or die "Unable to open Bio::SeqIO stream to $fasta_file ($!).";
	while(my $entry = $fasta->next_seq()) {
		my $header = $entry->display_id;
		my $seq = $entry->seq;
		$num_ok++ if pangenome_locus($pg_id,$pg_name,$header,$seq,\@sequence_group);
	}

	if($do_tree && $num_ok > 2) {
		my $tree_file = $perldir . "/$pg_id\_tree.perl";
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
		
		$chado->handle_phylogeny($tree, $pg_id, \@sequence_group);
	}
	
	if($do_snps && $num_ok > 1) {	
		# Compute snps relative to the reference alignment for all new loci
		# Performed by parallel script, load data for each genome
		foreach my $ghash (@sequence_group) {
			if($ghash->{is_new}) {
				find_snps($posdir, $pg_id, $ghash);
			}
		}
		
		# Load snp positions in each sequence
		# Must be run after all snps loaded into memory
		foreach my $ghash (@sequence_group) {
			if($ghash->{is_new}) {
				locate_snps($posdir, $pg_id, $ghash);
			}
		}
	}

	print $logger  "$pg_name (ID: $pg_id) fragment processed. Num valid loci: $num_ok. Tree: $do_tree. Snps: $do_snps\n" if $logger;
}
elapsed_time("All pangenome loci processed");

unless ($NOLOAD) {
	$chado->load_data();
}

$chado->remove_lock();
elapsed_time("Data loaded");

my $rt = time() - $start;
printf $logger "Full runtime: %.2f\n", $rt if $logger;

exit(0);


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

=head2 pangenome_locus


=cut

sub pangenome_locus {
	my ($query_id, $query_name, $header, $seq, $seq_group) = @_;
	
	# Parse input
	my $genome_ids = parse_loci_header($header);
	
	# privacy setting
	my $is_public = $genome_ids->{access} eq 'public' ? 1 : 0;
	my $pub_value = $is_public ? 'TRUE' : 'FALSE';
	
	# location hash
	my $loc_hash = $loci{$query_id}->{$genome_ids->{position_file_header}}->{$genome_ids->{copy}};
	unless(defined $loc_hash) {
		warn "Missing location information for locus allele $query_name ($query_id) in contig $header (lookup details: ".
			$genome_ids->{position_file_header}.",".
			$genome_ids->{copy}.").\n" unless defined $loc_hash;
		return;
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
	my $type = $chado->feature_types('locus');
	
	# uniquename - based on contig location and so should be unique (can't have duplicate pangenome loci at same spot) 
	my $uniquename = "locus:$contig_id.$min.$max.$is_public";
	
	# Check if this allele is already in DB
	my ($result, $allele_id) = $chado->validate_feature(query => $query_id, genome => $genome_ids->{genome}, uniquename => $uniquename,
			public => $pub_value, feature_type => 'pangenome');
	
	if($result eq 'new_conflict') {
		warn "Attempt to add new region multiple times. Dropping duplicate of pangenome region $uniquename.";
		return 0;
	}
	if($result eq 'db_conflict') {
		warn "Attempt to update existing region multiple times. Skipping duplicate pangenome region $uniquename.";
		return 0;
	}
	if($result eq 'db' || defined($allele_id)) {
		warn "Attempt to load pangenome region already in database. Skipping duplicate pangenome region $uniquename.";
		return 0;
	}
	
	# Create new loci feature
	
	# ID
	my $curr_feature_id = $chado->nextfeature($is_public);

	# retrieve genome data - most importantedly upload_id
	my $collection_info = $chado->collection($genome_ids->{genome}, $is_public);
	
	# organism - assume ecoli
	my $organism = $collection_info->{organism};
	
	# external accessions
	my $dbxref = '\N';
	
	#  name
	my $name = "loci derived from $query_id";
	
	# Add entry in core pangenome alignment table for genome, if it doesn't exist
	$chado->cache_genome_id($genome_ids->{genome}, $is_public, $collection_info->{name}, $collection_info->{organism}, 'public');
	
	# Feature relationships
	$chado->handle_parent(subject => $curr_feature_id, genome => $genome_ids->{genome}, contig => $contig_id, public => $is_public);
	$chado->handle_pangenome_loci($curr_feature_id, $query_id, $is_public, $genome_ids->{genome});
	
	# Additional Feature Types
	$chado->add_types($curr_feature_id, $is_public);
	
	# Sequence location
	$chado->handle_location($curr_feature_id, $contig_id, $min, $max, $strand, $is_public);
	
	# Print feature
	my $upload_id = $is_public ? undef : $collection_info->{upload};
	$chado->print_f($curr_feature_id, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $residues, $is_public, $upload_id);  
	$chado->nextfeature($is_public, '++');
		
	$allele_id = $curr_feature_id;

	# Record event in cache
	$chado->feature_cache('insert' => 1, feature_id => $allele_id, uniquename => $uniquename, genome_id => $genome_ids->{genome},
		query_id => $query_id, is_public => $pub_value);
	
	push @$seq_group, {
		genome => $genome_ids->{genome},
		header => $header,
		allele => $allele_id,
		contig => $contig_id,
		public => $is_public,
		is_new => 1,
	};

	return 1;
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
	
	# Load snp variations from file
	my $var_file = $data_dir . "/$ref_id/$genome\__snp_variations.txt";
	open(my $in, "<", $var_file) or croak "Error: unable to read file $var_file ($!).\n";
	
	while(my $snp_line = <$in>) {
		chomp $snp_line;
		my ($pos, $gap, $refc, $seqc) = split(/\t/, $snp_line);
		croak "Error: invalid snp variation format on line $snp_line." unless $seqc;
		
		$chado->handle_snp($ref_id, $refc, $pos, $gap, $contig_collection, $contig, $locus, $seqc, $is_public);
	}
	
	close $in;
}

sub locate_snps {
	my $data_dir = shift;
	my $ref_id = shift;
	my $genome_info = shift;

	my $genome = $genome_info->{header};
	my $contig_collection = $genome_info->{genome};
	my $contig = $genome_info->{contig};
	my $locus = $genome_info->{allele};
	my $is_public = $genome_info->{public};
	
	# Load snp alignment positions from file
	my $pos_file = $data_dir . "/$ref_id/$genome\__snp_positions.txt";
	open($in, "<", $pos_file) or croak "Error: unable to read file $pos_file ($!).\n";
	
	while(my $snp_line = <$in>) {
		chomp $snp_line;
		my ($start1, $start2, $end1, $end2, $gap1, $gap2) = split(/\t/, $snp_line);

		croak "Error: invalid snp position format on line $snp_line." unless defined $gap2;
		$chado->handle_snp_alignment_block($contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public);
	}
	
	close $in;
}

sub elapsed_time {
	my ($mes) = @_;
	
	my $time = $now;
	$now = time();

	if($logger) {
		printf $logger "$mes: %.2f\n", $now - $time;
	} else {
		printf("$mes: %.2f\n", $now - $time);
	}
}

sub parse_loci_header {
	my $header = shift;
	
	my ($access, $contig_collection_id, $access2, $contig_id, $allele_num) = ($header =~ m/^lcl\|(public|private)_(\d+)\|(public|private)_(\d+)(?:_\-a(\d+))?$/);
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


