use utf8;
package Database::Chado::Schema::Result::ContigFootprint;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::ContigFootprint

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<contig_footprint>

=cut

__PACKAGE__->table("contig_footprint");

=head1 ACCESSORS

=head2 contig_footprint_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'contig_footprint_contig_footprint_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 footprint

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=cut

__PACKAGE__->add_columns(
  "contig_footprint_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "contig_footprint_contig_footprint_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "footprint",
  { data_type => "varchar", is_nullable => 1, size => 32 },
);

=head1 PRIMARY KEY

=over 4

=item * L</contig_footprint_id>

=back

=cut

__PACKAGE__->set_primary_key("contig_footprint_id");

=head1 RELATIONS

=head2 feature

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "feature_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-03-11 13:58:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:rOFWPCqHWoh4hBlUltCnqQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
