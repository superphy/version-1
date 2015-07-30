#!/usr/bin/env perl

use strict;
use warnings;
use Bio::SearchIO;

my $inFile = $ARGV[0];

my $blastFH = Bio::SearchIO->new(
		-file => "<$inFile",
		-format => 'blastxml'
	);

while(my $result = $blastFH->next_result){
	while(my $hit = $result->next_hit){
		while(my $hsp = $hit->next_hsp){
			my $totalPercentID = $hsp->length('query') / $result->query_length * $hsp->percent_identity;
			if($totalPercentID >= 90){
				print($result->query_description
					 ,"\t"
					 ,$hit->name 
					 ,"\t"
					 ,$hit->description
					 ,"\t"
					 ,$totalPercentID
					 ,"\n"
					 );
			}
		}
	}
}
