 use utf8;
package Database::Chado::Schema::Result::DbDbxrefCount;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::DbDbxrefCount - per-db dbxref counts

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<db_dbxref_count>

=cut

__PACKAGE__->table("db_dbxref_count");

=head1 ACCESSORS

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 num_dbxrefs

  data_type: 'bigint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "name",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "num_dbxrefs",
  { data_type => "bigint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:li3jCPobanI7mU8WBK8bdg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->result_source_instance->is_virtual(0);
__PACKAGE__->result_source_instance->view_definition(
	"SELECT db.name, ".
	"count(*) AS num_dbxrefs ".
	"FROM db ".
	"JOIN dbxref USING (db_id) ".
	"GROUP BY db.name;"
);

1;
