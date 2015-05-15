#!/usr/bin/env perl

use strict;
use warnings;
use IO::File;

my $infile = $ARGV[0];

my $inFH = IO::File->new('<' . $infile) or die "$!";

my %vfNames;
while(my $line = $inFH->getline()){
    if($inFH->input_line_number == 1){
        next;
    }

    $line =~ s/\R//g;
    my @la = split(/\t/,$line);
    
    #[0] VF gene 
    #[1] Function    
    #[2] Uniprot 
    #[3]Categor(y/ies)  
    #[4] Sub Categor(y/ies)  
    #[5] Reference(s)    
    #[6] Ref Genome
    #[7] Sequence


    my $categories = $la[3];
    if(defined $la[4]){
        $categories .= ', ' . $la[4];
    }

    my $genome = $la[6];
    $genome =~ s/>//g;

    print('>' 
         . $la[0] . ' '
         . $la[1] . ', ' . $categories
         . ' [' . $genome . ']'
         . "\n"
         . $la[7] . "\n"
    );
    
}


$inFH->close();
