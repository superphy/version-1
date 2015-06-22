#!/usr/bin/env perl

use strict;
use warnings;
use Git::Hook::PostReceive;

my $payload = Git::Hook::PostReceive->new->read_stdin( <STDIN> );

$payload->{ref};

if($payload->{ref} eq "refs/heads/master"){
	system('git pull origin master');
}

#check to see if the hook involves a pull request
if(exists $payload->{pull_request}){
	#if the pull request is closed, this signals that merges were made and then pull
	if($payload->{pull_request}->{merged} eq 'true'){
		system('git pull origin master');
	}
}

