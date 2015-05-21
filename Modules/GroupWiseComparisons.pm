#!/usr/bin/env perl

=pod

=head1 NAME

Modules::GroupWiseComparisons

=head1 SNYNOPSIS

=head1 DESCRIPTION

=head1 ACKNOWLEDGMENTS

Thank you to Dr. Chad Laing and Dr. Michael Whiteside, for all their assistance on this project

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AVAILABILITY

The most recent version of the code may be found at:

=head1 AUTHOR

Akiff Manji (akiff.manji@gmail.com)

=head1 Methods

=cut

package Modules::GroupWiseComparisons;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Modules::FormDataGenerator;
use Modules::FastaFileWrite;
use HTML::Template::HashWrapper;
use CGI::Application::Plugin::AutoRunmode;
use Phylogeny::Tree;
use Modules::GroupComparator;
use Modules::TreeManipulator;
use Data::FormValidator::Constraints (qw/valid_email/);
use Log::Log4perl qw'get_logger';
use Carp;
use Time::HiRes;
use Math::Round 'nlowmult';
use IO::File;
use File::Temp;
use Proc::Daemon; #To fork off long processes
use JSON;

sub setup {
	my $self=shift;
	
	get_logger()->info("Logger initialized in Modules::GroupWiseComparisons");
}

=head2 groupWiseComparisons

Run mode for the group wise comparisons page

=cut

sub group_wise_comparisons : StartRunmode {
	my $self = shift;
	my $errs = shift;
	
	my $formDataGenerator = Modules::FormDataGenerator->new();
	$formDataGenerator->dbixSchema($self->dbixSchema);
	
	my $username = $self->authen->username;
	
	# Retrieve form data
	my ($pub_json, $pvt_json) = $formDataGenerator->genomeInfo($username);
	
	my $template = $self->load_tmpl( 'group_wise_comparison.tmpl' , die_on_bad_params=>0 );
	
	$template->param(groupwise => 1);
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;
	
	my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
	$template->param(tree_json => $tree->fullTree());
	
	if($errs) {
		$template->param(comparison_failed => $errs);
	}
	
	return $template->output();
}

#Set up the long polling server process here
sub comparison : Runmode {
	my $self = shift;
	my $start = Time::HiRes::gettimeofday();

	my $q = $self->query();
	#Needed for forked jobs
	my $job_id = $q->param("job_id");
	my $geospatial = $q->param("geospatial");

	my $username = $self->authen->username;

	if (!$username) {
		$username = "\"\"";
	}

	if (!$geospatial || $geospatial eq "false") {
		$geospatial = "false";
	}

	my $formDataGenerator = Modules::FormDataGenerator->new();
	$formDataGenerator->dbixSchema($self->dbixSchema);
	my ($pub_json, $pvt_json) = $formDataGenerator->genomeInfo($username);

	if ($job_id) {
		my $template = $self->load_tmpl( 'job_in_progress.tmpl' , die_on_bad_params=>0);
		$template->param(job_id => $job_id);
		$template->param(geospatial=>$geospatial);
		$template->param(public_genomes => $pub_json);
		$template->param(private_genomes => $pvt_json) if $pvt_json;
		return $template->output();
	}

	my @group1 = $q->param("comparison-group1-genome");
	my @group2 = $q->param("comparison-group2-genome");
	my @group1Names = $q->param("comparison-group1-name");
	my @group2Names = $q->param("comparison-group2-name");
	my $locisnp = $q->param("loci-snp");

	#Deprecated email funciton
	#my $email = $q->param("email-results");

	if(!@group1 && !@group2){
		return $self->group_wise_comparisons('one or more groups were empty');
	}

	if (!$geospatial || $geospatial eq "false" && !$locisnp || $locisnp eq "false") {
		return $self->group_wise_comparisons('no data analysis type selected');
	}

	# Validate genome access
	my @private_ids = map m/private_(\d+)/ ? $1 : (), (@group1, @group2);

	if(@private_ids) {
		my $ok = $formDataGenerator->verifyMultipleAccess($username, @private_ids);
		foreach my $id (keys %$ok) {
			return $self->group_wise_comparisons('<strong>Permission Denied!</strong> You have not been granted access to uploaded genome $id') unless $ok->{$id};
		}
	}
	
	if ($locisnp && $geospatial) {
		$self->startForkedGroupCompare($username, $self->session->remote_addr(), $self->session->id(), \@group1, \@group2, \@group1Names, \@group2Names, $geospatial);
	}
	elsif(!$geospatial || $geospatial eq "false") {
		$self->startForkedGroupCompare($username, $self->session->remote_addr(), $self->session->id(), \@group1, \@group2, \@group1Names, \@group2Names, $geospatial);
	}
	else {
		#Return geospatial data only
		my $template = $self->load_tmpl( 'geospatial_comparison.tmpl' , die_on_bad_params=>0 );
		my $end = Time::HiRes::gettimeofday();
		my $run_time = nlowmult(0.01, $end - $start);
		$template->param(locisnp => 0);
		#Prepare the groups into hash refs
		my (%_group1StrainIds, %_group2StrainIds);
		foreach my $id (@group1) {
			$_group1StrainIds{$id} = "";
		}
		foreach my $id (@group2) {
			$_group2StrainIds{$id} = "";
		}
		my $group1Json = encode_json(\%_group1StrainIds);
		my $group2Json = encode_json(\%_group2StrainIds);
		$template->param(geospatial => 1, group1 => $group1Json, group2 => $group2Json);
		$template->param(run_time => $run_time);
		$template->param(groupwise => 1);
		$template->param(public_genomes => $pub_json);
		$template->param(private_genomes => $pvt_json) if $pvt_json;
		return $template->output();
	}
	#Deprecated email module
	# elsif ($email) {
	# 	my $user_email = $q->param("user-email");
	# 	my $user_email_confirmed = $q->param("user-email-confirmed");
	# 	if (($user_email eq $user_email_confirmed) && (valid_email($user_email))) {
	# 		$self->_emailStrainInfo($user_email, \@group1 , \@group2 , \@group1Names , \@group2Names);
	# 	}
	# 	else {
	# 		return $self->group_wise_comparisons('invalid email address was entered');
	# 	}
	# }
}

sub running_job : Runmode {
	my $self = shift;
	my $q = $self->query();
	my $job_id = $q->param("job_id");
	my $geospatial = $q->param("geospatial");
	
	my $groupwise_dir = $self->config_param('dir.groupwise');

	#Check status of job id, if still in progress return to the polling script
	my $jobs_resultset = $self->dbixSchema->resultset('Job')->search(
		{'me.job_id' => $job_id},
		{
			select => ['status', 'user_config'],
			as => ['status', 'user_config']
		}
		);

	my $status = $jobs_resultset->first->get_column('status');

	die "Error. Job id not found." unless $status;

	my $html = "";
	my $group1 = "";
	my $group2 = "";

	if ($status ne "in progress") {
		open my $fh, "<", "$groupwise_dir/$status";		
		while(<$fh>) {
			$_ =~ s/\R//;
			$html .= "$_";
		}
		if (my $user_conf = new Config::Simple("$groupwise_dir/".$jobs_resultset->first->get_column('user_config'))) {
			$group1 = $user_conf->param('user.gp1IDs');
			$group2 = $user_conf->param('user.gp2IDs');
		}
		else {
			die Config::Simple->error();
		}
	}
	my %poll = (
		'status' => $status,
		'html' => $html,
		'geospatial' => $geospatial,
		'group1' => $group1,
		'group2' => $group2
		);
	my $poll_ref = encode_json(\%poll);
	return $poll_ref;
}

=head2 view

=cut

sub view : Runmode {
	my $self = shift;

	my $template = $self->load_tmpl( 'query_locus_view.tmpl' , die_on_bad_params=>0 );
	
	# Retrieve form data
	my $username = $self->authen->username;

	my $formDataGenerator = Modules::FormDataGenerator->new();
	$formDataGenerator->dbixSchema($self->dbixSchema);
	my ($pub_json, $pvt_json) = $formDataGenerator->genomeInfo($username);
	
	$template->param(public_genomes => $pub_json);
	$template->param(private_genomes => $pvt_json) if $pvt_json;

	# Params 
	my $q = $self->query();
	my $qgene;
	my $qtype;
	my @gp1genomes = $q->param('gp1genome');
	my @gp2genomes = $q->param('gp2genome');
	my @genomeIDs = (@gp1genomes, @gp2genomes);
	if($q->param('locus')) {
		$qtype='locus';
		$qgene = $q->param('locus');

		my $locusMetaInfo = $self->_getLocusMetaInfo($qtype, $qgene, \@genomeIDs);
		$template->param(locus => 1, locusMetaInfo => $locusMetaInfo);
		return $template->output();
	} 
	elsif($q->param('snp')) {
		$qtype='snp';
		$qgene = $q->param('snp');

		my $snpMetaInfo = $self->_getLocusMetaInfo($qtype, $qgene, \@genomeIDs);
		$template->param(snp => 1, locusMetaInfo => $snpMetaInfo);
		return $template->output();
	}

	croak "Error: no query gene parameter." unless $qgene;
}

=head2 _getStrainInfo

=cut

sub _getStrainInfo {
	my $self = shift;
	my $_group1StrainIds = shift;
	my $_group2StrainIds = shift;
	my $_group1StrainNames = shift;
	my $_group2StrainNames = shift;
	my $comparisonHandle = Modules::GroupComparator->new();
	$comparisonHandle->dbixSchema($self->dbixSchema);
	my $_binaryFETResults = $comparisonHandle->getBinaryData($_group1StrainIds, $_group2StrainIds, $_group1StrainNames , $_group2StrainNames);
	my $_snpFETResults = $comparisonHandle->getSnpData($_group1StrainIds, $_group2StrainIds, $_group1StrainNames , $_group2StrainNames);
	return ($_binaryFETResults, $_snpFETResults);
}

sub startForkedGroupCompare {
	my $self = shift;
	my ($_username, $_remote_addr, $_session_id, $_group1StrainIds, $_group2StrainIds, $_group1StrainNames, $_group2StrainNames, $_geospatial) = @_;
	
	# work directory
	my $groupwise_dir = $self->config_param('dir.groupwise');
	croak "Error: missing config file parameter 'dir.groupwise'." unless $groupwise_dir;
	
	# log directory
	my $log_dir = $self->config_param('dir.log');
	croak "Error: missing config file parameter 'dir.log'." unless $log_dir;
	
	# config file
	my $config_file = $self->config_file;

	#Check for current number of jobs, create a new job_id and fork off new job
	my $jobs_resultset = $self->dbixSchema->resultset('Job')->search(
		{},
		{
			select => [{count => 'me.job_id'}],
			as => ['job_count']
		}
		);

	my $userConFile = File::Temp->new(	TEMPLATE => 'user_conf_tempXXXXXXXXXX',
		DIR => $groupwise_dir,
		UNLINK => 0);

	my $_job_id = $1 if ($userConFile->filename =~ /user_conf_temp(\w+)$/);

	$_job_id = $jobs_resultset->first->get_column('job_count') +1 . "_" . $_job_id;

	#my $userConFileName = $userConFile->filename;
	my $userConFileName = $1 if ($userConFile->filename =~ m/\/(user_conf_temp\w+)$/);
	#Write the job params to the db

	my $newJob = $self->dbixSchema->resultset('Job')->new({
		'job_id' => $_job_id,
		'remote_addr' => $_remote_addr,
		'session_id' => $_session_id,
		'username' => $_username,
		'status' => "in progress",
		'user_config' => $userConFileName
		});

	$newJob->insert();


	if ($newJob->in_storage()) {
		print STDERR "New groupwise comparison job initialized successfully.\n";
	}
	else {
		die "Error initializing new groupwise comparison job.\n";
	}

	# #---User Config---

	# [user]
	# username = ;
	# remote_addr = ;
	# session_id = ;
	# gp1IDs = ;
	# gp2IDs = ;
	# gp1Names = ;
	# gp2Names =;
	

	my $userConString = "#---User Config---\n\n";
	$userConString .= '[user]' . "\n";
	$userConString .= "username = $_username\n";
	$userConString .= "remote_addr = $_remote_addr\n";
	$userConString .= "session_id = $_session_id\n";
	$userConString .= "job_id = $_job_id\n";
	$userConString .= "gp1IDs = " . join(',' , @{$_group1StrainIds}) . "\n";
	$userConString .= "gp2IDs = " . join(',' , @{$_group2StrainIds}) . "\n";
	$userConString .= "gp1Names = " . join(',', @{$_group1StrainNames}) . "\n";
	$userConString .= "gp2Names = " . join(',', @{$_group2StrainNames});
	$userConString .= "\ngeospatial = $_geospatial";

	print $userConFile $userConString or die "$!";

	#Fork program and run loading separately
	my $cmd = "perl $FindBin::Bin/../../Data/forked_group_compare.pl --config $config_file --user_config $userConFile";
	get_logger->debug($cmd);
	my $daemon = Proc::Daemon->new(
		work_dir => "$FindBin::Bin/../../Data/",
		exec_command => $cmd,
		child_STDERR => "$log_dir/group_wise_comparisons.log");
	#Fork
	$self->session->close;  # Why is this called, method depreciated and new method 'flush' gets called in the teardown method
	my $kid_pid = $daemon->Init;

	#Right now it redirects to comparison runmode, may want to change that
	return $self->redirect('/group-wise-comparisons/comparison?job_id='.$_job_id.'&geospatial='.$_geospatial);
}


#Deprecated email module
# sub _emailStrainInfo {
# 	my $self = shift;
# 	my $_user_email = shift;
# 	my $_group1StrainIds = shift;
# 	my $_group2StrainIds = shift;
# 	my $_group1StrainNames = shift;
# 	my $_group2StrainNames = shift;

# 	#Need to write all the params needed to send the email
# 	# #---User Email---

# 	# [user]
# 	# email = ;
# 	# gp1IDs = ;
# 	# gp2IDs = ;
# 	# gp1Names = ;
# 	# gp2Names =;

# 	my $userConFile = File::Temp->new(	TEMPLATE => 'user_conf_tempXXXXXXXXXX',
# 		DIR => '/home/genodo/group_wise_data_temp/',
# 		UNLINK => 0);

# 	my $userConString = "#---User Email---\n\n";
# 	$userConString .= '[user]' . "\n";
# 	$userConString .= "email = $_user_email\n";
# 	$userConString .= "gp1IDs = " . join(',' , @{$_group1StrainIds}) . "\n";
# 	$userConString .= "gp2IDs = " . join(',' , @{$_group2StrainIds}) . "\n";
# 	$userConString .= "gp1Names = " . join(',', @{$_group1StrainNames}) . "\n";
# 	$userConString .= "gp2Names = " . join(',', @{$_group2StrainNames});

# 	print $userConFile $userConString or die "$!";

# 	# Fork program and run loading separately
# 	my $cmd = "perl $FindBin::Bin/../../Data/email_user_data.pl --config $FindBin::Bin/../../Modules/genodo.cfg --user_config $userConFile";
# 	my $daemon = Proc::Daemon->new(
# 		work_dir => "$FindBin::Bin/../../Data/",
# 		exec_command => $cmd,
# 		child_STDERR => "/home/genodo/logs/group_wise_comparisons.log"
# 		);
# 	#Fork
# 	$self->session->close;
# 	my $kid_pid = $daemon->Init;

# 	#Return Parent
# 	my $template = $self->load_tmpl( 'comparison_email.tmpl' , die_on_bad_params=>0 );
# 	return $template->output();

# 	##Older/Another way to fork the process:
# 	# $self->session->close;
# 	# my $template = $self->load_tmpl( 'comparison_email.tmpl' , die_on_bad_params=>0 );
# 	# my $pid = fork;
# 	# if ($pid) {
# 	# 	$template->param(email_address=>$_user_email);
# 	# 	return $template->output();
# 	# 	waitpid $pid, 0;
# 	# }
# 	# else {
# 	# 	close STDIN;
# 	# 	close STDOUT;
# 	# 	close STDERR;
# 	# 	my $comparisonHandle = Modules::GroupComparator->new();
# 	# 	$comparisonHandle->dbixSchema($self->dbixSchema);
# 	# 	$comparisonHandle->configLocation($self->config_file);
# 	# 	$comparisonHandle->emailResultsToUser($_user_email, $_group1StrainIds, $_group2StrainIds, $_group1StrainNames , $_group2StrainNames);
# 	# }
# }

sub _getLocusMetaInfo {
	#Change this to reflect the new tables
	my $self = shift;
	my $_locusType = shift;
	my $_locusID = shift;
	my $_genomeIDs = shift;

	my @metaMetaInfo;

	if ($_locusType eq 'locus') {
		my $genomesPA = $self->dbixSchema->resultset('Feature')->search(
			{'me.feature_id' => $_locusID, 'loci_genotypes.genome_id' => $_genomeIDs},
			{
				join => ['loci_genotypes', 'featureprops'],
				select => ['me.uniquename', 'featureprops.value', 'loci_genotypes.genome_id', 'loci_genotypes.locus_genotype'],
				as => ['id', 'function', 'genome_id', 'genotype'],
			}
			);
		my @locusMetaInfo = $genomesPA->all;
		my @metaInfo;
		foreach my $metaRow (@locusMetaInfo) {
			my %rowData;
			$rowData{'genome_id'} = $metaRow->get_column('genome_id');
			$rowData{'genotype'} = $metaRow->get_column('genotype');
			push (@metaInfo, \%rowData);
		}
		push(@metaMetaInfo, {'id' => $locusMetaInfo[0]->get_column('id')});
		push(@metaMetaInfo, {'function' => $locusMetaInfo[0]->get_column('function')});
		push(@metaMetaInfo, {'data' => \@metaInfo});
		return \@metaMetaInfo;
	}
	elsif ($_locusType eq 'snp') {
		my $genomesPA = $self->dbixSchema->resultset('Feature')->search(
			{'me.feature_id' => $_locusID, 'snps_genotypes.genome_id' => $_genomeIDs},
			{
				join => ['snps_genotypes', 'featureprops'],
				select => ['me.uniquename', 'featureprops.value', 'snps_genotypes.genome_id', 'snps_genotypes.snp_a', 'snps_genotypes.snp_t', 'snps_genotypes.snp_c', 'snps_genotypes.snp_g'],
				as => ['id', 'function','genome_id', 'a_genotype', 't_genotype', 'c_genotype', 'g_genotype'],
			}
			);
		my @snpMetaInfo = $genomesPA->all;
		my @metaInfo;
		foreach my $metaRow (@snpMetaInfo) {
			my %rowData;
			$rowData{'genome_id'} = $metaRow->get_column('genome_id');
			my $genotype = '-';
			$genotype = "A" if $metaRow->get_column('a_genotype') == 1;
			$genotype = "T" if $metaRow->get_column('t_genotype') == 1;
			$genotype = "C" if $metaRow->get_column('c_genotype') == 1;
			$genotype = "G" if $metaRow->get_column('g_genotype') == 1;

			$rowData{'genotype'} = $genotype;
			push (@metaInfo, \%rowData);
		}
		push(@metaMetaInfo, {'id' => $snpMetaInfo[0]->get_column('id')});
		push(@metaMetaInfo, {'function' => $snpMetaInfo[0]->get_column('function')});
		push(@metaMetaInfo, {'data' => \@metaInfo});
		return \@metaMetaInfo;
	}
}

1;