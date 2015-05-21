#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../";
use Modules::Dispatch;

$ENV{PATH_INFO} =~ s/^$ENV{DOCUMENT_ROOT}// if defined $ENV{PATH_INFO};

Modules::Dispatch->dispatch();

1;
