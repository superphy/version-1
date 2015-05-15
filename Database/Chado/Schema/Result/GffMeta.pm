use utf8;
package Database::Chado::Schema::Result::GffMeta;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::GffMeta

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<gff_meta>

=cut

__PACKAGE__->table("gff_meta");

=head1 ACCESSORS

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 hostname

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 starttime

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "hostname",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "starttime",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CqBHueBFz7sshKVaFa2BGg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
