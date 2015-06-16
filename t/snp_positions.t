#!/usr/bin/env perl

=pod

=head1 NAME

t::shiny.t

=head1 SNYNOPSIS

perl t/shiny.t

=head1 DESCRIPTION

Tests for Data::Snppy and Snp Data in database.

Requires --config command-line argument to connect to live DB

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use FindBin;
use Test::More;
use lib "$FindBin::Bin/../";
use Data::Snppy;
use lib "$FindBin::Bin/lib/";
use TestPostgresDB;
use Test::DBIx::Class {
	schema_class => 'Database::Chado::Schema',
	deploy_db => 0,
	keep_db => 0,
	traits => [qw/TestPostgresDB/]
}, 'Feature', 'PrivateFeature', 'SnpCore';

my $snpObj = new_ok ('Data::Snppy' => [config => $ENV{SUPERPHY_CONFIGFILE}]);

# Identify test case snps in database

# Test Case 1
subtest 'Reference nt in middle' => sub { 
	my $pos = '> 2';
	my $snp_core_rs = SnpCore->search({ allele => {'!=' => '-'}, position => \$pos });
	my $snp_core;
	unless($snp_core = $snp_core_rs->first) {
		plan(skip_all => "Snp matching critera: non-gap in reference & with position > 2 not found ... skipping subtest.");
	}

	diag "SNP ID: ".$snp_core->snp_core_id;

	ok my $result = $snpObj->get($snp_core->snp_core_id, undef), 'Data::Snppy->get() call';

	ok validate_snps($result), 'Snp data matches contig sequence data';
	
};

# Test Case 2a
subtest 'Reference gap segment in middle, beginning of indel' => sub { 
	my $pos = '> 2';
	my $snp_core_rs = SnpCore->search({ allele => '-', position => \$pos, gap_offset => 1 });
	my $snp_core;
	unless($snp_core = $snp_core_rs->first) {
		plan(skip_all => "Snp matching critera: gap in reference with position > 2 & gap_offset == 1 ... skipping subtest.");
	}

	diag "SNP ID: ".$snp_core->snp_core_id;

	ok my $result = $snpObj->get($snp_core->snp_core_id, undef), 'Data::Snppy->get() call';

	ok validate_snps($result), 'Snp data matches contig sequence data';
};

# Test Case 2b
subtest 'Reference gap segment in middle, not beginning of indel' => sub { 
	my $pos = '> 2';
	my $snp_core_rs = SnpCore->search({ allele => '-', position => \$pos, gap_offset => \$pos });
	my $snp_core;
	unless($snp_core = $snp_core_rs->first) {
		plan(skip_all => "Snp matching critera: gap in reference, with position > 2 & gap_offset > 2 not found ... skipping subtest.");
	}

	diag "SNP ID: ".$snp_core->snp_core_id;

	ok my $result = $snpObj->get($snp_core->snp_core_id, undef), 'Data::Snppy->get() call';

	ok validate_snps($result), 'Snp data matches contig sequence data';
};


# Test Case 3a
subtest 'Reference gap segment at start, beginning of indel' => sub {
	my $snp_core_rs = SnpCore->search({ allele => '-', position => 0, gap_offset => 1 });
	my $snp_core;
	unless($snp_core = $snp_core_rs->first) {
		plan(skip_all => "Snp matching critera: gap in reference with position == 0 & gap_offset == 1 not found ... skipping subtest.");
	}

	diag "SNP ID: ".$snp_core->snp_core_id;

	ok my $result = $snpObj->get($snp_core->snp_core_id, undef), 'Data::Snppy->get() call';

	ok validate_snps($result), 'Snp data matches contig sequence data';
};


# Test Case 3b
subtest 'Reference gap segment at start, beginning of indel' => sub {
	my $pos = '> 2';
	my $snp_core_rs = SnpCore->search({ allele => '-', position => 0, gap_offset => \$pos });
	my $snp_core;
	unless($snp_core = $snp_core_rs->first) {
		plan(skip_all => "Snp matching critera: gap in reference with position == 0 & gap_offset > 2 not found ... skipping subtest.");
	}

	ok my $result = $snpObj->get($snp_core->snp_core_id, undef), 'Data::Snppy->get() call';

	ok validate_snps($result), 'Snp data matches contig sequence data';
	
};


done_testing();

sub validate_snps {
	my $resultset = shift;

	foreach my $result (values %$resultset) {
		my $locus_id = $result->{locus_id};
		my $is_public = $result->{is_public};
		my $genome_id = $result->{genome_id};
		my $contig_id = $result->{contig_id};
		my $strand = $result->{strand};
		my $allele = $result->{allele};

		#diag explain $result;

		# Retrive contig sequence
		
		my $contig;
		if($is_public) {
			$contig = Feature->find($contig_id);
			unless($contig) {
				diag "No contig matching feature_id $contig_id";
				return 0;
			}
		}
		else {
			$contig = PrivateFeature->find($contig_id);
			unless($contig) {
				diag "No contig matching private_feature_id $contig_id";
				return 0;
			}
		}

		my $seq = $contig->residues;

		my $start = $result->{position} - 2 - 1; # Zero doens't count as a position
		my $window = substr($seq, $start, 5);
		my @chars = split(//, $window);
		my $true_nt = $chars[2];
	
		my $pre = 'public_';
		$pre = 'private_' unless $is_public;
		
		my $msg = "SNP position in in contig $pre$genome_id|$contig_id (locus region: $locus_id) has expected SNP allele: $allele. Observed: ";
		if($result->{indel}) {
			$msg .= join('',@chars[0..2])." > - < ".join('',@chars[3..4])." (strand: $strand).";
			$true_nt = '-';
		}
		else {
			$msg .= join('',@chars[0..1])." > $chars[2] < ".join('',@chars[3..4])." (strand: $strand)."
		}

		if($strand == -1) {
			# Reverse strand convert
			my ($comp_nt, $ok) = Data::Snppy::dnacomp($true_nt);
			
			unless($ok && $comp_nt eq $allele) {
				diag $msg;
				return 0;
			}
			
		} else {
			unless($true_nt eq $allele) {
				diag $msg;
				return 0;
			}
		}

	}

	return 1;
}



