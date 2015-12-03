#!/usr/bin/env perl

=pod

=head1 NAME

Modules::Statistics

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

package Modules::Statistics;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Log::Log4perl;
use Carp;
use Math::Round 'nlowmult';
use HTML::Template::HashWrapper;
use CGI::Application::Plugin::AutoRunmode;;

use JSON;

sub setup {
	my $self=shift;
	my $logger = Log::Log4perl->get_logger();
	$logger->info("Logger initialized in Modules::Statistics");
}

=head2 Statistics

Run mode for the statistics page 

=cut

sub stats : StartRunmode {
	my $self = shift;
	my $timeStamp = localtime(time);
	my $template = $self->load_tmpl( 'statistics.tmpl' , die_on_bad_params=>0 );

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

	my $lociCount = $self->dbixSchema->resultset('DataLociName')->count(
		{},
		{
			column  => [qw/locus_name/],
		}
		);

	my $snpCount = $self->dbixSchema->resultset('DataSnpName')->count(
		{},
		{
			column  => [qw/snp_name/],
		}
		);

	my $totalBasesCount = $self->dbixSchema->resultset('Feature')->search(
		{},
		{
			columns => [qw/seqlen/],
			join => ['type']
		}
		);
	my $totalBases = 0;
	while (my $seqlenRow = $totalBasesCount->next) {
		$totalBases = ($totalBases + $seqlenRow->seqlen); 
	}
	$totalBases = nlowmult( 0.01, ($totalBases/1000000000)); #in billion bases

	$template->param(GENOMECOUNT=>$genomeCount);
	$template->param(AMRGENECOUNT=>$amrGeneCount);
	$template->param(VIRFACTORCOUNT=>$virFactorGeneCount);
	$template->param(BASECOUNT=>$totalBases);
	$template->param(LOCICOUNT=>$lociCount);
	$template->param(SNPCOUNT=>$lociCount);
	$template->param(TIMESTAMP=>$timeStamp);

	return $template->output();
}

1;