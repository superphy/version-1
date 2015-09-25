#!/usr/bin/env perl

=pod

=head1 NAME

t::pangenome-page.t

=head1 SNYNOPSIS

SUPERPHY_CONFIGFILE=filename prove -lv t/pangenome-page.t

=head1 DESCRIPTION

Tests for Modules::Pangenomes.pm

Requires environment variable SUPERPHY_CONFIGFILE to provide DB connection parameters. A production DB is ok,
no changes are made to the DB.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

use strict;
use warnings;
use FindBin;
use Test::More;
use Test::Exception;
use lib "$FindBin::Bin/../";
use Modules::Pangenomes;
use lib "$FindBin::Bin/lib/";
use App;
use TestPostgresDB;
use Test::DBIx::Class {
	schema_class => 'Database::Chado::Schema',
	deploy_db => 0,
	keep_db => 0,
	traits => [qw/TestPostgresDB/]
};

# Create test CGIApp and work environment
my $cgiapp;
lives_ok { $cgiapp = t::lib::App::relaunch(Schema, $ARGV[0]) } 'Test::WWW::Mechanize::CGIApp initialized';
BAIL_OUT('CGIApp initialization failed') unless $cgiapp;

subtest 'Retrieve pangenome loci region for public genome' => sub {
		
	my $page = "/pangenomes/info?region=3157634";
	$cgiapp->get_ok($page);
	
};


done_testing();



