use utf8;
package Database::Chado::Schema::Result::Host;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Host

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<host>

=cut

__PACKAGE__->table("host");

=head1 ACCESSORS

=head2 host_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'host_host_id_seq'

=head2 host_category_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 uniquename

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 displayname

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 commonname

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 scientificname

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=cut

__PACKAGE__->add_columns(
  "host_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "host_host_id_seq",
  },
  "host_category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "uniquename",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "displayname",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "commonname",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "scientificname",
  { data_type => "varchar", is_nullable => 0, size => 100 },
);

=head1 PRIMARY KEY

=over 4

=item * L</host_id>

=back

=cut

__PACKAGE__->set_primary_key("host_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<host_c1>

=over 4

=item * L</uniquename>

=back

=cut

__PACKAGE__->add_unique_constraint("host_c1", ["uniquename"]);

=head2 C<host_c2>

=over 4

=item * L</displayname>

=back

=cut

__PACKAGE__->add_unique_constraint("host_c2", ["displayname"]);

=head1 RELATIONS

=head2 host_category

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::HostCategory>

=cut

__PACKAGE__->belongs_to(
  "host_category",
  "Database::Chado::Schema::Result::HostCategory",
  { host_category_id => "host_category_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LkeRQOhv52CnqiIXO5OuQg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
