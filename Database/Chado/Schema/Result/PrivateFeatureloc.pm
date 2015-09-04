use utf8;
package Database::Chado::Schema::Result::PrivateFeatureloc;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PrivateFeatureloc

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<private_featureloc>

=cut

__PACKAGE__->table("private_featureloc");

=head1 ACCESSORS

=head2 featureloc_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'private_featureloc_featureloc_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 srcfeature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 fmin

  data_type: 'integer'
  is_nullable: 1

=head2 is_fmin_partial

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 fmax

  data_type: 'integer'
  is_nullable: 1

=head2 is_fmax_partial

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 strand

  data_type: 'smallint'
  is_nullable: 1

=head2 phase

  data_type: 'integer'
  is_nullable: 1

=head2 residue_info

  data_type: 'text'
  is_nullable: 1

=head2 locgroup

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "featureloc_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "private_featureloc_featureloc_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "srcfeature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fmin",
  { data_type => "integer", is_nullable => 1 },
  "is_fmin_partial",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "fmax",
  { data_type => "integer", is_nullable => 1 },
  "is_fmax_partial",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "strand",
  { data_type => "smallint", is_nullable => 1 },
  "phase",
  { data_type => "integer", is_nullable => 1 },
  "residue_info",
  { data_type => "text", is_nullable => 1 },
  "locgroup",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</featureloc_id>

=back

=cut

__PACKAGE__->set_primary_key("featureloc_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<private_featureloc_c1>

=over 4

=item * L</feature_id>

=item * L</locgroup>

=item * L</rank>

=back

=cut

__PACKAGE__->add_unique_constraint("private_featureloc_c1", ["feature_id", "locgroup", "rank"]);

=head1 RELATIONS

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

=head2 srcfeature

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->belongs_to(
  "srcfeature",
  "Database::Chado::Schema::Result::PrivateFeature",
  { feature_id => "srcfeature_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "SET NULL",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:iw3D5pkut/lUjjv+k5GA5w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
