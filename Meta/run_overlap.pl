#!/usr/bin/env perl

=pod

=head1 NAME

Meta::run_loader.pl

=head1 SYNOPSIS

run_miner.pl --in metadata_json_file --config conf_file

=head1 OPTIONS

  --in       Input attribute file
  --config   Config file with DB connection params

=head1 DESCRIPTION

Runs the Meta::Loader.pm, loading/updating meta-data in DB

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS
 
Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/../';
use Meta::Loader;
use File::Slurp qw/read_file/;
use JSON;
use Data::Dumper;

# Initialize Meta::Loader object
# This step parses the command-line arguments for DB connection parameters, and so
# must go before the other command-line argument processing
my $loader = Meta::Loader->new();

$loader->db_metadata();
print "\nLooking at overlap in strains\n";
$loader->uniquenameFix();
$loader->serotypeFix();
$loader->generate_sql_for_conflicts();