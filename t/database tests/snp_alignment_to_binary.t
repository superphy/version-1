#!/usr/bin/env perl

=pod

=head1 NAME

t::snp_alignment_to_binary.t

=head1 SNYNOPSIS

SUPERPHY_CONFIGFILE=filename prove -lv t/snp_alignment_to_binary.t

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
}, 'SnpVariation', 'SnpCore';


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
		qq/tots = colSums(snpm)/,
		q/num = nrow(snpm)/,
		qq/bad = any(tots < $threshold | tots > num - $threshold)/,
		q/print('SUCCESS')/
	);

	my $rs1 = $R->run(@rcmds);
	like($rs1, qr'SUCCESS', 'Computed matrix row sums');

	my $bad = $R->get('bad');
	like($bad, qr'FALSE', 'Matrix counts within threshold');
};

subtest 'SNP allele validation' => sub {

	for my $i (1..4) {
	
		my @rcmds;
		if($i == 4) {
			# Pick last binary pattern
			@rcmds = (
				q/testcol = ncol(snpm)/,
			);
		} 
		else {
			# Pick random SNP binary pattern
			@rcmds = (
				q/testcol = sample(ncol(snpm), 1)/,
			);
		}

		# Retrieve presence/absence data
		push @rcmds, q/pattern = colnames(snpm)[testcol]/,
			q/snps = pattern_to_snp[[pattern]]/,
			q/present = rownames(snpm)[snpm[,testcol] == 1]/,
			q/absent = rownames(snpm)[snpm[,testcol] == 0]/,
			q/print('SUCCESS')/;

		my $rs1 = $R->run(@rcmds);
		like($rs1, qr'SUCCESS', "Selected pattern for test (iteration $i)");

		my $snps = $R->get('snps');
		ok($snps, "Retrieved SNP list for pattern (iteration $i)");

		my $pattern = $R->get('pattern');
		diag($pattern);

		my $present = $R->get('present');
		my $absent = $R->get('absent');
		ok($present && $absent, "Retrieved binary pattern (iteration $i)");

		diag(explain($snps));

		# Parse SNP ID string
		my @snp_list = ref($snps) eq 'ARRAY' ? @$snps : ($snps);

		foreach my $snp (@snp_list) {
			my ($id, $alleles) = ($snp =~ m/^(\d+)_(.+)$/);

			# Find Snp in DB
			ok my $snp_row = SnpCore->find({ snp_core_id => $id })
				=> "SNP $id found in DB (iteration $i)";
			BAIL_OUT("Cannot find SNP in DB. Remaining tests will fail.") unless $snp_row;
			my $snp_id = $snp_row->snp_core_id;

			if($alleles =~ m/\&/) {
				# Only two alleles
				my ($present_nt, $absent_nt) = ($alleles =~ m/(\w)=1&(\w)=0/);

				# Determine background allele & variation
				my $variation;
				my %variation_genomes;
				if($snp_row->allele eq $present_nt) {
					$variation = $absent_nt;
					map { $variation_genomes{$_} = 1 } @$absent;
				}
				elsif($snp_row->allele eq $absent_nt) {
					$variation = $present_nt;
					map { $variation_genomes{$_} = 1 } @$present;
				}

				ok($variation, "Background allele matches one of alleles in binary pattern (iteration $i)");

				ok check_variations($snp_id, \%variation_genomes, $variation, 0)
					=> "SNP alleles match binary pattern for SNP $snp_id (iteration $i)"

			}
			else {
				# Multiple alleles
			
				if($alleles =~ m/(\w)=1/) {
					my $variation = $1;
					my %variation_genomes;
					my $is_not = 0;

					# Determine background allele & variation
					if($snp_row->allele eq $variation) {
						# This list of genomes in snp_variation table will not have this allele
						map { $variation_genomes{$_} = 1 } @$absent;
						$is_not = 1;

						ok check_variations($snp_id, \%variation_genomes, $variation, $is_not)
							=> "SNP alleles match binary pattern for SNP $snp_id (iteration $i)"
					}
					else {
						# This list of genomes with this allele will appear in snp_variation table
						map { $variation_genomes{$_} = 1 } @$present;
					
						ok check_genome_variations($snp_id, \%variation_genomes, $variation)
							=> "SNP alleles match binary pattern for SNP $snp_id (iteration $i)"
					}

				}
				elsif($alleles =~ m/(\w)=0/) {
					my $variation = $1;
					my %variation_genomes;
					my $is_not = 0;

					# Determine background allele & variation
					if($snp_row->allele eq $variation) {
						# This list of genomes in snp_variation table will not have this allele
						map { $variation_genomes{$_} = 1 } @$present;
						$is_not = 1;

						ok check_variations($snp_id, \%variation_genomes, $variation, $is_not)
							=> "SNP alleles match binary pattern for SNP $snp_id (iteration $i)"
					}
					else {
						# This list of genomes with this allele will appear in snp_variation table
						map { $variation_genomes{$_} = 1 } @$absent;

						ok check_genome_variations($snp_id, \%variation_genomes, $variation)
							=> "SNP alleles match binary pattern for SNP $snp_id (iteration $i)"
					}
				}
			}
		}
	}
};
	
done_testing();


###############
## Subs
###############

# Search all variations in the table for a SNP
# Check against expected list of genomes
sub check_variations {
	my $snp_id = shift;
	my $variation_genomes = shift;
	my $variation = shift;
	my $is_not = shift;

	my $var_rs = SnpVariation->search({ snp_id => $snp_id });

	#diag(explain($variation_genomes));

	# Check presence/absence in binary matrix against snp data in DB
	while(my $var_row = $var_rs->next) {

		my $genome = 'public_'.$var_row->contig_collection_id;
		if($variation_genomes->{$genome}) {
			$variation_genomes->{$genome}++
		}
		else {
			diag("Genome $genome in snp_variation table not marked in binary column for SNP $snp_id");
			return(0);
		}

		if($is_not && $var_row->allele eq $variation) {
			diag("Genome $genome has variation $variation. Expected genome to not have variation for SNP $snp_id");
			return(0);
		}
		elsif(!$is_not && $var_row->allele ne $variation) {
			diag("Genome $genome does not have variation $variation. Expected genome to have variation for SNP $snp_id");
			return(0);
		}
	}

	# Check all genomes were accounted for
	if( any { $_ != 2 } values %$variation_genomes ) {
		diag(explain($variation_genomes));
		diag("Some genomes were not found in snp_variation table for SNP $snp_id (case 1)");
		return 0;
	}

	return 1;

}

# Search for genomes with allele in snp_variations table
sub check_genome_variations {
	my $snp_id = shift;
	my $variation_genomes = shift;
	my $variation = shift;

	# Convert to integer IDs
	my @public;
	foreach my $g (keys %$variation_genomes) {
		if($g =~ m/public_(\d+)/) {
			push @public, $1;
		}
	}
	
	my $var_rs = SnpVariation->search(
		{
			snp_id => $snp_id,
			contig_collection_id => { '-in' => [ @public ] }
		}
	);

	# Check presence/absence in binary matrix against snp data in DB
	while(my $var_row = $var_rs->next) {

		my $genome = 'public_'.$var_row->contig_collection_id;
		$variation_genomes->{$genome}++;
	
		if($var_row->allele ne $variation) {
			diag("Genome $genome does not have variation $variation. Expected genome to have variation for SNP $snp_id");
			return(0);
		}

	}

	# Check all genomes were accounted for
	if( any { $_ != 2 } values %$variation_genomes ) {
		diag(explain($variation_genomes));
		diag("Some genomes were not found in snp_variation table for SNP $snp_id (case 2)");
		return 0;
	}

	return 1;
}