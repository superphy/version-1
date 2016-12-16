#!/usr/bin/env perl

=pod

=head1 NAME

Roles::CVMemory

=head1 DESCRIPTION

Stores commonly used cvterm IDs to remove need to repeatedly 
query individual cvterm IDs by name.

All cvterm IDs are queried once and stored in a serialized format
that is loaded into memory once.

Roles::CVMemory seamlessly integrates into L<CGI::Application>
modules by providing a L<Modules::CVMemory> object that is accessible from anywhere in
the application.

Lazy loading is used, that is, the CVMemory object is initialized until it is actually needed.
Also, the object will act as a singleton by always returning the same object for the duration 
of the request. Think of it as a plugin module that adds a couple of new methods directly into 
the CGI::Application namespace simply by loading the module.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.ca)

=cut

package Roles::CVMemory;

use strict;
use warnings;
use Role::Tiny;
use Carp;
use FindBin;
use Data::Dumper;

=head2 cvmemory

If term name is provided as argument, returns ID 
of cvterm or undef

If no argument is provided, returns hashref of all
cvterm IDs.
	
Lazy loading approach means that the cvterm_id hash
will be loaded into memory if it has not been loaded
previously

=cut

sub cvmemory {
	my $self = shift;
	my $term = shift;
	
	unless($self->{__CVMEMORY__}) {
		# Retrieve cvterm hash from DB
		$self->{__CVMEMORY__} = $self->_retrieve();
	}
	
	if($term) {
		if(my $id = $self->{__CVMEMORY__}->{$term}) {
			return $id;
		} else {
			croak "Error: unknown cvterm '$term'."
		}
	} else {
		return $self->{__CVMEMORY__};
	}
	
}

# Retrieves Data::Dumper serialized cvterm hash from
# meta table. Inserts if needed
sub _retrieve {
	my $self = shift;
	
	my $serialized_row = $self->dbixSchema->resultset('Meta')->find(
		{
			'name' => 'cvmemory',
		},
		{
			columns => ['data_string'],
			key => 'meta_c1'
		}
	);
	
	my $cvmemory;
	if($serialized_row) {
		# Retrieve entry
		# Load into $cvmemory variable
		eval $serialized_row->data_string;
		croak "Error: invalid cvmemory data string." unless $cvmemory;
		
	} else {
		# Create entry
		$cvmemory = $self->_insert();
	}
	
	return $cvmemory;
}


# Inserts cvterm hash as Data::Dumper serialized object
# into meta table
sub _insert {
	my $self = shift;
	
	my %cvterms = (
		'contig_collection' => 'sequence',
		'contig' => 'sequence',
		'allele' => 'sequence',
		'experimental_feature' => 'sequence',
		'sequence_variant' => 'sequence',
		'locus' => 'local',
		'pangenome' => 'local',
		'core_genome' => 'local',
		'typing_sequence' => 'local',
		'fusion_of' => 'local',
		'variant_of' => 'sequence',
		'allele_fusion' => 'local',
		'part_of' => 'relationship',
		'similar_to' => 'sequence',
		'derives_from' => 'relationship',
		'contained_in' => 'relationship',
		'located_in' => 'relationship',
		'copy_number_increase' => 'sequence',
		'match' => 'sequence',
		'panseq_function' => 'local',
		'stx1_subtype' => 'local',
		'stx2_subtype' => 'local',
		mol_type => 'feature_property',
		keywords => 'feature_property',
		description => 'feature_property',
		owner => 'feature_property',
		finished => 'feature_property',
		strain => 'local',
		serotype => 'local',
		isolation_host => 'local',
		isolation_location => 'local',
		isolation_date => 'local',
		synonym => 'feature_property',
		comment => 'feature_property',
		isolation_source => 'local',
		isolation_age => 'local',
		isolation_latlng => 'local',
		syndrome => 'local',
		pmid => 'local',
		'antimicrobial_resistance_gene' => 'local',
		'virulence_factor' => 'local',
		'reference_pangenome_alignment' => 'local',
		'aligned_sequence_of' => 'local'
	);
	
	my $cvmemory;

	# Get cvterm_ids
	foreach my $term (keys %cvterms) {
		my $ont = $cvterms{$term};
		my $type_row = $self->dbixSchema->resultset('Cvterm')->find(
			{
				'me.name' => $term,
				'cv.name' => $ont
			},
			{
				join => [qw/cv/],
				columns => ['cvterm_id', 'name']
		    }
		);
		
		
		if($type_row) {
			$cvmemory->{$type_row->name} = $type_row->cvterm_id;
		} else {
			croak "Error: Cvterm $term in ontology $ont not found."
		}
	}
	
	# Serialize
	$Data::Dumper::Indent = 0;
	my $data_string = Data::Dumper->Dump([$cvmemory], ['cvmemory']);
	
	# Insert into DB
	$self->dbixSchema->resultset('Meta')->update_or_create(
		{
			'name' => 'cvmemory',
			'format' => 'perl',
			'data_string' => $data_string
		},
		{
			key => 'meta_c1'
		}
	);
	
	return $cvmemory;
	
}


1;