#!/usr/bin/env perl

=pod

=head1 NAME

t::miner.t

=head1 SNYNOPSIS



=head1 DESCRIPTION

Tests for Meta::Miner

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Meta::Miner;
use Test::More;
use Test::Exception;
use Test::DBIx::Class;
use File::Slurp qw/read_file/;
use JSON::MaybeXS qw/decode_json/;

# Install DB data
fixtures_ok 'miner'
	=> 'Install fixtures from configuration files';

# Load Test decision_tree json
my $decision_tree_file = "$FindBin::Bin/etc/test_decision_tree.json";
my $decision_tree_json = read_file( $decision_tree_file );
ok($decision_tree_json, 'Read decision tree JSON file');

# Initialize Miner object
my $miner;
lives_ok { $miner = Meta::Miner->new(schema => Schema, decision_tree_json => $decision_tree_json) } 'Meta::Miner initialized';
BAIL_OUT('Meta::Miner initialization failed') unless $miner;

# Load input file that should work
my $infile = "$FindBin::Bin/etc/test_miner_pass.json";
my $input_json = read_file( $infile );
ok($input_json, 'Read input attribute JSON file: '.$infile);

# Run parser
ok( my $results_json = $miner->parse($input_json), 'Parse attributes');

# Check results
my $results = decode_json($results_json);
ok($results, 'Decode JSON results');

is($results->{'Accession1'}->{'isolation_host'}->[0]->{'id'}, 1, 'Correct assignment of host');

diag explain $results;

done_testing();

