#!/usr/bin/env perl


package Modules::Groups;

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
use Modules::LocationManager;
use JSON;
use Time::HiRes;
use Proc::Daemon;
use String::Random;

=head2 setup

Defines the start and run modes for CGI::Application and connects to the database.

=cut

sub setup {
    my $self=shift;
    my $logger = Log::Log4perl->get_logger();
    $logger->info("Logger initialized in Modules::Groups");
}

sub shiny : StartRunmode {
    my $self = shift;
    my $template = $self->load_tmpl('shiny.tmpl', die_on_bad_params => 0);
    my $CGISESSID = $self->session->id();
    my $user = $self->authen->username;

    my $cgi = $self->query();

    # Base url
    my $url = 'https://lfz.corefacility.ca/superphy/shiny/?';

    # Add session ID
    $url .= "CGISESSID=$CGISESSID";

    # Add encoded superphy group API
    my $api = $self->config_param('shiny.groupapi');
    die "Error: missing config parameter shiny.groupapi" unless $api;
    my $escaped_api = $cgi->escape($api);
    $url .= "&superphyuri=$escaped_api";

    # Add user, if available
    if($user) {
        my $escaped_user = $cgi->escape($user);
        $url .= "&user=$escaped_user";
    }

    $template->param(SHINYURI => $url);
    return $template->output();
}

# sub search : StartRunmode {
#     my $self = shift;

#     my $fdg = Modules::FormDataGenerator->new();
#     $fdg->dbixSchema($self->dbixSchema);
    
#     my $username = $self->authen->username;
#     my ($pub_json, $pvt_json) = $fdg->genomeInfo($username);

#     my $template = $self->load_tmpl('groups_search.tmpl', die_on_bad_params => 0);

#     $template->param(public_genomes => $pub_json);
#     $template->param(private_genomes => $pvt_json) if $pvt_json;
    
#     # Phylogenetic tree
#     my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
    
#     # find visable nodes for user
#     my $visable_nodes;
#     $fdg->publicGenomes($visable_nodes);
#     my $has_private = $fdg->privateGenomes($username, $visable_nodes);
    
#     if($has_private) {
#         my $tree_string = $tree->fullTree($visable_nodes);
#         $template->param(tree_json => $tree_string);
#         } else {
#             my $tree_string = $tree->fullTree();
#             $template->param(tree_json => $tree_string);
#         }

#     # Groups Manager, only active if user logged in
#     $template->param(groups_manager => 0) unless $username;
#     $template->param(groups_manager => 1) if $username;

#     $template->param(title1 => 'GROUP');
#     $template->param(title2 => 'ANALYSES');

#     return $template->output();
# }

sub compare : Runmode {
    my $self = shift;

    my $q = $self->query();

    my ($username, $userId);
    #Check if user is logged in (need both username and user id)
    $username = $self->authen->username;
    unless ($username) {
        ($username, $userId) = (undef, undef);
    }
    else {

        my $userIdRs = $self->dbixSchema->resultset('Login')->search(
            {username => $username},
            {
                column => [qw/login_id/]
            }
            );

        $userId = $userIdRs->first->login_id if $userIdRs->first // '';
    }

    # TODO: Need to check user permissions on genomes with genome warden

    # With the long polling system a user can bookmark the page and come back to it later
    # Each bookmarked page will have a job id tagged to it. If no job-id exists then
    #   the job is newly requested and should be created.
    my $job_id = $q->param("job_id");

    if ($job_id) {
        my $template = $self->load_tmpl( 'job_in_progress.tmpl' , die_on_bad_params=>0);
        $template->param(JOB=>1,job_id => $job_id);
        return $template->output();
    }

    my @group1Genomes = $q->param('group1-genome');
    my @group2Genomes = $q->param('group2-genome');

    #Else no job_id so we create a new request
    $self->_forkJob(\@group1Genomes, \@group2Genomes, $userId, $username, $self->session->remote_addr(), $self->session->id());
    
    return;
}

sub _forkJob {
    my ($self, $_group1Genomes, $_group2Genomes, $_userId, $_username, $_remoteAddress, $_sessionId) = @_;

    my %userConfig = ('group1' => $_group1Genomes, 'group2' => $_group2Genomes);

    my $userConfigJson = encode_json(\%userConfig);

    #Generate a new random job id:
    my @stringRandomInputs = ('C','c','n');
    my $randomStringLen = 20;
    my $randomStringInput;

    foreach (1..$randomStringLen) {
        $randomStringInput.=$stringRandomInputs[rand @stringRandomInputs];
    }

    my $stringRandomGenerator = new String::Random;

    my $jobCount = $self->dbixSchema->resultset('JobResult')->search(undef, {column => ['job_result_id']})->count;

    my $newJobId = $stringRandomGenerator->randpattern($randomStringInput) . $jobCount;

    my $newJob = $self->dbixSchema->resultset('JobResult')->new({
        'job_result_id' => $newJobId,
        'remote_address' => $_remoteAddress,
        'session_id' => $_sessionId,
        'user_id' => $_userId,
        'username' => $_username,
        'user_config' => $userConfigJson,
        'job_result_status' => 'Initializing request',
        'result' => undef
        });

    $newJob->insert();
    get_logger->info("New job: $newJobId created") if $newJob->in_storage() // die "Error initializing new groups compare job.\n";

    #Set up daemon proc and fork off!
    my $config = $self->config;
    my $logDir = $self->config_param('dir.log');

    my $cmd = "perl $FindBin::Bin/../../Data/groups_forked_job.pl --job_id $newJobId";

    my $daemon = Proc::Daemon->new(
        work_dir => "$FindBin::Bin/../../Data/",
        exec_command => $cmd,
        child_STDERR => "+>>$logDir"."groups.log");

    $self->teardown;

    my $kid_pid = $daemon->Init;

    return $self->redirect('/superphy/groups/compare?job_id='.$newJobId);
}

sub poll : Runmode {
    # TODO: Need to handle errors and returnig of results
    my $self = shift;
    my $q = $self->query();
    my $_jobId = $q->param('job_id');

    my $statusRs = $self->dbixSchema->resultset('JobResult')->find({job_result_id => $_jobId});

    my $status = {'error' => 'this request does not exist'};
    $status = {'status' => $statusRs->job_result_status} if $statusRs;

    return encode_json($status);
}

sub geophy : Runmode {
    # TODO: Need to query for strains and return only the subset
    my $self = shift;

    #my $q = $self->query();

    my $template = $self->load_tmpl('groups_geophy.tmpl', die_on_bad_params => 0);

    #my @public_selected_genome_ids = $q->param('public_genome');
    #my @private_selected_genome_ids = $q->param('private_genome');

    # #Change this to take into account any number of genomes
    # ####
    # my $num_groups = $q->param('num-groups');
    # my %qGroups;
    # my $showAllBool = $q->param('show-all');

    # for (my $i = 0; $i < $num_groups; $i++) {
    #    my @newgroup = $q->param('group'.($i+1).'-genome');
    #    if (scalar(@newgroup) gt 0) {
    #        $qGroups{($i+1)} = \@newgroup;
    #    }
    # }

    # print STDERR "$_\n" foreach(keys %qGroups);

    # if(scalar(keys %qGroups) gt 0) {
    #     my $groups_json =  encode_json(\%qGroups);
    #     $template->param(USER_SELECTIONS => 1, groups => $groups_json, num_groups => $num_groups);
    # }

    # if ($showAllBool) {
    #     $template->param(SHOWALL => 1);
    # }
    # ###

    # TODO: Need to use genome-warden for looking up genomes

    my $fdg = Modules::FormDataGenerator->new();
    $fdg->dbixSchema($self->dbixSchema);
    
    my $username = $self->authen->username;

    my ($pub_json, $pvt_json) = $fdg->genomeInfo($username);

    $template->param(public_genomes => $pub_json);
    $template->param(private_genomes => $pvt_json) if $pvt_json;
    
    # Phylogenetic tree
    my $tree = Phylogeny::Tree->new(dbix_schema => $self->dbixSchema);
    
    # find visable nodes for user
    my $visable_nodes = {};
    $fdg->publicGenomes($visable_nodes);
    my $has_private = $fdg->privateGenomes($username, $visable_nodes);
    
    if($has_private) {
        my $tree_string = $tree->fullTree($visable_nodes);
        $template->param(tree_json => $tree_string);
        } else {
            my $tree_string = $tree->fullTree();
            $template->param(tree_json => $tree_string);
        }

    $template->param(title1 => 'GROUP');
    $template->param(title2 => 'BROWSE');

    my $user_groups = $fdg->userGroups($username);

    $template->param(username => $username);
    $template->param(user_groups => $user_groups);


    return $template->output();
}

1;
