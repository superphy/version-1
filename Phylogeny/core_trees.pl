#!/usr/bin/env perl

=head1 NAME

$0 - Downloads all core pangenome phylogenetic trees to file

=head1 SYNOPSIS

  % $0 --config file --out file

=head1 OPTIONS

 --config      Config file with tmp directory and db connection parameters
 --out         Output file

=head1 DESCRIPTION

Downloads all core pangenome phylogenetic trees , which are initially in a
perl-based format, converts them to newick format and finally prints the
tree strings to file with a tab-delim two column format:

pangenome_region_feature_id\tnewick_tree_string

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
my ($output_file);

GetOptions(
    'out=s'  => \$output_file
);

# Output filenames
croak "Missing argument(s). You must supply an output filename --out.\n" unless $output_file;

# Get and print trees
$t->coreNewickTrees($output_file);





