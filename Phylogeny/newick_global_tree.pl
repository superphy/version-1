#!/usr/bin/env perl

=head1 NAME

$0 - Downloads the main phylogenetic genome tree and associated alignment

=head1 SYNOPSIS

  % $0 --config file [options]
=head1 OPTIONS

 --config      Config file with tmp directory and db connection parameters
 --tree        Output newick tree to this file
 --aln         Output global alignment to this file

=head1 DESCRIPTION

Downloads all genome phylogenetic tree , which are initially in a
perl-based format, converts it to newick format and finally prints the
tree string to file.

NOTE: this is the global tree and will include PRIVATE genomes

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2015

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Phylogeny::Tree;
use Data::Dumper;
use Carp;
use Getopt::Long;

# Needs to be called before GetOptions
# Parses command-line options to connect to DB
my $t = Phylogeny::Tree->new();

## Arguments
my ($tree_file, $aln_file);

GetOptions(
    'tree=s'  => \$tree_file,
    'aln=s'   => \$aln_file
);

# Retrieve tree
if($tree_file) {

	my $tree = $t->globalTree();
	my $taxa_only = 1;
	my $newick = $t->perlToNewick($tree, $taxa_only);

	open(my $out, ">$tree_file") or croak "Error: unable to write to file $tree_file ($!).\n";
	print $out $newick;
	close $out;
}

# Retrieve alignment
if($aln_file) {
	$t->snpAlignment(file => $aln_file);
}



