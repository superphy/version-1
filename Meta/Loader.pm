#!/usr/bin/env perl

=pod

=head1 NAME

Meta::Loader.pm

=head1 DESCRIPTION

Loads parsed meta-data from Miner.pm into the DB. Identifies conflicts between data being loaded
and data already in the DB.

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

	# Meta-data terms
	$self->{meta_data_terms} = {
		isolation_host => 1,
		isolation_source => 1,
		isolation_location => 1, 
		syndrome => 1,
		isolation_date => 1,
		serotype => 1,
		strain => 1
	};


	return $self;
}


=head2 featureprops

Retrieve featureprops/meta-data for all public genomes in DB

Returns hash-ref:


=cut

sub featureprops {
	my $self = shift;
	my %args = @_;

	my $f_rs = $self->dbixSchema->resultset('Feature')->search(
		{},
		{
			join => ['dbxref', { 'featureprops' => 'type' }],
			columns => [qw/feature_id/],
			'+columns' => {
				'featureprops.type.name' => 'type.name',
				'dbxref.accession' => 'dbxref.accession',
				'featureprops.value' => 'featureprops.value',
				'featureprops.rank' => 'featureprops.rank',
			}
		}
	);

	# Populate with meta-data values from DB
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




}

1;
