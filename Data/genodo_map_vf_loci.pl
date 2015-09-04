#!/usr/bin/env perl

use strict;
use warnings;

#Quick script to map loci ids to the correct data tags so file can be uploaded to the database

my ($binaryFile, $annofile) = @ARGV;

open my $annofh, "<", $annofile or die "Could not open $annofile: $!\n";
#Only need the first two columns of the annotation file. Column 1 is the locus ID, column 2 is the VF ID.
my %locusIDs;
while (<$annofh>) {
	$_ =~ s/\R//g;
	my @temp = split(/\t/, $_);
	$locusIDs{$temp[0]} = $temp[1];
}
close $annofh;

open my $binaryfh, "<", $binaryFile or die "Could not open $binaryFile: $!\n";

my $firstLine;
my @results;
while (<$binaryfh>) {
	$firstLine = $_ if $. == 1;
	if ($. > 1) {
		my @temp = split(/\t/, $_);
		$temp[0] = $locusIDs{$temp[0]} if exists $temp[0];
		push(@results, \@temp);
	}
}
close $binaryfh;

#Write out new file
open my $binaryWriter, ">>", "mapped_vf_binary.txt" or die "Could not initialize file: $!\n";

print $binaryWriter $firstLine;

foreach my $arres (@results) {
	print $binaryWriter join("\t", @{$arres});
}

close $binaryWriter;