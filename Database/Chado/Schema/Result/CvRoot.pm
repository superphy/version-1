use utf8;
package Database::Chado::Schema::Result::CvRoot;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::CvRoot

=head1 DESCRIPTION

the roots of a cv are the set of terms
which have no parents (terms that are not the subject of a
relation). Most cvs will have a single root, some may have >1. All
will have at least 1

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<cv_root>

=cut

__PACKAGE__->table("cv_root");

=head1 ACCESSORS

=head2 cv_id

  data_type: 'integer'
  is_nullable: 1

=head2 root_cvterm_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "cv_id",
  { data_type => "integer", is_nullable => 1 },
  "root_cvterm_id",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dh9gXeTLDMheeYObeBi+AA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->result_source_instance->is_virtual(0);
__PACKAGE__->result_source_instance->view_definition(
	"SELECT cvterm.cv_id, ".
	"cvterm.cvterm_id AS root_cvterm_id ".
	"FROM cvterm ".
	"WHERE NOT (cvterm.cvterm_id IN ( SELECT cvterm_relationship.subject_id ".
	"FROM cvterm_relationship)) AND cvterm.is_obsolete = 0"
);
1;
