#!/usr/bin/env perl

=pod

=head1 NAME

Meta::Loader.pm

=head1 DESCRIPTION

Loads parsed meta-data from Miner.pm into the DB. Identifies conflicts between data being loaded
and data already in the DB.

structure of sample json and db data fetch

sample json

'accession':
	'attribute 1'=>''
	'attribute 2'=>''

Data fetch from db

'accession'
	'feature_id'=>Y
	'attribute' => [
					name=>'value',
					rank=>'a number ranking this value for the attribute'
					]



=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

$| = 1;

package Meta::Loader;

use strict;
use warnings;
use List::Util qw(any);
use Log::Log4perl qw(:easy);
use JSON::MaybeXS qw(encode_json decode_json);
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/../';
use Role::Tiny::With;
with 'Roles::DatabaseConnector';
use Data::Dumper;
use Data::Compare;
use Geo::Coder::Google::V3;


# Initialize a basic logger
Log::Log4perl->easy_init($DEBUG);


=head2 new

Constructor

=cut

sub new {
	my $class = shift;
	my %arg   = @_;

	my $self  = bless {}, ref($class) || $class;

	# Connect to database
	if($arg{schema}) {
		# Use existing DBIx::Class::Schema connection
		$self->setDbix($arg{schema});

	}
	elsif($arg{dbh}) {
		# Use existing DBI database handle
		$self->connectDatabase( dbh => $arg{dbh} );

	}
	elsif($arg{config}) {
		# Parse connection parameters from config file
		$self->connectDatabaseConf( $arg{config} );
	}
	else {
		# Establish new DB connection using command-line args
		$self->connectDatabaseCL();
	}


	# # Meta-data terms
	 $self->{meta_data_terms} = {
	 	isolation_host => 1,
	 	isolation_source => 1,
	 	isolation_location => 1, 
	 	syndrome => 1,
	 	isolation_date => 1,
	 	serotype => 1,
	 	strain => 1
	 };

	# Record conflicts between new and db data
	$self->{conflicts} = [];

	return $self;
}


=head2 db_metadata

Retrieve featureprops/meta-data for all public genomes in DB

=cut

sub db_metadata {
	my $self = shift;
	my $sampleJson = shift;
	

	# Need to map featureprop values to IDs in host, source & syndrome
	my %hosts;
	my %sources;
	my %syndromes;
	my %categories;
	my %locations = {};
	my %genomeLocation = {};

	# Hosts
	my $host_rs = $self->dbixSchema->resultset('Host')->search();
	while(my $host_row = $host_rs->next) {
		$hosts{$host_row->host_id} = {
			category => $host_row->host_category_id,
			id => $host_row->host_id,
			uniquename => $host_row->uniquename,
			displayname => $host_row->displayname
		};

		$categories{$host_row->displayname} = $host_row->host_category_id;
	}

	$self->{hosts} = \%hosts;
	$self->{categories} = \%categories;

	# Sources
	my $source_rs = $self->dbixSchema->resultset('Source')->search();
	while(my $source_row = $source_rs->next) {
		$sources{$source_row->source_id} = {
			id => $source_row->source_id,
			category => $source_row->host_category_id,
			meta_term => 'isolation_source',
			uniquename =>  $source_row->uniquename,
			displayname => $source_row->displayname
		} 
	}

	$self->{sources} = \%sources;

	# Syndromes
	my $synd_rs = $self->dbixSchema->resultset('Syndrome')->search();
	while(my $synd_row = $synd_rs->next) {
		$syndromes{$synd_row->syndrome_id} = {
			id => $synd_row->syndrome_id,
			category => $synd_row->host_category_id,
			meta_term => 'syndrome',
			uniquename =>  $synd_row->uniquename,
			displayname => $synd_row->displayname
		}
	}

	$self->{syndromes} = \%syndromes;

	# locations
	my $location_string = "SELECT * FROM geocoded_location";
	my $preparedSQL = $self->dbh->prepare($location_string);
	$preparedSQL->execute();

	#id = simply the id of the geocoded location
	#location = simply the json string with a detailed location
	#search_query = this is the search term
	my @location_row  = [];
	while(@location_row = $preparedSQL->fetchrow_array) {
		%locations->{$location_row[0]} = {
			id => $location_row[0],
			location_json => $location_row[1],
			meta_term => 'isolation_location',
			search_query =>  $location_row[2]
		}
	}

	$self->{location} = \%locations;


	# genome Locations
	$location_string = "SELECT * FROM genome_location";
	$preparedSQL = $self->dbh->prepare($location_string);
	$preparedSQL->execute();

	#geocoded_location_id = simply the id of the geocoded location
	#feature_id = simply the json string with a detailed location

	while(my @location_row = $preparedSQL->fetchrow_array) {
		$genomeLocation{$location_row[1]} = {
			geocoded_location_id => $location_row[0],
			feature_id => $location_row[1]
		}
	}

	$self->{genomeLocation} = \%genomeLocation;


	#get all of the accessions 
	my @accessions = keys $sampleJson;
	
	#get all of the meta we want to find
	my $metas = "('";
	foreach my $meta (keys $self->{meta_data_terms}){
		if($self->{meta_data_terms}->{$meta} eq 1){$metas = $metas.$meta."','";}
	}

	chop($metas);
	chop($metas);
	$metas = $metas.")";

	my %featureprops;
	my $count =0;
	my $feature_id;
	foreach my $g_acc (@accessions){

		my $getAllAttributes = "SELECT feature.feature_id, dbxref.accession, cvterm.name, featureprop.value, rank FROM featureprop
			JOIN cvterm ON (featureprop.type_id = cvterm.cvterm_id) 
			JOIN feature ON (feature.feature_id = featureprop.feature_id) 
			JOIN dbxref ON (dbxref.dbxref_id = feature.dbxref_id) 
			WHERE feature.type_id = (select cvterm_id from cvterm where cvterm.name=\'contig_collection\') AND dbxref.accession=\'".$g_acc."\' AND cvterm.name IN ".$metas.";";

		$preparedSQL = $self->dbh->prepare($getAllAttributes);
		$preparedSQL->execute();

		while(my @f_row = $preparedSQL->fetchrow_array){

			if(ref($featureprops{$g_acc}->{$f_row[2]}) ne 'ARRAY'){
				$featureprops{$g_acc}->{$f_row[2]} = [];
			}
			push $featureprops{$g_acc}->{$f_row[2]}, {name =>$f_row[3], rank =>$f_row[4]};
			$featureprops{$g_acc}->{feature_id} = $f_row[0];
		}
	}

=pot
	my $f_rs = $self->dbixSchema->resultset('Feature')->search(
		{'type.name'=>'contig_collection'},
		{
			join => ['dbxref', { 'featureprops' => 'type' }, 'type'],
			columns => [qw/feature_id/],
			'+columns' => {
				'featureprops.type.name' => 'type.name',
				'dbxref.accession' => 'dbxref.accession',
				'featureprops.value' => 'featureprops.value',
				'featureprops.rank' => 'featureprops.rank',
			}
		}
	);


	# Populate all of the info for the accessions that were collected in the samples only

	my %featureprops;
	while(my $f_row = $f_rs->next) {
		my $g_acc = $f_row->dbxref->accession;

		$featureprops{$g_acc} = { feature_id => $f_row->feature_id } unless defined $featureprops{$g_acc};

		my $fp = $featureprops{$g_acc};
		
		while(my $fp_row = $f_row->featureprops) {
			my $cvterm = $fp_row->type->name;
			my $value = $fp_row->value;
			my $rank = $fp_row->rank;

			if($self->{meta_data_terms}->{$cvterm}) {
				$fp->{$cvterm} = [] unless $fp->{$cvterm};

				$fp->{$cvterm}->[$rank] = $value;
			}
		}
	}
=cut

	$self->{featureprops} = \%featureprops;
}

=head2 new_metadata

Compare input data with DB data. Identify new 
meta-data entries that need to be uploaded.

=cut

sub new_metadata {
	
	my $self = shift;
	my $input_hashref = shift;

	# Iterate through genomes
	foreach my $gacc (keys $self->{featureprops}) {

		my $new_metadata = $input_hashref->{$gacc};
		my $db_metadata = $self->{featureprops}->{$gacc};
		my $feature_id = $self->{featureprops}->{$gacc}->{feature_id};
		die "Error: genome with accession $gacc not found in database" unless $db_metadata;
		get_logger->info("Genome ".$gacc);

		# Check each meta-data term if an array, try to push content on top of array

		# Host
		my $host_category_id = $self->_compare_host($gacc, $feature_id, $db_metadata, $new_metadata);
		my $sources = $self->_compare_source($gacc, $feature_id, $db_metadata, $new_metadata, $host_category_id);
		my $strain = $self->_compare_strain($gacc, $feature_id, $db_metadata, $new_metadata);
		my $date = $self->_compare_date($gacc, $feature_id, $db_metadata, $new_metadata);
		my $syndrome = $self->_compare_syndrome($gacc, $feature_id, $db_metadata, $new_metadata);
		my $location = $self->_compare_location($gacc, $feature_id, $db_metadata, $new_metadata);
		# Source / syndrome
		
	}
	print @{$self->{inserts}}." new elements were added to the db";

}


sub _compare_host {
	my $self = shift;

	#for some reason, using shift would not take tha value from the call
	my @temp = @_;

	my $genome_id = $temp[0];
	my $feature_id = $temp[1];
	my $db_host = $temp[2];
	my $new_host = $temp[3];

	my $host_category_id;
	
	#see if there exists an isolation host in the sample page
	if($new_host->{isolation_host}) {
		
		# There should only be one host
		if(@{$new_host->{isolation_host}} > 1) {
			print Dumper($new_host->{isolation_host});
			die "Error: multiple hosts in input data for genome $genome_id.";
			
		}

		# Convert new value to final form
		my $new_id = $new_host->{isolation_host}->[0]->{id};
		my $new_value;

		#the ids come from the miner analysis, if there is a 0 this means that this host does not exist yet
		if($new_id) {
			# Standard host found in hosts table
			my $standard_host = $self->{hosts}->{$new_id};
			die "Error: No standard host found with ID $new_id for genome $genome_id." unless $standard_host;
			$new_value = $standard_host->{displayname};
		}
		else {
			# Non-standard host
			$new_value = $new_host->{isolation_host}->[0]->{name};
			die "Error: 'name' field not defined for 'Other'-type isolation_host entry for genome $genome_id." unless $new_value;
		}
		
		if($db_host->{isolation_host}) {
			# Host also in db

			# Compare values
			my $db_value = $db_host->{isolation_host}->[0]->{name};
	
			if($new_value ne $db_value) {
				# Conflict
				push @{$self->{conflicts}}, [$genome_id, $feature_id, 'isolation_host', $db_value, $new_value];
			}
			
		} else {

			# Discovered new meta-data host
			my $rank = 0;
			push @{$self->{inserts}}, [ $feature_id, 'isolation_host', $new_value, $rank];
			get_logger->info("\thost $new_value being added for genome $genome_id");

		}

		$host_category_id = $new_host->{isolation_host}->[0]->{category};
		die "Error: 'category' field not defined for isolation_host entry for genome $genome_id." unless $host_category_id;
		
	}
	else {
		
		if($db_host->{isolation_host}->[0]) {
			# Only entry in DB
			my $db_value = $db_host->{isolation_host}->[0];
			$host_category_id = $self->{categories}->{$db_value};
		}

	}
		
	return $host_category_id;

}

sub _compare_source {
	my $self = shift;
	my $genome_id = shift;
	my $feature_id = shift;
	my $db_source = shift;
	my $new_source = shift;
	my $host_category_id = shift;

	if($new_source->{isolation_source}) {
		# There should only be one source
		if(@{$new_source->{isolation_source}} > 1) {
			die "Error: multiple sources in input data for genome $genome_id.";
		}

		# Convert new value to final form
		my %new_potential_values;
		if($host_category_id) {
			# Host category provided, so only need to consider one possible source value
			my $new_value_hashref = $new_source->{isolation_source}->[0]->{$host_category_id};
			die "Error: source is not compatible with host category $host_category_id for genome $genome_id." unless $new_value_hashref;

			my $new_id = $new_value_hashref->{id};
			my $new_value;

			if($new_id) {
				# Standard source found in sources table
				my $standard_source = $self->{sources}->{$new_id};
				die "Error: No standard source found with ID $new_id for genome $genome_id." unless $standard_source;
				$new_value = $standard_source->{displayname};
			}
			else {
				# Non-standard source
				$new_value = $new_value_hashref->{name};
				die "Error: 'name' field not defined for 'Other'-type isolation_source entry for genome $genome_id." unless $new_value;
			}

			$new_potential_values{$new_value} = $new_id || 0;
		}
		else {
			# No host category provided, record variations for different host categories
			my @potential_ids;

			foreach my $potential_value (values %{$new_source->{isolation_source}->[0]}) {
				my $new_id = $potential_value->{id};
				my $new_value;

				if($new_id) {
					# Standard source found in sources table
					my $standard_source = $self->{sources}->{$new_id};
					die "Error: No standard source found with ID $new_id for genome $genome_id." unless $standard_source;
					$new_value = $standard_source->{displayname};
				}
				else {
					# Non-standard source
					$new_value = $potential_value->{name};
					die "Error: 'name' field not defined for 'Other'-type isolation_source entry for genome $genome_id." unless $new_value;
				}

				$new_potential_values{$new_value} = $new_id || 0;
			}
			
		}

		if($db_source->{isolation_source}) {
			# Source also in db

			# Compare values
			my $db_value = $db_source->{isolation_source}->[0];
			my @value_array = sort { $new_potential_values{$a} <=> $new_potential_values{$b} } keys %new_potential_values;
			
			my $found = any { $db_value eq $_ } @value_array;

			unless($found) {
				# Conflict
				push @{$self->{conflicts}}, [$genome_id, $feature_id, 'isolation_source', $db_value->{isolation_source}, $value_array[0]];
			}
			
		}
		else {
			# Discovered new meta-data host
			my @value_array = sort { $new_potential_values{$a} <=> $new_potential_values{$b} } keys %new_potential_values;
			my $new_value = $value_array[0]; 
			# If host category is not resolved, there may be multiple category-specific versions
			# of the same source, pick the one with the lowest ID to go into the DB.
			
			my $rank = 0;
			push @{$self->{inserts}}, [ $feature_id, 'isolation_source', $new_value, $rank];
			get_logger->info("\tsource $new_value being added for genome $genome_id");

		}
	}
}


=head2 _compare_strain
this method will take the Strain's array from the DB and the strain's array from 
the sample pages
This information is then compared to make sure that there are no duplicate
The order of priority and ranking is kept track by means of a highest rank generated from looping through the db array
The sample's ranks are therefore higher(least importance) to the db ranks already in the db 
=cut

sub _compare_strain {
	my $self = shift;
	my $genome_id = shift;
	my $feature_id = shift;
	my $db_value = shift;
	my $new_value = shift;

	my @strains;
	#see if there exists an isolation host in the sample page
	if($new_value->{strain}) {

		#make an array of name and rank

		foreach my $sample (@{$new_value->{strain}}){
			my $tempSampleRank = $sample->{priority} -1;
			my $tempSampleValue = $sample->{displayname};
			push @strains, {rank=>$tempSampleRank, name=>$tempSampleValue};
		}

		my $highestRank = 0;
		foreach my $db_strain (@{$db_value->{strain}}){
			push @strains, $db_strain;
			$highestRank++;
		}
		
		#got through the db info and remove any strain in the sample array
		#build a hash where keys are priority numbers, this will be used to repopulate an ordered array
		my %newOrderedSamples;

		my @names=[];
		foreach my $tempName (@{$db_value->{strain}}){
			push @names, lc $tempName->{name};
		}
		
			for(my $i = 0; $i< @{$new_value->{strain}}; $i++){
				if(lc $new_value->{strain}->[$i]->{value} ~~ @names){
					#we need to drop this value from the sample
					delete $new_value->{strain}->[$i];

				}else{
					#this value will be used and the priority needs to be adjusted
					#we can populate a new list of strains in order of priorirty
					$new_value->{strain}->[$i]->{priority} = $new_value->{strain}->[$i]->{priority}-1;
					if($newOrderedSamples{$new_value->{strain}->[$i]->{priority}})
					{
						if(ref($newOrderedSamples{$new_value->{strain}->[$i]->{priority}}) eq 'ARRAY'){
							#this priority already exists, simply push the value in this key
							push $newOrderedSamples{$new_value->{strain}->[$i]->{priority}}, $new_value->{strain}->[$i];
						}else{
							my $oldValue = $newOrderedSamples{$new_value->{strain}->[$i]->{priority}};
							$newOrderedSamples{$new_value->{strain}->[$i]->{priority}} = [];
							#this priority already exists, simply push the value in this key
							push $newOrderedSamples{$new_value->{strain}->[$i]->{priority}}, $oldValue;
							push $newOrderedSamples{$new_value->{strain}->[$i]->{priority}}, $new_value->{strain}->[$i];
						}
					}else{
						$newOrderedSamples{$new_value->{strain}->[$i]->{priority}} = $new_value->{strain}->[$i];
					}
				}
			}
		

		#populate an ordered list of new strains to be put after the ones currently in the db
		my @tempMaxKey = keys %newOrderedSamples;
		my @finalSampleArray;
		my $startPriority = $highestRank;
		my $max = @tempMaxKey;

		for (my $i = 0; $i < $max; $i++) {
			if($newOrderedSamples{$i} && $newOrderedSamples{$i} ne 'undef'){
				if(ref($newOrderedSamples{$i}) eq 'ARRAY'){
					foreach my $veryTempSample (@{$newOrderedSamples{$i}}){
						$veryTempSample->{rank} = $startPriority;
						push @finalSampleArray, $veryTempSample;
						$startPriority++;
					}
				}else{
					$newOrderedSamples{$i}->{rank} = $startPriority;

					if(($newOrderedSamples{$i}->{value} eq 'PUERTO RICAN')
						|| (lc $newOrderedSamples{$i}->{value} eq 'hvh 214 4-3062198' && 'hvh 214 (4-3062198)'~~@names)
						|| (lc $newOrderedSamples{$i}->{value} eq 'hvh 83 4-2051087' && 'hvh 83 (4-2051087)'~~@names) 
						|| (lc $newOrderedSamples{$i}->{value} eq 'hvh 177 4-2876612' && 'hvh 177 (4-2876612)'~~@names) ){
					}else{
						push @finalSampleArray, $newOrderedSamples{$i};
						$startPriority++;
					}
				}
			}
		}


		#add the the values from the highest rank as base
		foreach my $tempSampleValue (@finalSampleArray){
			if(@finalSampleArray>0){
				push @{$self->{inserts}}, [$genome_id, $feature_id, 'strain', $tempSampleValue->{value}, $tempSampleValue->{rank}];
				get_logger->info("\tStrain $tempSampleValue->{value} being added for genome $genome_id");
			}
		}
		
	}
}

=head2 _compare_date
Check if there is only one date
Check if the dates are the same
If the dates are different, then make sure to insert a conflict flag
If there is no date in the db, insert the sample date
=cut
sub _compare_date{
	
	my $self = shift;
	my $genome_id = shift;
	my $feature_id = shift;
	my $db_value = shift;
	my $new_value = shift;

	#check if the value is in samples
	if($new_value->{isolation_date}){

		if(@{$new_value->{isolation_date}} >1){
			die "Error : There is more than one date in the sample value";
		}

		#check to see if there is a value in the database
		if($db_value->{isolation_date}){
			if(lc $db_value->{isolation_date}->[0]->{name} ne lc $new_value->{isolation_date}->[0]->{displayname}){
				push @{$self->{conflicts}}, [$genome_id, $feature_id, 'isolation_date', $db_value->{isolation_date}, $new_value->{isolation_date}];

			}
			
		}else{
			#there is a new date that can be adde to the db
			push @{$self->{inserts}}, [$genome_id, $feature_id, 'isolation_date', $new_value->{isolation_date}, $new_value->{isolation_date}];
			get_logger->info("\tDate $new_value->{isolation_date}->[0]->{value} being added for genome $genome_id");

		}
	}
}


=head2 Compare Syndromes
Look to see if the syndromes are already in the db, if so, don't do anything, else add an insert for that value
Need to compare both arrays, look at and see if the syndromes are the same
if there is an identical syndrome, then ignore, if the there is a conflict, simply keep the genbank value
=cut

sub _compare_syndrome{

	my $self = shift;
	my $genome_id = shift;
	my $feature_id = shift;
	my $db_value = shift;
	my $new_value = shift;

	my $db_syndromes = $db_value->{syndrome};
	my $sample_syndromes = $new_value->{syndrome}->[0];
	

	if($sample_syndromes){
		if($db_syndromes){
			foreach my $db (@{$db_syndromes}){
				my $name = $db->{name};
				foreach my $sample (keys $sample_syndromes){
					if($sample_syndromes->{$sample}->{displayname} eq $name){
						delete $sample_syndromes->{$sample}->{name};
					}
				}
			}

		}
		#once the duplicates are deleted, addition can continue, based on the highest rank given in the db
		my $highest_rank = 0;
		foreach my $rank (@{$db_syndromes}){
			if($rank->{rank} > $highest_rank){
				$highest_rank = $rank;
			}
		}

		foreach my $new_syndrome (keys $sample_syndromes){
			$highest_rank++;
			push @{$self->{inserts}}, [$feature_id, $genome_id, 'syndrome', $sample_syndromes->{new_syndrome}->{displayname}, $highest_rank];
			get_logger->info("\tSyndrome $sample_syndromes->{$new_syndrome}->{displayname} being added for genome $genome_id");
		}
	}

}

=head2 _compare_location
Needs to take 
 -geocoded_location table, see if there is already a code location for this
 -genome location table, this is where the connection between feature and location is made, make sure to add a a value in that table when 
 -feature table, the normal feature needs to be added.
 -Will add the following information
 	[0] => genome id
 	[1] => feature id
 	[2] => meta value
 	[3] => display name
 	[4] => geocoded id
 this method should add the new values to the geocoded table and the genome location tables

=cut
sub _compare_location{

	my $self = shift;
	my $genome_id = shift;
	my $feature_id = shift;
	my $db_value = shift;
	my $new_value = shift;

	my $sample_location = $new_value->{isolation_location}->[0];


	if($sample_location){

		if($self->{location}->{$self->{genomeLocation}->{$db_value->{feature_id}}->{geocoded_location_id}}){
			
			my $db_location = $self->{location}->{$self->{genomeLocation}->{$db_value->{feature_id}}->{geocoded_location_id}};
			
			#if there is a conflict, update the genome location table and add a location in the geocoded_location, the table to say whether or not to make modification is the last element 
			#of the insertion array
			if($db_location->{search_query} ne $sample_location->{value}){
				push @{$self->{inserts}}, [$feature_id, $genome_id, 'isolation_location', $sample_location->{value}, 'update'];

			}

		}else{
			push @{$self->{inserts}}, [$feature_id, $genome_id, 'isolation_location', $sample_location->{value}, 'insert'];
			print "There was a new location added to the db";
			<>;
		}
	}
}

1;
