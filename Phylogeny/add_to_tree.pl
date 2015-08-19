#!/usr/bin/env perl

=head1 NAME

$0 - Inserts new genomes into existing genome tree

=head1 SYNOPSIS

  % $0 --config file [options]

=head1 OPTIONS

 --config      Config file with tmp directory and db connection parameters

=head1 DESCRIPTION

TODO

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2014

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Data::Bridge;
use Phylogeny::Tree;
use Phylogeny::TreeBuilder;
use Data::Dumper;
use Carp;
use Getopt::Long;

# Needs to be called before GetOptions
# Parses command-line options to connect to DB
my $t = Phylogeny::Tree->new();

## Arguments
my ($pipeline_mode, $test, $input_file, $global_output_file, $public_output_file,
	$tmp_dir, $supertree, $fasttree_exe);

GetOptions(
    'pipeline'   => \$pipeline_mode,
    'test'       => \$test,
    'tmpdir=s'   => \$tmp_dir,
    'input=s'    => \$input_file,
    'globalf=s'  => \$global_output_file,
    'publicf=s'  => \$public_output_file,
    'supertree'  => \$supertree,
    'fasttree=s' => \$fasttree_exe
);

# Temp directory
croak "Missing argument. You must supply temp directory --tmpdir.\n" unless $tmp_dir && -d $tmp_dir;

# Inputs
croak "Missing argument. You must supply input file --input .\n" unless $input_file && -r $input_file;

# Output filenames
croak "Missing argument(s). You must supply output filenames --globalf & --publicf .\n" unless $test || $global_output_file && $public_output_file;

# Executables
croak "Missing argument. You must supply fasttree executable path --fasttree .\n" unless $fasttree_exe;


my $v = 1;

my $tree_builder = Phylogeny::TreeBuilder->new(fasttree_exe => $fasttree_exe);

# Process inputs
my @target_set;
my %target_info;

open(my $in, "<$input_file") or croak "Unable to read file $input_file ($!).\n";
while(my $row = <$in>) {
	chomp $row;
	my ($genome, $uniquename, $displayname, $access, $feature_id) = split(/\t/, $row);
	push @target_set, $genome;
	$target_info{$genome} = {
		uniquename => $uniquename, displayname => $displayname, access => $access,
		feature_id => $feature_id
	};
}
close $in;



if($supertree) {
	# Rebuild only part of tree using supertree approach

	# Obtain working tree (should not include genomes)
	my $root = $t->globalTree;
	my @orig_leaves = $t->find_leaves($root);
	my $num_orig_leaves = scalar(@orig_leaves);

	if($test) {
		# Remove target nodes from tree to run test
		$root = $t->pruneNode($root, \%target_info);
	}


	# Build fast approx tree
	my ($nj_root, $nj_leaves) = buildNJtree();

	# Sometimes a supertree approach is not possible
	# In which case, the entire ML genome tree needs to 
	# be built.
	my $short_circuit = 0;

	# Keep track of which new genomes are inserted into main tree
	my %waiting_targets;
	map { $waiting_targets{$_} = 1 } @target_set;

	# Use supertree approach to add new genomes to existing ML tree
	foreach my $targetG (@target_set) {

		# Find corresponding leaf node
		my $leaf;
		foreach my $l (@$nj_leaves) {
			if($l->{name} eq $targetG) {
				$leaf = $l;
				last;
			}
		}
		croak "Error: new genome $targetG not found in core_alignment table.\n" unless $leaf;

		my $terminate = 0;
		my $level = 3;
		do {

			# Get candidate subtree set
			my ($rs, $genome_set) = find_umbrella($leaf, $level, \%waiting_targets);

			if($rs) {
				# Target genome not embedded in suitable subtree,
				# need to rebuild entire ML genome tree
				$short_circuit = 1;
				$terminate = 1;

			} else {
				# Attempt build of subtree using ML approach

				my ($new_subtree_root, $old_subtree_root) = buildSubtree($root, $targetG, $genome_set);

				# Check if target is outgroup
				my @subtree_leaves = $t->find_leaves($new_subtree_root);

				if(_isOutgroup($targetG, \@subtree_leaves)) {
					# Target is outgroup in subtree,
					# move to larger subtree
					$level++;
					$terminate = 0;

				} else {
					# Build successful
					# Reattach subtree to main tree
					foreach my $k (keys %{$new_subtree_root}) {
						$old_subtree_root->{$k} = $new_subtree_root->{$k};
					}

					# $root now contains $targetG, move on to next genome
					$terminate = 1;
				}

			}

		} while(!$terminate);
		
		last if $short_circuit;

		# Genome inserted into ML tree using supertree approach
		$waiting_targets{$targetG} = 0;

	} # End of iteration of target_genomes


	if($short_circuit) {
		# The supertree approach failed for one or more new genomes
		# Rebuild entire ML tree
		$root = buildMLtree();
	}

	# Verify correct number of leaves
	my @final_leaves = $t->find_leaves($root);
	
	if($test) {
		if($num_orig_leaves != scalar(@final_leaves)) {
			my %check;
			map { $check{$_->{node}->{name}} = 1 } @orig_leaves;

			foreach my $n (@final_leaves) {
				$check{$n->{node}->{name}}++;
			}

			foreach my $n (keys %check) {
				warn "Genome $n missing in new tree\n" unless $check{$n} > 1;
			}

			croak "Error: Final number of genomes in phylogenetic tree does not match input genomes (new: ".scalar(@final_leaves).", old: $num_orig_leaves).\n"
		}

		my $rs = $t->compareTrees($root, $t->globalTree);

		my ($result) = ($rs ? 'DIFFER' : 'are equal');

		print "\nThe test tree and original tree $result!\n";

		foreach my $tn (@target_set) {
			print "\nTEST Tree Summary for $tn:\n";
			leaf_snapshot($root, $tn);

			print "\nORIGINAL Tree Summary for $tn:\n";
			leaf_snapshot($t->globalTree, $tn);
		}

	} else {

		croak "Error: Final number of genomes in phylogenetic tree does not match input genomes.\n" unless scalar(@final_leaves) == ($num_orig_leaves + @target_set);

		my $public_root = finalize_tree($root);

		# Print global tree
		open(my $out, ">$global_output_file") or croak "Error: Unable to write to file $global_output_file ($!).\n";
		$Data::Dumper::Indent = 0;
		my $tree_string = Data::Dumper->Dump([$root], ['tree']);
		print $out $tree_string;
		close $out;

		# Print public tree
		open($out, ">$public_output_file") or croak "Error: Unable to write to file $public_output_file ($!).\n";
		$Data::Dumper::Indent = 0;
		$tree_string = Data::Dumper->Dump([$public_root], ['tree']);
		print $out $tree_string;
		close $out;
	}

} else {
	# Asked for full tree build, not supertree approach

	croak "Error: --test option only developed for --supertree approach" if $test;

	my $root = buildMEtree();

	# Print global tree
	open(my $out, ">$global_output_file") or croak "Error: Unable to write to file $global_output_file ($!).\n";
	$Data::Dumper::Indent = 0;
	my $tree_string = Data::Dumper->Dump([$root], ['tree']);
	print $out $tree_string;
	close $out;

	# Get list of visible genomes to public currently in DB
	my $visible_genomes = $t->visibleGenomes();

	# Add new public genomes uploaded in this run
	foreach my $g (keys %target_info) {
		if($target_info{$g}->{access} eq 'public') {
			$visible_genomes->{$g} = $target_info{$g};
		}
	}

	# Prune private genomes from tree
	my $public_tree = $t->prepTree($root, $visible_genomes, 0);

	# Print public tree
	open($out, ">$public_output_file") or croak "Error: Unable to write to file $public_output_file ($!).\n";
	$Data::Dumper::Indent = 0;
	$tree_string = Data::Dumper->Dump([$public_tree], ['tree']);
	print $out $tree_string;
	close $out;

}


## Subs

# Build NJ tree to use to pick candidate subtrees in supertree approach
sub buildNJtree {

	# Build quick NJ tree to identify closely related genomes
	my $pg_file = $tmp_dir . "superphy_pg_aligment.txt";

	if(-e $pg_file) {
		 unlink $pg_file or carp "Warning: could not delete temp file $pg_file ($!).\n";
	}

	if($test) {
		$t->pgAlignment(file => $pg_file);
	} else {
		if($pipeline_mode) {
			$t->pgAlignment(file => $pg_file, temp_table => 'PipelinePangenomeAlignment');
		} else {
			$t->pgAlignment(file => $pg_file)
		}
		
	}

	my $nj_file = $tmp_dir . 'superphy_core_tree.txt';
	open(OUT, ">$nj_file") or croak "Error: unable to write to file '$nj_file' ($!).\n";
	close OUT;
		
	$tree_builder->build_njtree($pg_file, $nj_file) or croak "Error: nj genome tree build failed.\n";

	# Load tree
	my $nj_tree = $t->newickToPerl($nj_file);

	# Add parent links, collect leaves
	my @leaves = ();
	_add_parent_links($nj_tree, \@leaves);

	return($nj_tree, \@leaves);
}

sub _add_parent_links {
	my $this_root = shift;
	my $leaves = shift;

	if($this_root->{children}) {
		foreach my $c (@{$this_root->{children}}) {
			$c->{parent} = $this_root;
			_add_parent_links($c, $leaves);
		}
	} else {
		push @$leaves, $this_root;
	}
}

=head2 find_umbrella

Given a single node, find the lowest (or most recent) umbrella ancestor internal node.
Umbrella nodes try to obtain a local subtree that encompasses the node of interest &
captures a reasonable degree of variation around the node of interest.

An umbrella node is defined as:
1. An internal node
2. Not direct parent of node of interest
3. Contains at least one leaf node that is farther than the node of interest
4. Contains at least 5 leaf nodes

Args:
1. A hash reference representing internal node in PERL-based tree
2. Array of strings that match the 'name' value in leaf nodes
3. Number of levels up on path to root from node of interest

Returns:
1. An arrayref of genomes that are leaves in umbrella-node subtree
2. Level of umbrella node

=cut

sub find_umbrella {
	my $leaf = shift;
	my $level = shift;
	my $waiting_targets = shift;

	my $rs;
	my $min_set_size = 20;

	# Move up $level levels from leaf
	my $node = $leaf;
	my $reached_root = 0;
	for(my $i = 0; $i < $level; $i++) {
		if($node->{parent}) {
			$node = $node->{parent}
		} else {
			# Reached root
			$reached_root = 1;
			last;
		}
	}

	if($reached_root) {
		# Need rebuild entire tree
		$rs = 1;
		return($rs, []);
	}

	# Check for valid umbrella node
	# Move up tree to root until one is found, or root is reached
	my $found = 0;
	my @leaves;

	do {
		@leaves = $t->find_leaves($node);

		# Remove leaves that have not yet been added to ML tree
		# Including the target genome
		my @tmp;
		my $theLeaf; # The target genome leaf node, now with length filled in
		foreach my $l (@leaves) {
			push @tmp, $l unless $waiting_targets->{$l->{node}->{name}};
			$theLeaf = $l if $l->{node}->{name} eq $leaf->{name};
		}
		@leaves = @tmp;
		unshift @leaves, $theLeaf; # Stick target genome at front of leaves array

		if(@leaves < $min_set_size) {
			# Only small subtree at this point
			# Move up one level if possible

			if($node->{parent}) {
				$found = 0;
				$node = $node->{parent};
			} else {
				# Reached root
				$rs = 1;
				return($rs, []);
			}

		} else {
			# Found substantial subtree

			if(_isOutgroup($leaf->{name}, \@leaves)) {
				# If target genome is outgroup
				# Move up one level if possible

				if($node->{parent}) {
					$found = 0;
					$node = $node->{parent};
				} else {
					# Reached root
					$rs = 1;
					return($rs, []);
				}

			} else {
				# Found umbrella node
				$found = 1;
			}

		}

	} while(!$found);
	
	
	my @genome_set = map { $_->{node}->{name} } @leaves;
	$rs = 0;
	return ($rs, \@genome_set);
}

sub _isOutgroup {
	my $leafName = shift;
	my $leaves = shift;

	# Check outgroup in subtree
	my $outg = { node => undef, len => -1};
	my $target_len;
	foreach my $l (@$leaves) {
		$outg = $l if $l->{len} > $outg->{len};
		if($l->{node}->{name} eq $leafName) {
			$target_len = $l->{len};
		}
	}

	croak "Error: subtree does not contain target genome $leafName. Cannot run _isOutgroup()." unless defined $target_len;
	return($target_len == $outg->{len});
}


# Build subtree
sub buildSubtree {
	my $root = shift;
	my $target_genome = shift;
	my $genome_set = shift;

	# Find LCA of leaf nodes
	my $subtree_root = $t->find_lca($root, @$genome_set);

	# Build tree for genomes in LCA subtree
	my @leaves = $t->find_leaves($subtree_root);
	my @subtree_genomes = map { $_->{node}->{name} } @leaves;
	push @subtree_genomes, $target_genome;
	
	my $align_file = $tmp_dir . "superphy_snp_aligment.txt";
	if(-e $align_file) {
		 unlink $align_file or carp "Warning: could not delete temp file $align_file ($!).\n";
	}

	if($pipeline_mode) {
		$t->snpAlignment(genomes => \@subtree_genomes, file => $align_file, temp_table => 'PipelineSnpAlignment');
	} else {
		$t->snpAlignment(genomes => \@subtree_genomes, file => $align_file);
	}
	
	my $tree_file = $tmp_dir . 'superphy_snp_tree.txt';
	open(my $out, ">".$tree_file) or croak "Error: unable to write to file $tree_file ($!).\n";
	close $out;
		
	$tree_builder->build_tree($align_file, $tree_file) or croak "Error: genome tree build failed.\n";

	# Load tree
	my $new_subtree = $t->newickToPerl($tree_file);

	return ($new_subtree, $subtree_root);
}

# Build entire ML tree
sub buildMLtree {

	# write alignment file
	my $tmp_file = $tmp_dir . 'genodo_genome_aln.txt';
	if($pipeline_mode) {
		$t->snpAlignment(file => $tmp_file, temp_table => 'PipelineSnpAlignment');
	} else {
		$t->snpAlignment(file => $tmp_file);
	}
	
	# clear output file for safety
	my $tree_file = $tmp_dir . 'genodo_genome_tree.txt';
	open(my $out, ">", $tree_file) or croak "Error: unable to write to file $tree_file ($!).\n";
	close $out;
	
	# build newick tree
	my $fast = 1; # Use options optimized for speed 
	$tree_builder->build_tree($tmp_file, $tree_file, $fast) or croak "Error: genome tree build failed.\n";

	my $new_tree = $t->newickToPerl($tree_file);

	return $new_tree;
}

# Build entire ME tree
sub buildMEtree {

	# write alignment file
	my $tmp_file = $tmp_dir . 'genodo_genome_aln.txt';
	if($pipeline_mode) {
		$t->snpAlignment(file => $tmp_file, temp_table => 'PipelineSnpAlignment');
	} else {
		$t->snpAlignment(file => $tmp_file);
	}
	
	# clear output file for safety
	my $tree_file = $tmp_dir . 'genodo_genome_tree.txt';
	open(my $out, ">", $tree_file) or croak "Error: unable to write to file $tree_file ($!).\n";
	close $out;
	
	# build newick tree
	my $fast = 'me'; # Use ME tree with ML lengths
	$tree_builder->build_tree($tmp_file, $tree_file, $fast) or croak "Error: genome tree build failed.\n";

	my $new_tree = $t->newickToPerl($tree_file);

	return $new_tree;
}

sub printTree {
	my $node = shift;
	my $level = shift;

	my $n = defined $node->{name} ? $node->{name} : 'undefined';
	my $l = defined $node->{length} ? $node->{length} : 'undefined';

	print join('',("\t") x $level);
	if($node->{children}) {
		print "I-Node: <$n> ($l)\n";
		$level++;
		foreach my $c (@{$node->{children}}) {
			printTree($c, $level);
		}
	} else {
		print "L-Node: <$n> ($l)\n";
	}

}

=head2 finalize_tree

Prunes tree remove non-visible genomes.

Note: includes new genomes added to tree which
may not be in database

=cut

sub finalize_tree {
	my $ptree = shift;

	my $public_list = $t->visableGenomes;

	# Add new genomes public list
	foreach my $g (keys %target_info) {
		my $ghash = $target_info{$g};

		$public_list->{$g} = {
			feature_id  => $ghash->{feature_id},
			displayname => $ghash->{displayname},
			uniquename  => $ghash->{uniquename},
			access      => $ghash->{access}
		};
	}
	
	# Prune private genomes from tree
	my $public_tree = $t->prepTree($ptree, $public_list, 0);

	return($public_tree);
}

=head2 leaf_snapshot

Prints summary of local tree structure around leaf node

Used for testing

=cut

sub leaf_snapshot {
	my $root = shift;
	my $leafname = shift;

	my @leaves = ();
	_add_parent_links($root, \@leaves);

	my $leafn;
	foreach my $l (@leaves) {
		if($l->{name} eq $leafname) {
			$leafn = $l;
			last;
		}
	}

	croak "Error: leaf node $leafname not found in tree.\n" unless $leafn;

	# Determine the level of the leaf node
	my $is_root = 0;
	my $lev = 0;
	my $this_node = $leafn;

	while($this_node->{parent}) {
		$lev++;
		$this_node = $this_node->{parent}
	}
	print "Node Level: $lev\n";

	# Print the subtree of the great grand-parent node or highest ancestor if not available
	my $ggp = $leafn;
	$ggp = $leafn->{parent} if $leafn->{parent};
	$ggp = $ggp->{parent} if $ggp->{parent};
	$ggp = $ggp->{parent} if $ggp->{parent};

	printTree($ggp, 0);
	
}



