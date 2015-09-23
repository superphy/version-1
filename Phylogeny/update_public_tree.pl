#!/usr/bin/env perl

=head1 NAME

  $0 - Updates the precomputed public tree

=head1 SYNOPSIS

  % update_public_tree.pl --config filename

=head1 COMMAND-LINE OPTIONS

 --config         Must specify a .conf containing DB connection parameters.
 

=head1 DESCRIPTION

The 'perlpub' and 'jsonpub' tree strings contain only the publicly visible
genomes in the 'global' genome tree. These need to be updated when the access
for a genome changes.

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

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

# Get full tree with all genomes
my $full_tree = $t->globalTree();

# Reload public trees, pruning private genomes
$t->loadPerlTree($full_tree);

exit(0);
