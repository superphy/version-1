#!/usr/bin/env perl

=head1 NAME

$0 - Loads phylogenetic genome tree data into tree table

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --tree      Newick-format tree file [OPTIONAL]

=head1 DESCRIPTION

To improve the speed of page loading, tree data
is computed once and then saved in a table called tree. Tree data
needs to be updated anytime data changes (relatively infrequent).

Can load precomputed tree (--tree option) or will perform FastTree
build of current snp_alignment in database.

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Phylogeny::Tree;
use Phylogeny::TreeBuilder;
use Carp;
use Getopt::Long;
use Config::Tiny;


my ($tree_file,$config);

GetOptions(
    'tree=s' => \$tree_file,
    'config=s' => \$config,
);

croak "Missing argument. You must supply the config filename.\n" unless $config;
my $tmp_dir;
my $fasttree_exe;
if(my $conf = Config::Tiny->read($config)) {
	$tmp_dir      = $conf->{tmp}->{dir};
	$fasttree_exe = $conf->{ext}->{fasttreemp};
} else {
	croak $Config::Tiny::errstr;
}
croak "Invalid configuration file." unless $tmp_dir;

my $t = Phylogeny::Tree->new(config => $config);

unless($tree_file) {
	# Compute genome tree
	my $tree_builder = Phylogeny::TreeBuilder->new(fasttree_exe => $fasttree_exe);
	
	# write alignment file
	my $tmp_file = $tmp_dir . 'genodo_genome_aln.txt';
	$t->snpAlignment(file => $tmp_file);
	
	# clear output file for safety
	$tree_file = $tmp_dir . 'genodo_genome_tree.txt';
	open(my $out, ">", $tree_file) or croak "Error: unable to write to file $tree_file ($!).\n";
	close $out;
	
	# build newick tree
	my $fast = 'fast';
	$tree_builder->build_tree($tmp_file, $tree_file, $fast) or croak "Error: genome tree build failed.\n";
}

# Load tree into database
$t->loadTree($tree_file);

exit(0);

