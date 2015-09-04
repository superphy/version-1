use utf8;
package Database::Chado::Schema::Result::PrivateSnpPosition;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PrivateSnpPosition

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<private_snp_position>

=cut

__PACKAGE__->table("private_snp_position");

=head1 ACCESSORS

=head2 snp_position_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'private_snp_position_snp_position_id_seq'

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

=head2 region_start

  data_type: 'integer'
  is_nullable: 1

=head2 locus_start

  data_type: 'integer'
  is_nullable: 1

=head2 region_end

  data_type: 'integer'
  is_nullable: 1

=head2 locus_end

  data_type: 'integer'
  is_nullable: 1

=head2 locus_gap_offset

  data_type: 'integer'
  default_value: -1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "snp_position_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "private_snp_position_snp_position_id_seq",
  },
  "contig_collection_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "contig_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "pangenome_region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "locus_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "region_start",
  { data_type => "integer", is_nullable => 1 },
  "locus_start",
  { data_type => "integer", is_nullable => 1 },
  "region_end",
  { data_type => "integer", is_nullable => 1 },
  "locus_end",
  { data_type => "integer", is_nullable => 1 },
  "locus_gap_offset",
  { data_type => "integer", default_value => -1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</snp_position_id>

=back

=cut

__PACKAGE__->set_primary_key("snp_position_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<private_snp_position_c1>

=over 4

=item * L</contig_collection_id>

=item * L</pangenome_region_id>

=item * L</region_start>

=item * L</region_end>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "private_snp_position_c1",
  [
    "contig_collection_id",
    "pangenome_region_id",
    "region_start",
    "region_end",
  ],
);

=head2 C<private_snp_position_c2>

=over 4

=item * L</locus_id>

=item * L</region_start>

=item * L</region_end>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "private_snp_position_c2",
  ["locus_id", "region_start", "region_end"],
);

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


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YoosOlVWuMMuPdnUn0QIhw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
