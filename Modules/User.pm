#!/usr/bin/env perl

package Modules::User;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Carp qw/croak carp/;
use CGI::Application::Plugin::ValidateRM;
use CGI::Application::Plugin::AutoRunmode;
use Data::FormValidator::Constraints qw(email FV_eq_with FV_length_between);
use Digest::MD5 qw(md5_base64);
use Log::Log4perl qw/get_logger/;
use Email::Simple;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS;

my $logger = get_logger();

my $dbic;

sub setup {
	my $self = shift;

	$dbic = $self->dbixSchema;

	$self->authen->protected_runmodes(
		qw(edit_account update_account add_access create_access edit_access update_access)
	);

}

=head2 logout

Currently a logout is only triggered when a authen_logout param is caught. This method provides another
mechanism of logging out by specifying a logout run-mode.

=cut 

sub logout : Runmode {
	my $self = shift;

	$self->authen->logout;

	$self->redirect( $self->home_page );
}

sub hello : Runmode {
	my $self = shift;
	my $template = $self->load_tmpl( 'hello.tmpl', die_on_bad_params => 0 );
	return $template->output();
}

=head2 edit_account

Display page to allow user to edit/update user info.

Requires authentication, and is therefore a protected run-mode.

=cut 

sub edit_account : Runmode {
	my $self = shift;
	my $errs = shift;

	my $t = $self->load_tmpl( 'user_form.tmpl', die_on_bad_params => 0 );

	# Retrieve existing user data from database
	my $user_rs =
	  $self->dbixSchema->resultset('Login')
	  ->find( { username => $self->authen->username } );

	croak 'User not found in database'
	  unless $user_rs; # should not happen because user is already authenticated

	# populate template with current field values
	my $fields = &_user_fields;
	foreach my $field ( keys %$fields ) {
		next if $field eq 'u_password';    # leave password field blank

		my $column = $fields->{$field};
		$t->param( $field, $user_rs->$column );
	}

	$t->param( rm    => '/user/update_account' );
	$t->param( title => 'My Account' );
	$t->param($errs) if $errs;             # created by rm update
	$t->output;
}

=head2 update

Update user account.  Return to user form page if there are errors.

=cut

sub update_account : Runmode {
	my $self = shift;

	# Prepare rules for edit user form
	my $rules = &_dfv_common_rules;    # Builds on general rules for form

	$rules->{required} =
	  [qw(u_first_name u_last_name u_email)];    # required fields
	$rules->{dependency_groups}->{password_group} =
	  [qw/u_password password_confirm/]
	  ;    # password can be both black or both filled in

	# Validate user_form for update operation
	my $dfv_results = $self->check_rm( 'edit_account', $rules )
	  || return $self->check_rm_error_page;

	# No errors, update user acount
	my $q      = $self->query;
	my $fields = &_user_fields;

	my $username = $self->authen->username;
	my $user_rs =
	  $dbic->resultset('Login')->find( { $fields->{u_username} => $username } )
	  or croak "Username $username not found in database ($!).\n";

	foreach my $field ( keys %$fields ) {

		next if $field eq 'u_username';    # Cannot update username
		next if $q->param($field) eq "";  # Skip empty fields, nothing to update
		croak "Invalid edit account form field $field.\n"
		  unless $dfv_results->valid($field);

		my $value = $q->param($field);

		if ( $field eq 'u_password' ) {

			#Encode password
			$user_rs->set_column( $fields->{$field}, _encode_password($value) );
		}
		else {
			$user_rs->set_column( $fields->{$field}, $value );
		}
	}

	# Update record in DB
	$user_rs->update
	  or croak "Update of user information in database failed ($!).\n";

	$self->session->param( status => '<strong>Success!</strong> Account updated.' );
	$self->redirect( $self->home_page );
}

=head2 new_account

Display page to allow user to create account.  If user is logged in, they will be sent to the edit page.

=cut 

sub new_account : StartRunmode {
	my $self = shift;
	my $errs = shift
	  ; # errors will be passed from run-mode create (forcing user to try again)

	$logger->debug('Displaying new account form.');

	if ( $self->authen->is_authenticated ) {

		# User is logged in. Forward to the edit page
		return $self->edit_account;
	}

	my $t = $self->load_tmpl( 'user_form.tmpl', die_on_bad_params => 0 );

	$t->param( new_user => 1 )
	  ; # The same form is used to create and edit user accounts, this param sets up new account view in template.
	$t->param( rm    => '/user/create_account' );
	$t->param( title => 'My Account' );
	$t->param($errs) if $errs;    # errors from run-mode create
	$t->output;
}

=head2 create_account

Create new user account.  Return to user form page if there are errors.

=cut 

sub create_account : Runmode {
	my $self = shift;

	$logger->debug('Initiating a user creation.');

	# Prepare rules for new user form
	my $rules = &_dfv_common_rules;    # Builds on general rules for form

	$rules->{required} = [
		qw(u_username u_password password_confirm u_first_name u_last_name u_email)
	];

	$rules->{constraint_methods}->{u_username} =
	  [ \&_valid_username, \&_username_does_not_exist, ];

	$rules->{msgs}->{constraints}->{username_does_not_exist} =
	  'username exists';

	# Validate user_form for create operation
	my $dfv_results = $self->check_rm( 'new_account', $rules )
	  || return $self->check_rm_error_page;

	# No errors, create user acount
	my $q      = $self->query;
	my $fields = &_user_fields;
	my %create_hash;
	foreach my $field ( keys %$fields ) {
		croak "Missing new account form field $field.\n"
		  if $q->param($field) eq ""
		;    # There should be no empty fields at this point, but just in case
		croak "Invalid new account form field $field.\n"
		  unless $dfv_results->valid($field);
		my $value = $q->param($field);

		if ( $field eq 'u_password' ) {

			#Encode password
			$create_hash{ $fields->{$field} } = _encode_password($value);
		}
		else {
			$create_hash{ $fields->{$field} } = $value;
		}
	}

	# Insert into DB
	$dbic->resultset('Login')->create( \%create_hash )
	  or croak "Insertion of new user into database failed ($!).\n";

	# Login automatically for user
	my $a                          = $self->authen;
	my $authentication_form_params = $a->credentials;
	$q->param( $authentication_form_params->[0] => $q->param('u_username') );
	$q->param( $authentication_form_params->[1] => $q->param('u_password') );
	$a->{initialized} = 0;    # force reinitialization, hence storage of login
	$a->initialize;
	$self->session->param(
		status => '<strong>Success!</strong> Account created.'
	);

	# Go to main page
	$self->redirect( $self->home_page );
}

=head2 forgot_password 

Display page for forgotten password

=cut

sub forgot_password : RunMode {
	my $self = shift;
	my $errs = shift;

	my $t =
	  $self->load_tmpl( 'forgot_password_form.tmpl', die_on_bad_params => 0 );
	$t->param( rm    => '/user/email_password' );
	$t->param( title => 'Forgot Password' );
	$t->param($errs) if $errs;    # created by run-mode email_password
	$t->output

}

=head2 email_password 

Email user new password. Return to forgot password page if there are errors.

=cut

sub email_password : RunMode {
	my $self = shift;

	# Validate forgot password form
	my $results =
	  $self->check_rm( 'forgot_password', &_dfv_forgot_password_rules )
	  || return $self->check_rm_error_page;

	# Obtain exisiting password, revert to this password if operation fails
	my $username = $self->query->param('u_username');
	my $user_rs = $dbic->resultset('Login')->find( { username => $username } )
	  or croak "Username $username not found in database ($!).\n";

	my $existing_password = $user_rs->password;

	# Generate a new password and set user password to new value
	my $new_password = &_new_password;
	$user_rs->password( _encode_password($new_password) );
	$user_rs->update
	  or croak "Unable to update password for user $username ($!).\n";

	# Send email with new password to user
	
	my $transport = Email::Sender::Transport::SMTP::TLS->new(
	    host     => 'smtp.gmail.com',
	    port     => 587,
	    username => $self->config_param('mail.address'),
	    password => $self->config_param('mail.pass'),
	);
	
	my $message = Email::Simple->create(
	    header => [
	        From           => $self->config_param('mail.address'),
	        To             => $user_rs->email,
	        Subject        => 'SuperPhy password reset',
	        'Content-Type' => 'text/html'
	    ],
	    body => '<html>Your new password is: <b>'
		  . $new_password . '</b>'
		  . '<br><br>You may want to change your password to something more memorable after you log in.'
		  . '<br><br>SuperPhy Team.'
		  . '</html>',
	);
	
	sendmail( $message, {transport => $transport} );

	$self->session->param( status =>
		'<strong>Check your Email!</strong> A new password has been sent to your email address.'
	);

	$self->redirect( $self->home_page );
}

=head2 add_access

Display page to allow user to add permissions for other users on THEIR uploaded sequences.

Requires authentication, and is therefore a protected run-mode.

=cut

sub add_access : RunMode {
	my $self = shift;
	my $errs = shift;

	croak 'User cannot change upload access unless logged in.'
	  unless $self->authen->is_authenticated;

	# should not happen because this is a protected run-mode
	my $t = $self->load_tmpl('add_user_access_form.tmpl', die_on_bad_params => 0, loop_context_vars => 1);

	# Retrieve uploaded entries from database for this user
	# Only get entries that have 'share' permissions
	my $upload_rs = $self->dbixSchema->resultset('Upload')->search(
		{
			'permissions.can_share'     => 1,
			'login.username'            => $self->authen->username,
			'type.name'                 => 'contig_collection',
		},
		{
			join => [
				{ 'permissions'      => 'login' },
				{ 'private_features' => 'type' }
			],
			columns   => [qw/me.upload_id me.tag me.upload_date/],
			'+select' => [qw/private_features.uniquename/],
			'+as'     => [qw/name/],
		}
	);

	# Group upload entries by tag
	my %form_hash;
	while ( my $upload_row = $upload_rs->next ) {

		my $group_nm = ( $upload_row->tag eq '' ) ? 'Uncategorized' : $upload_row->tag;
		$form_hash{$group_nm} = [] unless defined $form_hash{$group_nm};
		push @{ $form_hash{$group_nm} },
		  {
			name => $upload_row->get_column('name'),
			date => _strip_time( $upload_row->upload_date ),
			uid  => $upload_row->upload_id
		  };
	}

	# Convert to loops for template
	my @form_list;
	foreach my $group ( keys %form_hash ) {
		push @form_list,
		  { group_name => $group, group_rows => $form_hash{$group} };
	}
	$t->param( uploads => \@form_list );

	# User has no sequences
	# Redirect to home page with status message indicating problem
	unless ( scalar @form_list ) {
		$self->session->param( status => '<strong>No Genomes!</strong> You have not uploaded any genome sequences or been granted Administrator access to other uploaded genome sequences.');
		$self->redirect( $self->home_page );
	}

	$t->param( rm    => '/user/create_access' );
	$t->param( title => 'Grant access to uploaded sequences' );
	$t->param($errs) if $errs;    # created by rm update_access
	$t->output;
}

=head2 create_access

Create new access setting for a user.  Return to form page if there are errors.

=cut 
sub create_access : Runmode {
	my $self = shift;

	# Validate add access form
	my $results = $self->check_rm( 'add_access', &_dfv_add_access_rules )
		|| return $self->check_rm_error_page;

	# No errors, create user access

	# Did not check to see if access already exists in permission table
	# Use update_or_create to update any existing rows that match users request
	my $q    = $self->query;
	my $dbix = $self->dbixSchema;

	my $target_user = $q->param('a_username');
	my $user_rs = $dbix->resultset('Login')->search( { username => $target_user }, { columns => [qw/login_id/] } ) 
		or croak "Username $target_user not found in database ($!).\n";

	my $target_login_id = $user_rs->first()->login_id;

	my @uploads = $q->param('a_sequence');
	my ( $can_share, $can_modify ) = _db_permission_settings($q->param('a_perm'));

	# Checks if combination of upload_id, login_id is in permission table (called constraint 'permission_c1' in schema)
	# Updates if is, creates otherwise.
	my $num_updated = my $num_created = 0;
	foreach my $upload_id (@uploads) {
		my $perm = $dbix->resultset('Permission')->update_or_new(
			{
				upload_id  => $upload_id,
				login_id   => $target_login_id,
				can_share  => $can_share,
				can_modify => $can_modify
			},
			{ key => 'permission_c1' }
		);

		# Check if this permission already existed in permission table
		# If so, update performed. If not, permission created.
		if ( $perm->in_storage ) {
			$num_updated++;
		}
		else {
			$perm->insert;
			$num_created++;
		}
	}

	$self->session->param( status =>
		  '<strong>Success!</strong> User has been granted access to sequence.'
	);
	$self->redirect( $self->home_page );
}

=head2 edit_access

Display page to allow user to edit/delete permissions for other users on THEIR uploaded sequences.

Requires authentication, and is therefore a protected run-mode.

=cut

sub edit_access : RunMode {
	my $self = shift;
	my $errs = shift;

	croak 'User cannot edit upload access unless logged in.' unless $self->authen->is_authenticated;
	# should not happen because this is a protected run-mode

	my $t = $self->load_tmpl(
		'edit_user_access_form.tmpl',
		die_on_bad_params => 0,
		loop_context_vars => 1
	);

	# Retrieve upload entries that user has control over, joined with the users that have access to those upload entries
	my $upload_rs = $self->dbixSchema->resultset('Upload')->search(
		{
			'permissions_2.can_share'   => 1,
			'login_2.username'          => $self->authen->username,
			'login.username'            => { '!=', $self->authen->username },
			'type.name'                 => 'contig_collection',
		},
		{
			join => [
				{ 'permissions'          => 'login' },
				{ 'permissions'          => 'login' },
				{ 'private_features'     => 'type' }
			],
			columns   => [qw/me.upload_id me.tag me.upload_date/],
			'+select' => [qw/login.username permissions.permission_id permissions.can_modify permissions.can_share private_features.uniquename/],
			'+as'    => [qw/username permission_id modify share name/],
		}
	);

	# Group upload entries by username, then by tag
	my %form_hash;
	while ( my $upload_row = $upload_rs->next ) {

		my $group_nm = ( $upload_row->tag eq '' ) ? 'Uncategorized' : $upload_row->tag;
		my $user = $upload_row->get_column('username');

		$form_hash{$user}->{groups}->{$group_nm} = [] unless defined $form_hash{$user}->{groups}->{$group_nm};
		$form_hash{$user}->{num_genomes}++;
		
		my $perm = _permission_descriptor($upload_row->get_column('share'), $upload_row->get_column('modify'));
	
		push @{ $form_hash{$user}->{groups}->{$group_nm} },
		  {
			name   => $upload_row->get_column('name'),
			date   => _strip_time( $upload_row->upload_date ),
			target_id    => $upload_row->get_column('permission_id'),
			admin  => ($perm eq 'admin') ? 1:0,
			modify => ($perm eq 'modify') ? 1:0,
			view => ($perm eq 'view') ? 1:0,
			sequence_id => $form_hash{$user}->{num_genomes}
		  };
	}

	# Convert to loops for template
	my @form_list;
	my $group_id = 0; # global unique id for groups in form
	foreach my $user ( keys %form_hash ) {
		my @form_user_block;
		foreach my $group ( keys %{ $form_hash{$user}->{groups} } ) {
			push @form_user_block, { group_name => $group, group_id => ++$group_id, group_rows => $form_hash{$user}->{groups}->{$group} };
		}
		push @form_list,
		  {
			target_user        => $user,
			target_num_genomes => $form_hash{$user}->{num_genomes},
			target_rows        => \@form_user_block,
			rm                 => '/user/update_access'
		  };
	}

	$t->param( uploads => \@form_list );

	# User has no sequences
	# Redirect to home page with status message indicating problem
	unless ( scalar @form_list ) {
		$self->session->param( status => '<strong>No Access Permissions Set!</strong> You have not created any access permissions to your uploaded genomes.'.
			'<br/><br/>Use <span class="text-info">Genome Submission > Grant access to an uploaded genome</span> to give a user access to an uploaded genome.');
		$self->redirect( $self->home_page );
	}
	
	# Give user indication of success
	my $status = 0;
	$status = $self->param('update_status') if $self->param('update_status');
	if($self->session->param('update_status')) {
		$status = $self->session->param('update_status');
		$self->session->clear('update_status');
	}    				
	$t->param( update_status => $status );

	$t->param( go_home => $self->home_page );
	$t->param( title   => 'Modify or delete access to uploaded sequences' );
	$t->param($errs) if $errs;    # created by rm update_access
	$t->output;
}

=head2 update_access

Update/delete existing setting for a user.  Die if there are errors (there shouldnt be because the form is all radio buttons)

=cut 

sub update_access : Runmode {
	my $self = shift;
	
	croak 'User cannot submit changes to upload access unless logged in.' unless $self->authen->is_authenticated;
	# should not happen because this is a protected run-mode

	# The access for one user should have been submitted
	# This could include multiple uploads

	# Validate manually
	# The user can't really screw anything up, the form is all radio buttons and hidden inputs.
	# If they set nothing, its still valid. If form is invalid, its on our end.

	my $q = $self->query;

	my $num_genomes   = $q->param('c_num_genomes');

	# The number of genomes in the user's set.
	# There should be a matching number of c_perm and c_target parameters submitted.

	# Die instead of return to the form page.
	# If these parameters are missing, it means the form was not created properly.
	croak 'Missing hidden parameter c_num_genomes from the edit user access form.' unless $num_genomes;

	# Get the admin users login_id for verification
	my $dbix = $self->dbixSchema;
	my $admin_id = $dbix->resultset('Login')->find({'username' => $self->authen->username})->login_id;

	# Iterate through each genome setting for the user and update entry in permission table
	for ( my $i = 1 ; $i <= $num_genomes ; $i++ ) {

		my $this_upload_access = 'c_target' . $i;
		my $pid         = $q->param($this_upload_access);
		croak "Missing hidden parameter $this_upload_access in the edit user access form." unless defined $pid;

		my $this_perm = 'c_perm' . $i . '_'. $pid;
		my $perm      = $q->param($this_perm);
		croak "Missing parameter $this_perm in the edit user access form." unless $perm;
		
		my $permission_row = $dbix->resultset('Permission')->find( { permission_id => $pid } );
		croak "Permission table entry corresponding to permission_id $pid not found." unless $permission_row;
		
		# Safety Check! Verify that admin user has access to this upload.
		# Only way this would be violated is if the admin user faked a post submission with permission_ids not accessible to them.
		# Better safe than sorry, especially when the admin user can delete rows.
		$dbix->resultset('Permission')->find(
			{
				login_id  => $admin_id,
				upload_id => $permission_row->upload_id,
				can_share => 1
			}
		) or croak "Access violation! User ",$self->authen->username," does not have admin access on upload ID ",$permission_row->upload_id,"\n";

		if ( $perm eq 'remove' ) {
			# Delete access
			$permission_row->delete or croak "Deletion of permission table row failed.";

		} else {
			# Update existing access
			my ( $can_share, $can_modify ) = _db_permission_settings($perm);
			
			$permission_row->update( { can_share => $can_share, can_modify => $can_modify } ) or croak "Update of permission table row failed.";
		}
	}

	# Redirect back to edit access form, making it easier for user to edit multiple access settings
	$self->session->param( update_status => '<strong>Success!</strong> User access has been updated.' );
	$self->redirect('/user/edit_access');
}

###########
## Methods to validate user form
###########

=head2 _dfv_common_rules

Update and new account form must satisfy these rules

=cut

sub _dfv_common_rules {
	return {
		filters            => [qw(trim strip)],
		constraint_methods => {
			u_password       => FV_length_between( 6, 10 ),
			password_confirm => FV_eq_with('u_password'),
			u_first_name     => \&_valid_name,
			u_last_name      => \&_valid_name,
			u_email          => email(),
		},
		msgs => {
			format      => '<span class="help-inline"><span class="text-error"><strong>%s</strong></span></span>',
			any_errors  => 'some_errors',
			prefix      => 'err_',
			constraints => {
				'eq_with'        => 'passwords must match',
				'length_between' => 'character count',
			}
		},
	};
}

=head2 _valid_name 

Valid names can have ' - . spaces and letters are valid, e.g.,  First   Last-withHyphen Jr.

=cut

sub _valid_name {
	my $name = pop;

	return $name =~ /^[a-zA-Z' \.-]{1,30}$/;
}

=head2 _valid_username 

Valid usernames can be at most 20 alphanumeric chars (incl _);

=cut

sub _valid_username {
	my ( $dfv, $u_username ) = @_;

	$u_username =~ /^\w{1,20}$/;
}

=head2 _username_does_not_exist 

Search DB for existing username. Note: setup() sets global $dbic to current dbix::class:schema object

=cut

sub _username_does_not_exist {
	my ( $dfv, $u_username ) = @_;

	$dfv->name_this('username_does_not_exist');

	my $rv = $dbic->resultset('Login')->find( { username => $u_username } );

	return ( !defined($rv) );

}

=head2 _user_fields

Maps user form params to login table columns
	
=cut

sub _user_fields {
	return {
		u_username   => 'username',
		u_password   => 'password',
		u_first_name => 'firstname',
		u_last_name  => 'lastname',
		u_email      => 'email'
	};
}

=head2 _encode_password 

Encode password

=cut

sub _encode_password {
	my ($new_val) = @_;

	return md5_base64($new_val);
}

=head2 _username_exists 

Search DB for existing username. Note: setup() sets global $dbic to current dbix::class:schema object

=cut

sub _username_exists {
	my ( $dfv, $u_username ) = @_;

	$dfv->name_this('username_exists');

	my $rv = $dbic->resultset('Login')->find( { username => $u_username } );

	return ( defined($rv) );
}

=head2 _new_password 

Generate random password for users that have forgotten their password.

=cut

sub _new_password {
	my @chars = (
		'a' .. 'k', 'm',        'n', 'p' .. 'z',
		'2' .. '9', '!',        '@', '#',
		'$',        '%',        '&', '*',
		'-',        'A' .. 'N', 'P' .. 'Z'
	);    # skip confusing 1,l,o,0
	my $password = '';
	for ( 0 .. 7 ) {
		$password .= $chars[ int rand @chars ];
	}
	return $password;
}

=head2 _dfv_forgot_password_rules

Forgot password form must satisfy these rules

=cut

sub _dfv_forgot_password_rules {
	return {
		required => [qw(u_username)],
		filters  => 'trim',
		constraint_methods =>
		  { u_username => [ \&_valid_username, \&_username_exists, ], },
		msgs => {
			format      => '<span class="help-inline"><span class="text-error"><strong>%s</strong></span></span>',
			prefix      => 'err_',
			constraints => { username_exists => 'username does not exist' }
		},
	};
}

=head2 _dfv_add_access_rules

Add user access form must satisfy these rules

=cut

sub _dfv_add_access_rules {
	return {
		required => [qw(a_username a_sequence a_perm)],
		filters  => 'trim',
		constraint_methods =>
		  { a_username => [ \&_valid_username, \&_username_exists, ], },
		msgs => {
			format      => '<span class="help-inline"><span class="text-error"><strong>%s</strong></span></span>',
			prefix      => 'err_',
			constraints => { username_exists => 'username does not exist' }
		},
	};
}

=head2 _strip_time

Remove the time from a date time string returned by DB query

=cut

sub _strip_time {
	my $datetime = shift;

	$datetime =~ m/(\d{4}\-\d{2}\-\d{2}) /;

	return $1;
}

=head2 _db_permission_settings

Change verbal description of permission (i.e. view, modify, admin)
to db can_modify, can_share column settings

=cut

sub _db_permission_settings {
	my $perm = shift;

	my ($can_share, $can_modify);

	if ($perm eq 'view') {
		$can_share = $can_modify = 0;

	} elsif( $perm eq 'modify') {
		$can_share  = 0;
		$can_modify = 1;

	} else {
		$can_share  = 1;
		$can_modify = 1;

	}
	
	return($can_share, $can_modify);
}

=head2 _permission_descriptor

Change db can_modify, can_share column settings into
verbal description of permission (i.e. view, modify, admin)

=cut

sub _permission_descriptor {
	my ($can_share, $can_modify) = @_;
	
	if($can_modify && $can_share) {
		return 'admin'
	} elsif($can_modify && !$can_share) {
		return 'modify'
	} elsif($can_share && !$can_modify){
		croak "Violation of permission scheme (can_share implies can_modify).";
	} else {
		return 'view'
	}
}

1;
