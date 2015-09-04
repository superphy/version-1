#!/usr/bin/env perl

=head1 NAME

  $0 - Creates or updates the strain groups that are available to all users

=head1 SYNOPSIS

  % update_standard_strain_groups.pl --config filename

=head1 COMMAND-LINE OPTIONS

 --config         Must specify a .conf containing DB connection parameters.
 

=head1 DESCRIPTION

Collects public meta-data and produces the set of standard groups that all
users are presented with. Operates in 'find or create' mode, only adding
missing groups and group-genome connections.

Private genomes are added to these groups in the upload pipeline. This
script only updates the public genome set. Groups only need to be updated
when the public genome set changes.

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
use Modules::FormDataGenerator;
use Carp qw/croak carp/;
use Log::Log4perl qw/:easy/;


# Initialize logger
Log::Log4perl->easy_init($INFO);

# Initialize DB interface objects via Bridge module
my $dbBridge = Data::Bridge->new();

# Initialize Grouping module
my $grouper = Data::Grouper->new(schema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory);

# Initialize Data Retrival module
my $data = Modules::FormDataGenerator->new(dbixSchema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory);


# Perform update / creation of standard groups
$grouper->updateStandardGroups($data, $dbBridge->adminUser);




