use utf8;
package Database::Chado::Schema::Result::TmpSnpColumn;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::TmpSnpColumn

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tmp_snp_column>

=cut

__PACKAGE__->table("tmp_snp_column");

=head1 ACCESSORS

=head2 snp_id

  data_type: 'integer'
  is_nullable: 1

=head2 aln_column

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "snp_id",
  { data_type => "integer", is_nullable => 1 },
  "aln_column",
  { data_type => "integer", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<tmp_snp_column_idx1>

=over 4

=item * L</snp_id>

=back

=cut

__PACKAGE__->add_unique_constraint("tmp_snp_column_idx1", ["snp_id"]);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jRD9Y382CsCEZEsmdozwCA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
