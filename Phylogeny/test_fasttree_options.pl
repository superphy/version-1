#!/usr/bin/env perl

=head1 NAME

$0 - Test different fasttree options and compares resulting trees

=head1 SYNOPSIS

  % $0 --config file [options]

=head1 OPTIONS


=head1 DESCRIPTION


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
use Phylogeny::Tree;
use Phylogeny::TreeBuilder;
use Data::Dumper;
use Carp;
use Getopt::Long;
use Time::HiRes qw/gettimeofday tv_interval/;

## Arguments
my ($pipeline_mode, $test, $input_file, $global_output_file, $public_output_file,
	$dbhost, $dbname, $dbport, $dbuser, $dbpass, $tmp_dir, $supertree);
GetOptions(
    'dbname=s'   => \$dbname,
    'dbhost=s'   => \$dbhost,
    'dbport=i'   => \$dbport,
    'dbuser=s'   => \$dbuser,
    'dbpass=s'   => \$dbpass,
    'tmpdir=s'   => \$tmp_dir
);

# Temp directory
croak "Missing argument. You must supply temp directory --tmpdir.\n" unless $tmp_dir && -d $tmp_dir;

# DB connection params
croak "Missing argument(s). You must supply database connection parameters:  --dbname, --dbhost, --dbport, --dbuser & --dbpass.\n"
	unless $dbhost && $dbname && $dbport && $dbuser && $dbpass;


my $v = 1;

my $t = Phylogeny::Tree->new(
    dbname  => $dbname,
    dbhost  => $dbhost,
    dbport  => $dbport,
    dbuser  => $dbuser,
    dbpass  => $dbpass
);
my $tree_builder = Phylogeny::TreeBuilder->new();

# Look at a subtrees around a couple of leaves
my @target_set = qw(public_127639 public_80001 public_77824);


my $t0 = [gettimeofday];
my $root_slow = buildMLtree(0);
my $t1 = [gettimeofday];
my $root_fast = buildMLtree(1);
my $t2 = [gettimeofday];

print "Elapsed time for slow tree: ".tv_interval($t0, $t1)."\n";
print "Elapsed time for fast tree: ".tv_interval($t1, $t2)."\n";
	

my $rs = $t->compareTrees($root_slow, $t->globalTree);

my ($result) = ($rs ? 'DIFFER' : 'are equal');

print "\nThe slow tree and fast tree $result!\n";

foreach my $tn (@target_set) {
	print "\nSLOW Tree Summary for $tn:\n";
	leaf_snapshot($root_slow, $tn);

	print "\nFAST Tree Summary for $tn:\n";
	leaf_snapshot($root_fast, $tn);
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


# Build entire ML tree
sub buildMLtree {
	my $fast = shift;

	# write alignment file
	my $tmp_file = $tmp_dir . 'genodo_genome_aln.txt';
	$t->snpAlignment(file => $tmp_file);
	
	# clear output file for safety
	my $tree_file = $tmp_dir . 'genodo_genome_tree.txt';
	open(my $out, ">", $tree_file) or croak "Error: unable to write to file $tree_file ($!).\n";
	close $out;
	
	# build newick tree
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



