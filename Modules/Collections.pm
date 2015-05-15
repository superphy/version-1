#!/usr/bin/env perl

=pod

=head1 NAME

Modules::Collection

=head1 SNYNOPSIS

=head1 DESCRIPTION

Run-mode to handle requests for user-defined strain groups.

Run-mode methods return the following JSON Response fields:

{ success: boolean, error: string, ...  }

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

package Modules::Collections;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Modules::FormDataGenerator;
use HTML::Template::HashWrapper;
use CGI::Application::Plugin::AutoRunmode;
use Scalar::Util qw/looks_like_number/;
use JSON::Any;
use Log::Log4perl qw/get_logger/;
use Modules::GenomeWarden;


=head2 setup

Run-mode initialization

=cut
sub setup {
	my $self = shift;

	# Logger
	my $logger = Log::Log4perl->get_logger();
	$logger->info("Initializing Modules::Collections");

	# This is a AJAX module and needs to work as part of larger page.
	# Allow unathenticated users to reach server, but then
	# send JSON error rather than redirecting them to the
	# login page.
	# 
	# $self->authen->protected_runmodes(
	# 	qw/create/
	# );

}

=head2 update

Save changes to existing group

=cut
sub update : Runmode {
	my $self = shift;

	# User needs to be logged in to change groups
	unless($self->authen->is_authenticated) {
		return $self->failed_response("User not logged in");
	}
	my $username = $self->authen->username;
	

	# Params
	my $q = $self->query();

	# Group ID, required
	my $group_id = $q->param('group_id');
	unless($group_id) {
		return $self->failed_response("Parameter 'group_id' missing");
	}

	# Group strains, optional
	my @genomes = $q->param('genome');

	# Group name, optional
	my $group_name = $q->param('name');
	
	# Group description, optional 
	my $group_desc = $q->param('description');

	# Category name, optional
	my $category_name = $q->param('category');

	# Update requested genomes/properties for group
	my $changes_made = 0;
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);

	# Update the set of genomes for group
	if(@genomes) {

		# Validate genomes
		my $warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, genomes => \@genomes, user => $username, cvmemory => $self->cvmemory);
		my ($err, $bad1, $bad2) = $warden->error; 

		if($err) {
	 		# User requested invalid strains or strains that they do not have permission to view
	 		return $self->failed_response('Access violation for uploaded genomes: '.join(', ',@$bad1, @$bad2));
	 	}
	 	
		# Update group genomes
		my $success = $data->updateGroupMembers($warden, {
			group_id => $group_id,
			username => $username
		});

		unless($success) {
			return $self->failed_response("Update of group genomes failed. Is group ID $group_id correct?");
		}

		$changes_made = 1;
	}

	# Update the group properties
	if($group_name || $group_desc || $category_name) {
		my $params = {
			group_id => $group_id,
			username => $username
		};

		$params->{description} = $group_desc if $group_desc;
		$params->{name} = $group_name if $group_name;
		$params->{category} = $category_name if $category_name;

		# Update group
		my $success = $data->updateGroupProperties($params);
		unless($success) {
			return $self->failed_response("Update of group properties failed. Is group ID $group_id correct?");
		}

		$changes_made = 1;
	}


	if($changes_made) {
		# Success, return group ID
		return $self->successful_response($data, $username, { group_id => $group_id });

	} else {
		# Error
		return $self->failed_response('Group update failed. No changes made.');
	}

}

=head2 create

Create new group & collection if it doesn't
exist.

=cut
sub create : Runmode {
	my $self = shift;

	# User needs to be logged in to create groups
	unless($self->authen->is_authenticated) {
		return $self->failed_response("User not logged in");
	}
	my $username = $self->authen->username;
	

	# Params
	my $q = $self->query();

	# Group name, required
	my $group_name = $q->param('name');
	unless($group_name) {
		return $self->failed_response("Parameter 'name' missing");
	}

	# Group strains, required
	my @genomes = $q->param('genome');

	print STDERR @genomes;
	
	unless(@genomes) {
		return $self->failed_response("Parameter 'genome' missing");
	}

	# Group description, optional 
	my $group_desc = $q->param('description');

	# Collection name, optional
	my $category = $q->param('category');

	# Validate genomes
	my $warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, genomes => \@genomes, user => $username, cvmemory => $self->cvmemory);
	my ($err, $bad1, $bad2) = $warden->error; 

	if($err) {
 		# User requested invalid strains or strains that they do not have permission to view
 		return $self->failed_response('Access violation for uploaded genomes: '.join(', ',@$bad1, @$bad2));
 	}
 	
	# Create group
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);
	my $grp_id = $data->createGroup($warden, {
		name => $group_name,
		username => $username,
		category => $category,
		description => $group_desc,
	});
	
	if($grp_id) {
		# Success, return new group ID
		return $self->successful_response($data, $username, { group_id => $grp_id });

	} else {
		# Error
		return $self->failed_response('Group creation failed. Is group name unique?');
	}

}

=head2 delete

Delete existing group, and remove collection
if empty.

=cut
sub delete : Runmode {
	my $self = shift;

	# User needs to be logged in to delete groups
	unless($self->authen->is_authenticated) {
		return $self->failed_response("User not logged in");
	}
	my $username = $self->authen->username;
	

	# Params
	my $q = $self->query();

	# Group ID, required
	my $group_id = $q->param('group_id');
	unless($group_id) {
		return $self->failed_response("Parameter 'group_id' missing");
	}

	# Delete group
	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);

	my $success = $data->updateGroupMembers(undef, {
		group_id => $group_id,
		username => $username
	});



	if($success) {
		return $self->successful_response($data, $username, { group_id => $group_id });

	} else {
		# Error
		return $self->failed_response("Deletion of group failed. Is group ID $group_id correct?");
	}
}

=head2 update_category

NOT IMPLEMENTED

Change name of existing group category

Note: This is a special case for update.
To change the category that a group is in, use update().
The update() method will create new group categories or rename
an existing category as needed when a group is re-assigned to a new
category.
This method only changes group_category name for all the groups
in the category.

=cut
sub update_category : Runmode {
	my $self = shift;

	return $self->failed_response("Method not implemented");

	# User needs to be logged in to change categories
	unless($self->authen->is_authenticated) {
		return $self->failed_response("User not logged in");
	}
	my $username = $self->authen->username;
	

	# Params
	my $q = $self->query();

	# Category, required
	my $category_name = $q->param('category');
	unless($category_name) {
		return $self->failed_response("Parameter 'category' missing");
	}

	# New category name, required
	my $new_category_name = $q->param('new');
	unless($new_category_name) {
		return $self->failed_response("Parameter 'new' missing");
	}

	# Update category name
	return $self->failed_response("New category name is not different") 
		if $category_name eq $new_category_name;


	my $data = Modules::FormDataGenerator->new(dbixSchema => $self->dbixSchema, cvmemory => $self->cvmemory);

	my $params = {
		username => $username
	};


	# if($success) {
		

	# } else {
	# 	# Error
	# 	return $self->failed_response("Update of category name failed. Is the category name $category_name correct?");
	# }

}

=head2 successful_response

JSON response from Collections method.

response JSON object contains:
  success: 1
  error: none
  group_id: GroupID
  groups: JSON object containing group hierarchy (returned by Modules::FormDataGenerator::userGroups)
  public_genomes: JSON object containing public genome meta-data and group assignments (returned by Modules::FormDataGenerator::genomeInfo)
  private_genomes: JSON object containing private genome meta-data and group assignments (returned by Modules::FormDataGenerator::genomeInfo)

=cut
sub successful_response {
	my $self = shift;
	my $data = shift;
	my $username = shift;
	my $other_values = shift;

	my $groups_json = $data->userGroups($username);
	my ($public_json, $private_json) = $data->genomeInfo($username);

	$private_json = $private_json ? $private_json : '{}';

	my @response_values = (
		'"success": 1',
		'"error": "none"',
		'"groups": '.$groups_json,
		'"public_genomes": '.$public_json,
		'"private_genomes": '.$private_json
	);

	if($other_values) {
		foreach my $k (keys %$other_values) {
			my $v = $other_values->{$k};
			unless(looks_like_number($v)) {
				$v = "\"$v\"";
			}
			push @response_values, "\"$k\": $v"
		}
	}
	
	# Set response header type
	$self->header_add('-type' => 'application/json');

	return "{\n" . join(",\n", @response_values) . "\n}";
}

=head2 failed_response

JSON response from Collections method.

response JSON object contains:
  success: 0
  error: "error_message"
  
=cut
sub failed_response {
	my $self = shift;
	my $message = shift;

	my @response_values = (
		'"success": 0',
		'"error": '."\"$message\""
	);
	
	# Set response header type
	$self->header_add('-type' => 'application/json');

	return "{\n" . join(",\n", @response_values) . "\n}";
}


1;