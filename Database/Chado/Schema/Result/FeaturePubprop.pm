use utf8;
package Database::Chado::Schema::Result::FeaturePubprop;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeaturePubprop - Property or attribute of a feature_pub link.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature_pubprop>

=cut

__PACKAGE__->table("feature_pubprop");

=head1 ACCESSORS

=head2 feature_pubprop_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_pubprop_feature_pubprop_id_seq'

=head2 feature_pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 value

  data_type: 'text'
  is_nullable: 1

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_pubprop_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_pubprop_feature_pubprop_id_seq",
  },
  "feature_pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_pubprop_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_pubprop_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_pubprop_c1>

=over 4

=item * L</feature_pub_id>

=item * L</type_id>

=item * L</rank>

=back

=cut

__PACKAGE__->add_unique_constraint("feature_pubprop_c1", ["feature_pub_id", "type_id", "rank"]);

=head1 RELATIONS

=head2 feature_pub

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::FeaturePub>

=cut

__PACKAGE__->belongs_to(
  "feature_pub",
  "Database::Chado::Schema::Result::FeaturePub",
  { feature_pub_id => "feature_pub_id" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FscGvN9DZ28sXyQdzZu46A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
