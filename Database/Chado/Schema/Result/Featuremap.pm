use utf8;
package Database::Chado::Schema::Result::Featuremap;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Featuremap

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<featuremap>

=cut

__PACKAGE__->table("featuremap");

=head1 ACCESSORS

=head2 featuremap_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'featuremap_featuremap_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 unittype_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "featuremap_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "featuremap_featuremap_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "unittype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</featuremap_id>

=back

=cut

__PACKAGE__->set_primary_key("featuremap_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<featuremap_c1>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("featuremap_c1", ["name"]);

=head1 RELATIONS

=head2 featuremap_pubs

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeaturemapPub>

=cut

__PACKAGE__->has_many(
  "featuremap_pubs",
  "Database::Chado::Schema::Result::FeaturemapPub",
  { "foreign.featuremap_id" => "self.featuremap_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurepos

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurepo>

=cut

__PACKAGE__->has_many(
  "featurepos",
  "Database::Chado::Schema::Result::Featurepo",
  { "foreign.featuremap_id" => "self.featuremap_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureranges

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurerange>

=cut

__PACKAGE__->has_many(
  "featureranges",
  "Database::Chado::Schema::Result::Featurerange",
  { "foreign.featuremap_id" => "self.featuremap_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 unittype

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "unittype",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "unittype_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FqWYq8TuJln7fH0+pIVunw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
