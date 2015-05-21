use utf8;
package Database::Chado::Schema::Result::GroupCategory;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::GroupCategory

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<group_category>

=cut

__PACKAGE__->table("group_category");

=head1 ACCESSORS

=head2 group_category_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'group_category_group_category_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 200

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 20

=head2 standard

  data_type: 'boolean'
  default_value: false
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "group_category_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "group_category_group_category_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 200 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "standard",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</group_category_id>

=back

=cut

__PACKAGE__->set_primary_key("group_category_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<group_category_c1>

=over 4

=item * L</username>

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("group_category_c1", ["username", "name"]);

=head1 RELATIONS

=head2 genome_groups

Type: has_many

Related object: L<Database::Chado::Schema::Result::GenomeGroup>

=cut

__PACKAGE__->has_many(
  "genome_groups",
  "Database::Chado::Schema::Result::GenomeGroup",
  { "foreign.category_id" => "self.group_category_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RbKaehzhGTRRKpa5DYdPlg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
