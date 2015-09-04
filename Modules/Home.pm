#!/usr/bin/env perl

=pod

=head1 NAME

Modules::Home

=head1 SNYNOPSIS

=head1 DESCRIPTION

=head1 ACKNOWLEDGMENTS

Thank you to Dr. Chad Laing and Dr. Matthew Whiteside, for all their assistance on this project

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm
=head1 AVAILABILITY

The most recent version of the code may be found at:

=head1 AUTHOR

Akiff Manji (akiff.manji@gmail.com)

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

Run mode for the home page.

=cut

sub home : StartRunmode {
	my $self = shift;
	my $template = $self->load_tmpl( 'home.tmpl' , die_on_bad_params=>0 );

	my $session_id = $self->session->id();

	print STDERR "Session id at home page is: $session_id\n";
	print STDERR "User currently logged in is: " . $self->authen->username . "\n" if $self->authen->username;

	my $genomeCount = $self->dbixSchema->resultset('Feature')->count(
		{'type.name' =>  'contig_collection'},
		{
			columns => [qw/feature_id/],
			join => ['type']
		}
		);
	
	my $amrGeneCount = $self->dbixSchema->resultset('Feature')->count(
		{'type.name' =>  'antimicrobial_resistance_gene'},
		{
			columns => [qw/feature_id/],
			join => ['type']
		}
		);

	my $virFactorGeneCount = $self->dbixSchema->resultset('Feature')->count(
		{'type.name' =>  'gene', 'featureprops.value' => "Virulence Factor"},
		{
			column  => [qw/feature_id/],
			join        => ['featureprops' , 'type']
		}
		);

	# my $lociCount = $self->dbixSchema->resultset('Loci')->count(
	# 	{},
	# 	{
	# 		column  => [qw/locus_name/],
	# 	}
	# 	);

#	my $snpCount = $self->dbixSchema->resultset('DataSnpName')->count(
#		{},
#		{
#			column  => [qw/snp_name/],
#		}
#		);


	$template->param(GENOMECOUNT=>$genomeCount);
	$template->param(AMRGENECOUNT=>$amrGeneCount);
	$template->param(VIRFACTORCOUNT=>$virFactorGeneCount);
	#$template->param(LOCICOUNT=>$lociCount);
	#$template->param(SNPCOUNT=>$snpCount);
	return $template->output();
}

1;