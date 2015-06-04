#!/usr/bin/env perl

=pod

=head1 NAME

Meta::ValidationRoutines.pm

=head1 DESCRIPTION

This object contains methods to convert attribute-value pairs to Superphy meta-data terms and standard
values.

This Role object is a container for all the validation_routine methods. It is added as plugin to the
main parsing object.

Validation routine methods have specification:
    Parameters: 
      [0] input string
    Returns:
      False when no match was found
        -or-
      String 'skip' to ignore values like 'NA' or 'missing'
        -or-
      Array containing [0] = meta_data term AND [1] = meta-data hash-ref as follows:
        - when meta_term = 'isolation_host'
          { id => host table ID matching host value,
            meta_term => 'isolation_host',
            category => host_category ID for human, mammal, bird, environment categories,
            displayname => English description of value used in debugging messages
          }
        - when meta_term = 'isolation_source' or 'syndrome'
          { host_category_id => {
               id => source|syndrome table ID matching value,
               meta_term => 'isolation_source'|'syndrome',
               displayname => English description of value used in debugging messages
            },
            ...(for each category that has value matching that source|syndrome)
          }
        - when meta_term = 'isolation_date', 'isolation_location', 'serotype'
          { meta_term = 'isolation_date'|'isolation_location'|'serotype',
            value = string value,
            displayname => English description of value used in debugging messages
          }
        - when meta_term = 'strain'
          { meta_term = 'strain',
            value = string value,
            priority = 1:3,
            displayname => English description of value used in debugging messages
          }

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

package Meta::ValidationRoutines;

use strict;
use warnings;
use Data::Dumper;
use Role::Tiny;



##################
# Utility methods
##################


# If the exact string is found, return success
# case insensitive
sub _exact_match {
	my $v = shift;
	my $patterns = shift;

	my @compiled = map qr/^$_$/i, @$patterns;
	my $success = 0;
	foreach my $pat (@compiled) {
		if($v =~ /$pat/) {
			return 1;
		}
    }
	
	return(0);
}



##################
# Matching methods
##################

# Hosts
sub hosts {
	my $self = shift;
	my $v = shift;

	my %inputs = %{$self->{hosts}};

	if(_exact_match($v, [keys %inputs])) {
		return ('isolation_host', $inputs{$v});
	}
	else {
		return 0;
	}
}

# Sources
sub sources {
	my $self = shift;
	my $v = shift;

	my %inputs = %{$self->{sources}};
	
	if(_exact_match($v, [keys %inputs])) {
		return ('isolation_source', $inputs{$v});
	}
	else {
		return 0;
	}
}

# Syndromes
sub syndromes {
	my $self = shift;
	my $v = shift;

	my %inputs = %{$self->{syndromes}};
	
	if(_exact_match($v, [keys %inputs])) {
		return ('syndrome', $inputs{$v});
	}
	else {
		return 0;
	}
}

# TODO Nicolas
sub locations {
	my $self = shift;
	my $v = shift;


	# Check that v contains a valid location name

	# See guessLocation in Sequences::genbank_to_genodo.pl
	# For examples
	my $valid_v = 'TBD';

	# Return value:
	return ('isolation_location', { value => $valid_v, meta_term => 'isolation_location', displayname => $valid_v });
}

# TODO Nicolas
sub serotypes {
	my $self = shift;
	my $v = shift;


	# Check that v contains a valid serotype designation and convert to consistent format

	# There is currently nothing for serotypes
	# You will need to develop from scratch
	# There is sort of is a consistent format for serotypes
	# I will let figure it out
	my $valid_v = 'TBD';

	# Return value:
	return ('serotype', { value => $valid_v, meta_term => 'serotype', displayname => $valid_v });
}

# TODO Nicolas
sub dates {
	my $self = shift;
	my $v = shift;


	# Check that v contains a valid date and convert to consistent format YYYY-MM-DD

	# Perl has libraries for this, see Sequences::GenodoDateTime and collection date parsing
	# in genbank_to_genodo.pl
	# Make sure date is not in the future
	my $valid_v = 'TBD';

	# Return value:
	return ('serotype', { value => $valid_v, meta_term => 'serotype', displayname => $valid_v });
}

sub host_sources {
	my $self = shift;
	my $v = shift;


	# if(my $v = _exact_match($v, [keys %inputs])) {
	# 	return $inputs{$v};
	# }
	# else {
	# 	return 0;
	# }
}

# Is this a non-value like 'missing'
sub skip_value {
	my $self = shift;
	my $v = shift;

	my @inputs = qr/
		missing
		N\/A
		NA
	/;

	if(_exact_match($v, \@inputs)) {
		return 'skip';
	}
	else {
		return 0;
	}

}


##################
# Attribute Specific methods
##################

1;
