use utf8;
package Database::Chado::Schema::Result::PrivateFeatureDbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PrivateFeatureDbxref

=head1 DESCRIPTION

A mirror of the feature_dbxref table.
 Only difference is that this table references features in the private_feature table.  See
comments on feature_dbxref table for more information.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<private_feature_dbxref>

=cut

__PACKAGE__->table("private_feature_dbxref");

=head1 ACCESSORS

=head2 feature_dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'private_feature_dbxref_feature_dbxref_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 is_current

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_dbxref_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "private_feature_dbxref_feature_dbxref_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_current",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_dbxref_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_dbxref_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<private_feature_dbxref_c1>

=over 4

=item * L</feature_id>

=item * L</dbxref_id>

=back

=cut

__PACKAGE__->add_unique_constraint("private_feature_dbxref_c1", ["feature_id", "dbxref_id"]);

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

=head2 feature

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "Database::Chado::Schema::Result::PrivateFeature",
  { feature_id => "feature_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:OwJssoHC7b8I7IAhkk/uew


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
