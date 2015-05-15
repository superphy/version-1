#!/usr/bin/env perl

use strict;
use warnings;
use Carp;
use FindBin;
use lib "$FindBin::Bin/../";
use Data::Bridge;
use Modules::FormDataGenerator;

=head1 NAME

$0 - Loads meta data for all public genomes into meta table

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config      INI style config file containing DB connection parameters

=head1 DESCRIPTION

To improve the speed of page loading, meta data (i.e. featureprops such as strain)
are queried once and then saved in a table called meta as a json string.  The json
string needs to be updated anytime the public data changes (relatively infrequent).

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

$|=1;

# Parse command-line options and connect to database
my $db_bridge = Data::Bridge->new();

# Initialize FDG object
my $fdg = Modules::FormDataGenerator->new();
$fdg->dbixSchema($db_bridge->dbixSchema);

# Retrieve and load JSON feature data objects in table
$fdg->loadMetaData();


