use utf8;
package Database::Chado::Schema::Result::Cvprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Cvprop

=head1 DESCRIPTION

Additional extensible properties can be attached to a cv using this table.  A notable example would be the cv version

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cvprop>

=cut

__PACKAGE__->table("cvprop");

=head1 ACCESSORS

=head2 cvprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'cvprop_cvprop_id_seq'

=head2 cv_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The name of the property or slot is a cvterm. The meaning of the property is defined in that cvterm.

=head2 value

  data_type: 'text'
  is_nullable: 1

The value of the property, represented as text. Numeric values are converted to their text representation.

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Property-Value ordering. Any
cv can have multiple values for any particular property type -
these are ordered in a list using rank, counting from zero. For
properties that are single-valued rather than multi-valued, the
default 0 value should be used.

=cut

__PACKAGE__->add_columns(
  "cvprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "cvprop_cvprop_id_seq",
  },
  "cv_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cvprop_id>

=back

=cut

__PACKAGE__->set_primary_key("cvprop_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cvprop_c1>

=over 4

=item * L</cv_id>

=item * L</type_id>

=item * L</rank>

=back

=cut

__PACKAGE__->add_unique_constraint("cvprop_c1", ["cv_id", "type_id", "rank"]);

=head1 RELATIONS

=head2 cv

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cv>

=cut

__PACKAGE__->belongs_to(
  "cv",
  "Database::Chado::Schema::Result::Cv",
  { cv_id => "cv_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 type

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bF8H/4yJ9H+tAnJb6C9SQg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
