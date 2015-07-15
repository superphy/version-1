#!/usr/bin/env perl

=pod

=head1 NAME

t::miner.t

=head1 SNYNOPSIS

=head1 DESCRIPTION

Tests for Meta::Miner

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use Meta::Miner;
use Test::More;
use Test::Exception;
use Test::DBIx::Class;
use File::Slurp qw/read_file/;
use JSON::MaybeXS qw/decode_json/;
use Data::Dumper;

# Install DB data
fixtures_ok 'miner'
	=> 'Install fixtures from configuration files';

# Load Test decision_tree json
my $decision_tree_file = "$FindBin::Bin/etc/test_decision_tree.json";
my $decision_tree_json = read_file( $decision_tree_file );
ok($decision_tree_json, 'Read decision tree JSON file');

# Initialize Miner object
my $miner;
lives_ok { $miner = Meta::Miner->new(decision_tree_json => $decision_tree_json) } 'Meta::Miner initialized';
BAIL_OUT('Meta::Miner initialization failed') unless $miner;

# Load input file that should work
my $infile = "$FindBin::Bin/etc/test_miner_pass.json";
my $input_json = read_file( $infile );
ok($input_json, 'Read input attribute JSON file: '.$infile);

# Run parser
#ok( my $results_json = $miner->parse($input_json), 'Parse attributes');

#testing all of the cleanup routines

my @animals = qw/human cow pig mouse chicken rabbit horse dog onion goat poop ut intestine/;

my %cleanupMapping = (
	human=>'hsapiens',
	cow=>'btaurus',
	pig=>'sscrofa',
	mouse=>'mmusculus',
	chicken=>'ggallus',
	rabbit=>'ocuniculus',
	horse=>'eferus',
	dog=>'clupus',
	onion=>'acepa',
	goat=>'caegagrus',
	poop=>'feces',
	ut => 'urogenital',
	intestine =>'intestine',


);

#test to see if putting a wrong animal in a fix function returns the same value
foreach my $currentTestFunction (@animals){

	my $input = $currentTestFunction;
	$input = 'feces' if $currentTestFunction eq 'poop';
	$input = 'urogenital_tract' if $currentTestFunction eq 'ut';
	$input = 'gastrointestinal' if $currentTestFunction eq 'intestine';

	my $testFunction = 'fix_'.$currentTestFunction;
	is($miner->$testFunction($input),$cleanupMapping{$currentTestFunction}, "T ".$currentTestFunction." got ".$miner->$testFunction($currentTestFunction));
	

	#loop throught the functions that are wrong for this attribute
	foreach my $wrongTestFunction(@animals){
		my $wrongInput = $wrongTestFunction;
		$wrongInput = 'feces' if $wrongTestFunction eq 'poop';
		$wrongInput = 'urogenital_tract' if $wrongTestFunction eq 'ut';
		$wrongInput = 'gastrointestinal' if $wrongTestFunction eq 'intestine';
		my $tofailFunction = 'fix_'.$wrongTestFunction;
		unless($currentTestFunction eq $wrongTestFunction){
			is($miner->$testFunction($wrongTestFunction),$wrongTestFunction,"Testing wrong animal, inputting ".$wrongTestFunction." in ".$testFunction);
		}
	}
}


is($miner->bei_resources('BEI'),(0,'BEI'), 'Testing wrong BEI');
is($miner->bei_resources('BEI '),(1,'BEI Resoures Strain '), 'Testing right BEI ');
is($miner->remove_ecoli_name('Escherichia coli '),'', "Testing good ecoli removal");
is($miner->remove_ecoli_name('Escherichia coli'),'Escherichia coli', "Testing bad ecoli removal");
is($miner->fix_syndromes('urinary tract infection'),(1,'uti'), 'Testing good syndrome');
is($miner->fix_syndromes('cow'),(0,'cow'), 'Testing wrong syndrome');
is($miner->fix_serotypes('     non-typable'),(1,'nt'), 'Testing to fix serotype');
is($miner->fix_serotypes('ot'),(0,'ot'), 'Testing wrong serotype fixing');















#testing one higher level, to the validation routines

my @cleanupCallsForValidations = qw/
	basic_formatting  
	fix_hosts 
	remove_type_strain 
	bei_resources 
	remove_ecoli_name 
	fix_sources 
	fix_syndromes 
	fix_serotypes
/;

#Tests to see if the hosts will be well identified
my @goodInputs = qw/human horse rabbit/;
my %validation_hash = (human=>'Homo sapiens (human)', horse=>'Equus ferus caballus (horse)', rabbit=>'Oryctolagus cuniculus (rabbit)');
my @badInputs = qw/H157:N4 Argentina/;

my $validationResult;
foreach my $goodInput (@goodInputs){
	foreach my $cleanup_call (@cleanupCallsForValidations){
		$validationResult = $miner->$cleanup_call($goodInput);
		if($cleanup_call eq 'fix_hosts'){
			is($miner->hosts($validationResult)->{displayname}, $validation_hash{$goodInput}, "Good Validation validation for ".$goodInput);
		}else{
			is($miner->hosts($validationResult), 'skip', "Sould skip if $goodInput cleans through $cleanup_call and inputed in host");
		}
	}
}
foreach my $badInput (@badInputs){
	foreach my $cleanup_call (@cleanupCallsForValidations){
		$validationResult = $miner->$cleanup_call($badInput);
		is($miner->hosts($validationResult),  'skip', "Sould skip if $badInput cleans through $cleanup_call and inputed in host");
	}
}


#Tests to see if the source will be well identified
@goodInputs = qw/feces urogenital_tract gastrointestinal_tract/;
%validation_hash = (feces=>'Stool', urogenital_tract=>'Urogenital system', gastrointestinal_tract=>'Intestine');
@badInputs = qw/H157:N4 Argentina human/;

foreach my $goodInput (@goodInputs){
	foreach my $cleanup_call (@cleanupCallsForValidations){
		$validationResult = $miner->$cleanup_call($goodInput);
		if($cleanup_call eq 'fix_sources' || $goodInput eq 'feces'){
			is($miner->sources($validationResult)->{1}->{displayname}, $validation_hash{$goodInput}, "Good source validation for ".$goodInput);
			
		}else{
			is($miner->sources($validationResult), 'skip', "Sould skip if $goodInput cleans through $cleanup_call and inputed in sources");
		}
	}
}
foreach my $badInput (@badInputs){
	foreach my $cleanup_call (@cleanupCallsForValidations){
		$validationResult = $miner->$cleanup_call($badInput);
		is($miner->sources($validationResult), 'skip', "Sould skip if $badInput cleans through $cleanup_call and inputed in sources");
	}
}


#Tests to see if the syndrome will be well identified
@goodInputs = qw//;
push @goodInputs, "urinary tract infection";
push @goodInputs, "hemolytic uremic syndrome";
push @goodInputs,"Pneumonia";

%validation_hash = ("urinary tract infection"=>"Urinary tract infection (cystitis)", "hemolytic uremic syndrome"=>"Hemolytic-uremic syndrome", "Pneumonia"=>"Pneumonia");
@badInputs = qw/H157:N4 Argentina human Stool/;

foreach my $goodInput (@goodInputs){
	foreach my $cleanup_call (@cleanupCallsForValidations){
		$validationResult = $miner->$cleanup_call($goodInput);
		if($cleanup_call eq 'fix_syndromes' || $goodInput eq "Pneumonia"){
			is($miner->syndromes($validationResult)->{1}->{displayname}, $validation_hash{$goodInput}, "Good syndrome validation for ".$goodInput);
		}else{
			is($miner->syndromes($validationResult), 'skip', "Sould skip if $goodInput cleans through $cleanup_call and inputed in syndromes");
		}
	}
}

foreach my $badInput (@badInputs){
	foreach my $cleanup_call (@cleanupCallsForValidations){
		$validationResult = $miner->$cleanup_call($badInput);
		is($miner->syndromes($validationResult), 'skip', "Sould skip if $badInput cleans through $cleanup_call and inputed in syndromes");
	}
}

@goodInputs = qw/Lethbridge Yellowknife/;
is($miner->locations("Yellowknife")->{displayname},"Canada, Northwest Territories, Yellowknife","Testing proper location");
is($miner->locations("New York")->{displayname},"United States, New York, New York","Testing proper location");
is($miner->locations("Washington State")->{displayname},"United States, Washington","Testing proper location");

is($miner->locations("Mozambique")->{displayname},"Mozambique","Testing proper location");

@badInputs = qw/Pneumonia Stool H157:nm t7/;
push @badInputs, "Homo Sapien";
foreach my $badInput (@badInputs){
	is($miner->locations($badInput),"skip","Testing bad location ".$badInput);
}


# Check results
#my $results = decode_json($results_json);
#ok($results, 'Decode JSON results');

#is($results->{'Accession1'}->{'isolation_host'}->[0]->{'id'}, 1, 'Correct assignment of host');

#diag explain $results;

done_testing();

