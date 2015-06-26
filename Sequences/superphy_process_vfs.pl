#!/usr/bin/env perl

# Quick script to update the VF csv with new genes to be annotated (based on a fasta file input).
# The script looks for genes already annotated in the csv and adds any new ones while skipping those already present.
# The script also converts the first letter of every gene to a lowercase for consistency in naming.


use strict;
use warnings;

use Bio::SeqIO;
use IO::File;
use POSIX qw(strftime);
use List::MoreUtils qw(uniq);
use Data::Dumper;

# Global Variables
my $timestamp = strftime "%d:%m:%Y %H:%M", localtime;
my $filetimestamp = strftime "%d_%m_%Y", localtime;

my $path_to_vf_fasta = $ARGV[0];
my $path_to_csv = $ARGV[1];
my ($csv_header, $max_tabs, @annotations);

my (%ontology_categories, %ontology_genes, %ontology_unclassified, %ontology_subcategories);

my $ontology_category_count = 1000000;
my $ontology_subcategory_count = 2000000;
my $unclassified_id = 9000000;

#$ontology_categories{'unclassified'}{id} = $unclassified_id;

########################
#Call script subroutines
########################

#write_to_files();

#read_in_fasta();
read_in_csv();
perpare_ontology_terms();
#my $d = Data::Dumper->Dump(\@annotations);
#print $d;
#print Dumper(\%ontology_subcategories);
#print Dumper(\%ontology_categories);
write_out_ontology();

####################
# Helper Subroutines
####################


# TODO: Not implemented yet
# sub read_in_fasta {
# }

sub read_in_csv {
	#TODO: read in categories
	open (my $fh, "<", $path_to_csv) or die "Could not open file: $!\n";

	$csv_header = <$fh>; # strip header from CSV
	$max_tabs = 0;

	while (<$fh>) {
		chomp($_);
		my @line = split('\t', $_);
		$max_tabs = scalar(@line) if scalar(@line) >= $max_tabs;
		# Need to convert the first letter of the gene name to lowercase
 		$line[0] =~ s/^([A-Z])/\l$1/;
		$ontology_genes{$line[0]}{id} = $line[1];
		$ontology_genes{$line[0]}{is_a} = [];
 		push(@annotations, \@line);

	}
}

#####################
# Ontology Structure:
#####################

# Parent VFO: 0000000
# Category IDs start with: 1000000
# Sub Category IDs start with: 2000000
# Gene IDs start with: 3000000

# Category Example
# [Term]
# id: VFO:0000001
# name: Adherence
# xref: VFO:www.mgc.ac.cn/VFs/
# is_a: VFO:0000000 ! Pathogenesis
# created_by: amanji
# creation_date: $timestamp

# Sub Cateegory Example:
# [Term]
# id: VFO:0000003
# name: Type II Secretion System
# xref: VFO:www.mgc.ac.cn/VFs/
# is_a: VFO:0000001 ! Adherence
# created_by: amanji
# creation_date: $timestamp

# VF gene Example:
# [Term]
# id: VFO:0000006
# name: gspC
# xref: VFO:www.mgc.ac.cn/VFs/
# def: "Inner membrane protein; secretin interaction" []
# is_a: VFO:0000002 ! Autotrasnporter
# is_a: VFO:0000003 ! Type II Secretion System
# created_by: amanji
# creation_date: $timestamp

sub perpare_ontology_terms {
	# CSV Headers:
	# [0] VF gene
	# [1] VFO ID
	# [2] Categor(y/ies)
	# [3] Sub Categor(y/ies)

	# Set up unclassified terms
	$ontology_categories{'unclassified'}{id} = $unclassified_id;
	$ontology_subcategories{'unclassified'}{id} = $unclassified_id;

	#Need to prepare categoires if they dont exist and match genes to categories
	foreach my $annotation (@annotations) {
		my @_categories = split(',', $annotation->[2]);
		my @_sub_categories = split(',', $annotation->[3]);

		# Expect categories and subcategories to be the same length
		for (my $i = 0; $i < scalar(@_categories); $i++) {
			# Set up new category and subcategory ids
			$ontology_categories{$_categories[$i]}{id} = ++$ontology_category_count unless exists $ontology_categories{$_categories[$i]};
			$ontology_subcategories{$_sub_categories[$i]}{id} = ++$ontology_subcategory_count unless exists $ontology_subcategories{$_sub_categories[$i]};
			
			# Associate gene -> sub_category -> category
			# Assume a 1:1 relationship between sub_category and category always
			$ontology_subcategories{$_sub_categories[$i]}->{is_a} = $ontology_categories{$_categories[$i]}{id};

			# TODO: Marked for deprecation - Caused issue in mapping
			#push(@{$ontology_subcategories{$_sub_categories[$i]}{is_a}}, $ontology_category_count) unless $_categories[$i] eq 'unclassified';
			#push(@{$ontology_subcategories{$_sub_categories[$i]}{is_a}}, $unclassified_id) if $_categories[$i] eq 'unclassified';
			#push(@{$ontology_genes{$annotation->[0]}{is_a}}, $ontology_subcategory_count) unless $_sub_categories[$i] eq 'unclassified';
			#push(@{$ontology_genes{$annotation->[0]}{is_a}}, $unclassified_id) if $_sub_categories[$i] eq 'unclassified';


			push(@{$ontology_genes{$annotation->[0]}{is_a}}, $ontology_subcategories{$_sub_categories[$i]}{id}) unless $_sub_categories[$i] eq 'unclassified';
			push(@{$ontology_genes{$annotation->[0]}{is_a}}, $unclassified_id) if $_sub_categories[$i] eq 'unclassified';
			
		}
	}
}

sub write_out_ontology {

	open (my $ontology_fh, ">", "./e_coli_VFO_$filetimestamp.obo") or die "Could not open ontology file handle: $!\n";

	my @ontology_header = (
		"format-version: 1.2", 
		"date: $timestamp",
		"saved-by: Akiff Manji",
		"auto-generated-by: update_vf_csv_ontology",
		"default-namespace: e_coli_virulence",
		"ontology: e_coli_virulence\n\n"
		);

	print $ontology_fh join("\n", @ontology_header);

	my @ontology_parent_term = (
		"[Term]",
		"id: VFO:0000000",
		"name: Pathogenesis",
		"namespace: e_coli_virulence",
		"xref: VFO:www.mgc.ac.cn/VFs/",
		"created_by: amanji",
		"creation_date: $timestamp\n\n"
	);

	print $ontology_fh join("\n", @ontology_parent_term);

	my @ontology_unclassified_term = (
		"[Term]",
		"id: VFO:" . $unclassified_id,
		"name: unclassified",
		"namespace: e_coli_virulence",
		"xref: VFO:www.mgc.ac.cn/VFs/",
		"is_a: VFO:0000000 ! Pathogenesis",
		);

	push(@ontology_unclassified_term, "created_by: amanji", "creation_date: $timestamp\n\n");

	print $ontology_fh join("\n", @ontology_unclassified_term);

	# Write out categories
	foreach (keys %ontology_categories) {

		# # Print test:
		# print $_ . " : " . $ontology_categories{$_}{id} . "\n";

		next if $_ eq 'unclassified';
		my @_category = (
			"[Term]",
			"id: VFO: " . $ontology_categories{$_}{id},
			"name: " . $_,
			"namespace: e_coli_virulence",
			"xref: VFO:www.mgc.ac.cn/VFs/",
			"is_a: VFO:0000000 ! Pathogenesis",
			"created_by: amanji",
			"creation_date: $timestamp\n\n"
			);

		print $ontology_fh join("\n", @_category);
	}

	# Write out sub categories
	foreach (keys %ontology_subcategories) {
		next if $_ eq 'unclassified';
		my @_subcategory = (
			"[Term]",
			"id: VFO:" . $ontology_subcategories{$_}{id},
			"name: " . $_,
			"namespace: e_coli_virulence",
			"xref: VFO:www.mgc.ac.cn/VFs/",
			);
			# TODO : Marked for deprecation, caused issue in mapping
			# foreach my $parent_category_id (uniq(@{$ontology_subcategories{$_}{is_a}})) {
			# 		push(@_subcategory, "is_a: VFO:". $parent_category_id . " ! ");
			# 	}	

			push(@_subcategory, "is_a: VFO:". $ontology_subcategories{$_}->{is_a} . " ! ");

			push(@_subcategory, "created_by: amanji", "creation_date: $timestamp\n\n");

			print $ontology_fh join("\n", @_subcategory);
	}

	# Write out genes
	foreach (keys %ontology_genes) {
		my @_gene = (
			"[Term]",
			"id: VFO:" . $ontology_genes{$_}{id},
			"name: " . $_,
			"namespace: e_coli_virulence",
			"xref: VFO:www.mgc.ac.cn/VFs/",
			);
			foreach my $parent_subcategory_id (uniq(@{$ontology_genes{$_}{is_a}})) {
					push(@_gene, "is_a: VFO:". $parent_subcategory_id . " ! ");
				}	
			push(@_gene, "created_by: amanji", "creation_date: $timestamp\n\n");

			print $ontology_fh join("\n", @_gene);
	}

	close $ontology_fh;
}