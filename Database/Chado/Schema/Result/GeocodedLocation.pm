use utf8;
package Database::Chado::Schema::Result::GeocodedLocation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::GeocodedLocation

=head1 DESCRIPTION

Stores latlng coordinates of genome locations in JSON objects.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<geocoded_location>

=cut

__PACKAGE__->table("geocoded_location");

=head1 ACCESSORS

=head2 geocode_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'geocoded_location_geocode_id_seq'

=head2 location

  data_type: 'json'
  is_nullable: 0

=head2 search_query

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 255

Can be NULL if a pin-pointed location

=cut

__PACKAGE__->add_columns(
  "geocode_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "geocoded_location_geocode_id_seq",
  },
  "location",
  { data_type => "json", is_nullable => 0 },
  "search_query",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 255,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</geocode_id>

=back

=cut

__PACKAGE__->set_primary_key("geocode_id");

=head1 RELATIONS

=head2 genome_locations

Type: has_many

Related object: L<Database::Chado::Schema::Result::GenomeLocation>

=cut

__PACKAGE__->has_many(
  "genome_locations",
  "Database::Chado::Schema::Result::GenomeLocation",
  { "foreign.geocode_id" => "self.geocode_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_genome_locations

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateGenomeLocation>

=cut

__PACKAGE__->has_many(
  "private_genome_locations",
  "Database::Chado::Schema::Result::PrivateGenomeLocation",
  { "foreign.geocode_id" => "self.geocode_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 features

Type: many_to_many

Composing rels: L</genome_locations> -> feature

=cut

__PACKAGE__->many_to_many("features", "genome_locations", "feature");

=head2 features_2s

Type: many_to_many

Composing rels: L</private_genome_locations> -> feature

=cut

__PACKAGE__->many_to_many("features_2s", "private_genome_locations", "feature");


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:N4XajZ2NavowycSJFYSvOw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
