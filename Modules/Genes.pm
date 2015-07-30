#!/usr/bin/env perl

=pod

=head1 NAME

Modules::Genes

=head1 DESCRIPTION

For display of Virulence factors, AMR genes and Stx typing data

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Akiff Manji (akiff.manji@gmail.com)
Matthew Whiteside (matthew.whiteside@phac-aspc.gov.ca)

=cut

package Modules::Genes;

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
use JSON;
use Data::Dump qw(dump);

sub setup {
	my $self=shift;
	
	get_logger->debug('CGI::Application Genes.pm')

}

=head2 stx

Summary of stx subtypes across genomes

=cut

sub stx : Runmode {
	my $self = shift;
	
	# Params
	my $query = $self->query();
	
	my @genomes = $query->param("genome");

	# Data object
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);
	
	# User
	my $user = $self->authen->username;
	
	# Obtain reference typing sequence
	my @subunits;
	foreach my $uniquename (qw/stx1_subunit stx2_subunit/) {
		my $refseq = $self->dbixSchema->resultset('Feature')->find(
		{
			uniquename => $uniquename
		}
		);
		my $ref_id = $refseq->feature_id;
		push @subunits, $ref_id;
	}
	
	# Validate genomes
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
	my $template = $self->load_tmpl('genes_stx.tmpl' , die_on_bad_params => 0);
	
	# Retrieve presence / absence
	my $results = _genomeStx($data, \@subunits, $warden);
	
	my $stx = $results->{stx};
	my $stx_json = encode_json($stx);
	$template->param(stx_json => $stx_json);
	
	# Only need to display subset of all genomes
	if(@genomes) {
		my $genome_list = $warden->genomeList();
		my $gl_json = encode_json($genome_list);
		$template->param(genomes_json => $gl_json);
	}
	
	# Retrieve meta info
	my ($pub_json, $pvt_json) = $data->genomeInfo($user);
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;
	
	# Trees / MSA for each subunit
	my $stx_names = $results->{names};
	
	foreach my $ref_id (@subunits) {
		my $key = $stx_names->{$ref_id};
		my $num_alleles = $results->{counts}->{$key};
		
		# Retrieve tree
		if($num_alleles > 2) {
			my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
			my $tree_string = $tree->geneTree($ref_id, 1, $warden->genomeLookup());
			my $param = "$key\_tree";
			$template->param($param => $tree_string);
		}
		
		# Retrieve MSA
		if($num_alleles > 1) {
			my $is_typing = 1;
			my $msa = $data->seqAlignment(
				locus => $ref_id, 
				warden => $warden,
				typing => $is_typing
				);
			if($msa) {
				my $param = "$key\_msa";
				my $msa_json = encode_json($msa);
				$template->param($param => $msa_json);
			}
		}
		
	}
	
	# Title
	$template->param(title1 => 'SHIGA-TOXIN');
	$template->param(title2 => 'SUBTYPE');
	
	return $template->output();
}

=head2 _genomeStx

Obtain genome feature IDs and subtype
for genomes that contain an Stx typing sequence.

=cut

sub _genomeStx {
	my $fdg         = shift;
	my $subunit_ids = shift;
	my $warden      = shift;
	
	my %args;
	$args{warden} = $warden;
	$args{markers} = $subunit_ids;
	
	my $result_hash = $fdg->getStxData(%args);

	# List format
	my %stx_lists;
	my %stx_counts;
	my $stx_hash = $result_hash->{stx};
	my $stx_names = $result_hash->{names};
	
	foreach my $g (keys %$stx_hash) {
		
		foreach my $r_id (@$subunit_ids) {
			
			my $subu = $stx_names->{$r_id};
			my $num = 0;
			my %allele_data;

			if(defined($stx_hash->{$g})) {
				# genome has some subtypes
				if(defined($stx_hash->{$g}->{$r_id})) {
					# genome has subtype for this ref gene
					my $copy = 1;
					
					foreach my $hr (sort @{$stx_hash->{$g}->{$r_id}}) {
						
						my $st = $hr->{subtype};
						if($st eq 'multiple') {
							$st = 'multiple subtypes predicted'
							} else {
								$st = "Stx".$st;
							}

							my $al = $hr->{allele};
							$allele_data{allele} = $al;
							$allele_data{copy} = $copy;
							$allele_data{data} = $st;
							$stx_lists{$subu}->{$g}->{$al} = \%allele_data;

							$copy++;
						}

						$num += $copy;
					}
				}

				$stx_counts{$subu} += $num;
			}
		}
		
		return {stx => \%stx_lists, counts => \%stx_counts, names => $stx_names};
	}

=head2 matrix

Display a cardinality matrix for a set of 
selected genes/genomes

=cut

sub matrix : Runmode {
	my $self = shift;
	
	# Params
	my $query = $self->query();
	my @genomes = $query->param("genome");
	my @genes = $query->param("gene");

	# Data object
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);
	
	# User
	my $user = $self->authen->username;
	
	# Validate genomes
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
	my $template = $self->load_tmpl('genes_matrix.tmpl' , die_on_bad_params => 0);
	
	# Retrieve presence / absence of alleles for query genes
	my %args = (
		warden => $warden
		);
	
	print STDERR "GENE ids:\n";

	print STDERR "$_\n" foreach (@genes);

	if(@genes) {
		$args{markers} = \@genes
	}
	
	my $results = $data->getGeneAlleleData(%args);
	
	my $gene_list = $results->{genes};
	my $gene_json = encode_json($gene_list);
	$template->param(gene_json => $gene_json);
	
	my $alleles = $results->{alleles};
	my $allele_json = encode_json($alleles);
	$template->param(allele_json => $allele_json);
	
	if(@genomes) {
		my $genome_list = $warden->genomeList();
		my $gl_json = encode_json($genome_list);
		$template->param(genome_json => $gl_json);
	}
	
	# Retrieve genome meta info
	my ($pub_json, $pvt_json) = $data->genomeInfo($user);
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;
	
	# Retrieve genome tree
	my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
	my $tree_string;
	if($warden->hasPersonal) {
		$tree_string = $tree->fullTree($warden->genomeLookup());
		} else {
			$tree_string = $tree->fullTree();
		}
		$template->param(tree_json => $tree_string);
		get_logger->debug('halt4');

		$template->param(title1 => 'VIRULENCE &amp; AMR');
		$template->param(title2 => 'RESULTS');

		#my $user_groups = $self->_getUserGroups();
		my $user_groups = $data->userGroups($user);
		$template->param(username => $user);
		$template->param(user_groups => $user_groups);
		
		return $template->output();
	}

=head2 search

Search for VF/AMR matrix

=cut

sub search : StartRunmode {
	my $self = shift;
	
	# Data object
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);
	
	# User
	my $user = $self->authen->username;
	
	# Genomes
	my $warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, user => $user, cvmemory => $self->cvmemory);

	# Template
	my $template = $self->load_tmpl('genes_search.tmpl' , die_on_bad_params => 0);
	
	# Genome meta info
	my ($pub_json, $pvt_json) = $data->genomeInfo($user);
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;
	
	# Genome tree
	my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
	my $tree_string;
	if($warden->hasPersonal) {
		$tree_string = $tree->fullTree($warden->genomeLookup());
		} else {
			$tree_string = $tree->fullTree();
		}
		$template->param(tree_json => $tree_string);

	# AMR/VF Lists
	my $vfRef = $data->getVirulenceFormData();
	my $amrRef = $data->getAmrFormData();

	# AMR/VF categores
	my $categoriesRef;
	($categoriesRef, $vfRef, $amrRef) = $data->categories($vfRef, $amrRef);
	$template->param(categories => $categoriesRef);
	
	$template->param(vf => $vfRef);
	$template->param(amr => $amrRef);
	
	# Title
	$template->param(title1 => 'VIRULENCE &amp; AMR');
	$template->param(title2 => 'GENES');

	# Group
	# TODO: Mark for deletion
	my $group_json = $data->userGroups;
	$template->param(genome_groups => $group_json);

	my $user_groups = $data->userGroups($user);
	$template->param(username => $user);
	$template->param(user_groups => $user_groups);

	return $template->output();
	
}

=head2 search

Search for individual genes

=cut

sub lookup : Runmode {
	my $self = shift;
	
	# Data object
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);
	
	# User
	my $user = $self->authen->username;

	# Template
	my $template = $self->load_tmpl('genes_lookup.tmpl' , die_on_bad_params => 0);
	
	# AMR/VF Lists
	my $vfRef = $data->getVirulenceFormData();
	my $amrRef = $data->getAmrFormData();

	# AMR/VF categories
	my $categoriesRef;
	($categoriesRef, $vfRef, $amrRef) = $data->categories($vfRef, $amrRef);
	$template->param(categories => $categoriesRef);
	
	$template->param(vf => $vfRef);
	$template->param(amr => $amrRef);
	
	# Title
	$template->param(title1 => 'VIRULENCE &amp; AMR');
	$template->param(title2 => 'GENES');
	
	return $template->output();
	
}

=head2 info

=cut

sub info : Runmode {
	my $self = shift;
	
	# Params 
	my $q = $self->query();
	my $qgene;
	my $qtype;
	
	if($q->param('gene')) {
		$qgene = $q->param('gene');
		
		my $type = $self->gene_type($qgene);
		
		if($type eq 'antimicrobial_resistance_gene') {
			$qtype='amr';
			} elsif($type eq 'virulence_factor') {
				$qtype='vf';
				} else {
					croak "Error: unrecognized gene type for gene ID $qgene."
				}

				} elsif($q->param('amr')) {
					$qtype='amr';
					$qgene = $q->param('amr');
					} elsif($q->param('vf')) {
						$qtype='vf';
						$qgene = $q->param('vf');
					}
					my @genomes = $q->param("genome");

					croak "Error: no query gene parameter." unless $qgene;

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

	# Template
	my $template = $self->load_tmpl('genes_info.tmpl' , die_on_bad_params => 0);
	
	$template->param(gene_id => $qgene);
	$template->param(gene_type => $qtype);
	
	
	# Gene information
	my $qgene_json;
	my $gene_name;
	my @accessions;
	my $is_amr;
	if($qtype eq 'amr') {
		my $qgene_info = $self->amr_info($qgene);
		$template->param(gene_synonyms => join(', ', @{$qgene_info->{synonyms}}));
		
		$gene_name = $qgene_info->{name};
		map { push @accessions, {accession => $_} } @{$qgene_info->{accessions}};
		$is_amr = 1;
		
		} elsif($qtype eq 'vf') {
			my $qgene_info = $self->vf_info($qgene);
			$template->param(gene_strain => join(', ', @{$qgene_info->{strain}}));
			$template->param(gene_plasmid => join(', ', @{$qgene_info->{plasmid}}));

			$gene_name = $qgene_info->{name};
			map { push @accessions, {accession => $_} } @{$qgene_info->{vir_id}};
			$is_amr = 0;
			} else {
				croak "Error: unknown query gene type $qtype."
			}

			$template->param(is_amr => $is_amr);
			$template->param(gene_name => $gene_name);
			$template->param(gene_accessions => \@accessions) if @accessions;


			my $category_json = $self->gene_category($qtype, $qgene);
			$template->param(category_json => $category_json);

	# Alleles
	my $result_hash = _genomeAlleles($data, [$qgene], $warden);
	
	my $allele_json = encode_json($result_hash->{alleles}->{$qgene});
	$template->param(allele_json => $allele_json);
	
	my $num_alleles = $result_hash->{counts}->{$qgene};
	
	get_logger->debug('Number of alleles found:'.$num_alleles);
	$template->param(allele_num => $num_alleles);
	
	# Retrieve tree
	# GENE TREES BROKEN - need to reload to remove tmp IDs like upl_4
	# TODO: Comment out later
	if($num_alleles > 2) {
		my $public = 1;
		my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
		my $tree_string = $tree->geneTree($qgene, $public, $warden->genomeLookup());
		$template->param(tree_json => $tree_string);
	}
	
	# Retrieve MSA
	# TODO: Comment out later
	if($num_alleles > 1) {
		get_logger->debug('attempt made for alignment');
		my $is_typing = 0;
		my $msa = $data->seqAlignment(
			locus => $qgene, 
			warden => $warden,
			typing => $is_typing
			);
		if($msa) {
			my $msa_json = encode_json($msa);
			$template->param(msa_json => $msa_json);
			} else {
				get_logger->debug('got nothing');
			}
		}

	# Retrieve meta info
	my ($pub_json, $pvt_json) = $data->genomeInfo($user);
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;
	
	# Title
	if($qtype eq 'vf') {
		$template->param(title1 => 'VIRULENCE GENE');
		} else {
			$template->param(title1 => 'AMR GENE');
		}
		$template->param(title2 => 'INFO');


		return $template->output();
	}

=head2 amr_info

=cut
sub amr_info : Runmode {
	my $self = shift;
	my $gene_id = shift;
	

	my $feature_rs = $self->dbixSchema->resultset('Feature')->search(
	{
		'me.feature_id' => $gene_id
		},
		{
			join => [
			'type',
			{ featureprops => 'type' },
			{ feature_cvterms => { cvterm => 'dbxref'}}
			]
		}
		);

	my $frow = $feature_rs->first;
	die "Error: feature $gene_id is not of antimicrobial resistance gene type (feature type: ".$frow->type->name.").\n" unless $frow->type->name eq 'antimicrobial_resistance_gene';

	my @desc;
	my @syn;
	my @aro;
	
	my $fp_rs = $frow->featureprops;
	
	while(my $fprow = $fp_rs->next) {
		if($fprow->type->name eq 'description') {
			push @desc, $fprow->value;
			} elsif($fprow->type->name eq 'synonym') {
				push @syn, $fprow->value;
			}
		}

		my $fc_rs = $frow->feature_cvterms;

#	while(my $fcrow = $fc_rs->next) {
#		my $aro_entry = {
#			accession => 'ARO:'.$fcrow->cvterm->dbxref->accession,
#			term_name => $fcrow->cvterm->name,
#			term_defn => $fcrow->cvterm->definition
#		};
#		push @aro, $aro_entry;
#	}
while(my $fcrow = $fc_rs->next) {
	push @aro, 'ARO:'.$fcrow->cvterm->dbxref->accession;
}


my %data_hash = (
	name          => $frow->uniquename,
	synonyms      => \@syn,
	accessions    => \@aro
	);

return \%data_hash;
}

=head2 vf_info

=cut
sub vf_info : Runmode {
	my $self = shift;
	my $gene_id = shift;
	
	my $feature_rs = $self->dbixSchema->resultset('Feature')->search(
	{
		'me.feature_id' => $gene_id
		},
		{
			join => [
			'type',
			{ featureprops => 'type' },
			],
		}
		);
	
	my $frow = $feature_rs->first;
	die "Error: feature $gene_id is not of virulence factor gene type (feature type: ".$frow->type->name.").\n" unless $frow->type->name eq 'virulence_factor';

	my @desc;
	my @keyw;
	my @plasmid;
	my @strain;
	my @virid;
	my @molec;
	my @org;
	
	my $fp_rs = $frow->featureprops;
	
	while(my $fprow = $fp_rs->next) {
		if ($fprow->type->name eq "description") {
			push @desc, $fprow->value;
			} elsif($fprow->type->name eq "keywords") {
				push @keyw, $fprow->value;
				} elsif($fprow->type->name eq "mol_type") {
					push @molec, $fprow->value;
					} elsif($fprow->type->name eq "organism") {
						push @org, $fprow->value;
						} elsif($fprow->type->name eq "plasmid") {
							push @plasmid, $fprow->value unless $fprow->value eq 'none'
							} elsif($fprow->type->name eq "strain") {
								push @strain, $fprow->value;
								} elsif($fprow->type->name eq "virulence_id") {
									push @virid, $fprow->value;
									} else {
										get_logger->debug('Unused VF featureprop:'.$fprow->type->name.'='.$fprow->value)
									}
								}

								my %data_hash = (
									uniquename => $frow->uniquename,
									name => $frow->name,
									description  => \@desc,
									keyword => \@keyw,
									plasmid => \@plasmid,
									strain => \@strain,
									vir_id => \@virid,
									mol_type => \@molec,
									organism => \@org 
									);

								return \%data_hash

							}

=head2 _genomeAlleles

Obtain genome and allele feature IDs
for genomes that have gene copy

=cut

sub _genomeAlleles {
	my $fdg         = shift;
	my $gene_ids   = shift;
	my $warden      = shift;
	
	my %args;
	$args{warden} = $warden;
	$args{markers} = $gene_ids;
	
	my $result_hash = $fdg->getGeneAlleleData(%args);
	
	# List format
	my %gene_lists;
	my %gene_counts;
	my $gene_hash = $result_hash->{alleles};
	my $gene_names = $result_hash->{names};
	
	foreach my $g (@{$warden->genomeList}) {
		
		foreach my $r_id (@$gene_ids) {
			
			my $num = 0;
			my %allele_data;

			if(defined($gene_hash->{$g}) && defined($gene_hash->{$g}->{$r_id})) {
				# genome has alleles this ref gene
				
				my $copy = 0;
				foreach my $al (sort @{$gene_hash->{$g}->{$r_id}}) {
					
					++$copy;
					$allele_data{copy} = $copy;
					$gene_lists{$r_id}->{$g}->{$al} = \%allele_data;
					
				}
				
				$num += $copy;
				
			}
			
			$gene_lists{$r_id}->{$g}->{num_copies} = $num;
			$gene_counts{$r_id} += $num;
		}
	}

	return {alleles => \%gene_lists, counts => \%gene_counts, names => $gene_names};
}


=head2 gene_category

Obtain category/subcategory for a specific gene


=cut
sub gene_category {
	my $self = shift;
	my $gtype = shift;
	my $gene_id = shift;
	
	my $table = 'AmrCategory';
	$table = 'VfCategory' unless $gtype eq 'amr';
	
	my $cat_rs = $self->dbixSchema->resultset($table)->search(
	{
		'feature_id' => $gene_id
		},
		{
			prefetch => [qw(parent_category gene_cvterm category)]
		}
		);
	
	my $category_row = $cat_rs->first;
	
	my $parent_category = {
		name => $category_row->parent_category->name,
		definition => $category_row->parent_category->definition,
		id => $category_row->parent_category->cvterm_id,
	};
	
	my $category = {
		name => $category_row->category->name,
		definition => $category_row->category->definition,
		id => $category_row->category->cvterm_id,
	};
	
	my $gene_anno = {
		name => $category_row->gene_cvterm->name,
		definition => $category_row->gene_cvterm->definition,
		id => $category_row->feature_id,
	};
	
	my %hierarchy = (
		top => $parent_category,
		category => $category,
		gene => $gene_anno
		);

	my $category_json = encode_json(\%hierarchy);
	return $category_json;
}

=head2 gene_type

=cut
sub gene_type {
	my $self = shift;
	my $gene_id = shift;
	

	my $feature_rs = $self->dbixSchema->resultset('Feature')->search(
	{
		'me.feature_id' => $gene_id
		},
		{
			join => [
			'type',
			],
			select => [qw/type.name/],
			as => [qw/gene_type/]
		}
		);
	
	if (my $gene_row = $feature_rs->first) {
		return $gene_row->get_column('gene_type')
		} else {
			return 0
		}

	}

=head2 sequences

Return all sequences for copies of a gene in JSON object.
Called in AJAX request

=cut

sub sequences : Runmode {
	my $self = shift;
	
	# Params 
	my $q = $self->query();
	my $qgene;
	
	if($q->param('gene')) {
		$qgene = $q->param('gene');
	}
	
	my @genomes = $q->param("genome");

	croak "Error: no query gene parameter." unless $qgene;
	
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
		locus => $qgene, 
		warden => $warden,
		typing => $is_typing
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

sub _getUserGroups {
	my $self = shift;
	my $username = $self->authen->username;

	return encode_json({status => "Please <a href=\'\/superphy\/user\/login\'>sign in<\/a> to view your saved groups"}) unless $username;

	my $userGroupsRs = $self->dbixSchema->resultset('UserGroup')->find({username => $username});

	return encode_json({status => "You haven't created any groups yet. Create some groups <a href=\'\/superphy\/groups\/shiny\'>here<\/a>."})  unless $userGroupsRs;

	my $userGroupsJson = $userGroupsRs->user_groups;
	my $user_groups_json = $userGroupsJson;

	return $user_groups_json;
}

1;
