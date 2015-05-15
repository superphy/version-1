use utf8;
package Database::Chado::Schema::Result::PrivateFeatureCvterm;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PrivateFeatureCvterm

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<private_feature_cvterm>

=cut

__PACKAGE__->table("private_feature_cvterm");

=head1 ACCESSORS

=head2 feature_cvterm_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'private_feature_cvterm_feature_cvterm_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 is_not

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_cvterm_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "private_feature_cvterm_feature_cvterm_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_not",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_cvterm_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_cvterm_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<private_feature_cvterm_c1>

=over 4

=item * L</feature_id>

=item * L</cvterm_id>

=item * L</pub_id>

=item * L</rank>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "private_feature_cvterm_c1",
  ["feature_id", "cvterm_id", "pub_id", "rank"],
);

=head1 RELATIONS

=head2 cvterm

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Cvterm>

=cut

__PACKAGE__->belongs_to(
  "cvterm",
  "Database::Chado::Schema::Result::Cvterm",
  { cvterm_id => "cvterm_id" },
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

=head2 pub

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Pub>

=cut

__PACKAGE__->belongs_to(
  "pub",
  "Database::Chado::Schema::Result::Pub",
  { pub_id => "pub_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Vrr3Danvkk7Hv/spSyBNWw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
