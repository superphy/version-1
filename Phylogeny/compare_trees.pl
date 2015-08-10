#!/usr/bin/env perl

=head1 NAME

$0 - Compares two trees

=head1 SYNOPSIS

  % $0 newick_file1 newick_file2

=head1 DESCRIPTION

Compares branching order in two trees reporting if the are equal or
different.  Input is two newick-format tree files.

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Tree;
use Data::Dumper;

my $t = Phylogeny::Tree->new(dbix_schema => 1);

die "Error: missing argument(s)" unless $ARGV[0] || $ARGV[1];

my $t1 = $t->newickToPerl($ARGV[0]);

my $t2 = $t->newickToPerl($ARGV[1]);


my $r = $t->compareTrees($t1, $t2) ? 'different': 'equal';

print "The trees are $r\n";