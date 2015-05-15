use utf8;
package Database::Chado::Schema::Result::CvtermRelationship;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::CvtermRelationship

=head1 DESCRIPTION

A relationship linking two
cvterms. Each cvterm_relationship constitutes an edge in the graph
defined by the collection of cvterms and cvterm_relationships. The
meaning of the cvterm_relationship depends on the definition of the
cvterm R refered to by type_id. However, in general the definitions
are such that the statement "all SUBJs REL some OBJ" is true. The
cvterm_relationship statement is about the subject, not the
object. For example "insect wing part_of thorax".

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cvterm_relationship>

=cut

__PACKAGE__->table("cvterm_relationship");

=head1 ACCESSORS

=head2 cvterm_relationship_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'cvterm_relationship_cvterm_relationship_id_seq'

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The nature of the
relationship between subject and object. Note that relations are also
housed in the cvterm table, typically from the OBO relationship
ontology, although other relationship types are allowed.

=head2 subject_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The subject of
the subj-predicate-obj sentence. The cvterm_relationship is about the
subject. In a graph, this typically corresponds to the child node.

=head2 object_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The object of the
subj-predicate-obj sentence. The cvterm_relationship refers to the
object. In a graph, this typically corresponds to the parent node.

=cut

__PACKAGE__->add_columns(
  "cvterm_relationship_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "cvterm_relationship_cvterm_relationship_id_seq",
  },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "subject_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "object_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cvterm_relationship_id>

=back

=cut

__PACKAGE__->set_primary_key("cvterm_relationship_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cvterm_relationship_c1>

=over 4

=item * L</subject_id>

=item * L</object_id>

=item * L</type_id>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "cvterm_relationship_c1",
  ["subject_id", "object_id", "type_id"],
);

=head1 RELATIONS

=head2 object

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "object",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "object_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 subject

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "subject",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "subject_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sjCne7avpgaJi76ktZcEzQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
