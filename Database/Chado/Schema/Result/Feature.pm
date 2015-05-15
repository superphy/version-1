use utf8;
package Database::Chado::Schema::Result::Feature;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Feature

=head1 DESCRIPTION

A feature is a biological sequence or a
section of a biological sequence, or a collection of such
sections. Examples include genes, exons, transcripts, regulatory
regions, polypeptides, protein domains, chromosome sequences, sequence
variations, cross-genome match regions such as hits and HSPs and so
on; see the Sequence Ontology for more. The combination of
organism_id, uniquename and type_id should be unique.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature>

=cut

__PACKAGE__->table("feature");

=head1 ACCESSORS

=head2 feature_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_feature_id_seq'

=head2 dbxref_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

An optional primary public stable
identifier for this feature. Secondary identifiers and external
dbxrefs go in the table feature_dbxref.

=head2 organism_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The organism to which this feature
belongs. This column is mandatory.

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

The optional human-readable common name for
a feature, for display purposes.

=head2 uniquename

  data_type: 'text'
  is_nullable: 0

The unique name for a feature; may
not be necessarily be particularly human-readable, although this is
preferred. This name must be unique for this type of feature within
this organism.

=head2 residues

  data_type: 'text'
  is_nullable: 1

A sequence of alphabetic characters
representing biological residues (nucleic acids, amino acids). This
column does not need to be manifested for all features; it is optional
for features such as exons where the residues can be derived from the
featureloc. It is recommended that the value for this column be
manifested for features which may may non-contiguous sublocations (e.g.
transcripts), since derivation at query time is non-trivial. For
expressed sequence, the DNA sequence should be used rather than the
RNA sequence. The default storage method for the residues column is
EXTERNAL, which will store it uncompressed to make substring operations
faster.

=head2 seqlen

  data_type: 'integer'
  is_nullable: 1

The length of the residue feature. See
column:residues. This column is partially redundant with the residues
column, and also with featureloc. This column is required because the
location may be unknown and the residue sequence may not be
manifested, yet it may be desirable to store and query the length of
the feature. The seqlen should always be manifested where the length
of the sequence is known.

=head2 md5checksum

  data_type: 'char'
  is_nullable: 1
  size: 32

The 32-character checksum of the sequence,
calculated using the MD5 algorithm. This is practically guaranteed to
be unique for any feature. This column thus acts as a unique
identifier on the mathematical sequence.

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

A required reference to a table:cvterm
giving the feature type. This will typically be a Sequence Ontology
identifier. This column is thus used to subclass the feature table.

=head2 is_analysis

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

Boolean indicating whether this
feature is annotated or the result of an automated analysis. Analysis
results also use the companalysis module. Note that the dividing line
between analysis and annotation may be fuzzy, this should be determined on
a per-project basis in a consistent manner. One requirement is that
there should only be one non-analysis version of each wild-type gene
feature in a genome, whereas the same gene feature can be predicted
multiple times in different analyses.

=head2 is_obsolete

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

Boolean indicating whether this
feature has been obsoleted. Some chado instances may choose to simply
remove the feature altogether, others may choose to keep an obsolete
row in the table.

=head2 timeaccessioned

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.

=head2 timelastmodified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

For handling object
accession or modification timestamps (as opposed to database auditing data,
handled elsewhere). The expectation is that these fields would be
available to software interacting with chado.

=cut

__PACKAGE__->add_columns(
  "feature_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_feature_id_seq",
  },
  "dbxref_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "organism_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "uniquename",
  { data_type => "text", is_nullable => 0 },
  "residues",
  { data_type => "text", is_nullable => 1 },
  "seqlen",
  { data_type => "integer", is_nullable => 1 },
  "md5checksum",
  { data_type => "char", is_nullable => 1, size => 32 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_analysis",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_obsolete",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "timeaccessioned",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "timelastmodified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_c1>

=over 4

=item * L</organism_id>

=item * L</uniquename>

=item * L</type_id>

=back

=cut

__PACKAGE__->add_unique_constraint("feature_c1", ["organism_id", "uniquename", "type_id"]);

=head1 RELATIONS

=head2 accessory_region

Type: might_have

Related object: L<Database::Chado::Schema::Result::AccessoryRegion>

=cut

__PACKAGE__->might_have(
  "accessory_region",
  "Database::Chado::Schema::Result::AccessoryRegion",
  { "foreign.pangenome_region_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 amr_categories

Type: has_many

Related object: L<Database::Chado::Schema::Result::AmrCategory>

=cut

__PACKAGE__->has_many(
  "amr_categories",
  "Database::Chado::Schema::Result::AmrCategory",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 contig_footprints

Type: has_many

Related object: L<Database::Chado::Schema::Result::ContigFootprint>

=cut

__PACKAGE__->has_many(
  "contig_footprints",
  "Database::Chado::Schema::Result::ContigFootprint",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 core_region

Type: might_have

Related object: L<Database::Chado::Schema::Result::CoreRegion>

=cut

__PACKAGE__->might_have(
  "core_region",
  "Database::Chado::Schema::Result::CoreRegion",
  { "foreign.pangenome_region_id" => "self.feature_id" },
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
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "NO ACTION",
  },
);

=head2 feature_cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureCvterm>

=cut

__PACKAGE__->has_many(
  "feature_cvterms",
  "Database::Chado::Schema::Result::FeatureCvterm",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureDbxref>

=cut

__PACKAGE__->has_many(
  "feature_dbxrefs",
  "Database::Chado::Schema::Result::FeatureDbxref",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_groups

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureGroup>

=cut

__PACKAGE__->has_many(
  "feature_groups",
  "Database::Chado::Schema::Result::FeatureGroup",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_pubs

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeaturePub>

=cut

__PACKAGE__->has_many(
  "feature_pubs",
  "Database::Chado::Schema::Result::FeaturePub",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationship_objects

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureRelationship>

=cut

__PACKAGE__->has_many(
  "feature_relationship_objects",
  "Database::Chado::Schema::Result::FeatureRelationship",
  { "foreign.object_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_relationship_subjects

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureRelationship>

=cut

__PACKAGE__->has_many(
  "feature_relationship_subjects",
  "Database::Chado::Schema::Result::FeatureRelationship",
  { "foreign.subject_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_synonyms

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureSynonym>

=cut

__PACKAGE__->has_many(
  "feature_synonyms",
  "Database::Chado::Schema::Result::FeatureSynonym",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 feature_trees

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureTree>

=cut

__PACKAGE__->has_many(
  "feature_trees",
  "Database::Chado::Schema::Result::FeatureTree",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureloc_features

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featureloc>

=cut

__PACKAGE__->has_many(
  "featureloc_features",
  "Database::Chado::Schema::Result::Featureloc",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureloc_srcfeatures

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featureloc>

=cut

__PACKAGE__->has_many(
  "featureloc_srcfeatures",
  "Database::Chado::Schema::Result::Featureloc",
  { "foreign.srcfeature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurepos_features

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurepo>

=cut

__PACKAGE__->has_many(
  "featurepos_features",
  "Database::Chado::Schema::Result::Featurepo",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurepos_map_features

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurepo>

=cut

__PACKAGE__->has_many(
  "featurepos_map_features",
  "Database::Chado::Schema::Result::Featurepo",
  { "foreign.map_feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featureprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featureprop>

=cut

__PACKAGE__->has_many(
  "featureprops",
  "Database::Chado::Schema::Result::Featureprop",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_features

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_features",
  "Database::Chado::Schema::Result::Featurerange",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_leftendfs

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_leftendfs",
  "Database::Chado::Schema::Result::Featurerange",
  { "foreign.leftendf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_leftstartfs

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_leftstartfs",
  "Database::Chado::Schema::Result::Featurerange",
  { "foreign.leftstartf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_rightendfs

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_rightendfs",
  "Database::Chado::Schema::Result::Featurerange",
  { "foreign.rightendf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 featurerange_rightstartfs

Type: has_many

Related object: L<Database::Chado::Schema::Result::Featurerange>

=cut

__PACKAGE__->has_many(
  "featurerange_rightstartfs",
  "Database::Chado::Schema::Result::Featurerange",
  { "foreign.rightstartf_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 gap_position_contig_collections

Type: has_many

Related object: L<Database::Chado::Schema::Result::GapPosition>

=cut

__PACKAGE__->has_many(
  "gap_position_contig_collections",
  "Database::Chado::Schema::Result::GapPosition",
  { "foreign.contig_collection_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 gap_position_contigs

Type: has_many

Related object: L<Database::Chado::Schema::Result::GapPosition>

=cut

__PACKAGE__->has_many(
  "gap_position_contigs",
  "Database::Chado::Schema::Result::GapPosition",
  { "foreign.contig_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 gap_position_loci

Type: has_many

Related object: L<Database::Chado::Schema::Result::GapPosition>

=cut

__PACKAGE__->has_many(
  "gap_position_loci",
  "Database::Chado::Schema::Result::GapPosition",
  { "foreign.locus_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 gap_position_pangenome_regions

Type: has_many

Related object: L<Database::Chado::Schema::Result::GapPosition>

=cut

__PACKAGE__->has_many(
  "gap_position_pangenome_regions",
  "Database::Chado::Schema::Result::GapPosition",
  { "foreign.pangenome_region_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 genome_locations

Type: has_many

Related object: L<Database::Chado::Schema::Result::GenomeLocation>

=cut

__PACKAGE__->has_many(
  "genome_locations",
  "Database::Chado::Schema::Result::GenomeLocation",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 organism

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Organism>

=cut

__PACKAGE__->belongs_to(
  "organism",
  "Database::Chado::Schema::Result::Organism",
  { organism_id => "organism_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 pripub_feature_relationships

Type: has_many

Related object: L<Database::Chado::Schema::Result::PripubFeatureRelationship>

=cut

__PACKAGE__->has_many(
  "pripub_feature_relationships",
  "Database::Chado::Schema::Result::PripubFeatureRelationship",
  { "foreign.object_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_gap_positions

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateGapPosition>

=cut

__PACKAGE__->has_many(
  "private_gap_positions",
  "Database::Chado::Schema::Result::PrivateGapPosition",
  { "foreign.pangenome_region_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_snp_positions

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateSnpPosition>

=cut

__PACKAGE__->has_many(
  "private_snp_positions",
  "Database::Chado::Schema::Result::PrivateSnpPosition",
  { "foreign.pangenome_region_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 pubpri_feature_relationships

Type: has_many

Related object: L<Database::Chado::Schema::Result::PubpriFeatureRelationship>

=cut

__PACKAGE__->has_many(
  "pubpri_feature_relationships",
  "Database::Chado::Schema::Result::PubpriFeatureRelationship",
  { "foreign.subject_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 raw_amr_datas

Type: has_many

Related object: L<Database::Chado::Schema::Result::RawAmrData>

=cut

__PACKAGE__->has_many(
  "raw_amr_datas",
  "Database::Chado::Schema::Result::RawAmrData",
  { "foreign.gene_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 raw_virulence_datas

Type: has_many

Related object: L<Database::Chado::Schema::Result::RawVirulenceData>

=cut

__PACKAGE__->has_many(
  "raw_virulence_datas",
  "Database::Chado::Schema::Result::RawVirulenceData",
  { "foreign.gene_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_cores

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpCore>

=cut

__PACKAGE__->has_many(
  "snp_cores",
  "Database::Chado::Schema::Result::SnpCore",
  { "foreign.pangenome_region_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_position_contig_collections

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpPosition>

=cut

__PACKAGE__->has_many(
  "snp_position_contig_collections",
  "Database::Chado::Schema::Result::SnpPosition",
  { "foreign.contig_collection_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_position_contigs

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpPosition>

=cut

__PACKAGE__->has_many(
  "snp_position_contigs",
  "Database::Chado::Schema::Result::SnpPosition",
  { "foreign.contig_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_position_loci

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpPosition>

=cut

__PACKAGE__->has_many(
  "snp_position_loci",
  "Database::Chado::Schema::Result::SnpPosition",
  { "foreign.locus_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_position_pangenome_regions

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpPosition>

=cut

__PACKAGE__->has_many(
  "snp_position_pangenome_regions",
  "Database::Chado::Schema::Result::SnpPosition",
  { "foreign.pangenome_region_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_variation_contig_collections

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpVariation>

=cut

__PACKAGE__->has_many(
  "snp_variation_contig_collections",
  "Database::Chado::Schema::Result::SnpVariation",
  { "foreign.contig_collection_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_variation_contigs

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpVariation>

=cut

__PACKAGE__->has_many(
  "snp_variation_contigs",
  "Database::Chado::Schema::Result::SnpVariation",
  { "foreign.contig_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 snp_variation_loci

Type: has_many

Related object: L<Database::Chado::Schema::Result::SnpVariation>

=cut

__PACKAGE__->has_many(
  "snp_variation_loci",
  "Database::Chado::Schema::Result::SnpVariation",
  { "foreign.locus_id" => "self.feature_id" },
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

=head2 vf_categories

Type: has_many

Related object: L<Database::Chado::Schema::Result::VfCategory>

=cut

__PACKAGE__->has_many(
  "vf_categories",
  "Database::Chado::Schema::Result::VfCategory",
  { "foreign.feature_id" => "self.feature_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 geocodes

Type: many_to_many

Composing rels: L</genome_locations> -> geocode

=cut

__PACKAGE__->many_to_many("geocodes", "genome_locations", "geocode");


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-03-11 13:58:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ESl6bzhLB79hMis+0SGq1Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
