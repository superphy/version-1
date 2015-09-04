#!/usr/bin/env perl

use strict;
use warnings;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;

make_schema_at(
	'Database::Chado::Schema',
	{ debug => 1, 
	dump_directory => '/home/amanji/repos/computational_platform/'},
	[ 'dbi:Pg:dbname=genodo;host=localhost;port=5432', 'postgres', 'postgres',  ],
	);
