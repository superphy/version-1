#!/usr/bin/env perl

=pod

=head1 NAME

Modules::Pangenomes

=head1 DESCRIPTION

For display of Pangenome segments

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matthew Whiteside (matthew.whiteside@phac-aspc.gov.ca)

=cut

package Modules::Pangenomes;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Modules::FormDataGenerator;
use Modules::GenomeWarden;
use Phylogeny::Tree;
use HTML::Template::HashWrapper;
use CGI::Application::Plugin::AutoRunmode;
use Log::Log4perl qw/get_logger/;
use Carp;
use JSON::MaybeXS;
use Data::Dumper;

sub setup {
	my $self=shift;
	
	get_logger->debug('CGI::Application Pangenomes.pm')

}

=head2 info

=cut

sub info : Runmode {
	my $self = shift;
	
	# Params 
	my $q = $self->query();
	my $region = $q->param('region');
	my @genomes = $q->param("genome");
	croak "Error: no region parameter." unless $region;

	# User
	my $user = $self->authen->username;
	
	# Genomes
	my $warden;
	if(@genomes) {
		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, genomes => \@genomes, user => $user, cvmemory => $self->cvmemory);
		my ($err, $bad1, $bad2) = $warden->error; 
		if($err) {
			# User requested invalid strains or strains that they do not have permission to view
			$self->session->param( status => '<strong>Permission Denied!</strong> You have not been granted access to uploaded genomes: '.join(', ',@$bad1, @$bad2) );
			return $self->redirect( $self->home_page );
		}
		
	} else {
		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, user => $user, cvmemory => $self->cvmemory);
	}

	# Template
	my $template = $self->load_tmpl('pangenomes_info.tmpl' , die_on_bad_params => 0);
	
	$template->param(region_id => $region);
	
	# Region information
	my $feature_rs = $self->dbixSchema->resultset('Feature')->search(
		{
			'me.feature_id' => $region,
			'feature_cvterms.cvterm_id' => $self->cvmemory->{'core_genome'}
		},
		{
			prefetch => ['type', 'feature_cvterms', {'featureprops' => 'type'}]
		}
	);

	my $frow = $feature_rs->first;
	die "Error: feature $region is not of pangenome type (feature type: ".$frow->type->name.").\n" unless $frow->type_id eq $self->cvmemory->{'pangenome'};

	# Conserved status
	my $cvterms_row = $frow->feature_cvterms->first;
	my $in_core = !$cvterms_row->is_not;

	$template->param(conserved => $in_core);

	# Function
	my $fprop_rs = $frow->featureprops;
	while(my $fprop_row = $fprop_rs->next) {
		if($fprop_row->type->name eq 'match') {
			$template->param(blast_hit_id => $fprop_row->value);
		}
		elsif($fprop_row->type->name eq 'panseq_function') {
			$template->param(blast_hit_desc => $fprop_row->value);
		}
	}

	# Alleles
	my $result_hash = $self->_pangenomeHits($region, $warden);
	
	my $allele_json = encode_json($result_hash->{alleles});
	$template->param(allele_json => $allele_json);
	
	my $num_alleles = $result_hash->{total};
	
	get_logger->debug('Number of pangenome hits found:'.$num_alleles);
	$template->param(allele_num => $num_alleles);
	
	# Retrieve tree
	if($num_alleles > 2) {
		my $public = 1;
		my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
		my $tree_string = $tree->geneTree($region, $public, $warden->genomeLookup());
		$template->param(tree_json => $tree_string);
	}
	
	
	# Retrieve meta info
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);
	
	my ($pub_json, $pvt_json) = $data->genomeInfo($user);
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;

	$template->output();
}


=head2 _pangenomeHits

Obtain genome and region feature IDs
for genomes that have pangenome region copy

=cut

sub _pangenomeHits {
	my $self     = shift;
	my $ref_id   = shift;
	my $warden   = shift;

	my %hits;
	my $total = 0;
	my ($public_genomes, $private_genomes) = $warden->featureList();
	
	# Public genomes
	if($warden->numPublic) {
		my $select_stmt = {
			'me.object_id' => $ref_id,
			'me.type_id' => $self->cvmemory->{'derives_from'},
			'feature_relationship_subjects.type_id' => $self->cvmemory->{'part_of'}
		};

		# Subset of public genomes
		if($warden->subset) {
			$select_stmt->{'feature_relationship_subjects.object_id'} = {'-in' => $public_genomes},
		}

		my $public_rs = $self->dbixSchema->resultset('FeatureRelationship')->search(
			$select_stmt,
			{
				prefetch => { 'subject' => 'feature_relationship_subjects'}
			}
		);

		while(my $hit_row = $public_rs->next) {
			my $pg_id = $hit_row->subject->feature_id;
			my $genome_rs = $hit_row->subject->feature_relationship_subjects;

			while(my $genome_row = $genome_rs->next) {
				my $genome = 'public_'.$genome_row->object_id;

				my $curr_copy = $hits{$genome}->{num_copies} || 0; 
				$hits{$genome}->{$pg_id} = { copy => ++$curr_copy };
				$hits{$genome}->{num_copies}++
			}		
		}
	}

	# Private genomes
	if($warden->numPrivate) {

		my $select_stmt = {
			'me.object_id' => $ref_id,
			'me.type_id' => $self->cvmemory->{'derives_from'},
			'private_feature_relationship_subjects.type_id' => $self->cvmemory->{'part_of'},
			'private_feature_relationship_subjects.object_id' => {'-in' => $private_genomes}
		};

		my $private_rs = $self->dbixSchema->resultset('PripubFeatureRelationship')->search(
			$select_stmt,
			{
				prefetch => { 'subject' => 'private_feature_relationship_subjects'}
			}
		);

		while(my $hit_row = $private_rs->next) {
			my $pg_id = $hit_row->subject->feature_id;
			my $genome_rs = $hit_row->subject->private_feature_relationship_subjects;

			while(my $genome_row = $genome_rs->next) {
				my $genome = 'private_'.$genome_row->feature_id;

				my $curr_copy = $hits{$genome}->{num_copies} || 0; 
				$hits{$genome}->{$pg_id} = { copy => ++$curr_copy };
				$hits{$genome}->{num_copies}++
			}		
		}
	}

	foreach my $genome (keys %hits) {
		die "Error: pangenome count value 0 for genome $genome" unless $hits{$genome}->{num_copies};
		$total += $hits{$genome}->{num_copies};
	}

	return {alleles => \%hits, total => $total};
}

=head2 sequences

Return all sequences and positions for copies of a pangenome region in JSON object.
Called in AJAX request

=cut

sub sequences : Runmode {
	my $self = shift;
	
	# Params 
	my $q = $self->query();
	my $region_id = $q->param('region');
	my @genomes = $q->param("genome");

	croak "Error: no region parameter." unless $region_id;
	
	# Data object
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);
	
	# User
	my $user = $self->authen->username;
	
	# Genomes
	my $warden;
	if(@genomes) {
		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, genomes => \@genomes, user => $user, cvmemory => $self->cvmemory);
		my ($err, $bad1, $bad2) = $warden->error; 
		if($err) {
			# User requested invalid strains or strains that they do not have permission to view
			$self->session->param( status => '<strong>Permission Denied!</strong> You have not been granted access to uploaded genomes: '.join(', ',@$bad1, @$bad2) );
			return $self->redirect( $self->home_page );
		}
		
	} else {

		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, user => $user, cvmemory => $self->cvmemory);
	}


	# Retrieve MSA
	my $msa_json;
	get_logger->debug('attempt made for alignment');
	my $is_typing = 0;
	my $msa = $data->seqAlignment(
		locus => $region_id, 
		warden => $warden,
		type => 'pangenome'
	);
	
	if($msa) {
		$msa_json = encode_json($msa);
	} else {
		get_logger->debug('got nothing');
	}

	$self->header_add( 
		-type => 'application/json',
	);

	return $msa_json

}

	

1;
