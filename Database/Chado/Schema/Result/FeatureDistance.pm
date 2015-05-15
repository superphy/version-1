use utf8;
package Database::Chado::Schema::Result::FeatureDistance;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeatureDistance

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<feature_distance>

=cut

__PACKAGE__->table("feature_distance");

=head1 ACCESSORS

=head2 subject_id

  data_type: 'integer'
  is_nullable: 1

=head2 object_id

  data_type: 'integer'
  is_nullable: 1

=head2 srcfeature_id

  data_type: 'integer'
  is_nullable: 1

=head2 subject_strand

  data_type: 'smallint'
  is_nullable: 1

=head2 object_strand

  data_type: 'smallint'
  is_nullable: 1

=head2 distance

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "subject_id",
  { data_type => "integer", is_nullable => 1 },
  "object_id",
  { data_type => "integer", is_nullable => 1 },
  "srcfeature_id",
  { data_type => "integer", is_nullable => 1 },
  "subject_strand",
  { data_type => "smallint", is_nullable => 1 },
  "object_strand",
  { data_type => "smallint", is_nullable => 1 },
  "distance",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/gPAjg2YW2CQlkKrSQ3PFg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->result_source_instance->is_virtual(0);
__PACKAGE__->result_source_instance->view_definition(
  "SELECT x.feature_id AS subject_id, ".
  "y.feature_id AS object_id, ".
  "x.srcfeature_id, ".
  "x.strand AS subject_strand, ".
  "y.strand AS object_strand, ".
  "CASE ".
  "WHEN x.fmax <= y.fmin THEN x.fmax - y.fmin ".
  "ELSE y.fmax - x.fmin ".
  "END AS distance ".
  "FROM featureloc x, ".
  "featureloc y ".
  "WHERE x.srcfeature_id = y.srcfeature_id AND (x.fmax <= y.fmin OR x.fmin >= y.fmax)"
);
1;
