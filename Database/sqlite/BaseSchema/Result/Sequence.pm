#!/usr/bin/env perl

package BaseSchema::Result::Sequence;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../";
use parent qw/DBIx::Class::Core/;

__PACKAGE__->table('sequence');
__PACKAGE__->add_columns(
	'sequence'=>{
		data_type => 'text'
	},
	'type'=>{
		data_type=>'text'
	},
	'seqid'=>{
		data_type=>'integer'
	}
);

__PACKAGE__->set_primary_key('seqid');
__PACKAGE__->belongs_to('Strain');
1;