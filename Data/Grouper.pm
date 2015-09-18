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
use Data::Dumper qw/Dumper/;
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

    $self->logger->info("Logger initialized in Modules::GenomeWarden");  

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

	$self->{'_modifiable_meta'} = {
		serotype            => 'Serotype',
		isolation_host      => 'Host',
		isolation_source    => 'Source',
		syndrome            => 'Disease / Symptom',
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

=head2 modifiable_meta

Indicates if meta-data key is one that
can be altered by user

Returns boolean if key provided,
otherwise returns array of all modifiable
metadata terms.

=cut

sub modifiable_meta {
	my $self = shift;
	my $key = shift;

	if($key) {
		$self->{'_modifiable_meta'}->{$key};
	}
	else {
		return (keys %{$self->{'_modifiable_meta'}});
	}
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

=head2 initializeStandardGroups

Populate genome_groups table with 
standard groups that all users have
access to.

=cut

sub initializeStandardGroups {
	my $self = shift;
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

	my $meta_data = $self->_get_featureprops();
	my $genomes = $self->_get_genomes();

	#get_logger->debug(Dumper($meta_data));

	
	# Iterate through meta-data identifying cases where genome is missing data
	my %groups;
	my @group_hierarchy;
	foreach my $d (keys %$meta_data) {

		get_logger->debug("$d");
		
		my %missing;
		map { $missing{$_} = 1 } keys($genomes);

		foreach my $v ( keys %{$meta_data->{$d}} ) {
			my @genome_list = @{$meta_data->{$d}{$v}};

			foreach my $g (@genome_list) {
				$missing{$g->[0]} = 0
			}
		}

		my $value = $d.'_na';
		$groups{$d}{$value} = [];

		foreach my $g (keys %missing) {
			push @{$groups{$d}{$value}}, [$g, undef] if $missing{$g};
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

		} else {
			get_logger->debug("Unrecognized serotype format $n.");
			return "Serotype undefined";
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
	my $group_category_id = $self->insertGroupCategory($root_category_name);
	my $other_group_id;

	foreach my $gn (keys %{$groups->{$key}}) {

		if(scalar(@{$groups->{$key}{$gn}}) > 1 || $gn =~ m/_na$/ ) {
			# Groups with 2 or more, or 'Undefined' groups

			my $value = $gn;
			$gn = $name_coderef->($gn);
			
			my $group_id = $self->insertGroup($gn, $value, $group_category_id);
			$group_list{$gn} = [$group_id, $gn];

			# Link all genomes to group
			foreach my $g_arrayref (@{$groups->{$key}{$value}}) {
				my ($g, $fp) = @$g_arrayref;
				$self->insertGenomeGroup($g, $group_id, $fp);
			}

		} else {
			# Other
			# Includes all groups with only one genome

			unless($other_group_id) {
				my $gn = "$root_category_name Other";
				my $value = "$key\_other";
				
				$other_group_id = $self->insertGroup($gn, $value, $group_category_id);
				$group_list{$gn} = [$other_group_id, $gn];
			}

			# Link all genomes to group
			foreach my $g_arrayref (@{$groups->{$key}{$gn}}) {
				my ($g, $fp) = @$g_arrayref;
				$self->insertGenomeGroup($g, $other_group_id, $fp);
			}
		}
	}

	# Build JSON representation of group organization
	my $root = $build_coderef->($root_category_name, [values %group_list]);
	
	return $root;
}



=head2 insertGroupCategory

Insert group category if not found. Return group
category ID.

=cut

sub insertGroupCategory {
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

=head2 insertGroup

Insert group if not found. Return group ID

=cut

sub insertGroup {
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

=head2 insertGenomeGroup

Insert genome-group linkage if not found.

=cut

sub insertGenomeGroup {
	my $self = shift;
	my $genome = shift; # public genome feature ID
	my $g_id = shift; # Group ID
	my $fp_id = shift; # featureprop ID


	my $row = $self->schema->resultset('FeatureGroup')->find_or_new(
		{
			feature_id => $genome,
			genome_group_id => $g_id,
			featureprop_id => $fp_id
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


=head2 _get_featureprops

Retrieve all featureprops in public database
used to initialize standard user groups

=cut
sub _get_featureprops {
	my $self = shift;

	# Obtain featureprops directly linked to genome
	my @fps = (grep {!/subtype/} keys %{$self->meta_data});

	my $fp_rs = $self->schema->resultset('Featureprop')->search(
		{
			'type.name' => \@fps
		},
		{
			columns => [qw/featureprop_id feature_id rank value/],
			'+columns' => [qw/type.name/],
			join => [qw/type/]
		}
	);

	my %meta_data;
	while(my $fp_row = $fp_rs->next) {
		$meta_data{$fp_row->type->name}{$fp_row->value} = [] unless defined $meta_data{$fp_row->type->name}{$fp_row->value};
		push @{$meta_data{$fp_row->type->name}{$fp_row->value}}, [$fp_row->feature_id, $fp_row->featureprop_id];
	}

	# Obtain featureprops indirectly linked to genome through subfeatures
	my @subtype_fps = (grep {/subtype/} keys %{$self->meta_data});
	
	my $st_rs = $self->schema->resultset('Featureprop')->search(
		{
			'type_3.name'      => 'part_of',
			'type_2.name'      => 'allele_fusion',
			'type.name'        => { '-in' => [ @subtype_fps ] },
		},
		{
			join => ['type', { 'feature' => [ 'type', { 'feature_relationship_subjects' => 'type' } ] } ],
			columns => [qw/featureprop_id rank value/],
			'+select' => [qw/type.name feature_relationship_subjects.object_id/],
			'+as' => ['meta_type_name', 'genome_feature_id']
		}
	);

	while(my $st_row = $st_rs->next) {
		$meta_data{$st_row->get_column('meta_type_name')}{$st_row->value} = [] unless defined $meta_data{$st_row->get_column('meta_type_name')}{$st_row->value};
		push @{$meta_data{$st_row->get_column('meta_type_name')}{$st_row->value}}, [$st_row->get_column('genome_feature_id'), $st_row->featureprop_id];
	}

	return \%meta_data;
}


=head2 _get_genomes

Retrieve all genomes in public database
used to initialize standard user groups

=cut
sub _get_genomes {
	my $self = shift;

	my $f_rs = $self->schema->resultset('Feature')->search(
		{
			'type_id' => $self->cvmemory->{'contig_collection'}
		},
		{
			columns => [qw/feature_id/],
		}
	);

	my %genomes;
	while(my $f_row = $f_rs->next) {
		$genomes{$f_row->feature_id} = 1;
	}

	return \%genomes;
}


=head2 update_group_hierarchy

Update std-grp JSON object with current
groups in DB (needed when standard group set changes)

=cut

sub update_group_hierarchy {
	my $self = shift;

	# Get list of groups in DB
	my $groups = $self->group_assignments;

	# Build hierarchy
	my @group_hierarchy;

	# Host groups
	my $term = 'isolation_host';
	my $root_category_name = $self->meta_data($term);
	my @host_groups;
	map { push @host_groups, [ $groups->{$term}{$_}, $_] } keys %{$groups->{$term}{$_}};
	my $host_root = _twoLevelHierarchy($root_category_name, \@host_groups);
	push @group_hierarchy, $host_root;

	# Source groups
	$term = 'isolation_source';
	$root_category_name = $self->meta_data($term);
	my @source_groups;
	map { push @source_groups, [ $groups->{$term}{$_}, $_] } keys %{$groups->{$term}{$_}};
	my $source_root = _twoLevelHierarchy($root_category_name, \@source_groups);
	push @group_hierarchy, $source_root;

	# Source groups
	$term = 'syndrome';
	$root_category_name = $self->meta_data($term);
	my @syndrome_groups;
	map { push @source_groups, [ $groups->{$term}{$_}, $_] } keys %{$groups->{$term}{$_}};
	my $syndrome_root = _twoLevelHierarchy($root_category_name, \@syndrome_groups);
	push @group_hierarchy, $syndrome_root;

	# Serotype groups
	$term = 'serotype';
	$root_category_name = $self->meta_data($term);
	my @serotype_groups;
	map { push @serotype_groups, [ $groups->{$term}{$_}, $_] } keys %{$groups->{$term}{$_}};
	my $serotype_root = _seroHierarchy($root_category_name, \@serotype_groups);
	push @group_hierarchy, $serotype_root;

	# Stx1 groups
	$term = 'stx1_subtype';
	$root_category_name = $self->meta_data($term);
	my @stx1_subtype_groups;
	map { push @stx1_subtype_groups, [ $groups->{$term}{$_}, $_] } keys %{$groups->{$term}{$_}};
	my $stx1_subtype_root = _twoLevelHierarchy($root_category_name, \@stx1_subtype_groups);
	push @group_hierarchy, $stx1_subtype_root;

	# Stx2 groups
	$term = 'stx2_subtype';
	$root_category_name = $self->meta_data($term);
	my @stx2_subtype_groups;
	map { push @stx2_subtype_groups, [ $groups->{$term}{$_}, $_] } keys %{$groups->{$term}{$_}};
	my $stx2_subtype_root = _twoLevelHierarchy($root_category_name, \@stx2_subtype_groups);
	push @group_hierarchy, $stx2_subtype_root;

	
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

}

=head2 match

Given hash-ref of meta-data term and value arrays
identify genome_group_ids that match values.

Returns hash-ref of term/value sets with group ID for
each standard group meta-data type (NOTE: this method
will return 'unassigned' genome_group_id's for undef values).

=cut

sub match {
	my $self = shift;
	my $property_hashref = shift;

	my $group_assignments = $self->group_assignments;
	my %genome_groups;

	foreach my $meta_term (keys %$property_hashref) {

		if($self->meta_data($meta_term)) {
			# Meta-data term used in standard group memberships

			if($property_hashref->{$meta_term}) {
				# Meta-data value provided
				
				foreach my $meta_value (@{$property_hashref->{$meta_term}}) {
					unless($meta_value) {
						# Empty meta value
						my $missing_group_value = "$meta_term\_na";
						my $group_id = $group_assignments->{$meta_term}{$missing_group_value};
						croak "Error: no 'NA' group for data type $meta_term." unless $group_id;

						$genome_groups{$meta_term}{$missing_group_value} = $group_id;
					}
					else {
						# Defined meta value
						if($group_assignments->{$meta_term}{$meta_value}) {
							# Found group assignment for meta-data term
							$genome_groups{$meta_term}{$meta_value} = $group_assignments->{$meta_term}{$meta_value};
						}
						else {
							# No group matching value, place in 'other'
							my $other_group_value = "$meta_term\_other";
							my $group_id = $group_assignments->{$meta_term}{$other_group_value};
							croak "Error: no 'Other' group for value $meta_value in data type $other_group_value." unless $group_id;

							$genome_groups{$meta_term}{$meta_value} = $group_id;
						}
					}
				}
			}
			else {
				# Empty value
				# Return 'unassigned' for this standard group meta-data type
				my $missing_group_value = "$meta_term\_na";
				my $group_id = $group_assignments->{$meta_term}{$missing_group_value};
				croak "Error: no 'NA' group for data type $meta_term." unless $group_id;

				$genome_groups{$meta_term}{$missing_group_value} = $group_id;

			}
		}
	}


	return \%genome_groups;
}

=head2 retrieve

Identify feature_group_id and genome_group_id membership entries for a given genome
and metadata type.  

=cut

sub retrieve {
	my $self = shift;
	my $feature_id = shift;
	my $is_public = shift;
	my $meta_term = shift;

	my $table = 'PrivateFeatureGroup';
	my $category_name = $self->meta_data($meta_term);

	return () unless $category_name;

	my $group_rs = $self->schema->resultset($table)->search(
		{
			'-bool' => 'genome_group.standard',
			'category.name' => $category_name,
			'me.feature_id' => $feature_id
		},
		{
			join => {'genome_group' => 'category'}
		}
	);

	my @rows;
	while(my $group_row = $group_rs->next) {
		push @rows, [$group_row->feature_group_id, $group_row->genome_group_id];
	}

	return @rows;
}



1;