#!/usr/bin/env perl

package Modules::DisplayTest;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use parent 'CGI::Application';
#use Role::Tiny::With;
#use Phylogeny::PhyloTreeBuilder;
use Modules::FastaFileWrite;
#with 'Roles::DatabaseConnector';

sub setup{
	my $self = shift;
	$self->start_mode('hello');
	# <reference name> => <sub name>
	$self->run_modes( 'hello'=>'hello');

}

###############
###Run Modes###
###############

#This will display the home page. Need to set the parameters for the templates so that they get loaded into browser properly
# sub displayTest {
# 	my $self = shift;

# 	#Returns an object with column data
# 	my $features = $self->_getFormData();

# 	#Each row of column data is stored into a hash table. A reference to each hash table row is stored in an array.
# 	#Returns a reference to an array with references to each row of data in the hash table
# 	my $formFeatureRef = $self->_hashFormData($features);

# 	my $template = $self->load_tmpl( 'display_test.tmpl' , die_on_bad_params=>0 );
# 	$template->param(FEATURES=>$formFeatureRef);	
# 	return $template->output();
# }

# if a run mode is not indicated the program will croak(), so we set the default/start mode to this.
sub hello {
	my $self = shift;
	my $template = $self->load_tmpl ( 'hello.tmpl' , die_on_bad_params=>0 );
	return $template->output();
}

###############################
###Form Processing Run Modes###
###############################

# sub singleStrain {
# 	#Ready form data and load template
# 	my $self = shift;
# 	my $features = $self->_getFormData();
# 	my $formFeatureRef = $self->_hashFormData($features);
# 	my $template = $self->load_tmpl ( 'single_strain.tmpl' , die_on_bad_params=>0);

# 	my $q = $self->query();
# 	my $strainName = $q->param("singleStrainName");

# 	if(!defined $strainName || $strainName eq ""){
# 		$template->param(FEATURES=>$formFeatureRef);
# 	}
# 	else {
# 		my $strainFeaturepropTable = $self->dbixSchema->resultset('Featureprop');
# 		my $strainFeatureTable = $self->dbixSchema->resultset('Feature');
# 		my $sSDataRef = $self->_getSingleStrainData($strainName , $strainFeaturepropTable , $strainFeatureTable);

# 		$template->param(FEATURES=>$formFeatureRef);
# 		$template->param(sSMETADATA=>$sSDataRef);
# 		my $ssvalidator = "Return Success";
# 		$template->param(sSVALIDATOR=>$ssvalidator);
# 	}
# 	return $template->output();
# }

# sub multiStrain {
# 	my $self = shift;
# 	my $features = $self->_getFormData();
# 	my $formFeatureRef = $self->_hashFormData($features);
# 	my $template = $self->load_tmpl ( 'multi_strain.tmpl' , die_on_bad_params=>0 );

# 	my $q = $self->query();
# 	my $strainFeaturepropTable = $self->dbixSchema->resultset('Featureprop');
# 	my $strainFeatureTable = $self->dbixSchema->resultset('Feature');
# 	my @groupOneStrainFeatureIds = $q->param("group1");
# 	my @groupTwoStrainFeatureIds = $q->param("group2");

# 	if(!(@groupOneStrainFeatureIds) && !(@groupTwoStrainFeatureIds)) {
# 		$template->param(FEATURES=>$formFeatureRef);
# 	}
# 	else {
# 		my $groupOneDataRef = $self->_getMultiStrainData(\@groupOneStrainFeatureIds, $strainFeaturepropTable, $strainFeatureTable);
# 		my $groupTwoDataRef = $self->_getMultiStrainData(\@groupTwoStrainFeatureIds, $strainFeaturepropTable, $strainFeatureTable);
# 		$template->param(FEATURES=>$formFeatureRef);
# 		#$template->param(mSGPONEFEATURES=>$groupOneDataRef);
# 		#$template->param(mSGPTWOFEATURES=>$groupTwoDataRef);
# 		my $msvalidator = "Return Success";
# 		$template->param(mSVALIDATOR=>$msvalidator);
# 	}
# 	return $template->output();
# }

# sub bioinfoStrainList {

# 	#For now just testing to see if we can display joined data on the website
# 	my $self = shift;
# 	#Returns an object with column data
# 	my $vFactors = $self->_getVFData();
# 	my $features = $self->_getFormData();
# 	my $vFRef = $self->_hashVFData($vFactors);
# 	my $formFeatureRef = $self->_hashFormData($features);
# 	my $template = $self->load_tmpl( 'bioinfo_strain_list.tmpl' , die_on_bad_params=>0 );
# 	$template->param(vFACTORS=>$vFRef);
# 	#$template->param(FEATURES=>$formFeatureRef);
# 	return $template->output();
# }

# sub bioinfoVirulenceFactors {
# 	my $self = shift;
# 	my $vFactors = $self->_getVFData();
# 	my $vFRef = $self->_hashVFData($vFactors);
	
# 	my $q = $self->query();
# 	my $template = $self->load_tmpl( 'bioinfo_virulence_factors.tmpl' , die_on_bad_params=>0 );
# 	my $vfFeatureId = $q->param("VFName");

# 	if (!defined $vfFeatureId || $vfFeatureId eq ""){
# 		$template->param(vFACTORS=>$vFRef);
# 	}
# 	else {
# 		my $vFMetaInfoRef = $self->_getVFMetaInfo($vfFeatureId);
# 		$template->param(vFACTORS=>$vFRef);
# 		my $vfvalidator = "Return Success";
# 		$template->param(vFVALIDATOR=>$vfvalidator);
# 		$template->param(vFMETAINFO=>$vFMetaInfoRef);
# 	}
# 	return $template->output();
# }

# sub bioinfoStatistics {
# 	my $self = shift;
# 	my $vFactors = $self->_getVFData();
# 	my $features = $self->_getFormData();
# 	my $vFRef = $self->_hashVFData($vFactors);
# 	my $formFeatureRef = $self->_hashFormData($features);
# 	my $template = $self->load_tmpl( 'bioinfo_statistics.tmpl' , die_on_bad_params=>0 );
# 	$template->param(vFACTORS=>$vFRef);
# 	$template->param(FEATURES=>$formFeatureRef);
# 	return $template->output();
# }

#######################
###Helper Functions ###
#######################

# sub _getFormData {
# 	my $self = shift;
# 	my $_features = $self->dbixSchema->resultset('Featureprop')->search(
# 	{
# 		name => 'genome_of'
# 		},
# 		{	join => ['type'],
# 		select => [qw/me.value type.name/],
# 		group_by => [qw/me.value type.name/],
# 		order_by 	=> { -asc => ['me.value']}
# 	}
# 	);
# 	return $_features;
# }

# sub _hashFormData {
# 	my $self=shift;
# 	my $features=shift;
# 	my @formData;
# 	while (my $featureRow = $features->next){
# 		my %formRowData;
# 		#$formRowData{'FEATUREID'}=$featureRow->feature_id;
# 		$formRowData{'UNIQUENAME'}=$featureRow->value;
# 		push(@formData, \%formRowData);
# 	}
# 	return \@formData;
# }

# sub _getSingleStrainData {
# 	my $self = shift;
# 	my $singleStrainName = shift;
# 	my $strainFeaturepropTable = shift;
# 	my $strainFeatureTable = shift;
# 	my @singleStrainData;

# 	my $_featureProps = $strainFeaturepropTable->search(
# 		{value => "$singleStrainName"},
# 		{
# 			column => [qw/me.feature_id/],
# 			order_by => {-asc => ['me.feature_id']}
# 		}
# 		);

# 	while (my $_featurepropsRow = $_featureProps->next) {
# 		my %singleRowData;
# 		$singleRowData{'FEATUREID'}=$_featurepropsRow->feature_id;
# 		push(@singleStrainData, \%singleRowData);
# 		#get all the meta info for that particular feature id and hash it
# 	}
# 	return \@singleStrainData;;

# }

# sub _getMultiStrainData {
# 	my $self = shift;
# 	my $strainFeatureNames = shift;
# 	my $strainFeaturepropTable = shift;
# 	my $strainFeatureTable = shift;
# 	my @multiNestedRowLoop;

# 	#Need to make a copy of the dereferenced array into a new list since $ffwhandle will modify the names in the list.
# 	push (my @strainNames , @{$strainFeatureNames}); 

# 	my $ffwHandle = Modules::FastaFileWrite->new();
# 	$ffwHandle->dbixSchema($self->dbixSchema);
# 	$ffwHandle->writeStrainsToFile(\@strainNames);

# 	# foreach my $multiStrainName (@{$strainFeatureNames}) {
		
# 	# 	my $_featureProps = $strainFeaturepropTable->search(
# 	# 		{value => "$multiStrainName"},
# 	# 		{
# 	# 			column => [qw/me.feature_id/],
# 	# 			order_by => {-asc => ['me.feature_id']}
# 	# 		}
# 	# 		);

# 	# 	while (my $_featurepropsRow = $_featureProps->next){
# 	# 		my %multiRowData;
# 	# 		my $_rowFeaturedId = $_featurepropsRow->feature_id;
# 	# 		my $_rowFeatures = $strainFeatureTable->find({feature_id => $_rowFeaturedId});
# 	# 		$multiRowData{'FEATUREID'}=$_featurepropsRow->feature_id;
# 	# 		$multiRowData{'UNIQUENAME'}=$_rowFeatures->uniquename;
# 	# 		push (@multiNestedRowLoop, \%multiRowData);
# 	# 	}
# 	# }
# 	# return \@multiNestedRowLoop;
# }

# sub _getVFData {
# 	my $self = shift;
# 	my $_virulenceFactorProperties = $self->dbixSchema->resultset('Featureprop')->search(
# 		{value => 'Virulence Factor'},
# 		{
# 			join		=> ['type', 'feature'],
# 			select		=> [ qw/me.feature_id me.type_id me.value type.cvterm_id type.name feature.uniquename/],
# 			as 			=> ['feature_id', 'type_id' , 'value' , 'cvterm_id', 'term_name' , 'uniquename'],
# 			group_by 	=> [ qw/me.feature_id me.type_id me.value type.cvterm_id type.name feature.uniquename/ ],
# 			order_by 	=> { -asc => ['uniquename'] }
# 		}
# 		);

# 	return $_virulenceFactorProperties;
# }

#Inputs all column data into a hash table and returns a reference to the hash table.
#Note: the Cvterms must be defined when up-loading sequences to the database otherwise you'll get a NULL exception and the page wont load.
#	i.e. You cannot just upload sequences into the db just into the Feature table without having any terms defined in the Featureprop table.
#	i.e. Fasta files must have attributes tagged to them before uploading.
# sub _hashVFData {
# 	my $self=shift;
# 	my $_vFactors=shift;
	
# 	#Initialize an array to hold the loop
# 	my @vFData;
	
# 	while (my $vFRow = $_vFactors->next){
# 		#Initialize a hash structure to store column data in.
# 		my %vFRowData;
# 		$vFRowData{'FEATUREID'}=$vFRow->feature_id;
# 		$vFRowData{'UNIQUENAME'}=$vFRow->feature->uniquename;
# 		push(@vFData, \%vFRowData);
# 	}
# 	#return a reference to the loop array
# 	return \@vFData;
# }

# sub _getVFMetaInfo {
# 	my $self = shift;
# 	my $_vFFeatureId = shift;

# 	my @vFMetaData;

# 	my $_virulenceFactorMetaProperties = $self->dbixSchema->resultset('Featureprop')->search(
# 		{'me.feature_id' => $_vFFeatureId},
# 		{
# 			join		=> ['type' , 'feature'],
# 			select		=> [ qw/feature_id me.type_id me.value type.cvterm_id type.name feature.uniquename/],
# 			as 			=> ['me.feature_id', 'type_id' , 'value' , 'cvterm_id', 'term_name' , 'uniquename'],
# 			group_by 	=> [ qw/me.feature_id me.type_id me.value type.cvterm_id type.name feature.uniquename/ ],
# 			order_by	=> { -asc => ['type.name'] }
# 		}
# 		);

# 	while (my $vFMetaRow = $_virulenceFactorMetaProperties->next){
# 		#Initialize a hash structure to store column data
# 		my %vFMetaRowData;
# 		$vFMetaRowData{'vFFEATUREID'}=$vFMetaRow->feature_id;
# 		$vFMetaRowData{'vFUNIQUENAME'}=$vFMetaRow->feature->uniquename;
# 		$vFMetaRowData{'vFTERMVALUE'}=$vFMetaRow->value;
# 		if ($vFMetaRow->type->name eq "description") {
# 			$vFMetaRowData{'vFTERMNAME'}="Description";
# 		}
# 		elsif ($vFMetaRow->type->name eq "keywords"){
# 			$vFMetaRowData{'vFTERMNAME'}="Keyword";
# 		}
# 		elsif ($vFMetaRow->type->name eq "mol_type"){
# 			$vFMetaRowData{'vFTERMNAME'}="Molecular Type";
# 		}
# 		elsif ($vFMetaRow->type->name eq "name"){
# 			$vFMetaRowData{'vFTERMNAME'}="Factor Name";
# 		}
# 		elsif ($vFMetaRow->type->name eq "organism"){
# 			$vFMetaRowData{'vFTERMNAME'}="Organism";
# 		}
# 		elsif ($vFMetaRow->type->name eq "plasmid"){
# 			$vFMetaRowData{'vFTERMNAME'}="Plasmid name";
# 		}
# 		elsif ($vFMetaRow->type->name eq "strain"){
# 			$vFMetaRowData{'vFTERMNAME'}="Strain";
# 		}
# 		elsif ($vFMetaRow->type->name eq "uniquename"){
# 			$vFMetaRowData{'vFTERMNAME'}="Unique Name";
# 		}
# 		else {
# 			$vFMetaRowData{'vFTERMNAME'}=$vFMetaRow->type->name;
# 		}
# 		push(@vFMetaData, \%vFMetaRowData);
# 	}
# 	return \@vFMetaData;
# }

1;