use utf8;
package Database::Chado::Schema::Result::PipelineStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::PipelineStatus

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<pipeline_status>

=cut

__PACKAGE__->table("pipeline_status");

=head1 ACCESSORS

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 starttime

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => \"now()"}

=head2 status

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 job

  data_type: 'varchar'
  default_value: null
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "name",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "starttime",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "status",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "job",
  {
    data_type => "varchar",
    default_value => \"null",
    is_nullable => 1,
    size => 10,
  },
);


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ALZ1kWmArDsL0kCQu2oJRw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
