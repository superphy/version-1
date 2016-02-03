
=head1 NAME

$0 - Validate config file

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config      INI style config file containing DB connection parameters

=head1 DESCRIPTION

Checks if config values are defined and exist.

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Getopt::Long;
use Try::Tiny;
use Config::Tiny;


# Test 1 - connect to DB
my $config;
my $config_filepath;
try {
	my $db_bridge = Data::Bridge->new();
	$config_filepath = $db_bridge->configFile();
} catch {
	die "Error: Initialization of Pg DB handle failed ($_).\n";
};

# Test 2 - check directories
unless(my $config = Config::Tiny->read($config_filepath)) {
	die Config::Tiny->error();
}

my @dirs = (
	['tmp','dir'],
	['dir','seq'],
	['dir','log'],
	['dir','groupwise'],
	['dir','sandbox'],
	['shiny','backupdir'],
	['shiny','targetdir'],
	['ext','blastdir'],
	['ext','mummerdir'],
);

foreach my $ds (@dirs) {
	my ($t, $b) = @$ds;
	my $p = "$t.$b";
	my $v = $config->{$t}->{$b};
	die "Error: Directory $v for parameter $p not found." unless -d $v;
}
	
# Test 2 - check parameters
my @params = (
	['mail','address'],
	['mail','pass'],
	['shiny','address'],
	['shiny','user'],
	['shiny','password'],
	['snp', 'significant_count_threshold'],

);

foreach my $ds (@params) {
	my ($t, $b) = @$ds;
	my $p = "$t.$b";
	my $v = $config->{$t}->{$b};
	die "Error: Value $v for parameter $p not defined." unless $v;
}

# Test 3 - check excutables
my @exes = (
	['ext','muscle'],
	['ext','panseq'],
	['ext','parallel'],
	['ext','fasttree'],
	['ext','fasttreemp'],
);

foreach my $ds (@exes) {
	my ($t, $b) = @$ds;
	my $p = "$t.$b";
	my $v = $config->{$t}->{$b};
	die "Error: Executable $v for parameter $p not found." unless -e $v;
}

# Test 4 - check blast db
my ($t, $b) = ('ext', 'blastdatabase');
my $p = "$t.$b";
my $v = $config->{$t}->{$b};
$v = $v . ".pal";
die "Error: Blast database $v for parameter $p not found." unless -e $v;


exit(0);

