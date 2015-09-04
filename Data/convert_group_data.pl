#!/usr/bin/env perl

=head1 NAME

$0 - Prepares SNP and pangenome presence/absence data for R/Shiny app

=head1 SYNOPSIS

  % convert_group_data.pl --config filename [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Must specify a .conf containing DB connection parameters.
 [--offset ]      For parallelization, process a subset of pangenome segments that fall within given LIMIT/OFFSET.
 [--limit ]       For parallelization, process a subset of pangenome segments that fall within given LIMIT/OFFSET.
 [--timer ]       Print runtime stats
 [--fileprefix ]  Use this directory filename prefix instead of default in naming the SNPs and pangenome matrix files.

=head1 DESCRIPTION

Retrieves the SNP data, binarizes it and saves it in file as tab-delim matrix. Also
retrieves the pangenome presence/absence data and saves it as matrix file.

DBI over DBIx::Class is used for speed.

Default output files are:
  superphy_matrix_snp.tab
  superphy_matrix_pangenome.tab

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
use DBI;
use Carp qw/croak carp/;
use Config::Simple;
use Time::HiRes qw( time );


# Get cmd-line options
my ($CONFIG, $BLOCKSIZE, $OFFSET, $TIMER, $FILEPRE);
$TIMER = 0;
GetOptions(
    'config=s'      => \$CONFIG,
    'offset=i'      => \$OFFSET,
    'limit=i'       => \$BLOCKSIZE,
    'timer'         => \$TIMER,
    'fileprefix=s'  => \$FILEPRE
) or ( system( 'pod2text', $0 ), exit -1 );

# Option checks
if(defined($OFFSET) && !$BLOCKSIZE) {
	croak "Error: missing argument. You must provide a --limit value when --offset specified.\n" . system ('pod2text', $0) unless $CONFIG;
}
if(!defined($OFFSET) && $BLOCKSIZE) {
	croak "Error: missing argument. You must provide a --offset value when --limit specified.\n" . system ('pod2text', $0) unless $CONFIG;
}

$FILEPRE = 'superphy_matrix' unless $FILEPRE;

# Connect to DB
my ($DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI);
croak "Error: missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;
if(my $db_conf = new Config::Simple($CONFIG)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
} else {
	die Config::Simple->error();
}

my $dsn = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dsn . ';port=' . $DBPORT if $DBPORT;

my $dbh = DBI->connect(
		$dsn,
		$DBUSER,
		$DBPASS,
		{
			AutoCommit => 1,
			TraceLevel => 0,
			RaiseError => 1
		}
	) or croak "Error: unable to connect to database";
	

my $now = my $begin = time();

# Obtain cvterm IDs
my %cvterms = initialize_ontology($dbh);
elapsed_time("CVterms retrieved");

# Retrieve IDs of all genomes in DB
my ($tmp, $ngenomes) = retrieve_genomes($dbh);
my %genomes = %$tmp;
elapsed_time("Genomes retrieved ($ngenomes genomes)" );

# Prepare statements

# Retrieve pangenome segments and core status
my @sql_parts = (
	q{SELECT feature_id, is_not FROM feature_cvterm WHERE cvterm_id = }.$cvterms{core_genome}
);

# Only retrieve subset of pangenome segments
if($BLOCKSIZE) {
	push @sql_parts, qq{LIMIT $BLOCKSIZE};
	push @sql_parts, qq{OFFSET $OFFSET};
	push @sql_parts, q{ORDER BY feature_id};
}
my $pg_sth = $dbh->prepare(join(' ', @sql_parts));
$pg_sth->execute;
my ($pg_id, $not_core);
$pg_sth->bind_columns(\$pg_id, \$not_core);

# Retrieve list of public genomes with segment
my $publoci_sth = $dbh->prepare(
	join(' ',
		q{SELECT r2.object_id},
		q{FROM feature_relationship r1, feature_relationship r2, feature f},
		q{WHERE r1.type_id = },$cvterms{derives_from},'AND',
		q{r1.object_id = ?},'AND',
		q{r1.subject_id = f.feature_id},'AND',
		q{f.feature_id = r2.subject_id},'AND',
		q{r2.type_id = },$cvterms{part_of}
	)
);

# Retrieve list of private genomes with segment
my $priloci_sth = $dbh->prepare(
	join(' ',
		q{SELECT r2.object_id},
		q{FROM pripub_feature_relationship r1, pripub_feature_relationship r2, private_feature f},
		q{WHERE r1.type_id = },$cvterms{derives_from},'AND',
		q{r1.object_id = ?},'AND',
		q{r1.subject_id = f.feature_id},'AND',
		q{f.feature_id = r2.subject_id},'AND',
		q{r2.type_id = },$cvterms{part_of}
	)
);

# Retrieve SNPs found in this pangenome region
my $snp_sth = $dbh->prepare(
	join(' ',
		q{SELECT snp_core_id, allele, frequency_a, frequency_t, frequency_c, frequency_g},
		q{FROM snp_core},
		q{WHERE pangenome_region_id = ?},'AND',
		q{snp_core.is_polymorphism = TRUE}
	)
);

# Retrieve public variations for this snp
my $pubvar_sth = $dbh->prepare(
	join(' ',
		q{SELECT contig_collection_id, allele},
		q{FROM snp_variation},
		q{WHERE snp_id = ?}
	)
);

# Retrieve private variations for this snp
my $privar_sth = $dbh->prepare(
	join(' ',
		q{SELECT contig_collection_id, allele},
		q{FROM private_snp_variation},
		q{WHERE snp_id = ?}
	)
);

# Open output file handles

my $pgfile = $FILEPRE.'_pangenome.tab';
open(PGOUT, ">$pgfile") or croak "Error: unable to write to file $pgfile ($!).\n";
my $snpfile = $FILEPRE.'_snp.tab';
open(SNPOUT, ">$snpfile") or croak "Error: unable to write to file $snpfile ($!).\n";

# Print ordered genome headers for pangenome and SNPs files
unless($OFFSET) {
	my @ordered_genomes = sort { $genomes{$a} <=> $genomes{$b} } keys %genomes;
	print PGOUT "\t".join("\t",@ordered_genomes),"\n";
	print SNPOUT "\t".join("\t",@ordered_genomes),"\n";
}

# Iterate through each pangenome segment
while($pg_sth->fetch) {
	elapsed_time("Current pangenome segment: $pg_id");

	# Initialize empty array, default genome does not have segment (0 value).
	my @pangenome_row = (0) x $ngenomes;
	
	# Retrieve list of public genomes with segment
	$publoci_sth->execute($pg_id);
	while(my ($genome_id) = $publoci_sth->fetchrow_array()) {
		my $genome = 'public_'. $genome_id;

		my $row = $genomes{$genome};
		die "Error: unknown genome $genome." unless defined $row;

		# Set value for presence
		$pangenome_row[$row] = 1;
	}

	# Retrieve list of private genomes with segment
	$priloci_sth->execute($pg_id);
	while(my ($genome_id) = $priloci_sth->fetchrow_array()) {
		my $genome = 'private_'. $genome_id;

		my $row = $genomes{$genome};
		die "Error: unknown genome $genome." unless defined $row;

		# Set value for presence
		$pangenome_row[$row] = 1;
	}
	elapsed_time("Lookup of pangenome loci completed.");

	# Print row of pangenome values
	print PGOUT join("\t",$pg_id,@pangenome_row),"\n";

	unless($not_core) {
		
		# Create starting array with NA filled in.
		# NA indicates genome does not have snp due
		# to missing pangenome segment or indel event.
		my @starting_a;
		my @starting_b;
		foreach my $c (@pangenome_row) {
			my $v1 = ($c == 0) ? 'NA' : 0;
			my $v2 = ($c == 0) ? 'NA' : 1;
			push @starting_a, $v1;
			push @starting_b, $v2;
		}

		# Retrieve SNPs found in this pangenome region
		# Only get entries in snp_core that qualify as polymorphisms
		$snp_sth->execute($pg_id);

		# Iterate through each snp
		while(my ($snp_id, $background, $freq_a, $freq_t, $freq_g, $freq_c) = $snp_sth->fetchrow_array()) {

			# Expand snp into binary states
			# Each row is separate state
			my %states;
			my %found_states; # This is just some debugging from my sanity, its not needed for function

			# Background state
			$states{$background} = [@starting_b];

			# Other states
			if($freq_a > 1) {
				$states{'A'} = [@starting_a];
			}

			if($freq_t > 1) {
				$states{'T'} = [@starting_a];
			}

			if($freq_g > 1) {
				$states{'G'} = [@starting_a];
			}

			if($freq_c > 1) {
				$states{'C'} = [@starting_a];
			}

			# Retrieve variations for this snp
			foreach my $set (['public_', $pubvar_sth], ['private_', $privar_sth]) {
				my $label = $set->[0];
				my $var_sth = $set->[1];

				$var_sth->execute($snp_id);

				# Record variations in binary state arrays
				while (my ($genome_id, $n) = $var_sth->fetchrow_array()) {
					my $genome = $label. $genome_id;
					my $row = $genomes{$genome};
					croak "Error: unknown genome $genome." unless defined $row;

					croak "Logic Error!! Nucleotides matching the background allele should not be recorded in snp_variation table (genome: $genome, snp: $snp_id)"
						if $n eq $background;
			
					# Gaps get NA values
					if($n eq '-') {
						foreach my $state (keys %states) {
							$states{$state}->[$row] = 'NA';
						}
					} else {
						$n = uc($n);
						if(defined($states{$n})) {
							$states{$background}->[$row] = 0;
							$states{$n}->[$row] = 1;
						}
						$found_states{$n}++;
					}
				}
			}

			# Sanity check
			foreach my $n (keys %found_states) {
				if($found_states{$n} > 1) {
					# Reached critical num of variations for given state
					# There better be a record of this state
					croak "Logic Error!! snp_core table frequency values do not match snp_variation entries ".
						"(found ".$found_states{$n}." $n alleles for snp_core_id: $snp_id).\n"
						unless defined $states{$n};
				}
			}

			foreach my $n (keys %states) {
				unless($n eq $background || $found_states{$n} > 1) {
					# Did not reached critical num of variations for given state
					# There should not be a record of this state
					croak "Logic Error!! snp_core table frequency values do not match snp_variation entries ".
						"(found ".$found_states{$n}." $n alleles for snp_core_id: $snp_id).\n"
						unless defined $states{$n};
				}
			}

			
			# Print SNPs rows
			foreach my $state (keys %states) {
				my $rowname = $snp_id . "_$state";
				print SNPOUT join("\t",$rowname,@{$states{$state}}),"\n";
			}
		}

		elapsed_time("Lookup of pangenome snps completed.");
	}
	
	

	elapsed_time("End of iteration for pangenome segment $pg_id.");
}

close SNPOUT;
close PGOUT;

$now = $begin;
elapsed_time("Total runtime");

## END or program

## Subs

sub elapsed_time {
	my ($mes) = @_;

	return unless $TIMER;
	
	my $time = $now;
	$now = time();
	printf("$mes: %.2f\n", $now - $time);
	
}

sub initialize_ontology {
	my $dbh = shift;

	my %cvterms;
	my @types;

	# Needed types
	push @types, ['derives_from', 'relationship'];
	push @types, ['contig_collection', 'sequence'];
	push @types, ['pangenome', 'local'];
	push @types, ['core_genome', 'local'];
	push @types, ['locus', 'local'];
	push @types, ['part_of', 'relationship'];

	# Run query
	my $sth = $dbh->prepare(q {SELECT t.cvterm_id FROM cvterm t, cv v WHERE t.name = ? AND v.name = ? AND t.cv_id = v.cv_id} ); 

	foreach my $t (@types) {
		$sth->execute($t->[0], $t->[1]);

    	my ($cvterm_id) = $sth->fetchrow_array();
		$cvterms{$t->[0]} = $cvterm_id;
	}

	return %cvterms;
 }

 sub retrieve_genomes {
 	my $dbh = shift;

 	my %genomes;
 	my $nrow = 0;

 	# Public genomes
 	my $sth = $dbh->prepare(q{SELECT feature_id FROM feature WHERE type_id = }.$cvterms{contig_collection}.q{ ORDER BY feature_id});
 	$sth->execute;

 	my $feature_id;
 	$sth->bind_columns(\$feature_id);

 	while($sth->fetch) {
 		$genomes{'public_'.$feature_id} = $nrow;
 		$nrow++;
 	}

 	# Private genomes
 	$sth = $dbh->prepare(q{SELECT feature_id FROM private_feature WHERE type_id = }.$cvterms{contig_collection}.q{ ORDER BY feature_id});
 	$sth->execute;
 	$sth->bind_columns(\$feature_id);

 	while($sth->fetch) {
 		$genomes{'private_'.$feature_id} = $nrow;
 		$nrow++;
 	}

 	return (\%genomes, $nrow);
 }
