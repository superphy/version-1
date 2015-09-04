 use utf8;
package Database::Chado::Schema::Result::CvPathCount;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::CvPathCount

=head1 DESCRIPTION

per-cv summary of number of
paths (cvtermpaths) broken down by relationship_type. num_paths is the
total # of paths of the specified type in which the subject_id of the
path is in the named cv. See also: cv_distinct_relations

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<cv_path_count>

=cut

__PACKAGE__->table("cv_path_count");

=head1 ACCESSORS

=head2 cv_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 relation_name

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 relation_cv_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 num_paths

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "cv_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "relation_name",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "relation_cv_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "num_paths",
  { data_type => "bigint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ut+HDFDmxUodT5T5wn99Zw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->result_source_instance->is_virtual(0);
__PACKAGE__->result_source_instance->view_definition(
  "SELECT cv.name AS cv_name, ".
  "relation.name AS relation_name, ".
  "relation_cv.name AS relation_cv_name, ".
  "count(*) AS num_paths ".
  "FROM cv ".
  "JOIN cvterm ON cvterm.cv_id = cv.cv_id ".
  "JOIN cvtermpath ON cvterm.cvterm_id = cvtermpath.subject_id ".
  "JOIN cvterm relation ON cvtermpath.type_id = relation.cvterm_id ".
  "JOIN cv relation_cv ON relation.cv_id = relation_cv.cv_id ".
  "GROUP BY cv.name, relation.name, relation_cv.name"
);
1;
