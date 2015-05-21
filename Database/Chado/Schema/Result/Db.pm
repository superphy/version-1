use utf8;
package Database::Chado::Schema::Result::Db;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Db

=head1 DESCRIPTION

A database authority. Typical databases in
bioinformatics are FlyBase, GO, UniProt, NCBI, MGI, etc. The authority
is generally known by this shortened form, which is unique within the
bioinformatics and biomedical realm.  To Do - add support for URIs,
URNs (e.g. LSIDs). We can do this by treating the URL as a URI -
however, some applications may expect this to be resolvable - to be
decided.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<db>

=cut

__PACKAGE__->table("db");

=head1 ACCESSORS

=head2 db_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'db_db_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 urlprefix

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 url

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=cut

__PACKAGE__->add_columns(
  "db_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "db_db_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "urlprefix",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "url",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);

=head1 PRIMARY KEY

=over 4

=item * L</db_id>

=back

=cut

__PACKAGE__->set_primary_key("db_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<db_c1>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("db_c1", ["name"]);

=head1 RELATIONS

=head2 dbxrefs

Type: has_many

Related object: L<Database::Chado::Schema::Result::Dbxref>

=cut

__PACKAGE__->has_many(
  "dbxrefs",
  "Database::Chado::Schema::Result::Dbxref",
  { "foreign.db_id" => "self.db_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7EcXypTKor9xoswe5bLT5w


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
