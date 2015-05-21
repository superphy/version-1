#!/usr/bin/env perl

=pod

=head1 NAME

Modules::GenomeWarden

=head1 DESCRIPTION

Tracks which genomes and groups are viewable by current user. Also performs some common tasks
for genome data and genome groups.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.ca)

=cut

package Modules::GenomeWarden;

use strict;
use warnings;
use Carp;
use FindBin;
use lib "$FindBin::Bin/../";
use Log::Log4perl qw/get_logger/;
use Data::Dump qw/dump/;

=head2 constructor

=cut

sub new {
	my $class = shift;
	my $self = {};
	bless( $self, $class );
	
	# Initialize errors
	$self->{_error} = 0;
	$self->{_publicErrors} = [];
	$self->{_privateErrors} = [];
	
	# Initialize displaynames
	my $private_suffix = ' [P]';
    my $public_suffix = ' [G]';
    $self->{private_suffix} = $private_suffix;
    $self->{public_suffix} = $public_suffix;
	
	# Retrieve genome data
	$self->_initialize(@_);
	
	return $self;
}

=head2 _initialize

=cut

sub _initialize {
	my $self = shift;

    get_logger->info("Initializing Modules::GenomeWarden");  

    my %params = @_;

    # Set all parameters
    $self->schema($params{schema});
    croak "Error: 'schema' is a required parameter" unless $self->schema;
    $self->cvmemory($params{cvmemory});
    croak "Error: 'cvmemory' is a required parameter" unless $self->cvmemory;
    $self->requestingUser($params{user}) if $params{user};
    
    # Has subset been requested?
    if($params{genomes}) {
    	my @genomes = @{$params{genomes}};
    	my @private_ids = map m/private_(\d+)/ ? $1 : (), @genomes;
		my @public_ids = map m/public_(\d+)/ ? $1 : (), @genomes;
		
		croak "Error: one or more invalid 'genomes' parameters." unless ( scalar(@private_ids) + scalar(@public_ids) == scalar(@genomes) );
		
		$self->{_publicFeatures} = \@public_ids;
		$self->{_privateFeatures} = \@private_ids;
		$self->subset(1);
    } else {
    	$self->subset(0);
    }
    
    my $publicLookup = {};
    my $privateLookup = {};
    my $has_private = 0;
    
    # Retrieve data for genomes
    if($self->subset) {
    	$self->_publicGenomes($publicLookup, $self->{_publicFeatures});
    	$has_private = $self->_privateGenomes($self->requestingUser, $privateLookup, $self->{_privateFeatures});
    	
    	my @public_invalid;
    	my @public_ok;
    	foreach my $id (@{$self->{_publicFeatures}}) {
    		my $genome = "public_$id";
    		if(defined($publicLookup->{$genome})) {
    			push @public_ok, $id;
    		} else {
    			push @public_invalid, $id;
    		}
    	}
    	$self->{_publicFeatures} = \@public_ok;
    	
    	my @private_invalid;
    	my @private_ok;
    	foreach my $id (@{$self->{_privateFeatures}}) {
    		my $genome = "private_$id";
    		if(defined($privateLookup->{$genome})) {
    			push @private_ok, $id;
    		} else {
    			push @private_invalid, $id;
    		}
    	}
    	$self->{_privateFeatures} = \@private_ok;
    	
    	# Record possible non-fatal errors
    	$self->error(\@public_invalid, \@private_invalid);
    	
    	# Fatal error
    	croak "No valid genomes requested." unless @public_ok || @private_ok;
    	
    } else {
    	
    	$self->_publicGenomes($publicLookup);
    	$has_private = $self->_privateGenomes($self->requestingUser, $privateLookup);
    	
    	my @tmp1 = keys %$publicLookup;
    	$self->{_publicFeatures} = \@tmp1;
    	
    	my @tmp2 = keys %$privateLookup;
    	$self->{_privateFeatures} = \@tmp2;
    	
    }
    
    $self->{_publicGenomeLookup} = $publicLookup;
    $self->{_privateGenomeLookup} = $privateLookup;
    $self->{_hasPrivate} = $has_private;
     
}


=head2 requestingUser

User making request

=cut

sub requestingUser {
	my $self = shift;
	$self->{'_user'} = shift // return $self->{'_user'};
}

=head2 schema

DBIx::Class schema pointer

=cut

sub schema {
	my $self = shift;
	$self->{'_schema'} = shift // return $self->{'_schema'};
}

=head2 cvmemory

cvterm hashref

=cut

sub cvmemory {
	my $self = shift;
	$self->{'_cvmemory'} = shift // return $self->{'_cvmemory'};
}

=head2 subset

Returns boolean indicating if working with subset

=cut

sub subset {
	my $self = shift;
	$self->{'_subset'} = shift // return $self->{'_subset'};
}

=head2 error

Records invalid / inaccessible genomes requested by user

=cut

sub error {
	my $self = shift;
	
	if(@_) {
		my $pub_ref = shift;
		my $pri_ref = shift;
		if(@$pub_ref) {
			$self->{_error} = 1;
			$self->{_publicErrors} = $pub_ref;
		}
		if(@$pri_ref) {
			$self->{_error} = 1;
			$self->{_privateErrors} = $pri_ref;
		}
	}
	
	return($self->{_error}, $self->{_publicErrors}, $self->{_privateErrors});
}


=head2 featureList

Returns two-element array containing:
  [0] = array-ref of public feature IDs
  [1] = array-ref of private feature IDs viewable by user

=cut

sub featureList {
	my $self = shift;
	
	if(@_) {
		my $which = shift;
		
		if($which eq 'public') {
			return $self->{_publicFeatures}
		} elsif($which eq 'private') {
			return $self->{_privateFeatures};
		}
	}
	
	return($self->{_publicFeatures}, $self->{_privateFeatures});
}

=head2 numPublic

Number of public genomes in current genome set

=cut

sub numPublic {
	my $self = shift;
	
	return scalar(@{$self->{_publicFeatures}});
}

=head2 numPrivate

Number of private genomes in current genome set

=cut

sub numPrivate {
	my $self = shift;
	
	return scalar(@{$self->{_privateFeatures}});
}

=head2 hasPersonal

Boolean indicating if user has private genomes that are not
publicly viewable.

=cut

sub hasPersonal {
	my $self = shift;
	
	return $self->{_hasPrivate};
}



=head2 genomeLookup

Returns hash-ref using genome labels as keys (e.g. public_123456). 
  
Each genome hash contains:
  feature_id => int
  displayname => string
  uniquename => string
  access => string (private only)

=cut

sub genomeLookup {
	my $self = shift;
	
	if(@_) {
		my $which = shift;
		
		if($which eq 'public') {
			return $self->{_publicGenomeLookup}
		} elsif($which eq 'private') {
			return $self->{_privateGenomeLookup};
		}
	}
	
	my %tmp = (%{$self->{_publicGenomeLookup}}, %{$self->{_privateGenomeLookup}});
	return(\%tmp);
}

=head2 genomeList

Returns array-ref of genome labels (e.g. public_123456). 

=cut

sub genomeList {
	my $self = shift;
	
	my $tmp = $self->genomeLookup(@_);
	
	return([keys %$tmp]);
}


=head2 _publicGenomes

SQL Queries

=cut

sub _publicGenomes {
	my $self = shift;
	my $visable_nodes = shift;
	my $subset_ids = shift;
	
	my $select_stmt = {
		'type_id' =>  $self->cvmemory->{'contig_collection'}
	};
	if($subset_ids) {
		croak unless ref($subset_ids) eq 'ARRAY';
		return unless @$subset_ids;
		$select_stmt->{feature_id} = { '-in' => $subset_ids };
	}
	
	my $genomes = $self->schema->resultset('Feature')->search(
		$select_stmt,
		{
			result_class => 'DBIx::Class::ResultClass::HashRefInflator',
			columns => [qw/feature_id uniquename name dbxref.accession/],
			join => ['dbxref'],
			order_by    => {-asc => ['me.uniquename']}
	    }
	);
	
	while (my $row_hash = $genomes->next) {
		my $display_name = $row_hash->{uniquename};
		my $fid = $row_hash->{feature_id};
		
		my $key = "public_$fid";
		$visable_nodes->{$key} = {
			feature_id => $fid,
			displayname => $display_name,
			uniquename => $display_name,
			access => 0
		};
		
	}
}

=head2 _privateGenomes

SQL Queries

=cut

sub _privateGenomes {
    my $self = shift;
    my $username = shift;
    my $visable_nodes = shift;
    my $subset_ids = shift;
    
    if($username) {
        # user is logged in
        
        # Return private genome names as list of hash-refs
        # Need to check view permissions for user
        
		my $select_stmt = [
			{
	             'login.username' => $username,
	             'type_id' =>  $self->cvmemory->{'contig_collection'}
			},
			{
				'upload.category' => 'public',
				'type_id' =>  $self->cvmemory->{'contig_collection'}
			},
		];
		
		if($subset_ids) {
			croak unless ref($subset_ids) eq 'ARRAY';
			return unless @$subset_ids;
			$select_stmt = [
				{
		             'login.username' => $username,
		             'type_id' =>  $self->cvmemory->{'contig_collection'},
		             'feature_id'     => { '-in' => $subset_ids }
				},
				{
					'upload.category' => 'public',
					'type_id' =>  $self->cvmemory->{'contig_collection'},
					'feature_id'     => { '-in' => $subset_ids }
				},
			];
		}
		
        my $genomes = $self->schema->resultset('PrivateFeature')->search(
			$select_stmt,
			{
				result_class => 'DBIx::Class::ResultClass::HashRefInflator',
				columns => [qw/feature_id uniquename/],
				'+columns' => [qw/upload.category login.username/],
				join => [
					{ 'upload' => { 'permissions' => 'login'} }
				]

			}
		);
        
        my $has_private = 0;

		while (my $row_hash = $genomes->next) {
        #foreach my $row_hash (@privateFormData) {
			my $display_name = $row_hash->{uniquename};
			my $fid = $row_hash->{feature_id};
			my $acc = $row_hash->{upload}->{category};
			
			if($acc eq 'public') {
			   $display_name .= $self->{public_suffix};
			} else {
			     $display_name .= $self->{private_suffix};
			     $has_private = 1;
			}
			
			my $key = "private_$fid";
			$visable_nodes->{$key} = {
				feature_id => $fid,
				displayname => $display_name,
				uniquename => $row_hash->{uniquename},
				access => $acc
			};
			
        }

        return ($has_private);

	} else {
		# Return user-uploaded public genome names as list of hash-refs
		my $select_stmt = {
			'upload.category' => 'public',
			'type_id' =>  $self->cvmemory->{'contig_collection'}
		};
		
		if($subset_ids) {
			croak unless ref($subset_ids) eq 'ARRAY';
			$select_stmt->{feature_id} = { '-in' => $subset_ids };
		}
		
		my $genomes = $self->schema->resultset('PrivateFeature')->search(
			$select_stmt,
			{
	            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	            columns => [qw/feature_id uniquename/],
	            join => [
					{ 'upload' => 'permissions' },
				]
	
	        }
        );
        
        my $has_private = 0;

		while (my $row_hash = $genomes->next) {
			my $display_name = $row_hash->{uniquename} . $self->{public_suffix};
			my $fid = $row_hash->{feature_id};
			my $acc = 'public';
			
			my $key = "private_$fid";
			$visable_nodes->{$key} = {
				feature_id => $fid,
				displayname => $display_name,
				uniquename => $row_hash->{uniquename},
				access => $acc
			};
			
        }
        
		return($has_private);
	}
}


1;