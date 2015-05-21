#!/usr/bin/env perl

package Roles::DatabaseConnector;

use strict;
use warnings;
use Role::Tiny;
use Carp qw(croak);
use Getopt::Long;
use Config::Tiny;
use FindBin;
use lib "$FindBin::Bin/../";;
use Database::Chado::Schema;


=head2 connectDatabase

Create and save dbix::class::schema handle.  Connect to database using DBI::connect parameters.  If already connected,
it will die.

=cut
sub connectDatabase {
	my $self = shift;
	my %params = @_;
	
	croak "Cannot call connectDatabase with existing connection to database.\n" if $self->{_dbixSchema};

	if($params{'dbh'}) {
		# Connect to existing connected DBI database handle
		$self->{_dbixSchema} = Database::Chado::Schema->connect(sub { return $params{'dbh'} }) 
			or croak "Error: Could not connect to existing database connection";
	}
	elsif($params{'dsn'}) {
		$self->{_dbixConif}->{dbUser} = $params{'dbUser'} // croak 'Missing dbUser argument.';
		$self->{_dbixConif}->{dbPass} = $params{'dbPass'} // '';
		$self->{_dbixConif}->{dbSource} = $params{'dsn'};
		
		$self->{_dbixSchema} = Database::Chado::Schema->connect($self->{_dbixConif}->{'dbSource'}, $self->{_dbixConif}->{'dbUser'},
				$self->{_dbixConif}->{'dbPass'}) or croak "Error: Could not connect to database";
	}
	else {
		my $dbi = $params{'dbi'} // croak 'Missing dbi argument.';
		my $dbName = $params{'dbName'} // croak 'Missing dbName argument.';
		my $dbHost = $params{'dbHost'} // croak 'Missing dbHost argument.';
		my $dbPort = $params{'dbPort'};
		
		$self->{_dbixConif}->{dbUser} = $params{'dbUser'} // croak 'Missing dbUser argument.';
		$self->{_dbixConif}->{dbPass} = $params{'dbPass'} // '';
		my $source = 'dbi:' . $dbi . ':dbname=' . $dbName . ';host=' . $dbHost;
		$source . ';port=' . $dbPort if $dbPort;
		$self->{_dbixConif}->{dbSource} = $source;
		
		$self->{_dbixSchema} = Database::Chado::Schema->connect($self->{_dbixConif}->{'dbSource'}, $self->{_dbixConif}->{'dbUser'},
				$self->{_dbixConif}->{'dbPass'}) or croak "Error: Could not connect to database";
	}
}

=head2 

DB connection parameters will be parsed from command-line options. 
If connection options are valid, a DB connection will be made by calling connectDatabase(). 

Note: because pass-through is set to true, options unrelated
to the database connection parameters will remain in the @ARGV array.

DB connection paramers (in order of prescedence):

1) --dbuser,
   --dbpass,
   --dsn

2) --config filename    A INI config file containg valid DB connection parameters: 
                          db.user, 
                          db.pass,
                          db.dsn or db.dbi + db.name + db.host + db.port




Returns the command-line options values in a hash-ref or undef if failed.

=cut

sub connectDatabaseCL {
	my $self = shift;

	Getopt::Long::Configure("pass_through");

	my %opts;
	GetOptions(\%opts, 'config=s', 'dsn=s', 'dbpass=s', 'dbuser=s') or
		croak "Error: GetOptions() failed for DB connection parameters ($!)";

	my ($dbsource, $dbuser, $dbpass);

	if(defined($opts{dsn})) {
		# Connection parameters are listed on command-line

		foreach my $p (qw/dbpass dbuser/) {
			croak "Error: Missing DB connection parameter: '--$p'." unless defined($opts{$p});
		}

		$dbsource = $opts{dsn};
		$dbuser = $opts{dbuser};
		$dbpass = $opts{dbpass};

	}
	elsif(defined($opts{config})) {
		# Connection parameters are in config file
		($dbsource, $dbuser, $dbpass) = $self->readConfig($opts{config});

		$self->{_dbixConif}->{dbConfig} = $opts{config};

	}
	else {
		croak "Error: Missing DB connection parameters.";
	}

	$self->connectDatabase(
		dsn    => $dbsource,
		dbUser => $dbuser,
		dbPass => $dbpass
	);

	Getopt::Long::Configure("no_pass_through"); # Reset Getopt::Long config

	return \%opts;
}

=head readConfig

Retrieve DB connection parameters from Superphy config file

=cut

sub readConfig {
	my $self = shift;
	my ($config) = @_;

	my ($dbsource, $dbuser, $dbpass);

	my $conf;
	unless($conf = Config::Tiny->read($config)) {
		croak "Config Error: $Config::Tiny::errstr\n";
	}

	if($conf->{db}->{dsn}) {
		$dbsource = $conf->{db}->{dsn};
	} 
	else {
		foreach my $p (qw/name dbi host/) {
			croak "Error: Missing DB connection parameter in config file: '$p'." 
				unless defined($conf->{db}->{$p});
		}
		$dbsource = 'dbi:' . $conf->{db}->{dbi} . 
			':dbname=' . $conf->{db}->{name} . 
			';host=' . $conf->{db}->{host};
		$dbsource . ';port=' .$conf->{db}->{port} if $conf->{db}->{port} ;
	}

	foreach my $p (qw/pass user/) {
		croak "Error: Missing DB connection parameter in config file: '$p'." 
			unless defined($conf->{db}->{$p});
	}

	$dbuser = $conf->{db}->{user};
	$dbpass = $conf->{db}->{pass};

	return ($dbsource, $dbuser, $dbpass);
}

=head connectDatabaseConf

DB connection parameters will be parsed from Superphy config file. 
If connection options are valid, a DB connection will be made by calling connectDatabase(). 

=cut

sub connectDatabaseConf {
	my $self = shift;
	my ($config) = @_;

	my ($dbsource, $dbuser, $dbpass) = $self->readConfig($config);

	$self->connectDatabase(
		dsn    => $dbsource,
		dbUser => $dbuser,
		dbPass => $dbpass
	);
}

=head2 dbixSchema

Return the dbix::class::schema object.

=cut

sub dbixSchema {
	my $self = shift;
	
	croak "Database not connected" unless $self->{_dbixSchema};
	
	return($self->{_dbixSchema});
}

=head2 dbixSchema

Set the dbix::class::schema object.

=cut

sub setDbix {
	my $self = shift;
	my $dbix_handle = shift;
	
	$self->{_dbixSchema} = $dbix_handle;
}

=head2 dbh

Return the DBI dbh from the dbix::class::schema object.

=cut

sub dbh {
	my $self = shift;
	
	croak "Database not connected" unless $self->{_dbixSchema};
	
	return($self->{_dbixSchema}->storage->dbh);
}

=head2 adminUser

Return entry in Login table corresponding to "System admin".
This user is used as a default for user groups e.g.

=cut

sub adminUser {
	my $self = shift;
	
	return $self->dbuser;
}

=head2 db*

Return DB connection parameters

=cut

sub dbuser {
	my $self = shift;
	
	return $self->{_dbixConif}->{dbUser};
}

sub dbpass {
	my $self = shift;
	
	return $self->{_dbixConif}->{dbPass};
}

sub dsn {
	my $self = shift;
	
	return $self->{_dbixConif}->{dbSource};
}

sub configFile {
	my $self = shift;
	
	return $self->{_dbixConif}->{dbConfig};
}

1;
