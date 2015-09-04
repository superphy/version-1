use utf8;
package Database::Chado::Schema::Result::OrganismDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::OrganismDbxref

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<organism_dbxref>

=cut

__PACKAGE__->table("organism_dbxref");

=head1 ACCESSORS

=head2 organism_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'organism_dbxref_organism_dbxref_id_seq'

=head2 organism_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "organism_dbxref_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "organism_dbxref_organism_dbxref_id_seq",
  },
  "organism_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</organism_dbxref_id>

=back

=cut

__PACKAGE__->set_primary_key("organism_dbxref_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<organism_dbxref_c1>

=over 4

=item * L</organism_id>

=item * L</dbxref_id>

=back

=cut

__PACKAGE__->add_unique_constraint("organism_dbxref_c1", ["organism_id", "dbxref_id"]);

=head1 RELATIONS

=head2 dbxref

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Dbxref>

=cut

__PACKAGE__->belongs_to(
  "dbxref",
  "Database::Chado::Schema::Result::Dbxref",
  { dbxref_id => "dbxref_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

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


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WXoUM7AhVIG4S57Sl0NwGQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
