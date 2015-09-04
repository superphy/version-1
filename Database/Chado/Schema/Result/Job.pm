use utf8;
package Database::Chado::Schema::Result::Job;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Database::Chado::Schema::Result::Job

=head1 DESCRIPTION

Stores id's and statuses of current groupwise comparison jobs.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<jobs>

=cut

__PACKAGE__->table("jobs");

=head1 ACCESSORS

=head2 job_id

  data_type: 'text'
  is_nullable: 0
  original: {data_type => "varchar"}

Job ID for currently running process. Combination of concatening the tempfile tag of the user config file to an incerment of the count of current jobs to guarantee uniqueness.

=head2 remote_addr

  data_type: 'text'
  is_nullable: 0
  original: {data_type => "varchar"}

IP address of the remote user that requested the job

=head2 session_id

  data_type: 'text'
  is_nullable: 0
  original: {data_type => "varchar"}

CGI session ID

=head2 username

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

Username (if user logged in) of site user requesting job

=head2 status

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

Current status of job. Will either be "in progress" or "completed"

=head2 user_config

  data_type: 'text'
  is_nullable: 0
  original: {data_type => "varchar"}

=cut

__PACKAGE__->add_columns(
  "job_id",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "remote_addr",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "session_id",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
  "username",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "status",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "user_config",
  {
    data_type   => "text",
    is_nullable => 0,
    original    => { data_type => "varchar" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</job_id>

=back

=cut

__PACKAGE__->set_primary_key("job_id");


# Created by DBIx::Class::Schema::Loader v0.07041 @ 2015-02-10 14:57:44
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HR5IbdV4Eao2ZaVMDVUN2g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
