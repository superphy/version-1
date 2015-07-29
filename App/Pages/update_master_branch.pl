#!/usr/bin/env perl

use strict;
use warnings;
use JSON;

#use STDIN for the input
open(my $inFH, '<-') or die "Could not open STDIN\n $!";
my $fileContents= join('', $inFH->getlines());

my $inJSON = from_json($fileContents);

#"true" values in JSON converts to 1 in perl data structure
if(exists $inJSON->{pull_request} && 
	exists $inJSON->{pull_request}->{merged} &&
    $inJSON->{pull_request}->{merged} eq 1){
	system('git pull origin master');
}

