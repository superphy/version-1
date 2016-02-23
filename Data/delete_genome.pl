#!/usr/bin/env perl

=head1 NAME

$0 - Deletes genome from the database

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config          INI style config file containing DB connection parameters
 --genome          Genome label to remove from the DB (e.g public_1234567 or private_123)
 --remove_lock     Remove the lock to allow a new process to run
 --help            Detailed manual pages
 --email           Send email notification when script terminates unexpectedly
 --test            Run in test mode

=head1 DESCRIPTION

TBD

=head2 NOTES

TBD

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2015

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Config::Tiny;
use FindBin;
use lib "$FindBin::Bin/../";
use Time::HiRes qw( time );
use Log::Log4perl qw(:easy);
use Carp;
use DBI;
use File::Temp qw(tempdir);
use File::Copy qw(copy move);
use IO::CaptureOutput qw(capture_exec);
use Data::Bridge;
use Phylogeny::Tree;
use Try::Tiny;
use Data::Dumper;
use Modules::UpdateScheduler;


# Globals
my ($remove_lock, $help, $email_notification,
	$lock, $test, $perl_interpreter,
	$target_genome, $feature_id, $is_public, $genome_regex,
	$tmp_dir, $work_dir);

# Connect to database
my $db_bridge = Data::Bridge->new();
my $dbh = $db_bridge->dbh();
my $config = $db_bridge->configFile();

GetOptions(
	'genome=s' => \$target_genome,
    'remove_lock'  => \$remove_lock,
    'help' => \$help,
    'email' => \$email_notification,
    'test' => \$test,
) 
or pod2usage(-verbose => 1, -exitval => 1);
pod2usage(-verbose => 2, -exitval => 1) if $help;

# Perform error reporting before dying
$SIG{__DIE__} = $SIG{INT} = 'error_handler';
 

# SQL
# Lock
use constant VERIFY_TABLE => "SELECT count(*) FROM pg_class WHERE relname=? and relkind='r'";
use constant CREATE_LOCK_TABLE =>
	"CREATE TABLE pipeline_status (
		name        varchar(100),
		starttime   timestamp not null default now(),
		status      int default 0,
		job         varchar(10) default null
	)";
use constant FIND_LOCK => "SELECT name,starttime,status FROM pipeline_status WHERE status = 0";
use constant ADD_LOCK =>  "INSERT INTO pipeline_status (name) VALUES (?)";
use constant REMOVE_LOCK => "DELETE FROM pipeline_status WHERE name = ?";
use constant UPDATE_LOCK => "UPDATE pipeline_status SET status = ? WHERE name = ?";
use constant INSERT_JOB => "UPDATE pipeline_status SET job = ? WHERE name = ?";
use constant RECORD_DELETE => "INSERT INTO deleted_upload (upload_id, upload_date, cc_feature_id, cc_uniquename, username) VALUES (?,?,?,?,?)";

my %tracker_step_values = (
	pending => 1,
	processing => 2,
	completed => 3,
	notified => 4
);

my %tmp_files = (
	tree => 'tree.txt'
);




################
# MAIN
################

# Initialization
init($config);

INFO "\n\t***Start of analysis pipeline run***";

# Place lock
remove_lock() if $remove_lock;
place_lock();

# Initialize Phylogeny object
my $tree_io = Phylogeny::Tree->new(dbix_schema => $db_bridge->dbixSchema);

# Deletion is performed in transaction
try {
	
	# Retrieve genome info
	my ($upload_id, $upload_date, $uniquename, $user) = get_genome_specifics();

	# Remove from DB
	$db_bridge->dbixSchema->txn_do(sub {

		&prune_trees();
		&delete_groups();
		&delete_pangenome();
		&delete_snps();
		&delete_caches();
		&delete_relationships();
		&delete_feature();
		if(!$is_public) {
			delete_upload($upload_id);
		}

	});

	# Update cached data
	$db_bridge->dbixSchema->txn_do(sub {

		&update_precomputed_public_data();

	});

	# Record private genome deletions
	unless($is_public) {
		my $sth = $dbh->prepare(RECORD_DELETE);
    	$sth->execute($upload_id, $upload_date, $feature_id, $uniquename, $user) or die "Inserting deletion record into deleted_upload failed.";
	}
	
}
catch {
	die "Encountered error during genome deletion ($_).";
}


# Termination
remove_lock();

INFO "End of analysis pipeline run.";

################
# SUBROUTINES
################


=head2 init

  Process config file and connect to DB

=cut

sub init {
	my $config_file = shift; 
	
	# Process config file
	my $conf;
	unless($conf = Config::Tiny->read($config_file)) {
		die $Config::Tiny::errstr;
	}
	
	# Start logger
	my $log_dir = $conf->{dir}->{log};
	my $logfile = ">>$log_dir/delete.log";
	Log::Log4perl->easy_init(
		{ 
			level  => ("$DEBUG"), 
			layout => "%P %d %p - %m%n", 
			file   => $logfile
		}
	);
	
	$tmp_dir = $conf->{tmp}->{dir};
	die "Invalid configuration file. Missing tmp.dir parameters." unless $tmp_dir;

	# Set exe paths
	$perl_interpreter = $^X;

	# Parse genome input
	my $access;
	($access, $feature_id) = ($target_genome =~ m/(public|private)_(\d+)/);
	die "Invalid genome identifier: $target_genome. Unrecognized access." unless $access;
	die "Invalid genome identifier: $target_genome. Missing integer." unless $feature_id;
	$is_public = 0;
	$is_public = 1 if $access eq 'public';

	# Create tmp directory
	my $job_id;
	($job_id, $work_dir) = init_job();

	# Create regex to identify genome in tree nodes
	$genome_regex = qr/^$target_genome/;
}


=head2 place_lock

Places a row in the pipeline_status table (creating that table if necessary) 
that will prevent other users/processes from running simultaneous analysis pipeline
while the current process is running.

=cut

sub place_lock {

    # Determine if table exists
    my $sth = $dbh->prepare(VERIFY_TABLE);
    $sth->execute('pipeline_status');

    my ($table_exists) = $sth->fetchrow_array;

    if (!$table_exists) {
       INFO "Creating lock table.\n";
       $dbh->do(CREATE_LOCK_TABLE);
       
    } else {
    	# check for existing lock
	    my $select_query = $dbh->prepare(FIND_LOCK);
	    $select_query->execute();
	
	    if(my @result = $select_query->fetchrow_array) {
			my ($name,$time,$status) = @result;
			my ($progname,$pid)  = split /\-/, $name;
	
	       	die "Cannot establish lock. There is another process running with process id $pid (started: $time, status: $status).";
		}
	}
    
    my $pid = $$;
	my $name = "$0-$pid";
    
	my $insert_query = $dbh->prepare(ADD_LOCK);
	$insert_query->execute($name);
	
	$lock = $name;

    return;
}

sub remove_lock {

	my $select_query = $dbh->prepare(FIND_LOCK);
    $select_query->execute();

    my $delete_query = $dbh->prepare(REMOVE_LOCK);

    if(my @result = $select_query->fetchrow_array) {
		my ($name,$time,$status) = @result;

		$delete_query->execute($name) or die "Removing the lock failed.";
		
    } else {
    	DEBUG "Could not find row in pipeline_status table. Lock was not removed.";
    }
    
    $lock = 0;
    
    return;
}

sub update_status {
	my $status = shift;
	
    my $update_query = $dbh->prepare(UPDATE_LOCK);
	$update_query->execute($status, $lock) or die "Updating status failed.";
}


=head2 job_id

  Find novel ID for new job. ID is used as directory.

=cut

sub init_job {
	
	my $job_dir = tempdir('XXXXXXXXXX', DIR => $tmp_dir );
	my ($job_id) = $job_dir =~ m/\/(\w{10})$/; 
	
	my $update_query = $dbh->prepare(INSERT_JOB);
	$update_query->execute($job_id, $lock) or die "Inserting job ID into status table failed.";
	
	return ($job_id, $job_dir);
}


=head2 send_email

Call program that sends various email notifications - probably doesn't need to
be separate program

=cut

sub send_email {
	my $type = shift;
	
	my @loading_args = ("$perl_interpreter $FindBin::Bin/email_notification.pl",
		"--config $config", "--notify $type");
		
	my $cmd = join(' ',@loading_args);
	system($cmd);
}

=head2 error_handler

  Print error to log, send error flag to DB table and then send email notification

=cut

sub error_handler {
	# Log
	my $m = "Abnormal termination.";
	$m = "[ERROR] @_\n" if @_;
	FATAL("$m");
	warn "$m";
    
    # DB
    if ($dbh && $dbh->ping && $lock) {
        update_status(-1);
    }
    
    # Email
    if($email_notification) {
    	send_email(1);
    }
    
    # Exit
    exit(1);
}

=head2 _genome_match 

=cut

sub _genome_match {
	my $name = shift;

	return $name =~ m/$genome_regex/
}

=head2 prune_trees

  Prune genome from all trees

=cut

sub prune_trees {

	my $table = $is_public ? 'FeatureTree' : 'PrivateFeatureTree';

	# Identify all gene and pangenome trees containing genome
	my $tree_rs = $db_bridge->dbixSchema->resultset($table)->search(
		{
			feature_id => $feature_id
		},
		{
			prefetch => [qw/tree/]
		}
	);

	# Prune genome and print updated tree to file
	my $genome_coderef = \&_genome_match;

	while(my $tree_row = $tree_rs->next) {

		# Load tree into memory
		my $tree;
		eval $tree_row->tree_string;
		
		# Prune tree
		$tree_io->pruneNode($tree, $genome_coderef);

		# Update tree
		my $tree_row2 = $tree_row->tree;
		$tree_row2->update({ tree_string => $tree });
		
		# Delete row
		$tree_row->delete;
	}

	# Update global tree
	my $global_tree = $tree_io->globalTree;
	$tree_io->pruneNode($global_tree, $genome_coderef);

	$tree_io->loadPerlTree($global_tree);

}

=head2 delete_groups

  Remove genome from all groups

=cut

sub delete_groups {

	my $table = $is_public ? 'FeatureGroup' : 'PrivateFeatureGroup';
	my $rel = $is_public ? 'feature_groups' : 'private_feature_groups';

	# Locate genome groups
	my $fgroup_rs = $db_bridge->dbixSchema->resultset($table)->search(
		{
			'me.feature_id' => $feature_id
		}, 
		{
			prefetch => 'genome_group'
		}
	);

	while(my $fgroup_row = $fgroup_rs->next) {
		my $group_id = $fgroup_row->genome_group_id;
		$fgroup_row->delete; # Delete feature_group entry

		# Count number of genomes left in group
		my $group_row = $db_bridge->dbixSchema->resultset('GenomeGroup')->find($group_id, { prefetch => $rel });
		my $remaining_rs = $group_row->$rel;

		unless($remaining_rs->count()) {
			# Group empty
			my $category_id = $group_row->category_id;
			$group_row->delete;

			# Check if category is now emtpy
			my $category_row = $db_bridge->dbixSchema->resultset('GroupCategory')->find($category_id, { prefetch => 'genome_groups' });

			unless($category_row->genome_groups->count()) {
				# Category empty, delete category
				$category_row->delete;
			}
		}
	}

}

=head2 delete_pangenome

  Remove features, accessory_regions and alignment columns and rows
  linked to genome

=cut

sub delete_pangenome {

	# Identify regions linked to genome
	my $pgaln_row = $db_bridge->dbixSchema->resultset('PangenomeAlignment')->find({ name => $target_genome }, { key => 'pangenome_alignment_c1' });
	die "Error: no alignment found for genome $target_genome in table pangenome_alignment." unless($pgaln_row);

	my @present_absent = split //, $pgaln_row->acc_alignment;
	my $num_regions = scalar(@present_absent);
	my $i = 0;
	my @columns = grep $present_absent[$i++], (0..$num_regions);

	# Find if other genomes have region
	my @counts = (0) x @columns;
	my $accaln_rs = $db_bridge->dbixSchema->resultset('PangenomeAlignment')->search({}, { columns => [qw/pangenome_alignment_id name acc_column acc_alignment/] });

	while(my $accaln_row = $accaln_rs->next) {
		my @pa = split //, $accaln_row->acc_alignment;
		my @this_cols = @pa[@columns];

		for(my $j = 0; $j < @counts; $j++) {
			$counts[$j]++ if $this_cols[$j];
		}
	}

	my @keep_columns;
	my @drop_columns;
	for(my $j = 0; $j < @counts; $j++) {
		if($counts[$j] > 1) {
			push @keep_columns, $columns[$j] 
		}
		else {
			push @drop_columns, $columns[$j]
		}
	}

	# Remove columns 
	if(@drop_columns) {
		$accaln_rs->reset;
		my $new_col = scalar(@keep_columns);

		# Update accessory alignment
		while(my $accaln_row = $accaln_rs->next) {
			my @pa = split //, $accaln_row->acc_alignment;
			my @spliced_aln = @pa[@keep_columns];

			$accaln_row->acc_alignment(join('', @spliced_aln));
			$accaln_row->acc_column($new_col);
			$accaln_row->update();
		}

		# Delete accessory regions
		my $accregion_rs = $db_bridge->dbixSchema->resultset('AccessoryRegion')->search(
			{
				aln_column => { '-in' => \@drop_columns }
			}
		);
		$accregion_rs->delete_all;

		# Shift column assignments
		push @drop_columns, $new_col-1;
		my $adjustment = 1;

		for(my $k = 0; $k < $#drop_columns; $k++) {
			my $dropped = $drop_columns[$k];
			my $next = $drop_columns[$k+1];

			# Find all columns in range
			my $pos1 = "> $dropped";
			my $pos2 = "< $next";
			my $region_rs = $db_bridge->dbixSchema->resultset('AccessoryRegion')->search(
				{
					aln_column => \$pos1,
					aln_column => \$pos2
				},
				{
					columns => [qw/accessory_region_id aln_column/],
					order_by => { -asc => 'aln_column' }
				}
			);

			while(my $region_row = $region_rs->next) {
				my $old_column = $region_row->aln_column;
				$region_row->aln_column($old_column-$adjustment);
				$region_row->update();
			}

			$adjustment++;
		}

	}

	# Delete accessory genome alignment
	$pgaln_row->delete;


		
}

=head2 delete_snps

  Remove snp_core, snp_variations, snp_positions, gap_position and snp_alignment columns and rows
  linked to genome

=cut

sub delete_snps {

	if($test) {
		print "TESTING SNP DELETION\n";
		#$db_bridge->dbixSchema->storage->debug(1);
	}

	my @drop_snps;
	my ($r1, $r2, $t);
	if($is_public) {
		$r1 = 'FeatureRelationship';
		$r2 = 'feature_relationship_subjects';
		$t = 'feature_cvterms';
	} 
	else {
		$r1 = 'PripubFeatureRelationship';
		$r2 = 'private_feature_relationship_subjects';
		$t = 'feature_cvterms';
	}

	# Identify core regions linked to genome
	my $pg_rs = $db_bridge->dbixSchema->resultset($r1)->search(
		{
			'me.type_id' => $db_bridge->cvmemory->{'derives_from'},
			"$r2.type_id" => $db_bridge->cvmemory->{'part_of'},
			"$r2.object_id" => $feature_id,
			"$t.cvterm_id" => $db_bridge->cvmemory->{'core_genome'},
			'-not_bool' => "$t.is_not"

		},
		{
			join => [
				{'subject' =>  $r2},
				{'object' => $t}
			],
			columns => [qw/object_id/]
		}
	);

	my $var_relationship = $is_public ? 'snp_variations' : 'private_snp_variations';
	while(my $pg_row = $pg_rs->next) {
		# Iterate through SNPs in each region, adjusting totals

		my $pg_id = $pg_row->object_id;
		if($test) {
			print "WORKING ON REGION $pg_id\n";
		}

		next unless $pg_id == 3161040;

		my $snp_rs = $db_bridge->dbixSchema->resultset('SnpCore')->search(
			{
				pangenome_region_id => $pg_id,
				"$var_relationship.contig_collection_id" => $feature_id
			},
			{
				prefetch => [$var_relationship]
			}
		);

		while(my $snp_row = $snp_rs->next) {
			# Find variations linked to snp
			my $snp_id = $snp_row->snp_core_id;

			my $var_rs = $snp_row->$var_relationship;
			my $var_row = $var_rs->first;

			
			if($var_row) {
				subtract_allele($snp_row, $var_row->allele);
				$var_row->delete;
			}
			else {
				# Background allele, adjust total
				subtract_allele($snp_row, $snp_row->allele)
			}

			$snp_row->update();

			# Check if this position is still polymorphism
			if(defined($snp_row->aln_column) && !check_snp_status($snp_row)) {
				# Delete snp in alignment
				push @drop_snps, [$snp_row->snp_core_id, $snp_row->aln_column];
				if($test) {
					print "SELECTED FOR DELETION: ".stringify_snp($snp_row)."\n";
				}
			}
		}
	}

	# Fix Snp alignment to remove deleted snps
	delete_snp_columns(\@drop_snps) if @drop_snps;
	# Remove offending row
	my $delete_row = $db_bridge->dbixSchema->resultset('SnpAlignment')->find({ name => $target_genome }, { key => 'snp_alignment_c1' });
	$delete_row->delete();

	# Delete gap_position, snp_position
	# Cascading should delete these, but this should be faster
	my $pos_rs = $db_bridge->dbixSchema->resultset('SnpPosition')->search(
		{
			contig_collection_id => $feature_id
		}
	);
	$pos_rs->delete;

	my $gap_rs = $db_bridge->dbixSchema->resultset('GapPosition')->search(
		{
			contig_collection_id => $feature_id
		}
	);
	$gap_rs->delete;



	return;
}

sub check_snp_status {
	my $snp_row = shift;

	my $num_alleles = shift;

	my @allele_methods = qw/frequency_a frequency_t frequency_c frequency_g/;
	foreach my $method (@allele_methods) {
		$num_alleles++ if $snp_row->$method > 0;
	}

	if($snp_row->allele =~ m/[ATGC]/i) {
		$num_alleles++;
	}

	print "ALLELES: $num_alleles\n" if $test;

	return($num_alleles > 1);
}

sub stringify_snp {
	my $snp_row = shift;

	my @out = ("id: ".$snp_row->snp_core_id, "allele: ".$snp_row->allele, "col: ".$snp_row->aln_column);

	my @allele_methods = qw/frequency_a frequency_t frequency_c frequency_g frequency_gap frequency_other/;
	foreach my $method (@allele_methods) {
		push @out, "$method: ".$snp_row->$method();
	}

	return(join(', ', @out));
}

sub subtract_allele {
	my ($snp_row, $allele) = @_;

	$allele = uc($allele);
	my $method;

	if($allele eq 'A') {
		$method = 'frequency_a';
	} 
	elsif($allele eq 'T') {
		$method = 'frequency_t';
	}
	elsif($allele eq 'G') {
		$method = 'frequency_g';
	}
	elsif($allele eq 'C') {
		$method = 'frequency_c';
	}
	elsif($allele eq '-') {
		$method = 'frequency_gap';
	}
	else {
		$method = 'frequency_other';
	}

	my $curr = $snp_row->$method();

	$snp_row->$method($curr-1);
}

sub delete_snp_columns {
	my $drop_snps = shift;

	if($test) {
		print @$drop_snps." snps being deleted.\n";
		print Dumper($drop_snps),"\n";
	}

	my $col_row = $db_bridge->dbixSchema->resultset('SnpAlignment')->find({ name => 'core' }, { key => 'snp_alignment_c1' });
	my $max_column = $col_row->aln_column;
	print "MAX COL: $max_column\n" if $test;

	my %drop_columns;
	map { $drop_columns{$_->[1]} = 1 } @$drop_snps;
	my @keep_columns = grep { !$drop_columns{$_} } 0..$max_column-1;

	my $new_col = scalar(@keep_columns);

	# Update snp alignment
	my $snpaln_rs = $db_bridge->dbixSchema->resultset('SnpAlignment')->search();
	while(my $snpaln_row = $snpaln_rs->next) {
		my @aln = split //, $snpaln_row->alignment;
		my @spliced_aln = @aln[@keep_columns];

		$snpaln_row->alignment(join('', @spliced_aln));
		$snpaln_row->aln_column($new_col);
		$snpaln_row->update();
	}

	# Delete snps
	my @drop_cols = keys %drop_columns;
	my @drop_ids = map { $_->[0] } @$drop_snps;
	my $snpcore_rs = $db_bridge->dbixSchema->resultset('SnpCore')->search(
		{
			snp_core_id => { '-in' => \@drop_ids }
		}
	);
	$snpcore_rs->delete_all;
	print "DELETED SNP_CORE ROWS: ".join(', ', @drop_ids)."\n" if $test;
	$db_bridge->dbixSchema->storage->debug(1);

	# Shift column assignments
	push @drop_cols, $max_column+1;
	my $adjustment = 1;

	for(my $k = 0; $k < $#drop_cols; $k++) {
		my $dropped = $drop_cols[$k]+1;
		my $next = $drop_cols[$k+1]-1;

		# Find all columns in range
		my $core_rs = $db_bridge->dbixSchema->resultset('SnpCore')->search(
			{
				aln_column => {
					'-between' => [$dropped, $next]
				}
			},
			{
				columns => [qw/snp_core_id aln_column/],
				order_by => { -asc => 'aln_column' }
			}
		);

		while(my $core_row = $core_rs->next) {
			my $old_column = $core_row->aln_column;
			my $new_column = $old_column-$adjustment;
			$core_row->aln_column($new_column);
			#print "COLUMN MOVED FROM $old_column to $new_column\n";
			$core_row->update();
		}

		$adjustment++;
	}

}
	

sub remove_later {
	
	my @counts;
	my $accaln_rs = $db_bridge->dbixSchema->resultset('PangenomeAlignment')->search({}, { columns => [qw/name acc_alignment/] });

	while(my $accaln_row = $accaln_rs->next) {
		my @pa = split //, $accaln_row->acc_alignment;
		
		for(my $j = 0; $j < @pa; $j++) {
			$counts[$j]++ if $pa[$j];
		}
	}

	my $i = 0;
	foreach my $c (@counts) {
		print "$i,$c\n" if $c < 2;
		$i++;
	}

}

sub snp_test_slice {
	my $snp_id = shift;

	# Find column linked to snp_id
	my $snp_row = $db_bridge->dbixSchema->resultset('SnpCore')->find($snp_id);

	my $col = $snp_row->aln_column;

	print "$snp_id column: $col\n";

	# Extract column
	my $aln_rs = $db_bridge->dbixSchema->resultset('SnpAlignment')->search();
	my @column;
	while(my $aln_row = $aln_rs->next) {
		next if $aln_row->name eq $target_genome;

		push @column, substr($aln_row->alignment, $col, 1);
	}
	
	return join('', @column);
}

=head2 delete_caches

  Empty caches.  Caches will be rebuilt next loading run.

=cut

sub delete_caches {

	my @tables = ('tmp_loci_cache', 'tmp_allele_cache');

	foreach my $t (@tables) {
		my $quoted_name = $dbh->quote_identifier($t);
    	$dbh->do("DROP TABLE IF EXISTS $quoted_name") or die "Error: drop table $t failed ($!)\n";
	}
}

=head2 delete_relationships

  Delete features linked via feature_relationship table

=cut

sub delete_relationships {

	my $r = $is_public ? 'FeatureRelationship' : 'PrivateFeatureRelationship';

	# Identify experimental features linked to genome
	my $subj_rs = $db_bridge->dbixSchema->resultset($r)->search(
		{
			'me.object_id' => $feature_id,
			'me.type_id' => $db_bridge->cvmemory('part_of')
		},
		{
			prefetch => [qw/subject/]
		}
	);

	while(my $subj_row = $subj_rs->next) {
		my $subj_id = $subj_row->subject->feature_id;
		$subj_row->subject->delete;
		$subj_row->delete;
		#print "Deleted relationship to $subj_id\n" if $test;
	}

	print "DELETED RELATIONSHIPS and EXPERIMENTAL FEATURES\n" if $test; 
}

=head2 delete_feature

  Delete feature. Cascading delete should clear:
    feature_cvterms,
    featureloc,
    featureprop,
    genome_location,
    feature_dbxref

=cut

sub delete_feature {
	
	my $r = $is_public ? 'Feature' : 'PrivateFeature';

	# Identify experimental features linked to genome
	my $feature_row = $db_bridge->dbixSchema->resultset($r)->find(
		$feature_id
	);

	$feature_row->delete;

	print "DELETED FEATURE\n" if $test;
}

=head2 delete_upload

  Delete upload entry. Cascading should clear
    permission

=cut

sub delete_upload {
	my $upload_id = shift;
	
	# Identify upload_id linked to genome
	my $upload_row = $db_bridge->dbixSchema->resultset('Upload')->find(
		$upload_id
	);

	$upload_row->delete;

	print "DELETED UPLOAD\n" if $test; 
}

=head2 update_precomputed_public_data

 Recompute the public data that is stored as
 JSON for fast access

=cut

sub update_precomputed_public_data {

	my $scheduler = Modules::UpdateScheduler->new(dbix_schema => $db_bridge->dbixSchema, config => $config);

	$scheduler->recompute_public();
}

=head2 get_private_genome_specifics

 Query info for genome being deleted

=cut

sub get_genome_specifics {

	my ($upload_id, $upload_date, $cc_uniquename, $username) = (0,0,0,0,0);

	if($is_public) {
		my $feature_row = $db_bridge->dbixSchema->resultset('Feature')->find(
			$feature_id
		);
		$cc_uniquename = $feature_row->uniquename;
	}
	else {
		my $feature_rs = $db_bridge->dbixSchema->resultset('PrivateFeature')->search(
			{
				feature_id => $feature_id
			},
			{
				prefetch => { upload => 'login'}
			}
		);

		my $feature_row = $feature_rs->first;
		$cc_uniquename = $feature_row->uniquename;
		$upload_id = $feature_row->upload_id;
		$upload_date = $feature_row->upload->upload_date;
		$username = $feature_row->upload->login->username;

	}

	return($upload_id, $upload_date, $cc_uniquename, $username);
}