#!/usr/bin/env perl


=head1 NAME

$0 - Updates the location field in the geocode table with new Google API geocode json values

=head1 SYNOPSIS

    % superphy_update_geocodes.pl [options]

=head1 COMMAND-LINE OPTIONS

    --config        Specify a .conf file with DB connection parameters.

=head1 DESCRIPTION

New Google geocode json values are retrieved using the search_query field in 
table geocode_location and inserted in the location field. This script corrects
a bug with the original location value formats.

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Geo::Coder::Google;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Carp qw/croak carp/;
use Data::Bridge;
use Config::Simple;
use JSON::Any;
use Log::Log4perl qw(:easy);

# Initialize logger
Log::Log4perl->easy_init($DEBUG);


# Connect to database via Bridge module
my $bridge = Data::Bridge->new();


# Create new global geocoder
my $googleGeocoder = Geo::Coder::Google->new(apiver => 3);


# Perform update in transaction block
my $guard = $bridge->dbixSchema->txn_scope_guard;


# Iterate through the geocode entrys
my $geo_sth = $bridge->dbixSchema->resultset('GeocodedLocation')->search();

while(my $geo_row = $geo_sth->next) {

    my $query = $geo_row->search_query;
    get_logger->info("Updating geocode for: $query\n");

    my $gc = $googleGeocoder->geocode($query) or 
        get_logger->logdie("Geocode failed for query: $query\n");

    my $json = JSON::Any->to_json($gc) or
        get_logger->logdie("JSON conversion failed: $query\n");
    
    $geo_row->update({ location => $json }) or
        get_logger->logdie("Database update failed: $query\n");
    
    sleep(3);
}

# Commit
$guard->commit;

