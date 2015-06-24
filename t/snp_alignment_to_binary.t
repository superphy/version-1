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
use Statistics::R;


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
my $rfile = "$test_dir/test.RData";
my @program = ($perl_interpreter, $script,
	"--path $test_dir/test",
	"--config $config_file",
	"--rfile $rfile"
);
my $cmd = join(' ', @program);
	
my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
ok($success, "Run $cmd");

# Launch R interface object
my $R = new_ok('Statistics::R');

# Load R data
my $rs1 = $R->run(qq/load('$rfile'); print('SUCCESS')/);
like($rs1, qr'SUCCESS', 'Loaded Rdata file');

subtest 'Binary matrix counts' => sub {
	# Get threshold levels
	my $threshold;
	if(my $conf = Config::Tiny->read($config_file)) {
		$threshold = $conf->{snp}->{significant_count_threshold};
	}
	ok($threshold, 'Obtained SNP count threshold from config');

	# Sum columns in matrix
	my @rcmds = (
		qq/tots = rowSums(snpm)/,
		q/num = ncol(snpm)/,
		qq/bad = any(tots < $threshold | tots > num - $threshold)/,
		q/print('SUCCESS')/
	);

	my $rs1 = $R->run(@rcmds);
	like($rs1, qr'SUCCESS', 'Computed matrix row sums');

	my $bad = $R->get('bad');
	ok(!$bad, 'Matrix counts within threshold');
};

subtest 'SNP allele validation' => sub {

	my $i = 1;
	
	# Pick random SNP binary pattern
	# Retrieve SNP ID & presence/absence data
	my @rcmds = (
		q/testrow = sample(nrow(snpm), 1)/,
		q/pattern = rownames(snpm)[testrow]/,
		q/snps = pattern_to_snp[[pattern]]/,
		q/binary = snpm[testrow,]/
	);

	my $rs1 = $R->run(@rcmds);
	like($rs1, qr'SUCCESS', 'Computed matrix row sums');

	my $bad = $R->get('bad');
	ok(!$bad, 'Matrix counts within threshold');
};
	
	

done_testing();

