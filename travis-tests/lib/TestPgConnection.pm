#!/usr/bin/env perl

=pod

=head1 NAME

t::lib::TestPostgresDB;

=head1 SNYNOPSIS



=head1 DESCRIPTION

A Moose::Role for connecting to existing Postgres database in Test::DBIx::Class

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

package Test::DBIx::Class::SchemaManager::Trait::TestPgConnection;

{
    
    use Moose::Role;
    use MooseX::Attribute::ENV;
    use DBI;
    use Time::HiRes qw/gettimeofday/;
    use Config::Tiny;
    use Test::More;

    has 'dsn' => (
        is      => 'ro',
        writer  => '_set_dsn'
    );

    has 'dbuser' => (
        is      => 'ro',
        writer  => '_set_dbuser'
    );

    has 'owner' => (
        is      => 'ro', 
        traits  => ['ENV'],
        default => 'genodo'
    );

    has 'postgresql_dbh' => (
        is      => 'ro',
        lazy    => 1,
        builder => '_build_postgresql_dbh'
    );

    sub _build_postgresql_dbh {
        my ($self) = @_;

        if($ENV{SUPERPHY_CONFIGFILE}) {
            my $config_filepath = $ENV{SUPERPHY_CONFIGFILE};

            # Parse config file for DB connection parameters
            my ($dsn, $dbuser);
            if(my $conf = Config::Tiny->read($config_filepath)) {
                $dsn       = $conf->{db}->{dsn};
                $dbuser    = $conf->{db}->{user};
            } else {
                die Config::Tiny->errstr();
            }

            die "Error: missing parameter 'db.dsn' in config file $config_filepath." unless $dsn;
            die "Error: missing parameter 'db.duser' in config file $config_filepath." unless $dbuser;

            $self->_set_dsn($dsn);
            $self->_set_dbuser($dbuser);
    
        } else {
            die "Error: enviroment variable SUPERPHY_CONFIGFILE undefined.";
        }

        if($ENV{USER} ne $self->dbuser) {
            die "Error: must run script as user: ".$self->dbuser;
        }

        # Connect to database
        my $dbh = DBI->connect($self->dsn(), $self->dbuser, '', {})
            or die $DBI::errstr;

        return $dbh;
    }

    sub get_default_connect_info {
        my ($self) = @_;

        # Initiate connection
        my $dbh = $self->postgresql_dbh;

        if ($self->tdbic_debug){
            Test::More::diag("DBI->connect('",$self->dsn,"','",$self->dbuser,"',''])");
        }
        return [$self->dsn,$self->dbuser,''];
    }

    before 'cleanup' => sub {
        my ($self) = @_;

        $self->postgresql_dbh->disconnect if $self->postgresql_dbh;
    };

} 1;