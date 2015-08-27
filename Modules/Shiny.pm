#!/usr/bin/env perl

package Modules::Shiny;

#Shiny API

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
use Modules::LocationManager;
use JSON::MaybeXS qw(encode_json decode_json);
use Time::HiRes;
use Data::Dumper;
use List::MoreUtils qw(any);

=head2 setup

Defines the start and run modes for CGI::Application and connects to the database.

=cut

sub setup {
    my $self = shift;
    
    get_logger->info("Initializing Modules::Shiny");

}




=head2 groups

API GET method for groups

List user's groups

=cut
sub groups : StartRunmode {
    my $self = shift;

    my $q = $self->query();

    # User crudentials
    my $username = $self->authen->username;
    my $session_id = $self->session->id();
    my $shiny_data = { CGISESSID => $session_id };
    
    if($self->authen->is_authenticated) {
        get_logger->debug("Username: $username");
        
    } 
    else {
        get_logger->debug("Not logged in");
        $username = undef;
    }

    $shiny_data->{user} = $username;
    $self->shiny_data($username, $shiny_data);
    
    return $self->json_response('retrieved', $shiny_data);
}

=head2 create_group

API POST method for groups

Create new group

=cut
sub create_group : Runmode {
    my $self = shift;

    # User crudentials
    my $username = $self->authen->username;
    my $session_id = $self->session->id();
    
    if($self->authen->is_authenticated) {
        get_logger->debug("Username: $username");
    } 
    else {
        get_logger->debug("Not logged in");
        my $shiny_data = { CGISESSID => $session_id };
        return $self->error_response('not_logged_in', $shiny_data);
    }

    my $shiny_data = { CGISESSID => $session_id, user => $username };

    # Validate POST data
    # NOTE: (from CGI.pm) If POSTed data is not of type application/x-www-form-urlencoded 
    # or multipart/form-data, then the POSTed data will not be processed, but instead be 
    # returned as-is in a parameter named POSTDATA
    my $post_data = $self->query->param('POSTDATA');
    
    my ($err, $group_data) = $self->valid_request('create', $username, $session_id, $post_data, $shiny_data);
    return $err if $err;

    # Create new group
    my $data_mod = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, 
        cvmemory => $self->cvmemory);

    my $ordered_genomes = $group_data->{genome_list};

    my $i = 0;
    my @genomes;
    foreach my $value (@{$group_data->{group_list}}) {
        if($value) {
            push @genomes, $ordered_genomes->[$i];
        }
        $i++;
    }

    unless(@genomes) {
        get_logger->debug('No genomes present in group array');
        return $self->error_response('no_genomes', $shiny_data);
    }   

    # Validate genomes
    my $warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, 
        genomes => \@genomes, user => $username, 
        cvmemory => $self->cvmemory);

    my ($err2, $bad1, $bad2) = $warden->error; 
    if($err2) {
        # User requested invalid strains or strains that they do not have permission to view
        return $self->error_response('forbidden', $shiny_data);
    }

    # Create group
    my $gid = $data_mod->createGroup($warden, {
        name => $group_data->{group_name},
        username => $username
    });

    unless($gid) {
        return $self->error_response('duplicate', $shiny_data);
    }

    
    # Return current genome data
    $data_mod->shiny_data($username, $shiny_data);

    
    return $self->json_response('created', $shiny_data, $gid);
}

=head2 update_group

API PUT method for groups

Update existing group

=cut
sub update_group : Runmode {
    my $self = shift;

    # User crudentials
    my $username = $self->authen->username;
    my $session_id = $self->session->id();
    
    if($self->authen->is_authenticated) {
        get_logger->debug("Username: $username");
    } 
    else {
        get_logger->debug("Not logged in");
        my $shiny_data = { CGISESSID => $session_id };
        return $self->error_response('not_logged_in', $shiny_data);
    }

    my $shiny_data = { CGISESSID => $session_id, user => $username };

    # URI should provide group ID
    my $group_id = $self->param('group_id');
    unless($group_id) {
        get_logger->debug('Missing group_id parameter in URL');
        return $self->error_response('missing_param', $shiny_data);
    }
   

    # Validate PUT data
    # NOTE: (from CGI.pm) If PUTed data is not of type application/x-www-form-urlencoded 
    # or multipart/form-data, then the PUTed data will not be processed, but instead be 
    # returned as-is in a parameter named PUTDATA
    my $put_data = $self->query->param('PUTDATA');
    
    my ($err, $group_data) = $self->valid_request('update', $username, $session_id, $put_data, $shiny_data);
    return $err if $err;

    # Update group
    my $data_mod = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, 
        cvmemory => $self->cvmemory);

    my $ordered_genomes = $group_data->{genome_list};

    my $i = 0;
    my @genomes;
    foreach my $value (@{$group_data->{group_list}}) {
        if($value) {
            push @genomes, $ordered_genomes->[$i];
        }
        $i++;
    }

    unless(@genomes) {
        get_logger->debug('No genomes present in group array');
        return $self->error_response('no_genomes', $shiny_data);
    }    

    # Validate genomes
    my $warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, 
        genomes => \@genomes, user => $username, 
        cvmemory => $self->cvmemory);

    my ($err2, $bad1, $bad2) = $warden->error; 
    if($err2) {
        # User requested invalid strains or strains that they do not have permission to view
        return $self->error_response('forbidden', $shiny_data);
    }

    # Update group name
    # If name is unchanged, no updates will be made
    my $rs = $data_mod->updateGroupProperties({
        name => $group_data->{group_name},
        username => $username,
        group_id => $group_id
    });

    unless($rs) {
        return $self->error_response('duplicate', $shiny_data);
    }

    # Update group members
    $rs = $data_mod->updateGroupMembers($warden, 
        {
            username => $username,
            group_id => $group_id
        }
    );

    unless($rs) {
        return $self->error_response('group_missing', $shiny_data);
    }

    
    # Return current genome data
    my $fdg = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, 
        cvmemory => $self->cvmemory);
    $fdg->shiny_data($username, $shiny_data);

    
    return $self->json_response('updated', $shiny_data, $group_id);
}



=head2 error_response

Provide RESTful responses to common errors encountered in
module.

=cut
sub error_response {
    my $self = shift;
    my $err_t = shift; # error type
    my $shiny_data = shift;
   
    my $msg;
    if($err_t eq 'not_logged_in'){
            $self->header_add('-status' => '401 User not logged in');
            $msg = 'User not logged in';
    }
    if($err_t eq 'forbidden') {
        $self->header_add('-status' => '403 Restricted access');
        $msg = 'User does not have access to requested genomes';
    }
    if($err_t eq 'no_data') {
        $self->header_add('-status' => '400 Bad Request');
        $msg = 'Missing POST/PUT body in request';
    }
    if($err_t eq 'no_genomes') {
        $self->header_add('-status' => '400 Bad Request');
        $msg = 'groups array is empty in request body';
    }
    if($err_t eq 'bad_syntax') {
        $self->header_add('-status' => '400 Bad Request');
        $msg = 'Malformed request';
    }
    if($err_t eq 'missing_param') {
        $self->header_add('-status' => '400 Bad Request');
        $msg = 'Missing group ID in URL';
    }
    if($err_t eq 'duplicate') {
        $self->header_add('-status' => '400 Bad Request');
        $msg = 'Possible duplicate group name. Review logs for confirmation.';
    }
    if($err_t eq 'group_missing'){
        $self->header_add('-status' => '400 Bad Request');
        $msg = 'Group matching group ID not found for user. Review logs for confirmation.';
    }
    else {
        die "Error: unknown error type $err_t.";
    }

    $shiny_data->{error} = $msg;

    # Type
    $self->header_add('-type' => 'application/json');

    return encode_json($shiny_data)
}

=head2 json_response

Provide REST response to for creation or retrieval of group

Consider adding HATEOAS links in JSON body using HAL specification.
For now self URI will be provided in LINK header. THis may or may not
be correct.

=cut
sub json_response {
    my $self = shift;
    my $response_t = shift; # response type
    my $shiny_data = shift;
    my $group_id = shift;
    
    # URI HATEOAS links
    my $url = $self->query->url('-rewrite' => 1);
    my $uri = $url . "/api/group/";
    
    # Status
    if($response_t eq 'created'){
        $self->header_add('-status' => '201 Created');
        $uri .= $group_id;
    }
    elsif($response_t eq 'retrieved') {
        $self->header_add('-status' => '200 OK');
    }
    elsif($response_t eq 'updated') {
        $self->header_add('-status' => '200 OK');
        $uri .= $group_id;
    }
    else {
        die "Error: unknown response type $response_t.";
    }

    # Type & Link header
    $self->header_add('-type' => 'application/json');
    $self->header_add('-Link' => $uri);

    return encode_json($shiny_data)
}

=head2 valid_request

Checks REQUEST object for POST and PUT
and returns array:
0: Error Response or undef
1: Hash containing REQUEST data under keys:

 group_name
 group_id
 genome_list
 group_list

=cut
sub valid_request {
    my $self = shift;
    my ($reqtype, $username, $session_id, $request_data, $shiny_data) = @_;

    my $processed_data;

    if($request_data) {
        my $request = decode_json($request_data);

        if($request) {

            if($request->{user} ne $username) {
                get_logger->debug("Logged-in user does not match user in request body");
                return $self->error_response('forbidden', $shiny_data);
            }

            if($request->{CGISESSID} ne $session_id) {
                get_logger->warn("Current session ID does not match CGISESSID in request body");
            }

            unless(defined($request->{genomes}) && ref($request->{genomes}) eq 'ARRAY') {
                get_logger->debug("Invalid JSON in POST/PUT request, missing genomes field");
                return $self->error_response('bad_syntax', $shiny_data);
            }
            $processed_data->{genome_list} = $request->{genomes};

            unless($request->{group} && ref($request->{group}) eq 'HASH') {
                get_logger->debug("Invalid JSON in POST/PUT request, missing group field");
                return $self->error_response('bad_syntax', $shiny_data);
            }

            my @group_name = keys %{$request->{group}};
            if(@group_name > 1) {
                get_logger->debug("Invalid JSON in POST/PUT request, multiple groups submitted");
                return $self->error_response('bad_syntax', $shiny_data);
            }
            $processed_data->{group_name} = $group_name[0];

            unless($request->{group}->{$processed_data->{group_name}} && 
                ref($request->{group}->{$processed_data->{group_name}}) eq 'ARRAY') {
                get_logger->debug("Invalid JSON in POST/PUT request, group entry invalid");
                return $self->error_response('bad_syntax', $shiny_data);
            }
            $processed_data->{group_list} = $request->{group}->{$processed_data->{group_name}};

            # if($reqtype eq 'update') {
            #      unless($request->{group_id}) {
            #         get_logger->debug("Invalid JSON in POST request, missing group_id field");
            #         return $self->error_response('bad_syntax', $shiny_data);
            #     }
            #     $processed_data->{group_id} = $request->{group_id};
            # }

        }
        else {
            get_logger->debug("Invalid JSON in POST/PUT request");
            return $self->error_response('bad_syntax', $shiny_data);
        }

    }
    else {
        get_logger->debug("Missing POST/PUT body");
        return $self->error_response('no_data', $shiny_data);
    }

    return (0, $processed_data);
}

1;
