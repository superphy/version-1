use utf8;
package Database::Chado::Schema::Result::TmpGffLoadCache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::TmpGffLoadCache

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tmp_gff_load_cache>

=cut

__PACKAGE__->table("tmp_gff_load_cache");

=head1 ACCESSORS

=head2 feature_id

  data_type: 'integer'
  is_nullable: 1

=head2 uniquename

  data_type: 'varchar'
  is_nullable: 1
  size: 1000

=head2 type_id

  data_type: 'integer'
  is_nullable: 1

=head2 organism_id

  data_type: 'integer'
  is_nullable: 1

=head2 pub

  data_type: 'boolean'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "feature_id",
  { data_type => "integer", is_nullable => 1 },
  "uniquename",
  { data_type => "varchar", is_nullable => 1, size => 1000 },
  "type_id",
  { data_type => "integer", is_nullable => 1 },
  "organism_id",
  { data_type => "integer", is_nullable => 1 },
  "pub",
  { data_type => "boolean", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:DmnMyeQ5HXcHdvPE5rm7HA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
