#!/usr/bin/env perl

=pod

=head1 NAME

  Phylogeny::TreeBuilder

=head1 DESCRIPTION

  This class is a wrapper around FastTree. Given a 
  multiple sequence alignment, it produces a newick format tree.

=head1 AUTHOR

  Matt Whiteside (mawhites@phac-aspc.gov.ca)

=cut

package Phylogeny::TreeBuilder;
use base qw(Class::Accessor);

use strict;
use warnings;
use Carp qw/croak carp/;

# Get/set methods
Phylogeny::TreeBuilder->mk_accessors(qw/ft_exe ft_opt cc_exe cc_opt ft_fast_opt ft_me_opt ft_mllen_opt/);


=head2 new

Constructor

=cut

sub new {
	my ($class) = shift;
	my %args = @_;
	
	my $self = {};
	bless( $self, $class );
	
	# Fast tree executable
	my $ftexe = $args{fasttree_exe};
	croak "Error: argument fasttree_exe \'$ftexe\' invalid." unless $ftexe && -x $ftexe;
	$self->ft_exe($ftexe);

	# Thread setting
	my $num_threads = 10;
	$num_threads = $args{num_threads} if $args{num_threads};
	$ENV{OMP_NUM_THREADS} = $num_threads;
	
	# Fast tree command
	my $ftopt = $args{fasttree_opt} // '-gtr -nt';
	$self->ft_opt($ftopt);

	# Fast fast tree command
	my $ftopt2 = $args{fasttree_fast_opt} // '-gtr -nt -nosupport -fastest -mlnni 4';
	$self->ft_fast_opt($ftopt2);

	# Fast fast tree ME command
	my $ftopt3 = $args{fasttree_me_opt} // '-gtr -nt -nosupport -fastest -noml';
	$self->ft_me_opt($ftopt3);

	# Fast fast tree ME with ML lengths command
	my $ftopt4 = $args{fasttree_me_opt} // '-gtr -nt -nosupport -fastest -mllen';
	$self->ft_mllen_opt($ftopt4);
	
	# Clearcut executable
	my $ccexe = $args{clearcut_exe} // 'clearcut';
	$self->cc_exe($ccexe);
	
	# Fast tree command
	my $ccopt = $args{clearcut_opt} // '--alignment --DNA';
	$self->cc_opt($ccopt);
	
	return $self;
}


=head2 build_tree

Args:
1. file name containg nt MSA in FASTA format
2. file name for newick tree output
3. Fasttree version (fast|me|mllen)

=cut

sub build_tree {
	my ($self, $msa_file, $tree_file, $ver) = @_;
	
	my $cmd = join(' ', $self->ft_exe, $self->ft_opt, $msa_file, '>', $tree_file);
	if($ver) {
		if($ver eq 'fast') {
			$cmd = join(' ', $self->ft_exe, $self->ft_fast_opt, $msa_file, '>', $tree_file);
		}
		elsif($ver eq 'me') {
			$cmd = join(' ', $self->ft_exe, $self->ft_me_opt, $msa_file, '>', $tree_file);
		}
		elsif($ver eq 'mllen') {
			$cmd = join(' ', $self->ft_exe, $self->ft_mllen_opt, $msa_file, '>', $tree_file);
		}
		else {
			croak "Error: unknown build_tree option: $ver";
		}
	}
	
	# Run fasttree
	unless(system($cmd) == 0) {
		die "FastTree error ($!).\n";
		return 0;
	}
	
	return(1);
}

=head2 build_njtree

Args:
1. file name containg nt MSA in FASTA format
2. file name for newick tree output

=cut

sub build_njtree {
	my ($self, $msa_file, $tree_file) = @_;
	
	my $cmd = join(' ', $self->cc_exe, $self->cc_opt, '--in='.$msa_file, '--out='.$tree_file);
	
	unless(system($cmd) == 0) {
		die "clearcut error ($!).\n";
		return 0;
	}
	
	return(1);
}





1;
