#!/usr/bin/env perl
package Modules::FET;

=pod

=head1 NAME

Stats::FET - Returns FET p-value between two groups being compared for a particular $testChar. Stores the results for each comparison as a row in a hashref.

=head1 SYNOPSIS

	my $fet = Stats::FET->new();

	$fet->run();


=head1 DESCRIPTION

Stats::FET is for analyzing tab-delimited table data with both column and row labels.
An object is created by specifying the file name of the table one will analyze, along with single character data to test for significance with,
characters that should be ignored rather than counted as "not the test char", and the names of the members of two groups.
The column headers must match exactly the group names specified upon object creation.
The module prints the results sorted by ascending P-value as follows:

<row header>	<character tested for significance>	<P-value>

The default output is STDOUT, but can be piped or specified directly using $obj->outputFH(<filehandle>);

=head2 Methods

=head3 group1

A HASHREF that stores the members of group1.
$self->group1->{strain}=1/
Must be specified during object creation.
RO.

=head3 group2

A HASHREF that stores the members of group2.
$self->group2->{strain}=1/
Must be specified during object creation.
RO.

=head3 _resultHash

Private HASHREF that stores the results of the entire run.
$self->_resultHash->{row_header}->{test_character}=p_value.

=head3 _memoize

A HASHREF that stores the four number FET query sequence as the hash key and P Value for each FET as the value.
	$self->_memoize->{'2_4_8_11'}=p_value
This allows the program to check if a test has previously been computed and if so fetch the P Value from the hash.
Both combinations that give the same P Value are automatically stored, eg.
FET(2,4,8,11) == FET(8,11,2,4)

=head3 logger

Stores the Log::Log4perl object for module logging.

=head3 _R

Private method that stores the Statistics::R object and is used for all R-related calls.

=head3 _initialize

Private method called by new to initialize object.
Calls the FileInteraction::FlexiblePrinter _initialize.
Sets the Log::Log4perl object.
Sets the Statistics::R object.
Sets group1 object.
Sets group2 object.

Initializes the data structures:
	$self->_memoize({});
	$self->_resultHash({});

=head3 _setGroup

	$self->_setGroup('grpup_name',(ARRAYREF or <filename>);

Private method that converts an ARRAYREF or items listed in a file into the _group1 or _group2 HASHREF, with the key as the group member name and the value of 1.

=head3 _getPValue

	$self->_getPValue(group1pos,group1neg,group2pos,group2neg);
Private method that returns the P value for the 4 numbers passed as an ARRAY to the function.
Uses the two-tailed test via $self->_R and fisher.test().

=head3 _processLine

	$self->_processLine($line,$testChar);

Private method that prepares the four values to be sent to the _getPValue function.
Retrieves the counts for each group via the _countGroup function.
Queries _memoize to see if FET has previously been computed, if it has, gets P Value from hash;
if not, calls the _getPValue function and adds the result to the _memoize HASHREF.
Stores results in the _resultHash.

=head3 _countGroup

	$self->_countGroup('groupname', $testChar, \@la);

Where @la is the array of the line, with each array cell containing a single character, computed by the _processLine function where this function is called.
Returns the hashRef where $hashRef->{'pos'}=(number of times the testCharacter was counted)
and $hashRef->{'neg'}=(number of non-testCharacters, excluding any _excludedCharacters).

=head3 _printResultsToFile

Sorts the _resultHash by ascending P Value and outputs the results in the form:

row_header	test_character	count_data	P_Value

uses the inherited ->print and ->outputFH methods from FlexiblePrinter, which defaults to STDOUT.

=head3 run

The public method to get the FET stats from the file.
Opens the file, iterates over each line, and send the line to the _processLine function, except for the first line which defines the column arrays via _setGroupColumns.
Finally, calls the _printResultsToFile function.

=head3 DESTROY

Closes the _R instance started in _initialize.


=head1 ACKNOWLEDGEMENTS

Thanks.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.html

=head1 AVAILABILITY

The most recent version of the code may be found at: https://github.com/chadlaing/Panseq

=head1 AUTHOR

Chad Laing (chadlaing gmail com)

=cut

use FindBin;
use lib "$FindBin::Bin../";
use warnings;
use strict;
use Carp;
use IO::File; #get rid of these after moving the methods over 
use File::Temp; #get rid of these after moving them methods over
use Statistics::R;
use Log::Log4perl qw(:easy);

#object creation
sub new {
	my ($class) = shift;
	my $self = {};
	bless( $self, $class );
	$self->_initialize(@_);
	return $self;
}

#Get/Set methods

#Here, groups refer to the genomes being queried
sub group1 {
	my $self = shift;
	$self->{'_group1'} = shift // return $self->{'_group1'};
}

sub group2 {
	my $self = shift;
	$self->{'_group2'} = shift // return $self->{'_group2'};
}

#Here, markers refer to either genome loci or SNPs
sub group1Markers {
	my $self = shift;
	$self->{'_group1Markers'} = shift // return $self->{'_group1Markers'};
}

sub group2Markers {
	my $self = shift;
	$self->{'_group2Markers'} = shift // return $self->{'_group2Markers'};
}

#Test chars will be either a binary digit (1/0) or a SNP letter (A,T,C,G)
sub testChar {
	my $self = shift;
	$self->{'_testChar'} = shift // return $self->{'_testChar'};
}

sub _memoize{
	my $self=shift;
	$self->{'__memoize'}=shift // return $self->{'__memoize'};
}

sub logger{
	my $self=shift;
	$self->{'_logger'}=shift // return $self->{'_logger'};
}

sub _R{
	my $self=shift;
	$self->{'__R'}=shift // return $self->{'__R'};
}

#methods
sub _initialize{
	my $self=shift;

	#logging
	Log::Log4perl->easy_init($DEBUG) unless Log::Log4perl->get_logger();
	$self->logger(Log::Log4perl->get_logger());
	$self->logger->debug("Logger initialized in Modules::FET");

	my %init = @_;
	
	#set R
	$self->_R(Statistics::R->new());
	$self->_R->startR;

	#initialize data structures
	$self->_memoize({});

	return 1;
}

sub _getPValue{
	my $self=shift;
	my @values=@_;

	my $matrixString =
	'comp<-matrix(c('
		. $values[0] . ','
		. $values[1] . ','
		. $values[2] . ','
		. $values[3] . ' ), nr = 2)';

my $rQuery = 'fisher.test(' . $matrixString . ")\n";

	#access R	
	$self->_R->send($rQuery);
	my $results = $self->_R->read();
	
	my $pvalue;
	if($results =~ /p-value\D+(.+)/){		
		$pvalue=$1;
		$self->logger->debug("p-value: $pvalue");
	}
	else{
		$self->logger->fatal("no p-value $results");
		exit(1);
	}
	return $pvalue;
}

sub _countGroup{
	my $self=shift;
	my $groupList=shift;
	my $groupMarkerPosCount=shift;

	#do the counts
	my %countHash;
	$countHash{'pos'}=0;
	$countHash{'neg'}=0;

	$countHash{'pos'}=$groupMarkerPosCount;
	$countHash{'neg'}=(scalar(@$groupList) - $countHash{'pos'});

	return \%countHash; 
}

sub _processLine{
	my $self=shift;
	my $group1PosCount=shift;
	my $group2PosCount=shift;
	my $_testChar=shift;
	
	#Gets the counts for each group
	my $group1Counts = $self->_countGroup($self->group1, $group1PosCount);
	my $group2Counts = $self->_countGroup($self->group2, $group2PosCount);

	#run the FET using the current values if not in _memoize
	my $memoizeString = join('_', $group1Counts->{'pos'}, $group1Counts->{'neg'}, $group2Counts->{'pos'}, $group2Counts->{'neg'});

	#$self->logger->debug('memoizeString: ' . $memoizeString);

	my $pValue;	
	if(defined $self->_memoize->{$memoizeString}){
		$pValue = $self->_memoize->{$memoizeString};
	}
	else{
		#get pValue
		#add to memoize
		#add reverse to memoize as it is the same eg fet(1,4,8,11) == fet(8,11,1,4)
		$pValue = $self->_getPValue($group1Counts->{'pos'}, $group1Counts->{'neg'}, $group2Counts->{'pos'}, $group2Counts->{'neg'});
		$self->_memoize->{$memoizeString}=$pValue;

		my $memoizeString2 = join('_', $group1Counts->{'pos'}, $group1Counts->{'neg'}, $group2Counts->{'pos'}, $group2Counts->{'neg'});
		$self->_memoize->{$memoizeString2} = $pValue;
	}

	return ($pValue , $group1Counts , $group2Counts);
}


sub run {
	my $self=shift;
	my $_count_column = shift;
	unless(scalar(@{$self->group1Markers}) == scalar(@{$self->group2Markers})) {
		$self->logger->error("Sizes of loci/snp lists for group1 and group2 must be the same");
		exit(1);
	}
	
	my @allResults;
	my $listSize = scalar(@{$self->group1Markers});
	my $sigpValueCount = $listSize;

	for (my $i = 0; $i < $listSize; $i++) {
		my ($_pValue, $_group1Counts, $_group2Counts) = $self->_processLine($self->group1Markers->[$i]->{$_count_column}, $self->group2Markers->[$i]->{$_count_column} , $self->testChar);

		my %rowResult;
		$rowResult{'marker_feature_id'} = $self->group1Markers->[$i]->{'feature_id'};
		$rowResult{'marker_id'} = $self->group1Markers->[$i]->{'id'};
		$rowResult{'marker_function'} = $self->group1Markers->[$i]->{'function'};
		$rowResult{'group1Present'} = $_group1Counts->{'pos'};
		$rowResult{'group1Absent'} = $_group1Counts->{'neg'};
		$rowResult{'group2Present'} = $_group2Counts->{'pos'};
		$rowResult{'group2Absent'} = $_group2Counts->{'neg'};
		$rowResult{'pvalue'} = $_pValue;
		$rowResult{'test_char'} = $self->testChar;
		if ($_pValue > 0.0500) {
			$sigpValueCount--;
		}
		else {
		}
		push(@allResults , \%rowResult);
	}
	my @resultArray;
	my @sortedAllResults = sort({$a->{'pvalue'} <=> $b->{'pvalue'}} @allResults);
	my @sigResults = @sortedAllResults[0..($sigpValueCount-1)];
	push(@resultArray, {'all_results' => \@sortedAllResults}, {'sig_results' => \@sigResults}, {'sig_count' => $sigpValueCount}, {'total_comparisons' => $listSize});
	return \@resultArray;
}

#define a DESTROY method to close R instance on object close
sub DESTORY {
	my $self=shift;
	$self->_R->stopR;
}

1;