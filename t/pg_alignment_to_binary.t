#!/usr/bin/env perl

=pod

=head1 NAME

t::pg_alignment_to_binary.t

=head1 SNYNOPSIS

SUPERPHY_CONFIGFILE=filename prove -lv t/pg_alignment_to_binary.t

=head1 DESCRIPTION



=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 TODO

1) Add support for private genomes in test script.

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
use Config::Tiny;
use List::Util qw/any/;
use lib dirname(__FILE__) .'/lib/';
use TestPostgresDB;
use Test::DBIx::Class {
	schema_class => 'Database::Chado::Schema',
	deploy_db => 0,
	keep_db => 0,
	traits => [qw/TestPostgresDB/]
}, 'FeatureRelationship', 'Feature', 'Cvterm';


my $perl_interpreter = $^X;
my $script = dirname(__FILE__) . '/../Data/pg_alignment_to_binary.pl';

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
		qq/tots = colSums(pgm)/,
		q/num = nrow(pgm)/,
		qq/bad = any(tots < $threshold | tots > num - $threshold)/,
		q/print('SUCCESS')/
	);

	my $rs1 = $R->run(@rcmds);
	like($rs1, qr'SUCCESS', 'Computed matrix row sums');

	my $bad = $R->get('bad');
	like($bad, qr'FALSE', 'Matrix counts within threshold');
};

my ($derives_from, $locus, $part_of);
subtest 'PG presence/absence validation' => sub {

	# Grap some type IDs
	my $t_rs = Cvterm->search(
		{
			'me.name' => { '-in' => [qw/derives_from locus part_of/]}
		},
		{
			prefetch => [ qw/cv/ ] 
		}
	);

	while(my $t_row = $t_rs->next) {
		if($t_row->name eq 'derives_from' && $t_row->cv->name eq 'relationship') {
			$derives_from = $t_row->cvterm_id;
		}
		elsif($t_row->name eq 'locus') {
			$locus = $t_row->cvterm_id;
		}
		elsif($t_row->name eq 'part_of' && $t_row->cv->name eq 'relationship') {
			$part_of = $t_row->cvterm_id;
		}
	}
	ok($derives_from && $part_of && $locus, 'Retrieved cvterm IDs');

	for my $i (1..4) {
	
		my @rcmds;
		if($i == 4) {
			# Pick last binary pattern
			@rcmds = (
				q/testcol = ncol(pgm)/,
			);
		} 
		else {
			# Pick random SNP binary pattern
			@rcmds = (
				q/testcol = sample(ncol(pgm), 1)/,
			);
		}

		# Retrieve presence/absence data
		push @rcmds, q/pattern = colnames(pgm)[testcol]/,
			q/pgs = pattern_to_pg[[pattern]]/,
			q/present = rownames(pgm)[pgm[,testcol] == 1]/,
			q/absent = rownames(pgm)[pgm[,testcol] == 0]/,
			q/print('SUCCESS')/;

		my $rs1 = $R->run(@rcmds);
		like($rs1, qr'SUCCESS', "Selected pattern for test (iteration $i)");

		my $pgs = $R->get('pgs');
		ok($pgs, "Retrieved pangenome list for pattern (iteration $i)");

		my $pattern = $R->get('pattern');
		diag($pattern);

		my $present = $R->get('present');
		my $absent = $R->get('absent');
		ok($present && $absent, "Retrieved binary pattern (iteration $i)");

		diag(explain($pgs));

		# Parse SNP ID string
		my @pg_list = ref($pgs) eq 'ARRAY' ? @$pgs : ($pgs);

		foreach my $pg (@pg_list) {
			my ($id, $with) = ($pg =~ m/^(\d+)_has=(\d)$/);

			# Find Pangenome feature in DB
			ok my $pg_row = Feature->find({ feature_id => $id })
				=> "Region $id found in DB (iteration $i)";
			BAIL_OUT("Cannot find region in DB. Remaining tests will fail.") unless $pg_row;
			my $pg_id = $pg_row->feature_id;

			# Grab expected genomes with region
			my %pg_genomes;
			unless($with) {
				map { $pg_genomes{$_} = 1 } @$absent;

			}
			else {
				map { $pg_genomes{$_} = 1 } @$present;

			}

			ok check_regions($pg_id, \%pg_genomes)
				=> "Pangenome regions match binary pattern for PG $pg_id (iteration $i)";

		}
	}
};
	
done_testing();


###############
## Subs
###############

# Check regions in DB against expected list of genomes
sub check_regions {
	my $pg_id = shift;
	my $pg_genomes = shift;

	my $pg_rs = FeatureRelationship->search(
		{
			'me.type_id' => $part_of,
			'subject.type_id' => $locus,
			'feature_relationship_subjects.type_id' => $derives_from,
			'feature_relationship_subjects.object_id' => $pg_id,
		},
		{
			join => { 'subject' => 'feature_relationship_subjects' },
			columns => [qw/object_id/]
		}
	);
	
	
	# Check presence/absence in binary matrix against pg data in DB
	while(my $pg_row = $pg_rs->next) {

		my $genome = 'public_'.$pg_row->object_id;
		if($pg_genomes->{$genome}) {
			$pg_genomes->{$genome}++
		}
		else {
			diag("Genome $genome linked to region in DB not marked in binary column for PG $pg_id");
			return(0);
		}
	}

	# Check all genomes were accounted for
	if( any { $_ != 2 } values %$pg_genomes ) {
		diag(explain($pg_genomes));
		diag("Some genomes were not found linked to region in DB for PG $pg_id");
		return 0;
	}

	return 1;

}

