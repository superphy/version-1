use utf8;
package Database::Chado::Schema::Result::FeaturepropPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeaturepropPub

=head1 DESCRIPTION

Provenance. Any featureprop assignment can optionally be supported by a publication.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<featureprop_pub>

=cut

__PACKAGE__->table("featureprop_pub");

=head1 ACCESSORS

=head2 featureprop_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'featureprop_pub_featureprop_pub_id_seq'

=head2 featureprop_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "featureprop_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "featureprop_pub_featureprop_pub_id_seq",
  },
  "featureprop_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</featureprop_pub_id>

=back

=cut

__PACKAGE__->set_primary_key("featureprop_pub_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<featureprop_pub_c1>

=over 4

=item * L</featureprop_id>

=item * L</pub_id>

=back

=cut

__PACKAGE__->add_unique_constraint("featureprop_pub_c1", ["featureprop_id", "pub_id"]);

=head1 RELATIONS

=head2 featureprop

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Featureprop>

=cut

__PACKAGE__->belongs_to(
  "featureprop",
  "Database::Chado::Schema::Result::Featureprop",
  { featureprop_id => "featureprop_id" },
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


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hbBUtanaYeeRiQqc98x0QQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
