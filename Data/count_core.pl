#!/usr/bin/env perl
use strict;
use warnings;
use List::Util qw/sum/;

my $inFile = $ARGV[0];
open(my $f, '<', $inFile) or die "Cannot open $inFile. $!\n";
<$f>;
<$f>;

my @counts;
while(my $l = <$f>) {
	chomp $l;
	next unless $l;
	next if $l =~ m/^\(/;
	my ($n, $c) = split(/\|/, $l);
	$n =~ s/\s//g;
	$c =~ s/\s//g;
	push @counts, [$n, sum(split(//, $c))];
}
my @sorted = sort { $a->[1] <=> $b->[1] } @counts;
print join("\n", map { join(', ', @$_) } @sorted),"\n"; 
