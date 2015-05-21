use utf8;
package Database::Chado::Schema::Result::DeletedUpload;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::DeletedUpload

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<deleted_upload>

=cut

__PACKAGE__->table("deleted_upload");

=head1 ACCESSORS

=head2 deleted_upload_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'deleted_upload_deleted_upload_id_seq'

=head2 upload_id

  data_type: 'integer'
  is_nullable: 0

=head2 upload_date

  data_type: 'timestamp'
  is_nullable: 0

=head2 cc_feature_id

  data_type: 'integer'
  is_nullable: 0

=head2 cc_uniquename

  data_type: 'text'
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 deletion_date

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "deleted_upload_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "deleted_upload_deleted_upload_id_seq",
  },
  "upload_id",
  { data_type => "integer", is_nullable => 0 },
  "upload_date",
  { data_type => "timestamp", is_nullable => 0 },
  "cc_feature_id",
  { data_type => "integer", is_nullable => 0 },
  "cc_uniquename",
  { data_type => "text", is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "deletion_date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</deleted_upload_id>

=back

=cut

__PACKAGE__->set_primary_key("deleted_upload_id");


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6U70HFcPa1OF64LYaxrgRg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
