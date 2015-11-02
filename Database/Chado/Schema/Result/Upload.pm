use utf8;
package Database::Chado::Schema::Result::Upload;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Upload

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<upload>

=cut

__PACKAGE__->table("upload");

=head1 ACCESSORS

=head2 upload_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'upload_upload_id_seq'

=head2 login_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 tag

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 50

=head2 release_date

  data_type: 'date'
  default_value: infinity
  is_nullable: 0

=head2 category

  data_type: 'enum'
  default_value: 'undefined'
  extra: {custom_type_name => "upload_type",list => ["public","release","private","undefined"]}
  is_nullable: 0

=head2 upload_date

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "upload_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "upload_upload_id_seq",
  },
  "login_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "tag",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 50 },
  "release_date",
  { data_type => "date", default_value => "infinity", is_nullable => 0 },
  "category",
  {
    data_type => "enum",
    default_value => "undefined",
    extra => {
      custom_type_name => "upload_type",
      list => ["public", "release", "private", "undefined"],
    },
    is_nullable => 0,
  },
  "upload_date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</upload_id>

=back

=cut

__PACKAGE__->set_primary_key("upload_id");

=head1 RELATIONS

=head2 login

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Login>

=cut

__PACKAGE__->belongs_to(
  "login",
  "Database::Chado::Schema::Result::Login",
  { login_id => "login_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 pending_updates

Type: has_many

Related object: L<Database::Chado::Schema::Result::PendingUpdate>

=cut

__PACKAGE__->has_many(
  "pending_updates",
  "Database::Chado::Schema::Result::PendingUpdate",
  { "foreign.upload_id" => "self.upload_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 permissions

Type: has_many

Related object: L<Database::Chado::Schema::Result::Permission>

=cut

__PACKAGE__->has_many(
  "permissions",
  "Database::Chado::Schema::Result::Permission",
  { "foreign.upload_id" => "self.upload_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_featureprops

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeatureprop>

=cut

__PACKAGE__->has_many(
  "private_featureprops",
  "Database::Chado::Schema::Result::PrivateFeatureprop",
  { "foreign.upload_id" => "self.upload_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_features

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeature>

=cut

__PACKAGE__->has_many(
  "private_features",
  "Database::Chado::Schema::Result::PrivateFeature",
  { "foreign.upload_id" => "self.upload_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 trackers

Type: has_many

Related object: L<Database::Chado::Schema::Result::Tracker>

=cut

__PACKAGE__->has_many(
  "trackers",
  "Database::Chado::Schema::Result::Tracker",
  { "foreign.upload_id" => "self.upload_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-08-27 10:54:29
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BCxSQmkPpWJKvCBln5C0Yw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
