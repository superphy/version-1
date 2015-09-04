use utf8;
package Database::Chado::Schema::Result::FeatureRelationshippropPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeatureRelationshippropPub - Provenance for feature_relationshipprop.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature_relationshipprop_pub>

=cut

__PACKAGE__->table("feature_relationshipprop_pub");

=head1 ACCESSORS

=head2 feature_relationshipprop_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq'

=head2 feature_relationshipprop_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_relationshipprop_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_relationshipprop_pub_feature_relationshipprop_pub_i_seq",
  },
  "feature_relationshipprop_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_relationshipprop_pub_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_relationshipprop_pub_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_relationshipprop_pub_c1>

=over 4

=item * L</feature_relationshipprop_id>

=item * L</pub_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "feature_relationshipprop_pub_c1",
  ["feature_relationshipprop_id", "pub_id"],
);

=head1 RELATIONS

=head2 feature_relationshipprop

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::FeatureRelationshipprop>

=cut

__PACKAGE__->belongs_to(
  "feature_relationshipprop",
  "Database::Chado::Schema::Result::FeatureRelationshipprop",
  { feature_relationshipprop_id => "feature_relationshipprop_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 pub

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "Database::Chado::Schema::Result::Pub",
  { pub_id => "pub_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VQUpW1CWaKOAPXUgzdUDrA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
