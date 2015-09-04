use utf8;
package Database::Chado::Schema::Result::FeatureTree;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::FeatureTree

=head1 DESCRIPTION

Maps features to the trees structures. When tree_relationship_type is locus
that feature was used as a query gene to find other sequences to build the tree. When tree_relationship_type is allele,
that sequence was used to build the tree. (note: the containing contig_collection feature_id will appear as the tree node, so that mapping
of global genome properties can happen quickly).

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<feature_tree>

=cut

__PACKAGE__->table("feature_tree");

=head1 ACCESSORS

=head2 feature_tree_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'feature_tree_feature_tree_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 tree_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 tree_relationship

  data_type: 'enum'
  default_value: 'undefined'
  extra: {custom_type_name => "tree_relationship_type",list => ["locus","allele","undefined"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "feature_tree_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "feature_tree_feature_tree_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tree_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tree_relationship",
  {
    data_type => "enum",
    default_value => "undefined",
    extra => {
      custom_type_name => "tree_relationship_type",
      list => ["locus", "allele", "undefined"],
    },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</feature_tree_id>

=back

=cut

__PACKAGE__->set_primary_key("feature_tree_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<feature_tree_c1>

=over 4

=item * L</feature_id>

=item * L</tree_id>

=back

=cut

__PACKAGE__->add_unique_constraint("feature_tree_c1", ["feature_id", "tree_id"]);

=head1 RELATIONS

=head2 feature

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Feature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "Database::Chado::Schema::Result::Feature",
  { feature_id => "feature_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 tree

Type: belongs_to

Related object: L<Database::Chado::Schema::Result::Tree>

=cut

__PACKAGE__->belongs_to(
  "tree",
  "Database::Chado::Schema::Result::Tree",
  { tree_id => "tree_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5DzYkTTT/85YvzFA8Ebqag


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
