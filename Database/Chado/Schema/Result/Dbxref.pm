use utf8;
package Database::Chado::Schema::Result::Dbxref;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Dbxref

=head1 DESCRIPTION

A unique, global, public, stable identifier. Not necessarily an external reference - can reference data items inside the particular chado instance being used. Typically a row in a table can be uniquely identified with a primary identifier (called dbxref_id); a table may also have secondary identifiers (in a linking table <T>_dbxref). A dbxref is generally written as <DB>:<ACCESSION> or as <DB>:<ACCESSION>:<VERSION>.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<dbxref>

=cut

__PACKAGE__->table("dbxref");

=head1 ACCESSORS

=head2 dbxref_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'dbxref_dbxref_id_seq'

=head2 db_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 accession

  data_type: 'varchar'
  is_nullable: 0
  size: 255

The local part of the identifier. Guaranteed by the db authority to be unique for that db.

=head2 version

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "dbxref_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "dbxref_dbxref_id_seq",
  },
  "db_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "accession",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "version",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "description",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</dbxref_id>

=back

=cut

__PACKAGE__->set_primary_key("dbxref_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<dbxref_c1>

=over 4

=item * L</db_id>

=item * L</accession>

=item * L</version>

=back

=cut

__PACKAGE__->add_unique_constraint("dbxref_c1", ["db_id", "accession", "version"]);

=head1 RELATIONS

=head2 cvterm

Type: might_have

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->might_have(
  "cvterm",
  "Database::Chado::Schema::Result::Cvterm",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::CvtermDbxref>

=cut

__PACKAGE__->has_many(
  "cvterm_dbxrefs",
  "Database::Chado::Schema::Result::CvtermDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 db

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Db>

=cut

__PACKAGE__->belongs_to(
  "db",
  "Database::Chado::Schema::Result::Db",
  { db_id => "db_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 dbxrefprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Dbxrefprop>

=cut

__PACKAGE__->has_many(
  "dbxrefprops",
  "Database::Chado::Schema::Result::Dbxrefprop",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterm_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureCvtermDbxref>

=cut

__PACKAGE__->has_many(
  "feature_cvterm_dbxrefs",
  "Database::Chado::Schema::Result::FeatureCvtermDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureDbxref>

=cut

__PACKAGE__->has_many(
  "feature_dbxrefs",
  "Database::Chado::Schema::Result::FeatureDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 features

Type: has_many

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->has_many(
  "features",
  "Database::Chado::Schema::Result::Feature",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organism_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::OrganismDbxref>

=cut

__PACKAGE__->has_many(
  "organism_dbxrefs",
  "Database::Chado::Schema::Result::OrganismDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_feature_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeatureDbxref>

=cut

__PACKAGE__->has_many(
  "private_feature_dbxrefs",
  "Database::Chado::Schema::Result::PrivateFeatureDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_features

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->has_many(
  "private_features",
  "Database::Chado::Schema::Result::PrivateFeature",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::PubDbxref>

=cut

__PACKAGE__->has_many(
  "pub_dbxrefs",
  "Database::Chado::Schema::Result::PubDbxref",
  { "foreign.dbxref_id" => "self.dbxref_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WRZrFzsEE8LCcZ6FQqyxlA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
