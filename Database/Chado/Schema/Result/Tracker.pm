use utf8;
package Database::Chado::Schema::Result::Tracker;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Tracker

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tracker>

=cut

__PACKAGE__->table("tracker");

=head1 ACCESSORS

=head2 tracker_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'tracker_tracker_id_seq'

=head2 step

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 failed

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 feature_name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 command

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 pid

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 upload_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 login_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 start_date

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 end_date

  data_type: 'timestamp'
  is_nullable: 1

=head2 footprint

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 access_category

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "tracker_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tracker_tracker_id_seq",
  },
  "step",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "failed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "feature_name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "command",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "pid",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "upload_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "login_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "start_date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "end_date",
  { data_type => "timestamp", is_nullable => 1 },
  "footprint",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "access_category",
  { data_type => "varchar", is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tracker_id>

=back

=cut

__PACKAGE__->set_primary_key("tracker_id");

=head1 RELATIONS

=head2 login

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Login>

=cut

__PACKAGE__->belongs_to(
  "login",
  "Database::Chado::Schema::Result::Login",
  { login_id => "login_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 upload

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Upload>

=cut

__PACKAGE__->belongs_to(
  "upload",
  "Database::Chado::Schema::Result::Upload",
  { upload_id => "upload_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-03-11 13:58:50
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cib6klpkuL9yQX7B4JazUA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
