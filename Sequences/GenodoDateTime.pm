#!/usr/bin/env perl

=pod

=head1 NAME

Sequences::GenodoDateTime

=head1 SNYNOPSIS

  my $dateTime = Sequences::GenodoDateTime->parse_datetime($date)

=head1 DESCRIPTION

  This class is designed to parse all the different date formats encountered in genbank 
  files and user uploaded forms.  Implements method parse_datetime which returns a DateTime object.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AVAILABILITY

The most recent version of the code may be found at:

=head1 AUTHOR

Matt Whiteside (mawhites@phac-aspc.gov.ca)

=head1 Methods

=cut

package Sequences::GenodoDateTime;

use strict;
use warnings;
use DateTime::Format::Strptime;
use DateTime qw/today/;

my $yeardays = 365.25;
my $monthdays = 30.4375;

# Genodo form 1998-01-01
my $ymd = DateTime::Format::Strptime->new(
	pattern   => '%Y-%m-%d',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);

# Genodo form 21-03-1992
my $dmy = DateTime::Format::Strptime->new(
	pattern   => '%d-%m-%Y',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);

# Genodo form 1998-01, saved as 01-01-1998
my $ym = DateTime::Format::Strptime->new(
	pattern   => '%Y-%m',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);

# Genbank 1999, saved as 01-01-1999
my $year = DateTime::Format::Strptime->new(
	pattern   => '%Y',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);

# Genbank APR-1991, saved as 01-04-1991
my $monyear = DateTime::Format::Strptime->new(
	pattern   => '%b-%Y',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);

# Genbank 15-APR-1991, saved as 15-04-1991
my $daymonyear = DateTime::Format::Strptime->new(
	pattern   => '%d-%b-%Y',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);

# Sample data APR-91, saved as 01-04-1991
my $monthyear = DateTime::Format::Strptime->new(
	pattern   => '%b-%y',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);

# Sample data 15-APR-91, saved as 15-04-1991
my $dmsmally = DateTime::Format::Strptime->new(
	pattern   => '%d-%b-%y',
	locale    => 'en_US',
	time_zone => 'America/Edmonton',
	on_error  => 'croak',
);


use DateTime::Format::Builder (
	parsers => { 
		parse_datetime => [
			sub { eval { $ymd->parse_datetime($_[1] ) } },
			sub { eval { $dmy->parse_datetime($_[1] ) } },
			sub { eval { $daymonyear->parse_datetime($_[1] ) } },
			sub { eval { $ym->parse_datetime($_[1] ) } },
			sub { eval { $monyear->parse_datetime($_[1],  ) } },
      		sub { eval { $year->parse_datetime($_[1] ) } },
      		sub { eval { $monthyear->parse_datetime($_[1] ) } },
      		sub { eval { $dmsmally->parse_datetime($_[1] ) } }
		]
	}
);

=head2 beforeToday

Check if date is prior to today

=cut

sub beforeToday {
	my ($dt) = @_;

	my $dt_target = DateTime->today();
   
    if( $dt && $dt_target && $dt <= $dt_target ) {
        return 1;
    } else {
        return 0;
    }
}

=head2 afterToday

Check if date is after today

=cut

sub afterToday {
	my ($dt) = @_;

	my $dt_target = DateTime->today();
   
    if( $dt && $dt_target && $dt > $dt_target ) {
        return 1;
    } else {
        return 0;
    }
}

=head2 ageIn

Convert age to common unit for storage in database

=cut

sub ageIn {
	my ($a, $u) = @_;

	my $days;
	
	if($u eq 'days') {
		$days = $a;
	} elsif($u eq 'months') {
		$days = $a*$monthdays;
	} elsif($u eq 'years') {
		$days = $a*$yeardays;
	}
	return($days);
}

=head2 ageIn

Convert the age in days stored in database
to common units for display

=cut

sub ageOut {
	my ($d) = @_;

	my $age;
	
	if($d >= $yeardays) {
		return($d/$yeardays, 'years');
	} elsif($d >= $monthdays) {
		return($d/$monthdays, 'months');
	} else {
		return($d, 'days');
	}
}

1;
