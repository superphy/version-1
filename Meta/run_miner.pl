#!/usr/bin/env perl

=pod

=head1 NAME

Meta::run_miner.pl

=head1 SYNOPSIS

run_miner.pl --in attribute_json_file --out result_output_file

=head1 OPTIONS

  --in       Input attribute file
  --out      Filename to print results to

=head1 DESCRIPTION

Runs the Meta::Miner.pm parsing scheme against the attributes in the JSON-format input file
outputing Superphy meta-data terms in JSON format to the specified output file.

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
use Meta::Miner;
use File::Slurp qw/read_file/;

# Initialize Meta::Miner object
# This step parses the command-line arguments for DB connection parameters, and so
# must go before the other command-line argument processing
my $decision_tree_file = dirname(__FILE__) . '/etc/biosample_decision_tree.json';
my $decision_tree_json = read_file( $decision_tree_file ) or die "Error: unable to load file $decision_tree_file ($!)\n";

my $miner = Meta::Miner->new(decision_tree_json => $decision_tree_json);


# Parse command-line arguments
my ($infile, $outfile, $DEBUG, $MANPAGE);
print GetOptions(
    'in=s'     => \$infile,
    'out=s'    => \$outfile,
    'manual'   => \$MANPAGE,
    'debug'    => \$DEBUG,
) or pod2usage(-verbose => 1, -exitval => -1);

pod2usage(-verbose => 1, -exitval => 1) if $MANPAGE;

die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --in.") unless $infile;
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --out.") unless $outfile;

# Load input file
my $input_json = read_file( $infile ) or die "Error: unable to load file $infile ($!)\n";

print "<$input_json>";

# Search input & generate Superphy meta-data
my $results_json = $miner->parse($input_json);


# Print results
if($results_json) {
	open(my $out, ">$outfile") or die "Error: unable to write to file $outfile ($!)\n";
	print $out $results_json;
	close $out;
}