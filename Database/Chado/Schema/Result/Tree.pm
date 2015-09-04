use utf8;
package Database::Chado::Schema::Result::Tree;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Tree

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<tree>

=cut

__PACKAGE__->table("tree");

=head1 ACCESSORS

=head2 tree_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'tree_tree_id_seq'

=head2 name

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 format

  data_type: 'enum'
  default_value: 'undefined'
  extra: {custom_type_name => "tree_type",list => ["perl","json","newick","undefined"]}
  is_nullable: 0

=head2 tree_string

  data_type: 'text'
  is_nullable: 0

=head2 timelastmodified

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=cut

__PACKAGE__->add_columns(
  "tree_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "tree_tree_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "format",
  {
    data_type => "enum",
    default_value => "undefined",
    extra => {
      custom_type_name => "tree_type",
      list => ["perl", "json", "newick", "undefined"],
    },
    is_nullable => 0,
  },
  "tree_string",
  { data_type => "text", is_nullable => 0 },
  "timelastmodified",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</tree_id>

=back

=cut

__PACKAGE__->set_primary_key("tree_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<tree_c1>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("tree_c1", ["name"]);

=head1 RELATIONS

=head2 feature_trees

Type: has_many

Related object: L<Database::Chado::Schema::Result::FeatureTree>

=cut

__PACKAGE__->has_many(
  "feature_trees",
  "Database::Chado::Schema::Result::FeatureTree",
  { "foreign.tree_id" => "self.tree_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 private_feature_trees

Type: has_many

Related object: L<Database::Chado::Schema::Result::PrivateFeatureTree>

=cut

__PACKAGE__->has_many(
  "private_feature_trees",
  "Database::Chado::Schema::Result::PrivateFeatureTree",
  { "foreign.tree_id" => "self.tree_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8N+glc83az0Vl75CCb9nbQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
