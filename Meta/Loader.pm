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

		my $preparedSQL = $self->dbh->prepare($getAllAttributes);
		$preparedSQL->execute();
		while(my @f_row = $preparedSQL->fetchrow_array){			
			if(ref(%featureprops->{$g_acc}->{$f_row[2]}) ne 'ARRAY'){
				%featureprops->{$g_acc}->{$f_row[2]} = [];
			}
			push %featureprops->{$g_acc}->{$f_row[2]}, {name =>$f_row[3], rank =>$f_row[4]};
			%featureprops->{$g_acc}->{feature_id} = $f_row[0];
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
		#my $host_category_id = $self->_compare_host($gacc, $feature_id, $db_metadata, $new_metadata);
		
		# Source / syndrome
		my $valid_source = $self->_compare_source();
	}
}

sub _compare_source {

}

sub _compare_host2{
	my $self = shift;
	my @content = @_;

	print Dumper(@content);

}

sub _compare_host {
	my $self = shift;
	
	my $genome_id = shift;
	my $feature_id = shift;
	my $db_host = shift;
	my $new_host = shift;
	
	my $host_category_id;
	print $new_host->{isolation_host}; 
	#see if there exists an isolation host in the sample page
	if($new_host->{isolation_host}) {

		# There should only be one host
		if(@{$new_host->{isolation_host}} > 1) {
			die "Error: multiple hosts in input data for genome $genome_id.";
		}

		# Convert new value to final form
		my $new_id = $new_host->{isolation_host}->[0]->{id};
		my $new_value;

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
			my $db_value = $db_host->{isolation_host}->[0];
			
			if($new_value ne $db_value) {
				# Conflict
				push @{$self->{conflicts}}, [$genome_id, $feature_id, 'isolation_host', $db_value, $new_value];
			}
			
		}
		else {
			# Discovered new meta-data host
			my $rank = 0;
			push @{$self->{inserts}}, [ $feature_id, 'isolation_host', $new_value, $rank];
			get_logger->info("\thost $new_value being added for genome $genome_id");

		}

		$host_category_id = $new_host->{isolation_host}->[0]->{category};
		die "Error: 'category' field not defined for isolation_host entry for genome $genome_id." unless $host_category_id;
		<>;
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
				push @{$self->{conflicts}}, [$genome_id, $feature_id, 'isolation_source', $db_value, $value_array[0]];
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

sub _compare_source2 {
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
				push @{$self->{conflicts}}, [$genome_id, $feature_id, 'isolation_source', $db_value, $value_array[0]];
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

1;
