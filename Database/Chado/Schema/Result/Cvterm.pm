use utf8;
package Database::Chado::Schema::Result::Cvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Cvterm

=head1 DESCRIPTION

A term, class, universal or type within an
ontology or controlled vocabulary.  This table is also used for
relations and properties. cvterms constitute nodes in the graph
defined by the collection of cvterms and cvterm_relationships.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cvterm>

=cut

__PACKAGE__->table("cvterm");

=head1 ACCESSORS

=head2 cvterm_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'cvterm_cvterm_id_seq'

=head2 cv_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The cv or ontology or namespace to which
this cvterm belongs.

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 1024

A concise human-readable name or
label for the cvterm. Uniquely identifies a cvterm within a cv.

=head2 definition

  data_type: 'text'
  is_nullable: 1

A human-readable text
definition.

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

Primary identifier dbxref - The
unique global OBO identifier for this cvterm.  Note that a cvterm may
have multiple secondary dbxrefs - see also table: cvterm_dbxref.

=head2 is_obsolete

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Boolean 0=false,1=true; see
GO documentation for details of obsoletion. Note that two terms with
different primary dbxrefs may exist if one is obsolete.

=head2 is_relationshiptype

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Boolean
0=false,1=true relations or relationship types (also known as Typedefs
in OBO format, or as properties or slots) form a cv/ontology in
themselves. We use this flag to indicate whether this cvterm is an
actual term/class/universal or a relation. Relations may be drawn from
the OBO Relations ontology, but are not exclusively drawn from there.

=cut

__PACKAGE__->add_columns(
  "cvterm_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "cvterm_cvterm_id_seq",
  },
  "cv_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 1024 },
  "definition",
  { data_type => "text", is_nullable => 1 },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_obsolete",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "is_relationshiptype",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cvterm_id>

=back

=cut

__PACKAGE__->set_primary_key("cvterm_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cvterm_c1>

=over 4

=item * L</name>

=item * L</cv_id>

=item * L</is_obsolete>

=back

=cut

__PACKAGE__->add_unique_constraint("cvterm_c1", ["name", "cv_id", "is_obsolete"]);

=head2 C<cvterm_c2>

=over 4

=item * L</dbxref_id>

=back

=cut

__PACKAGE__->add_unique_constraint("cvterm_c2", ["dbxref_id"]);

=head1 RELATIONS

=head2 amr_category_categories

Type: has_many

Related object: L<Database::Chado::Schema::Result::AmrCategory>

=cut

__PACKAGE__->has_many(
  "amr_category_categories",
  "Database::Chado::Schema::Result::AmrCategory",
  { "foreign.category_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 amr_category_gene_cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::AmrCategory>

=cut

__PACKAGE__->has_many(
  "amr_category_gene_cvterms",
  "Database::Chado::Schema::Result::AmrCategory",
  { "foreign.gene_cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 amr_category_parent_categories

Type: has_many

Related object: L<Database::Chado::Schema::Result::AmrCategory>

=cut

__PACKAGE__->has_many(
  "amr_category_parent_categories",
  "Database::Chado::Schema::Result::AmrCategory",
  { "foreign.parent_category_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cv

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cv>

=cut

__PACKAGE__->belongs_to(
  "cv",
  "Database::Chado::Schema::Result::Cv",
  { cv_id => "cv_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 cvprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvprop>

=cut

__PACKAGE__->has_many(
  "cvprops",
  "Database::Chado::Schema::Result::Cvprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::CvtermDbxref>

=cut

__PACKAGE__->has_many(
  "cvterm_dbxrefs",
  "Database::Chado::Schema::Result::CvtermDbxref",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_objects

Type: has_many

Related object: L<Database::Chado::Schema::Result::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_objects",
  "Database::Chado::Schema::Result::CvtermRelationship",
  { "foreign.object_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_subjects

Type: has_many

Related object: L<Database::Chado::Schema::Result::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_subjects",
  "Database::Chado::Schema::Result::CvtermRelationship",
  { "foreign.subject_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterm_relationship_types

Type: has_many

Related object: L<Database::Chado::Schema::Result::CvtermRelationship>

=cut

__PACKAGE__->has_many(
  "cvterm_relationship_types",
  "Database::Chado::Schema::Result::CvtermRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_objects

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_objects",
  "Database::Chado::Schema::Result::Cvtermpath",
  { "foreign.object_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_subjects

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_subjects",
  "Database::Chado::Schema::Result::Cvtermpath",
  { "foreign.subject_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpath_types

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpath_types",
  "Database::Chado::Schema::Result::Cvtermpath",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_cvterms",
  "Database::Chado::Schema::Result::Cvtermprop",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermprop_types

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermprop>

=cut

__PACKAGE__->has_many(
  "cvtermprop_types",
  "Database::Chado::Schema::Result::Cvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermsynonym_cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_cvterms",
  "Database::Chado::Schema::Result::Cvtermsynonym",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermsynonym_types

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermsynonym>

=cut

__PACKAGE__->has_many(
  "cvtermsynonym_types",
  "Database::Chado::Schema::Result::Cvtermsynonym",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 dbxref

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Dbxref>

=cut

__PACKAGE__->belongs_to(
  "dbxref",
  "Database::Chado::Schema::Result::Dbxref",
  { dbxref_id => "dbxref_id" },
  { is_deferrable => 1, on_delete => "SET NULL", on_update => "NO ACTION" },
);

=head2 dbxrefprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Dbxrefprop>

=cut

__PACKAGE__->has_many(
  "dbxrefprops",
  "Database::Chado::Schema::Result::Dbxrefprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvtermprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureCvtermprop>

=cut

__PACKAGE__->has_many(
  "feature_cvtermprops",
  "Database::Chado::Schema::Result::FeatureCvtermprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureCvterm>

=cut

__PACKAGE__->has_many(
  "feature_cvterms",
  "Database::Chado::Schema::Result::FeatureCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_pubprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeaturePubprop>

=cut

__PACKAGE__->has_many(
  "feature_pubprops",
  "Database::Chado::Schema::Result::FeaturePubprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationshipprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureRelationshipprop>

=cut

__PACKAGE__->has_many(
  "feature_relationshipprops",
  "Database::Chado::Schema::Result::FeatureRelationshipprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationships

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureRelationship>

=cut

__PACKAGE__->has_many(
  "feature_relationships",
  "Database::Chado::Schema::Result::FeatureRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featuremaps

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featuremap>

=cut

__PACKAGE__->has_many(
  "featuremaps",
  "Database::Chado::Schema::Result::Featuremap",
  { "foreign.unittype_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featureprop>

=cut

__PACKAGE__->has_many(
  "featureprops",
  "Database::Chado::Schema::Result::Featureprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 features

Type: has_many

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->has_many(
  "features",
  "Database::Chado::Schema::Result::Feature",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organismprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Organismprop>

=cut

__PACKAGE__->has_many(
  "organismprops",
  "Database::Chado::Schema::Result::Organismprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pripub_feature_relationships

Type: has_many

Related object: L<Database::Chado::Schema::Result::PripubFeatureRelationship>

=cut

__PACKAGE__->has_many(
  "pripub_feature_relationships",
  "Database::Chado::Schema::Result::PripubFeatureRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_feature_cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeatureCvterm>

=cut

__PACKAGE__->has_many(
  "private_feature_cvterms",
  "Database::Chado::Schema::Result::PrivateFeatureCvterm",
  { "foreign.cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_feature_relationships

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeatureRelationship>

=cut

__PACKAGE__->has_many(
  "private_feature_relationships",
  "Database::Chado::Schema::Result::PrivateFeatureRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_featureprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeatureprop>

=cut

__PACKAGE__->has_many(
  "private_featureprops",
  "Database::Chado::Schema::Result::PrivateFeatureprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_features

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->has_many(
  "private_features",
  "Database::Chado::Schema::Result::PrivateFeature",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pub_relationships

Type: has_many

Related object: L<Database::Chado::Schema::Result::PubRelationship>

=cut

__PACKAGE__->has_many(
  "pub_relationships",
  "Database::Chado::Schema::Result::PubRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubpri_feature_relationships

Type: has_many

Related object: L<Database::Chado::Schema::Result::PubpriFeatureRelationship>

=cut

__PACKAGE__->has_many(
  "pubpri_feature_relationships",
  "Database::Chado::Schema::Result::PubpriFeatureRelationship",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Pubprop>

=cut

__PACKAGE__->has_many(
  "pubprops",
  "Database::Chado::Schema::Result::Pubprop",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubs

Type: has_many

Related object: L<Database::Chado::Schema::Result::Pub>

=cut

__PACKAGE__->has_many(
  "pubs",
  "Database::Chado::Schema::Result::Pub",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 synonyms

Type: has_many

Related object: L<Database::Chado::Schema::Result::Synonym>

=cut

__PACKAGE__->has_many(
  "synonyms",
  "Database::Chado::Schema::Result::Synonym",
  { "foreign.type_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vf_category_categories

Type: has_many

Related object: L<Database::Chado::Schema::Result::VfCategory>

=cut

__PACKAGE__->has_many(
  "vf_category_categories",
  "Database::Chado::Schema::Result::VfCategory",
  { "foreign.category_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vf_category_gene_cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::VfCategory>

=cut

__PACKAGE__->has_many(
  "vf_category_gene_cvterms",
  "Database::Chado::Schema::Result::VfCategory",
  { "foreign.gene_cvterm_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 vf_category_parent_categories

Type: has_many

Related object: L<Database::Chado::Schema::Result::VfCategory>

=cut

__PACKAGE__->has_many(
  "vf_category_parent_categories",
  "Database::Chado::Schema::Result::VfCategory",
  { "foreign.parent_category_id" => "self.cvterm_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1fJBH6LF/8JPNknxV22lvA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
