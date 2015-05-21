use utf8;
package Database::Chado::Schema::Result::Meta;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Meta

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<meta>

=cut

__PACKAGE__->table("meta");

=head1 ACCESSORS

=head2 meta_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'meta_meta_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 format

  data_type: 'enum'
  default_value: 'undefined'
  extra: {custom_type_name => "meta_type",list => ["perl","json","undefined"]}
  is_nullable: 0

=head2 data_string

  data_type: 'text'
  is_nullable: 0

=head2 timelastmodified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "meta_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "meta_meta_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "format",
  {
    data_type => "enum",
    default_value => "undefined",
    extra => {
      custom_type_name => "meta_type",
      list => ["perl", "json", "undefined"],
    },
    is_nullable => 0,
  },
  "data_string",
  { data_type => "text", is_nullable => 0 },
  "timelastmodified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</meta_id>

=back

=cut

__PACKAGE__->set_primary_key("meta_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<meta_c1>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("meta_c1", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:3KKIjLpOZpLpyhTvOheDbQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
