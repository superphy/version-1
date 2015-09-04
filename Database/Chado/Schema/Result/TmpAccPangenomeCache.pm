use utf8;
package Database::Chado::Schema::Result::TmpAccPangenomeCache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::TmpAccPangenomeCache

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tmp_acc_pangenome_cache>

=cut

__PACKAGE__->table("tmp_acc_pangenome_cache");

=head1 ACCESSORS

=head2 genome

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 aln_column

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "genome",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "aln_column",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:U2UQk1RP3B7YamHW2MX2fw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
