use utf8;
package Database::Chado::Schema::Result::VfCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::VfCategory - Table that maps VF category type_ids to gene feature_ids

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<vf_category>

=cut

__PACKAGE__->table("vf_category");

=head1 ACCESSORS

=head2 vf_category_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'vf_category_vf_category_id_seq'

=head2 parent_category_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 category_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Cvterm_id for category.
Is a foreign key to the Cvterm table.

=head2 gene_cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Cvterm_id for vf gene. 
Is a foregn key to the Cvterm table.

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

Stores the feature_id for each VF gene. Is a foreign key to the feature table. Maps to cvterm_id from the feature_cvterm table.

=cut

__PACKAGE__->add_columns(
  "vf_category_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "vf_category_vf_category_id_seq",
  },
  "parent_category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "gene_cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</vf_category_id>

=back

=cut

__PACKAGE__->set_primary_key("vf_category_id");

=head1 RELATIONS

=head2 category

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "category",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "category_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 feature

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "feature_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

=head2 gene_cvterm

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "gene_cvterm",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "gene_cvterm_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 parent_category

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "parent_category",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "parent_category_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:516XePOc15znyvAlzG1TWw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
