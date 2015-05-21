use utf8;
package Database::Chado::Schema::Result::GenomeGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::GenomeGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<genome_group>

=cut

__PACKAGE__->table("genome_group");

=head1 ACCESSORS

=head2 genome_group_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'genome_group_genome_group_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 200

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 category_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 standard

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=head2 standard_value

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "genome_group_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "genome_group_genome_group_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 200 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "standard",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "standard_value",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</genome_group_id>

=back

=cut

__PACKAGE__->set_primary_key("genome_group_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<genome_group_c1>

=over 4

=item * L</username>

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("genome_group_c1", ["username", "name"]);

=head1 RELATIONS

=head2 category

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::GroupCategory>

=cut

__PACKAGE__->belongs_to(
  "category",
  "Database::Chado::Schema::Result::GroupCategory",
  { group_category_id => "category_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 feature_groups

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureGroup>

=cut

__PACKAGE__->has_many(
  "feature_groups",
  "Database::Chado::Schema::Result::FeatureGroup",
  { "foreign.genome_group_id" => "self.genome_group_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_feature_groups

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeatureGroup>

=cut

__PACKAGE__->has_many(
  "private_feature_groups",
  "Database::Chado::Schema::Result::PrivateFeatureGroup",
  { "foreign.genome_group_id" => "self.genome_group_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:te/9oPC+WGEtuE7XoEnJYw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
