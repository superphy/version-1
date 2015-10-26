#!/usr/bin/env perl

=pod

=head1 NAME

Meta::run_bulk_miner.pl

=head1 SYNOPSIS

run_bulk_miner.pl --in attribute_json_file --out result_output_file --prop_directory output_directory

=head1 OPTIONS

  --in               Input attribute file
  --out              Filename to print results to
  --prop_directory   Directory to write property files for each genome (used as input to loading pipeline)

=head1 DESCRIPTION

Runs the Meta::Miner.pm parsing scheme against the attributes in the JSON-format input file
outputing Superphy meta-data terms in JSON format to the specified output file.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

use v5.18; # Needed since someone decided to use some experimental features

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/../';
use Meta::Miner;
use Data::Dumper;

# Initialize Meta::Miner object
# This step parses the command-line arguments for DB connection parameters, and so
# must go before the other command-line argument processing
my $miner = Meta::Miner->new();


# Parse command-line arguments
my ($infile, $outfile, $propdir, $DEBUG, $MANPAGE);
print GetOptions(
    'in=s'     => \$infile,
    'out=s'    => \$outfile,
    'prop_directory=s' => \$propdir,
    'manual'   => \$MANPAGE,
    'debug'    => \$DEBUG,
) or pod2usage(-verbose => 1, -exitval => -1);

pod2usage(-verbose => 1, -exitval => 1) if $MANPAGE;

die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --in.") unless $infile;
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --out.") unless $outfile;
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --prop_directory.") unless $propdir;


# Validate input
$miner->parse_input($infile);

# Search input & generate Superphy meta-data
my $results_json = $miner->finalize();

# Print results
if($results_json) {
	open(my $out, ">$outfile") or die "Error: unable to write to file $outfile ($!)\n";
	print $out $results_json;
	close $out;

	$miner->convert_to_pipeline_input(
		output_directory => $propdir,
		acc2name => 1,
		acc2strain => 1
	);
}

