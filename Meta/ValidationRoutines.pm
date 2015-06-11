#!/usr/bin/env perl

=pod

=head1 NAME

Meta::ValidationRoutines.pm

=head1 DESCRIPTION

This object contains methods to convert attribute-value pairs to Superphy meta-data terms and standard
values.

This Role object is a container for all the validation_routine methods. It is added as plugin to the
main parsing object.

Validation routine methods have specification:
    Parameters: 
      [0] input string
    Returns:
      False when no match was found
        -or-
      String 'skip' to ignore values like 'NA' or 'missing'
        -or-
      Array containing [0] = meta_data term AND [1] = meta-data hash-ref as follows:
        - when meta_term = 'isolation_host'
          { id => host table ID matching host value,
            meta_term => 'isolation_host',
            category => host_category ID for human, mammal, bird, environment categories,
            displayname => English description of value used in debugging messages
          }
        - when meta_term = 'isolation_source' or 'syndrome'
          { host_category_id => {
               id => source|syndrome table ID matching value,
               meta_term => 'isolation_source'|'syndrome',
               displayname => English description of value used in debugging messages
            },
            ...(for each category that has value matching that source|syndrome)
          }
        - when meta_term = 'isolation_date', 'isolation_location', 'serotype'
          { meta_term = 'isolation_date'|'isolation_location'|'serotype',
            value = string value,
            displayname => English description of value used in debugging messages
          }
        - when meta_term = 'strain'
          { meta_term = 'strain',
            value = string value,
            priority = 1:3,
            displayname => English description of value used in debugging messages
          }

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

package Meta::ValidationRoutines;

use strict;
use warnings;
use Data::Dumper;
use Role::Tiny;
use Locale::Country;
use Geo::Coder::Google::V3;
use JSON;
require '../Sequences/GenodoDateTime.pm';
use Log::Log4perl qw(:easy);


##################
# Utility methods
##################


# If the exact string is found, return success
# case insensitive
sub _exact_match {
	my $v = shift;
	my $patterns = shift;

	my @compiled = map qr/^$_$/i, @$patterns;
	my $success = 0;
	foreach my $pat (@compiled) {
		if($v =~ /$pat/) {
			return 1;
		}
    }
	
	return(0);
}



##################
# Matching methods
##################

# Hosts
sub hosts {
	my $self = shift;
	my $v = shift;

	my %inputs = %{$self->{hosts}};

	if(_exact_match($v, [keys %inputs])) {
		return ('isolation_host', $inputs{$v});
	}
	else {
		return 0;
	}
}

# Sources
sub sources {
	my $self = shift;
	my $v = shift;

	my %inputs = %{$self->{sources}};
	
	if(_exact_match($v, [keys %inputs])) {
		return ('isolation_source', $inputs{$v});
	}
	else {
		return 0;
	}
}

# Syndromes
sub syndromes {
	my $self = shift;
	my $v = shift;

	my %inputs = %{$self->{syndromes}};
	
	if(_exact_match($v, [keys %inputs])) {
		return ('syndrome', $inputs{$v});
	}
	else {
		return 0;
	}
}

# Breakdown complex symptoms / diseases into
# individual syndrome entries
sub multi_syndromes {
	my $self = shift;
	my $v = shift;

	my %inputs = (
		'uti induced bacteremia' => [
			'uti',
			'bacteremia'
		],
		'hc, hus' => [
			'hc',
			'hus'
		]
	);
	
	if(_exact_match($v, [keys %inputs])) {
		return $self->_lookupD($inputs{$v});
		
	}
	else {
		return 0;
	}
}

#Keep a global hash of the data and the google results
#load the google maps country mapping here
my $filename = 'etc/countries.json';
my $json_text = do {
	open(my $json_fh, "<:encoding(UTF-8)", $filename)
	or die("Can't open \$filename\": $!\n");
	local $/;
	<$json_fh>
};
my $json = JSON->new;
my $countryMapping = $json->decode($json_text);

print Dumper($countryMapping);

# TODO Nicolas
sub locations {

	my $self = shift;
	my $v = shift;

	#Use a eval for the google api
	eval{
		#if the country has already been mapped by google, 
		if(exists $countryMapping->{country}->{$v}){
			#this is a one case conditional statement, but in the json this would have a 0 next to it
		}elsif($v eq "denmark: who reference center"){
			return 0;
		#run the google search for the country and put the result in the hash
		}else{
			my $geocoder = Geo::Coder::Google::V3->new(apiver =>3);
			if(my $location = $geocoder->geocode(location => $v)){
				my $locationString = $location->{formatted_address};
				$countryMapping->{country}->{$v} = $locationString;
			}
		}
	};

	#write the things back to file
	my $json = encode_json($countryMapping);
	my $filename = 'etc/countries.json';
	open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
	print $fh $json;
	close $fh;
	#any value that maps to 0, make sure to not include them in location
	if($countryMapping->{country}->{$v} eq "0"){
		return 0;
	}
	my $valid_v = $countryMapping->{country}->{$v};

	# Return value:
	return ('isolation_location', { value => $valid_v, meta_term => 'isolation_location', displayname => $valid_v });
}

#my %serotypes;
# TODO Nicolas
sub serotypes {
	
	# Check that v contains a valid serotype designation and convert to consistent format

	# There is currently nothing for serotypes
	# You will need to develop from scratch
	# There is sort of is a consistent format for serotypes
	# I will let figure it out
	
	#the names will most likely be separated by a semicolon
	#This will be hard coded, there doesn't seem to be that many cases
	my $self = shift;
	my $v = shift;
	my $vOne = "";
	my $vTwo = "";
	my $vThree = "";
	my $valid_v = "";

	# all of the serotype classifications use : to seperate different elements of the notation
	# The first part of the serotype needs to start with an o and be followed by numbers
	my @serotypeElements = split(":", $v);
	if($serotypeElements[0]){

		$vOne = $serotypeElements[0];
		if(index($vOne, "sf") ne -1){
			$vOne =~ s/sf//;
		}
		#search for the odd word
		$vOne =~ s/e. coli //;
		$vOne =~ s/or/ont/;
		$vOne =~ s/ non-typable/nt/;
		
		
		my $firstCharV = substr $vOne, 0,1;
		if((substr $vOne, 0, 1) eq "0"){
			substr $vOne, 0, 1, "o";	
		}elsif((substr $vOne, 0, 1) ne "o"){
			#if the first character is a number, then put the o in front of it
			if($firstCharV =~ /[0-9]/){
				$vOne = "o".$vOne;
			}
		}
		$valid_v = $vOne;

	}

	#the second part of the serotype needs to have a letter and then continue with
	#numbers, here k capsule types will be discarted
	if($serotypeElements[1]){
		$vTwo = $serotypeElements[1];
		my $firstOfTwo = substr $vTwo,0,1;
		$vTwo =~ s/h-/nm/;
		if($vTwo eq ""){
			$vTwo = "nm";
			if($serotypeElements[2]){
				$vThree = $serotypeElements[2];
				$valid_v = $valid_v.":".$vThree;
			}
		} elsif($firstOfTwo eq "k" || $firstOfTwo eq "K"){
				$vTwo = $serotypeElements[2];
			}

		$valid_v = $valid_v.":".$vTwo;

	}



	#%serotypes->{sero}->{$v}=$valid_v;
	#print Dumper(%serotypes);
	#my $valid_v = $vOne.":".$vTwo;
	# Return value:
	return ('serotype', { value => $valid_v, meta_term => 'serotype', displayname => $valid_v });
}
my %dates;
# TODO Nicolas
sub dates {

	my $self = shift;
	my $v = shift;


	# Check that v contains a valid date and convert to consistent format YYYY-MM-DD

	# Perl has libraries for this, see Sequences::GenodoDateTime and collection date parsing
	# in genbank_to_genodo.pl
	# Make sure date is not in the future

	#change the MM/DD/YYYY notation to the MM-DD-YYYY notation
	#if we don't do that the GonodoDateTime will not raise error and will put day anf month = 1
	if($v =~ /\//){
		my @date = split "\/",$v;
		$v = $date[1]."-".$date[0]."-".$date[2];
	}

	my $valid_v = Sequences::GenodoDateTime->parse_datetime($v);

	$valid_v = $valid_v->{local_c}->{day}."-".$valid_v->{local_c}->{month}."-".$valid_v->{local_c}->{year};
	# Return value:
	return ('isolation_date', { value => $valid_v, meta_term => 'isolation_date', displayname => $valid_v });
}


# Is this a non-value like 'missing'
sub skip_value {
	my $self = shift;
	my $v = shift;

	my @inputs = qw/
		missing
		N\/A
		NA
		None
		Unknown
	/;
	push @inputs, "not determined";

	if(_exact_match($v, \@inputs)) {
		return 'skip';
	}
	else {
		return 0;
	}

}

# To simplify the many ways of classifing bacterial strains
# (e.g. strain, substrain, collection, isolate, etc)
# all bacterial strain info is collected under the same meta-data term and the organized
# by relative specificity e.g. strain > substrain > collection > isolate
sub strains_toplevel {
	my $self = shift;
	my $v = shift;

	return _strain_value($v, 1);
}

sub strains_midlevel {
	my $self = shift;
	my $v = shift;

	return _strain_value($v, 2);
}

sub strains_lowlevel {
	my $self = shift;
	my $v = shift;

	return _strain_value($v, 3);
}

sub _strain_value {
	my $v = shift;
	my $p = shift;

	my $n = uc($v);

	return 'strain', { 
		meta_term => 'strain',
        value => $n,
        priority => $p,
        displayname => $n
    };
}


##################
# Attribute Specific methods
##################
sub matchAttribute{
	my $attribute = shift;
	my $value = shift;
	my $filename = '/home/nicolas/Documents/super1/version-1/Data/genomeAttributes.json';
	my $metatag;

	my $json_text = do {
		open(my $json_fh, "<:encoding(UTF-8)", $filename)
		or die("Can't open \$filename\": $!\n");
		local $/;
		<$json_fh>
	};

	my $json = JSON->new;
	my $data = $json->decode($json_text);

	#see if attribute matches and give choices
	my $found = 0;

	foreach my $att (@{$data->{attributes}}){
		my @keys = keys $att;
		foreach my $subAtt (@{$att->{$keys[0]}}){
			if($attribute eq $subAtt){
				$found = 1;
			}
		}
	}

	if($found!=1){
		#if the category could not be found. Simply suggest where it should go and add it to the json file
		my $counter = 0;
		if($found eq 0){
			foreach my $att (@{$data->{attributes}}){
				my @keys = keys $att;
				print $counter.". ".$keys[0]."\n";
				$counter ++;
			}
		}
		print $counter.". New category \n";
		print "Q exit \n";
		my $input = -1;
		my $goodInput =1;

		print "Please enter a number from 0 to ".$counter." to select what best fits the attribute : ".$attribute." => ".$value."\n";
		while ($goodInput) {
			
			$input = <STDIN>;
			chomp $input;

			if ($input eq "Q"){
				return;
			}
			if($input>=0 && $input<=$counter){
				$goodInput = 0;
			}else{
				print "Please enter a number from 0 to ".$counter."\n";
			}
		}

		#see is we need to make a new category or add 
		if($input eq $counter){

			print "\nPlease specify the new attribute name : ";
			$goodInput = 1;
			my $newAttribute = "na";
			while ($goodInput) {
			
				$newAttribute = <STDIN>;
				chomp $newAttribute;
				print "\nAre you sure you want to have a new attribute called ".$newAttribute." (y/n) : ";

				my $inputConfirm = <STDIN>;
				chomp $inputConfirm;
				if($inputConfirm eq "y"){
					$goodInput = 0;
				}else{
					print "\nPlease specify the new attribute name : ";
				}
			}
			#make a new array containing the serotype element
			my @newAttributeArray = ($attribute);
			#put the new array in the $attribute hash key
			my $attArray = {$newAttribute=>\@newAttributeArray};
			#push the hash to the attributes array
			push @{$data->{attributes}}, $attArray;
			$metatag = $newAttribute;
		}else{

			#find the hash and then add the element in the proper array
			my $meta = $data->{attributes}->[$input];
			my @keys = keys $meta;
			$metatag = $keys[0];
			push @{$data->{attributes}->[$input]->{$keys[0]}}, $attribute;
		}
		print Dumper($data);

		

		#write back to file
		open my $fh, ">:encoding(UTF-8)", $filename;
		print $fh encode_json($data);
		close $fh;

	}else{
		#find the corresponding meta tag for the online description in order to insert into db
		$metatag = matchMeta($attribute);
		#print "\xF0\x9F\x8D\xBA  ". $metatag;
	}

	return $metatag;

}


# Label - a weird attribute containing strain and host
sub label_attribute {
	my $self = shift;
	my $v = shift;

	my %inputs = (
		'premature infant gut metagenome' => ['isolation_host', $self->{hosts}->{hsapiens}],
		'etec b2c' => [_strain_value('ETEC B2C', 3)]
	);
	
	if(_exact_match($v, [keys %inputs])) {
		return @{$inputs{$v}};
	}
	else {
		return 0;
	}
}

# host_sources - very specific descriptions used to describe host, source and sometimes disease (e.g stool sample from infant)
sub host_source_syndromes {
	my $self = shift;
	my $v = shift;

	my %inputs = (
		'premature newborn' => {
			host => 'hsapiens'
		},
		'typical hsapiens during the sakai outbreak' => {
			host => 'hsapiens'
		},
		'hsapiens gut' => {
			host => 'hsapiens',
			source => 'intestine',
		},
		'neonatal bacteremia' => {
			category => ['human','mammal','bird'],
			disease => 'bacteremia',
		},
		'necrotizing fasciitis' => {
			other_disease => 'Necrotizing fasciitis',
			category => ['human']
		},
		'biological product envo:02000043' => 'skip',
		'peri-anal swab' => {
			category => ['human','mammal'],
			other_source => 'Perianal'
		},
		'rectal sample' => {
			source => 'intestine'
		},
		'yolk of a one-day-old ggallus with clinical signs of omphalitis' => {
				host => 'ggallus',
				source => 'yolk',
				other_disease => 'Omphalitis'
			},
		'blood sample of individual with bacteremia' => {
				host => 'hsapiens',
				source => 'blood',
				disease => 'bacteremia'
			},
		'africa' => 'skip',
		'peritoneal fluid' => {
			category => ['human','mammal'],
			other_source => 'Peritoneal fluid'
		},
		'transient mastitis' => {
			disease => 'mastitis'
		},
		'culture of e. coli that spent 17 days in space aboard the shenzhou 8 spacecraft' => 'skip',
		'asymptomatic hsapiens' => {
			host => 'hsapiens',
			disease => 'asymptomatic'
		},
		'isolate from a young female with long term asymptomatic bacteriuria abu' => {
			host => 'hsapiens',
			disease => 'bacteriuria'
		},
		'blood culture' => {
			source => 'blood'
		},
		'gelatinous edema on the head and periorbital tissues of a ggallus with swollen head syndrome' => {
			host => 'ggallus',
			other_source => 'gelatinous edema',
			other_disease => 'swollen head syndrome'
		},
		'lesion swab of diarrheal isolate' => {
			disease => 'diarrhea'
		},
		'healthy btaurus feces' => {
			disease => 'asymptomatic',
			host => 'btaurus',
			source => 'feces'
		},
		'btaurus feces' => {
			host => 'btaurus',
			source => 'feces'
		},
		'hsapiens with bloody diarrhea bd' => {
			host => 'hsapiens',
			disease => 'bloody_diarrhea'
		},
		'wound' => {
			other_source => 'wound',
			category => ['human','mammal','bird']
		},
		'urine from hsapiens < 5 years old' => {
			host => 'hsapiens',
			source => 'urine'
		},
		'cerebrospinal fluid of a neonate with meningitis' => {
			source => 'cerebrospinal_fluid',
			disease => 'meningitis'
		},
		'bile' => {
			other_source => 'bile',
			category => ['human','mammal','bird']
		},
		'abscess' => {
			other_source => 'abscess',
			category => ['human','mammal','bird']
		},
		'wound abscess' => => {
			other_source => 'abscess',
			category => ['human','mammal','bird']
		},
		'feces from ggallus' => {
			host => 'ggallus',
			source => 'feces'
		},
		'symptomatic hsapiens' => {
			host => 'hsapiens'
		},
		'bronchoalveolar lava' => {
			other_source => 'Bronchoalveolar lavage',
			category => ['human','mammal','bird']
		},
		'bronchoalveolar lavage' => {
			other_source => 'Bronchoalveolar lavage',
			category => ['human','mammal','bird']
		},
		'swab, abdominal incision' => 'skip',
		'feces from a 45-year old female hsapiens suffering from diarrhea after traveling in tunisia' => {
			host => 'hsapiens',
			disease => 'diarrhea',
			source => 'feces'
		},
		'hsapiens with diarrhea' => {
			host => 'hsapiens',
			disease => 'diarrhea'
		},
		'healthy hsapiens feces samples' => {
			disease => 'asymptomatic',
			host => 'hsapiens',
			source => 'feces'
		},
		'feces from female hsapiens with ehec symptoms bloody diarrhea' => {
			host => 'hsapiens',
			disease => 'bloody_diarrhea',
			source => 'feces'
		},
		'liver of a ggallus with clinical signs of septicemia' => {
			host => 'ggallus',
			source => 'liver',
			disease => 'septicaemia'
		},
		'grown in culture and sent on a short-term space flight' => 'skip',
		'feces of a hsapiens suffering from bloody diarrhea and abdominal pain' => {
			host => 'hsapiens',
			disease => 'bloody_diarrhea',
			source => 'feces'
		},
		'milk from btaurus with bovine mastitis' => {
			source => 'milk',
			host => 'btaurus',
			disease => 'mastitis'
		},
		'persistent mastitis' => {
			disease => 'mastitis'
		},
		'feces from hsapiens with hemolytic uremic syndrome hus' => {
			host => 'hsapiens',
			disease => 'hus',
			source => 'feces'
		},
		'feces from a female hsapiens suffering from hus' => {
			host => 'hsapiens',
			disease => 'hus',
			source => 'feces'
		},
		'spinach bag' => {
			source => 'veggiefood',
			host => 'environment'
		},
		'food' => 'skip',
		'swab, abdomen' => 'skip',
		'aspirate, biliary drain' => 'skip',
		'tracheal aspirate' => 'skip',
		'feces from a 64-year-old woman from hamburg who presented with bloody diarrhea and did not develop hemolytic uremic syndrome hus' => {
			host => 'hsapiens',
			disease => 'bloody_diarrhea',
			source => 'feces'
		},
		'sscrofa neonatal diarrhea' => {
			host => 'sscrofa',
			disease => 'diarrhea',
		},
		'hsapiens with hemolytic uremic syndrome hus' => {
			host => 'hsapiens',
			disease => 'hus',
		},
		'lesion site lung of a dead turkey with colibacillosis' => {
			other_host => 'Meleagris gallopavo (turkey)',
			category => ['bird']
		},
		'milk from healthy btaurus' => {
			source => 'milk',
			host => 'btaurus',
			disease => 'asymptomatic'
		},
		'swab' => 'skip',
		'feces from hsapiens' => {
			host => 'hsapiens',
			source => 'feces'
		},
		'feces from pediatric hsapiens' => {
			host => 'hsapiens',
			source => 'feces'
		},
		'feces of diarrhea hsapiens' => {
			host => 'hsapiens',
			disease => 'diarrhea',
			source => 'feces'
		},
		'feces of individual with bacteremia' => {
			host => 'hsapiens',
			source => 'feces',
			disease => 'bacteremia'
		},
		'feces from male hsapiens with ehec associated symptoms bloody diarrhea' => {
			host => 'hsapiens',
			source => 'feces',
			disease => 'bloody_diarrhea'
		},
		'in lab' => 'skip',
		'clinical' => 'skip',
		'hsapiens intestinal microflora' => {
			host => 'hsapiens',
			source => 'intestine',
		},
		'soil' => {
			host => 'environment',
			source => 'soil'
		},
		'marine sediment' => {
			host => 'environment',
			source => 'marine_sediment'
		},
		'wastewater  treatment plant' => {
			host => 'environment',
			source => 'water'
		},
		'hsapiens rectal sample' => {
			host => 'hsapiens',
			source => 'colon'
		},
		'feces of male sscrofa' => {
			host => 'sscrofa',
			source => 'feces'
		},
		'hsapiens feces' => {
			host => 'hsapiens',
			source => 'feces'
		},
		'enteral feeding tube' => {
			category => ['human'],
			other_source => 'Enteral feeding tube',
		},
		'feces from a deer' => {
			other_host => 'Odocoileus sp. (deer)',
			category => ['mammal'],
			source => 'feces'
		},
		'host, hsapiens intestinal microflora' => {
			source => 'intestine',
			host => 'hsapiens',
		},
		'hsapiens intestinal microflora, host' => {
			source => 'intestine',
			host => 'hsapiens',
		}

	);

	
	if(_exact_match($v, [keys %inputs])) {
		if(ref($inputs{$v}) eq 'HASH') {
			return $self->_lookupHSD(%{$inputs{$v}});
		} else {
			return $inputs{$v};
		}
	}
	else {
		return 0;
	}
}

# Utility method to facilitate value formatting for
# hosts, sources & diseases
sub _lookupHSD {
	my $self = shift;
	my %hsd = @_;

	my ($host, $source, $disease);
	my @cats;

	# Category (not required if host defined)
	if($hsd{category}) {
		foreach my $c (@{$hsd{category}}) {
			my $cat = $self->{categories}->{$c};
			get_logger->logdie("Error: unrecognized category uniquename: ".$hsd{category}) unless $cat;

			push @cats, $cat->{category};
		}
	}
		
	
	# Host
	if($hsd{host}) {
		$host = $self->{hosts}->{$hsd{host}};
		get_logger->logdie("Error: unrecognized host uniquename: ".$hsd{host}) unless $host;
		@cats = ($host->{category});
	}
	elsif($hsd{other_host}) {
		get_logger->logdie("Error: category not defined for 'other' host.") unless @cats;

		my $cat = $cats[0]; # Host should belong to one category

		$host = {
			category => $cat,
			id => undef,
			name => $hsd{other_host},
			meta_term => 'isolation_host',
			displayname =>  $hsd{other_host}
		};
	}

	# Source
	if($hsd{source}) {
		$source = $self->{sources}->{$hsd{source}};
		get_logger->logdie("Error: unrecognized source uniquename: ".$hsd{source}) unless $source;
	}
	elsif($hsd{other_source}) {
		get_logger->logdie("Error: category not defined.") unless @cats;

		foreach my $c (@cats) {
			$source->{$c} = {
				id => undef,
				name => $hsd{other_source},
				meta_term => 'isolation_source',
				displayname =>  $hsd{other_source}
			};
		}
		
	}

	# Disease
	if($hsd{disease}) {
		$disease = $self->{syndromes}->{$hsd{disease}};
		get_logger->logdie("Error: unrecognized syndrome uniquename: ".$hsd{disease}) unless $disease;
	}
	elsif($hsd{other_disease}) {
		get_logger->logdie("Error: category not defined.") unless @cats;

		foreach my $c (@cats) {
			$disease->{$c} = {
				id => undef,
				name => $hsd{other_disease},
				meta_term => 'syndrome',
				displayname =>  $hsd{other_disease}
			};
		}
	}

	my @results;
	if($host) {
		push @results, ['isolation_host', $host];
	}

	if($source) {
		push @results, ['isolation_source', $source];
	}

	if($disease) {
		push @results, ['syndrome', $disease];
	}

	return \@results;

}

# Utility method to facilitate value formatting for diseases
sub _lookupD {
	my $self = shift;
	my $d_arrayref = shift;

	my @results;
	foreach my $dname (@$d_arrayref) {
		my $disease = $self->{syndromes}->{$dname};
		get_logger->logdie("Error: unrecognized syndrome uniquename: ".$dname) unless $disease;
		push @results, ['syndrome', $disease];
	}
	
	return \@results;
}



# environment - set host to environment
# source unclear
sub environment_attribute {
	my $self = shift;
	my $v = shift;

	my %inputs = (
		'terrestial biome' => 'skip',
		'terrestrial biome envo:00000446' => 'skip',
		'hsapiens-associated habitat envo:00009003' => 'skip',
		'host-associated' => 'skip'
	);
	
	if(_exact_match($v, [keys %inputs])) {
		return $inputs{$v};
	}
	else {
		return 0;
	}
}

# ref_biomaterial attribute
# Contains one strain name, but don't want to blindly assign all future values as strains
sub biomaterial_attribute {
	my $self = shift;
	my $v = shift;

	my %inputs = (
		'ATCC 9637' => 1,
	);
	
	if(_exact_match($v, [keys %inputs])) {
		return _strain_value($v, 3);
	}
	else {
		return 0;
	}
}

# host_disease attribute
# Contains one Pathotype name
sub host_disease_attribute {
	my $self = shift;
	my $v = shift;

	my %inputs = (
		'enterohemorrhagic escherichia coli' => 'EHEC',
	);
	
	if(_exact_match($v, [keys %inputs])) {
		return _strain_value($inputs{$v}, 3);
	}
	else {
		return 0;
	}
}


# note - very specific free-form descriptions that can contain any info
sub note_attribute {
	my $self = shift;
	my $v = shift;

	my %inputs = (
		'diagnosis: diarrhea, aepec' => [
			[ 'hsd', 
				{
					syndrome => 'diarrhea'
				}
			],
			[ 'str', ['epec',3] ]
		],
		'mlst st-17; 2006-3008' => [
			[ 'str', ['mlst st-17',3] ],
			[ 'str', ['ATCC 2006-3008',3] ]
		],
		'mlst st-32; edl 931' => [
			[ 'str', ['mlst st-32',3] ],
			[ 'str', ['edl 931',3] ]
		],
		'isolated in the 2011 germany e. coli outbreak'	=> 'skip',
		'isolated in the 1970\'s' => 'skip',
		'mlst st-723; 2000-3039' => [
			[ 'str', ['mlst st-723',3] ],
			[ 'str', ['ATCC 2000-3039',3] ]
		],
		'k1 strain' => [
			[ 'str', ['k1',1] ],
		],
		'escherchia coli k12 mutant' => 'skip',
		'mlst st-16; 2001-3357' => [
			[ 'str', ['mlst st-16',3] ],
			[ 'str', ['ATCC 2001-3357',3] ]
		],
		'mlst st-11; 99-3311' => [
			[ 'str', ['mlst st-11',3] ],
			[ 'str', ['ATCC 99-3311',3] ]
		],
		'mlst st-21; 2003-3014' => [
			[ 'str', ['mlst st-21',3] ],
			[ 'str', ['2003-3014',3] ]
		],
		'mlst st-655; 2002-3211' => [
			[ 'str', ['mlst st-655',3] ],
			[ 'str', ['2002-3211',3] ]
		],
		'strain associated with crohn\'s disease; aiec o83:h1' => {
			[ 'hsd', 
				{
					syndrome => 'crohns'
				}
			],
			[ 'str', ['aiec', 3] ]
		},
		'carbapenem resistance' => 'skip',
		'type strain of escherichia coli h17' =>  [
			[ 'str', ['h17', 1] ],
		],
		'st11' => [
			[ 'str', ['mlst st-11',3] ],
		],
		'enterohemorrhagic' => [
			[ 'str', ['ehec', 3] ]
		],
		'phylogenetic group b1' => 'skip',
		'nalr_deltape2348-2_gyra_ftsk_phihfld-purbdeltanlef' => 'skip',
		'nalr_deltape2348-2_gyra_ftsk_phihfld-purb' => 'skip'
	);
	
	if(_exact_match($v, [keys %inputs])) {

		if(ref($inputs{$v}) eq 'ARRAY') {
			my @results;

			foreach my $lookup (@{$inputs{$v}}) {
				if($lookup->[0] eq 'hsd') {
					push @results,  @{$self->_lookupHSD(%{$lookup->[1]})};
				}
				elsif($lookup->[0] eq 'str') {
					push @results, [ _strain_value(@{$lookup->[1]}) ];
				}
			}

			return \@results;
			
		} else {
			return $inputs{$v};
		}
	}
	else {
		return 0;
	}
}


1;
