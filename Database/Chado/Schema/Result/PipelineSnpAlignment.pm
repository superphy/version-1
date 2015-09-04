use utf8;
package Database::Chado::Schema::Result::PipelineSnpAlignment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PipelineSnpAlignment

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<pipeline_snp_alignment>

=cut

__PACKAGE__->table("pipeline_snp_alignment");

=head1 ACCESSORS

=head2 snp_alignment_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'snp_alignment_snp_alignment_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 aln_column

  data_type: 'integer'
  is_nullable: 1

=head2 alignment

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "snp_alignment_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "snp_alignment_snp_alignment_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "aln_column",
  { data_type => "integer", is_nullable => 1 },
  "alignment",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</snp_alignment_id>

=back

=cut

__PACKAGE__->set_primary_key("snp_alignment_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<pipeline_snp_alignment_c1>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("pipeline_snp_alignment_c1", ["name"]);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-05-06 12:40:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BC9oPq8UisaZLCJwkkgSFA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
