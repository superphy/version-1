#!/usr/bin/env perl

=pod

=head1 NAME

Meta::CleanupRoutines.pm

=head1 DESCRIPTION

This object contains methods to transform 'dirty' attribute values into standardized values recognized by
validation routines.

This Role object is a container for all the cleanup_routine methods. It is added as plugin to the
main parsing object.

Cleanup routine methods have specification:
    Parameters: 
      [0] input string
    Returns array containing:
      [0] boolean indicating if formatting was performed
      [1] formatted string

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

package Meta::CleanupRoutines;

use strict;
use warnings;
use Role::Tiny;


# Remove leading and trailing ws
# Change case
sub basic_formatting {
	my $self = shift;
	my $v = shift;

	$v =~ s/^\s+//;
	$v =~ s/\s+$//;
	$v =~ s/[\[\(\)\]]//g;
	my $success = 1;

	return ($success, lc($v));
}

# If one of the patterns are found, replace
# with $replacement
sub _replacement {
	my $v = shift;
	my $patterns = shift;
	my $replacement = shift;

	my @compiled = map qr/\b$_\b/i, @$patterns;
	my $success = 0;
	foreach my $pat (@compiled) {
		$success = 1, last if $v =~ s/$pat/$replacement/;
    }
	
	return($success, $v);
}

# Wrapper for several synonym methods
# related to host
sub fix_hosts {
	my $self = shift;
	my $v = shift;

	my @methods = qw/fix_human fix_cow fix_pig fix_mouse fix_dog 
		fix_chicken fix_goat fix_horse fix_onion fix_rabbit/;
	my $success = 0;

	foreach my $m (@methods) {
		my ($cleaned, $n) = $self->$m($v);

		$v = $n, $success = 1, last if $cleaned;
	}

	return ($success, $v);
}

# Convert all human synonyms
sub fix_human {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		human
		patient
		infant
		child
		9606
	/;
	push @inputs, "Homo sapiens";

	return _replacement($v, \@inputs, 'hsapiens');
}

# Convert all cow synonyms
sub fix_cow {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		cow
		cattle
		calf
		bovine
	/;
	push @inputs, "Bos taurus";

	return _replacement($v, \@inputs, 'btaurus');
}

# Convert all pig synonyms
sub fix_pig {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		pig
		piglet
		porcine
	/;
	push @inputs, "Sus scrofa";

	return _replacement($v, \@inputs, 'sscrofa');
}

# Convert all mouse synonyms
sub fix_mouse {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		mouse
		mice
	/;
	push @inputs, "Mus musculus";

	return _replacement($v, \@inputs, 'mmusculus');
}

# Convert all chicken synonyms
sub fix_chicken {
	my $self = shift;
	my $v = shift;

	my @inputs = ("laying hen", "broiler chick", "Gallus gallus");
	push @inputs, qw/
		chicken
		chick
		rooster
		hen
	/;

	return _replacement($v, \@inputs, 'ggallus');
}

sub fix_rabbit {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		rabbit
	/;
	push @inputs, "Oryctolagus cuniculus";

	return _replacement($v, \@inputs, 'ocuniculus');
}

sub fix_horse {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		horse
	/;
	push @inputs, "Equus ferus caballus";

	return _replacement($v, \@inputs, 'eferus');
}

sub fix_dog {
	my $self = shift;
    my $v = shift;

    my @inputs = qw/
        dog
    /;
    push @inputs, "Canis lupus familiaris";

    return _replacement($v, \@inputs, 'clupus');
}

sub fix_onion {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
        onion
    /;
    push @inputs, "Allium cepa";

    return _replacement($v, \@inputs, 'acepa');

}

sub fix_goat {
	my $self = shift;
    my $v = shift;

    my @inputs = qw/
        goat 
    /;
    push @inputs, "Capra aegagrus hircus";

    return _replacement($v, \@inputs, 'caegagrus');

}


# Remove some useless text from strain name
sub remove_type_strain {
	my $self = shift;
	my $v = shift;

	my ($c) = ($v =~ s/Type Strain//i);

	return ($c, $v);
}

# Clarify that BEI refers to a company
sub bei_resources {
	my $self = shift;
	my $v = shift;

	my ($c) = ($v =~ s/^BEI\s/BEI Resoures Strain /i);

	return ($c, $v);
}

# Remove Ecoli from sample names
sub remove_ecoli_name {
	my $self = shift;
	my $v = shift;

	my ($c1) = ($v =~ s/^Escherichia coli\s//i);
	my ($c2) = ($v =~ s/^Ec\s/Ec/i);
	my $c = $c1 || $c2;

	return ($c, $v);
}

# Wrapper for several synonym methods
# related to source
sub fix_sources {
	my $self = shift;
	my $v = shift;

	my @methods = qw/fix_poop fix_intestine fix_ut/;
	my $success = 0;

	foreach my $m (@methods) {
		my ($cleaned, $n) = $self->$m($v);

		$v = $n, $success = 1, last if $cleaned;
	}

	return ($success, $v);
}

# Convert all stool synonyms
sub fix_poop {
	my $self = shift;
	my $v = shift;

	my @inputs = ("stool sample", "fecal sample", "feces envo:00002003");
	push @inputs, qw/
		stool
		feces
		fecal
	/;

	return _replacement($v, \@inputs, 'feces');
}

# Convert all urinary tract synonyms
sub fix_ut {
	my $self = shift;
	my $v = shift;

	my @inputs = ("urinary tract");
	push @inputs, qw/
		urogenital_tract
		genitourinary
	/;

	return _replacement($v, \@inputs, 'urogenital');
}

# Convert all intestine synonyms
sub fix_intestine {
	my $self = shift;
	my $v = shift;

	my @inputs = ("gastrointestinal_tract", "intestinal mucosa tissue");
	push @inputs, qw/
		gastrointestinal
	/;

	return _replacement($v, \@inputs, 'intestine');
}

# Map synonyms related to syndrome
sub fix_syndromes {
	my $self = shift;
	my $v = shift;

	my $success = 0;
	my %diseases = (
		uti => ['urinary tract infection', 'recurrent uti'],
		hus => ['hemolytic uremic syndrome'],
		hc => ['hemorrhagic colitis'],
		septicaemia => ['sepsis'],
		diarrhea => ['travellers diarhhea']
	);

	foreach my $d (keys %diseases) {
		my ($cleaned, $n) = _replacement($v, $diseases{$d}, $d);

		$v = $n, $success = 1, last if $cleaned;
	}

	return ($success, $v);
}

sub fix_serotypes {
	my $self = shift;
	my $v = shift;

	# Run serotype through some regex 'cleaners';
	$v = lc $v;
	# O fixes
	$v =~ s/\:k\d+//; # Remove capsule
	$v =~ s/\s*non-typable/nt/;
	$v =~ s/e. coli\s*\b//;
	$v =~ s/^sf//;
	$v =~ s/^or/ont/;
	$v =~ s/^0/o/; # Change 0 -> O
	$v =~ s/^(\d)/o$1/; # Put o in front of leading number

	# H fixes
	$v =~ s/\:h-$/\:nm/; # Missing H
	$v =~ s/\:-$/\:nm/;
	$v =~ s/\:$/\:na/;
	$v =~ s/^(o\d+)$/$1\:na/;

	return (1, $v);
}



1;
