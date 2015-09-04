use utf8;
package Database::Chado::Schema::Result::PipelineCache;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PipelineCache

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<pipeline_cache>

=cut

__PACKAGE__->table("pipeline_cache");

=head1 ACCESSORS

=head2 tracker_id

  data_type: 'integer'
  is_nullable: 0

=head2 chr_num

  data_type: 'integer'
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 collection_id

  data_type: 'integer'
  is_nullable: 1

=head2 contig_id

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "tracker_id",
  { data_type => "integer", is_nullable => 0 },
  "chr_num",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "collection_id",
  { data_type => "integer", is_nullable => 1 },
  "contig_id",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:phCEg9ev+ooT4g5Z3VUDxw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
