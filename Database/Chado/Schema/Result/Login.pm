use utf8;
package Database::Chado::Schema::Result::Login;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Login

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<login>

=cut

__PACKAGE__->table("login");

=head1 ACCESSORS

=head2 login_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'login_login_id_seq'

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 password

  data_type: 'varchar'
  is_nullable: 0
  size: 22

=head2 firstname

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 30

=head2 lastname

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 30

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 45

=head2 creation_date

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "login_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "login_login_id_seq",
  },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 22 },
  "firstname",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 30 },
  "lastname",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 30 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 45 },
  "creation_date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</login_id>

=back

=cut

__PACKAGE__->set_primary_key("login_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<login_c1>

=over 4

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("login_c1", ["username"]);

=head1 RELATIONS

=head2 permissions

Type: has_many

Related object: L<Database::Chado::Schema::Result::Permission>

=cut

__PACKAGE__->has_many(
  "permissions",
  "Database::Chado::Schema::Result::Permission",
  { "foreign.login_id" => "self.login_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 trackers

Type: has_many

Related object: L<Database::Chado::Schema::Result::Tracker>

=cut

__PACKAGE__->has_many(
  "trackers",
  "Database::Chado::Schema::Result::Tracker",
  { "foreign.login_id" => "self.login_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 uploads

Type: has_many

Related object: L<Database::Chado::Schema::Result::Upload>

=cut

__PACKAGE__->has_many(
  "uploads",
  "Database::Chado::Schema::Result::Upload",
  { "foreign.login_id" => "self.login_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4S/22x7Ny9zsTgDCAmwczA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
