use utf8;
package Database::Chado::Schema::Result::PrivateGenomeLocation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PrivateGenomeLocation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<private_genome_location>

=cut

__PACKAGE__->table("private_genome_location");

=head1 ACCESSORS

=head2 geocode_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "geocode_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</geocode_id>

=item * L</feature_id>

=back

=cut

__PACKAGE__->set_primary_key("geocode_id", "feature_id");

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

=head2 geocode

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::GeocodedLocation>

=cut

__PACKAGE__->belongs_to(
  "geocode",
  "Database::Chado::Schema::Result::GeocodedLocation",
  { geocode_id => "geocode_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zOJ7GWWETm0tprLF/nySlA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
