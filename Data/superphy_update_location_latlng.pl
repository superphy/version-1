#!/usr/bin/env perl

use strict;
use warnings;

use Geo::Coder::Google;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use DBI;
use Carp qw/croak carp/;
use Config::Simple;
use JSON;
use IO::File;
use IO::Dir;

=head1 NAME

$0 - Updates all locations in genodo db with latLng coordinates.

=head1 SYNOPSIS

    % superphy_update_location_latlng.pl [options]

=head1 COMMAND-LINE OPTIONS

    --config        Sepecify a .conf file with DB connection parameters.

=head1 DESCRIPTION

A one time use script to update all the locations currently in superphys database with latlng coordinates.
User must provide connection parameters for the database in the form of a config file.

The script will access Googles geocoding service using the named locations in the database.

The geocoder returns a number of coordinates. The script stores the center coordinates along
with the viewport (boundary) coordinates.

Center coordinates will be stored in JSON format in the database:

Note: This script will delete any locations currently stored in the featureprop table of the database.
    Locations are now stored in a separate table that are referenced by id

location = 
    {   
        "name": "ABCDEF", 
        
        "coordinates": {
            
            "center" : {
                "lat": XX.XXX,
                "lng": XX.XXX
            },

            "viewport": {
                
                "southwest" : {
                    "lat": XX.XXX,
                    'lng': XX.XXX
                },
                
                "northeast" : {
                    "lat" : XX.XXX,
                    "lng" : XX.XXX
                }
            }
        }
    }

=head1 AUTHOR

Akiff Manji

=cut

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI);

GetOptions(
    'config=s'  => \$CONFIG,
    ) or ( system('pod2text', $0), exit -1);

# Connection params to the database
croak "Missing argument. You must supply a config filename.\n". system ('pod2text', $0) unless $CONFIG;

if (my $db_config = new Config::Simple($CONFIG)) {
    $DBNAME = $db_config->param('db.name');
    $DBUSER = $db_config->param('db.user');
    $DBPASS = $db_config->param('db.pass');
    $DBHOST = $db_config->param('db.host');
    $DBPORT = $db_config->param('db.port');
    $DBI = $db_config->param('db.dbi');
}
else {
    die Config::Simple->error();
}

#Connect to database
my $dbh = DBI->connect(
    "dbi:Pg:dbname=$DBNAME;port=$DBPORT;host=$DBHOST",
    $DBUSER,
    $DBPASS,
    {AutoCommit=> 0, TraceLevel=> 0}
    ) or die "Unable to connect to database: " . DBI->errstr;

print "\t...Connected\n";

#Create new global geocoder
my $googleGeocoder = Geo::Coder::Google->new(apiver => 3);
populateGeocodedLocations();
removeLocationFeatureprops();

#Resync database ##DO NOT REMOVE - Need to sync the setValue of the database with the max value of the copied table so postgres can update the next serial id correctly ##
print "\t...Syncing database\n";
my $syncStmt = ('SELECT setval(?, (SELECT MAX(geocode_id) FROM geocoded_location)+1)');
my $sth = $dbh->prepare($syncStmt) or die "Error! Could not prepare statement: " . $dbh->errstr;
$sth->execute('geocoded_location_geocode_id_seq') or die "Error! Could not execute statement: " . $dbh->errstr;
$sth->finish;

#Commit all changes and disconnect
$dbh->commit or die $dbh->errstr;
print "\t...Changes committed successfully\n";
$dbh->disconnect;
print "\t...Disconected\n";

sub populateGeocodedLocations {
    my ($locations, $public_genome_locations, $private_genome_locations) = _retrieveLocations();
    

    my %_geocode_ids;

    my $geocoded_count = 1;

    open my $fh, ">" , "temp_geocoded_locations.txt" or die "Error! Could not open file: $!\n";
    open my $pubfh, ">", "temp_public_genomes.txt" or die "Error! Could not open file: $!\n";
    open my $pvtfh, ">", "temp_private_genomes.txt" or die "Error! Could not open file: $!\n"; 
    
    foreach (keys %$locations) {
        print "Retrieving coordinates for: $_\n";
        print "Calling geocoder...\n";
        my $latLng = $googleGeocoder->geocode($_);
        die "Error. Could not retirieve coordinates\n." unless $latLng;
        $locations->{$_} = $latLng;
        
        $_geocode_ids{$_} = $geocoded_count;

        print $fh "$geocoded_count\t$_\t" . encode_json($latLng) . "\n";
        
        $geocoded_count++;

        sleep(1);
    }

    foreach (keys $public_genome_locations) {
        print $pubfh $_geocode_ids{$public_genome_locations->{$_}} . "\t$_\n";
    }

    foreach (keys $private_genome_locations) {
        print $pvtfh $_geocode_ids{$private_genome_locations->{$_}} . "\t$_\n";
    }

    close $fh;
    close $pubfh;
    close $pvtfh;
    
    #exit();

    #Populate geocoded_location
    $dbh->do("COPY geocoded_location(geocode_id, search_query, location) FROM STDIN");

    open my $copyfh1, "<", "temp_geocoded_locations.txt" or die "Error! Could not open file: $!\n";

    while (<$copyfh1>) {
        if (!($dbh->pg_putcopydata($_))) {
            $dbh->pg_putcopyend();
            $dbh->rollback;
            $dbh->disconnect;
            die "Error calling pg_putcopydata: $!\n";
        }
    }
    print "pg_putcopydata completed sucessfully.\n";

    $dbh->pg_putcopyend() or die "Error calling pg_putcopyend: $!\n";
    print "Data copy completed\n";

    close $copyfh1;


    #Populate genome_location table
    $dbh->do("COPY genome_location(geocode_id, feature_id) FROM STDIN");

    open my $copyfh2, "<", "temp_public_genomes.txt" or die "Error! Could not open file: $!\n";

    while (<$copyfh2>) {
        if (!($dbh->pg_putcopydata($_))) {
            $dbh->pg_putcopyend();
            $dbh->rollback;
            $dbh->disconnect;
            die "Error calling pg_putcopydata: $!\n";
        }
    }
    print "pg_putcopydata completed sucessfully.\n";

    $dbh->pg_putcopyend() or die "Error calling pg_putcopyend: $!\n";
    print "Data copy completed\n";
    
    close $copyfh2;


    # Populate private_genome_location_table
    $dbh->do("COPY private_genome_location(geocode_id, feature_id) FROM STDIN");

    open my $copyfh3, "<", "temp_private_genomes.txt" or die "Error! Could not open file: $!\n";

    while (<$copyfh3>) {
        if (!($dbh->pg_putcopydata($_))) {
            $dbh->pg_putcopyend();
            $dbh->rollback;
            $dbh->disconnect;
            die "Error calling pg_putcopydata: $!\n";
        }
    }
    print "pg_putcopydata completed sucessfully.\n";

    $dbh->pg_putcopyend() or die "Error calling pg_putcopyend: $!\n";
    print "Data copy completed\n";

    close $copyfh3;

    unlink("temp_geocoded_locations.txt");
    unlink("temp_public_genomes.txt");
    unlink("temp_private_genomes.txt");

    return;
}

sub _retrieveLocations {
    my (%_locations, %_public_genome_locations, %_private_genome_locations);
    
    #Get public genome locations
    my $sqlStmt1 = 'SELECT feature_id, value FROM featureprop JOIN cvterm ON (featureprop.type_id = cvterm.cvterm_id) WHERE cvterm.name = ?';
    my $sth = $dbh->prepare($sqlStmt1) or die "Error! Could not prepare statement: " . $dbh->errstr;
    my $queryResult = $sth->execute('isolation_location') or die "Error! Could not execute statement: " . $dbh->errstr;

    while (my $location = $sth->fetchrow_hashref) {
        my $_locationStr = _parseLocation($location->{'value'});
        print "PARSED ".$location->{'value'}. " GOT ". $_locationStr ."\n";
        my $_pubFeatureId = $location->{'feature_id'};
        $_locations{$_locationStr} = undef;
        $_public_genome_locations{$_pubFeatureId} = $_locationStr;
    }

    die $sth->errstr if $sth->errstr;

    #Get private genome locations
    my $sqlStmt2 = 'SELECT feature_id, value FROM private_featureprop JOIN cvterm ON (private_featureprop.type_id = cvterm.cvterm_id) WHERE cvterm.name = ?';
    $sth = $dbh->prepare($sqlStmt2) or die "Error! Could not prepare statement: " . $dbh->errstr;
    $queryResult = $sth->execute('isolation_location') or die "Error! Could not execute statement: " . $dbh->errstr;

    while (my $location = $sth->fetchrow_hashref) {
        my $_locationStr = _parseLocation($location->{'value'});
        my $_pvtFeatureId = $location->{'feature_id'};
        $_locations{$_locationStr} = undef;
        $_private_genome_locations{$_pvtFeatureId} = $_locationStr;
    }

    die $sth->errstr if $sth->errstr;

    return (\%_locations, \%_public_genome_locations, \%_private_genome_locations);
}

sub _parseLocation {
    my $_XMLlocation = shift;
    my $_location = $1 if ($_XMLlocation =~ m/(<location>.*<\/location>)/);
    die "Error! Location could not be parsed for: \n$_XMLlocation\n" unless $_location;
    $_location =~ s/(<[\/]*location>)//g;
    $_location =~ s/<[\/]+[\w\d]*>//g;
    $_location =~ s/<[\w\d]*>/, /g;
    $_location =~ s/, //;
    return $_location;
}

#Deletes all isolation_locations from the featureprop and private_featureprop tables
sub removeLocationFeatureprops {
    my $sqlStmt1 = 'DELETE FROM featureprop USING cvterm WHERE featureprop.type_id = cvterm.cvterm_id AND cvterm.name = ?';
    my $sth = $dbh->prepare($sqlStmt1) or die "Error! Could not prepare statement: " . $dbh->errstr;
    $sth->execute('isolation_location') or die "Error! Could not execute statement: " . $dbh->errstr;

    #Check that no rows are returned after the delete
    my $sqlStmt2 = 'SELECT COUNT(*) FROM featureprop JOIN cvterm ON (featureprop.type_id = cvterm.cvterm_id) WHERE cvterm.name = ?';
    $sth = $dbh->prepare($sqlStmt2) or die "Error! Could not prepare statement: " . $dbh->errstr;;
    my $rv = $sth->execute('isolation_location') or die "Error! Could not execute statement: " . $dbh->errstr;
    
    while(my @data = $sth->fetchrow_array()){
        print $data[0] . " rows found\n";
    }

    unless($sth->rows > 0) {
        $dbh->rollback;
        $dbh->disconnect;
        die "Error! Could not execute statement: " . $dbh->errstr;
    }
    return;
}
