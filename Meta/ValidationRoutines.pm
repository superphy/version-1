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

# TODO Nicolas
sub locations {
	my $self = shift;
	my $v = shift;

	
	# Check that v contains a valid location name

	# See guessLocation in Sequences::genbank_to_genodo.pl
	# For examples

	# get the locations
	# Countries
	my %valid_countries;
	map { $valid_countries{$_} = 1 } all_country_names();
	map { if(m/,/) { s/, .+$//; $valid_countries{$_} = 1 } } all_country_names();

	# try to get the country
	my @fields = split /:/, $v;
	foreach my $vv (@fields){
		if(exists($valid_countries{$vv})){
			print $vv." is a valid country\n";
		}else{
			print $vv." is not a valid country\n";
		}
		
	}


	<>;

	my $valid_v = 'TBD';

	# Return value:
	return ('isolation_location', { value => $valid_v, meta_term => 'isolation_location', displayname => $valid_v });
}

# TODO Nicolas
sub serotypes {
	my $self = shift;
	my $v = shift;


	# Check that v contains a valid serotype designation and convert to consistent format

	# There is currently nothing for serotypes
	# You will need to develop from scratch
	# There is sort of is a consistent format for serotypes
	# I will let figure it out
	my $valid_v = 'TBD';

	# Return value:
	return ('serotype', { value => $valid_v, meta_term => 'serotype', displayname => $valid_v });
}

# TODO Nicolas
sub dates {
	my $self = shift;
	my $v = shift;


	# Check that v contains a valid date and convert to consistent format YYYY-MM-DD

	# Perl has libraries for this, see Sequences::GenodoDateTime and collection date parsing
	# in genbank_to_genodo.pl
	# Make sure date is not in the future
	my $valid_v = 'TBD';

	# Return value:
	return ('isolation_date', { value => $valid_v, meta_term => 'isolation_date', displayname => $valid_v });
}

sub host_sources {
	my $self = shift;
	my $v = shift;




	# if(my $v = _exact_match($v, [keys %inputs])) {
	# 	return $inputs{$v};
	# }
	# else {
	# 	return 0;
	# }
}

# Is this a non-value like 'missing'
sub skip_value {
	my $self = shift;
	my $v = shift;

	my @inputs = qr/
		missing
		N\/A
		NA
		None
		not determined
	/;

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
		foreach my $subAtt (@{$att->{@keys[0]}}){
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
				print $counter.". ".@keys[0]."\n";
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
			$metatag = @keys[0];
			push @{$data->{attributes}->[$input]->{@keys[0]}}, $attribute;
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


1;
