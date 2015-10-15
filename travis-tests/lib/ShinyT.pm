#!/usr/bin/env perl

=pod

=head1 NAME

lib::ShinyT.pm

=head1 DESCRIPTION

Test module for shiny.t script

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

package t::lib::ShinyT;

use strict;
use warnings;
use Test::Builder::Module;
use List::MoreUtils qw(all);
use Sub::Exporter -setup => { exports => ['is_shiny_response'] };

sub is_shiny_response {
	my ($json, $name) = @_;

	$name ||= '';

	my $Test = Test::Builder::Module->builder;

	my @required_keys = qw(
		groups
		genomes
		CGISESSID
		group_ids
	);

	@required_keys = qw(genomes CGISESSID) unless $json->{user};

	return $Test->ok( (all { defined($json->{$_}) } @required_keys ), $name);
}



1;