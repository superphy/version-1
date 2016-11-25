#!/usr/bin/env perl

=pod

=head1 NAME

Modules::Maintenance

=head1 SNYNOPSIS

=head1 DESCRIPTION

Displayed when site is down for maintenance

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm
=head1 AVAILABILITY

The most recent version of the code may be found at:

=head1 AUTHOR

Matt Whiteside

=head1 Methods

=cut

package Modules::Home;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Modules::FormDataGenerator;
use HTML::Template::HashWrapper;
use CGI::Application::Plugin::AutoRunmode;;

=head2 setup

Defines the start and run modes for CGI::Application and connects to the database.
Run modes are passed in as <reference name>=><subroutine name>

=cut

sub setup {
	my $self=shift;
	my $logger = Log::Log4perl::get_logger();
	$logger->info("Logger initialized in Modules::Home");
}

=head2 home

Run mode for the maintentance page.

=cut

sub maintentance : StartRunmode {
	my $self = shift;
	my $template = $self->load_tmpl( 'technical_difficulties.tmpl' , die_on_bad_params=>0 );

	
	return $template->output();
}

1;