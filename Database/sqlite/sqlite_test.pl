#!/usr/bin/env perl

use strict;
use warnings;
use BaseSchema;

my $schema = BaseSchema->connect('dbi:SQLite:testvf.db');

my $newName = $schema->resultset('Strain')->create(
	'name'=>"Testus bacterius",
	'id'=>'1'
);

$newName->update();
