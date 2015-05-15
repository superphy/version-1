#!/usr/bin/env perl

use strict;
use warnings;
use Bio::DB::GenBank;
use Bio::DB::Query::GenBank;
use IO::File;

my $inputFile = $ARGV[0];

my $inFH = IO::File->new('<' . $inputFile) or die "$!";

my %vf;
my @proteinIds;

my $dounter = 0;
while(my $line = $inFH->getline()){
    unless($line =~ m/^>/){
        next;
    }
    $line =~ s/\R//g;

    my @la = split(/\s+/, $line);

    if($la[0] =~ m/>(.+)/){
        my $geneName = $1;
        #test to see if the query exists in Genbank -- if not, don't add
        my $tempQuery;

        eval{$tempQuery = Bio::DB::Query::GenBank->new(
            -db=>'nucleotide',
            -ids=>[$la[1]]
        )};

        if($@){
            print STDERR "Could not find $la[1], adding to protein list\n";
            push @proteinIds, $la[1];
            next;
        }
        print STDERR "file: $la[1]\n";

        $vf{$la[1]}->{geneName}=$geneName;

        #get the start / stop positions
        if(!defined $la[2]){
            $vf{$la[1]}->{'start'}=1;
            $vf{$la[1]}->{'stop'}='all';
        }
        elsif($la[2] =~ m/(\d+)(\-+|_+)(\d+)/){
            my $start = $1;
            my $end = $3;

            if($start > $end){
                ($start,$end) = ($end,$start);
            }

            $vf{$la[1]}->{'start'}=$start;
            $vf{$la[1]}->{'stop'}=$end;
        }
        else{
            print "Could not parse start / stop positions $la[2]\n$line";
            exit(1);
        }
    }
    else{
        print "Could not find gene name\n";
        exit(1);
    }
}
continue{
    $dounter++;
    # if($dounter == 100){
    #     last;
    # }
}



my $query = Bio::DB::Query::GenBank->new(
        -db=>'nucleotide',
        -ids=>[sort keys %vf]
    );


my $gb = Bio::DB::GenBank->new();
my $stream = $gb->get_Stream_by_query($query);

my $counter=0;
while(my $seq = $stream->next_seq()){
    my $currId = $seq->accession_number();

    unless(defined $vf{$currId}){
        print STDERR "$currId not defined, skipping\n";
        next;
    }

    print STDERR "Processing $currId " . 
        $vf{$currId}->{geneName} . 
        ' length: ' . $seq->length() . "\n"
        . ' start: ' . $vf{$currId}->{start}
        . ' stop: ' . $vf{$currId}->{stop} . "\n";
    my $endBp;
    if($vf{$currId}->{stop} eq 'all'){
        $endBp = $seq->length();
    }
    else{
        $endBp = $vf{$currId}->{stop};
    }

    print('>' . $vf{$currId}->{geneName}  . ' ' . $seq->desc() .
        ' [' . $currId . ' ' . $vf{$currId}->{start} . '-' . 
        $endBp . "]\n" . 
        $seq->subseq($vf{$currId}->{start},$vf{$currId}->{stop}) . "\n");
}
continue{
    $counter++;
}
$inFH->close();
