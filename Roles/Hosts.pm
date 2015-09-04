#!/usr/bin/env perl

=pod

=head1 NAME

Roles::Hosts

=head1 DESCRIPTION

Model layer for hosts and associated sources/syndromes

Provides easy access to host / source / syndrome terms & IDs

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.ca)

=cut

package Roles::Hosts;

use strict;
use warnings;
use Role::Tiny;
use Carp;
use FindBin;
use Data::Dumper;


=head2 categoryList

Return array-ref of host categories

=cut

sub categoryList {
	my $self = shift;
	
	unless($self->{__HOSTCATEGORYLIST__}) {
		my $hosts_rs = $self->dbixSchema->resultset('HostCategory')->search(
			{},
			{
				columns => ['uniquename','displayname'],
			}
		);
		my %hosts;
		while(my $host_row = $hosts_rs->next) {
			$hosts{$host_row->uniquename} = $host_row->displayname;
		}
		
		$self->{__HOSTCATEGORYLIST__} = [keys %hosts];
	}
	
	return $self->{__HOSTCATEGORYLIST__}
}


=head2 hostCategories

Return hash-ref of host => category mappings

=cut

sub hostCategories {
	my $self = shift;
	
	unless($self->{__HOSTCATEGORIES__}) {
		my $hosts_rs = $self->dbixSchema->resultset('Host')->search(
			{},
			{
				columns => ['uniquename'],
				prefetch => ['host_category']
			}
		);
		my %hosts;
		while(my $host_row = $hosts_rs->next) {
			$hosts{$host_row->uniquename} = $host_row->host_category->uniquename;
		}
		
		$self->{__HOSTCATEGORIES__} = \%hosts;
	}
	
	return $self->{__HOSTCATEGORIES__};
}


=head2 hostList

Return hash-ref of host uniquename => full names

=cut

sub hostList {
	my $self = shift;
	
	unless($self->{__HOSTLIST__}) {
		my $hosts_rs = $self->dbixSchema->resultset('Host')->search(
			{},
			{
				columns => ['uniquename', 'displayname']
			}
		);
		my %hosts;
		while(my $host_row = $hosts_rs->next) {
			$hosts{$host_row->uniquename} = $host_row->displayname;
		}
		
		$self->{__HOSTLIST__} = \%hosts;
	}
	
	return $self->{__HOSTLIST__};
}


=head2 sourceList

Return three-level hash-ref of available sources for each category:
	category => source uniquename => source full name

=cut

sub sourceList {
	my $self = shift;
	
	unless($self->{__SOURCELIST__}) {
		my $sources_rs = $self->dbixSchema->resultset('Source')->search(
			{},
			{
				columns => ['uniquename', 'displayname'],
				prefetch => ['host_category']
			}
		);
		my %sources;
		while(my $source_row = $sources_rs->next) {
			$sources{$source_row->host_category->uniquename}{$source_row->uniquename} = $source_row->displayname;
		}
		
		$self->{__SOURCELIST__} = \%sources;
	}
	
	return $self->{__SOURCELIST__};
}


=head2 sourceList

Return three-level hash-ref of available syndromes for each category:
	category => source uniquename => source full name

=cut

sub syndromeList {
	my $self = shift;
	
	unless($self->{__SYNDROMELIST__}) {
		my $sources_rs = $self->dbixSchema->resultset('Syndrome')->search(
			{},
			{
				columns => ['uniquename', 'displayname'],
				prefetch => ['host_category']
			}
		);
		my %synds;
		while(my $source_row = $sources_rs->next) {
			$synds{$source_row->host_category->uniquename}{$source_row->uniquename} = $source_row->displayname;
		}
		
		$self->{__SYNDROMELIST__} = \%synds;
	}
	
	return $self->{__SYNDROMELIST__};
}


=head2 sourceList

Return host uniquename for given full name

=cut

sub hostUniquename {
	my $self = shift;
	my $displayname = shift;
	
	my $row = $self->dbixSchema->resultset('Host')->find(
		{
			displayname => $displayname
		}
	);
	
	if($row) {
		return $row->uniquename
	} else {
		return undef;
	}
	
}


=head2 sourceUniquename

Return source uniquename for given full name

=cut

sub sourceUniquename {
	my $self = shift;
	my $category = shift;
	my $displayname = shift;
	
	my $row = $self->dbixSchema->resultset('Source')->find(
		{
			displayname => $displayname,
			'host_category.uniquename' => $category
		},
		{
			join => [qw/host_category/]
		}
	);
	
	if($row) {
		return $row->uniquename
	} else {
		return undef;
	}
	
}


=head2 syndromeUniquename

Return syndrome uniquename for given full name

=cut

sub syndromeUniquename {
	my $self = shift;
	my $category = shift;
	my $displayname = shift;
	
	my $row = $self->dbixSchema->resultset('Syndrome')->find(
		{
			displayname => $displayname,
			'host_category.uniquename' => $category
		},
		{
			join => [qw/host_category/]
		}
	);
	
	if($row) {
		return $row->uniquename
	} else {
		return undef;
	}
	
}

=head2 subtypeList

=cut

sub subtypeList {
	my $self = shift;

	
}

=head2 metaTerms

Return full hash of values for each meta-data type

=cut

sub metaTerms {
	my $self = shift;

	my %termHash;

	$termHash{host} = $self->hostList;
	$termHash{source} = $self->sourceList;
	$termHash{syndrome} = $self->syndromeList;

	return \%termHash;
}




1;