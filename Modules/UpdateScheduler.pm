#!/usr/bin/env perl

=pod

=head1 NAME

  Modules::UpdateScheduler

=head1 DESCRIPTION

  UpdateScheduler coordinates database updates with the loading pipeline. It stops
  conflicts by preventing database writes while loading pipeline is running.

=head1 AUTHOR

  Matt Whiteside (mawhites@phac-aspc.gc.ca)

=cut

package Modules::UpdateScheduler;

use strict;
use warnings;

use File::Basename;
use lib dirname (__FILE__) . "/../";
use Carp qw/croak carp/;
use Role::Tiny::With;
with 'Roles::DatabaseConnector';
with 'Roles::Hosts';
with 'Roles::CVMemory';
use Data::Dumper;
use Log::Log4perl qw(get_logger);
use IO::CaptureOutput qw(capture_exec);
use Sequences::GenodoDateTime;
use Data::Grouper;

## Globals

# pending_update table step values
my $step = {
	'pending' => 1,
	'running' => 2,
	'completed' => 3,
	'failed' => -1
};

=head2 new

Constructor

=cut

sub new {
	my ($class) = shift;
	
	my $self = {};
	bless( $self, $class );
	
	my %params = @_;

	my $dbix = $params{dbix_schema};
	
	if($dbix) {
		# Use existing connection
		$self->setDbix($dbix);

		if($params{config}) {
			$self->configFile($params{config});
		}
		else {
			get_logger->logdie("Error: missing parameter 'config' to UpdateScheduler::new().  A config filepath is needed ".
				"when the UpdateScheduler class is initialized with an existing DBIx::Schema object");
		}
		
	} 
	else {
		# Parse command-line options
		$self->connectDatabaseCL();
	}

	# valid methods that can be called by pending_update job
	$self->{job_method} = {
		'update_genome_jm' => 1,
	};

	$self->{perl_interpreter} = $^X;
	$self->{root_directory} = dirname (__FILE__) . "/../";

	
	get_logger->debug('Initializing UpdateScheduler object');
	
	return $self;
}

=head2 submit

Submit new job.

Parameters:
1) upload_id - upload table ID
2) login_id - login table ID
3) job_method - name of update method to run
4) job_input - hash-ref containing input to update method

returns 0 on failure or the pending_update_id on success

=cut

sub submit {
	my $self = shift;
	my ($upload_id, $login_id, $job_method, $job_input) = @_;

	get_logger->debug("U: $upload_id, L: $login_id, JM: $job_method\n");
	
	# Validate user has access to upload_id
	my $upload_rs = $self->can_modify($login_id, $upload_id);
	my $upload_row = $upload_rs->first;
	
	unless($upload_row) {
		get_logger->warn("User $login_id does not have access to modify upload $upload_id");
		return(0);
	}
	
	# Validate job method
	unless($self->{job_method}->{$job_method}) {
		get_logger->warn("Not a valid job method $job_method");
		return(0);
	}
	unless($self->can($job_method)) {
		get_logger->warn("Job method $job_method not defined");
		return(0);
	}

	# Serialize input
	$Data::Dumper::Indent = 0;
	my $input_string = Data::Dumper->Dump([$job_input], ['input']);

	my $job = {
		failed => 0,
		step => $step->{pending},
		login_id => $login_id,
		upload_id => $upload_id
	};

	# Save pending job
	my $existing_rs = $self->dbixSchema->resultset('PendingUpdate')->search(
		$job
	);

	if($existing_rs->first) {
		get_logger->warn("User $login_id has pending update job for upload $upload_id");
		return(0);
	}
	else {
		# Add job details
		$job->{job_method} = $job_method;
		$job->{job_input} = $input_string;

		# Insert into DB
		my $new_row = $self->dbixSchema->resultset('PendingUpdate')->create(
			$job
		);

		return $new_row->pending_update_id;
	}

}

=head2 pending

Return array of pending update job IDs and timestamps

=cut

sub pending {
	my $self = shift;
	
	# Validate user has access to upload_id
	my $pending_rs = $self->dbixSchema->resultset('PendingUpdate')->search(
		{
			'-not_bool' => 'failed',
			'step' => $step->{pending}
		}
	);

	get_logger->info($pending_rs->count ." private genomes found that need to be updated.\n");

	my @pending;
	while(my $pending_row = $pending_rs->next) {
		push @pending, [$pending_row->pending_update_id, $pending_row->start_date];
	}

	return \@pending;
}

=head2 waiting_release

Return array of upload_ids for private genomes that are past their release date.

=cut

sub waiting_release {
	my $self = shift;
	
	# Retrieve all 'release'-type genomes that have lapsed
	my $pastdate = "<= now()";
	my $release_rs = $self->dbixSchema->resultset('Upload')->search({
		release_date => \$pastdate,
		category => 'release'
	});

	get_logger->info($release_rs->count ." private genomes found that need to be released as public.\n");

	my @pending;
	while(my $release_row = $release_rs->next) {
		push @pending, [$release_row->upload_id, $release_row->release_date];
	}
	
	return \@pending;
}


=head2 run_all

Run all pending update jobs, change private genomes to public that are past release date.

=cut

sub run_all {
	my $self = shift;
	
	# Find pending update jobs
	my $pending_rs = $self->dbixSchema->resultset('PendingUpdate')->search(
		{
			'-not_bool' => 'failed',
			'step' => $step->{pending}
		}
	);

	# Run jobs one at a time
	while(my $pending_row = $pending_rs->next) {

		$self->run($pending_row->pending_update_id, $pending_row->login_id, $pending_row->upload_id, 
			$pending_row->job_method, $pending_row->job_input);
		
	}

	# Release genomes into the wild
	my $pastdate = "<= now()";
	my $release_rs = $self->dbixSchema->resultset('Upload')->search({
		release_date => \$pastdate,
		category => 'release'
	});

	while(my $release_row = $release_rs->next) {
		$release_row->category('public');
		$release_row->update;
		get_logger->info("Genome with upload_id ". $release_row->upload_id ." set as public (requested release date: ". $release_row->release_date .")");
	}

	# Update public data
	$self->recompute_public();


}

sub run {
	my $self = shift;
	my ($pending_id, $login_id, $upload_id, $job_method, $job_input_string) = @_;

	my $input;
	eval $job_input_string;

	get_logger->debug("Running $job_method for $login_id");

	get_logger->logwarn("Empty job input for pending_update_id $pending_id") unless $input;
	my $pending_row = $self->dbixSchema->resultset('PendingUpdate')->find($pending_id);
	$pending_row->update({ step => $step->{running} });

	eval {
		$self->$job_method($login_id, $upload_id, $input);
	};
	if($@) {
		get_logger->logwarn("Job $pending_id failed ($@).");
		
		$pending_row->update({ failed => 1 });
		$pending_row->update({ step => $step->{failed} });
	}
	else {
		$pending_row->update({ step => $step->{completed}, end_date => \'now()' });
	}
}


=head2 recompute_public

Several JSON objects containing public data are pre-computed and stored for quick retrieval.
These include:
  - the 'perlpub' genome tree
  - The 'public_genomes' JSON object
  - The Shiny superphy-df_meta.RData file
  - The 'stdgrp-org' JSON group hiearchy object

These objects need to be updated after changes to the genome properties. This method calls
the necessary scripts to update all public objects.

=cut

sub recompute_public {
	my $self = shift;

	my $root_directory = $self->{root_directory};
	my $perl_interpreter = $self->{perl_interpreter};
	my $config_filepath = $self->configFile;


	# Update meta-data
	get_logger->info("Updating public Meta-data JSON object...");
	_run_script($perl_interpreter, "$root_directory/Database/load_meta_data.pl", "--config $config_filepath");
	get_logger->info("Meta-data complete.");

	# Update tree
	get_logger->info("Updating public genome tree...");
	_run_script($perl_interpreter, "$root_directory/Phylogeny/update_public_tree.pl", "--config $config_filepath");
	get_logger->info("tree complete.");

	# Update Shiny
	get_logger->info("Updating public Meta-data RData object...");
	_run_script($perl_interpreter, "$root_directory/Data/send_group_data.pl", "--config $config_filepath", "--meta");
	get_logger->info("rdata complete.");

}

sub _run_script {
	my @program = @_;

	my $cmd = join(' ',@program);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		get_logger->logdie("Running script $cmd failed ($stderr).");
	}
}

=head2 _getModifiableFeatures

Return a result set corresponding to upload_id
argument.  Checks user has can_modify permissions on upload.
The uploading user always has full access 
no matter what the permissions.

=cut

sub can_modify {
	my $self = shift;
	my ($login_id, $upload_id) = @_;

	my $upload_rs = $self->dbixSchema->resultset('Upload')->search(
		{
			'login.login_id'            => $login_id,
			'login_2.login_id'          => $login_id,
			'type.name'                 => 'contig_collection',
			'permissions.can_modify'    => 1,
			'me.upload_id'              => $upload_id
		},
		{
			join => [
				'login',
				{ 'permissions'      => 'login' },
				{ 'private_features' => 'type' },
			],
			columns   => [qw/me.tag me.upload_date/],
			'+select' => [qw/private_features.uniquename private_features.feature_id permissions.can_share/],
			'+as'     => [qw/name feature_id can_share/],
		}
	);

	return $upload_rs;
}

################
## Job Methods
################

# Return 1/0 based on success

sub update_genome_jm {
	my $self = shift;
	my ($login_id, $upload_id, $results) = @_;

	my $grouper = Data::Grouper->new(schema => $self->dbixSchema, cvmemory => $self->cvmemory);

    get_logger->debug('UPLOADID: '.$upload_id);
    
	# Check if user has sufficient permissions to edit provided upload_id
	my $test_rs = $self->can_modify($login_id, $upload_id);
	
	my $test_row = $test_rs->first();
	unless($test_row) {
		get_logger->logdie("User $login_id does not have sufficient permissions to edit genome with upload_id $upload_id.");
	}
	
	# Everything is good to go, update all required tables
	
	# NOTE: this may involve creating new featureprop or dbxref entries
	# if they do not exist and were added in this edit form.
	
	# Grab everything!!
    # Assumes that each contig_collection feature only has one dbxref
    # and this dbxref is defined in the dbxref_id column in the feature
    # table.  Additional dbxrefs for a feature are stored in feature_dbxref.
    # If this changes in the future, than a join with feature_dbxref is needed.
    my $feature_id = $test_row->get_column('feature_id');
    my $feature_rs = $self->dbixSchema->resultset('PrivateFeature')->search(
    	{
    		'me.feature_id' => $feature_id,
    	},
    	{
    		prefetch => [
    			{'private_featureprops' => 'type'}, 
    			'upload', 
    			{'dbxref' => 'db'},
    			'private_genome_locations'
    		]
    	}
    );
    
    my $feature_row = $feature_rs->first();
    
    # Feature table
    
    # Update if user has changed name
    # Form checks ensure new name is unique.
    if($results->{'g_name'} ne $feature_row->uniquename) {
    	$feature_row->name($results->{'g_name'});
    	$feature_row->uniquename($results->{'g_name'});
    }
    
    # Upload table
    
    # Privacy setting can only be changed by admin
    if($results->{'g_privacy'} &&  $results->{'g_privacy'} ne $feature_row->upload->category) {
    	# Attempt to change privacy
    	unless($test_row->get_column('can_share')) {
    		$self->session->param( operation_status => '<strong>Access Denied.</strong> You do not have sufficient permissions to modify the privacy settings for this genome.');
			$self->redirect('/superphy/upload/list');
    	} else {
    		$feature_row->upload->category($results->{'g_privacy'});
    	}
    }
    # I don't worry about the release date as much. We only consider it
    # when the category = 'release', so field won't affect permissions.
    # Never needs to be deleted, only updated if changed to a new valid date.
    if($results->{'g_release_date'}) {
    	$feature_row->upload->release_date($results->{'g_release_date'});
    }
    
    if($results->{'g_group'}) {
    	$feature_row->upload->tag($results->{'g_group'});
    } else {
    	$feature_row->upload->tag('Unclassified');
    }
    
    $feature_row->upload->update;
    
	# Dbxref table

	if($results->{'g_dbxref_acc'}) {
		# Dbxref form field has value
		my $db = $results->{'g_dbxref_db'};
		my $acc = $results->{'g_dbxref_acc'};
		my $ver = $results->{'g_dbxref_ver'};
		
		$ver = '' unless $ver;
		
		if($feature_row->dbxref && 
			($feature_row->dbxref->db->name ne $db ||
		     $feature_row->dbxref->accession ne $acc ||
		     $feature_row->dbxref->accession ne $ver)) {

			# dbxref in DB does not match submitted value
			
			# Other features with this dbxref?
			my $dbxref_rs = $self->dbixSchema->resultset('PrivateFeature')->search(
				[
					{ 'me.dbxref_id' => $feature_row->dbxref->dbxref_id },
					{ 'private_feature_dbxrefs.dbxref_id' => $feature_row->dbxref->dbxref_id }
					
				],
				{
					join => 'private_feature_dbxrefs',
					columns => 'dbxref_id'
				}
			);
			
			if($dbxref_rs->count > 1) {
				# Other features use this dbxref,
				# Need to create a new dbxref instead of changing this one
				
				my $dbxref_row = _createDbxref($self->dbixSchema, $db, $acc, $ver);
				$feature_row->dbxref_id($dbxref_row->dbxref_id);
				
			} else {
				# No other features with dbxref, can safely update
				my $dbxref_row = $feature_row->dbxref;
				
				# Update database value
				if($dbxref_row->db->name ne $db) {
					# Database changed
					# I don't delete DB records, only add new ones
					
					my $db_row = $self->dbixSchema->resultset('Db')->find({ name => $db });
					
					unless($db_row) {
						# Db not in DB, need to create record
						$db_row = $self->dbixSchema->resultset('Db')->create(
							{
								name => $db,
								description => "autocreated:$db"
							}
						);
					}
					
					$dbxref_row->db_id( $db_row->db_id );
				}
				
				# Update other dbxref values
				$dbxref_row->update({
					accession => $acc,
					version => $ver,
				});
			}
			
		} else {
			# User is adding a new dbxref
			my $dbxref_row = _createDbxref($self->dbixSchema, $db, $acc, $ver);
			$feature_row->dbxref_id($dbxref_row->dbxref_id);
		}
		
	} else {
		# Form field is empty
		
		if($feature_row->dbxref) {
			# User is deleting dbxref
			
			# Other features with this dbxref?
			my $dbxref_rs = $self->dbixSchema->resultset('PrivateFeature')->search(
				[
					{ 'me.dbxref_id' => $feature_row->dbxref->dbxref_id },
					{ 'private_feature_dbxrefs.dbxref_id' => $feature_row->dbxref->dbxref_id }
					
				],
				{
					join => 'private_feature_dbxrefs',
					columns => 'dbxref_id'
				}
			);
			
			if($dbxref_rs->count > 1) {
				# Other features use this dbxref,
				# Set dbxref_id column for this feature to null
				$feature_row->update({dbxref_id => undef});
			} else {
				# No other features with dbxref, can safely delete.
				# Deleting will automagically set feature dbxref_id column to null, YEAH Postgres!!
				# I don't delete DB records.
				$feature_row->dbxref->delete;
			}
				
		}
	}
	
	# Commit all updates
	$feature_row->update;
		
	# Featureprop table
	
	# Convert form into DB values
	# required
	my $host;
	if($results->{'g_host'} eq 'other') {
		$host = $results->{'g_host_genus'} . ' ' . $results->{'g_host_species'} . ' ('.
			$results->{'g_host_name'}.')';
	} else {
		$host = $self->hostList->{$results->{'g_host'}};
		croak "Unrecognized host ".$results->{'g_host'} unless $host;
	}
	
	my $host_category = $self->hostCategories->{$results->{'g_host'}};
	
	my $source;
	if($results->{'g_source'} eq 'other') {
		$source = $results->{'g_other_source'};
	} else {
		$source = $self->sourceList->{ $host_category }->{ $results->{'g_source'} };
		croak "Unrecognized source ".$results->{'g_source'}." for provided host ".$results->{'g_host'} unless $source;
	}
	
	my %form_values = (
		serotype => $results->{'g_serotype'},
		strain => $results->{'g_strain'},
		isolation_host => $host,
		isolation_source => $source,
		isolation_date => $results->{'g_date'},
		mol_type => $results->{'g_mol_type'}
	);

	if($results->{'g_syndrome'}) {
		my @syndrome_keys = $results->{'g_syndrome'};
		my @syndromes;
		foreach my $key (@syndrome_keys) {
			my $syndrome = $self->syndromeList->{ $host_category }->{ $key };
			croak "Unrecognized disease $key for provided host ".$results->{'g_host'} unless $syndrome;
			push @syndromes, $syndrome;
		}
		$form_values{'syndrome'} = \@syndromes;
	} elsif($results->{'g_asymptomatic'}) {
		$form_values{'syndrome'} = ['Asymptomatic'];
	}
	
	if($results->{'g_other_syndrome_cb'}) {
		$form_values{'syndrome'} ||= [];
		push @{$form_values{'syndrome'}}, $results->{'g_other_syndrome'};
	}
	
	if($results->{'g_age'}) {
		# Store everthing in day units
		my $days = Sequences::GenodoDateTime::ageIn($results->{'g_age'}, $results->{'g_age_unit'});
		$form_values{isolation_age} = $days;
	}
	
	if($results->{'g_pmid'}) {
		my @pmids = split(/,/, $results->{'g_pmid'});
		my @final_pmids;
		foreach my $item (@pmids){
			push @final_pmids, ($item =~ s/(^\s*)|(\s*$)//);
		}
		$form_values{pmid} = \@final_pmids;
	}
	
	if($results->{'g_description'}) {
		$form_values{'description'} = $results->{'g_description'};
	}
	
	if($results->{'g_comments'}) {
		$form_values{'comment'} = $results->{'g_comments'};
	}
	
	if($results->{'g_keywords'}) {
		$form_values{'keywords'} = $results->{'g_keywords'};
	}
	
	if($results->{'g_owner'}) {
		$form_values{'owner'} = $results->{'g_owner'};
	}

	if($results->{'g_synonym'}) {
		$form_values{'synonym'} = $results->{'g_synonym'};
	}
    
    if($results->{'g_finished'} && $results->{'g_finished'} ne 'unknown') {
		$form_values{'finished'} = $results->{'g_finished'};
	}
	
	
    # Need to keep track of modified vs new featureprops
    my %updated;
    map { $updated{$_}=0} keys %form_values;
  
  	# Perform insertion of Featureprops as single transaction
  	my $txn_guard = $self->dbixSchema->storage->txn_scope_guard;

  	# Record new meta values used in standard group memberships
	my %groupable_meta;
	my %groupable_featureprops;
  	
    # Update existing values in featureprop table
    my $featureprops_rs = $feature_row->private_featureprops;
    while(my $featureprop_row = $featureprops_rs->next) {
    	my $property = $featureprop_row->type->name;
    	
    	get_logger->debug("Property $property");
    	
    	if($property eq 'syndrome' || $property eq 'pmid') {
    		# Delete all existing syndromes and pmid
    		# Will re-insert all syndromes from the form again.
    		# Need to do this to maintain proper rank
    		$featureprop_row->delete;
    		
    	} elsif($form_values{$property}) {
    		
    		# Setting new value 
    		get_logger->debug("...set to ".$form_values{$property});
    		$featureprop_row->value($form_values{$property});
    		$featureprop_row->update;

    		# Record this property if it used to define standard group membership
    		if($grouper->modifiable_meta($property)) {
    			$groupable_meta{$property} = [] unless defined $groupable_meta{$property};
    			push @{$groupable_meta{$property}}, $form_values{$property};
    			$groupable_featureprops{$property}{$form_values{$property}} = $featureprop_row->featureprop_id;
    		}
    		
    	} elsif($featureprop_row->value) {
    		# Form field was deleted by user.
    		# Deleting existing value in DB.
    		# Don't worry, won't delete required fields because
    		# we checked required fields contained a value in form checks.
    		$featureprop_row->delete;
    		get_logger->debug("...deleted ");
    	}
    	
    	$updated{$property} = 1;
    }
    
    # Creating new featureprop entries defined for the first time in this form
    my %fp_cv = (
		mol_type => 'feature_property',
		keywords => 'feature_property',
		description => 'feature_property',
		owner => 'feature_property',
		finished => 'feature_property',
		strain => 'local',
		serotype => 'local',
		isolation_host => 'local',
		isolation_date => 'local',
		synonym => 'feature_property',
		comment => 'feature_property',
		isolation_source => 'local',
		isolation_age => 'local',
		syndrome => 'local',
		pmid     => 'local',
	);
	
	# Update syndromes
	if($form_values{syndrome}) {
		# Find type_id
	    my $syndrome_type_rs = $self->dbixSchema->resultset('Cvterm')->search(
	    	{
	    		'me.name' => 'syndrome', 
	    		'cv.name' => $fp_cv{'syndrome'}
	    	},
	    	{
	    		join => 'cv',
	    		columns => ['cvterm_id']
	    	}
	    );
	    my $syndrome_type_row = $syndrome_type_rs->first;
	    croak "Form field syndrome not defined in cvterm table." unless $syndrome_type_row;
	    
	    my $rank = 0;
		foreach my $form_syndrome (@{$form_values{syndrome}}) {
			
			# Add syndrome 
			get_logger->debug("Property syndrome");
	    		
	    	# Create featureprop
	    	my $new_fp_row = $self->dbixSchema->resultset('PrivateFeatureprop')->create(
		    	{
		    		feature_id => $feature_id,
		    		upload_id => $upload_id,
		    		value => $form_syndrome,
		    		rank => $rank,
		    		type_id => $syndrome_type_row->cvterm_id
		    	}
	    	);
	    	$rank++;
	    	get_logger->debug("...created with value ".$form_values{'syndrome'});

	    	# Currently syndrome is used to define standard group membership
	    	# Left check in, in case this changes in the future
    		if($grouper->modifiable_meta('syndrome')) {
    			$groupable_meta{'syndrome'} = [] unless defined $groupable_meta{'syndrome'};
    			push @{$groupable_meta{'syndrome'}}, $form_values{'syndrome'};
    			$groupable_featureprops{'syndrome'}{$form_values{'syndrome'}} = $new_fp_row->featureprop_id;
    		}
			
		}
		$updated{syndrome}=1
	}
	
	# Update PMIDs
	if($form_values{pmid}) {
		# Find type_id
	    my $pmid_type_rs = $self->dbixSchema->resultset('Cvterm')->search(
	    	{
	    		'me.name' => 'pmid', 
	    		'cv.name' => $fp_cv{'pmid'}
	    	},
	    	{
	    		join => 'cv',
	    		columns => ['cvterm_id']
	    	}
	    );
	    my $pmid_type_row = $pmid_type_rs->first;
	    croak "Form field pmid not defined in cvterm table." unless $pmid_type_row;
	    
	    my $rank = 0;
		foreach my $form_pmid (@{$form_values{pmid}}) {
			# Add pmid 
			get_logger->debug("Property pmid");
	    		
	    	# Create featureprop
	    	$self->dbixSchema->resultset('PrivateFeatureprop')->create(
		    	{
		    		feature_id => $feature_id,
		    		upload_id => $upload_id,
		    		value => $form_pmid,
		    		rank => $rank,
		    		type_id => $pmid_type_row->cvterm_id
		    	}
	    	);
	    	$rank++;
	    	get_logger->debug("...created with value ".$form_values{pmid});
			
		}
		$updated{pmid}=1
	}

	

    foreach my $property (keys %form_values) {
    	if(!$updated{$property}) {
    		get_logger->debug("Property $property");
    		
    		# Find type_id
    		my $type_rs = $self->dbixSchema->resultset('Cvterm')->search(
    			{
    				'me.name' => $property, 
    				'cv.name' => $fp_cv{$property}
    			},
    			{
    				join => 'cv',
    				columns => ['cvterm_id']
    			}
    		);
    		
    		my $type_row = $type_rs->first;
    		croak "Form field $property not defined in cvterm table." unless $type_row;
    		
    		# Create featureprop
    		my $new_fp_row = $self->dbixSchema->resultset('PrivateFeatureprop')->create(
	    		{
	    			feature_id => $feature_id,
	    			upload_id => $upload_id,
	    			value => $form_values{$property},
	    			rank => 0, # New feature, so rank = 0
	    			type_id => $type_row->cvterm_id
	    		}
    		);
    		get_logger->debug("...created with value ".$form_values{$property});

    		# Record this property if it used to define standard group membership
    		if($grouper->modifiable_meta($property)) {
    			$groupable_meta{$property} = [] unless defined $groupable_meta{$property};
    			push @{$groupable_meta{$property}}, $form_values{$property};
    			$groupable_featureprops{$property}{$form_values{$property}} = $new_fp_row->featureprop_id;
    		}
    	}
    }


    # Manage the standard group memberships that are based on meta-data/featureprops

    # Fill in missing values
    foreach my $property ($grouper->modifiable_meta) {
    	$groupable_meta{$property} = [undef] unless defined $groupable_meta{$property};

    }

    # Retrieve new group memberships
    my $genome_groups = $grouper->match(\%groupable_meta);

    # Retrieve existing group memberships
    my %existing_group_assignments;
   	foreach my $property (keys %groupable_meta) {

   		my $is_public = 0;
		my @group_ids = $grouper->retrieve($feature_id, $is_public, $property);

		if(@group_ids) {

			foreach my $id_set (@group_ids) {
				$existing_group_assignments{$id_set->[1]} = $id_set->[0];
			}
		}
		else {
			get_logger->warn("Genome private_$feature_id has no standard group assignment for metadata $property");
		}
   	}

    # Insert new group memberships where needed
    get_logger->debug("Updating standard group memberships");
    foreach my $meta_term (keys %$genome_groups) {
    	foreach my $meta_value ( keys %{$genome_groups->{$meta_term}} ) {
    		my $fp_id = $groupable_featureprops{$meta_term}{$meta_value};
    		my $group_id = $genome_groups->{$meta_term}{$meta_value};

    		unless($existing_group_assignments{$group_id}) {
    			my $new_group_row = $self->dbixSchema->resultset('PrivateFeatureGroup')->create(
		    		{
		    			feature_id => $feature_id,
		    			genome_group_id => $group_id,
		    			featureprop_id => $fp_id
		    		}
	    		);
	    		get_logger->debug("...created group membership to $group_id for value $meta_value");
    		}
    		else {
    			get_logger->debug("...kept existing group membership to $group_id for value $meta_value");
    			delete $existing_group_assignments{$group_id};
    		}
    	}
    }

    # Delete unused group assignments
    foreach my $feature_group_id (values %existing_group_assignments) {
    	my $feature_group_row = $self->dbixSchema->resultset('PrivateFeatureGroup')->find($feature_group_id);

    	croak "No entry in private_feature_group table with primary ID $feature_group_id" unless $feature_group_row;
		$feature_group_row->delete;
		get_logger->debug("...deleted old group membership $feature_group_id");
    }

    # Manage genome locations
    
    if($results->{'geocode_id'}) {
    	# Location provided

    	my $genome_location_row = $feature_row->private_genome_locations->first;
    	if($genome_location_row) {
    		# Update
    		$genome_location_row->geocode_id($results->{'geocode_id'});
    		$genome_location_row->update;
    	}
    	else {
    		# Create
    		$self->dbixSchema->resultset('PrivateGenomeLocation')->create(
	    		{
	    			feature_id => $feature_id,
	    			geocode_id => $results->{'geocode_id'}
	    		}
    		);
    	}
    }
    else {
    	# No location provided

    	my $genome_location_row = $feature_row->private_genome_locations->first;
    	if($genome_location_row) {
    		# Delete
    		$genome_location_row->delete;
    	}
    }
    
    $txn_guard->commit;

    return 1;
}

sub status_id {
	my $status_name = shift;

	return $step->{$status_name};
}


1;