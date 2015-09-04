use utf8;
package Database::Chado::Schema::Result::TmpSnpCache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::TmpSnpCache

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tmp_snp_cache>

=cut

__PACKAGE__->table("tmp_snp_cache");

=head1 ACCESSORS

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 snp_id

  data_type: 'integer'
  is_nullable: 1

=head2 aln_column

  data_type: 'integer'
  is_nullable: 1

=head2 nuc

  data_type: 'char'
  is_nullable: 1
  size: 1

=cut

__PACKAGE__->add_columns(
  "name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "snp_id",
  { data_type => "integer", is_nullable => 1 },
  "aln_column",
  { data_type => "integer", is_nullable => 1 },
  "nuc",
  { data_type => "char", is_nullable => 1, size => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:K2XVn3XbRLPpETUg72M7fw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
