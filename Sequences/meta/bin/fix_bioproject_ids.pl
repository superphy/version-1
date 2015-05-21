#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

$0 - Fixes BioProject IDs so the BioPerl parser Bio::SeqIO::genbank.pm can recognize the ID

=head1 SYNOPSIS

  % $0 genbank_file_directory

=head1 DESCRIPTION

BioPerl has not caught up with recent changes in NCBI's BioProject ID assignment.

BioProject Accessions have format PRJNA123456, the parser only recognizes IDs consisting of
numeric digits.  This script removes the PRJNA to switch from the accession to simple id number.

Both point to the same entity in BioProject DB.

The program will modify all files matching the regex and then output them to a file called *_fixed.*

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

$|=1;

my $dir = $ARGV[0];
die "Error: missing/invalid command line argument: input directory" unless -e $dir && -d $dir;

opendir(my $dh, $dir) || die "Error: can't opendir $dir: $!";
my @gbk_files = grep { /\.gbk$/ && -f "$dir/$_" } readdir($dh);
closedir $dh;

print "Fixing ".(scalar @gbk_files)." genbank files...\n";

foreach my $file (@gbk_files) {
	my $f = $dir . $file;
	open(IN, "<$f") or die "Error: cannot read file $f: $!";
	$f =~ s/\.gbk$/_fixed\.gbk/;
	open(OUT, ">$f") or die "Error: cannot write to file $f: $!";
	
	while(<IN>) {
		s/BioProject: PRJ[END]\w(\d+)/BioProject: $1/;
		print OUT $_;
	}
	close IN;
	close OUT;
	
	print "\t$f fixed.\n";
}

print "complete\n";
