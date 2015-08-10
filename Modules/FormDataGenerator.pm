#!/usr/bin/env perl

=pod

=head1 NAME

Modules::FormDataGenerator

=head1 DESCRIPTION

=head1 ACKNOWLEDGMENTS

Thank you to Dr. Chad Laing and Dr. Matt Whiteside, for all their assistance on this project

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AVAILABILITY

The most recent version of the code may be found at:

=head1 AUTHOR

Akiff Manji (akiff.manji@gmail.com)

=head1 Methods

=cut

package Modules::FormDataGenerator;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Log::Log4perl qw/get_logger :easy/;
use Carp;
use Time::HiRes qw( time );
use JSON;

#One time use
use IO::File;
use IO::Dir;
umask 0000;

my $private_suffix = ' [P]';
my $public_suffix = ' [G]';

#object creation
sub new {
	my ($class) = shift;
	my $self = {};
	bless( $self, $class );
	$self->_initialize(@_);

	my %fp_types = (
		serotype            => 1,
		strain              => 1,
		isolation_host      => 1,
		isolation_source    => 1,
		isolation_location  => 1,
		#isolation_latlng    => 1,
		isolation_date      => 1,
		syndrome            => 1,
	);

	$self->{meta_terms} = \%fp_types;

	my %st_types = (
		stx1_subtype        => 1,
		stx2_subtype        => 1,
	);

	$self->{subtypes} = \%st_types;

    $self->{now} = time();
    
	return $self;
}

=head2 _initialize

Initializes the logger.
Assigns all values to class variables.
Anything else that the _initialize function does.

=cut

sub _initialize {
	my($self)=shift;

    #logging
    $self->logger(Log::Log4perl->get_logger()); 

    $self->logger->info("Logger initialized in Modules::FormDataGenerator");  

    my %params = @_;

    #on object construction set all parameters
    foreach my $key(keys %params){
    	if($self->can($key)){
    		$self->$key($params{$key});
    	}
    	else{
            #logconfess calls the confess of Carp package, as well as logging to Log4perl
            $self->logger->logconfess("$key is not a valid parameter in Modules::FormDataGenerator");
        }
    }
    
}

=head2 dbixSchema

A pointer to the dbix::class::schema object used in Application

=cut
sub dbixSchema {
	my $self = shift;
	
	$self->{_dbixSchema} = shift // return $self->{_dbixSchema};
}

=head2 cvmemory

A pointer to the hashref of cvterm IDs

=cut
sub cvmemory {
	my $self = shift;
	
	$self->{_cvmemory} = shift // return $self->{_cvmemory};
}

=head2 logger

Stores a logger object for the module.

=cut

sub logger {
	my $self=shift;
	$self->{'_logger'} = shift // return $self->{'_logger'};
}


=head2 getFormData

Queries the database to return list of genomes available to user.

Method is used to populate forms with a list of public and
private genomes.

MW: OBSOLETE?

sub getFormData {
    my $self = shift;
    my $username = shift;
    
    # Return public genome names as list of hash-refs
    my $publicFormData = $self->publicGenomes();
    
    my $pubEncodedText = $self->_getJSONFormat($publicFormData);
    
    # Get private list (or empty list)
    my $privateFormData = $self->privateGenomes($username);

    #One time use.
    #$self->_getNameMap();
    #$self->_getAccessionMap();
    
    return($publicFormData, $privateFormData, $pubEncodedText);
}
=cut

sub publicGenomes {
	my $self = shift;
	my $visable_nodes = shift;
	my $subset_ids = shift;
	
	my $select_stmt = {
		'type.name' =>  'contig_collection'
	};
	if($subset_ids) {
		croak unless ref($subset_ids) eq 'ARRAY';
		$select_stmt->{feature_id} = { '-in' => $subset_ids };
	}
	
	my $genomes = $self->dbixSchema->resultset('Feature')->search(
		$select_stmt,
		{
			result_class => 'DBIx::Class::ResultClass::HashRefInflator',
			columns => [qw/feature_id uniquename name dbxref.accession/],
			join => ['type' , 'dbxref'],
			order_by    => {-asc => ['me.uniquename']}
	    }
	);
	
	$visable_nodes = {} unless defined $visable_nodes;

	while (my $row_hash = $genomes->next) {
		my $user_genome = 0;
		my $display_name = displayname($row_hash->{uniquename}, $user_genome);
		my $fid = $row_hash->{feature_id};

		print "DN: $display_name\n";
		
		my $key = "public_$fid";
		$visable_nodes->{$key} = {
			feature_id => $fid,
			displayname => $display_name,
			uniquename => $display_name,
			access => 0
		};
		
	}
}

sub privateGenomes {
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
	             'type.name'      => 'contig_collection',
			},
			{
				'upload.category' => 'public',
				'type.name'       => 'contig_collection',
			},
		];
		
		if($subset_ids) {
			croak unless ref($subset_ids) eq 'ARRAY';
			$select_stmt = [
				{
		             'login.username' => $username,
		             'type.name'      => 'contig_collection',
		             'feature_id'     => { '-in' => $subset_ids }
				},
				{
					'upload.category' => 'public',
					'type.name'       => 'contig_collection',
					'feature_id'     => { '-in' => $subset_ids }
				},
			];
		}
		
        my $genomes = $self->dbixSchema->resultset('PrivateFeature')->search(
			$select_stmt,
			{
				result_class => 'DBIx::Class::ResultClass::HashRefInflator',
				columns => [qw/feature_id uniquename/],
				'+columns' => [qw/upload.category login.username/],
				join => [
					{ 'upload' => { 'permissions' => 'login'} },
					'type'
				]

			}
		);
        
        $visable_nodes = {} unless defined $visable_nodes;
        my $has_private = 0;

		while (my $row_hash = $genomes->next) {
        #foreach my $row_hash (@privateFormData) {
			
			my $fid = $row_hash->{feature_id};
			my $acc = $row_hash->{upload}->{category};
			my $user_genome = 1;
			my $display_name = displayname($row_hash->{uniquename}, $user_genome, $acc);
			
			unless($acc eq 'public') {
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
			'type.name'       => 'contig_collection',
		};
		
		if($subset_ids) {
			croak unless ref($subset_ids) eq 'ARRAY';
			$select_stmt->{feature_id} = { '-in' => $subset_ids };
		}
		
		my $genomes = $self->dbixSchema->resultset('PrivateFeature')->search(
			$select_stmt,
			{
	            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
	            columns => [qw/feature_id uniquename/],
	            join => [
					{ 'upload' => 'permissions' },
					'type'
				]
	
	        }
        );
        
        $visable_nodes = {} unless defined $visable_nodes;
        my $has_private = 0;

		while (my $row_hash = $genomes->next) {
			my $fid = $row_hash->{feature_id};
			my $acc = 'public';
			my $user_genome = 1;
			my $display_name = displayname($row_hash->{uniquename}, $user_genome, $acc);
			
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

=head2 _hashFormData

Hashes row entries returned from the database and returns an array ref to a list of these rows.

sub _hashFormData {
    my $self = shift;
    my $features = shift;
    my @formData;
    while (my $featureRow = $features->next){
        my %formRowData;
        $formRowData{'FEATUREID'}=$featureRow->feature_id;
        $formRowData{'UNIQUENAME'}=$featureRow->uniquename;
        push(@formData, \%formRowData);
    }
    return \@formData;
}
=cut

=head2 getGenomeUploadFormData

Queries the database for form data to be filled in the genome uploader form.
Returns an array ref to form entry data.

=cut

sub getGenomeUploadFormData {
    my $self = shift;
    my $cVTerms = $self->dbixSchema->resultset('Cvterm')->search(
        {'cv.name' => 'feature_property'},
        {
            join => ['cv'],
            select => [qw/me.name/]
        }
        );
    my $genomeUploaderRef = $self->_hashGenomeUploadFormData($cVTerms);
    return $genomeUploaderRef;
}

=head2 _hashGenomeUploadFormData

Hashes row entries returnes from the database and returns an array ref to a list of these rows.

=cut

sub _hashGenomeUploadFormData {
    my $self = shift;
    my $cVTerms = shift;
    my @genomeUploadFormData;
    while (my $cVTermRow = $cVTerms->next){
        my %guRowData;
        $guRowData{'TERM'}=$cVTermRow->name;
        push(@genomeUploadFormData, \%guRowData);
    }
    return \@genomeUploadFormData;
}

=cut _getVirulenceFormData

Queries the database for form data to be filled in the virluence factor form.
Returns an array ref to form entry data.

=cut

sub getVirulenceFormData {
    my $self = shift;
    my $_virulenceFactorProperties = $self->dbixSchema->resultset('Feature')->search(
		{
        	'type_id' => $self->cvmemory->{'virulence_factor'}
        },
        {
			column  => [qw/feature_id type_id name uniquename/],
            order_by    => { -asc => ['name'] }
        }
	);
    my $virulenceFormDataRef = $self->_hashVirAmrFormData($_virulenceFactorProperties);
    my $encodedText = encode_json($virulenceFormDataRef);
    return $encodedText;
}

=cut _getAmrFormData

Queries the database for form data to be filled in the amr factor form.
Returns an array ref to form entry data.

=cut

sub getAmrFormData {
    my $self = shift;
    my $_amrFactorProperties = $self->dbixSchema->resultset('Feature')->search(
    	{
			'type_id' => $self->cvmemory->{'antimicrobial_resistance_gene'}
        },
        {
			column  => [qw/feature_id type_id name uniquename/],
        	order_by    => { -asc => ['name'] }
		}
	);
    my $amrFormDataRef = $self->_hashVirAmrFormData($_amrFactorProperties);
    my $encodedText = encode_json($amrFormDataRef);
    return $encodedText;
}

=cut _hashVirAmrFormData

Inputs all column data into a hash table and returns a reference to the hash table.
Note: the Cvterms must be defined when up-loading sequences to the database otherwise you'll get a NULL exception and the page wont load.
i.e. You cannot just upload sequences into the db just into the Feature table without having any terms defined in the Featureprop table.
i.e. Fasta files must have attributes tagged to them before uploading.

=cut

sub _hashVirAmrFormData {
    my $self=shift;
    my $_factorProperties = shift;

    my %factors;

    while (my $fRow = $_factorProperties->next){
        my %fRowData;
        $fRowData{'feature_id'}=$fRow->feature_id;
        $fRowData{'name'}=$fRow->name;
        $fRowData{'uniquename'}=$fRow->uniquename;
        $factors{$fRow->feature_id} = \%fRowData;
    }
    return \%factors;
}

=cut _getJSONFormat 

Takes as input a hash ref and returns a UTF-8 encoded JSON string. 
When passed to the browser this string is atuomatically recognized as JSON structure.

=cut

sub _getJSONFormat {
    my $self=shift;
    my $dataHashRef = shift;
    my $json = JSON::XS->new->pretty(1);
    my %jsonHash;
    $jsonHash{'data'} = $dataHashRef;
    my $_encodedText = $json->encode(\%jsonHash);
    return $_encodedText;
}

sub _getNameMap {
    my $self=shift;
    my $genomes = $self->dbixSchema->resultset('Feature')->search(
    {
        'type.name' =>  'contig_collection',
        },
        {
            columns => [qw/feature_id uniquename name dbxref.accession/],
            join => ['type' , 'dbxref'],
            order_by    => {-asc => ['me.uniquename']}
        }
        );

    my $outDirectoryName = "../../Phylogeny/NewickTrees/";
    my $outFile = "pub_common_names.map";

	open my $outFH, '>', $outDirectoryName . $outFile or die "Could not open $!\n";
    while (my $featureRow = $genomes->next) {
        my $editedFeatureName = $featureRow->name;
        $editedFeatureName =~ s/:/_/g;
        $editedFeatureName =~ s/\(/_/g;
        $editedFeatureName =~ s/\)/_/g;
		$editedFeatureName =~ s/ /_/g;
		$outFH->print("public_" . $featureRow->feature_id . "\t" . $editedFeatureName . "\n")
	}
	$outFH->close();
}

sub _getAccessionMap {
    my $self=shift;

    my $genomes = $self->dbixSchema->resultset('Feature')->search(
    {
        'type.name' =>  'contig_collection',
        },
        {
            columns => [qw/feature_id uniquename name dbxref.accession/],
            join => ['type' , 'dbxref'],
            order_by    => {-asc => ['me.uniquename']}
        }
        );

    my $outDirectoryName = "../../Phylogeny/NewickTrees/";
    my $outFile = "pub_accession.map";
	open my $outFH, '>', $outDirectoryName . $outFile or die "Could not open $!\n";

    while (my $featureRow = $genomes->next) {
        my $editedFeatureName = $featureRow->dbxref->accession;  
        $editedFeatureName =~ s/:/_/g;
        $editedFeatureName =~ s/\(/_/g;
        $editedFeatureName =~ s/\)/_/g;
		$editedFeatureName =~ s/ /_/g;

		$outFH->print("public_" . $featureRow->feature_id . "\t" . $editedFeatureName . "\n");
	}
	$outFH->close();
}


=head2 genomeInfo

Returns list of ALL genomes (and associated meta-data) for
a given user. If user is undef, returns all genomes in Feature 
table and genomes in PrivateFeature table visable to public.

Returns as json string.

=cut

sub genomeInfo {
	my $self = shift;
	my $username = shift;
	
	# Get pre-queried public feature table data
	my $meta_rs = $self->dbixSchema->resultset("Meta")->search(
		{
			name => 'public'	
		},
		{
		    columns => ['data_string']
		}
	);
		
	my $public_json;
	if($username) {
		my $public_genome_info = $self->_runGenomeQuery(1, $username);
		$public_json = encode_json($public_genome_info);
	}
	else {
		if(my $row = $meta_rs->first) {
			$public_json = $row->data_string;
		} else {
			my $public_genome_info = $self->_runGenomeQuery(1);
			$public_json = encode_json($public_genome_info);
		}
	}
	
	my $private_json;
	if($username) {
		# Get user private genomes
	
		my $private_genome_info = $self->_runGenomeQuery(0, $username);
		$private_json = encode_json($private_genome_info);
	
   } else {
		# Get user public genomes
		
		my $meta_rs = $self->dbixSchema->resultset("Meta")->search(
			{
				name => 'upublic'	
			},
			{
				columns => ['data_string']
			}
		);
		
		if(my $row = $meta_rs->first) {
			$private_json = $row->data_string;
		} else {
			my $private_genome_info = $self->_runGenomeQuery(0);
			$private_json = encode_json($private_genome_info);	
		}
   }

   return($public_json, $private_json);
}

=head2 metaTerms 

Hash-ref of meta term keys used in meta-data hashes

=cut

sub metaTerms {
	my $self = shift;

	return $self->{meta_terms};
}

=head2 subtypes

Hash-ref of subtype keys used in meta-data hashes

=cut

sub subtypes {
	my $self = shift;

	return $self->{subtypes};
}

sub _runGenomeQuery {
	my ($self, $public, $username) = @_;
	
	#$self->dbixSchema->storage->debug(1);
	
	#$self->elapsed_time('Start of meta-data query');

	# Table and relationship names
	my $feature_table_name = 'Feature';
	my $featureprop_rel_name = 'featureprops';
	my $feature_relationship_rel_name = 'feature_relationship_objects';
	my $feature_group_table_name = 'FeatureGroup';
    # Added tables to look up genome locaiton info
    my $genome_location_table_name = 'genome_locations';
	my $order_name = { '-asc' => ['featureprops.rank'] };
	unless($public) {
		$feature_table_name = 'PrivateFeature';
		$featureprop_rel_name = 'private_featureprops';
		$feature_relationship_rel_name = 'private_feature_relationship_objects';
		$feature_group_table_name = 'PrivateFeatureGroup';
        # Added tables to look up private genome location infoq
        $genome_location_table_name = "private_genome_locations";
		$order_name = { '-asc' => ['private_featureprops.rank'] };
	}
	
	# Query
	my $query = {
		'type.name'      => 'contig_collection',
		'type_2.name'    => { '-in' => [ keys %{$self->{meta_terms}} ] },
    };
	
    
    # Added $genome_location_table_name => 'geocode' to join
    my $join = ['type', {$genome_location_table_name => 'geocode'}];
    my $prefetch = [
	    { 'dbxref' => 'db' },
	    { $featureprop_rel_name => 'type' },
    ];
    
    # Subtypes needs separate query
    my $query2 = {
    	'type.name'        => 'part_of',
		'type_2.name'      => 'allele_fusion',
		'type_3.name'      => { '-in' => [ keys %{$self->{subtypes}} ] },
    };
    my $join2 = [];
    my $prefetch2 = [
	    { $feature_relationship_rel_name  => [ 'type', { 'subject' => [ 'type', { $featureprop_rel_name => 'type' } ] } ] }
	];

	# Groups needs separate query
	my $query3 = {
		'-bool' => 'genome_group.standard'
	};
	my $join3 = [
		'genome_group'
	];

	if($username) {
		$query3 = {
			'-or' => [ { '-bool' => 'genome_group.standard' }, { 'genome_group.username' => $username } ]
	    };
	}

	# Query data in private tables
	unless($public) {
		
		if($username) {
			$query = [
            	{
					'login.username'     => $username,
					'type.name'          => 'contig_collection',
					'type_2.name'        => { '-in' => [ keys %{$self->{meta_terms}} ] }			
             	},
             	{
					'upload.category'    => 'public',
					'type.name'          => 'contig_collection',
					'type_2.name'        => { '-in' => [ keys %{$self->{meta_terms}} ] }
				}
			];

			push @$prefetch, 'upload';
			
			$query2 = [
            	{
					'login.username'     => $username,
					'type.name'          => 'part_of',
					'type_2.name'        => 'allele_fusion',
					'type_3.name'        => { '-in' => [ keys %{$self->{subtypes}} ] },
					
             	},
             	{
					'upload.category'    => 'public',
					'type.name'          => 'part_of',
					'type_2.name'        => 'allele_fusion',
					'type_3.name'        => { '-in' => [ keys %{$self->{subtypes}} ] },
				}
			];
		    push @$prefetch2, 'upload';
			
		} else {
			$query = {
				'upload.category'    => 'public',
				'type.name'          => 'contig_collection',
				'type_2.name'        => { '-in' => [ keys %{$self->{meta_terms}} ] },
				
            };
            
            $query2 = {
				'upload.category'    => 'public',
				'type.name'          => 'part_of',
				'type_2.name'        => 'allele_fusion',
				'type_3.name'        => { '-in' => [ keys %{$self->{subtypes}} ] },
            };
        }

        push @$join, { 'upload' => { 'permissions' => 'login'} };
        push @$join2, { 'upload' => { 'permissions' => 'login'} };
    }

	#$self->elapsed_time('Begin query 1');
    my $feature_rs = $self->dbixSchema->resultset($feature_table_name)->search(
		$query,	
		{
			join => $join,
			prefetch => $prefetch,
			#order_by => $order_name
		}
     );
     
	#$self->elapsed_time('Begin query 2');
	my $feature_rs2 = $self->dbixSchema->resultset($feature_table_name)->search(
		$query2,	
		{
			join => $join2,
			prefetch => $prefetch2,
			#order_by => $order_name
		}
	);

    #$self->elapsed_time('Begin query 3');
	my $groups_rs3 = $self->dbixSchema->resultset($feature_group_table_name)->search(
		$query3,	
		{
			join => $join3,
			order_by => 'me.feature_id'
		}
	);


	# Create hash from all results
	my %genome_info;
	
    my $featureCount = 0;
    
	#$self->elapsed_time('Hash query 1');
	while(my $feature = $feature_rs->next) {
		my %feature_hash;
		# Feature data
		$feature_hash{uniquename} = $feature->uniquename;
		if($feature->dbxref) {
			my $version = $feature->dbxref->version;
			$feature_hash{primary_dbxref} = $feature->dbxref->db->name . ': ' . $feature->dbxref->accession;
			$feature_hash{primary_dbxref} .= '.' . $version if $version && $version ne '';
		}
		
		unless($public) {
			# Display name
			my $user_genome = 1;
			
			if($username) {
				# User logged in and may have some private genomes
				$feature_hash{displayname} = displayname($feature_hash{uniquename}, $user_genome, $feature->upload->category);

			} else {
				# User not logged in, all user genomes must be public
				$feature_hash{displayname} = displayname($feature_hash{uniquename}, $user_genome, 'public');
			}
			
		} else {
			my $user_genome = 0;
			$feature_hash{displayname} = displayname($feature_hash{uniquename}, $user_genome);
		}
		
		# Featureprop data
		my $featureprops = $feature->$featureprop_rel_name;

		while(my $fp = $featureprops->next) {
			my $type = $fp->type->name;
			$feature_hash{$type} = [] unless defined $feature_hash{$type} || $type eq 'isolation_location';
			push @{$feature_hash{$type}}, $fp->value unless $type eq 'isolation_location';
		}

        # Genome location data
        my $genomeLocation = $feature->$genome_location_table_name;

        while (my $location = $genomeLocation->next) {
            $feature_hash{'isolation_location'} = [] unless defined $feature_hash{'isolation_location'} || !($location->geocode->location);
            push @{$feature_hash{'isolation_location'}}, $location->geocode->location unless !($location->geocode->location);
        }
		
		my $k = ($public) ? 'public_' : 'private_';
		
		$k .= $feature->feature_id;
		
		$genome_info{$k} = \%feature_hash;
		$featureCount++;
	}

	get_logger->debug("$featureCount features found");
	
	#$self->elapsed_time('Hash query 2');
	while(my $feature = $feature_rs2->next) {
		
		my $k = ($public) ? 'public_' : 'private_';
		$k .= $feature->feature_id;
		
		my $feature_hash = $genome_info{$k};
		croak "Error: something strange is going on... genome with subtype properties but no other properties.\n" unless defined $feature_hash;
		
		my $typing_feature_relationships =  $feature->$feature_relationship_rel_name;
		while(my $fr = $typing_feature_relationships->next ) {
			# Iterate through typing sequences linked to genome
			
			my $typing_properties = $fr->subject->$featureprop_rel_name;
			while(my $st = $typing_properties->next){
				# Iterate through types assigned to sequence
				my $type = $st->type->name;

				$feature_hash->{$type} = [] unless defined $feature_hash->{$type};
				push @{$feature_hash->{$type}}, $st->value;
			}
			
		}
		
	}

	#$self->elapsed_time('Hash query 3');
	# Requires resultset to be sorted by feature ID
	my $group = $groups_rs3->next;
	if($group) {

		my $current_feature = $group->feature_id;
		my @group_assignments = ($group->genome_group_id);
		while($group = $groups_rs3->next) {

			if($current_feature != $group->feature_id) {
				my $k = ($public) ? 'public_' : 'private_';
				$k .= $current_feature;
				my $feature_hash = $genome_info{$k};
				croak "Error: something strange is going on... genome with group assignment but not returned by main feature query.\n" unless defined $feature_hash;
				$feature_hash->{groups} = [@group_assignments];
				$current_feature = $group->feature_id;
				@group_assignments = ($group->genome_group_id);
			} else {
				push @group_assignments, $group->genome_group_id;
			}
		}

		my $k = ($public) ? 'public_' : 'private_';
		$k .= $current_feature;
		my $feature_hash = $genome_info{$k};
		croak "Error: something strange is going on... genome with group assignment but not returned by main feature query.\n" unless defined $feature_hash;
		$feature_hash->{groups} = \@group_assignments;
	}
	

	#$self->elapsed_time('End');
	
	return(\%genome_info);
}

=head2 loadMetaData

To save time, all public meta data (which is fairly static)
is queried once and then converted to json.  This json string 
is stored in the meta table.

=cut

sub loadMetaData {
	my $self = shift;
	
	my $public_genomes = $self->_runGenomeQuery(1);	
	my $user_public_genomes = $self->_runGenomeQuery(0);
	
	my $pub_json = encode_json($public_genomes);
	my $usr_json = encode_json($user_public_genomes);
	
	$self->dbixSchema->resultset('Meta')->update_or_create(
		{
			name             => 'public',
			format           => 'json',
			data_string      => $pub_json,
			timelastmodified => \'now()'
		},
		{
			key => 'meta_c1'
		}
	);
	
	$self->dbixSchema->resultset('Meta')->update_or_create(
		{
			name             => 'upublic',
			format           => 'json',
			data_string      => $usr_json,
			timelastmodified => \'now()'
		},
		{
			key => 'meta_c1'
		}
	);
	
}

=cut verifyAccess

Confirm that user can view provided user-uploaded genome.

Returns false if user does not have view access or returns the genome
privacy setting if true (i.e. public, private or release).

=cut

sub verifyAccess {
	my ($self, $username, $feature_id) = @_;
	
	my $results = $self->verifyMultipleAcess($username, [$feature_id]);
	
	return $results->{$feature_id};
}

sub verifyMultipleAccess {
	my ($self, $username, $feature_ids) = @_;
	
	croak unless ref($feature_ids) eq 'ARRAY';
	
	my $genomes_rs = $self->dbixSchema->resultset('PrivateFeature')->search(
		[
			{
				'login.username' => $username,
				'feature_id' => { '-in' => $feature_ids }
        	},
			{
				'upload.category'    => 'public',
				'feature_id' => { '-in' => $feature_ids }
			},
		],
        {     
        	columns => [qw/feature_id/],
            '+columns' => [qw/upload.category/],
            join => { 'upload' => { 'permissions' => 'login'} },
		}
	);
	
	my %results;
	foreach my $id (@$feature_ids) {
		if(my $feature = $genomes_rs->find( { 'feature_id' => $id })) {
			$results{$id} = $feature->upload->category;	
		} else {
			$results{$id} = 0;	
		}
	}
	
	return \%results;
}

=head2 seqAlignment

seqAlignent(hash)

Input:
Hash with keys:
  locus        => A query gene feature_id 
  warden       => GenomeWarden instance
  typing       => Indicates looking up typing sequences
                  rather than alleles
                  	                                
Returns: 
  a hash-ref representing a multiple
  sequence alignment of gene alleles.

=cut

sub seqAlignment {
	my ($self, %args) = @_;

	my $locus   = $args{locus};
	my $warden  = $args{warden};
	my $type  = $args{type};

	my $type_name;
	if($type eq 'gene') {
		$type_name = 'similar_to';
	}
	elsif($type eq 'typing') {
		$type_name = 'variant_of';
	}
	elsif($type eq 'pangenome') {
		$type_name = 'derives_from'
	}
	else {
		croak "Error: Unrecognized 'type' argument $type in parameter hash to seqAlignment() method\n"
	}
	
	my %alignment;
	
	if($warden->numPrivate) {
		
		my $feature_rs = $self->dbixSchema->resultset('PrivateFeature')->search(
			{
				'private_feature_relationship_subjects.object_id' => $locus,
				'type.name' => $type_name, 
				'private_feature_relationship_subjects_2.object_id' => { '-in' => $warden->featureList('private') },
				'type_2.name' => 'part_of'
			},
			{
				join => [
					{ 'private_feature_relationship_subjects' => 'type' },
					{ 'private_feature_relationship_subjects' => 'type' },
					{ 'private_featureloc_features' => 'srcfeature'}
				],
				columns => [qw/residues feature_id/],
				'+select' => ['private_feature_relationship_subjects_2.object_id', 'private_featureloc_features.fmin',
					'private_featureloc_features.fmax', 'private_featureloc_features.strand', 'srcfeature.name'],
				'+as' => ['collection_id', 'fmin', 'fmax', 'strand', 'contig_name']
			}
		);
		
		while(my $feature = $feature_rs->next) {
			my $genome = 'private_'.$feature->get_column('collection_id');
			my $allele = $feature->feature_id;
			my $header = "$genome|$allele";
			$alignment{$header} = {
				seq => $feature->residues,
				genome => $genome,
				locus => $allele
			};

			if($feature->get_column('contig_name')) {
				$alignment{$header}{start_pos} = $feature->get_column('fmin');
				$alignment{$header}{end_pos} = $feature->get_column('fmax') - 1;
				$alignment{$header}{strand} = $feature->get_column('strand');
				$alignment{$header}{contig_name} = $feature->get_column('contig_name');
			}
		}
	}
	
	if($warden->numPublic) {
		my $select_stmt = {
			'feature_relationship_subjects.object_id' => $locus,
			'type.name' => $type_name,
			'type_2.name' => 'part_of'
		};
		if($warden->subset) {
			$select_stmt->{'feature_relationship_subjects_2.object_id'} = { '-in' => $warden->featureList('public') };
		}
		my $feature_rs = $self->dbixSchema->resultset('Feature')->search(
			$select_stmt,
			{
				join => [
					{ 'feature_relationship_subjects' => 'type' },
					{ 'feature_relationship_subjects' => 'type' },
					{ 'featureloc_features' => 'srcfeature'},
				],
				columns => [qw/residues feature_id/],
				'+select' => ['feature_relationship_subjects_2.object_id', 'featureloc_features.fmin',
					'featureloc_features.fmax', 'featureloc_features.strand', 'srcfeature.name'],
				'+as' => ['collection_id', 'fmin', 'fmax', 'strand', 'contig_name']
			}
		);
		
		while(my $feature = $feature_rs->next) {
			my $genome = 'public_'.$feature->get_column('collection_id');
			my $allele = $feature->feature_id;
			my $header = "$genome|$allele";
			$alignment{$header} = {
				seq => $feature->residues,
				genome => $genome,
				locus => $allele
			};

			if($feature->get_column('contig_name')) {
				$alignment{$header}{start_pos} = $feature->get_column('fmin');
				$alignment{$header}{end_pos} = $feature->get_column('fmax') - 1;
				$alignment{$header}{strand} = $feature->get_column('strand');
				$alignment{$header}{contig_name} = $feature->get_column('contig_name');
			}
		}
	}
	
	my @sets = values(%alignment);
	
	my $sequence = $sets[0]->{seq};
	my $len = length($sequence);
	
	map { croak "Error: sequence alignment lengths are not equal." unless length($_->{seq}) == $len } @sets[1..$#sets];
	
	# Remove gap columns
	my @removeCols;
	for(my $i = 0; $i < $len; $i++) {
		
		my $symbol = substr($sequence, $i, 1);
		
		if($symbol eq '-') {
			# Check if entire col is a gap
			
			foreach my $s (@sets[1..$#sets]) {
				if($symbol ne substr($s->{seq},$i,1)) {
					# mismatch
					last;
				}
			}
		
			# Gap column needs to be spliced out
			push @removeCols, $i;
		}
	}
	
	foreach my $s (values %alignment) {
		my $seq = '';
		my $p = 0;
		foreach my $r (@removeCols) {
			my $l = $r-$p;
			$seq .= substr $s->{seq}, $p, $l;
			
			$p = $r+1;
		}
		my $l = $len-$p+1;
		$seq .= substr $s->{seq}, $p, $l if $l;
		$s->{seq} = $seq;
	}

	return \%alignment;
	
}




=head2 getGeneAlleleData

getGeneAlleleData(%args)

Inputs:
hash containing key-value pairs:
 -markers [optional]  Array-ref of query gene feature ids 
 -warden              GenomeWarden object                         

Returns:
Hash containing key-value pairs:
  name - hash mapping query gene feature ids to names
  amr  - hash mapping allele feature ids to genome ids and query gene ids
         for AMR genes   
  vf   - hash mapping allele feature ids to genome ids and query gene ids
         for virulence factors

=cut

sub getGeneAlleleData {
	my $self = shift;
	my (%args) = @_;
	
	# Params
	get_logger->debug(%args);
	my $warden = $args{warden};
	croak "Error: must provide GenomeWarden object 'warden' as an argument." unless $warden;
	
	# Get query genes
	my $amr_type = $self->cvmemory->{'antimicrobial_resistance_gene'};
	my $vf_type = $self->cvmemory->{'virulence_factor'};
	my %query_genes;
	
	my $select_stmt;
	if($args{markers}) {
		# Lookup specific genes
		croak "Invalid 'markers' argument. Must be arrayref." unless ref($args{markers}) eq 'ARRAY';
		$select_stmt->{'feature_id'} = {'-in' => $args{markers}};
	} else {
		# Lookup all genes
		$select_stmt->{'type_id'} = {'-in' => [$amr_type, $vf_type]};
	}
	
	my $query_rs = $self->dbixSchema->resultset('Feature')->search(
		$select_stmt,
		{
			columns => [qw/feature_id uniquename type_id/]
		}
	);
	
	while( my $query_row = $query_rs->next) {
		
		my $type_id = $query_row->type_id;
		my $gene_name = $query_row->uniquename;
		my $gene_id = $query_row->feature_id;
		
		if($type_id == $vf_type) {
			$query_genes{vf}{$gene_id} = $gene_name;
		} elsif($type_id == $amr_type) {
			$query_genes{amr}{$gene_id} = $gene_name;
		} else {
			get_logger->warn("Unrecognized query gene type $type_id.\n");
		}
	}
	
	# Get alleles
	my ($public_genomes, $private_genomes) = $warden->featureList();
	my %alleles;
	
	#$self->dbixSchema->storage->debug(1);
	
	if($warden->numPublic) {
		
		# Retreive allele hits for each query gene (can be AMR/VF)
		# for selected public genomes
		my $select_stmt = {
			'me.type_id' => $self->cvmemory->{'similar_to'},
			'feature_relationship_subjects.type_id' => $self->cvmemory->{'part_of'},
		};
		
		# Select only for specific AMR/VF genes
		if($args{markers}) {
			$select_stmt->{'me.object_id'} = {'-in' => $args{markers}};
		}
		
		# Subset of public genomes
		if($warden->subset) {
			$select_stmt->{'feature_relationship_subjects.object_id'} = {'-in' => $public_genomes},
		}
		
		my $allelehits_rs = $self->dbixSchema->resultset('FeatureRelationship')->search(
			$select_stmt,
			{
				join => [
					{'subject' => 'feature_relationship_subjects'},
				],
				columns => [qw/subject_id object_id/],
				'+columns' => [
					{
						'subject.feature_id' => 'subject.feature_id'
					},
					{ 
						'subject.feature_relationship_subjects.object_id' => 'feature_relationship_subjects.object_id',
					    'subject.feature_relationship_subjects.feature_relationship_id' => 'feature_relationship_subjects.feature_relationship_id'
					}
                 ],
				collapse => 1
			}
		);
		
		
		# Hash results
		while(my $allele_row = $allelehits_rs->next) {
			
			my $genome_label = 'public_'.$allele_row->subject->feature_relationship_subjects->first->object_id;
			my $allele_id = $allele_row->subject_id;
			my $gene_id = $allele_row->object_id;
			
			$alleles{$genome_label}->{$gene_id} = [] unless defined($alleles{$genome_label}->{$gene_id});
			push @{$alleles{$genome_label}->{$gene_id}}, $allele_id;
		}
	}
	
	if($warden->numPrivate) {
		
		# Retreive allele hits for each query gene (can be AMR/VF)
		# for selected public genomes
		my $select_stmt = {
			'me.type_id' => $self->cvmemory->{'similar_to'},
			'private_feature_relationship_subjects.type_id' => $self->cvmemory->{'part_of'},
			'private_feature_relationship_subjects.object_id' => {'-in' => $private_genomes}
		};
		
		# Select only for specific AMR/VF genes
		if($args{markers}) {
			$select_stmt->{'me.object_id'} = {'-in' => $args{markers}};
		}
		
		my $allelehits_rs = $self->dbixSchema->resultset('PripubFeatureRelationship')->search(
			$select_stmt,
			{
				prefetch => [
					{'subject' => 'private_feature_relationship_subjects'},
				]
			}
		);
		
		# Hash results
		while(my $allele_row = $allelehits_rs->next) {
			
			my $genome_label = 'private_'.$allele_row->subject->private_feature_relationship_subjects->first->object_id;
			my $allele_id = $allele_row->subject_id;
			my $gene_id = $allele_row->object_id;
			
			$alleles{$genome_label}->{$gene_id} = [] unless defined $alleles{$genome_label}->{$gene_id};
			push @{$alleles{$genome_label}->{$gene_id}}, $allele_id;
		}
		
	}
	
	return({ genes => \%query_genes, alleles => \%alleles });
}

=head2 getStxData

getStxData(%args)

Inputs:
hash containing possible key -value pairs:
 -markers          Array-ref of typing sequence feature ids    
 -public_genomes   Array-ref of genome feature ids OR a string 'all' to retrieve all genomes
 -private_genomes  Array-ref of genome private_feature ids
	                                
MAKE SURE THE USER CAN ACCESS THESE GENOMES
DO NOT RELEASE PRIVATE SEQUENCES!	                                

Returns:
Hash containing key - value pairs:
  name - hash mapping typing reference sequence feature ids to names 
  stx  - hash mapping allele_fusion feature ids to genome ids and ref sequence ids

=cut


sub getStxData {
	my $self = shift;
	my (%args) = @_;
	
	$self->dbixSchema->storage->debug(1);
	
	# The set of genomes must be defined
	my $warden = $args{warden};
	
	my ($public_genomes, $private_genomes) = $warden->featureList();
	
	my %subunit_names;
	my %subtypes;
	
	if($warden->numPublic) {
		
		# Retreive allele_fusion hits for each reference gene
		# for selected public genomes
		my $select_stmt = {
			'me.type_id' => $self->cvmemory->{'variant_of'},
			'feature_relationship_subjects.type_id' => $self->cvmemory->{'part_of'},
			'featureprops.type_id' => [$self->cvmemory->{'stx1_subtype'}, $self->cvmemory->{'stx2_subtype'}]
		};
		
		# Select only for specific typing reference sequences
		if($args{markers}) {
			croak "Invalid 'markers' argument. Must be arrayref." unless ref($args{markers}) eq 'ARRAY';
			$select_stmt->{'me.object_id'} = {'-in' => $args{markers}};
		}
		
		# Subset of public genomes
		if($warden->subset) {
			$select_stmt->{'feature_relationship_subjects.object_id'} = {'-in' => $public_genomes},
		}
		
		my $allelehits_rs = $self->dbixSchema->resultset('FeatureRelationship')->search(
			$select_stmt,
			{
				prefetch => [
					{'subject' => ['feature_relationship_subjects', 'featureprops']},
					'object'
				]
			}
		);
		
		# Hash results
		while(my $allele_row = $allelehits_rs->next) {
			
			my $genome_label = 'public_'.$allele_row->subject->feature_relationship_subjects->first->object_id;
			my $allele_id = $allele_row->subject_id;
			my $ref_id = $allele_row->object_id;
			my $ref_name = $allele_row->object->uniquename;
			my $subt = $allele_row->subject->featureprops->first->value;
			
			$subunit_names{$ref_id} = $ref_name;
			
			$subtypes{$genome_label}->{$ref_id} = [] unless defined($subtypes{$genome_label}->{$ref_id});
			push @{$subtypes{$genome_label}->{$ref_id}}, { allele => $allele_id, subtype => $subt};
		}
	}
	
	if($warden->numPrivate) {
		
		# Retreive allele_fusion hits for each reference gene
		# for selected public genomes
		my $select_stmt = {
			'me.type_id' => $self->cvmemory->{'variant_of'},
			'private_feature_relationship_subjects.type_id' => $self->cvmemory->{'part_of'},
			'private_feature_relationship_subjects.object_id' => {'-in' => $private_genomes},
			'private_featureprops.type_id' => [$self->cvmemory->{'stx1_subtype'}, $self->cvmemory->{'stx2_subtype'}]
		};
		
		# Select only for specific typing reference sequences
		if($args{markers}) {
			croak "Invalid 'markers' argument. Must be arrayref." unless ref($args{markers}) eq 'ARRAY';
			$select_stmt->{'me.object_id'} = {'-in' => $args{markers}};
		}
		
		my $allelehits_rs = $self->dbixSchema->resultset('PripubFeatureRelationship')->search(
			$select_stmt,
			{
				prefetch => [
					{'subject' => ['private_feature_relationship_subjects', 'private_featureprops']},
					'object'
				]
			}
		);
		
		# Hash results
		while(my $allele_row = $allelehits_rs->next) {
			
			my $genome_label = 'private_'.$allele_row->subject->feature_relationship_subjects->first->object_id;
			my $allele_id = $allele_row->subject_id;
			my $ref_id = $allele_row->object_id;
			my $ref_name = $allele_row->object->uniquename;
			my $subt = $allele_row->subject->featureprops->first->value;
			
			$subunit_names{$ref_id} = $ref_name;
			
			$subtypes{$genome_label}->{$ref_id} = [] unless defined($subtypes{$genome_label}->{$ref_id});
			push @{$subtypes{$genome_label}->{$ref_id}}, { allele => $allele_id, subtype => $subt};
		}
		
	}
	
	return({names => \%subunit_names, stx => \%subtypes});
}


=head2 categories

Duplicate from Genes module - may consider merging into FormDataGenerator

=cut
sub categories {
    my $self = shift;
    my ($vfJSON, $amrJSON) = @_;

    die "Must pass a VF and AMR hash ref" unless $vfJSON && $amrJSON;

    my ($vfRef,$amrRef) = (decode_json($vfJSON), decode_json($amrJSON));  
    
    my $amrCategoryResults = $self->dbixSchema->resultset('AmrCategory')->search(
        {},
        {
            join => ['parent_category', 'gene_cvterm', 'category'],
            select => [
                'parent_category.cvterm_id',
                'parent_category.name',
                'parent_category.definition',
                'gene_cvterm.cvterm_id',
                'gene_cvterm.name',
                'gene_cvterm.definition',
                'category.cvterm_id',
                'category.name',
                'category.definition',
                'feature_id'],
            as => [
                'parent_id',
                'parent_name',
                'parent_definition',
                'gene_id',
                'gene_name',
                'gene_definition',
                'category_id',
                'category_name',
                'category_definition',
                'feature_id']
        }
    );

    my %amrCategories;
    while (my $row = $amrCategoryResults->next) {
        # TODO: Apeend the AMR categories and subcategories to the AMR lists
        my $parent_id = $row->get_column('parent_id');
        my $category_id = $row->get_column('category_id');
        my $gene_id = $row->get_column('feature_id');
        my $parent_name = $row->get_column('parent_name');
        my $category_name = $row->get_column('category_name');

        $amrRef->{$gene_id}->{'cats'} = {} unless exists $amrRef->{$gene_id}->{'cats'};
        $amrRef->{$gene_id}->{'cats'}->{$parent_id}->{'subcats'} = {} unless exists $amrRef->{$gene_id}->{'cats'}->{$parent_id}->{'subcats'};
        $amrRef->{$gene_id}->{'cats'}->{$parent_id}->{'subcats'}->{$category_id} = undef;

        $amrCategories{$parent_id} = {} unless exists $amrCategories{$parent_id};
        $amrCategories{$parent_id}->{'parent_name'} = $parent_name;
        $amrCategories{$parent_id}->{'parent_definition'} = $row->get_column('parent_definition');
        $amrCategories{$parent_id}->{'subcategories'} = {} unless exists $amrCategories{$parent_id}->{'subcategories'};
        $amrCategories{$parent_id}->{'subcategories'}->{$category_id} = {} unless exists $amrCategories{$parent_id}->{'subcategories'}->{$category_id};
        $amrCategories{$parent_id}->{'subcategories'}->{$category_id}->{'parent_id'} = $parent_id;
        $amrCategories{$parent_id}->{'subcategories'}->{$category_id}->{'category_name'} = $category_name;
        $amrCategories{$parent_id}->{'subcategories'}->{$category_id}->{'category_definition'} = $row->get_column('category_definition');
        $amrCategories{$parent_id}->{'subcategories'}->{$category_id}->{'gene_ids'} = [] unless exists $amrCategories{$parent_id}->{'subcategories'}->{$category_id}->{'gene_ids'};
        push(@{$amrCategories{$parent_id}->{'subcategories'}->{$category_id}->{'gene_ids'}}, $gene_id);
    }

    my $vfCategoryResults = $self->dbixSchema->resultset('VfCategory')->search(
        {},
        {
            join => ['parent_category', 'gene_cvterm', 'category'],
            select => [
                'parent_category.cvterm_id',
                'parent_category.name',
                'parent_category.definition',
                'gene_cvterm.cvterm_id',
                'gene_cvterm.name',
                'gene_cvterm.definition',
                'category.cvterm_id',
                'category.name',
                'category.definition',
                'feature_id'],
            as => [
                'parent_id',
                'parent_name',
                'parent_definition',
                'gene_id',
                'gene_name',
                'gene_definition',
                'category_id',
                'category_name',
                'category_definition',
                'feature_id']
        }
    );


    my %vfCategories;
    while (my $row = $vfCategoryResults->next) {
        #TODO: Append categories and subcategories to the VF lists
        my $parent_id = $row->get_column('parent_id');
        my $category_id = $row->get_column('category_id');
        my $gene_id = $row->get_column('feature_id');
        my $parent_name = $row->get_column('parent_name');
        my $category_name = $row->get_column('category_name');

        $vfRef->{$gene_id}->{'cats'} = {} unless exists $vfRef->{$gene_id}->{'cats'};
        $vfRef->{$gene_id}->{'cats'}->{$parent_id}->{'subcats'} = {} unless exists $vfRef->{$gene_id}->{'cats'}->{$parent_id}->{'subcats'};
        $vfRef->{$gene_id}->{'cats'}->{$parent_id}->{'subcats'}->{$category_id} = undef;
        
        $vfCategories{$parent_id} = {} unless exists $vfCategories{$parent_id};
        $vfCategories{$parent_id}->{'parent_name'} = $parent_name;
        $vfCategories{$parent_id}->{'parent_definition'} = $row->get_column('parent_definition');
        $vfCategories{$parent_id}->{'subcategories'} = {} unless exists $vfCategories{$parent_id}->{'subcategories'};
        $vfCategories{$parent_id}->{'subcategories'}->{$category_id} = {} unless exists $vfCategories{$parent_id}->{'subcategories'}->{$category_id};
        $vfCategories{$parent_id}->{'subcategories'}->{$category_id}->{'parent_id'} = $parent_id;
        $vfCategories{$parent_id}->{'subcategories'}->{$category_id}->{'category_name'} = $category_name;
        $vfCategories{$parent_id}->{'subcategories'}->{$category_id}->{'category_definition'} = $row->get_column('category_definition');
        $vfCategories{$parent_id}->{'subcategories'}->{$category_id}->{'gene_ids'} = [] unless exists $vfCategories{$parent_id}->{'subcategories'}->{$category_id}->{'gene_ids'};
        push(@{$vfCategories{$parent_id}->{'subcategories'}->{$category_id}->{'gene_ids'}}, $gene_id);
    }

    my %categories = ('vfCats' => \%vfCategories,
                      'amrCats' => \%amrCategories);

    my $categories_json = encode_json(\%categories);
    $amrJSON = encode_json($amrRef);
    $vfJSON = encode_json($vfRef);
    return ($categories_json, $vfJSON, $amrJSON);
}

sub elapsed_time {
	my ($self, $mes) = @_;
	
	my $time = $self->{now};
	$self->{now} = time();
	printf("$mes: %.2f\n", $self->{now} - $time); 
	$self->logger->debug(sprintf("$mes: %.2f", $self->{now} - $time));
	
}

sub displayname {
	my ($uniquename, $private_table, $category) = @_;

	my $dname = $uniquename;

	return $dname unless $private_table;

	if($category eq 'public') {
		$dname .= $public_suffix;
	} else {
		$dname .= $private_suffix;
	}

	return $dname;

}


################
## Group Methods
################


=head2 userGroups

Returns group JSON object for anonymous or logged-in
user. This is just the list of group categories & corresponding
groups. Group IDs for individual genomes are provided in the 
public_ and private_genome JSON object returned by method
genomeInfo().

Groups not assigned a 'collection', are added to the default
user collection: 'Individuals',

Users with no custom groups, will have empty custom array.

group JSON:

{
	
	custom: {
		[
			{
				name: ...,
				description: ...,
				level: 0,
				type: 'collection',
				children: [
					{
						id: ....,
						name: ...,
						description: ...,
						type: 'group'
					}
				]
			},
			...
		]
	},
	standard: {
		...
	}
}

=cut

sub userGroups {
	my $self = shift;
	my $username = shift;

	# Standard groups
	# All users get these groups
	my $standard_rs = $self->dbixSchema->resultset("Meta")->search(
		{
			name => 'stdgrp-org'	
		},
		{
		    columns => ['data_string']
		}
	);
		
	my $standard_json;
	if(my $row = $standard_rs->first) {
		$standard_json = $row->data_string;
	} else {
		croak "Error: cannot find Standard Group hierarchy object in Meta.";
	}

	
	my $custom_section;
	if($username) {
		# Get user custom groups
		my $custom_rs = $self->dbixSchema->resultset("GroupCategory")->search(
			{
				'me.username' => $username	
			},
			{
			    prefetch => [ 'genome_groups' ]
			}
		);

		$custom_section = $self->_formatUserGroups($custom_rs);
		
   	} else {
		# User not logged in, return 'empty' object
		$custom_section = $self->_formatUserGroups(undef);
		
   	}
   	my $custom_json = encode_json($custom_section);

	my $group_hierarchy_json = "{\"standard\": $standard_json, \"custom\": $custom_json }";

   return $group_hierarchy_json;
}

sub _formatUserGroups {
	my $self = shift;
	my $group_rs = shift;

	if($group_rs && $group_rs->count) {
		# Convert group into proper JSON format
		my @collections;

		while(my $collection_row = $group_rs->next) {
			
			my $collection = {
				name => $collection_row->name,
				description => $collection_row->description,
				type => 'collection',
				children => [],
				level => 0
			};

			my $group_rs = $collection_row->genome_groups;
			while(my $group_row = $group_rs->next) {

				my $group_href = {
					id => $group_row->genome_group_id,
					name => $group_row->name,
					description => $group_row->description,
					type => 'group'
				};
				push @{$collection->{'children'}}, $group_href;
			}

			push @collections, $collection;
		}

		return \@collections;

	} else {
		# No group/categories

		return [ ];
	}
}

=head2 userGroupList

Returns hash-ref of user-created custom groups for logged-in users. 
Does not include group category structure or standard pre-defined groups.

Hash-ref structure:
  group_id => group_name

=cut
sub userGroupList {
	my $self = shift;
	my $username = shift;

	croak "Error: missing parameter 'username'." unless $username;

	# Get user custom groups
	my $group_rs = $self->dbixSchema->resultset("GenomeGroup")->search(
		{
			'me.username' => $username	
		},
		{
			result_class => 'DBIx::Class::ResultClass::HashRefInflator',
			columns => [qw/genome_group_id name/],
		}
	);

	my $group_hashref = {};
	map { $group_hashref->{$_->{'genome_group_id'}} = $_->{'name'} } $group_rs->all();

	return $group_hashref;
}

=head2 createGroup

Add new custom strain group.

Input:
Param hash-ref:
[Required]
  username    => text 
  name        => text
[Optional]
  description => text 
  category  => text

Returns:
  genome_group_id on success, or 0 on failure

=cut

sub createGroup {
	my $self = shift;
	my $warden = shift; # GenomeWarden object
	my $params = shift; # Input params hash-ref

	# Required parameters
	my $group_name = $params->{name} or croak "Error: missing input parameter 'name'";
	my $username = $params->{username} or croak "Error: missing input parameter 'username'"; 

	# Optional parameters
	my $group_description = $params->{description};
	my $category_name = $params->{category} ||= 'Individuals';

	# Check if group name is unique
	my $group = {
		name => $group_name,
		username => $username
	};
	my $group_result = $self->dbixSchema->resultset('GenomeGroup')->find(
		$group,
		{
			key => 'genome_group_c1'
		}
	);

	if($group_result && $group_result->in_storage) {
		# Found duplicate group
		get_logger->error("Genome group name collion. Group with name $group_name already exists");
		return 0;
	}

	# Perform group creation in single DBIx::Class create call so that it is
	# executed in single transaction

	# Note: because category_id is a 'belongs_to' relationship, this will
	# perform a find_or_create call on the group_category entry
	$group->{category} = {
		name => $category_name,
		username => $username,
		standard => 0
	};

	# Genome_group properties
	$group->{standard} = 0;
	$group->{standard_value} = undef;
	$group->{description} = $group_description if $group_description;

	# Genome-group links
	my ($public_genome_ids, $private_genome_ids) = $warden->featureList;
	
	# Public
	my @feature_group_rows;
	foreach my $g (@$public_genome_ids) {
		push @feature_group_rows, { feature_id => $g };
	}
	$group->{feature_groups} = \@feature_group_rows if @feature_group_rows;

	# Private
	my @private_feature_group_rows;
	foreach my $g (@$private_genome_ids) {
		push @private_feature_group_rows, { feature_id => $g };
	}
	$group->{private_feature_groups} = \@private_feature_group_rows if @private_feature_group_rows;

	# Trying to create empty group
	unless(@private_feature_group_rows || @feature_group_rows) {
		get_logger->error('Attempt to create empty group');
		return 0;
	}

	# Insert into database
	my $group_row = $self->dbixSchema->resultset('GenomeGroup')->create($group);

	# Success?
	if($group_row && $group_row->in_storage) {
		return $group_row->genome_group_id;
	} else {
		return 0;
	}
}


=head2 updateGroupProperties

Modify existing custom strain group properties. If
group category changed, and other groups also part
of group category, a new group category will be created
otherwise it will be renamed in the DB.

Input:
2) Param hash-ref:
[Required]
  username    => text 
  group_id    => int
[Optional]
  name        => text
  description => text 
  collection  => text

Returns:
  1 on success, or 0 on failure

=cut

sub updateGroupProperties {
	my $self = shift;
	my $params = shift; # Input params hash-ref

	# Required parameters
	my $group_id = $params->{group_id} or croak "Error: missing input parameter 'group_id'";
	my $username = $params->{username} or croak "Error: missing input parameter 'username'";
	
	# Optional parameters to update for group
	my $group_description = $params->{description};
	my $group_name = $params->{name};
	my $category_name = $params->{category};

	# Locate existing group data
	my $group_row = $self->dbixSchema->resultset('GenomeGroup')->find(
		{
			'me.username' => $username,
			'me.genome_group_id' => $group_id
		}, 
		{
			prefetch => [qw/category/]
		}
	);

	unless($group_row && $group_row->in_storage) {
		get_logger->error("Genome group $group_id for user $username does not exist");
		return 0;
	}

	my $guard = $self->dbixSchema->txn_scope_guard;

	my $update_group;
	my $category_id;

	get_logger->debug("Old category: ".$group_row->category->name.", New category: $category_name") if $category_name;

	if($category_name && $category_name ne $group_row->category->name) {
		# Update group category, 
		# May require creation of new category
		# when other groups also part of this category

		$category_id = $group_row->category_id;
		my $category_row = $self->dbixSchema->resultset('GroupCategory')->find($category_id, { prefetch => 'genome_groups' });

		if($category_row->genome_groups->count() > 1) {
			# Multiple groups in category
			# Create or find new category with desired name
			my $new_category_row = $self->dbixSchema->resultset('GroupCategory')->find_or_create(
				{
					name => $category_name,
					username => $username,
					standard => 0
				},
				{
					key => 'group_category_c1'
				}
			);

			$update_group->{category_id} = $new_category_row->group_category_id;
			$category_id = $update_group->{category_id};

			get_logger->debug('Multiple groups in category, Found or created new category '.$new_category_row->group_category_id);

		} else {
			# Only one group in this category.
			# Either update this category name
			# or switch to existing category and delete this category
			my $other_category_row = $self->dbixSchema->resultset('GroupCategory')->find(
				{
					name => $category_name,
					username => $username,
					standard => 0
				},
				{
					key => 'group_category_c1'
				}
			);

			if($other_category_row && $other_category_row->in_storage) {
				$update_group->{category_id} = $other_category_row->group_category_id;
				$category_id = $update_group->{category_id};
				$category_row->delete;
				get_logger->debug('Single group in category but another category exists with name. Delete category '.
					$category_row->group_category_id . ' and set category to ' . $other_category_row->group_category_id);
			} else {
				$category_row->update({'name' => $category_name});
				get_logger->debug('Single group in category ' .
					$category_row->group_category_id . 
					', update category name to '.$category_name);
			}
			
		}

	}

	# Change description
	$update_group->{description} = $group_description if $group_description;

	# Change name if it doesnt result in name collision
	if($group_name && $group_name ne $group_row->name) {
		my $other_group_row = $self->dbixSchema->resultset('GenomeGroup')->find(
			{
				name => $group_name,
				username => $username
			},
			{
				key => 'genome_group_c1'
			}
		);

		if($other_group_row && $other_group_row->in_storage) {
			get_logger->error("Genome group name collion. Group with name $group_name already exists");
			return 0;
		}
		else {
			$update_group->{name} = $group_name
		}
	}

	$group_row->update($update_group) if $update_group && %$update_group;

	$guard->commit;

	# Success
	return 1;
}

=head2 updateGroupMembers

Modify the genomes in existing custom strain group. Method
performs both 'Save' & 'Delete' functions. Deletion will
cascade to group category if its only group in category.


Input:
1) GenomeWarden object (loaded with genomes in group) | undef (for delete)
2) Param hash-ref:
[Required]
  username    => text 
  group_id    => int


Returns:
  1 on success, or 0 on failure

=cut

sub updateGroupMembers {
	my $self = shift;
	my $warden = shift; # GenomeWarden object
	my $params = shift; # Input params hash-ref

	# Required parameters
	my $group_id = $params->{group_id} or croak "Error: missing input parameter 'group_id'";
	my $username = $params->{username} or croak "Error: missing input parameter 'username'";
	

	# Locate existing members of group
	my $group_row = $self->dbixSchema->resultset('GenomeGroup')->find(
		{
			'me.username' => $username,
			'me.genome_group_id' => $group_id
		}, 
		{
			prefetch => [qw/feature_groups private_feature_groups category/]
		}
	);

	unless($group_row && $group_row->in_storage) {
		get_logger->error("Genome group $group_id for user $username does not exist");
		return 0;
	}

	# Collection
	my $category_id = $group_row->category_id;
	
	# Identify genomes slated for removal and addition to group
	my @public_additions;
	my @private_additions;
	my %already_in_group;
	
	# The following steps need to be done in a single transaction
	my $guard = $self->dbixSchema->txn_scope_guard;

	my $genome_group = $warden ? $warden->genomeLookup() : { };

	my $public_feature_rs = $group_row->feature_groups;
	while(my $f = $public_feature_rs->next) {
		my $k = 'public_'.$f->feature_id;

		if(defined $genome_group->{$k}) {
			$already_in_group{$k} = $f->feature_id;
		} else {
			$f->delete;
			get_logger->debug("Deleting feature-group link $group_id - $k");
		}
	}

	my $private_feature_rs = $group_row->private_feature_groups;
	while(my $f = $private_feature_rs->next) {
		my $k = 'private_'.$f->feature_id;

		if(defined $genome_group->{$k}) {
			$already_in_group{$k} = $f->feature_id;
		} else {
			$f->delete;
			get_logger->debug("Deleting feature-group link $group_id - $k");
		}
	}

	foreach my $g (keys %$genome_group) {
		unless($already_in_group{$g}) {
			if($g =~ m/^public_/) {
				push @public_additions, [ $group_id, $genome_group->{$g}->{feature_id} ];
			} else {
				push @private_additions, [ $group_id, $genome_group->{$g}->{feature_id} ];
			}
		}
	}

	get_logger->debug("Adding public genomes to group $group_id: ".join(', ', map {$_->[1]} @public_additions));
	get_logger->debug("Adding private genomes to group $group_id: ".join(', ', map {$_->[1]} @private_additions));
	get_logger->debug("Genomes in group $group_id that will remain unchanged: ".join(', ', keys %already_in_group));

	if(@public_additions) {
		unshift @public_additions, [qw/genome_group_id feature_id/];
		$self->dbixSchema->resultset('FeatureGroup')->populate(\@public_additions);
	}
	
	if(@private_additions) {
		unshift @private_additions, [qw/genome_group_id feature_id/];
		$self->dbixSchema->resultset('PrivateFeatureGroup')->populate(\@private_additions);
	}
	
	unless($warden) {
		# Delete group
		$group_row->delete;

		my $category_row = $self->dbixSchema->resultset('GroupCategory')->find($category_id, { prefetch => 'genome_groups' });

		unless($category_row->genome_groups->count()) {
			# Category empty, delete category
			$category_row->delete;
		}

	}

	$guard->commit;

	# Success
	return 1;
}


=head2 updateCollectionProperties

Change collection name.



Returns:
  1 on success, or 0 on failure

=cut

sub updateCollectionProperties {
	my $self = shift;
	my $username = shift;
	my $collection_name = shift;
	my $new_collection_name = shift;

	# Required parameters
	croak "Error: missing input parameter 'new group_category_name'" unless $new_collection_name;
	croak "Error: missing input parameter 'group_category_name'" unless $collection_name;
	croak "Error: missing input parameter 'username'" unless $username;

	my $category_row = $self->dbixSchema->resultset('GroupCategory')->find({

	});

	return 0 unless $category_row;

	return 0 unless $category_row->username eq $username;

	$category_row->update( { name => $collection_name } );

	return 1;
}

1;