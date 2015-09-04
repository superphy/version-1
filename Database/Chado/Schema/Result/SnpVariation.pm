use utf8;
package Database::Chado::Schema::Result::SnpVariation;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::SnpVariation

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<snp_variation>

=cut

__PACKAGE__->table("snp_variation");

=head1 ACCESSORS

=head2 snp_variation_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'snp_variation_snp_variation_id_seq'

=head2 snp_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 contig_collection_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 contig_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 locus_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 allele

  data_type: 'char'
  default_value: 'n'
  is_nullable: 0
  size: 1

=cut

__PACKAGE__->add_columns(
  "snp_variation_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "snp_variation_snp_variation_id_seq",
  },
  "snp_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "contig_collection_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "contig_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "locus_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "allele",
  { data_type => "char", default_value => "n", is_nullable => 0, size => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</snp_variation_id>

=back

=cut

__PACKAGE__->set_primary_key("snp_variation_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<snp_variation_c1>

=over 4

=item * L</snp_id>

=item * L</contig_collection_id>

=back

=cut

__PACKAGE__->add_unique_constraint("snp_variation_c1", ["snp_id", "contig_collection_id"]);

=head1 RELATIONS

=head2 contig

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "contig",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "contig_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 contig_collection

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "contig_collection",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "contig_collection_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 locus

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "locus",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "locus_id" },
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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AR1tF/Loo4ihoPIYS0pu2w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
