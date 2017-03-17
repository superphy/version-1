#!/usr/bin/env perl 

=head1 NAME

$0 - Fix pangenome alignment to sync with feature tables

=head1 SYNOPSIS

  % rebuild_pg_alignment.pl --config config_file

=head1 COMMAND-LINE OPTIONS

 --config         A *.conf file containing DB connection parameters and log directory
 
=head1 DESCRIPTION

The pangenome alignment is a summary of the data in the feature and feature_relationship.
This data became out of sync and this script re-writes the pangenome_alignment, core_region, accessory_region tables
by polling these other sources

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2016

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Carp qw/croak carp/;
use Config::Tiny;
use Log::Log4perl qw(get_logger);
use Bio::SeqIO;
use lib "$FindBin::Bin/../";
use Data::Bridge;
use Data::Dumper;
use List::Util qw/sum/;
use IO::CaptureOutput qw(capture_exec);
use Time::HiRes qw/gettimeofday/;

# Genomes in DB
my %genomes;

# SNP alignments in DB
my %snp_alignments;
my $core_alignment = '';
my $current_column = 0;
my %alignment_columns;

# Config
my ($config_filepath, 
	$log_dir,
	$tmp_dir
);

# Get options
GetOptions(
    'config=s'  => \$config_filepath

) or ( system( 'pod2text', $0 ), exit -1 );

croak "Error: missing argument. You must supply a configuration filepath.\n" . system ('pod2text', $0) unless $config_filepath;

if(my $conf = Config::Tiny->read($config_filepath)) {
	$log_dir = $conf->{dir}->{log};
	$tmp_dir = $conf->{tmp}->{dir};
} else {
	die Config::Tiny->error();
}

# Connect to database
my $dbBridge = Data::Bridge->new(config => $config_filepath);
my $schema = $dbBridge->dbixSchema;
my $dbh = $dbBridge->dbh;
my $cvterms = $dbBridge->cvmemory;

my %sql_sth; # Prepared SQL statements
my %file_handles;
my $logger = init($log_dir); # Setup logger
$logger->info("<<BEGIN Superphy Pangenome alignment repair");

fix_pangenomes();
update();

$logger->info("Repair complete");
$logger->info("END>>");

###############
## Subs
###############

# Setup logging
sub init {
	my $dir = shift;

    # config
    my $conf = q(
        log4perl.logger                    = DEBUG, FileApp
        log4perl.appender.FileApp          = Log::Log4perl::Appender::File
        log4perl.appender.FileApp.filename = ).$dir.q(rebuild_pg_alignment.log
        log4perl.appender.FileApp.layout   = PatternLayout
        log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n
        log4perl.appender.FileApp.mode     = write
    );

    # Initialize logging behaviour
    Log::Log4perl->init(\$conf);

    # Obtain a logger instance
    my $logger = get_logger();

    # Prepared sql statements
	my $stmt1 =
	"SELECT f.feature_id, r2.object_id ".
	"FROM feature f, feature_relationship r, feature_relationship r2 ".
	"WHERE r2.subject_id = f.feature_id AND ".
	" r2.type_id = ". $cvterms->{part_of} . " AND ".
	" r.subject_id = f.feature_id AND ".
	" r.type_id = ". $cvterms->{derives_from} . " AND ".
	" r.object_id = ?";
	$sql_sth{public_pangenome_loci} = $dbh->prepare($stmt1);

	my $stmt2 = "SELECT f.feature_id, f.type_id, r2.object_id ".
	"FROM private_feature f, pripub_feature_relationship r, private_feature_relationship r2 ".
	"WHERE r2.subject_id = f.feature_id AND ".
	" r2.type_id = ". $cvterms->{part_of} . " AND ".
	" r.subject_id = f.feature_id AND ".
	" r.type_id = ". $cvterms->{derives_from} . " AND ".
	" r.object_id = ?";
	$sql_sth{private_pangenome_loci} = $dbh->prepare($stmt2);

	my $stmt3 = "DELETE FROM feature where feature_id = ?";
	$sql_sth{delete_pangenome} = $dbh->prepare($stmt3);

	my @files = (
		['accessory_region.txt', 'accessory_region'],
		['core_region.txt', 'core_region'],
		['pangenome_alignment.txt', 'pangenome_alignment']
	);

	foreach my $fset (@files) {
		my $f = "$tmp_dir/" . $fset->[0];
		my $fh = $fset->[1];

		open($file_handles{$fh}, "+>$f") or die "Error: unable to write to file $f ($!).\n";
	}

   return $logger;
}


sub fix_pangenomes {

	my %alignments;

	# Retrieve genomes
	my @types = ('private','public');
	foreach my $f_table ('private_feature', 'feature') {
		my $type = shift @types;
		my $stmt =
			"SELECT feature_id ".
			"FROM $f_table ".
		    "WHERE type_id = ".$cvterms->{contig_collection};
		my $sth = $dbh->prepare($stmt);
		$sth->execute();
		
		while(my ($genome_id) = $sth->fetchrow_array()) {
			my $id = "$type\_$genome_id";
			$alignments{defaults}{$id} = '0'; # Default
			$alignments{core}{$id} = '';
			$alignments{accessory}{$id} = '';
		}
	}
	$logger->info("Total genomes: ".scalar(keys %{$alignments{defaults}}));

	$alignments{core_column} = 0;
	$alignments{accessory_column} = 0;

	# Retrieve list of pangenome regions
	my $pg_rs = $schema->resultset('Feature')->search(
	    {
	        type_id => $dbBridge->cvmemory('pangenome'),
	        'feature_cvterms.cvterm_id' => $dbBridge->cvmemory('core_genome'),
	 
	    },
	    {
	        join => 'feature_cvterms',
	        columns => [qw/feature_id/],
	        '+select' => ['feature_cvterms.is_not'],
	        '+as' => ['is_core']
	    }
	);

	# Iterate through each pangenome region
	# Record presence / absence status in genomes
	while(my $pg_row = $pg_rs->next) {
		pangenome_alignment($pg_row->feature_id, $pg_row->get_column('is_core'), \%alignments);
	}

	write_alignments(\%alignments);
}

sub pangenome_alignment {
	my $pg_id = shift;
	my $not_core = shift;
	my $alignments = shift;

	my $state = $not_core ? 'accessory' : 'core';
	$logger->info("starting $state region $pg_id...");

	# Retrieve genomes with region
	my %default_values = %{$alignments->{defaults}};
	my %copy_dv;
	foreach my $k (keys %default_values) {
		$copy_dv{$k} = $default_values{$k}
	}

	my $nhits = 0;
	my @types = ('private', 'public');
	foreach my $handle_name ('private_pangenome_loci', 'public_pangenome_loci') {
	
		my $type = shift @types;

		my $sth = $sql_sth{$handle_name};
		$sth->execute($pg_id);

		while(my ($loci_id, $genome_id) = $sth->fetchrow_array) {
			my $id = "$type\_$genome_id";
			croak "Error: unknown genome $id" unless defined $copy_dv{$id};
			$copy_dv{$id} = '1';
			$nhits++;
		}
	}


	if($nhits == 0) {
		# Delete empty entry
		$logger->warn("$pg_id has NO loci\n");
		$logger->warn("Deleting $pg_id\n");

		$sql_sth{delete_pangenome}->execute($pg_id);
		
	} else {
		# Save new column
		foreach my $id (keys %copy_dv) {
			$alignments->{$state}{$id} .= $copy_dv{$id}
		}

		my $table = "$state\_region";
		my $col = "$state\_column";
		print { $file_handles{$table} } join("\t",($pg_id, $alignments->{$col})),"\n";
		$logger->debug("$pg_id assigned column ".$alignments->{$col});
		$alignments->{$col}++;
	}

	$logger->info("$state region $pg_id complete.");
}

sub write_alignments {
	my $alignments = shift;

	my $acc_col = $alignments->{accessory_column};
	my $core_col = $alignments->{core_column};
	foreach my $genome (keys %{$alignments->{core}}) {

		croak "Unexpected length for core alignment in $genome ($core_col vs ".length($alignments->{core}{$genome})."\n"
			unless length($alignments->{core}{$genome}) == $core_col;
		croak "Unexpected length for accessory alignment in $genome" unless length($alignments->{accessory}{$genome}) == $acc_col;

		print { $file_handles{'pangenome_alignment'} } join("\t", ($genome, $alignments->{core}{$genome}, $core_col,
			$alignments->{accessory}{$genome}, $acc_col)),"\n";
	}

	# Print core record
	print { $file_handles{'pangenome_alignment'} } join("\t", ('core', '0'x$core_col, $core_col,
			'0'x$acc_col, $acc_col)),"\n";
}

sub reset_tables {

    my @backup_tables = (qw/core_region accessory_region pangenome_alignment/);
    my @reset_ids = (qw/core_region_core_region_id_seq
        pangenome_alignment_pangenome_alignment_id_seq
        accessory_region_accessory_region_id_seq/);

    foreach my $stable (@backup_tables) {
        my $ttable = unique_tablename($stable);
    
        # Copy data and basic structure from source table
        my $sql1 = "CREATE TABLE $ttable AS SELECT * FROM $stable";
        $dbh->do($sql1) or croak("Error when executing: $sql1 ($!).\n");

        get_logger->debug("Table $stable copied");

        $dbh->do("TRUNCATE TABLE $stable");
        get_logger->debug("Truncated table $stable");
    }

    foreach my $pkey (@reset_ids) {
    
        # Reset primary keys
        my $sql3 = "ALTER SEQUENCE $pkey RESTART WITH 1";
        $dbh->do($sql3) or croak("Error when executing: $sql3 ($!).\n");

        get_logger->debug("Sequence $pkey reset");
    }
    
}

sub unique_tablename {
    my $name = shift;
    my $timestamp = int (gettimeofday * 1000);
    my $uname = "$name\_backup_$timestamp";
    return $uname;
}

sub update {

	$dbh->{AutoCommit} = 0;  # Enable transactions
	$dbh->{RaiseError} = 1;

	eval {
    
		reset_tables();

        my @tables = (
            [
                $file_handles{'core_region'},
                'core_region',
                '(pangenome_region_id,aln_column)',
                'core_region.txt',
            ],
            [
                $file_handles{'accessory_region'},
                'accessory_region',
                '(pangenome_region_id,aln_column)',
                'accessory_region.txt',
            ],
            [
                $file_handles{'pangenome_alignment'},
                'pangenome_alignment',
                '(name,core_alignment,core_column,acc_alignment,acc_column)',
                'pangenome_alignment.txt'
            ]
        );

        foreach my $set (@tables) {
            copy_from_stdin(@$set);
        }

        
        $dbh->commit; # Save transaction changes
    };

    if ($@) {
        get_logger->warn("Transaction aborted because $@");
        $dbh->rollback;
    }
}

sub copy_from_stdin {
    my $fh       = shift;
    my $table    = shift;
    my $fields   = shift;
    my $file     = shift;
  
    get_logger->info("Loading data into $table table ...\n");

    $fh->autoflush;
    seek($fh,0,0);

    my $query = "COPY $table $fields FROM STDIN;";
    print $query;

    $dbh->do($query) or croak("Error when executing: $query: $!");

    while (<$fh>) {
        if ( ! ($dbh->pg_putline($_)) ) {
            # error, disconecting
            $dbh->pg_endcopy;
            $dbh->rollback;
            $dbh->disconnect;
            croak("error while copying data's of file $file, line $.");
        } # putline returns 1 if succesful
    }

    $dbh->pg_endcopy or croak("calling endcopy for $table failed: $!");

}
