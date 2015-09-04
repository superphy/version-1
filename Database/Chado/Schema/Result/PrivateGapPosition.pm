use utf8;
package Database::Chado::Schema::Result::PrivateGapPosition;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PrivateGapPosition

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<private_gap_position>

=cut

__PACKAGE__->table("private_gap_position");

=head1 ACCESSORS

=head2 gap_position_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'private_gap_position_gap_position_id_seq'

=head2 contig_collection_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 contig_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 pangenome_region_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 locus_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 snp_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 locus_pos

  data_type: 'integer'
  is_nullable: 0

=head2 locus_gap_offset

  data_type: 'integer'
  default_value: -1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "gap_position_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "private_gap_position_gap_position_id_seq",
  },
  "contig_collection_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "contig_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pangenome_region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "locus_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "snp_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "locus_pos",
  { data_type => "integer", is_nullable => 0 },
  "locus_gap_offset",
  { data_type => "integer", default_value => -1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</gap_position_id>

=back

=cut

__PACKAGE__->set_primary_key("gap_position_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<private_gap_position_c1>

=over 4

=item * L</snp_id>

=item * L</contig_collection_id>

=back

=cut

__PACKAGE__->add_unique_constraint("private_gap_position_c1", ["snp_id", "contig_collection_id"]);

=head2 C<private_gap_position_c2>

=over 4

=item * L</snp_id>

=item * L</locus_id>

=back

=cut

__PACKAGE__->add_unique_constraint("private_gap_position_c2", ["snp_id", "locus_id"]);

=head1 RELATIONS

=head2 contig

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->belongs_to(
  "contig",
  "Database::Chado::Schema::Result::PrivateFeature",
  { feature_id => "contig_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 contig_collection

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->belongs_to(
  "contig_collection",
  "Database::Chado::Schema::Result::PrivateFeature",
  { feature_id => "contig_collection_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 locus

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->belongs_to(
  "locus",
  "Database::Chado::Schema::Result::PrivateFeature",
  { feature_id => "locus_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 pangenome_region

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "pangenome_region",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "pangenome_region_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 snp

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::SnpCore>

=cut

__PACKAGE__->belongs_to(
  "snp",
  "Database::Chado::Schema::Result::SnpCore",
  { snp_core_id => "snp_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VlbW4LSyJxdv9lXT0ljwvg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
