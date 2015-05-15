use utf8;
package Database::Chado::Schema::Result::Cv;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Cv

=head1 DESCRIPTION

A controlled vocabulary or ontology. A cv is
composed of cvterms (AKA terms, classes, types, universals - relations
and properties are also stored in cvterm) and the relationships
between them.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cv>

=cut

__PACKAGE__->table("cv");

=head1 ACCESSORS

=head2 cv_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'cv_cv_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

The name of the ontology. This
corresponds to the obo-format -namespace-. cv names uniquely identify
the cv. In OBO file format, the cv.name is known as the namespace.

=head2 definition

  data_type: 'text'
  is_nullable: 1

A text description of the criteria for
membership of this ontology.

=cut

__PACKAGE__->add_columns(
  "cv_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "cv_cv_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "definition",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</cv_id>

=back

=cut

__PACKAGE__->set_primary_key("cv_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<cv_c1>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("cv_c1", ["name"]);

=head1 RELATIONS

=head2 cvprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvprop>

=cut

__PACKAGE__->has_many(
  "cvprops",
  "Database::Chado::Schema::Result::Cvprop",
  { "foreign.cv_id" => "self.cv_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvtermpaths

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvtermpath>

=cut

__PACKAGE__->has_many(
  "cvtermpaths",
  "Database::Chado::Schema::Result::Cvtermpath",
  { "foreign.cv_id" => "self.cv_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 cvterms

Type: has_many

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->has_many(
  "cvterms",
  "Database::Chado::Schema::Result::Cvterm",
  { "foreign.cv_id" => "self.cv_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:eDH7kqUlLk72Q8SA+nw27g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
