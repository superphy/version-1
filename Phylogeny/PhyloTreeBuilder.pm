#!/usr/bin/perl
package Phylogeny::PhyloTreeBuilder;

#Builds a given tree from a Newick out put file.

use strict;
use warnings;
use FindBin;
use lib "FindBin::Bin/../";

#These will now be specifid when creating a new instance of this object
#my $treefile = 'NewickTrees/example_tree';
#my $outtree  = 'NewickTrees/tree';

#Constructor
sub new {
	my ($class) = shift;
	my $self = {};
	bless( $self, $class );
	$self->_initialize(@_);
	return $self;
}

sub treefile {
	my $self = shift;
	$self->{'_treefile'} = shift // return $self->{'_treefile'};
}

sub outtree {
	my $self =shift;
	$self->{'_outtree'} = shift // return $self->{'_outtree'};
}

sub _initialize {
	my $self = shift;
	my %params =  @_;
	$self->treefile($params{'treefile'}) // die "treefile has not been initialized";
	$self->outtree($params{'outtree'}) // die "outtree has not been initialized";
}

#Methods

#Makes a system call to create the tree and output is as an SVG file.
sub createTree {
	my $self = shift;
	#Specify -s for an SVG tree and also an output name.
	my $systemargs = 'nw_display' . ' -s ' . $self->{treefile} . ' > ' . $self->{outtree};
	system($systemargs) == 0 or die "system $systemargs failed: $?";
	printf "System executed $systemargs with value: %d\n", $? >> 8;
}

#Destroys a tree.SVG file when the user no longer requires it
sub destroyTree {
	my $self = shift;
	unlink $self->{outtree};
}

1;
