#!/usr/bin/env perl

=pod

=head1 NAME

Modules::FastaFileWrite - A class that provides the following functionality:

=head1 SYNOPSIS

	use Modules::FastaFileWrite;
	...

=head1 DESCRIPTION

This module can be called to write out whole genomes to files selected from the multi strain selection form on the website.
The fasta files will then be passed to the Panseq analysis platform for statistical analysis.

=head1 ACKNOWLEDGEMENTS

Thanks.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.html

=head1 AVAILABILITY

The most recent version of the code may be found at:

=head1 AUTHOR

Akiff Manji (akiff.manji@gmail.com)

=head1 Methods

=cut

package Modules::FastaFileWrite;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use IO::File;
use IO::Dir;
use Log::Log4perl;
use Carp;
umask 0000;

#object creation
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

=cut

sub _initialize {
	my ($self) = shift;

	#logging
	$self->logger(Log::Log4perl->get_logger());
	$self->logger->info("Logger initialized in Modules::FastaFileWrite");

	my %params = @_;

	#object construction set all parameters
	foreach my $key(keys %params){
		if($self->can($key)){
			$self->key($params{$key});
		}
		else {
		#logconfess calls the confess of Carp package, as well as logging to Log4perl
		$self->logger->logconfess("$key is not a valid parameter in Modules::FastaFileWrite");
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

=head2 writeStrainsToFile

Method which takes in a list of contigs for a single genome and writes it out to a fasta file.

=cut


sub writeStrainsToFile {
	my $self = shift;
	my $strainNames = shift;
	my $outDirectoryName = "../../Sequences/FastAnalysis/";

	#Returns an array reference to a list of %genome.
	my $genomeRef = $self->_hashStrains($strainNames);

	foreach my $genome (@{$genomeRef}) {
		my $outFile = $genome->{'genome_name'};
		open(OUT, '>' . "$outDirectoryName" . "$outFile") or die "$!";
		#my $newFH = \*OUT; If you wanted to pass the handler off to another method

		foreach my $contig (@{$genome->{'contigs'}}){
			print(OUT ">" . $contig->{'name'} . $contig->{'description'} . "\n" . $contig->{'residues'} . "\n") or die "$!";
		}
		close(OUT);
	}
}

sub _hashStrains {
	my $self = shift;
	my $strainNames = shift;
	my @genomeList;

	#Genomes are stored with the following structure:
	# %Genome{{name => '<genome_name>'},
	# 		@contigs[%contig{
	# 			{name => '<contig_name'},
	# 			{residues => '<dna_residues>'},
	# 			{description => '<contig_description>'}
	# 			}]
	# }


	foreach my $strainName (@{$strainNames}) {
		my %genome;
		my @contigs;
		my $featureProperties = $self->dbixSchema->resultset('Featureprop')->search(
			{value => "$strainName"},
			{
				column => [qw/me.feature_id/]
			}
			);
		while (my $featureRow = $featureProperties->next) {
			my %contig;
			my $contigRowId = $featureRow->feature_id;
			my $contigRow = $self->dbixSchema->resultset('Feature')->find({feature_id => $contigRowId});
			$contig{'name'} = $contigRow->name;
			$contig{'residues'} = $contigRow->residues;

			my $_contigDescription = $self->dbixSchema->resultset('Featureprop')->search(
				{'me.feature_id' => $contigRowId},
				{
					join => ['type'],
					column => [qw/me.value/]
				}
				);
			my $contDesc = "";
			while (my $cont = $_contigDescription->next) {
				$contDesc =  $contDesc . ", " . $cont->value;
			}
			$contig{'description'} = $contDesc;
			push(@contigs , \%contig);
		}
		$strainName =~ s/\//-/;
		$genome{'genome_name'} = $strainName;
		$genome{'contigs'} = \@contigs;
		push (@genomeList , \%genome);
	}
	return \@genomeList;
}

#The file writeout needs to be able to take in a series of fasta headers and write them out to a fasta file
1;