use utf8;
package Database::Chado::Schema::Result::AccessoryRegion;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::AccessoryRegion

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<accessory_region>

=cut

__PACKAGE__->table("accessory_region");

=head1 ACCESSORS

=head2 accessory_region_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'accessory_region_accessory_region_id_seq'

=head2 pangenome_region_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 aln_column

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "accessory_region_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "accessory_region_accessory_region_id_seq",
  },
  "pangenome_region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "aln_column",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</accessory_region_id>

=back

=cut

__PACKAGE__->set_primary_key("accessory_region_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<accessory_region_c1>

=over 4

=item * L</pangenome_region_id>

=back

=cut

__PACKAGE__->add_unique_constraint("accessory_region_c1", ["pangenome_region_id"]);

=head2 C<accessory_region_c2>

=over 4

=item * L</aln_column>

=back

=cut

__PACKAGE__->add_unique_constraint("accessory_region_c2", ["aln_column"]);

=head1 RELATIONS

=head2 pangenome_region

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "pangenome_region",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "pangenome_region_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:R2RlycIzwobabVKo8Z+vmA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
