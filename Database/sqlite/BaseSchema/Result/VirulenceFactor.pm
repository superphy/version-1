#!/usr/bin/env perl

package BaseSchema::Result::VirulenceFactor;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../";
use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('vf');
__PACKAGE__->add_columns(
	'name'=>{
		data_type => 'text'
	},
	'found_in'=>{
		data_type=>'text'
	},
	'vfid'=>{
		data_type=>'integer'
	}
);

__PACKAGE__->set_primary_key('vfid');
__PACKAGE__->belongs_to('Strain');
1;