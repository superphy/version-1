use utf8;
package Database::Chado::Schema::Result::HostCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::HostCategory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<host_category>

=cut

__PACKAGE__->table("host_category");

=head1 ACCESSORS

=head2 host_category_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'host_category_host_category_id_seq'

=head2 uniquename

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 displayname

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=cut

__PACKAGE__->add_columns(
  "host_category_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "host_category_host_category_id_seq",
  },
  "uniquename",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "displayname",
  { data_type => "varchar", is_nullable => 0, size => 100 },
);

=head1 PRIMARY KEY

=over 4

=item * L</host_category_id>

=back

=cut

__PACKAGE__->set_primary_key("host_category_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<host_category_c1>

=over 4

=item * L</uniquename>

=back

=cut

__PACKAGE__->add_unique_constraint("host_category_c1", ["uniquename"]);

=head2 C<host_category_c2>

=over 4

=item * L</displayname>

=back

=cut

__PACKAGE__->add_unique_constraint("host_category_c2", ["displayname"]);

=head1 RELATIONS

=head2 hosts

Type: has_many

Related object: L<Database::Chado::Schema::Result::Host>

=cut

__PACKAGE__->has_many(
  "hosts",
  "Database::Chado::Schema::Result::Host",
  { "foreign.host_category_id" => "self.host_category_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sources

Type: has_many

Related object: L<Database::Chado::Schema::Result::Source>

=cut

__PACKAGE__->has_many(
  "sources",
  "Database::Chado::Schema::Result::Source",
  { "foreign.host_category_id" => "self.host_category_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 syndromes

Type: has_many

Related object: L<Database::Chado::Schema::Result::Syndrome>

=cut

__PACKAGE__->has_many(
  "syndromes",
  "Database::Chado::Schema::Result::Syndrome",
  { "foreign.host_category_id" => "self.host_category_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pZUCus6wGnIZqPOQp/g0qg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
