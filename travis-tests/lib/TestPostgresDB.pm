#!/usr/bin/env perl

=pod

=head1 NAME

t::lib::TestPostgresDB;

=head1 SNYNOPSIS



=head1 DESCRIPTION

A Moose::Role for creating a test Postgres database in Test::DBIx::Class

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

package Test::DBIx::Class::SchemaManager::Trait::TestPostgresDB;

{
    
    use Moose::Role;
    use MooseX::Attribute::ENV;
    use DBI;
    use Time::HiRes qw/gettimeofday/;
    use Test::More ();

    has 'template' => (
        is      => 'ro', 
        traits  => ['ENV'],
        default => 'demodo'
    );

    has 'dbname' => (
        is      => 'ro',
        lazy    => 1,
        builder => '_build_dbname'
    );

    has 'owner' => (
        is      => 'ro', 
        traits  => ['ENV'],
        default => 'genodo'
    );

    has 'dbuser' => (
        is      => 'ro', 
        traits  => ['ENV'],
        default => 'postgres'
    );

    has 'postgresql_dbh' => (
        is         => 'ro',
        lazy    => 1,
        builder => '_build_postgresql_dbh'
    );

    sub _build_postgresql_dbh {
        my ($self) = @_;

        if($ENV{USER} ne $self->dbuser) {
            die "Must be run script as user: ".$self->dbuser;
        }

        if($self->keep_db) {
            $ENV{TEST_POSTGRESQL_PRESERVE} = 1;
        }

        # Connect to database
        my $dbh = DBI->connect($self->dsn(dbname => 'template1'), $self->dbuser, '', {})
            or die $DBI::errstr;

        # Create database that is clone of template
        my $dbname = $self->dbname;
        my $template = $self->template;
        my $owner = $self->owner;

        if($dbh->selectrow_arrayref(qq{SELECT COUNT(*) FROM pg_database WHERE datname='$dbname'})->[0] == 0) {
            $dbh->do("CREATE DATABASE $dbname WITH TEMPLATE $template OWNER $owner")
                or die $dbh->errstr;
        }

        return $dbh;
    }

    sub _build_dbname {
        my $timestamp = int (gettimeofday * 1000);
        my $dbname = "testodo$timestamp";
        return $dbname;
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

    sub dsn {
        my ($self, %args) = @_;

        $args{dbname} ||= $self->dbname;

        return 'DBI:Pg:' . join(';', map { "$_=$args{$_}" } sort keys %args);
    }


    before 'cleanup' => sub {
        my ($self) = @_;
        unless($self->keep_db) {

            my $dbname = $self->dbname;
            if($self->postgresql_dbh) {
                print "Dropping database $dbname using dbh\n";

                $self->postgresql_dbh->do("DROP DATABASE $dbname")
                    or die $self->postgresql_dbh->errstr;

                $self->postgresql_dbh->disconnect;
            } else {
                # Handle has already been deleted
                # Use dropdb command
                print "Dropping database $dbname using dropdb\n";
                my $cmd = "dropdb $dbname";
                system($cmd) == 0 or warn "Dropping database $dbname failed.";
            }
        }
    };


    override drop_table_sql => sub {
        my $self = shift;
        my $table = shift;
        return "drop table $table cascade";
    };

} 1;