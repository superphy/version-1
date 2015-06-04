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
	my $success = 1;

	return ($success, lc($v));
}

# If one of the patterns are found, replace
# with $replacement
sub _replacement {
	my $v = shift;
	my $patterns = shift;
	my $replacement = shift;

	my @compiled = map qr/$_/i, @$patterns;
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

	my @methods = qw/fix_human fix_cow fix_pig/;
	my $success = 0;

	foreach my $m (@methods) {
		my ($cleaned, $n) = $self->$m($v);

		$v = $n, $success = 1, last if $cleaned;
	}

	return ($success, $v);
}

# Convert all human synonyms to 'human'
sub fix_human {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		Homo sapiens
		human
		patient
		infant
		child
		9606
	/;

	return _replacement($v, \@inputs, 'hsapiens');
}

# Convert all cow synonyms to 'cow'
sub fix_cow {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		Bos taurus
		cattle
		calf
		bovine
	/;

	return _replacement($v, \@inputs, 'btaurus');
}

# Convert all pig synonyms to 'pig'
sub fix_pig {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		Sus scrofa
		piglet
		porcine
	/;

	return _replacement($v, \@inputs, 'sscrofa');
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


1;