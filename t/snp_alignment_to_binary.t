#!/usr/bin/env perl

=pod

=head1 NAME

t::snp_alignment_to_binary.t

=head1 SNYNOPSIS

SUPERPHY_CONFIGFILE=filename prove -lv t/snp_alignment_to_binary.t

=head1 DESCRIPTION

Tests for Data::Snppy and Snp Data in database.

Requires environment variable SUPERPHY_CONFIGFILE to provide DB connection parameters. A production DB is ok,
no changes are made to the DB.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use Test::More;
use File::Basename qw/dirname/;
use IO::CaptureOutput qw/capture_exec/;
use File::Temp qw/tempdir/;


my $perl_interpreter = $^X;
my $script = dirname(__FILE__) . '/../Data/snp_alignment_to_binary.pl';

my $config_file = $ENV{SUPERPHY_CONFIGFILE};
ok($config_file, "Retrieved config file");
diag("Config file: ".$config_file);

# Temp directory
my $keep_dir = 0;
my $root_dir = dirname(__FILE__) . '/sandbox';
my $test_dir = tempdir('XXXX', DIR => $root_dir, CLEANUP => $keep_dir);

# Run binary conversion script
my @program = ($perl_interpreter, $script,
	"--path $test_dir/test",
	"--config $config_file"
);
my $cmd = join(' ', @program);
	
my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
ok($success, "Run $cmd");


# # Test Case 3b
# subtest 'Reference gap segment at start, beginning of indel' => sub {
# 	my $pos = '> 2';
# 	my $snp_core_rs = SnpCore->search({ allele => '-', position => 0, gap_offset => \$pos });
# 	my $snp_core;
# 	unless($snp_core = $snp_core_rs->first) {
# 		plan(skip_all => "Snp matching critera: gap in reference with position == 0 & gap_offset > 2 not found ... skipping subtest.");
# 	}

# 	ok my $result = $snpObj->get($snp_core->snp_core_id, undef), 'Data::Snppy->get() call';

# 	ok validate_snps($result), 'Snp data matches contig sequence data';
	
# };


done_testing();

