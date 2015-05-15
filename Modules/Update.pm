#!/usr/bin/env perl
package Modules::Update;

# mod_rewrite alters the PATH_INFO by turning it into a file system path,
# so we repair it.
#from https://metacpan.org/module/CGI::Application::Dispatch#DISPATCH-TABLE

$ENV{PATH_INFO} =~ s/^$ENV{DOCUMENT_ROOT}// if defined $ENV{PATH_INFO};

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use parent 'CGI::Application';
use CGI::Application::Plugin::AutoRunmode;
use File::Basename;

#get script location via File::Basename
my $SCRIPT_LOCATION = dirname(__FILE__);


sub update : StartRunmode{
	system($SCRIPT_LOCATION . '/../App/Pages/update_master_branch.pl');
    return 1;
}


1;
