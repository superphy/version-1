 use utf8;
package Database::Chado::Schema::Result::CommonAncestorCvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::CommonAncestorCvterm

=head1 DESCRIPTION

The common ancestor of any
two terms is the intersection of both terms ancestors. Two terms can
have multiple common ancestors. Use total_pathdistance to get the
least common ancestor

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<common_ancestor_cvterm>

=cut

__PACKAGE__->table("common_ancestor_cvterm");

=head1 ACCESSORS

=head2 cvterm1_id

  data_type: 'integer'
  is_nullable: 1

=head2 cvterm2_id

  data_type: 'integer'
  is_nullable: 1

=head2 ancestor_cvterm_id

  data_type: 'integer'
  is_nullable: 1

=head2 pathdistance1

  data_type: 'integer'
  is_nullable: 1

=head2 pathdistance2

  data_type: 'integer'
  is_nullable: 1

=head2 total_pathdistance

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "cvterm1_id",
  { data_type => "integer", is_nullable => 1 },
  "cvterm2_id",
  { data_type => "integer", is_nullable => 1 },
  "ancestor_cvterm_id",
  { data_type => "integer", is_nullable => 1 },
  "pathdistance1",
  { data_type => "integer", is_nullable => 1 },
  "pathdistance2",
  { data_type => "integer", is_nullable => 1 },
  "total_pathdistance",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pSowAB8/Iea3hU319wqv3Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->result_source_instance->is_virtual(0);
__PACKAGE__->result_source_instance->view_definition(
  "SELECT p1.subject_id AS cvterm1_id, ".
  "p2.subject_id AS cvterm2_id, ".
  "p1.object_id AS ancestor_cvterm_id, ".
  "p1.pathdistance AS pathdistance1, ".
  "p2.pathdistance AS pathdistance2, ".
  "p1.pathdistance + p2.pathdistance AS total_pathdistance ".
  "FROM cvtermpath p1, cvtermpath p2 ".
  "WHERE p1.object_id = p2.object_id"
);
1;
