#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Config::Simple;
use Email::Simple;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS;
use DBI;
use Try::Tiny;

=head1 NAME

$0 - Sends various email notifications from the web-server node

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config          INI style config file containing DB connection parameters
 --notify          An integer indicating which email to send out
 

=head1 DESCRIPTION



=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# Globals
my ($config, $notify,
    $sender_address, $mail_notification_address, $transport, $test_user,
    $dbh);

GetOptions(
	'config=s' => \$config,
    'notify=i' => \$notify,
    'test=i' => \$test_user
) 
or pod2usage(-verbose => 1, -exitval => 1);

die "You must supply a configuration filename" unless $config;
die "You must supply a notification value" unless $notify;

# SQL
# Genomes
use constant FIND_GENOMES => qq/SELECT tracker_id, login_id, feature_name FROM tracker WHERE step = ? AND failed = FALSE/;
use constant UPDATE_GENOME => qq/UPDATE tracker SET step = ? WHERE tracker_id = ?/;
use constant FAIL_GENOME => qq/UPDATE tracker SET failed = TRUE WHERE tracker_id = ?/;

# Users
use constant GET_EMAIL => qq/SELECT email FROM login WHERE login_id = ?/;

# Globals
my $update_step_sth;
my %tracker_step_values = (
	pending => 1,
	processing => 2,
	completed => 3,
	notified => 4
);

### RUN ###

init($config);

email_notification($notify);

### SUBS ###

sub init {
	my $config_file = shift; 
	
	# Process config file;
	my $conf;
	unless($conf = new Config::Simple($config_file)) {
		die Config::Simple->error();
	}
	my $dbstring = 'dbi:Pg:dbname='.$conf->param('db.name').
	            ';port='.$conf->param('db.port').
	            ';host='.$conf->param('db.host');
	my $dbuser = $conf->param('db.user');
	my $dbpass = $conf->param('db.pass');
	die "Invalid configuration file. Missing db parameters." unless $dbuser;
	
	my $mail_address = $conf->param('mail.address');
	my $mail_pass = $conf->param('mail.pass');
	$mail_notification_address = $mail_address;
	$sender_address = $mail_address;
	die "Invalid configuration file. Missing email parameters." unless $mail_address;
	
	# Connect to db
	$dbh = DBI->connect(
		$dbstring,
		$dbuser,
		$dbpass,
		{
			AutoCommit => 1,
		}
	) or die "Unable to connect to database";
	
	# Setup emailer
	$transport = Email::Sender::Transport::SMTP::TLS->new(
		host     => 'smtp.gmail.com',
		port     => 587,
		username => $mail_address,
		password => $mail_pass,
	);

}

sub email_notification {
	my $notification = shift;
	
	
	if($notification == 1) {
		
		# Send error notification to admin
		my $message = Email::Simple->create(
		    header => [
		        From           => $sender_address,
		        To             => $mail_notification_address,
		        Subject        => 'SuperPhy Pipeline Abnormal Termination',
		        'Content-Type' => 'text/plain'
		    ],
		    body => "SuperPhy pipeline died on: ".localtime()."\nCheck log file <log_dir>/pipeline.log on for details.\n\n",
		);
		
		sendmail( $message, {transport => $transport} );
		
	} elsif($notification == 2) {
		# Send success notification to each user that uploaded sequence and analysis is available
		
		# Obtain list of current uploaded sequences
		my $find_sth = $dbh->prepare(FIND_GENOMES);
		my $update_sth = $dbh->prepare(UPDATE_GENOME);
		my $fail_sth = $dbh->prepare(FAIL_GENOME);
		my $email_sth = $dbh->prepare(GET_EMAIL);
		
		$find_sth->execute($tracker_step_values{completed});
		
		while (my ($tracker_id, $login_id, $genome_name) = $find_sth->fetchrow_array) {
			
			# Retrieve user email address
			$email_sth->execute($login_id);
			my ($user_address) = $email_sth->fetchrow_array();
			
			
			# Send email
			my $message = Email::Simple->create(
			    header => [
			        From           => $sender_address,
			        To             => $user_address,
			        Subject        => 'SuperPhy results available',
			        'Content-Type' => 'text/plain'
			    ],
			    body => "The SuperPhy analysis of your uploaded genome $genome_name (tracking ID $tracker_id) has completed and results are available from http://lfz.corefacility.ca/superphy\n\nSuperPhy Team\n".
			    	localtime()."\n",
			);
			
			eval {
	  			sendmail( $message, {transport => $transport} );
			};
			if($@) {
	    		warn "[ERROR] sending email for $tracker_id failed: $@";
	    		$fail_sth->execute($tracker_id);
			}
			
			$update_sth->execute($tracker_step_values{notified}, $tracker_id);
		}
	}
	elsif($notification == 3) {
		# Send test email to specific user
                
                my $email_sth = $dbh->prepare(GET_EMAIL);
		$email_sth->execute($test_user);
	        my ($user_address) = $email_sth->fetchrow_array();

		die "[ERROR] invalid login_id $test_user. No email associated with account" unless $user_address;

                # Send email
		my $message = Email::Simple->create(
                            header => [
                                From           => $sender_address,
                                To             => $user_address,
                                Subject        => 'SuperPhy email system test',
                                'Content-Type' => 'text/plain'
                            ],
                            body => "Hi, If you received this email, the SuperPhy email system works!!\n\nSuperPhy Team\n".
                                localtime()."\n",
                        );

                eval {
                        sendmail( $message, {transport => $transport} );
                };
                if($@) {
                        warn "[ERROR] sending email for $test_user failed: $@";
                }

	}
}

