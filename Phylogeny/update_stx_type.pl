#!/usr/bin/env perl

=head1 NAME

$0 - Computes stx types for all public genomes in DB and loads type.

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --tree      Newick-format tree file

=head1 DESCRIPTION

This is the bulk loader/analysis script that computes stx1/2 type and then
loads results into DB.

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/";
use Typer;
use Carp;
use Getopt::Long;


my ($config_file);

GetOptions(
    'config=s' => \$config_file,
);

my %args;
$args{config} = $config_file if $config_file;
my $t = Phylogeny::Typer->new(%args);

# Retrieve stx alignment from database
my ($stx1_file, $stx2_file) = $t->dbAlignments('/tmp/genodo2');

# Compute types
$t->stxTyping('/tmp/genodo2',$stx1_file, $stx2_file);







