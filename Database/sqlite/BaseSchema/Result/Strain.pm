#!/usr/bin/env perl

package BaseSchema::Result::Strain;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../";
use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('strain');
__PACKAGE__->add_columns(
	'name'=>{
		data_type => 'text'
	},
	'id'=>{
		data_type=>'integer'
	}
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many('Sequence','VirulenceFactor');
1;