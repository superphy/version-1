#!/usr/bin/env perl

=head1 NAME

$0 - Functions for retrieving SNP and SNP positions

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2015

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package Data::Snppy;

use strict;
use warnings;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../";
use Modules::GenomeWarden;
use Role::Tiny::With;
with 'Roles::DatabaseConnector';
with 'Roles::CVMemory';
use Log::Log4perl qw(:easy);

# Initialize a basic logger
Log::Log4perl->easy_init($DEBUG);

=head2 new

  Create DB connection by:
    1) schema        Passing in handle to existing DBIx::Schema object
    2) dbh           Passing in handle to existing DBI object
    3) command-line  Parsing command-line @ARGV for DB connection parameters

=cut

sub new {
	my $class = shift;
	my %arg   = @_;

	my $self  = bless {}, ref($class) || $class;

	my $logger = Log::Log4perl->get_logger;
	$logger->debug('Initializing Snppy object');
	
	if($arg{schema}) {
		# Use existing DBIx::Class::Schema connection
		$self->setDbix($arg{schema});

	}
	elsif($arg{dbh}) {
		# Use existing DBI database handle
		$self->connectDatabase( dbh => $arg{dbh} );

	}
	elsif($arg{config}) {
		# Parse connection parameters from config file
		$self->connectDatabaseConf( $arg{config} );
	}
	else {
		# Establish new DB connection using command-line args
		$self->connectDatabaseCL();
	}	
	
	return $self;
}

# Return a GenomeWarden object for a user
sub warden {
	my $self = shift;
	my $user = shift;
	my $genomes = shift;
	
	my $warden;
	if($genomes) {
		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, genomes => $genomes, user => $user, cvmemory => $self->cvmemory);
		my ($err, $bad1, $bad2) = $warden->error; 
		if($err) {
			# User requested invalid strains or strains that they do not have permission to view
			die 'Error: request for uploaded genomes that user does not have permission to view ' .join('', @$bad1, @$bad2);
		}
		
	} else {
		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, user => $user, cvmemory => $self->cvmemory);
	}
	
	return $warden;
}





=head2 get

Return alleles and snp positions for a single SNP postiion 

=cut2

sub get {
	my $self = shift;
	my $snp_id = shift; # snp_core_id to retrieve
	my $username = shift; # username or undef

	my $snp_row = $self->dbixSchema->resultset('SnpCore')->find($snp_id);
	die "Error: Cannot find reference snp $snp_id." unless $snp_row;

	my $snp_gap = $snp_row->gap_offset;
	my $background_allele = $snp_row->allele;
	my $snp_pos = $snp_row->position;
	my $pgregion = $snp_row->pangenome_region->feature_id;
	my $is_gap = $snp_gap ? 1 : 0;

	print join(',',$snp_gap, $background_allele, $snp_pos, $pgregion, $is_gap),"\n";

	# Get public & private genomes with region
	my $warden = $self->warden($username);

	my $public_rs = $self->dbixSchema->resultset('Feature')->search(
		{
			'me.type_id' => $self->cvmemory('locus'),
			'feature_relationship_subjects.type_id' => $self->cvmemory('derives_from'),
			'feature_relationship_subjects.object_id' => $pgregion,
			'feature_relationship_subjects_2.type_id' => $self->cvmemory('part_of'),
		},
		{
			join => ['feature_relationship_subjects', 'feature_relationship_subjects', 'featureloc_features'],
			columns => [qw/feature_id name uniquename seqlen/],
			'+select' => [qw/feature_relationship_subjects_2.object_id/],
			'+as' => [qw/genome_id/]
		}
	);

	my ($public,$private) = $warden->featureList();
	my $private_rs = $self->dbixSchema->resultset('PrivateFeature')->search(
		{
			'me.type_id' => $self->cvmemory('locus'),
			'pripub_feature_relationships.type_id' => $self->cvmemory('derives_from'),
			'pripub_feature_relationships.object_id' => $pgregion,
			'pripub_feature_relationships_2.type_id' => $self->cvmemory('part_of'),
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
		
		my $position;
		
		if($is_gap) {
			$position = $self->lookupGap($feature->feature_id, $snp_id, $snp_pos, $pgregion, 1);
			
		} else {
			$position = $self->lookup($feature->feature_id, $snp_id, $snp_pos, 1);
		}

		my $result_hash = $self->contig($feature, $position, $snp_id, $background_allele, 1);
		my $key = 'public_'.$result_hash->{genome_id}."|".$feature->feature_id;
		$results{$key} = $result_hash;
	}

	# Private
	while(my $feature = $private_rs->next) {
		my $position;
		
		if($is_gap) {
			$position = $self->lookupGap($feature, $snp_id, $snp_pos, $pgregion, 0);
		} else {
			$position = $self->lookup($feature, $snp_id, $snp_pos, 0);
		}
		
		my $result_hash = $self->contig($feature, $position, $snp_id, $background_allele, 0);
		my $key = 'private_'.$result_hash->{genome_id}."|".$feature->feature_id;
		$results{$key} = $result_hash;
		
	}

	return \%results;

}

sub lookup {
	my $self = shift;
	my $locus_feature_id = shift;
	my $snp_id = shift;
	my $snp_pos = shift;
	my $is_public = shift;
	
	my $table = 'SnpPosition';
	$table = 'PrivateSnpPositon' unless $is_public;
	my $start = "< $snp_pos";
	my $end = ">= $snp_pos";
	
	# Find alignment block snp falls into
	my $block_rs = $self->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			region_start => \$start,
			region_end => \$end,
		}
	);
	
	my $num = 0;
	my $locus_pos;
	while(my $block = $block_rs->next) {
		
		# Relative locus position
		my $locus_start = $block->locus_start;
		$locus_pos = $locus_start + $snp_pos - $block->region_start - 1;
		
		$num++;
		die("SNP $snp_id aligns with multiple alignment block in locus $locus_feature_id.\n") if $num > 2;
	}
	
	die("No alignment block for locus $locus_feature_id found for SNP $snp_id.\n") unless $num;

	return $locus_pos;
}

sub lookupGap {
	my $self = shift;
	my $locus_feature_id = shift;
	my $snp_id = shift;
	my $snp_pos = shift;
	my $pgregion = shift;
	my $is_public = shift;
	
	my $locus_pos;
	
	my $table = 'GapPosition';
	$table = 'PrivateGapPositon' unless $is_public;
	
	# Find alignment block snp falls into
	my $block_rs = $self->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			snp_id => $snp_id
		}
	);
	
	my $num = 0;
	while(my $block = $block_rs->next) {
		
		# Relative locus position
		$locus_pos = $block->locus_pos;
		
		$num++;
		die("SNP $snp_id aligns with multiple gap columns in locus ".$locus_feature_id.".\n") if $num > 2;
	}
	
	if($num == 0) {
		# No entry in gap_position table
		# Note: This is due to newly inserted gap columns. Can only determine point
		# of insertion in sequence, not true gap_offset / number of indels in region.
		
		# Find indel site of entire gap region in comparison sequence
		# Does not return valid gap_offset, only valid sequence position
		$locus_pos = $self->lookupAnchorPosition($locus_feature_id, $snp_id, $snp_pos, $pgregion, $is_public);
		$num++;
	}
	
	die("No alignment block for locus $locus_feature_id found for SNP $snp_id.\n") unless $num;
	
	return $locus_pos;
}

sub lookupAnchorPosition {
	my $self = shift;
	my ($locus_feature_id, $snp_id, $snp_pos, $pgregion, $is_public) = @_;

	my $num = 0;
	my $locus_pos;
	
	my $table = 'SnpPosition';
	$table = 'PrivateSnpPositon' unless $is_public;
	my $end = ">= $snp_pos";
	my $start = "< $snp_pos";
	
	# Search for overlapping block in snp_position table
	# This may be anchor, or there maybe an anchor in gap_position table that is downstream of the block
	my $block_rs = $self->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			region_end => \$end,
			region_start => \$start
		},
		{
			columns => [qw/region_start region_end locus_start locus_end locus_gap_offset/],
			rows => 1
		}
	);

	# Search gap_position tables to find nearest upstream indel site
	$table = 'GapPosition';
	$table = 'PrivateGapPositon' unless $is_public;
	my $indel_rs = $self->dbixSchema->resultset($table)->search(
		{
			locus_id => $locus_feature_id,
			'snp.position' => \$end,
			'snp.pangenome_region' => $pgregion,
		},
		{
			join => [qw/snp/],
			columns => [qw/locus_start locus_end locus_gap_offset/],
			order_by => {'-desc' => 'snp.position'},
			rows => 1
		}
	);
	
	# Compare block and gap positions to determine which applies
	my $block_row = $block_rs->first;

	if($block_row) {
		# Block overlaps the gap, use it to determine position

		# Relative position
		my $locus_start = $block_row->locus_start;
		my $locus_pos = $locus_start + $snp_pos - $block_row->region_start - 1;

		return $locus_pos;

	}
	else {
		# No overlapping block, look for upstream gap

		my $gap_row = $indel_rs->first;

		if($gap_row) {
			# Gap is upstream, gap end marks position of indel
			return $gap_row->locus_end;
		}
		else {
			# No anchors found
			# Indel occured at start of sequence
			return 0;
		}
	}
	
}

sub contig {
	my $self = shift;
	my $locus = shift;
	my $position = shift;
	my $snp_id = shift;
	my $background_allele = shift;
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
		$contig_pos = $start + $position;
	} else {
		# Reverse direction
		$contig_pos = $end - $position - 1;
	}
	
	# Retrieve contig
	my $table = 'Feature';
	unless ($is_public) {
		$table = 'PrivateFeature';
	}
	
	my @cols = qw/feature_id name residues/;
	
	my $contig_rs = $self->dbixSchema->resultset($table)->search(
		{
			'type_id' => $self->cvmemory('contig'),
			'feature_id' => $contig_id
		},
		{
			columns => \@cols
		}
	);

	my $contig = $contig_rs->first;
	
	my $contig_name = $contig->name;
	
	# Retrieve genome
	my $genome_id = $locus->get_column('genome_id');

	my $genome_rs = $self->dbixSchema->resultset($table)->search(
		{
			'type_id' => $self->cvmemory('contig_collection'),
			'feature_id' => $genome_id
		},
		{
			columns => [qw/uniquename/]
		}
	);
	my $genome = $genome_rs->first;

	my $genome_name = $genome->uniquename;
	
	# Retrieve snp allele
	my $table2 = 'SnpVariation';
	$table2 = 'PrivateSnpVariation' unless $is_public;
	
	my $snp_rs = $self->dbixSchema->resultset($table2)->search(
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
	my $min = $contig_pos - 100;
	$min = ($min < 0) ? 0 : $min;
	my $upstr = substr($seq, $min, 100);
	my $dnstr = substr($seq, $contig_pos, 100);

	my $is_indel = ($allele eq '-') ? 1 : 0;
	
	my $result = {
		genome => $genome_name,
		genome_id => $genome_id,
		contig => $contig_name,
		contig_id => $contig_id,
		allele => $allele,
		position => $contig_pos,
		indel => $is_indel,
		strand => $strand,
		upstream => $upstr,
		downstream => $dnstr,
		is_public => $is_public,
		locus_id => $locus->feature_id
	};

	if($snp) {
		$result->{snp_variation_id} = $snp->snp_variation_id;
	}
	
	return $result;
}

sub dnacomp {
	my $nt = shift;

	my ($num) = ($nt =~ tr/ACGTacgtYyRrKkMmDdHhVvBb\-/TGCAtgcaRrYyMmKkHhDdBbVv\-/);
  	return ($nt, $num);
}


1;