use utf8;
package Database::Chado::Schema::Result::Organismprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Organismprop - Tag-value properties - follows standard chado model.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<organismprop>

=cut

__PACKAGE__->table("organismprop");

=head1 ACCESSORS

=head2 organismprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'organismprop_organismprop_id_seq'

=head2 organism_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 value

  data_type: 'text'
  is_nullable: 1

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "organismprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "organismprop_organismprop_id_seq",
  },
  "organism_id",
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

=item * L</organismprop_id>

=back

=cut

__PACKAGE__->set_primary_key("organismprop_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<organismprop_c1>

=over 4

=item * L</organism_id>

=item * L</type_id>

=item * L</rank>

=back

=cut

__PACKAGE__->add_unique_constraint("organismprop_c1", ["organism_id", "type_id", "rank"]);

=head1 RELATIONS

=head2 organism

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "Database::Chado::Schema::Result::Organism",
  { organism_id => "organism_id" },
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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QFkelhRR2s4k9cxDhwVl/g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
