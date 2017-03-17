#!/usr/bin/env perl

use strict;
use warnings;
use DBI;

use FindBin;
use lib "$FindBin::Bin/../../";
use Data::Bridge;

# Test update_from_stdin function with specific inputs
# Make sure not to overwrite tables

# Connect to DB
my $db_bridge = Data::Bridge->new();

# Arguments
my $input_file = '/home/matt/tmp/sandbox/chado-tsnp_core-pQWu.dat';
my $table = "tsnp_core";
my %update_table_names = (
	"tsnp_core" => 'snp_core'
);
my %updatestring = (
	tsnp_core                     => "position = s.position, gap_offset = s.gap_offset",
);
my %tmpcopystring = (
	tsnp_core                     => "(snp_core_id,pangenome_region_id,position,gap_offset)",
);
my %joinstring = (
	tsnp_core                     => "s.snp_core_id = t.snp_core_id",
);
my %joinindices = (
	tsnp_core                     => "snp_core_id",
);


my $dbh = $db_bridge->dbh();
$dbh->{AutoCommit} = 0;
open(my $fh, "<", $input_file) or die "Can't open < $input_file: $!";
my $newttable = $update_table_names{$table}."_testy_mctestface";

cleanup($newttable);
test_table($newttable, $update_table_names{$table}, $joinindices{$table});

defer_constraints($newttable);

update_from_stdin(
	$newttable,
	$table,
	$tmpcopystring{$table},
	$updatestring{$table},
	$joinstring{$table},
	$fh,
	$joinindices{$table}
);

$dbh->commit();
close $fh;
cleanup($newttable);

sub update_from_stdin {
	my $ttable        = shift;
	my $stable        = shift;
	my $copy_fields   = shift;
	my $update_fields = shift;
	my $join          = shift;
	my $file          = shift;
	my $index         = shift;

	warn "Updating data in $ttable table ...\n";

	my $query1 = "CREATE TEMP TABLE $stable (LIKE $ttable INCLUDING DEFAULTS EXCLUDING CONSTRAINTS EXCLUDING INDEXES) ON COMMIT DROP";
	$dbh->do($query1) or croak("Error when executing: $query1 ($!).\n");
	
	my $query2 = "COPY $stable $copy_fields FROM STDIN;";
	print STDERR $query2,"\n";

	$dbh->do($query2) or croak("Error when executing: $query2 ($!).\n");

	while (<$fh>) {
		if ( ! ($dbh->pg_putline($_)) ) {
			# error, disconecting
			$dbh->pg_endcopy;
			$dbh->rollback;
			$dbh->disconnect;
			croak("error while copying data's of file $file, line $.");
		} # putline returns 1 if succesful
	}

	$dbh->pg_endcopy or croak("calling endcopy for $stable failed: $!");

	# Build index
	my $query2a = "CREATE INDEX $stable\_c1 ON $stable ( $index )";
	$dbh->do($query2a) or croak("Error when executing: $query2a ($!).\n");

	# update the target table
	my $query3 = "UPDATE $ttable t SET $update_fields FROM $stable s WHERE $join";
	
	$dbh->do("$query3") or croak("Error when executing: $query3 ($!).\n");
}

sub test_table {
	my $newttable = shift;
	my $ttable = shift;
	my $pkey = shift;
	

	warn "Creating copy of table $ttable called $newttable...\n";
	
	my $query1 = "CREATE TEMP TABLE $newttable (LIKE $ttable INCLUDING ALL);
		ALTER TABLE $newttable ALTER $pkey DROP DEFAULT;
		CREATE SEQUENCE $newttable\_id_seq;
		INSERT INTO $newttable SELECT * FROM $ttable;
		SELECT setval('$newttable\_id_seq', (SELECT max($pkey) FROM $newttable), true);
		ALTER TABLE $newttable ALTER $pkey SET DEFAULT nextval('$newttable\_id_seq');";
	$dbh->do($query1) or croak("Error when executing: $query1 ($!).\n");

	$dbh->commit();
}

sub cleanup {
	my $table = shift;

	warn "Deleting $table...\n";
	
	my $query1 = "DROP TABLE IF EXISTS $table;";
	$dbh->do($query1) or croak("Error when executing: $query1 ($!).\n");
	my $query2 = "DROP SEQUENCE IF EXISTS $table\_id_seq;";
	$dbh->do($query2) or croak("Error when executing: $query2 ($!).\n");

	$dbh->commit();

}

sub defer_constraints {
	my $newttable = shift;

	my @contraints = qw(
		snp_core_c1
	);

	my $constraint_list = join ', ', @contraints;

	# Delay contraints in this transaction
	my $query1 = "SET CONSTRAINTS $constraint_list DEFERRED";
	$dbh->do($query1) or croak("Error when executing: $query1 ($!).\n");

	$dbh->commit();

}




