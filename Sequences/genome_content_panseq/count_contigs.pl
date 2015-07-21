#!/usr/bin/env perl

use strict;
use warnings;
use IO::File;

my $inFile = $ARGV[0];

open (my $inFH, '<', $inFile) or die "Could not open $inFile $!\n";

my %contigCounts;
my $genome;
my $size=0;
while(my $line = $inFH->getline()){
    $line =~ s/\R//g;

    if($line =~ m/^>lcl\|(public_\d+)/){
        my $tempGenome = $1;
        #check to see if we are on a new genome
        #add the genome size to the previous genome if we are not
        if(defined $genome){
            if($tempGenome eq $genome){
                #do nothing, still collecting counts
            }
            else{
                $contigCounts{$genome}->{size}=$size;
                $size=0;
            }
        }

        $genome = $tempGenome;

        if(defined $contigCounts{$genome} && defined $contigCounts{$genome}->{contigs}){
            $contigCounts{$genome}->{contigs} = $contigCounts{$genome}->{contigs} +1;
        }
        else{
            $contigCounts{$genome}->{contigs} = 1;
        }
    }
    else{
        $size += length($line);
    }
}

foreach my $g(keys %contigCounts){
    print($g
         ,"\t"
         ,$contigCounts{$g}->{contigs}
         ,"\t"
         ,$contigCounts{$g}->{size}
         ,"\n"
         );
}

