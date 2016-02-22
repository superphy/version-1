#!/usr/bin/env perl

=pod

=head1 NAME

Data::Grouper

=head1 DESCRIPTION

Setup the standard genome groups that are available to all users. Standard groups are fairly static, changing
infrequently. Group structure is stored as JSON hash with formatting instructions for front-end libraries.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.ca)

=cut

$| = 1;

package Data::Grouper;

use strict;
use warnings;
use Carp;
use FindBin;
use lib "$FindBin::Bin/../";
use Log::Log4perl qw/get_logger/;
use Data::Dump qw/dump/;
use JSON qw/encode_json/;

## GLOBALS
my $ADMINUSER;

=head2 constructor

=cut

sub new {
	my $class = shift;
	my $self = {};
	bless( $self, $class );
	
	
	# Initialize
	$self->_initialize(@_);
	
	return $self;
}

=head2 _initialize

=cut

sub _initialize {
	my $self = shift;

    # Setup logging
    $self->logger(Log::Log4perl->get_logger()); 
    $self->logger->info("Logger initialized in Data::Grouper");  

    my %params = @_;

    # Set all parameters
    $self->schema($params{schema});
    croak "Error: 'schema' is a required parameter" unless $self->schema;
    $self->cvmemory($params{cvmemory});
    croak "Error: 'cvmemory' is a required parameter" unless $self->cvmemory;

    # Meta-data type names mapped to 'human-readable' category names for public
    # consumption
    $self->{'_meta_data'} = {
		serotype            => 'Serotype',
		isolation_host      => 'Host',
		isolation_source    => 'Source',
		syndrome            => 'Disease / Symptom',
		stx1_subtype        => 'Stx1 Subtype',
		stx2_subtype        => 'Stx2 Subtype',
	};
    
}

=head2 meta_data

Meta-data types mapped to public titles used
for group categories.

No input returns entire hash-ref.
If input key provided, returns public title
for meta data category.

=cut

sub meta_data {
	my $self = shift;
	my $key = shift;

	if($key) {
		$self->{'_meta_data'}->{$key};
	}
	else {
		return $self->{'_meta_data'};
	}
	
}

=head2 meta_keys

Meta-data types used to assign groups.

Returns array-ref of strings.

=cut

sub meta_keys {
	my $self = shift;
	
	return keys %{$self->{'_meta_data'}};
}

=head2 logger

Stores a logger object for the module.

=cut

sub logger {
	my $self = shift;
	$self->{'_logger'} = shift // return $self->{'_logger'};
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



########################
## Group Support Methods
########################

=head2 updateStandardGroups

Populate genome_groups table with 
standard groups that all users have
access to.

Performs an 'update or create' for
new and existing genomes in
groups

=cut

sub updateStandardGroups {
	my $self = shift;
	my $fdg = shift; # Object-ref to FormDataGenerator
	my $admin_user = shift;
	
	# Perform changes in transaction
	my $guard = $self->schema->txn_scope_guard;

	# Validate the admin user existence here,
	# this saves DatabaseConnector from having to do it every time it is
	# initialized.
	my $row = $self->schema->resultset('Login')->find(
		{
			username => $admin_user
		},
		{
			key => 'login_c1'
		}
	);
	croak "Error: System admin user does not exist: $admin_user" unless $row;

	$ADMINUSER = $admin_user;

	# Retrieve public meta-data
	my $meta_data = $fdg->_runGenomeQuery(1);

	# Iterate through meta-data collecting values to use for groups
	my %groups;
	my @group_hierarchy;
	foreach my $g (keys %$meta_data) {
		# Parse genome label
		my ($genome_id) = ($g =~ m/public_(\w+)/);
		croak "Error: format error in genome ID $g." unless $genome_id;

		my $d = $meta_data->{$g};
		foreach my $key (keys %{$self->meta_data}) {
			if(defined($d->{$key})) {
				my $value_arrayref = $d->{$key};
				foreach my $value (@$value_arrayref) {
					$groups{$key}{$value} = [] unless defined $groups{$key}{$value};
					push @{$groups{$key}{$value}}, $genome_id;
					get_logger->debug("$g has value $value for key $key")
				}

			} else {
				# Record NA for each type
				my $value = $key.'_na';
				$groups{$key}{$value} = [] unless defined $groups{$key}{$value};
				push @{$groups{$key}{$value}}, $genome_id;

			}
		}
	}

	# Extract groups with minimum 2 strains
	my $min = 2;
	

	# Host groups
	my $root_category_name = $self->meta_data('isolation_host');
	# Default name changes
	my $name_conversion_coderef = sub { 
		my $n = shift;
		return "Host undefined" if $n =~ m/_na$/;
		return $n
	};
	my $build_coderef = \&_twoLevelHierarchy; # All groups are children of root
	
	my $host_root = $self->_buildCategory(\%groups, $root_category_name, 'isolation_host', $name_conversion_coderef, $build_coderef);
	push @group_hierarchy, $host_root;


	# Source groups
	$root_category_name = $self->meta_data('isolation_source');

	# Alter group names for clarity
	$name_conversion_coderef = sub { 
		my $n = shift;
		if($n eq 'Stool') {
			return 'Stool (human)';
		} elsif($n eq 'Feces') {
			return 'Feces (non-human)';
		} elsif($n eq 'isolation_source_na') {
			return 'Source undefined';
		} else {
			return $n;
		}
	}; 
	$build_coderef = \&_twoLevelHierarchy; # All groups are children of root
	
	my $source_root = $self->_buildCategory(\%groups, $root_category_name, 'isolation_source', $name_conversion_coderef, $build_coderef);
	push @group_hierarchy, $source_root;
	

	# Syndrome groups
	$root_category_name = $self->meta_data('syndrome');
	# Default name changes
	$name_conversion_coderef = sub { 
		my $n = shift;
		return "Syndrome undefined" if $n =~ m/_na$/;
		return $n
	};
	$build_coderef = \&_twoLevelHierarchy; # All groups are children of root
	
	my $syndrome_root = $self->_buildCategory(\%groups, $root_category_name, 'syndrome', $name_conversion_coderef, $build_coderef);
	push @group_hierarchy, $syndrome_root;


	# Serotype
	$root_category_name = $self->meta_data('serotype');
	# Add invalid serotypes to undefined group
	$name_conversion_coderef = sub { 
		my $n = shift;
		if($n =~ m/^O\w+/) {
			return $n;

		} elsif($n =~ m/serotype_na/) {
			return "Serotype undefined";

		} elsif($n =~ m/NA/) {
			return "Serotype unknown";

		} else {
			get_logger->debug("Unrecognized serotype format $n.");
			croak "Unrecognized serotype format $n"
		}
		
	};
	$build_coderef = \&_seroHierarchy; # All groups are children of root
	
	my $serotype_root = $self->_buildCategory(\%groups, $root_category_name, 'serotype', $name_conversion_coderef, $build_coderef);
	push @group_hierarchy, $serotype_root;

	# Stx1 subtype groups
	$root_category_name = $self->meta_data('stx1_subtype');
	# Default name changes
	$name_conversion_coderef = sub { 
		my $n = shift;
		return "Stx1 subtype undefined" if $n =~ m/_na$/;
		return $n
	};
	$build_coderef = \&_twoLevelHierarchy; # All groups are children of root
	
	my $stx1_root = $self->_buildCategory(\%groups, $root_category_name, 'stx1_subtype', $name_conversion_coderef, $build_coderef);
	push @group_hierarchy, $stx1_root;

	# Stx2 subtype groups
	$root_category_name = $self->meta_data('stx2_subtype');;
	# Default name changes
	$name_conversion_coderef = sub { 
		my $n = shift;
		return "Stx2 subtype undefined" if $n =~ m/_na$/;
		return $n
	};
	$build_coderef = \&_twoLevelHierarchy; # All groups are children of root
	
	my $stx2_root = $self->_buildCategory(\%groups, $root_category_name, 'stx2_subtype', $name_conversion_coderef, $build_coderef);
	push @group_hierarchy, $stx2_root;


	# Convert group hierarchy into JSON string
	my $group_json = encode_json(\@group_hierarchy);

	# Save in DB
	$self->schema->resultset('Meta')->update_or_create(
		{
			name => 'stdgrp-org',
			format => 'json',
			data_string => $group_json
		},
		{
			key => 'meta_c1'
		}
	);


	# Commit transaction
	$guard->commit;

}

=head2 _buildCategory

Iterate through meta-data values creating groups,
link groups to genomes and build final group hierarchy.

=cut

sub _buildCategory {
	my $self = shift;
	my $groups = shift; # meta-data groups hash-ref
	my $root_category_name = shift; # Label for top-level category
	my $key = shift; # Meta-data type key
	my $name_coderef = shift; # Code-ref for modifying group names
	my $build_coderef = shift; # Code-ref for creating group category hierarchy
	
	# Serotype groups
	my %group_list;
	my $group_category_id = $self->updateGroupCategory($root_category_name);
	my $other_group_id;

	foreach my $gn (keys %{$groups->{$key}}) {

		if(scalar(@{$groups->{$key}{$gn}}) > 1 || $gn =~ m/_na$/ ) {
			# Groups with 2 or more, or 'Undefined' groups

			my $value = $gn;
			$gn = $name_coderef->($gn);
			
			my $group_id = $self->updateGroup($gn, $value, $group_category_id);
			croak "Error: non-unique genome group name $gn for value $value." if defined $group_list{$gn};
			$group_list{$gn} = [$group_id, $gn];

			# Link all genomes to group
			foreach my $g (@{$groups->{$key}{$value}}) {
				$self->updateGenomeGroup($g, $group_id);
			}

		} else {
			# Other
			# Includes all groups with only one genome

			unless($other_group_id) {
				my $gn = "$root_category_name Other";
				my $value = "$key\_other";
				
				$other_group_id = $self->updateGroup($gn, $value, $group_category_id);
				$group_list{$gn} = [$other_group_id, $gn];
			}

			# Link all genomes to group
			foreach my $g (@{$groups->{$key}{$gn}}) {
				$self->updateGenomeGroup($g, $other_group_id);
			}
		}
	}

	# Build JSON representation of group organization
	my $root = $build_coderef->($root_category_name, [values %group_list]);
	
	return $root;
}



=head2 updateGroupCategory

Insert group category if not found. Return group
category ID.

=cut

sub updateGroupCategory {
	my $self = shift;
	my $gc = shift; # Group category name
	
	my $row = $self->schema->resultset('GroupCategory')->find_or_new(
		{
			username => $ADMINUSER,
			name => $gc
		},
		{
			key => 'group_category_c1'
		}
	);

	unless($row->in_storage) {
		$self->logger->debug("Adding group category $gc.");
		$row = $row->insert; # Recover updated row object with PK filled in
	}

	croak "Error: insert of group_category row failed." unless $row->group_category_id;
	
	return $row->group_category_id;
}

=head2 updateGroup

Insert group if not found. Return group ID

=cut

sub updateGroup {
	my $self = shift;
	my $name = shift; # Group name
	my $value = shift; # Group value (meta-data value that group represents)
	my $gc_id = shift; # Group category ID
	
	my $row = $self->schema->resultset('GenomeGroup')->find_or_new(
		{
			username => $ADMINUSER,
			name => $name,
			standard => 1,
			standard_value => $value,
			category_id => $gc_id
		},
		{
			key => 'genome_group_c1'
		}
	);

	unless($row->in_storage) {
		$self->logger->debug("Adding group $name.");
		$row = $row->insert; # Recover updated row object with PK filled in
	}

	croak "Error: insert of group row failed." unless $row->genome_group_id;
	
	return $row->genome_group_id;
}

=head2 updateGroup

Insert genome-group linkage if not found. PUBLIC GENOME IDS ONLY.

=cut

sub updateGenomeGroup {
	my $self = shift;
	my $genome = shift; # public genome feature ID
	my $g_id = shift; # Group ID
	
	my $row = $self->schema->resultset('FeatureGroup')->find_or_new(
		{
			feature_id => $genome,
			genome_group_id => $g_id,
		},
		{
			key => 'feature_group_c1'
		}
	);

	unless($row->in_storage) {
		$self->logger->debug("Adding genome-group link for $genome & $g_id.");
		$row = $row->insert; # Recover updated row object with PK filled in
	}
}


=head2 _twoLevelHierarchy

Create group hierarchy hash-ref.

All groups are descendents of root

=cut

sub _twoLevelHierarchy {
	my $root_name = shift;
	my $group_list = shift;

	# Root
	my $root = {
		name => $root_name,
		description => 0,
		type => 'collection',
		children => [],
		level => 0
	};

	# Groups;
	foreach my $grp (@$group_list) {
		my $group_href = {
			id => $grp->[0],
			name => $grp->[1],
			description => 0,
			type => 'group'
		};
		push @{$root->{'children'}}, $group_href;
	}

	return $root;
}

=head2 _twoLevelHierarchy

Create group hierarchy hash-ref.

Specific to serotype groups.

=cut
sub _seroHierarchy {
	my $root_name = shift;
	my $group_list = shift; 

	# Root
	my $root = {
		name => $root_name,
		description => 0,
		type => 'collection',
		children => [],
		level => 0
	};

	# Internal collections
	my %o_groups;
	my %h_groups;
	my $seen_undef = 0;
	my $seen_other = 0;
	my $seen_unknown = 0;

	# Groups;
	foreach my $grp (@$group_list) {

		my $n = $grp->[1];

		my $group_href = {
			id => $grp->[0],
			name => $n,
			description => 0,
			type => 'group'
		};

		# Find internal groups
		my $otype = 0;
		my $htype = 0;

		# O antigen
		if($n =~ m/^(O\w+)\:?$/a) {
			# O type only
			$otype = $1;
			$htype = 'H-type undefined';

		} elsif($n =~ m/^(O\w+)\:([\w\-]+)$/a) {
			# O and H type
			$otype = $1;
			$htype = $2;

			if($htype =~ m/^(?:NM|H-|-)$/) {
				$htype = 'Non-motile';
			}

		} elsif($n =~ m/Serotype undefined/) {
			# No types
			croak "Error: multiple 'undefined' groups in group list" if $seen_undef;
			$seen_undef = 1;
			push @{$root->{'children'}}, $group_href;
			next;
			
		} elsif($n =~ m/Serotype Other/) {
			# No types
			croak "Error: multiple 'other' groups in group list" if $seen_other;
			$seen_other = 1;
			push @{$root->{'children'}}, $group_href;
			next;
			
		} 
		elsif($n =~ m/Serotype unknown/) {
			# NA from submitter
			croak "Error: multiple 'unknown' groups in group list" if $seen_unknown;
			$seen_unknown = 1;
			push @{$root->{'children'}}, $group_href;
			next;

		}    	
		else {
			# Something unexpected!
			# Name conversion should have eliminated these cases
			croak "Error: unexpected serotype group name $n.";

		}

		# Add to internal nodes
		if($otype && $htype) {
			# Add to o group
			my $ogrp_node = $o_groups{$otype};
		 
			if($ogrp_node) {
				push @{$ogrp_node->{'children'}}, $group_href;

			} else {
				$o_groups{$otype} = {
					name => $otype,
					description => 0,
					type => 'collection',
					children => [ $group_href ],
					level => 2
				};
			}

			# Add to h group
			my $hgrp_node = $h_groups{$htype};

			if($hgrp_node) {
				push @{$hgrp_node->{'children'}}, $group_href;

			} else {
				$h_groups{$htype} = {
					name => $htype,
					description => 0,
					type => 'collection',
					children => [ $group_href ],
					level => 2
				};
			}

		} else {
			croak "Error: unexpected serotype group name $n. Missing O- or H-type."

		}
	}

	# Add O-level and H-level groups
	my $olevel = {
		name => 'O-Antigen serotypes',
		description => 0,
		type => 'collection',
		children => [ values %o_groups ],
		level => 1
	};
	push @{$root->{'children'}}, $olevel;

	my $hlevel = {
		name => 'H-Antigen serotypes',
		description => 0,
		type => 'collection',
		children => [ values %h_groups ],
		level => 1
	};
	push @{$root->{'children'}}, $hlevel;	

	#get_logger->debug(dump($root));

	return $root;
}

=head2 group_assignments

Return hash-ref of standard group ids
mapped to their standard values

Used in loading pipeline to assign
new genomes to existing groups based
on their meta-data values.

Returns:
  A hash-ref containing:
  	meta_data_type => meta_data_value => group_id

	where meta_data_type is one of:
	  isolation_host,
	  isolation_source,
	  syndrome,
	  serotype,
	  stx1_subtype,
	  stx2_subtype

=cut
sub group_assignments {
	my $self = shift;

	my $group_rs = $self->schema()->resultset('GenomeGroup')->search(
		{
			'-bool' => 'me.standard'
		},
		{
			prefetch => 'category'
		}
	);

	my %group_assignments;
	my %group_labels = reverse %{$self->meta_data}; # Note: group category names are unique

	while(my $group_row = $group_rs->next) {
		my $group_id = $group_row->genome_group_id;
		my $meta_value = $group_row->standard_value;
		my $meta_key = $group_labels{$group_row->category->name};

		croak "Standard group $group_id with unknown category: ".$group_row->category->name."\n" unless $meta_key;
		croak "Standard value $meta_value in $meta_key already has group assigned." if defined $group_assignments{$meta_key}{$meta_value}; 

		$group_assignments{$meta_key}{$meta_value} = $group_id;
	}

	return \%group_assignments;
}


1;
