use utf8;
package Database::Chado::Schema::Result::FeatureRelationshipprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeatureRelationshipprop

=head1 DESCRIPTION

Extensible properties
for feature_relationships. Analagous structure to featureprop. This
table is largely optional and not used with a high frequency. Typical
scenarios may be if one wishes to attach additional data to a
feature_relationship - for example to say that the
feature_relationship is only true in certain contexts.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature_relationshipprop>

=cut

__PACKAGE__->table("feature_relationshipprop");

=head1 ACCESSORS

=head2 feature_relationshipprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_relationshipprop_feature_relationshipprop_id_seq'

=head2 feature_relationship_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The name of the
property/slot is a cvterm. The meaning of the property is defined in
that cvterm. Currently there is no standard ontology for
feature_relationship property types.

=head2 value

  data_type: 'text'
  is_nullable: 1

The value of the
property, represented as text. Numeric values are converted to their
text representation. This is less efficient than using native database
types, but is easier to query.

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Property-Value
ordering. Any feature_relationship can have multiple values for any particular
property type - these are ordered in a list using rank, counting from
zero. For properties that are single-valued rather than multi-valued,
the default 0 value should be used.

=cut

__PACKAGE__->add_columns(
  "feature_relationshipprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_relationshipprop_feature_relationshipprop_id_seq",
  },
  "feature_relationship_id",
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

=item * L</feature_relationshipprop_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_relationshipprop_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_relationshipprop_c1>

=over 4

=item * L</feature_relationship_id>

=item * L</type_id>

=item * L</rank>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "feature_relationshipprop_c1",
  ["feature_relationship_id", "type_id", "rank"],
);

=head1 RELATIONS

=head2 feature_relationship

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::FeatureRelationship>

=cut

__PACKAGE__->belongs_to(
  "feature_relationship",
  "Database::Chado::Schema::Result::FeatureRelationship",
  { feature_relationship_id => "feature_relationship_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 feature_relationshipprop_pubs

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureRelationshippropPub>

=cut

__PACKAGE__->has_many(
  "feature_relationshipprop_pubs",
  "Database::Chado::Schema::Result::FeatureRelationshippropPub",
  {
    "foreign.feature_relationshipprop_id" => "self.feature_relationshipprop_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
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


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TtFbkn7FetAuhkBYzI9eHw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
