#!/usr/bin/env perl

=head1 NAME

$0 - Loads the reference typing features into DB

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config     Config file containing DB connection parameters

=head1 DESCRIPTION

Needs only be called once. Script inserts the features used as references
in the Stx typing if not found. Variant features in individual genomes 
are linked to these reference features.

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

$t->insertTypingObjects();







