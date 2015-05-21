#!/usr/bin/env perl

=pod

=head1 NAME

Modules::LocationManager

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Akiff Manji (akiff.manji@gmail.com)

=cut

package Modules::LocationManager;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Log::Log4perl qw/get_logger :easy/;
use Carp;
use Geo::Coder::Google;
use JSON;
use Switch;

# Object creation
sub new {
    my ($class) = shift;
    my $self = {};
    bless( $self, $class );
    $self->_initialize(@_);
    return $self;
}

=head2 _initialize

Initializes the logger.
Assigns all values to class variables.
Anything else that the _initialize function does.

=cut

sub _initialize {
    my ($self) = shift;

    #logging
    $self->logger(Log::Log4perl->get_logger());
    $self->logger->info("Logger initialized in Modules::LocationManager");
    
    my %params = @_;
    #object construction set all parameters
    foreach my $key(keys %params){
        if($self->can($key)){
            $self->key($params{$key});
        }
        else {
            #logconfess calls the confess of Carp package, as well as logging to Log4perl
            $self->logger->logconfess("$key is not a valid parameter in Modules::LocationManager");
        }
    }
}

=head2 dbixSchema

A pointer to the dbix::class::schema object used in Application

=cut
sub dbixSchema {
    my $self = shift;
    $self->{'_dbixSchema'} = shift // return $self->{'_dbixSchema'};
}

=head2 logger

Stores a logger object for the module.

=cut

sub logger {
    my $self = shift;
    $self->{'_logger'} = shift // return $self->{'_logger'};
}

=head2 getStrainLocaion

# TODO:

=cut

sub getStrainLocation {
    my ($self, $genomeId, $genomePrivacy) = @_;
    
    my $searchTable = $genomePrivacy eq 'private' ? 'PrivateGenomeLocation' : 'GenomeLocation';
    die "genome privacy could not be determined" unless $searchTable;
    my $locationResult = $self->dbixSchema->resultset($searchTable)->search(
        {'me.feature_id' => "$genomeId"},
        {
            column => [qw/me.feature_id me.geocode_id geocode.location/],
            join => ['geocode']
        }
        );
    my %strainLocation = ('presence' => 0);
    while (my $location = $locationResult->next) {
        $strainLocation{'presence'} = 1;
        $strainLocation{'location'} = $location->geocode->location;
    }
    return \%strainLocation;
}

sub geocodeAddress {
    my ($self, $locationQuery) = @_;
    my ($result, $geolocation_id);
    
    #Look up geocoded_location table
    my $geocodedLocationRs = $self->dbixSchema->resultset('GeocodedLocation')->search(
        {search_query => "$locationQuery"},
        {
            column => [qw/location search_query/]
        }
        );

    #Handle error here that db doesnt return result
    if (defined $geocodedLocationRs && $geocodedLocationRs != 0) {
        $result = $geocodedLocationRs->first->location;
        $geolocation_id = $geocodedLocationRs->first->geocode_id;
        
        # Need to decode the result to add the geolocation id in
        my $decoded_result = decode_json($result);
        $decoded_result->{'geolocation_id'} = $geolocation_id;
        return encode_json($decoded_result);
    }

    print STDERR "Address: $locationQuery not found in database\n";

    my $googleGeocoder = Geo::Coder::Google->new(apiver => 3);
    $result = $googleGeocoder->geocode($locationQuery);        
    # If no result is found by Google the server will return a 500 server error

    my $result_json =  encode_json($result);

    # Need to store the result in the database
    $geocodedLocationRs->create({
        location => $result_json,
        search_query => "$locationQuery",
        });

    $result->{'geolocation_id'} = $geocodedLocationRs->first->geocode_id;

    print STDERR "Address: $locationQuery added to database\n";

    return encode_json($result);
}

sub parseGeocodedAddress {
    # TODO: 
    # Currently the only thing that we want from the geocoded locations:
    #   City : 'locality'
    #   Province/State: 'administrative_area_1'
    #   Country: 'country'
    my ($self, $locationJSONRef) = @_;
    my @address_components_array = $locationJSONRef->{'address_components'};
    my $parsed_location_ref = {};
    foreach my $address_components (@address_components_array) {
        foreach my $address_component_obj (@$address_components) {
            switch ($address_component_obj->{'types'}->[0]) {
                case ('country') {
                    $parsed_location_ref->{'isolation_country'} =  $address_component_obj->{'long_name'};
                }
                case ('administrative_area_level_1') {
                    $parsed_location_ref->{'isolation_province_state'} =  $address_component_obj->{'long_name'};
                }
                case ('locality') {
                    $parsed_location_ref->{'isolation_city'} =  $address_component_obj->{'long_name'};
                }
            }
        }
    }
    return $parsed_location_ref;
}

1;