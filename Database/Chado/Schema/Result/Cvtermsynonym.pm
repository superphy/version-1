use utf8;
package Database::Chado::Schema::Result::Cvtermsynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Cvtermsynonym

=head1 DESCRIPTION

A cvterm actually represents a
distinct class or concept. A concept can be refered to by different
phrases or names. In addition to the primary name (cvterm.name) there
can be a number of alternative aliases or synonyms. For example, "T
cell" as a synonym for "T lymphocyte".

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cvtermsynonym>

=cut

__PACKAGE__->table("cvtermsynonym");

=head1 ACCESSORS

=head2 cvtermsynonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'cvtermsynonym_cvtermsynonym_id_seq'

=head2 cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 synonym

  data_type: 'varchar'
  is_nullable: 0
  size: 1024

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

A synonym can be exact,
narrower, or broader than.

=cut

__PACKAGE__->add_columns(
  "cvtermsynonym_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "cvtermsynonym_cvtermsynonym_id_seq",
  },
  "cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "synonym",
  { data_type => "varchar", is_nullable => 0, size => 1024 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cvtermsynonym_id>

=back

=cut

__PACKAGE__->set_primary_key("cvtermsynonym_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cvtermsynonym_c1>

=over 4

=item * L</cvterm_id>

=item * L</synonym>

=back

=cut

__PACKAGE__->add_unique_constraint("cvtermsynonym_c1", ["cvterm_id", "synonym"]);

=head1 RELATIONS

=head2 cvterm

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "cvterm",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "cvterm_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 type

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "type",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "type_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jBJ865uea6WS6Ecl2/zbnw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
