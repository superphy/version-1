#!/usr/bin/env perl

=pod

=head1 NAME

Meta::Miner.pm

=head1 DESCRIPTION

Searches attribute JSON files for known attriubte-key pairs and converts it to Superphy
meta-data types.

Any unrecognized attribute or value will be reported.  These must be resolved before
the final report can be generated.

=head1 OPTIONAL ARGUMENTS

The default decision tree JSON file can be overridden with the command-line argument:

  --decision_tree filename

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

$| = 1;

package Meta::Miner;

use strict;
use warnings;
use List::MoreUtils qw(any);
use Log::Log4perl qw(:easy);
use JSON::MaybeXS qw(encode_json decode_json);
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/../';
use Role::Tiny::With;
with 'Roles::DatabaseConnector';
with 'Meta::CleanupRoutines';
with 'Meta::ValidationRoutines';
use LWP::Simple qw(get);

use Data::Dumper;
use XML::Simple qw(:strict);
use File::Slurp qw/read_file/;
use Getopt::Long;
use DateTime qw(ymd);

use Data::Dumper;
use Data::Compare;
use File::Slurp qw/read_file/;
use Geo::Coder::Google::V3;
use Modules::LocationManager;

use utf8;

use Unicode::Normalize;

my $default_decision_tree_file = dirname(__FILE__) . '/etc/biosample_decision_tree.json';

# Initialize a basic logger
Log::Log4perl->easy_init($DEBUG);


=head2 new

Constructor

=cut

sub new {

	my $class = shift;
	my %arg   = @_;

	my $self  = bless {}, ref($class) || $class;

	# Record unknown attributes/values
	$self->{unknowns}->{att} = {};
	$self->{unknowns}->{val} = {};
	

	# Record discarded attributes
	$self->{discarded} = {};


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


	# Load the decision_tree
	# Check for command-line argument that will override default decision tree
	my $decision_tree_json = $self->_load_options();
	
	my $decision_tree;
	eval {
		$decision_tree = decode_json($decision_tree_json)
	};
	if($@) {
		get_logger->logdie("Error: unable to decode decision_tree JSON ($@)");
	}

	my $rs = $self->_valid_decision_tree($decision_tree);
	unless($rs) {
		get_logger->logdie("Error: invalid decision tree hash");
	}
	
	$self->{decisions} = $decision_tree;

	
	# Load existing discrete values for Host, Source and Syndrome
	$self->_retrieve_values;

	# Check if overrides file is valid
	if($self->{overrides_file}) {
		my $overrides_json = read_file( $self->{overrides_file} ) or die "Error: unable to load file ".$self->{overrides_file}." ($!)\n";

		my $overrides;
		eval {
			$overrides = decode_json($overrides_json)
		};
		if($@) {
			get_logger->logdie("Error: unable to decode overrides JSON ($@)");
		}

		my $rs = $self->_valid_overrides($overrides);
		unless($rs) {
			get_logger->logdie("Error: invalid overrides hash");
		}

		$self->{custom_overrides} = $overrides;
	}

	# Default validation routines applied to all attributes
	$self->{default_validation_routines} = [qw/skip_value/];

	# Default cleanup routines applied to all attributes
	$self->{default_cleanup_routines} = [qw/basic_formatting/];

	#Keep a global hash of the data and the google results for the locations
	my $filename = dirname(__FILE__) .'/etc/countries.json';
	my $json_text = read_file($filename);
	my $json = JSON->new;
	$self->{countries} = $json->decode($json_text);

	#make a hash to store all of the results
	$self->{results} = {};
	$self->{post_results} = {};
	return $self;
}

=head2 _load_options

Searches arguments for decision tree file and overrides file

=cut

sub _load_options {
	my $self = shift;

	Getopt::Long::Configure("pass_through");

	my %opts;
	GetOptions(\%opts, 'decision_tree=s', 'overrides=s') or
		die "Error: GetOptions() failed for Miner options ($!)";

	my $decision_tree_file;

	if(defined($opts{decision_tree})) {
		# Decision tree defined on command-line, this will override default
		$decision_tree_file = $opts{decision_tree}
	}
	else {
		$decision_tree_file = $default_decision_tree_file;

	}

	if(defined($opts{overrides})) {
		# Overrides JSON file
		$self->{overrides_file} = $opts{overrides}
	}
	
	Getopt::Long::Configure("no_pass_through"); # Reset Getopt::Long config

	get_logger->warn("Using decision tree file: $decision_tree_file");
	my $decision_tree_json = read_file( $decision_tree_file ) or die "Error: unable to load file $decision_tree_file ($!)\n";

	return $decision_tree_json;
}

=head2 _valid_decision_tree

Checks decision_tree hash for parsing
attributes is valid

=cut

sub _valid_decision_tree {

	my $self = shift;
	my $decision_tree_hashref = shift;

	foreach my $att (keys %$decision_tree_hashref) {

		my $att_hashref = $decision_tree_hashref->{$att};
		
		my @keep_keys = qw(cleanup_routines validation_routines);

		if($att_hashref->{keep}) {

			# This is an attribute that will be used, check for needed info
			if( any { !defined($att_hashref->{$_}) } @keep_keys) {
				get_logger->warn("Invalid decision tree format: attribute $att missing required info.");
				return 0;
			}

			# Check that the cleanup and validation routines are defined
			foreach my $method_list (qw/cleanup_routines validation_routines/) {

				unless(ref($att_hashref->{$method_list}) eq 'ARRAY') {
					get_logger->warn("Invalid decision tree format: attribute $att $method_list should be an array-reference.");
					return 0;
				}

				foreach my $method (@{$att_hashref->{$method_list}}) {
					unless($self->can($method)) {
						get_logger->warn("Invalid decision tree format: attribute $att method $method in $method_list is not recognized.");
						return 0;
					}
				}
			}

		} else {
			# This is an attribute that will not be used, should be empty
			if( any { defined($att_hashref->{$_}) } @keep_keys) {
				get_logger->warn("Invalid decision tree format: discarded attribute $att should be empty.");
				return 0;
			}
		}

	}

	return 1;

}

=head2 _retrieve_values

Retrieve host, source and syndrome values from database

=cut
sub _retrieve_values {

	my $self = shift;

	my %hosts;
	my %sources;
	my %syndromes;
	my %categories;

	# Hosts
	my $host_rs = $self->dbixSchema->resultset('Host')->search();
	while(my $host_row = $host_rs->next) {
		$hosts{$host_row->uniquename} = {
			category => $host_row->host_category_id,
			id => $host_row->host_id,
			meta_term => 'isolation_host',
			displayname =>  $host_row->displayname
		}
	}

	# Sources
	my $source_rs = $self->dbixSchema->resultset('Source')->search();
	while(my $source_row = $source_rs->next) {
		# Manage multiple names for stool in different categories
		my $uname = $source_row->uniquename;
		$uname = 'feces' if $uname eq 'stool';
		$sources{$uname}{$source_row->host_category_id} = {
			id => $source_row->source_id,
			meta_term => 'isolation_source',
			displayname =>  $source_row->displayname
		} 
	}

	# Syndromes
	my $synd_rs = $self->dbixSchema->resultset('Syndrome')->search();
	while(my $synd_row = $synd_rs->next) {
		$syndromes{$synd_row->uniquename}{$synd_row->host_category_id} = {
			id => $synd_row->syndrome_id,
			meta_term => 'syndrome',
			displayname =>  $synd_row->displayname
		}
	}

	# Categories
	my $hc_rs = $self->dbixSchema->resultset('HostCategory')->search();
	while(my $hc_row = $hc_rs->next) {
		$categories{$hc_row->uniquename} = {
			category => $hc_row->host_category_id,
			displayname =>  $hc_row->displayname
		}
	}

	$self->{hosts} = \%hosts;
	$self->{syndromes} = \%syndromes;
	$self->{sources} = \%sources;
	$self->{categories} = \%categories;
	
}

sub retrieve_ncbi_accessions {
	my $self = shift;

	$self->{accessions} = [];
	my $getAccession = "select accession from dbxref where db_id = 5";
	my $preparedSQL = $self->dbh->prepare($getAccession);
	$preparedSQL->execute();

	while(my @f_row = $preparedSQL->fetchrow_array){
		push @{$self->{accessions}}, $f_row[0];
	}
}

=head2 parse

THIS VERSION DOES NOT WORK WITH ANY INPUT, IT RUNS ON THE 
ACCESSIONS IN NCBI

Extract Superphy meta-data terms from input attribute json string

JSON format:

{
    accession_id:{
        attribute1: [value1]
        attribute2: [value2]
        ...
    },
    accession_id2: {
        attribute1: [value1,value3]
        attribute2: [value2]
        ...
    },
    ...
    
}

=cut

sub parse {
	my $self = shift;
	my $acc = shift;  # Attribute json string

	# parsing for serotype title
	my $xml = new XML::Simple;
	get_logger->info("\nWorking on $acc");
	my $this_attributes = get_sample_xml($acc);
		
		if($this_attributes eq 0){return 0;}
		

		# Iterate through attribute-value pairs
		foreach my $att (keys %$this_attributes) {
			my $val = $this_attributes->{$att};

			# Skip 'null' values
			next unless defined($val);

			my $decision_tree = $self->{decisions}->{$att};

			# Is this a new attribute?
			unless($decision_tree) {
				unless($self->{unknowns}->{att}->{$att}) {
					$self->{unknowns}->{att}->{$att}->{$val} = 1;
				}
				else {				 
					$self->{unknowns}->{att}->{$att}->{$val}++;
				}
			}
			else {
				# Is this attribute a keeper?
				if($decision_tree->{keep}) {
					# Try to pull out Superphy term and value for this attribute-value pair
					my ($superphy_term, $superphy_value, $flag) = $self->_parse_attribute($decision_tree, $att, $val, $acc);

					unless($superphy_term) {
						# There is no validation match for this attribute-value pair
						
						$self->{unknowns}->{val}->{$att}->{$val} = $superphy_value;
					} else {
						# Matched attribute-value pair to superphy meta-data term

						# Value was a 'non-value' like NA or missing. Skip this term
						next if $superphy_term eq 'skip';
					
						if(ref($superphy_term) eq 'ARRAY') {
							# Multiple meta-data terms matched

							foreach my $set (@{$superphy_term}) {
								my ($sterm, $sval) = @$set; 
								$self->{results}->{$acc}->{$sterm} = [] unless defined($self->{results}->{$acc}->{$sterm});
								push @{$self->{results}->{$acc}->{$sterm}}, $sval;
							}

						}
						else {
							#print "Printing before addition ".Dumper($superphy_value)." \nThe result ".Dumper($self->{results}->{$acc});

							$self->{results}->{$acc}->{$superphy_term} = [] unless defined($self->{results}->{$acc}->{$superphy_term});
							push @{$self->{results}->{$acc}->{$superphy_term}}, $superphy_value;

						}
					}

				} else {
					# Discard this attribute
					# Record values so we can see if something newly
					# added to attribute is now useful

					# Ignore useless values
					
					my $skip = $self->skip_value($val);
				
					unless($skip) {
						unless($self->{discarded}->{$att}) {
							$self->{discarded}->{$att}->{$val} = 1;
						}
						else {				 
							$self->{discarded}->{$att}->{$val}++;
						}
					}
				}
			}
		}

		#look for serotype in title, only if no serotypes were detected by the attribute run
		if(exists ($self->{results}->{$acc}->{serotype}->[0])){
			#do nothing
		} else{
			#try to get the title of the sample and get the serotype
			
			if(-f dirname(__FILE__) .'/../Data/SampleXMLFromGenbank/'.$acc.'.xml'){

				my $sampleFile = read_file(dirname(__FILE__) .'/../Data/SampleXMLFromGenbank/'.$acc.'.xml');
				my $data = $xml->XMLin($sampleFile, KeyAttr =>{}, ForceArray => [] );
				my $title = $data->{BioSample}->{Description}->{Title};
				
				#see if the title contains the sero value
				if($title =~ /:/){
					my @titleP = split " ",$title;
					foreach my $titlePiece (@titleP){

						#get the piece of the title with the colon in it and get the sero value
						if($titlePiece =~ ":" && $titlePiece !~ "Pathogen:"){
						
							#run through validation
							my ($superphy_term, $superphy_value, $flag) = $self->_parse_attribute($self->{decisions}->{serotype}, "serotype", $titlePiece, $acc);
							
							$self->{results}->{$acc}->{serotype} = [] unless defined($self->{results}->{$acc}->{serotype});
							push @{$self->{results}->{$acc}->{serotype}}, $superphy_value;
						}
					}
				}

			}
		}
}

=head2 parse_input


Extract Superphy meta-data terms from input attribute json file

JSON format:

{
    accession_id: {
        attribute1: [value1]
        attribute2: [value2]
        ...
    },
    accession_id2: {
        attribute1: [value1,value3]
        attribute2: [value2]
        ...
    },
    ...
}

=cut

sub parse_input {
	my $self = shift;
	my $input_file = shift;  # Attribute json file

	my $input_json = read_file( $input_file ) or die "Error: unable to load file $input_file ($!)\n";

	my $input_data;
	eval {
		$input_data = decode_json($input_json)
	};
	if($@) {
		get_logger->logdie("Error: unable to decode input JSON ($!)");
	}

	# Iterate through genome blocks
	foreach my $acc ( keys %$input_data ) {
		my $this_attributes = $input_data->{$acc};

		# Iterate through attribute-value pairs
		foreach my $att (keys %$this_attributes) {
			my $val = $this_attributes->{$att};

			# Skip 'null' values
			next unless defined($val);
			next unless $val ne '';

			my $decision_tree = $self->{decisions}->{$att};

			# Is this a new attribute?
			unless($decision_tree) {
				unless($self->{unknowns}->{att}->{$att}) {
					$self->{unknowns}->{att}->{$att}->{$val} = 1;
				}
				else {				 
					$self->{unknowns}->{att}->{$att}->{$val}++;
				}
			}
			else {
				# Is this attribute a keeper?
				if($decision_tree->{keep}) {
					# Try to pull out Superphy term and value for this attribute-value pair
					my ($superphy_term, $superphy_value, $flag) = $self->_parse_attribute($decision_tree, $att, $val, $acc);

					unless($superphy_term) {
						# There is no validation match for this attribute-value pair
						$self->{unknowns}->{val}->{$att}->{$val} = $superphy_value;

					} 
					else {
						# Matched attribute-value pair to superphy meta-data term

						# Value was a 'non-value' like NA or missing. Skip this term
						next if $superphy_term eq 'skip';
				
						if(ref($superphy_term) eq 'ARRAY') {
							# Multiple meta-data terms matched

							foreach my $set (@{$superphy_term}) {
								my ($sterm, $sval) = @$set; 
								$self->{results}->{$acc}->{$sterm} = [] unless defined($self->{results}->{$acc}->{$sterm});
								push @{$self->{results}->{$acc}->{$sterm}}, $sval;
							}

						}
						else {
							# Single meta-data term matched 
					
							$self->{results}->{$acc}->{$superphy_term} = [] unless defined($self->{results}->{$acc}->{$superphy_term});
							push @{$self->{results}->{$acc}->{$superphy_term}}, $superphy_value;

						}
					}

				} 
				else {
					# Discard this attribute
					# Record values so we can see if something newly
					# added to attribute is now useful

					# Ignore useless values
					my $skip = $self->skip_value($val);
			
					unless($skip) {
						unless($self->{discarded}->{$att}) {
							$self->{discarded}->{$att}->{$val} = 1;
						}
						else {				 
							$self->{discarded}->{$att}->{$val}++;
						}
					}
				}
			}
		}
	}
	
}


sub get_sample_xml{

	my $acc = shift;
	my $xmlHash;
	my $xml = new XML::Simple;
	my %finalHash;

	#see if the sample xml is in the ../SampleXMLFromGenbank folder
	if(-f dirname(__FILE__) .'/../Data/SampleXMLFromGenbank/'.$acc.'.xml'){
print "There is a sample file";
		#now get the json with all of the attributes from the xml file
		open my $sample_file, '<', dirname(__FILE__) .'/../Data/SampleXMLFromGenbank/'.$acc.'.xml' or die "Can't open '$acc' for reading: $!";
		$xmlHash = $xml->XMLin($sample_file, KeyAttr =>{}, ForceArray => [] );
print "Made it through the xml parsing";
	
	}else{

		#some genbank files take time to download, having localy speeds things up
		if(-f dirname(__FILE__) .'/../Data/genbank/'.$acc.'.xml'){
			#found accession, do nothing, the file will be read after the if statement		
		}else{

			#download the genbank file and only keep the bioproject and the sample number
			print "Downloading genbank file for accession ".$acc."\n";

			my $downloadedGenbank = get("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=".$acc."&rettype=gb&retmode=xml");
			print "finished downloading ".$acc."\n";

			if($downloadedGenbank){

				#had to find the biosample with the index because it was really slow parsing the whole file			
				my $biosampleStart = index($downloadedGenbank, "<GBXref_dbname>BioSample</GBXref_dbname>");
				my $sample = "";

				if($biosampleStart == -1){
					$sample = "-1";
					print "There is no sample for this accession number\n";
				}else{
					my $preSampleSubstring = substr $downloadedGenbank, $biosampleStart , index ($downloadedGenbank, "</GBXref_id>", $biosampleStart)-$biosampleStart;
					$sample = substr $preSampleSubstring, index($preSampleSubstring,'<GBXref_id>')+length('<GBXref_id>');
				}

				my $outfile = dirname(__FILE__) .'/../Data/genbank/'.$acc.'.xml';
				open(my $out, '>:encoding(UTF-8)', $outfile) or die "Error: unable to write to file $outfile ($!)\n";
				print $out $sample;
				close $out;

			}else{
				return 0;
			}

		}
		
		#read the genbank file to try and get the sample page on ncbi
		my $genbankFileWithSample = read_file( dirname(__FILE__) .'/../Data/genbank/'.$acc.'.xml');
		if($genbankFileWithSample =~ /-1/){
			return 0;
		}else{
			print "Downloading sample file for accession ".$acc." genbank is downloaded \n".'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=biosample&id='.$genbankFileWithSample."\n";
			my $sampleXML = get('http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=biosample&id='.$genbankFileWithSample);
			$sampleXML = NFKD( $sampleXML );
			$sampleXML =~ s/\p{NonspacingMark}//g;
		

			$xmlHash = $xml->XMLin($sampleXML, KeyAttr =>{}, ForceArray => [] );

			my $outfile = dirname(__FILE__) .'/../Data/SampleXMLFromGenbank/'.$acc.'.xml';
			open(my $out, ">$outfile") or die "Error: unable to write to file $outfile ($!)\n";
			print $out $sampleXML;
			close $out;
		}

	}

	#once we have the sample files, we can get the hash of all the attributes in the sample page
	if($xmlHash){

		# get the attributes only
		if(ref($xmlHash->{BioSample}->{Attributes}->{Attribute}) eq 'ARRAY'){
			foreach my $attribute (@{$xmlHash->{BioSample}->{Attributes}->{Attribute}}){
				$finalHash{$attribute->{attribute_name}} = $attribute->{content};
			}
		}else{
			if($xmlHash->{BioSample}->{Attributes}->{Attribute}->{content}){
				$finalHash{$xmlHash->{BioSample}->{Attributes}->{Attribute}->{attribute_name}} = $xmlHash->{BioSample}->{Attributes}->{Attribute}->{content};
			}
			
		}		
	}else{
		print "No hash found";
		%finalHash =  0;
	}

	return \%finalHash;
}


sub finalize {

	my $self = shift;
	
	# Check if there are inconsistencies in the meta-data
	my $ok = $self->_validate_metadata($self->{results});
	unless($ok) {
		get_logger->warn("Inconsistencies were found in the meta-data. Modifications are needed to correct these issues before ".
			'the results can be generated...');

		return 0;
	}

	my $complete = 1;

	# If we have unknowns, these need to be dealt with
	# by adding entries to decision_tree or by adding/modifying
	# cleanup_routines and/or validation_routines
	if(%{$self->{unknowns}->{att}}) {
		get_logger->warn("The following attributes are unrecognized:\tModifications are needed to handle these attributes before ".
			'the results can be generated...');
		foreach my $att (keys %{$self->{unknowns}->{att}}) {
			get_logger->warn("Attribute: $att");
			get_logger->warn("Values:");
			foreach my $val (keys %{$self->{unknowns}->{att}->{$att}}) {
				my $count = $self->{unknowns}->{att}->{$att}->{$val};
				get_logger->warn("\t$val - $count");
			}
		}

		$complete = 0;
	}

	if(%{$self->{unknowns}->{val}}) {
		get_logger->warn("The following values are unrecognized:\tModifications are needed to handle these values before ".
			'the results can be generated...');
		foreach my $att (keys %{$self->{unknowns}->{val}}) {
			foreach my $val (keys %{$self->{unknowns}->{val}->{$att}}) {
				my $clean_value = $self->{unknowns}->{val}->{$att}->{$val};
				get_logger->warn("\t$att: $val - (cleanup value: $clean_value)");
			}
		}

		$complete = 0;
	}

	if($complete) {
		
		# All attribute values were accounted for
		get_logger->info("Mining of meta-data complete.");
		get_logger->info("The following attributes were discarded:");
		my $discarded_found = 0;

		foreach my $att (keys %{$self->{discarded}}) {
			foreach my $val (keys %{$self->{discarded}->{$att}}) {
				my $count = $self->{discarded}->{$att}->{$val};
				get_logger->warn("\t$att: $val - $count");
				$discarded_found = 1;
			}
		}

		unless($discarded_found) {
			get_logger->info("no attributes were discarded.");
		}

		my $json_encoder = JSON::MaybeXS->new(pretty => 1);
		return $json_encoder->encode($self->{post_results});

	} else {
		return 0;
	}
}

=head2 _parse_attribute

Extract Superphy meta-data terms from single attribute-value pair

=cut

sub _parse_attribute {
	my $self = shift;
	my $decision_tree = shift;
	my $att = shift;
	my $val = shift;
	my $accession = shift;
	my $flag = 0;

	# Clean up value
	# This applies consistent formatting and replaces synonyms with the same common term
	# It helps reduce the number of needed checks in the validation_routine

	# Default cleanup routines do things like leading/trailing strip whitespace etc
	my $clean_value = $val;
	foreach my $method_name (@{$self->{default_cleanup_routines}}) {
		(undef, $clean_value) = $self->$method_name($clean_value);
	}

	# Specialized cleanup routines are designed for specific values
	# Stop at first successful routine
	my $clean = 0;
	foreach my $method_name (@{$decision_tree->{cleanup_routines}}) {
		(undef, $clean_value) = $self->$method_name($clean_value);
	}
	
	get_logger->debug("Cleanup routines turned $val into $clean_value");

	# Now find the matching Superphy term & value for this attribute-value pair
	# Default validation routines do things like 'skip' over missing values 
	my ($superphy_term, $superphy_value);
	get_logger->logdie("Error: no validation routines defined for attribute $att.") unless @{$decision_tree->{validation_routines}};

	foreach my $method_name (@{$self->{default_validation_routines}}, @{$decision_tree->{validation_routines}}) {
		
		($superphy_term, $superphy_value) = $self->$method_name($clean_value);
	
		if($superphy_term) {

			if(ref($superphy_term) eq 'ARRAY') {
				
				# Multiple meta-data terms matched for this one value
				my $terms = join(', ', map { $_->[0] } @{$superphy_term});
				get_logger->debug("Validation routines assigned $clean_value to multiple meta-terms: $terms using method $method_name");
	
			}
			else {
				get_logger->debug("Validation routines assigned $clean_value to meta-term $superphy_term using method $method_name");
			}
			# What's the point of this statement?
			if($method_name eq 'host_source_syndromes' && $superphy_term ne 'skip'){$flag=1;}
			last;
		}
	}

	return (0, $clean_value) unless $superphy_term;

	return ($superphy_term, $superphy_value, $flag);
}

=head2 _validate_metadata

After parsing inputs,
verify meta-data for each genome ensuring there are
no conflicting meta-data terms or conflicting host-sources
or host-syndromes (i.e. mastitis in chicken)

=cut

sub _validate_metadata {
	my $self = shift;
	my $meta_hashref = shift;

	my $pass = 1;

	# Apply fixes for known meta-data conflicts
	$self->_overrides($meta_hashref);

	get_logger->info('Meta-data conflicts:');
	
	foreach my $genome (keys %$meta_hashref) {
		# There can only be one host
		my $host = $meta_hashref->{$genome}->{isolation_host};

		my $host_category_id;
		if($host) {

			# Remove duplicates
			$host = _remove_duplicates($host, $genome);

			if(@$host > 1) {
				get_logger->warn("Multiple hosts found for $genome (". join(', ', map { _print_value($_) } @$host ). ")");
				$pass = 0;

			} else {
				#change the current host to the new host removing duplicates
				$self->{post_results}->{$genome}->{isolation_host} = $host->[0];
				$host_category_id = $host->[0]->{category};
			}
		}

		# There can only be one source
		my $source = $meta_hashref->{$genome}->{isolation_source};
		if($source) {
			# Remove duplicates
			$source = _remove_duplicates($source);

			if(@$source > 1) {
				get_logger->warn("Multiple sources found for $genome (". join(', ', map { _print_value($_) } @$source). ")");
				$pass = 0;
			}
			elsif($host_category_id && !defined($source->[0]->{$host_category_id})) {
				get_logger->warn("Unrecognized source for host category $host_category_id in $genome (". join(', ', map { _print_value($_) } @$source). ")");
				$pass = 0;
			}
			else {
				# the results should be changed
				$self->{post_results}->{$genome}->{isolation_source} = $source->[0]->{$host_category_id};
			}
			
		}

		# Syndromes must agree with host category
		my $syndrome = $meta_hashref->{$genome}->{syndrome};
		if($syndrome) {
			# Remove duplicates
			my @ok;
			$syndrome = _remove_duplicates($syndrome);

			foreach my $s (@$syndrome) {
				if($host_category_id && !defined($s->{$host_category_id})) {
					get_logger->warn("Unrecognized syndrome for host category $host_category_id in $genome (". join(', ', map { _print_value($_) } @$syndrome). ")");
					$pass = 0;
				}
				else {
					push @ok, $s->{$host_category_id};
				}
			}
			
			$self->{post_results}->{$genome}->{syndrome} = \@ok if @ok;

		}

		# There can only be one serotype
		my $sero = $meta_hashref->{$genome}->{serotype};
		if($sero) {
			if(@$sero > 1) {
				get_logger->warn("Multiple serotypes found for $genome (". join(', ', map { _print_value($_) } @$sero). ")");
				$pass = 0;
			}
			else {
				$self->{post_results}->{$genome}->{serotype} = $sero->[0];
			}
		}

		# There can only be one isolation date
		my $date = $meta_hashref->{$genome}->{isolation_date};
		if($date) {
			if(@$date > 1) {
				get_logger->warn("Multiple dates found for $genome (". join(', ', map { _print_value($_) } @$date). ")");
				$pass = 0;
			}
			else {
				$self->{post_results}->{$genome}->{isolation_date} = $date->[0];
			}
		}

		# If there are sub-location entries, combine into single isolation_location
		my @locales;
		foreach my $level (qw/country state city/) {
			my $term = "isolation_location_$level";
			if($meta_hashref->{$genome}->{$term}) {
				if(@{$meta_hashref->{$genome}->{$term}} > 1) {
					get_logger->warn("Multiple $level found for $genome (". join(', ', map { _print_value($_) } @{$meta_hashref->{$genome}->{$term}}). ")");
					$pass = 0;
				}
				push @locales, $meta_hashref->{$genome}->{$term}->[0]->{value};
			}
		}

		if(@locales) {
			$meta_hashref->{$genome}->{isolation_location} = [] unless defined $meta_hashref->{$genome}->{isolation_location};
			my $loc_string = join(',', @locales);
			push @{$meta_hashref->{$genome}->{isolation_location}}, { meta_term => 'isolation_location', value => $loc_string, displayname => $loc_string };
		}
		
		# There can only be one isolation location
		my $locations = $meta_hashref->{$genome}->{isolation_location};
		if($locations) {

			$locations = _remove_duplicates($locations);

			if(@$locations > 1) {
				get_logger->warn("Multiple locations found for $genome (". join(', ', map { _print_value($_) } @$locations). ")");
				$pass = 0;
			}
			else {
				$self->{post_results}->{$genome}->{isolation_location} = $locations->[0];
			}
		}



		# There can be many strain descriptions, all strain values must have a priority
		# indicating the relative specificity
		# Remove duplicates
		my $strains = $meta_hashref->{$genome}->{strain};
		if($strains) {
			my %unique_strains;
			foreach my $s (@$strains) {
				unless($s->{priority} && $s->{priority} > 0 && $s->{priority} < 4) {
					get_logger->warn("Strain ".$s->{displayname}." not assigned a priority in $genome");
					$pass = 0;
				}
				if(defined $unique_strains{$s->{value}}) {
					$unique_strains{$s->{value}} = $s if $unique_strains{$s->{value}}->{priority} > $s->{priority};
					get_logger->warn("Duplicate strain descriptions: ".$s->{displayname}." in $genome. Dropping one.");
				}
				$unique_strains{$s->{value}} = $s;
			}

			$self->{post_results}->{$genome}->{strain} = [values %unique_strains];
		}

	}

	if($pass) {
		get_logger->info('none found.');
	}

	return $pass;
}

sub _print_value {
	my $v = shift;

	return Dumper($v);
}

sub _remove_duplicates {
	my $value_arrayref = shift;
	my $accession = shift;
	my @unique;

	foreach my $v (@$value_arrayref) {

		push @unique, $v unless any { Compare($v, $_) } @unique;

	}
	

	return \@unique;
}


=head2 _overrides

Fix conflicting meta-data

=cut

sub _overrides {
	my $self = shift;
	my $meta_hashref = shift;

	# Load custom overrides
	if($self->{custom_overrides}) {
		foreach my $override (@{$self->{custom_overrides}}) {

			# Prepare value
			my $value_hashref;
			if($override->{host_key}) {
				$value_hashref = $self->{hosts}->{$override->{host_key}};
			}
			elsif($override->{source_key}) {
				my $cat_id = $self->{categories}->{$override->{source_key}{category}}->{category};
				my $key = $override->{source_key}{key};
				$value_hashref = { $cat_id => $self->{sources}->{$key}{$cat_id} };
			}
			elsif($override->{syndrome_key}) {
				my $cat_id = $self->{categories}->{$override->{syndrome_key}{category}}->{category};
				my $key = $override->{syndrome_key}{key};
				$value_hashref = { $cat_id => $self->{syndrome}->{$key}{$cat_id} };
			}
			elsif($override->{source_value}) {
				my $cat_id = $self->{categories}->{$override->{source_value}{category}}->{category};
				$override->{source_value}->{meta_term} = 'isolation_source';
				$value_hashref = { $cat_id => $override->{source_value} };
			}
			elsif($override->{syndrome_value}) {
				my $cat_id = $self->{categories}->{$override->{syndrome_value}{category}}->{category};
				$override->{source_value}->{meta_term} = 'syndrome';
				$value_hashref = { $cat_id => $override->{syndrome_value} };
			}
			else {
				$override->{value}->{meta_term} = $override->{meta_term};
				$value_hashref = $override->{value};
			}

			# Apply value
			if(my $entry = $meta_hashref->{$override->{accession}}) {
				$entry->{$override->{meta_term}} = [ $value_hashref ];

				get_logger->debug(sprintf("Override Assignment: accession %s; term %s; value %s;", $override->{accession}, $override->{meta_term}, Dumper($value_hashref)));
			}
		}
	}


	# # Fixes for specific genomes
	# # If this becomes a larger issue
	# # will need to refactor out to mixin class

	# $meta_hashref->{'BA000007'}->{isolation_source} = [
	# 	$self->{sources}->{feces}
	# ];

	# $meta_hashref->{'JNOH00000000'}->{isolation_source} = [
	# 	$self->{sources}->{colon}
	# ];

	# $meta_hashref->{'JNOI00000000'}->{isolation_source} = [
	# 	$self->{sources}->{colon}
	# ];

	# $meta_hashref->{'JNOJ00000000'}->{isolation_source} = [
	# 	$self->{sources}->{colon}
	# ];

	# # There are multiple instances of feces & intestine being listed as
	# # sources, feces trumps intestine
	# my $feces = $self->{sources}->{'feces'};
	# my @feces_mixup_acc = qw/
	# 	JICG00000000
	# 	JDWT00000000
	# 	JICE00000000
	# 	JICD00000000
	# 	AZMA00000000
	# 	JICC00000000
	# 	JICH00000000
	# 	JICI00000000
	# 	JICB00000000
	# 	JICA00000000
	# 	JICF00000000
	# 	JDWQ00000000
	# 	AZLZ00000000
	# /;

	# foreach my $g (@feces_mixup_acc) {
	# 	$meta_hashref->{$g}->{isolation_source} = [
	# 		$feces
	# 	];
	# }

	# # There are multiple instances of peri-anal swab & intestine being listed as
	# # sources, peri > intestine
	# my $p = $self->_lookupHSD(
	# 		category => ['human','mammal'],
	# 		other_source => 'Perianal'
	# );
	# my $peri = $p->[0]->[1];
	# my @peri_mixup_acc = qw/
	# 	JDWS00000000
	# 	JDWU00000000
	# 	JDWR00000000
	# /;

	# foreach my $g (@peri_mixup_acc) {
	# 	$meta_hashref->{$g}->{isolation_source} = [
	# 		$peri
	# 	];
	# }

}

=head2 _valid_overrides

Checks overides hash for resolving meta-data conflicts is valid

=cut

sub _valid_overrides {
	my $self = shift;
	my $overrides_arrayref = shift;

	foreach my $override_block (@$overrides_arrayref) {

		unless($override_block->{accession}) {
			get_logger->warn("Missing accession field in block: ".Dumper($override_block));
			return 0;
		}
		
		unless($override_block->{meta_term}) {
			get_logger->warn("Missing meta_term field in block: ".Dumper($override_block));
			return 0;
		}

		unless($override_block->{meta_term} =~ m/isolation_host|isolation_source|syndrome|isolation_date|serotype|isolation_location/) {
			# Got lazy, there are other valid meta_terms. Add as needed.
			get_logger->warn("Invalid meta_term '".$override_block->{meta_term}."' in block: ".Dumper($override_block));
			return 0;
		}

		if($override_block->{meta_term} eq 'isolation_host') {
			# Host value is either string matching key in hosts hash, or a complete meta-term value
			# with keys: id, category, displayname
			
			if($override_block->{host_key}) {

				if(!defined($self->{hosts}->{$override_block->{host_key}})) {
					get_logger->warn("Unrecognized host_key: ".Dumper($override_block));
					return 0;
				}
			}
			elsif($override_block->{host_value}) {
				my @reqd = qw/id category displayname/;
				foreach my $k (@reqd) {
					unless($override_block->{host_value}{$k}) {
						get_logger->warn("Missing parameter $k in host_value field: ".Dumper($override_block));
						return 0;
					}
				}
				unless($self->{categories}->{$override_block->{host_value}{category}}) {
					get_logger->warn("Unrecognized category in host_value: ".Dumper($override_block));
					return 0;
				}
			}
			else {
				get_logger->warn("Missing host_value field in block: ".Dumper($override_block));
				return 0;
			}

		}
		elsif($override_block->{meta_term} eq 'isolation_source') {
			# Source value is either strings matching key in sources hash, or a complete meta-term value
			# with keys: id, category, displayname
			
			if($override_block->{source_key}) {

				my @reqd = qw/category key/;
				foreach my $k (@reqd) {
					unless($override_block->{source_key}{$k}) {
						get_logger->warn("Missing parameter $k in source_key field: ".Dumper($override_block));
						return 0;
					}
					
				}

				my $cat = $self->{categories}->{$override_block->{source_key}{category}}->{category};
				my $key = $override_block->{source_key}{key};

				if(!defined($self->{sources}{$key}{$cat})) {
					get_logger->warn("Unrecognized source_key: ".Dumper($override_block));
					return 0;
				}
			}
			elsif($override_block->{source_value}) {
				my @reqd = qw/id category displayname/;
				foreach my $k (@reqd) {
					unless($override_block->{source_value}{$k}) {
						get_logger->warn("Missing parameter $k in source_value field: ".Dumper($override_block));
						return 0;
					}
				}
			}
			else {
				get_logger->warn("Missing source_value field in block: ".Dumper($override_block));
				return 0;
			}
		}
		elsif($override_block->{meta_term} eq 'syndrome') {
			# syndrome value is either strings matching key in sources hash, or a complete meta-term value
			# with keys: id, category, displayname
			
			if($override_block->{syndrome_key}) {

				my @reqd = qw/category key/;
				foreach my $k (@reqd) {
					unless($override_block->{syndrome_key}{$k}) {
						get_logger->warn("Missing parameter $k in syndrome_key field: ".Dumper($override_block));
						return 0;
					}
				}

				my $cat = $self->{categories}->{$override_block->{syndrome_key}{category}}->{category};
				my $key = $override_block->{syndrome_key}{key};

				if(!defined($self->{syndromes}{$key}{$cat})) {
					get_logger->warn("Unrecognized syndrome_key: ".Dumper($override_block));
					return 0;
				}
			}
			elsif($override_block->{syndrome_value}) {
				my @reqd = qw/id category displayname/;
				foreach my $k (@reqd) {
					unless($override_block->{syndrome_value}{$k}) {
						get_logger->warn("Missing parameter $k in syndrome_value field: ".Dumper($override_block));
						return 0;
					}
				}
			}
			else {
				get_logger->warn("Missing syndrome_value field in block: ".Dumper($override_block));
				return 0;
			}
		}
		else {
			if($override_block->{value}) {
				my @reqd = qw/value displayname/;
				foreach my $k (@reqd) {
					unless($override_block->{value}{$k}) {
						get_logger->warn("Missing parameter $k in value field: ".Dumper($override_block));
						return 0;
					}
				}
			}
			else {
				get_logger->warn("Missing value field in block: ".Dumper($override_block));
				return 0;
			}
		}
	}

	return 1;

}

# Outputs meta-data in genodo_pipeline.pl format. Note: This
# output does not constitute complete upload input, as it does
# not include the fasta sequence or upload parameters.
# Additional scripts add to this output to produce complete upload
# dataset.
sub convert_to_pipeline_input {
	my $self = shift;
	my %args = @_;

	# Method parameters
	my $output_directory = $args{output_directory};
	get_logger->logdie("Error: missing parameter: output_directory") unless $output_directory;
	my $json_output_file = $args{miner_json_file};
	my $accession2uniquename = $args{acc2name};
	my $accession2strain = $args{acc2strain};

	# Reverse lookup of text names linked to IDs
	my %host_lookup;
	map { $host_lookup{ $self->{hosts}->{$_}->{id} } = $self->{hosts}->{$_}->{displayname} } keys %{$self->{hosts}};

	my %source_lookup;
	foreach my $uniquename (keys %{$self->{sources}}) {
		foreach my $cat (keys %{$self->{sources}->{$uniquename}}) {
			my $id = $self->{sources}->{$uniquename}->{$cat}->{id};
			my $value = $self->{sources}->{$uniquename}->{$cat}->{displayname};
			$source_lookup{ $id } = $value;
		}
	}

	my %syndrome_lookup;
	foreach my $uniquename (keys %{$self->{syndromes}}) {
		foreach my $cat (keys %{$self->{syndromes}->{$uniquename}}) {
			my $id = $self->{syndromes}->{$uniquename}->{$cat}->{id};
			my $value = $self->{syndromes}->{$uniquename}->{$cat}->{displayname};
			$syndrome_lookup{ $id } = $value;
		}
	}

	# Geocoder
	my $locationManager = Modules::LocationManager->new();
	$locationManager->dbixSchema($self->dbixSchema);

	# If output file is not provided, look in $self->{post_results}
	# These are the final results from the mining step
	my $meta_data;

	if($json_output_file) {
		my $final_json = read_file( $json_output_file ) or die "Error: unable to load file $json_output_file ($!)\n";

		eval {
			$meta_data = decode_json($final_json)
		};
		if($@) {
			get_logger->logdie("Error: unable to decode results JSON ($@)");
		}
	}
	else {
		$meta_data = $self->{post_results};

	}

	# Iterate through each meta-data term
	# Converting it the formats used by the DB
	foreach my $genome (keys %$meta_data) {
		my $file = "$output_directory/superphy-$genome-params.txt";

		open(my $out, '>', $file) or get_logger->logdie("Error: cannot write to file $file ($!)");

		my %params;
		
		# Validate uniquename
		if($accession2uniquename) {

			my $pub_rv = $self->dbixSchema->resultset('Feature')->find( { uniquename => $genome } );
			my $pri_rv = $self->dbixSchema->resultset('PrivateFeature')->find( { uniquename => $genome } );
			
			my $exists = defined($pub_rv) || defined($pri_rv);
			get_logger->logdie("Error: genome with uniquename $genome already exists in DB") if $exists;

			$params{uniquename} = $genome 
		}

		# Add accession as strain name
		$params{strain} = [ $genome ] if $accession2strain;

		foreach my $p (keys %{$meta_data->{$genome}}) {
			

			if($p eq 'isolation_host') {
				my $v = $meta_data->{$genome}->{$p};
				if($v->{id}) {
					# Defined host
					$params{isolation_host} = $host_lookup{$v->{id}};
				}
				else {
					# Other host
					$params{isolation_host} = $v->{displayname};
				}
	
			}
			elsif($p eq 'isolation_source') {
				my $v = $meta_data->{$genome}->{$p};

				if($v->{id}) {
					# Defined source
					$params{isolation_source} = $source_lookup{$v->{id}};
				}
				else {
					# Other source
					$params{isolation_source} = $v->{displayname};
				}
			}
			elsif($p eq 'syndrome') {
				$params{'syndrome'} = [];

				foreach my $v (@{$meta_data->{$genome}->{$p}}) {
					if($v->{id}) {
						# Defined syndrome
						push @{$params{syndrome}}, $syndrome_lookup{$v->{id}};
					}
					else {
						# Other syndrome
						push @{$params{syndrome}}, $v->{displayname};
					}
				}

			}
			elsif($p eq 'isolation_date' || $p eq 'serotype') {
				my $v = $meta_data->{$genome}->{$p};
				$params{$p} = $v->{value};

			}
			elsif($p eq 'strain') {
				my @sorted_strains = sort { $a->{priority} <=> $b->{priority} } @{$meta_data->{$genome}->{$p}};

				foreach my $v (@sorted_strains) {
					push @{$params{strain}}, $v->{value};
					
				}

			}
			elsif($p eq 'isolation_location') {
				# Insert record in genome_locations table
				my $v = $meta_data->{$genome}->{$p};
				my $geocode_id = $locationManager->geocode_id($v->{value});

				unless($geocode_id) {
					get_logger->logwarn("Warning: recieved geocode ID $geocode_id. Likely due to unknown location. Skipping.");
					next;
				}

				$params{$p} = $geocode_id;
				
			}
			else {
				die "SHOULD NEVER REACH HERE";
			}
		}

		$out->print(Data::Dumper->Dump([\%params], ['contig_collection_properties']));
		$out->close();

	}

}

1;
