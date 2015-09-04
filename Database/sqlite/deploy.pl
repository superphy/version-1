#!/usr/bin/env/perl

use strict;
use warnings;
use BaseSchema;
use SQL::Translator;

#SQL::Translator is required for deploy

#from cpan:
#deploy
#Arguments: \%sqlt_args, $dir
#Attempts to deploy the schema to the current storage using SQL::Translator.
#See "METHODS" in SQL::Translator for a list of values for \%sqlt_args. The most common value for this would be { add_drop_table => 1 } to have the SQL produced include a DROP TABLE statement for each table created. For quoting purposes supply quote_table_names and quote_field_names.
#Additionally, the DBIx::Class parser accepts a sources parameter as a hash ref or an array ref, containing a list of source to deploy. If present, then only the sources listed will get deployed. Furthermore, you can use the add_fk_index parser parameter to prevent the parser from creating an index for each FK.

my $schema = BaseSchema->connect('dbi:SQLite:testvf.db');
$schema->deploy({add_drop_table=>0,add_fk_index=>0});
print $schema->deployment_statements();