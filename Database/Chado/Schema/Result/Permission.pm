use utf8;
package Database::Chado::Schema::Result::Permission;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Permission

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<permission>

=cut

__PACKAGE__->table("permission");

=head1 ACCESSORS

=head2 permission_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'permission_permission_id_seq'

=head2 upload_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 login_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 can_modify

  data_type: 'boolean'
  is_nullable: 0

=head2 can_share

  data_type: 'boolean'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "permission_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "permission_permission_id_seq",
  },
  "upload_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "login_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "can_modify",
  { data_type => "boolean", is_nullable => 0 },
  "can_share",
  { data_type => "boolean", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</permission_id>

=back

=cut

__PACKAGE__->set_primary_key("permission_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<permission_c1>

=over 4

=item * L</upload_id>

=item * L</login_id>

=back

=cut

__PACKAGE__->add_unique_constraint("permission_c1", ["upload_id", "login_id"]);

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
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9Oyr59B0q6tIJtPi6ZUS1A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
