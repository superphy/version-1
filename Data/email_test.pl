#!/usr/bin/perl

use strict;
use warnings;
use MIME::Lite::TT::HTML;
use File::Basename qw/dirname/;

use lib dirname(__FILE__) .'/lib/';

 my %params;

 $params{first_name} = 'Matt';
 $params{last_name}  = 'W';
 $params{amt_due}    = '24.99';

 my %options;
 $options{INCLUDE_PATH} = dirname(__FILE__) .'/../App/Email/';

 my $msg = MIME::Lite::TT::HTML->new(
            From        =>  'do-not-reply@superphy.com',
            To          =>  'mdwhitesi@gmail.com',
            Subject     =>  'Not SPAM',
            Template    =>  {
                                text    =>  'test.txt.tt',
                                html    =>  'test.html.tt',
                            },
            TmplOptions =>  \%options,
            TmplParams  =>  \%params,
 );

 $msg->send;