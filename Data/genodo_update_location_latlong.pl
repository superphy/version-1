#!/usr/bin/env perl

use strict;
use warnings;

use Geo::Coder::Google;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Carp qw/croak carp/;
use Config::Simple;
use DBIx::Class::ResultSet;
use DBIx::Class::Row;

=head1 NAME

$0 - Updates all locations in genodo db with lat long coordinates.

=head1 SYNOPSIS

  % genodo_update_location_latlong.pl [options] 

=head1 COMMAND-LINE OPTIONS

 --config         Specify a .conf containing DB connection parameters.

=head1 DESCRIPTION

A one time use script to update all the locations currently in genodo with latlong coordinates.
User must provide connection parameters for the database in the form of a config file.

The script will access Googles geocoding service using the named locations in the database.

The geocoder returns a nunmber of coordinates. The script stores the center coordinates along
with the viewport (boundary) coordinates.

Center coordinates will be stored with the tag: 

<coordinates>
	<center>
		<lat>XX.XXX</lat>
		<lng>XX.XXX</lng>
	</center>
	<viewport>
		<southwest>
			<lat>XX.XXX</lat>
			<lng>XX.XXX</lng>
		</southwest>
		<northeast>
			<lat>XX.XXX</lat>
			<lng>XX.XXX<lng>
		</northeast>
	</viewport>
</coordinates>

=head1 AUTHOR

Akiff Manji

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI);

GetOptions(
	'config=s'      => \$CONFIG,
	) or ( system( 'pod2text', $0 ), exit -1 );

# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" . system ('pod2text', $0) unless $CONFIG;

if(my $db_conf = new Config::Simple($CONFIG)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
} 
else {
	die Config::Simple->error();
}

my $dbsource = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dbsource . ';port=' . $DBPORT if $DBPORT;

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS) or croak "Could not connect to database.";

# Need to first pull all the strains that have location data.
# Store the feature_id and featureprop_id in a table so that they can be updated easily.
my @locationList;

my $locationFeaturePropCount = $schema->resultset('Featureprop')->count({'type.name' => 'isolation_location'},{column  => [qw/me.feature_id me.value type.name/],join => ['type']});

print "\t...Found $locationFeaturePropCount locations in the database\n";
sleep(2);

my $locationFeatureProps = $schema->resultset('Featureprop')->search(
	{'type.name' => 'isolation_location'},
	{
		column  => [qw/me.feature_id me.value type.name me.featureprop_id/],
		join        => ['type']
	}
	);

#Create a new global geocoder
my $googleGeocoder = Geo::Coder::Google->new(apiver => 3);

while (my $locationRow = $locationFeatureProps->next) {
	my %location;
	my $locationFeaturepropId = $locationRow->featureprop_id;
	my $locationFeatureId = $locationRow->feature_id;
	my $markedUpLocation = $locationRow->value;

	print "Found location $markedUpLocation\n";

	## Need to parse out <markup></markup> tags for geocoding.
	my $noMarkupLocation = $markedUpLocation;
	$noMarkupLocation =~ s/(<[\/]*location>)//g;
	$noMarkupLocation =~ s/<[\/]+[\w\d]*>//g;
	$noMarkupLocation =~ s/<[\w\d]*>/, /g;
	$noMarkupLocation =~ s/, //;
	#print $noMarkupLocation . "\n";

	$location{'feature_id'} = $locationFeatureId;
	$location{'featureprop_id'} = $locationFeaturepropId;
	$location{'location'} = $noMarkupLocation;
	push(@locationList , \%location);
}

print "\t...Ready to convert " . scalar(@locationList) . " locations to lat long coordinates\n";

#List that will store already generated latlongs so that duplicate geocoding calls are not made.
my @coordinates;

foreach my $locationToConvert (@locationList) {
	print "Converting " . $locationToConvert->{'location'} . " to coordinates\n";
	my @foundCoordinate = (grep $_->{location} eq $locationToConvert->{'location'} , @coordinates);
	if (!@foundCoordinate) {
		my $location = $locationToConvert->{'location'};
		print "\tCalling geocoder on location '$location'...\n";
		my $latlong = $googleGeocoder->geocode(location => $location);
		print "\tFound coordinates " . $latlong->{geometry}->{location}->{lat} . "," . $latlong->{geometry}->{location}->{lng} . "\n";
		my %location;
		$location{'location'} = $locationToConvert->{'location'};
		$location{'coordinates'} = $latlong;
		push(@coordinates , \%location);
		#Let the geocode function sleep for 2 seconds before the next call, because Google rate-limits the number of calls that can be done and will return an error.
		print "\t...done\n";
		sleep(2);
		my @newCoordinate;
		push(@newCoordinate, \%location);
		updateDBLocation(\@newCoordinate , $locationToConvert);
	}
	else{
		print "\tFound coordinates " . $foundCoordinate[0]->{coordinates}->{geometry}->{location}->{lat} . "," . $foundCoordinate[0]->{coordinates}->{geometry}->{location}->{lng} . "\n";
		updateDBLocation(\@foundCoordinate , $locationToConvert);
	}
}

sub updateDBLocation {
	my $_coordinates = shift;
	my @_coordinates = @{$_coordinates};
	my $_locationToConvert = shift;

	print "\tAdding coordinates for " . $_locationToConvert->{'location'} . " to $DBNAME\n";

	my $locationRowToUpdate = $schema->resultset('Featureprop')->find({'me.featureprop_id' => $_locationToConvert->{'featureprop_id'}} , {'me.feature_id' => $_locationToConvert->{'feature_id'}});
	my $row  = $locationRowToUpdate->value;
	$row .= "<coordinates><center><lat>".$_coordinates[0]->{coordinates}->{geometry}->{location}->{lat}."</lat><lng>".$_coordinates[0]->{coordinates}->{geometry}->{location}->{lng}."</lng></center><viewport><southwest><lat>".$_coordinates[0]->{coordinates}->{geometry}->{viewport}->{southwest}->{lat}."</lat><lng>".$_coordinates[0]->{coordinates}->{geometry}->{viewport}->{southwest}->{lng}."</lng></southwest><northeast><lat>".$_coordinates[0]->{coordinates}->{geometry}->{viewport}->{northeast}->{lat}."</lat><lng>".$_coordinates[0]->{coordinates}->{geometry}->{viewport}->{northeast}->{lng}."</lng></northeast></viewport></coordinates>";
	my %newRow = ('value' => $row);
	$locationRowToUpdate->update(\%newRow) or croak "Could not update row\n";
}

print "...DONE\n";
