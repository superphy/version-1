#!/usr/bin/perl

use strict;
use warnings;

use Geo::Coder::Google;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use File::Basename;
use Carp qw/croak carp/;
use Config::Simple;
use DBI;

=head1 NAME

$0 - Removes sequences from the feature and featureprops tables.

=head1 SYNOPSIS

% genodo_remove_sequences.pl [options]

=head1 COMMAND-LINE OPTIONS

	--config 			Specify a .conf containing DB connection parameters.
	--seq_type 		Specify whether virulence or amr genes to delete

=head1 DESCRIPTION

=head1 AUTHOR

Akiff Maniji

=cut

my ($CONFIG, $dbname, $dbuser, $dbhost, $dbpass, $dbport, $DBI, $type);

GetOptions(
	'config=s' => \$CONFIG,
	'seq_type=s' => \$type
	) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system('pod2text', $0) unless $CONFIG;
croak "Missing argument. You must specify which genes to delete (ex. virulence, amr).\n" . system('pod2text', $0) unless $type;

if(my $db_conf = new Config::Simple($CONFIG)) {
	$dbname    = $db_conf->param('db.name');
	$dbuser    = $db_conf->param('db.user');
	$dbpass    = $db_conf->param('db.pass');
	$dbhost    = $db_conf->param('db.host');
	$dbport    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
} 
else {
	die Config::Simple->error();
}

die "Invalid configuration file.\n" unless $dbname;

my $dbh = DBI->connect(
	"dbi:Pg:dbname=$dbname;port=$dbport;host=$dbhost",
	$dbuser,
	$dbpass,
	{AutoCommit => 0, TraceLevel => 0}
	) or die "Unable to connect to database: " . DBI->errstr;


# Get type ID;
my $typeID;
if ($type eq 'virulence') {
	$typeID = getGeneTypeID();
	die "type_id not reurned for $type" unless ($typeID);
	deleteGenes($typeID);
}
elsif ($type eq 'amr') {
	$typeID = getAMRTypeID();
	die "type_id not reurned for $type" unless ($typeID);
	deleteGenes($typeID);
}
else {
	die "Invalid argument provided.\n" . system('pod2text', $0);
}

sub getGeneTypeID {
	my $cvterm = 'virulence_factor';
	my $sth = $dbh->prepare('SELECT cvterm_id FROM cvterm WHERE name = ?')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($cvterm) or die "Couldn't execute statement: " . $sth->errstr;
	my $_cvterm_id;
	while (my @data = $sth->fetchrow_array()) {
		$_cvterm_id = $data[0];
	} 
	return $_cvterm_id;
}

sub getAMRTypeID {
	my $cvterm = 'antimicrobial_resistance_gene';
	my $sth = $dbh->prepare('SELECT cvterm_id FROM cvterm WHERE name = ?')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth->execute($cvterm) or die "Couldn't execute statement: " . $sth->errstr;
	my $_cvterm_id;
	while (my @data = $sth->fetchrow_array()) {
		 $_cvterm_id = $data[0];
	}
	return $_cvterm_id;
}

sub deleteGenes {
	my $_type_id = shift;
	my $sth = $dbh->prepare('SELECT feature_id FROM feature WHERE type_id = ? ')
	or die "Couldn't prepare statement: " . $dbh->errstr;
	$sth ->execute($_type_id) or die "Couldn't execute statement: " . $sth->errstr;
	my $feature_ids = $sth->fetchall_arrayref();
	foreach my $feature_id (@$feature_ids) {
		#Delete all rows from the featureprops table 
		my $sth = $dbh->prepare('DELETE FROM featureprop USING feature WHERE featureprop.feature_id = feature.feature_id AND feature.feature_id = ?')
		or die "Couldn't prepare statement: " . $dbh->errstr;
		$sth->execute($feature_id->[0]) or die "Couldn't execute statement: " . $sth->errstr;
		$sth->finish;
		#Delete all rows from the feature table;
		my $sth2 = $dbh->prepare('DELETE FROM feature WHERE feature.feature_id = ?')
		or die "Couldn't prepare statement: " . $dbh->errstr;
		$sth2->execute($feature_id->[0]) or die "Couldn't execute statement: " . $sth2->errstr;
		$sth2->finish;
	}
	$dbh->commit;
	$dbh->disconnect;
	print "Sequences removed.\n"
}