#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Carp;
use Data::Dumper;

=head1 NAME

$0 - Checks which genomes have annotated terms used in superphy

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --dir     Directory containing meta-data PERL hash strings produced by genbank_to_genodo.pl script

=head1 DESCRIPTION



=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

{
	package MetaCounter;

	sub new {
		my $class = shift;
		my %args = @_;
		
		my $self = {};
		
		# Terms to look for in genome annotation
		$self->{'tags'} = {
			'serotype' => 0,
			'isolation_date' => 1,
			'isolation_location' => 2,
			'isolation_host' => 3,
			'isolation_source' => 4,
			'syndrome' => 5
		};

		$self->{ordered_tags} = [ sort { $self->{'tags'}->{$a} <=> $self->{'tags'}->{$b} } keys %{$self->{'tags'}} ];
		$self->{num_tags} = scalar(@{$self->{ordered_tags}});

		$self->{'counts'} = [];
		
		
		bless $self, $class;
		return $self;
	}
	
	sub record {
		my $self = shift;
		my $data_hash = shift;

		
		my @current_counts = (0) x $self->{num_tags};

		foreach my $tag (@{$self->{ordered_tags}}) {
			if(defined $data_hash->{$tag}) {
				$current_counts[$self->{'tags'}->{$tag}] = 1;
			}
		}

		push @{$self->{'counts'}}, \@current_counts;
	}


	sub report {
		my $self = shift;

		# Count values
		my @totals = (0) x $self->{num_tags};
		my @freqs = (0) x $self->{num_tags};

		foreach my $row (@{$self->{counts}}) {
			my $num_tag = 0;
			for(my $i = 0; $i < $self->{num_tags}; $i++) {
				$totals[$i] += $row->[$i];
				$num_tag += $row->[$i];
			}

			$freqs[$num_tag]++;
		}

		# Prepare report
		my %report = ();
		foreach my $tag (@{$self->{ordered_tags}}) {
			$report{individual}{$tag} = $totals[$self->{tags}->{$tag}];
		}

		for(my $i = 0; $i < $self->{num_tags}; $i++) {
			$report{total}{$i} = $freqs[$i];
		}

		$report{num_genomes} = scalar(@{$self->{counts}});

		return \%report;
	}


}

## MAIN

$|=1;

# Parse command-line options
my ($DIR);

GetOptions(
	'dir=s'=> \$DIR,
) || (pod2usage(-verbose => 1) && exit);

croak "Missing argument. You must supply a meta-data directory.\n" unless $DIR && -d $DIR;
$DIR .= '/' unless $DIR =~ m/\/$/;

# Get list of files in directory
opendir(my $dh, $DIR) || die "Error: can't opendir $DIR ($!)";
my @files = grep { /txt$/ && -f "$DIR/$_" } readdir($dh);
closedir $dh;

@files = map {$DIR . $_ } @files;

# Iterate through files
# Count meta-data attributes
my $metaCounter = MetaCounter->new();

foreach my $file (@files) {
	my $properties = load_input_parameters($file);

	$metaCounter->record($properties);
}

my $results = $metaCounter->report();

print Dumper($results);

## SUBS

=head2 load_input_parameters

loads hash produced by Data::Dumper with genome properties and upload user settings.

=cut

sub load_input_parameters {
	my $file = shift;
	
	open(IN, "<$file") or die "Error: unable to read file $file ($!).\n";

    local($/) = "";
    my($str) = <IN>;
    
    close IN;
    
    my $contig_collection_properties;
    eval $str;
    
    return ($contig_collection_properties);
}







