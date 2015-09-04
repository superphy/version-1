use utf8;
package Database::Chado::Schema::Result::FeaturemapPub;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeaturemapPub

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<featuremap_pub>

=cut

__PACKAGE__->table("featuremap_pub");

=head1 ACCESSORS

=head2 featuremap_pub_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'featuremap_pub_featuremap_pub_id_seq'

=head2 featuremap_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pub_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "featuremap_pub_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "featuremap_pub_featuremap_pub_id_seq",
  },
  "featuremap_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pub_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</featuremap_pub_id>

=back

=cut

__PACKAGE__->set_primary_key("featuremap_pub_id");

=head1 RELATIONS

=head2 featuremap

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Featuremap>

=cut

__PACKAGE__->belongs_to(
  "featuremap",
  "Database::Chado::Schema::Result::Featuremap",
  { featuremap_id => "featuremap_id" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:wBokq+XeCaITIW/BtF3w7A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
