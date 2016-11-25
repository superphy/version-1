#!/usr/bin/env perl
package Modules::Dispatch;

# mod_rewrite alters the PATH_INFO by turning it into a file system path,
# so we repair it.
#from https://metacpan.org/module/CGI::Application::Dispatch#DISPATCH-TABLE

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use parent qw/CGI::Application::Dispatch/;
use File::Basename;

$ENV{PATH_INFO} =~ s/^$ENV{DOCUMENT_ROOT}// if defined $ENV{PATH_INFO};


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
            # 'api/group[post]'             => { app => 'Shiny', rm => 'create_group'},
            # 'api/group/:group_id[put]'     => { app => 'Shiny', rm => 'update_group'},
            # 'api/group[get]'              => { app => 'Shiny', rm => 'groups'},
            # # REGULAR routing
            # '/update_master'      => {app => 'Update', rm => 'update'},
            # 'user/login'          => { app => 'User', rm => 'authen_login' },
            # ''                    => { app=>'Home', rm=>'home' },
            # '/home'               => { app=>'Home', rm=>'home' },
            # ':app/:rm'            => { }

            ':app/*'            => { app => 'Maintenance', rm=>'maintenance'}
           
        ],
    };
}

1;
