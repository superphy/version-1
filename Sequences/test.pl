#!/usr/bin/env perl


=head1 NAME

$0 - Nicolas's script

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config      INI style config file containing DB connection parameters

=head1 DESCRIPTION

Add description

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Copyright (c) 2015

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Carp;
use FindBin;
use lib "$FindBin::Bin/../";  # Place file in Sequences/ directory
use Data::Bridge; # An accessor object that stores the DB schema

# In the Data::Bridge constructor, the command-line arg: --config filename
# will be parsed and a connection to the DB will be made using the
# Perl DB interface called DBIx::Class
my $db_bridge = Data::Bridge->new();


# In the Chado schema, all 'things' such as genomes, genes, chromosomes go
# into the same table called the feature table. Features have 'types' that
# determine what they are.

# In our DB, genomes have type 'contig_collection'. (A contig is a assembled section of genome)
# Types are listed in a table called 'cvterm' (controlled-vocabulary terms)
# The cvterms are cross-referenced in the feature table in the type_id column (cvterm_id column in cvterm
# table maps to the type_id column in the feature table)

# Using the DBIx::Class interface (which is quite different than SQL), you can retrieve all the genomes in
# the DB as follows:

my $genome_rs = $db_bridge->dbixSchema()->resultset('Feature')->search(
	{
		type_id => $db_bridge->cvmemory('contig_collection') 
		# In Data::Bridge the type_ids for cvterms we commonly use
		# have been already retrieved and cab be accessed using this cvmemory method.
		# This search returns all features that have a type_id == contig_collection's type_id from the DB.
	}
);

# There is information on individual search/find/update methods in the Perl DBIx::Class::Resultset API document.
# Reading up on this would be a good idea

# Now that we have pulled down all genomes from the DB we can print them to screen
while(my $genome_row = $genome_rs->next) {
	print join(', ', $genome_row->feature_id, $genome_row->uniquename),"\n";
}

# To get the accessions for the genomes, using DBIx::Class interface, you can join and retrieve linked accession tables
# to the feature table.
# In Chado, NCBI DB accessions are in the dbxref table.
# Each genome should have a primary genbank id linked via the dbxref_id column in the feature table
# as well as several secondary IDs in linked via the feature_dbxref table (e.g. table maps feature_id <-> dbxref_ids).
# This is where you will find the Bioproject IDs.

# You can find the list of columns and their names as well as linked foreign tables
# in our Schema specification:
# E.g. Database/Chado/Schema/Result/Feature
# Read up on joining behavior for DBIC interface:
# http://search.cpan.org/dist/DBIx-Class/lib/DBIx/Class/Manual/Joining.pod
# http://search.cpan.org/~ribasushi/DBIx-Class-0.082820/lib/DBIx/Class/Manual/Cookbook.pod


my $genome_rs2 = $db_bridge->dbixSchema()->resultset('Feature')->search(
	{
		type_id => $db_bridge->cvmemory('contig_collection'),
	},
	{
		# Joining and fetching the all relevant linked tables
		# Need to link the db table to get the actual name of the Database that the accession is from
		prefetch => [
			{ 'feature_dbxrefs' => {'dbxref' => 'db'}},
			{ 'dbxref' => 'db' }
		]
	}
);

# Now print
while(my $genome_row = $genome_rs2->next) {
	# Must be aware if table links are 1-1 or 1-many
	# It will change how you can access the linked table data
	# In this case 'dbxref' is 1-1, but 'feature_dbxref' is 1-many
	my $primary_id = join('.', $genome_row->dbxref->db->name, $genome_row->dbxref->accession, $genome_row->dbxref->version);
	print 'PrimaryID:'.$primary_id .' for genome '. $genome_row->feature_id .': '. $genome_row->uniquename. "\n";

	my @secondary_accessions = $genome_row->feature_dbxrefs;
	foreach my $sa (@secondary_accessions) {
		my $secondary_id = join('.',$sa->dbxref->db->name,$sa->dbxref->accession,$sa->dbxref->version);
		print "\t", 'SecondaryID: '.$secondary_id,"\n";
	}
}

# Challenge #1, try to only fetch Secondary IDs that are from the BioProject DB.
