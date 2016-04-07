#!/usr/bin/env perl

=head1 NAME

  $0 - Updates the Other standard group for meta-data types Serotype, Stx1 and Stx2 subtype

=head1 SYNOPSIS

  % patch_other_standard_strain_groups.pl --config filename

=head1 COMMAND-LINE OPTIONS

 --config         Must specify a .conf containing DB connection parameters.
 

=head1 DESCRIPTION

A change was made to which genomes were added to the "Other" standard strain group
for serotype, stx1 and stx2 strain group. (Previously only values with > 1 were created)
Now all values will be added as strain groups.

This script is a patch/fix and should only be run once

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Data::Bridge;
use Data::Grouper;
use Log::Log4perl qw/:easy/;


# Initialize logger
Log::Log4perl->easy_init($DEBUG);

# Initialize DB interface objects via Bridge module
my $dbBridge = Data::Bridge->new();

# Initialize Grouping module
my $grouper = Data::Grouper->new(schema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory);

# Perform update / creation of standard groups
$grouper->patch_other($dbBridge->adminUser);




