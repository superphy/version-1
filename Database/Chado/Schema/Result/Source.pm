use utf8;
package Database::Chado::Schema::Result::Source;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Source

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<source>

=cut

__PACKAGE__->table("source");

=head1 ACCESSORS

=head2 source_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'source_source_id_seq'

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

=head2 description

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "source_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "source_source_id_seq",
  },
  "host_category_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "uniquename",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "displayname",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "description",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</source_id>

=back

=cut

__PACKAGE__->set_primary_key("source_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<source_c1>

=over 4

=item * L</host_category_id>

=item * L</uniquename>

=back

=cut

__PACKAGE__->add_unique_constraint("source_c1", ["host_category_id", "uniquename"]);

=head2 C<source_c2>

=over 4

=item * L</host_category_id>

=item * L</displayname>

=back

=cut

__PACKAGE__->add_unique_constraint("source_c2", ["host_category_id", "displayname"]);

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
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oXXpTKiBCeTuhecYbhXXIQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
