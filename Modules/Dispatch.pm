#!/usr/bin/env perl
package Modules::Dispatch;

# mod_rewrite alters the PATH_INFO by turning it into a file system path,
# so we repair it.
#from https://metacpan.org/module/CGI::Application::Dispatch#DISPATCH-TABLE

$ENV{PATH_INFO} =~ s/^$ENV{DOCUMENT_ROOT}// if defined $ENV{PATH_INFO};

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use parent qw/CGI::Application::Dispatch/;
use File::Basename;

#get script location via File::Basename
my $SCRIPT_LOCATION = dirname(__FILE__);


sub dispatch_args {
    return {
        prefix  => 'Modules',
        args_to_new=>{
            TMPL_PATH=>"$SCRIPT_LOCATION/../App/Templates/"
        },
        table   => [
            # SHINY RESTful API routing
            'api/group[post]'             => { app => 'Shiny', rm => 'create_group'},
            'api/group/:group_id[put]'     => { app => 'Shiny', rm => 'update_group'},
            'api/group[get]'              => { app => 'Shiny', rm => 'groups'},
            # REGULAR routing
            '/update_master'      => {app => 'Update', rm => 'update'},
            'user/login'          => { app => 'User', rm => 'authen_login' },
            ':app/:rm'            => { },
            'test'                => { app => 'User', rm => 'hello' },
			'/hello' =>     {app=>'Home' , rm=>'default'},
            '/home' =>      {app=>'Home', rm=>'home'}
        ],
    };
}

1;
