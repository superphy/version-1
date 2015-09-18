#!/usr/bin/env perl
package Modules::Update;

# mod_rewrite alters the PATH_INFO by turning it into a file system path,
# so we repair it.
#from https://metacpan.org/module/CGI::Application::Dispatch#DISPATCH-TABLE

use strict;
use warnings;
use FindBin;
use JSON;
use lib "$FindBin::Bin/..";
use parent 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use File::Basename;

$ENV{PATH_INFO} =~ s/^$ENV{DOCUMENT_ROOT}// if defined $ENV{PATH_INFO};

#get script location via File::Basename
my $SCRIPT_LOCATION = dirname(__FILE__);

sub update : StartRunmode{
    my $self = shift;
    my $payload = $self->query->param('POSTDATA');

    my $inJSON = from_json($payload);

    #"true" values in JSON converts to 1 in perl data structure
    if(exists $inJSON->{pull_request} &&
    	exists $inJSON->{pull_request}->{merged} &&
        $inJSON->{pull_request}->{merged} eq 1){

    	my $response = `sudo git pull origin master`;

    	#response given back to the hook
    	return("Pulled new version.\n$response\n");
    }
    else{
    	return("POST request did not trigger a pull");
    }
}

1;
