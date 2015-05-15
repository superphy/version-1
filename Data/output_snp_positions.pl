#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Data::Bridge;
use JSON;

=head1 NAME

$0 - Computes nucleotide position of SNP in each genome

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config      INI style config file containing DB connection parameters
 --job         Job ID in job_result table

=head1 DESCRIPTION

Computes SNP positions for all accessible genomes for a given user


=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

$|=1;
my $script = $0;

my $step = 0;
my @status = qw/Running Complete/;
my $error_status = 'Error occurred';

$SIG{__DIE__} = $SIG{INT} = 'fatal';

# Connect to DB
my $data = Data::Bridge->new();

my ($JOBID, $DOCHECKS);
$DOCHECKS = 0;
$JOBID = -1;
GetOptions(
    'job=s' => \$JOBID,
    'check' => \$DOCHECKS
);

# Retrieve job data
unless($JOBID || $JOBID == -1) {
	fatal("Missing argument: job")
}
my $job = $data->dbixSchema->resultset('JobResult')->find($JOBID);
unless($job) {
	fatal("No record matching ID $JOBID in job_result table.")
}

my $username = undef;
$username = $job->username;

my $job_param_json = $job->user_config;
my $job_params = decode_json($job_param_json);
my $snp_id = $job_params->{snp_core_id};
unless($snp_id) {
	fatal("User config is missing 'snp_core_id' parameter.")
}

$job->job_result_status($status[$step++]);
$job->update();

# Get core snp data
my $snp_row = $data->dbixSchema->resultset('SnpCore')->find($snp_id);
fatal("Cannot find reference snp $snp_id.") unless $snp_row;

my $snp_gap = $snp_row->gap_offset;
my $background_allele = $snp_row->allele;
my $snp_pos = $snp_row->position;
my $pgregion = $snp_row->pangenome_region->feature_id;
my $is_gap = 0 unless $snp_gap;

# Get public & private genomes with region
my $warden = $data->warden($username);

my $public_rs = $data->dbixSchema->resultset('Feature')->search(
	{
		'me.type_id' => $data->cvmemory('locus'),
		'feature_relationship_subjects.type_id' => $data->cvmemory('derives_from'),
		'feature_relationship_subjects.object_id' => $pgregion,
		'feature_relationship_subjects_2.type_id' => $data->cvmemory('part_of'),
	},
	{
		join => ['feature_relationship_subjects', 'feature_relationship_subjects', 'featureloc_features'],
		columns => [qw/feature_id name uniquename seqlen/],
		'+select' => [qw/feature_relationship_subjects_2.object_id/],
		'+as' => [qw/genome_id/]
	}
);

my ($public,$private) = $warden->featureList();
my $private_rs = $data->dbixSchema->resultset('PrivateFeature')->search(
	{
		'me.type_id' => $data->cvmemory('locus'),
		'pripub_feature_relationships.type_id' => $data->cvmemory('derives_from'),
		'pripub_feature_relationships.object_id' => $pgregion,
		'pripub_feature_relationships_2.type_id' => $data->cvmemory('part_of'),
		'pripub_feature_relationships_2.object_id' => {'-in' => $private }
	},
	{
		join => [qw/pripub_feature_relationships pripub_feature_relationships private_featureloc_features/],
		columns => [qw/feature_id name uniquename seqlen/],
		'+select' => [qw/pripub_feature_relationships_2.object_id/],
		'+as' => [qw/genome_id/]
	}
);

my %results;
my $num_wrong = 0;

# Public
while(my $feature = $public_rs->next) {
	
	my $position_array;
	
	if($is_gap) {
		$position_array = lookupGap($feature->feature_id, 1);
	} else {
		$position_array = lookup($feature->feature_id, 1);
	}
	
	locusCheck($feature->feature_id, $position_array, $snp_id, $background_allele, 1) if $DOCHECKS;
	
	my $result_hash = contig($feature, $position_array, 1);
	my $key = 'public_'.$result_hash->{genome}."|".$feature->feature_id;
	$results{$key} = $result_hash;
}

# Private
while(my $feature = $private_rs->next) {
	my $position_array;
	
	if($is_gap) {
		$position_array = lookupGap($feature, 0);
	} else {
		$position_array = lookup($feature, 0);
	}
	
	locusCheck($feature->feature_id, $position_array, $snp_id, $background_allele, 0) if $DOCHECKS;
	
	my $result_hash = contig($feature, $position_array, 0);
	my $key = 'private_'.$result_hash->{genome}."|".$feature->feature_id;
	$results{$key} = $result_hash;
	
}

if($DOCHECKS) {
	print "\n---------------------\nTOTAL ERRORS: $num_wrong.\n";
}

$job->job_result_status($status[$step++]);
my $result_json = encode_json \%results;
$job->result($result_json);

$job->update();

exit(0);

###########
## SUBS
###########

sub lookup {
	my $locus_feature_id = shift;
	my $is_public = shift;
	
	my $table = 'SnpPosition';
	$table = 'PrivateSnpPositon' unless $is_public;
	my $start = "< $snp_pos";
	my $end = ">= $snp_pos";
	
	# Find alignment block snp falls into
	my $block_rs = $data->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			region_start => \$start,
			region_end => \$end,
		}
	);
	
	my $num = 0;
	my $locus_pos;
	my $locus_gap;
	while(my $block = $block_rs->next) {
		
		# Relative locus position
		my $locus_start = $block->locus_start;
		$locus_gap = $block->locus_gap_offset;
		$locus_pos = $locus_start + $snp_pos - $block->region_start - 1;
		
		$num++;
		fatal("SNP $snp_id aligns with multiple alignment block in locus $locus_feature_id.\n") if $num > 2;
	}
	
	fatal("No alignment block for locus $locus_feature_id found for SNP $snp_id.\n") unless $num;
	
	# Gap offset values are always changing as new sequences are added, so $locus_gap may not be correct.
	# Can only determine location of gap in sequence, but not the number of consecutive indels in the gap region.
	my $is_indel = $locus_gap ? 1 : 0;
	return [$locus_pos, $is_indel];
}

sub lookupGap {
	my $locus_feature_id = shift;
	my $is_public = shift;
	
	my $locus_pos;
	my $gap_offset = 0;
	
	my $table = 'GapPosition';
	$table = 'PrivateGapPositon' unless $is_public;
	
	# Find alignment block snp falls into
	my $block_rs = $data->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			snp_id => $snp_id
		}
	);
	
	my $num = 0;
	while(my $block = $block_rs->next) {
		
		# Relative locus position
		$locus_pos = $block->locus_pos;
		$gap_offset = $block->locus_gap_offset;
		
		$num++;
		fatal("SNP $snp_id aligns with multiple gap columns in locus ".$locus_feature_id.".\n") if $num > 2;
	}
	
	if($num == 0) {
		# No entry in gap_position table
		# Note: This is due to newly inserted gap columns. Can only determine point
		# of insertion in sequence, not true gap_offset / number of indels in region.
		
		# Find indel site of entire gap region in comparison sequence
		# Does not return valid gap_offset, only valid sequence position
		my $this_pos = lookupAnchorPosition($locus_feature_id, $is_public);
		$locus_pos = $this_pos->[0];
		$gap_offset = $this_pos->[1];
		$num++;
	}
	
	fatal("No alignment block for locus $locus_feature_id found for SNP $snp_id.\n") unless $num;
	
	# Gap offset values are always changing as new sequences are added, so $gap_offset may not be correct.
	# Can only determine location of gap in sequence, but not the number of consecutive indels in the gap region.
	my $is_indel = $gap_offset ? 1 : 0;
	return [$locus_pos, $is_indel];
}

sub lookupAnchorPosition {
	my ($locus_feature_id, $is_public) = @_;

	my $num = 0;
	my $locus_pos;
	my $locus_gap;
	
	my $table = 'SnpPosition';
	$table = 'PrivateSnpPositon' unless $is_public;
	my $end = "< $snp_pos";
	
	# Search for nearest upstream block in snp_position table
	# This may be anchor, or there maybe an anchor in gap_position table that is downstream of the block
	my $block_rs = $data->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			region_end => \$end,
		},
		{
			order_by => {'-desc' => 'region_start'},
			prefetch => [qw/region_start region_end locus_start locus_end locus_gap_offset/],
			rows => 1
		}
	);

	# Search gap_ and snp_position tables to find nearest upstream indel site
	$table = 'GapPosition';
	$table = 'PrivateGapPositon' unless $is_public;
	my $indel_rs = $data->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			'snp.position' => \$end,
			'snp.pangenome_region' => $pgregion,
		},
		{
			join => [qw/snp/],
			prefetch => [qw/locus_start locus_end locus_gap_offset/],
			order_by => {'-desc' => 'snp.position'},
			rows => 1
		}
	);
	
	# Compare block and gap positions to determine which is downstream
	my $block_row = $block_rs->first;
	my $gap_row = $block_rs->first;

	if($block_row) {
		if($gap_row) {
			if($gap_row->locus_end > $block_row->locus_end) {
				# Gap is upstream, gap end marks position of indel
				return [$gap_row->locus_end, 1];
			}
			else {
				# Block is upstream, block end marks position of indel
				return [$block_row->locus_end, 1];
			}
		}
		else {
			# No preceding gap with anchor,
			# Block end marks position of indel.
			return [$block_row->locus_end, 1]
		}
	}
	elsif($gap_row) {

		# No preceding block
		# Gap end marks position of indel.
		return [$gap_row->locus_end, 1]

	}
	else {
		# No upstream anchors, indel occured at start of sequence
		return [0, 1];
	}
	
}

sub contig {
	my $locus = shift;
	my $position_array = shift;
	my $is_public = shift;
	
	# Compute contig position
	my $rel = 'featureloc_features';
	$rel = 'private_featureloc_features' unless $is_public;
	my $location = $locus->$rel->first;
	my $contig_id = $location->srcfeature_id;
	my $start = $location->fmin;
	my $end = $location->fmax;
	my $strand = $location->strand;
	
	my $contig_pos;
	if($strand == 1) {
		# Forward direction
		$contig_pos = $start + $position_array->[0];
	} else {
		# Reverse direction
		$contig_pos = $end - $position_array->[0] - 1;
	}
	
	# Retrieve contig
	my $table = 'Feature';
	unless ($is_public) {
		$table = 'PrivateFeature';
	}
	
	my @cols = qw/feature_id name residues/;
	
	my $contig = $data->dbixSchema->resultset($table)->find(
		{
			'type_id' => $data->cvmemory('contig'),
			'feature_id' => $contig_id
		},
		{
			columns => \@cols
		}
	);
	
	my $contig_name = $contig->name;
	
	# Retrieve genome
	my $genome_id = $locus->get_column('genome_id');

	my $genome = $data->dbixSchema->resultset($table)->find(
		{
			'type_id' => $data->cvmemory('contig_collection'),
			'feature_id' => $genome_id
		},
		{
			columns => [qw/uniquename/]
		}
	);
	
	my $genome_name = $genome->uniquename;
	
	# Retrieve snp allele
	my $table2 = 'SnpVariation';
	$table2 = 'PrivateSnpVariation' unless $is_public;
	
	my $snp_rs = $data->dbixSchema->resultset($table2)->search(
		{
			snp_id => $snp_id,
			contig_collection_id => $genome_id
		},
		{
			columns => [qw/allele/]
		}
	);
	
	my $snp = $snp_rs->first;
	my $allele;
	if($snp) {
		$allele = $snp->allele;
	} else {
		$allele = $background_allele;
	}
	
	# Surrounding contig sequence
	my $seq = $contig->residues;
	my $upstr = substr($seq, $contig_pos - 100, 100);
	my $dnstr = substr($seq, $contig_pos, 100);
	
	my $result = {
		genome => $genome_name,
		contig => $contig_name,
		allele => $allele,
		position => $contig_pos,
		indel => $position_array->[1],
		strand => $strand,
		upstream => $upstr,
		downstream => $dnstr,
	};
	
	if($DOCHECKS) {
		
	
		my $start = $contig_pos - 2 - 1; # Zero doens't count as a position
		my $window = substr($seq, $start, 5);
		my @chars = split(//, $window);
		my $locus_id = $locus->feature_id;
		my $true_nt = $chars[2];
	
		my $pre = 'public_';
		$pre = 'private_' unless $is_public;
		
		my $wrong = 0;
		if($strand == -1) {
			# Reverse strand convert
			my ($comp_nt, $ok) = dnacomp($true_nt);
			if($ok) {
				$wrong++ unless $comp_nt eq $allele;
			}
		} else {
			$wrong++ unless $true_nt eq $allele;
		}
		
		if($position_array->[1]) {
			# Gap
			print "Locus $locus_id in contig $pre$genome_id|$contig_id -> expected: $allele / observed: ".join('',@chars[0..2])." > - < ".join('',@chars[3..4])." (strand: $strand).";
		} else {
			# Nt
			print "Locus $locus_id in contig $pre$genome_id|$contig_id -> expected: $allele / observed: ".join('',@chars[0..1])." > $chars[2] < ".join('',@chars[3..4])." (strand: $strand).";
		}
		
		if($wrong) {
			$num_wrong++;
			print " --INCORRECT!\n";
		} else {
			print "\n";
		}
		
	}
	
	return $result;
}


sub fatal {
	my $msg = shift;
	
	$job->update(job_result_status => $error_status) if($job);
	
	my $err = "Error in $script (job ID $JOBID)";
	$err .= ": $msg" if $msg;
	print STDERR "$err\n";
	
	exit(1);
}

sub locusCheck {
	my $locus_id = shift;
	my $position_array = shift;
	my $snp_id = shift;
	my $is_public = shift;
	
	# Get sequence
	my $table = 'Feature';
	$table = 'PrivateFeature' unless $is_public;
	
	my $locus_rs = $data->dbixSchema->resultset($table)->search(
		{
			'type_id' => $data->cvmemory('locus'),
			'feature_id' => $locus_id
		},
		{
			columns => [qw/feature_id uniquename residues seqlen/]
		}
	);
	
	my $locus = $locus_rs->first;
	fatal("No locus feature $locus_id") unless $locus;
	
	my $seq = $locus->residues;
	
	my $start = $position_array->[0] - 2;
	my $window = substr($seq, $start, 5);
	my @chars = split(//, $window);
	
	# Get allele
	$table = 'SnpVariation';
	$table = 'PrivateSnpVariation' unless $is_public;
	
	my $snp_rs = $data->dbixSchema->resultset($table)->search(
		{
			'snp_id' => $snp_id,
			'locus_id' => $locus_id,
		},
		{
			columns => [qw/allele/]
		}
	);
	
	my $snp = $snp_rs->first;
	my $allele;
	if($snp) {
		$allele = $snp->allele;
	} else {
		$allele = $background_allele;
	}
	
	if($position_array->[1]) {
		# Gap
		print "Locus $locus_id -> $allele : ".join('',@chars[0..2])." > - < ".join('',@chars[3..4])."\n";
	} else {
		# Nt
		print "Locus $locus_id -> $allele : ".join('',@chars[0..1])." > $chars[2] < ".join('',@chars[3..4])."\n";
	}

	return;
}

sub dnacomp {
	my $nt = shift;

	my ($num) = ($nt =~ tr/ACGTacgt-/TGCAtgca-/);
  	return [$nt, $num];
}


