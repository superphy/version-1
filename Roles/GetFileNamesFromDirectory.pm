#!/usr/bin/perl

package Roles::GetFileNamesFromDirectory;

use strict;
use warnings;
use FindBin;
use lib "FindBin::Bin/../";
use Role::Tiny;

=head2 _getFileNamesFromDirectory

Opens the specified directory, excludes all filenames beginning with '.' and
returns the rest as an array ref.

=cut

sub _getFileNamesFromDirectory{
    my $self=shift;
    my $directory = shift;

    opendir( DIRECTORY, $directory ) or die "cannot open directory $directory $!\n";
    my @dir = readdir DIRECTORY;
    closedir DIRECTORY;

    my @fileNames;
    foreach my $fileName(@dir){
        next if substr( $fileName, 0, 1 ) eq '.';
        push @fileNames, ( $directory . $fileName );
    }
    return \@fileNames;
}