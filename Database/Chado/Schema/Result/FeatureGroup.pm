use utf8;
package Database::Chado::Schema::Result::FeatureGroup;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeatureGroup

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature_group>

=cut

__PACKAGE__->table("feature_group");

=head1 ACCESSORS

=head2 feature_group_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_group_feature_group_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 genome_group_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_group_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_group_feature_group_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "genome_group_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_group_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_group_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_group_c1>

=over 4

=item * L</feature_id>

=item * L</genome_group_id>

=back

=cut

__PACKAGE__->add_unique_constraint("feature_group_c1", ["feature_id", "genome_group_id"]);

=head1 RELATIONS

=head2 feature

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "feature_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 genome_group

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::GenomeGroup>

=cut

__PACKAGE__->belongs_to(
  "genome_group",
  "Database::Chado::Schema::Result::GenomeGroup",
  { genome_group_id => "genome_group_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CcJ4J149ZOxD+RXdbG49zQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
