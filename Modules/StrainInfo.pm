#!/usr/bin/env perl

=pod

=head1 NAME

Modules::StrainInfo

=head1 SNYNOPSIS

=head1 DESCRIPTION

=head1 ACKNOWLEDGMENTS

Thank you to Dr. Chad Laing and Dr. Matthew Whiteside, for all their assistance on this project

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AVAILABILITY

The most recent version of the code may be found at:

=head1 AUTHOR

Akiff Manji (akiff.manji@gmail.com)

=head1 Methods

=cut

package Modules::StrainInfo;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Modules::FormDataGenerator;
use HTML::Template::HashWrapper;
use CGI::Application::Plugin::AutoRunmode;
use Log::Log4perl qw/get_logger/;
use Sequences::GenodoDateTime;
use Phylogeny::Tree;
use Modules::TreeManipulator;
use IO::File;
use JSON;

# Featureprops
# hash: name => cv
my %fp_types = (
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
	pmid     => 'local',
);

# In addition to the meta-data in the featureprops table
# Also have external accessions (i.e. NCBI genbank ID) 
# found in the feature.dbxref_id column (primary) and
# the feature_dbxref table (secondary)


=head2 setup

Defines the start and run modes for CGI::Application and connects to the database.

=cut

sub setup {
	my $self=shift;
	my $logger = Log::Log4perl->get_logger();
	$logger->info("Logger initialized in Modules::StrainInfo");
}

=head2 strain_info

Run mode for the single strain page

=cut

sub strain_info : StartRunmode {
	my $self = shift;
	
	my $formDataGenerator = Modules::FormDataGenerator->new();
	$formDataGenerator->dbixSchema($self->dbixSchema);
	
	my $username = $self->authen->username;
	
	# Retrieve form data
	my ($pub_json, $pvt_json) = $formDataGenerator->genomeInfo($username);
	
	# Check if user is requesting genome info
	my $q = $self->query();
	
	# Need to replace these param checks with a single genome request.
	my $strainID;
	my $privateStrainID;
	my $feature = $q->param("genome");
	if($feature && $feature ne "") {
		if($feature =~ m/^public_(\d+)/) {
			$strainID = $1;
		} elsif($feature =~ m/^private_(\d+)/) {
			$privateStrainID = $1;
		} else {
			die "Error: invalid genome ID: $feature.";
		}
	}
	
	my $template;
	if(defined $strainID && $strainID ne "") {
		# User requested information on public strain
		
		my $strainInfoRef = $self->_getStrainInfo($strainID, 1);
		
		$template = $self->load_tmpl( 'strain_info.tmpl' ,
			associate => HTML::Template::HashWrapper->new( $strainInfoRef ),
			die_on_bad_params=>0 );
		$template->param('strainData' => 1);
		
		# Get phylogenetic tree
		my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
		$template->param(tree_json => $tree->nodeTree($feature));
		
		# Get Virulence and AMR genes for genome
		my $result_hashref = $formDataGenerator->getGeneAlleleData(public_genomes => [$strainID]);
		my $vf = $result_hashref->{vf};
		my $amr = $result_hashref->{amr};
		my $names = $result_hashref->{names};
		
		my @virData; my @amrData;
		
		foreach my $gene_id (keys %{$amr->{$feature}}) {
			my %virRow;
			$virRow{'gene_name'} = $names->{$gene_id};
			$virRow{'feature_id'} = $gene_id;
			foreach my $allele_id (@{$amr->{$feature}->{$gene_id}}) {
				$virRow{'allele_count'}++
			}
			push (@amrData, \%virRow);
		}
		
		foreach my $gene_id (keys %{$vf->{$feature}}) {
			my %virRow;
			$virRow{'gene_name'} = $names->{$gene_id};
			$virRow{'feature_id'} = $gene_id;
			foreach my $allele_id (@{$vf->{$feature}->{$gene_id}}) {
				$virRow{'allele_count'}++
			}
			push (@virData, \%virRow);
		}
		
		get_logger->debug("NUMBER OF VF:".scalar(@virData));
		get_logger->debug("NUMBER OF AMR:".scalar(@amrData));
		
		$template->param(VIRDATA=>\@virData);

		$template->param(AMRDATA=>\@amrData);

		# Get loacation data for map
		my $strainLocationDataRef = $self->_getStrainLocation($strainID, 'Featureprop');
		$template->param(LOCATION => $strainLocationDataRef->{'presence'} , strainLocation => 'public_'.$strainID);

	} elsif(defined $privateStrainID && $privateStrainID ne "") {
		# User requested information on private strain
		
		# Retrieve list of private genomes user can view (need full list to mask unviewable nodes in tree)
		my ($visable, $has_private) = $formDataGenerator->privateGenomes($username);
		
		unless(defined($visable->{$feature})) {
			# User requested strain that they do not have permission to view
			$self->session->param( status => '<strong>Permission Denied!</strong> You have not been granted access to uploaded genome ID: '.$privateStrainID );
			return $self->redirect( $self->home_page );
		}
		
		my $privacy_category = $visable->{$feature}->{access};
		my $strainInfoRef = $self->_getStrainInfo($privateStrainID, 0);
		
		$template = $self->load_tmpl( 'strain_info.tmpl' ,
			associate => HTML::Template::HashWrapper->new( $strainInfoRef ),
			die_on_bad_params=>0 );

		$template->param('strainData' => 1);
		$template->param('privateGenome' => 1);
		$template->param('username' => $username);
		
		if($privacy_category eq 'release') {
			$template->param('privacy' => "delayed public release");
		} else {
			$template->param('privacy' => $privacy_category);
		}
		
		# Get phylogenetic tree
		my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
		if($has_private) {
			# Need to use full tree, with non-visable nodes masked
			$formDataGenerator->publicGenomes(undef, $visable);
			$template->param(tree_json => $tree->nodeTree($feature, $visable));
		} else {
			# Can use public tree
			$template->param(tree_json => $tree->nodeTree($feature));
		}
		
		# Get Virulence and AMR genes for genome
		get_logger->debug($privateStrainID);
		my $result_hashref = $formDataGenerator->getGeneAlleleData(private_genomes => [$privateStrainID]);
		
		my $vf = $result_hashref->{vf};
		my $amr = $result_hashref->{amr};
		my $names = $result_hashref->{names};
		
		my @virData; my @amrData;
		
		foreach my $gene_id (keys %{$amr->{$feature}}) {
			my %virRow;
			$virRow{'gene_name'} = $names->{$gene_id};
			$virRow{'feature_id'} = $gene_id;
			foreach my $allele_id (@{$amr->{$feature}->{$gene_id}}) {
				$virRow{'allele_count'}++
			}
			push (@amrData, \%virRow);
		}
		
		foreach my $gene_id (keys %{$vf->{$feature}}) {
			my %virRow;
			$virRow{'gene_name'} = $names->{$gene_id};
			$virRow{'feature_id'} = $gene_id;
			foreach my $allele_id (@{$vf->{$feature}->{$gene_id}}) {
				$virRow{'allele_count'}++
			}
			push (@virData, \%virRow);
		}
		
		get_logger->debug("NUMBER OF VF:".scalar(@virData));
		get_logger->debug("NUMBER OF AMR:".scalar(@amrData));
		
		$template->param(VIRDATA=>\@virData);

		$template->param(AMRDATA=>\@amrData);

		my $strainLocationDataRef = $self->_getStrainLocation($privateStrainID, 'PrivateFeatureprop');
		$template->param(LOCATION => $strainLocationDataRef->{'presence'} , strainLocation => 'private_'.$privateStrainID);

	} else {
		$template = $self->load_tmpl( 'strain_info.tmpl' ,
			die_on_bad_params=>0 );
		$template->param('strainData' => 0);
	}

	# Populate forms
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;

	return $template->output();
}

=head2 search

=cut
sub search : Runmode {
	my $self = shift;
	
	my $fdg = Modules::FormDataGenerator->new();
	$fdg->dbixSchema($self->dbixSchema);
	
	my $username = $self->authen->username;
	my ($pub_json, $pvt_json) = $fdg->genomeInfo($username);
	
	my $template = $self->load_tmpl( 'strain_search.tmpl' , die_on_bad_params => 0);
	
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;
	
	# Phylogenetic tree
	my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
	
	if($self->authen->is_authenticated) {
		# User is logged in
		
		# To get finer control over the genome queries, i do them here and not use the 
		# FormDataGenerator methods
		
		my $genome_rs = $self->dbixSchema()->resultset('PrivateFeature')->search(
			[
				{
					'login.username' => $username,
					'type.name'      => 'contig_collection',
				},
				{
					'upload.category'    => 'public',
					'type.name'      => 'contig_collection',
				},
			],
			{
				columns => [qw/feature_id uniquename/],
				'+columns' => [qw/upload.category login.username/],
				join => [
					{ 'upload' => { 'permissions' => 'login'} },
					'type'
				]
			}
		);
		
		# If the user does not have any private genomes, we do not need to prune tree
		
		if($genome_rs->search({ '-not' => {'upload.category' => 'public' }})->first) {
			# User has access to private genomes
			# Prune tree based on visable genomes
			
			my %visable_nodes;
			
			my $public_genomes = $fdg->publicGenomes();
			
			foreach my $g (@$public_genomes) {
				$visable_nodes{'public_'.$g->{feature_id}} = $g->{uniquename};
			}
			
			$genome_rs->reset;
			
			while (my $g = $genome_rs->next) {
				$visable_nodes{'private_'.$g->feature_id} = $g->uniquename;
			}
			
			my $tree_string = $tree->fullTree(\%visable_nodes);
			
			$template->param(tree_json => $tree_string);

		} else {
			# No private genomes
			# Return public tree
			
			$template->param(tree_json => $tree->fullTree);
		}
		
	} else {
		# Anonymous user
		# Return public tree
		
		$template->param(tree_json => $tree->fullTree);
	}
	
	return $template->output();
	
} 

=head2 _getStrainInfo

Takes in a strain name paramer and queries it against the appropriate table.
Returns an array reference to the strain metainfo.

=cut

sub _getStrainInfo {
	my $self = shift;
	my $strainID = shift;
	my $public = shift;
	
	my $feature_table_name = 'Feature';
	my $featureprop_rel_name = 'featureprops';
	my $dbxref_table_name = "FeatureDbxref";
	my $order_name = 'featureprops.rank';
	
	# Data is in private tables
	unless($public) {
		$feature_table_name = 'PrivateFeature';
		$featureprop_rel_name = 'private_featureprops';
		$dbxref_table_name = "PrivateFeatureDbxref";
		$order_name = 'private_featureprops.rank';
	}

	my $feature_rs = $self->dbixSchema->resultset($feature_table_name)->search(
		{
			"me.feature_id" => $strainID
		},
		{
			prefetch => [
				{ 'dbxref' => 'db' },
				{ $featureprop_rel_name => 'type' },
			],
			order_by => $order_name
		}
	);
	
	# Create hash
	my %feature_hash;
	my $feature = $feature_rs->first;
	
	# Feature data
	$feature_hash{uniquename} = $feature->uniquename;
	if($feature->dbxref) {
		my $version = $feature->dbxref->version;
		$feature_hash{primary_dbxref} = $feature->dbxref->db->name . ': ' . $feature->dbxref->accession;
		$feature_hash{primary_dbxref} .= '.' . $version if $version && $version ne '';
		if($feature->dbxref->db->urlprefix) {
			$feature_hash{primary_dbxref_link} = $feature->dbxref->db->urlprefix . $feature->dbxref->accession;
			$feature_hash{primary_dbxref_link} .= '.' . $version if $version && $version ne '';
		}
	}
	
	# Secondary Dbxrefs
	# Separate query to prevent unwanted join behavior
	my $feature_dbxrefs = $self->dbixSchema->resultset($dbxref_table_name)->search(
		{
			feature_id => $feature->feature_id
		},
		{
			prefetch => {'dbxref' => 'db'},
			order_by => 'db.name'
		}
	);
	
	$feature_hash{secondary_dbxrefs} = [] if $feature_dbxrefs->count;
	while(my $dx = $feature_dbxrefs->next) {
		my $version = $dx->dbxref->version;
		my $dx_hashref = { secondary_dbxref => $dx->dbxref->db->name . ': ' . $dx->dbxref->accession };
		$dx_hashref->{secondary_dbxref} .= '.' . $version if $version && $version ne '';
		if($dx->dbxref->db->urlprefix) {
			$dx_hashref->{secondary_dbxref_link} = $dx->dbxref->db->urlprefix . $dx->dbxref->accession;
			$dx_hashref->{secondary_dbxref_link} .= '.' . $version if $version && $version ne '';
		}
		push @{$feature_hash{secondary_dbxrefs}}, $dx_hashref;
	}
	
	
	# Featureprop data
	my $featureprops = $feature->$featureprop_rel_name;
	
	while(my $fp = $featureprops->next) {
		my $type = $fp->type->name;
		my $plural_types = $type.'s';
		$feature_hash{$plural_types} = [] unless defined $feature_hash{$plural_types};
		push @{$feature_hash{$plural_types}}, { $type => $fp->value };
	}
	
	$feature_hash{references} = 1 if defined($feature_hash{owners}) || defined($feature_hash{pmids});
	
	if(defined($feature_hash{pmids})) {
		my $pmid_list = '"'.join(',', (map {$_->{pmid}} @{$feature_hash{pmids}})).'"';
		#get_logger->debug("<$pmid_list>");
		$feature_hash{pmid_list} = $pmid_list;
		delete $feature_hash{pmids};
	}
	
	# Convert age to proper units
	if(defined $feature_hash{isolation_ages}) {
		foreach my $age_hash (@{$feature_hash{isolation_ages}}) {
			my($age, $unit) = Sequences::GenodoDateTime::ageOut($age_hash->{isolation_age});
			$age_hash->{isolation_age} = "$age $unit";
		}
	}
	
	return(\%feature_hash);
}

=cut
sub _getVirulenceData {
	my $self = shift;
	my $strainID = shift;
	my $virulence_table_name = 'RawVirulenceData';
	my $formDataGenerator = Modules::FormDataGenerator->new();

	my @virulenceData;
	my $virCount = 0;

	my $virulenceData = $self->dbixSchema->resultset($virulence_table_name)->search(
		{'me.genome_id' => 'public_'.$strainID , 'me.presence_absence' => 1},
		{
			join => ['gene'],
			column => [qw/me.strain me.gene_name me.presence_absence gene.uniquename gene.feature_id/]
		}
		);

	while (my $virulenceDataRow = $virulenceData->next) {
		my %virRow;
		$virRow{'gene_name'} = $virulenceDataRow->gene->uniquename;
		$virRow{'feature_id'} = $virulenceDataRow->gene->feature_id;
		push (@virulenceData, \%virRow);
	}
	return \@virulenceData;
}

sub _getAmrData {
	my $self = shift;
	my $strainID = shift;
	my $amr_table_name = 'RawAmrData';
	my $formDataGenerator = Modules::FormDataGenerator->new();

	my @amrData;
	my $amrCount = 0;

	my $amrData = $self->dbixSchema->resultset($amr_table_name)->search(
		{'me.genome_id' => 'public_'.$strainID , 'me.presence_absence' => 1},
		{
			join => ['gene'],
			column => [qw/me.strain me.gene_name me.presence_absence gene.uniquename gene.feature_id/]
		}
		);

	while (my $amrDataRow = $amrData->next) {
		my %amrRow;
		$amrRow{'gene_name'} = $amrDataRow->gene->uniquename;
		$amrRow{'feature_id'} = $amrDataRow->gene->feature_id;
		push (@amrData , \%amrRow);
	}
	return \@amrData;
}
=cut

sub _getStrainLocation {
	my $self = shift;
	my $strainID = shift;
	my $tableName = shift;
	my $locationFeatureProps = $self->dbixSchema->resultset($tableName)->search(
		{'type.name' => 'isolation_location' , 'me.feature_id' => "$strainID"},
		{
			column  => [qw/me.feature_id me.value type.name/],
			join        => ['type']
		}
		);
	my %strainLocation;
	$strainLocation{'presence'} = 0;
	while (my $location = $locationFeatureProps->next) {
		$strainLocation{'presence'} = 1;
		my $locValue = $location->value;
		$strainLocation{'location'} = $locValue;
	}
	return \%strainLocation;
}

1;
