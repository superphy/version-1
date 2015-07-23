#!/usr/bin/env perl

=head1 NAME

$0 - Contains several packages needed for connecting to and accessing Database

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2014

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package Data::Bridge;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Modules::GenomeWarden;
use Role::Tiny::With;
with 'Roles::DatabaseConnector';
with 'Roles::CVMemory';
with 'Roles::Hosts';
use Log::Log4perl qw(:easy);
use Carp qw/croak/;
use Config::Simple;


# Initialize a basic logger
Log::Log4perl->easy_init($DEBUG);

=head2 new

Create DB connection by:
1) schema        Passing in handle to existing DBIx::Schema object
2) dbh           Passing in handle to existing DBI object
3) command-line  Parsing command-line @ARGV for DB connection parameters

=cut

sub new {
	my $class = shift;
	my %arg   = @_;

	my $self  = bless {}, ref($class) || $class;

	my $logger = Log::Log4perl->get_logger;
	$logger->debug('Initializing Bridge object');
	
	if($arg{schema}) {
		# Use existing DBIx::Class::Schema connection
		$self->setDbix($arg{schema});

	}
	elsif($arg{dbh}) {
		# Use existing DBI database handle
		$self->connectDatabase( dbh => $arg{dbh} );

	}
	elsif($arg{config}) {
		# Connect using config file
		$self->connectDatabaseConf($arg{config});

	}
	else {
		# Establish new DB connection using command-line args
		$self->connectDatabaseCL();
	}	
	
	return $self;
}

# Return a GenomeWarden object for a user
sub warden {
	my $self = shift;
	my $user = shift;
	my $genomes = shift;
	
	my $warden;
	if($genomes) {
		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, genomes => $genomes, user => $user, cvmemory => $self->cvmemory);
		my ($err, $bad1, $bad2) = $warden->error; 
		if($err) {
			# User requested invalid strains or strains that they do not have permission to view
			croak 'Request for uploaded genomes that user does not have permission to view ' .join('', @$bad1, @$bad2);
		}
		
	} else {
		
		$warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, user => $user, cvmemory => $self->cvmemory);
	}
	
	return $warden;
}



