use utf8;
package Database::Chado::Schema::Result::PubpriFeatureRelationship;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PubpriFeatureRelationship

=head1 DESCRIPTION

A mirror of the feature_relationship table.
 Only difference is that this table maps subject features in the feature table to object features in the private_feature table.  See
comments on feature_relationship table for more information.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<pubpri_feature_relationship>

=cut

__PACKAGE__->table("pubpri_feature_relationship");

=head1 ACCESSORS

=head2 feature_relationship_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'pubpri_feature_relationship_feature_relationship_id_seq'

=head2 subject_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 object_id

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
  "feature_relationship_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pubpri_feature_relationship_feature_relationship_id_seq",
  },
  "subject_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "object_id",
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

=item * L</feature_relationship_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_relationship_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<pubpri_feature_relationship_c1>

=over 4

=item * L</subject_id>

=item * L</object_id>

=item * L</type_id>

=item * L</rank>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "pubpri_feature_relationship_c1",
  ["subject_id", "object_id", "type_id", "rank"],
);

=head1 RELATIONS

=head2 object

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->belongs_to(
  "object",
  "Database::Chado::Schema::Result::PrivateFeature",
  { feature_id => "object_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 subject

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "subject",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "subject_id" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cHpQttPozpo7imf8omzZUQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
