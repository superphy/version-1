#!/usr/bin/env perl

=head1 NAME

$0 - Align sequences and build trees in parallel

=head1 SYNOPSIS

   % parallel_tree_builder.pl [options]

=head1 COMMAND-LINE OPTIONS

   --dir     Define directory containing fasta files and job list
   --config  Superphy config file with EXE paths
   --fast    Build tree in fast mode (necessary for long alignments)

=head1 DESCRIPTION



=head1 AUTHOR

Matt Whiteside

=cut

use Inline (Config =>
			DIRECTORY => $ENV{"SUPERPHY_INLINEDIR"} || $ENV{"HOME"}.'/Inline' );
use Inline 'C';

use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;
use FindBin;
use lib "$FindBin::Bin/../";
use Carp qw/croak carp/;
use Phylogeny::TreeBuilder;
use Phylogeny::Tree;
use Parallel::ForkManager;
use IO::CaptureOutput qw(capture_exec);
use File::Copy qw/copy/;
use Time::HiRes qw( time );
use Config::Tiny;
use Data::Dumper;
use JSON::MaybeXS;
use DBI;

########
# INIT
########

my $v = 0;

# Inialize the parallel manager
# Max processes for parallel run
my $pm = new Parallel::ForkManager(7);

# Get config
my ($alndir, $fast_mode, $config) = (0,'',0);
GetOptions(
	'config=s' => \$config,
	'dir=s' => \$alndir,
	'fast=s' => \$fast_mode,
	'v' => \$v
) or ( system( 'pod2text', $0 ), exit -1 );
croak "[Error] missing argument. You must supply a valid data directory\n" . system('pod2text', $0) unless $alndir;
croak "[Error] missing argument. You must supply a valid config file\n" . system('pod2text', $0) unless $config;

my $conf = Config::Tiny->read($config);
croak "[Error] Unable to read config file ($Config::Tiny::errstr)" unless($conf);

my $muscle_exe = $conf->{ext}->{muscle};
my $fasttree_exe = $conf->{ext}->{fasttree};

# Retrieve DB connection parameters
my $dbparams = dbConfig($conf);

# Intialize the Tree building module
my $tree_builder = Phylogeny::TreeBuilder->new(fasttree_exe => $fasttree_exe);
my $tree_io = Phylogeny::Tree->new(dbix_schema => 'empty');

my $fastadir = $alndir . '/fasta';
my $treedir = $alndir . '/tree';
my $perldir = $alndir . '/perl_tree';
my $refdir = $alndir . '/refseq';
my $outdir = $alndir . '/alignments';
my $newdir = $alndir . '/new';

# Load jobs
my $job_file = $alndir . '/jobs.txt';
my @jobs;
open my $in, '<', $job_file or croak "Error: unable to read job file $job_file ($!).\n";
while(my $job = <$in>) {
	chomp $job;
	
	my ($pg_id, $do_tree, $do_snp, $add_seq) = split(/\t/,$job);
	if($do_tree || $do_snp || $add_seq) {
		# Some work to do
		push @jobs, [$pg_id, $do_tree, $do_snp, $add_seq];
	} 
	else {
		# No work required, alignment from panseq is ok
		# Link MSA file to destination directory
		my $fasta_file = "$fastadir/$pg_id.ffn";
        my $out_file = "$outdir/$pg_id.ffn";
		symlink($fasta_file,$out_file) or croak "Symlink of $fasta_file to $out_file failed ($!).";
	}
}
close $in;

# Logger
my $log_file = "$alndir/parallel_log.txt";
open my $log, '>', $log_file or croak "Error: unable to create log file $log_file ($!).\n";
my $start = time();
print $log "parallel_tree_builder.pl - ".localtime()."\n";

# Initialize store
prepare_kv_store($dbparams);


########
# RUN
########

my $num = 0;
my $tot = scalar(@jobs);

foreach my $jarray (@jobs) {
	$num++;
	$pm->start and next; # do the fork

	my $st = time();
	my ($pg_id,$do_tree,$do_snp,$add_seq) = @$jarray;
	build_tree($pg_id,$do_tree,$do_snp,$add_seq);
	my $en = time();
	my $time = $en - $st;
	print $log "\t$pg_id completed (elapsed time $time)\n";

	$pm->finish; # do the exit in the child process
}

$pm->wait_all_children;
my $time = time() - $start;
print $log "complete (runtime: $time)\n";
close $log;
exit(0);

########
# SUBS
########

sub build_tree {
	my ($pg_id, $do_tree, $do_snp, $add_seqs) = @_;
	
	local *STDOUT = $log;
	local *STDERR = $log;
	my $time = time();

	my $fasta_file = "$fastadir/$pg_id.ffn";
	my $out_file = "$outdir/$pg_id\_out.ffn";
	my $in_file = $fasta_file;
	my $ref_file = "$refdir/$pg_id\_ref.ffn";

	# Prepare sequences for alignment by adding reference sequnce
	# for cases that compute SNPs
	if($do_snp) {
		$in_file = "$outdir/$pg_id\_in.ffn";
		copy($fasta_file,$in_file) or croak "Copy of $fasta_file to $in_file failed ($!).";
		system(qq( cat "$ref_file" >> "$in_file" )) == 0 or croak "Concatentation of $ref_file to $in_file failed ($!)."
	}

	# Perform alignment
	if($add_seqs) {
		# Iteratively add new sequences to existing alignment
		
		my $new_file = "$newdir/$pg_id.ffn";
		my $tmp_file = "$newdir/$pg_id\_tmp.ffn";
		copy($in_file,$out_file) or croak "Copy of $in_file to $out_file failed ($!).";
		
		my $fasta = Bio::SeqIO->new(-file   => $new_file,
									-format => 'fasta') or croak "Unable to open Bio::SeqIO stream to $new_file ($!).";
									
		while (my $entry = $fasta->next_seq) {
			
			open(my $tmpfh, '>', $tmp_file) or croak "Unable to write to tmp file $tmp_file ($!).";
			print $tmpfh '>'.$entry->display_id."\n".$entry->seq."\n";
			close $tmpfh;
			
			my @loading_args = ($muscle_exe, "-quiet -profile -in1 $tmp_file -in2 $out_file -out $out_file");
			my $cmd = join(' ',@loading_args);
			
			my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
		
			unless($success) {
				croak "Muscle profile alignment failed for pangenome $pg_id ($stderr).";
			}
		}
		
	} else {
		# Generate new alignment
		
		my @loading_args = ($muscle_exe, '-quiet -diags -maxiters 2', "-in $in_file -out $out_file");
		my $cmd = join(' ',@loading_args);
		
		my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
		unless($success) {
			croak "Muscle alignment failed for pangenome $pg_id ($stderr).";
		}
		
	}
	$time = elapsed_time("\talignment ", $time);

	# Compute snps
	# Make sure to strip out the refseq before proceeding with the tree build
	if($do_snp) {

		my $ref_aln_file = "$refdir/$pg_id\_aln.ffn";
		my $post_out_file = "$outdir/$pg_id\_tree.ffn";

		# Open tree alignment file
		open(my $fh, '>', $post_out_file) or croak "Unable to write to file $post_out_file ($!).";

		# Create DBI handle in child process
		my $dbh = dbconnect($dbparams); 
		
		# Find snp positions
		my $refheader = "refseq_$pg_id";
		my $refseq;
		my @comp_seqs;
		my @comp_names;

		my $fasta = Bio::SeqIO->new(-file   => $out_file,
									-format => 'fasta') or croak "Unable to open Bio::SeqIO stream to $out_file ($!).";
		while (my $entry = $fasta->next_seq) {
			my $id = $entry->display_id;
			
			if($id =~ m/^refseq/) {
				# Save reference sequence alignment string
				$refseq = $entry->seq;
				open(my $afh, '>', $ref_aln_file) or croak "Error: unable to write to file $ref_aln_file ($!).\n";
				print $afh ">$id\n$refseq\n";
				close $afh;
			}
			else {
				print $fh ">$id\n".$entry->seq."\n";
		
				if($add_seqs && $id =~ m/upl/) {
					# This alignment is a mix of new and old sequences
					# Only compute snps for newly added sequences
					push @comp_seqs, $entry->seq;
					push @comp_names, $id;
				} 
				else {
					# Alignment is entirely new
					# Compute snps for all sequences
					push @comp_seqs, $entry->seq;
					push @comp_names, $id;
				}
			}
			
		}

		close $fh;
		$out_file = $post_out_file; 
		# Use this modified alignment file with the refseq striped out
		# for the tree building step coming next
		croak "Missing reference sequence in SNP alignment fileor set $pg_id\n" unless $refseq;
		
		# Create output hashes
		my %variations = ();
		my %positions = ();

		#snp_positions(\@comp_seqs, \@comp_names, \%variations, \%positions, $refseq);
		perl_snp_positions(\@comp_seqs, \@comp_names, \%variations, \%positions, $refseq);

		my $put_sth = dbput($dbh, $pg_id, 'variation', \%variations);
		dbput($dbh, $pg_id, 'position', \%positions, $put_sth);

		# Commit inserts
		dbfinish($dbh);

	}
	elapsed_time("\tsnp ", $time);


	# Compute tree
	if($do_tree) {
		my $tree_file = "$treedir/$pg_id\_tree.phy";
		my $perl_file = "$perldir/$pg_id\_tree.perl";
		
		# build newick tree
		$tree_builder->build_tree($out_file, $tree_file, $fast_mode) or croak;
		
		# slurp tree and convert to perl format
		my $tree = $tree_io->newickToPerlString($tree_file);
		open my $out, ">", $perl_file or croak "Error: unable to write to file $perl_file ($!).\n";
		print $out $tree;
		close $out;
	}
	$time = elapsed_time("\ttree ", $time);
	
}

sub elapsed_time {
	my ($mes, $prev) = @_;
	
	my $now = time();
	printf("$mes: %.2f\n", $now - $prev) if $v;
	
	return $now;
}

sub perl_snp_positions {
	my $seqs = shift;
	my $names = shift;
	my $variations = shift;
	my $positions = shift;
	my $refseq = shift;

	my @refseq_array = split(//,$refseq);

	for(my $i=0; $i < @$seqs; $i++) {
		my $seq = $seqs->[$i];
		my @seq_array = split(//, $seq);
		my $genomename = $names->[$i];

		perl_write_positions(\@refseq_array, \@seq_array, $variations, $positions, $genomename)
	}

}

sub perl_write_positions {
	my $refseq = shift;
	my $seq = shift;
	my $variations = shift;
	my $positions = shift;
	my $genomename = shift;

	my @varlist; 
	my @poslist;

	$variations->{$genomename} = \@varlist;
	$positions->{$genomename} = \@poslist;

	my $i = 0;
	my $g = 0;
	my $p = 0; # current position
	my $s = 0; # start of alignment block
	my $g2 = 0;
	my $p2 = 0;
	my $s2 = 0; 
	my $gapoffset_state = 0; 
	# 0 = gap offset equal in reference and comparison sequence at current position
	# 1 = gap offset not equal
	
	# Alignment blocks are interupted by gaps.
	# See transition state diagram for full explanation of emission of alignment blocks.
	# Alignment blocks are printed as
	# ref_start, comp_start, ref_end, comp_end, ref_gap_offset, comp_gap_offset
		
	# Starting state
	if($refseq->[$i] eq '-') {
		# Gap in reference sequence
		
		if($seq->[$i] eq '-') {
			# Gap in comparison sequence
			$gapoffset_state = 0;
			$g2++;

		}
		else {
			# Nt in comparison sequence
			$gapoffset_state = 1;
			$p2++;
		}

		$g++;
	}
	else {
		# Nt in reference sequence

		if($seq->[$i] eq '-') {
			# Gap in comparison sequence
			$gapoffset_state = 1;
			$g2++;
		}
		else {
			# Nt in comparison sequence
			$gapoffset_state = 0;
			$p2++;
		}

		$p++;
	}

	                                         
	for($i=1; $i < @$refseq; $i++) {

		if($gapoffset_state eq 0) {
			# Present state: equal gap offset values in reference and comparison sequence

			# New column
			if($refseq->[$i] eq '-') {
				# Gap in reference sequence
				
				if($seq->[$i] eq '-') {
					# Gap in comparison sequence
					$gapoffset_state = 0;
					$g2++;

				}
				else {
					# Nt in comparison sequence
					# Marks start of new block
					# Print old block, update starting positions
					push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
					$s = $p;
					$s2 = $p2;

					$gapoffset_state = 1;
					$p2++;
					$g2 = 0;
				}

				$g++;
			}
			else {
				# Nt in reference sequence

				if($seq->[$i] eq '-') {
					# Gap in comparison sequence
					# Marks start of new block
					# Print old block, update starting positions
					push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
					$s = $p;
					$s2 = $p2;

					$gapoffset_state = 1;
					$g2++;
				}
				else {
					# Nt in comparison sequence
					$gapoffset_state = 0;
					$p2++;
					$g2 = 0;

				}

				$p++;
				$g = 0;
			}
		}
		else {
			# Present state: unequal gap offset values in reference and comparison sequence

			# New column
			if($refseq->[$i] eq '-') {
				# Gap in reference sequence
				
				if($seq->[$i] eq '-') {
					# Gap in comparison sequence
					# States stays unequal
					# Marks start of new block
					# Print old block, update starting positions
					push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
					$s = $p;
					$s2 = $p2;

					$gapoffset_state = 1;
					$g2++;

				}
				else {
					# Nt in comparison sequence
					# Marks start of new block
					# Print old block, update starting positions
					push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
					$s = $p;
					$s2 = $p2;

					$gapoffset_state = 1;
					$p2++;
					$g2 = 0;
				}

				$g++;
			}
			else {
				# Nt in reference sequence

				if($seq->[$i] eq '-') {
					# Gap in comparison sequence
					# Marks start of new block
					# Print old block, update starting positions
					push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
					$s = $p;
					$s2 = $p2;

					$gapoffset_state = 1;
					$g2++;
				}
				else {
					# Nt in comparison sequence
					# Marks start of new block
					# Print old block, update starting positions
					push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
					$s = $p;
					$s2 = $p2;

					$gapoffset_state = 0;
					$p2++;
					$g2 = 0;

				}

				$p++;
				$g = 0;
			}
		}
		
		# Print SNP                                        
		if($refseq->[$i] ne $seq->[$i]) {
			push(@varlist, [$p, $g, $refseq->[$i], $seq->[$i]]);
		}
		                                                                     
	}

	# Print last block
	push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);

}

=head2 prepare_kv_store

Set up key/value store in postgres DB for this run

=cut
sub prepare_kv_store {
	my $dbparams = shift;

	my $dbh = dbconnect($dbparams);

	$dbh->do(q/CREATE TABLE IF NOT EXISTS tmp_parallel_kv_store (
		store_id varchar(40),
                json_value text,
		CONSTRAINT store_id_c1 UNIQUE(store_id)
	)/) or croak $dbh->errstr;

	$dbh->do(q/
			DELETE FROM tmp_parallel_kv_store
		/) or croak $dbh->errstr;

}

sub dbconnect {
	my $dbparams = shift;

	my $dbh = DBI->connect($dbparams->{dbsource}, $dbparams->{dbuser}, $dbparams->{dbpass})
		or croak $DBI::errstr;

	return ($dbh);
}

sub dbput {
	my $dbh = shift;
	my $pg_id = shift;
	my $data_type = shift;
	my $data_hashref = shift;
	my $put_sth = shift;

	croak "Error: invalid argument: pangenome ID $pg_id." unless $pg_id =~ m/^\d+$/;
	croak "Error: invalid argument: data type $data_type." unless $data_type =~ m/^(?:variation|position)$/;
	croak "Error: invalid argument: data hash ref." unless ref($data_hashref) eq 'HASH';

	# Serialize hashes using JSON
	my $data_json = encode_json($data_hashref);

	# Unique key
	my $key = "$pg_id\_$data_type";

	unless($put_sth) {
		$put_sth = $dbh->prepare("INSERT INTO tmp_parallel_kv_store(store_id, json_value) VALUES (?,?)")
			or croak $dbh->errstr;
	}
	
	$put_sth->execute($key, $data_json) or croak $dbh->errstr;

	return $put_sth;
}

sub dbfinish {
	my $dbh = shift;

	#$dbh->commit() or croak $dbh->errstr;
	$dbh->disconnect();
}

=head dbConfig

Retrieve DB connection parameters from Superphy config file

=cut

sub dbConfig {
	my ($conf) = @_;

	my ($dbsource, $dbuser, $dbpass);
	
	if($conf->{db}->{dsn}) {
		$dbsource = $conf->{db}->{dsn};
	} 
	else {
		foreach my $p (qw/name dbi host/) {
			croak "Error: Missing DB connection parameter in config file: '$p'." 
				unless defined($conf->{db}->{$p});
		}
		$dbsource = 'dbi:' . $conf->{db}->{dbi} . 
			':dbname=' . $conf->{db}->{name} . 
			';host=' . $conf->{db}->{host};
		$dbsource . ';port=' .$conf->{db}->{port} if $conf->{db}->{port} ;
	}

	foreach my $p (qw/pass user/) {
		croak "Error: Missing DB connection parameter in config file: '$p'." 
			unless defined($conf->{db}->{$p});
	}

	$dbuser = $conf->{db}->{user};
	$dbpass = $conf->{db}->{pass};

	return { dbsource => $dbsource, dbuser => $dbuser, dbpass => $dbpass};
}



__END__
__C__

void write_positions(char* refseq, char* seq, SV* variations_ref, SV* positions_ref, char* genomename);
void save_position_row(AV* poslist, int s, int s2, int p, int p2, int g, int g2);
void save_variation_row(AV* varlist, int p, int g, char r, char s);


void snp_positions(SV* seqs_arrayref, SV* names_arrayref, SV* variations_hashref, SV* positions_hashref, char* refseq) {

	/* if ( !SvROK( variations_hashref ) ) croak( "variations_hashref is not a reference" );
    if ( SvTYPE( SvRV( variations_hashref ) ) != SVt_PVHV ) croak( "variations_hashref is not an hash reference" );

    if ( !SvROK( positions_hashref ) ) croak( "positions_hashref is not a reference" );
    if ( SvTYPE( SvRV( positions_hashref ) ) != SVt_PVHV ) croak( "positions_hashref is not an hash reference" );

    if ( !SvROK( seqs_arrayref ) ) croak( "seqs_arrayref is not a reference" );
    if ( SvTYPE( SvRV( seqs_arrayref ) ) != SVt_PVAV ) croak( "seqs_arrayref is not an array reference" );

    if ( !SvROK( names_arrayref ) ) croak( "names_arrayref is not a reference" );
    if ( SvTYPE( SvRV( names_arrayref ) ) != SVt_PVAV ) croak( "names_arrayref is not an array reference" ); */

	AV* names;
	AV* seqs;

	names = (AV*)SvRV(names_arrayref);
	seqs = (AV*)SvRV(seqs_arrayref);
	int n = av_len(seqs);
	int i;
	
	// compare each seq to ref
	// write snps to file for genome
	for(i=0; i <= n; ++i) {
		SV* name = av_shift(names);
		SV* seq = av_shift(seqs);
		char* genomename;
		genomename = SvPV_nolen(name);
		
		write_positions(refseq, (char*)SvPV_nolen(seq), variations_hashref, positions_hashref, genomename);
	}
	
}

void write_positions(char* refseq, char* seq, SV* variations_ref, SV* positions_ref, char* genomename) {

	HV* variations = (HV*)SvRV(variations_ref);
	HV* positions = (HV*)SvRV(positions_ref);
	
	AV* varlist = newAV(); 
	AV* poslist = newAV();

	hv_store(variations, genomename, strlen(genomename), newRV_noinc((SV*)varlist), 0);
	hv_store(positions, genomename, strlen(genomename), newRV_noinc((SV*)poslist), 0);

	int i = 0;
	int g = 0; // gap
	int p = 0; // current position
	int s = 0; // start of alignment block
	int g2 = 0;
	int p2 = 0;
	int s2 = 0; 
	int gapoffset_state = 0; 
	// 0 = gap offset equal in reference and comparison sequence at current position
	// 1 = gap offset not equal
	
	// Alignment blocks are interupted by gaps.
	// See transition state diagram for full explanation of emission of alignment blocks.
	// Alignment blocks are printed as
	// ref_start, comp_start, ref_end, comp_end, ref_gap_offset, comp_gap_offset
		
	// Starting state
	if(refseq[i] == '-') {
		// Gap in reference sequence
		
		if(seq[i] == '-') {
			// Gap in comparison sequence
			gapoffset_state = 0;
			g2++;

		}
		else {
			// Nt in comparison sequence
			gapoffset_state = 1;
			p2++;
		}

		g++;
	}
	else {
		// Nt in reference sequence

		if(seq[i] == '-') {
			// Gap in comparison sequence
			gapoffset_state = 1;
			g2++;
		}
		else {
			// Nt in comparison sequence
			gapoffset_state = 0;
			p2++;
		}

		p++;
	}

	                                         
	for(i=1; refseq[i] && seq[i]; ++i) {

		if(gapoffset_state == 0) {
			// Present state: equal gap offset values in reference and comparison sequence

			// New column
			if(refseq[i] == '-') {
				// Gap in reference sequence
				
				if(seq[i] == '-') {
					// Gap in comparison sequence
					gapoffset_state = 0;
					g2++;

				}
				else {
					// Nt in comparison sequence
					// Marks start of new block
					// Print old block, update starting positions
					save_position_row(poslist, s, s2, p, p2, g, g2);
					s = p;
					s2 = p2;

					gapoffset_state = 1;
					p2++;
					g2 = 0;
				}

				g++;
			}
			else {
				// Nt in reference sequence

				if(seq[i] == '-') {
					// Gap in comparison sequence
					// Marks start of new block
					// Print old block, update starting positions
					save_position_row(poslist, s, s2, p, p2, g, g2);
					s = p;
					s2 = p2;

					gapoffset_state = 1;
					g2++;
				}
				else {
					// Nt in comparison sequence
					gapoffset_state = 0;
					p2++;
					g2 = 0;

				}

				p++;
				g = 0;
			}
		}
		else {
			// Present state: unequal gap offset values in reference and comparison sequence

			// New column
			if(refseq[i] == '-') {
				// Gap in reference sequence
				
				if(seq[i] == '-') {
					// Gap in comparison sequence
					// States stays unequal
					// Marks start of new block
					// Print old block, update starting positions
					save_position_row(poslist, s, s2, p, p2, g, g2);
					s = p;
					s2 = p2;

					gapoffset_state = 1;
					g2++;

				}
				else {
					// Nt in comparison sequence
					// Marks start of new block
					// Print old block, update starting positions
					save_position_row(poslist, s, s2, p, p2, g, g2);
					s = p;
					s2 = p2;

					gapoffset_state = 1;
					p2++;
					g2 = 0;
				}

				g++;
			}
			else {
				// Nt in reference sequence

				if(seq[i] == '-') {
					// Gap in comparison sequence
					// Marks start of new block
					// Print old block, update starting positions
					save_position_row(poslist, s, s2, p, p2, g, g2);
					s = p;
					s2 = p2;

					gapoffset_state = 1;
					g2++;
				}
				else {
					// Nt in comparison sequence
					// Marks start of new block
					// Print old block, update starting positions
					save_position_row(poslist, s, s2, p, p2, g, g2);
					s = p;
					s2 = p2;

					gapoffset_state = 0;
					p2++;
					g2 = 0;

				}

				p++;
				g = 0;
			}
		}
		
		// Print SNP                                        
		if(refseq[i] != seq[i]) {
			save_variation_row(varlist, p, g, refseq[i], seq[i]);
		}
		                                                                     
	}

	// Print last block
	save_position_row(poslist, s, s2, p, p2, g, g2);                                                             

}


void save_position_row(AV* poslist, int s, int s2, int p, int p2, int g, int g2) {
	
	AV* prow = newAV();
	av_push(poslist, newRV_noinc((SV*)prow));
	av_push(prow, newSViv(s));
	av_push(prow, newSViv(s2));
	av_push(prow, newSViv(p));
	av_push(prow, newSViv(p2));
	av_push(prow, newSViv(g));
	av_push(prow, newSViv(g2));

}

void save_variation_row(AV* varlist, int p, int g, char r, char s) {
	
	AV* vrow = newAV();
	av_push(varlist, newRV_noinc((SV*)vrow));
	av_push(vrow, newSViv(p));
	av_push(vrow, newSViv(g));
	av_push(vrow, newSVpvf("%c", r));
	av_push(vrow, newSVpvf("%c", s));
	
}

