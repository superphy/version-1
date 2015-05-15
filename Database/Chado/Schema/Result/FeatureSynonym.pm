use utf8;
package Database::Chado::Schema::Result::FeatureSynonym;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeatureSynonym - Linking table between feature and synonym.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature_synonym>

=cut

__PACKAGE__->table("feature_synonym");

=head1 ACCESSORS

=head2 feature_synonym_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_synonym_feature_synonym_id_seq'

=head2 synonym_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The pub_id link is for relating the usage of a given synonym to the publication in which it was used.

=head2 is_current

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

The is_current boolean indicates whether the linked synonym is the  current -official- symbol for the linked feature.

=head2 is_internal

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

Typically a synonym exists so that somebody querying the db with an obsolete name can find the object theyre looking for (under its current name.  If the synonym has been used publicly and deliberately (e.g. in a paper), it may also be listed in reports as a synonym. If the synonym was not used deliberately (e.g. there was a typo which went public), then the is_internal boolean may be set to -true- so that it is known that the synonym is -internal- and should be queryable but should not be listed in reports as a valid synonym.

=cut

__PACKAGE__->add_columns(
  "feature_synonym_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_synonym_feature_synonym_id_seq",
  },
  "synonym_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_current",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_internal",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_synonym_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_synonym_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_synonym_c1>

=over 4

=item * L</synonym_id>

=item * L</feature_id>

=item * L</pub_id>

=back

=cut

__PACKAGE__->add_unique_constraint("feature_synonym_c1", ["synonym_id", "feature_id", "pub_id"]);

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

=head2 synonym

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Synonym>

=cut

__PACKAGE__->belongs_to(
  "synonym",
  "Database::Chado::Schema::Result::Synonym",
  { synonym_id => "synonym_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cSEpdXfgvtVTDCgD6+7YOA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
