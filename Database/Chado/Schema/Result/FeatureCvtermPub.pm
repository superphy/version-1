use utf8;
package Database::Chado::Schema::Result::FeatureCvtermPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeatureCvtermPub

=head1 DESCRIPTION

Secondary pubs for an
association. Each feature_cvterm association is supported by a single
primary publication. Additional secondary pubs can be added using this
linking table (in a GO gene association file, these corresponding to
any IDs after the pipe symbol in the publications column.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature_cvterm_pub>

=cut

__PACKAGE__->table("feature_cvterm_pub");

=head1 ACCESSORS

=head2 feature_cvterm_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_cvterm_pub_feature_cvterm_pub_id_seq'

=head2 feature_cvterm_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_cvterm_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_cvterm_pub_feature_cvterm_pub_id_seq",
  },
  "feature_cvterm_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_cvterm_pub_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_cvterm_pub_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_cvterm_pub_c1>

=over 4

=item * L</feature_cvterm_id>

=item * L</pub_id>

=back

=cut

__PACKAGE__->add_unique_constraint("feature_cvterm_pub_c1", ["feature_cvterm_id", "pub_id"]);

=head1 RELATIONS

=head2 feature_cvterm

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::FeatureCvterm>

=cut

__PACKAGE__->belongs_to(
  "feature_cvterm",
  "Database::Chado::Schema::Result::FeatureCvterm",
  { feature_cvterm_id => "feature_cvterm_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
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


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CSjgJ11VRFRzStYKRKFD0Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
