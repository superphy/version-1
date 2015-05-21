#!/usr/bin/env perl

use strict;
use warnings;
use Bio::SeqIO;
use FindBin;
use lib "$FindBin::Bin/";
use ExperimentalFeatures;
use Getopt::Long;
use Pod::Usage;
use Carp;
use Sys::Hostname;
use Config::Simple;
use POSIX qw(strftime);

=head1 NAME

$0 - loads multi-fasta file into a genodo's chado database. Fasta file contains genomic or shotgun contig sequences.

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --fasta           Fasta file to load sequence from
 --attributes      Data::Dumper file containing hash of parent genome properties
 --config          INI style config file containing DB connection parameters
 --noload          Create bulk load files, but don't actually load them.
 --recreate_cache  Causes the uniquename cache to be recreated
 --remove_lock     Remove the lock to allow a new process to run
 --save_tmpfiles   Save the temp files used for loading the database
 --manual          Detailed manual pages
 --webupload       Indicates that genome is user uploaded. Loads to private tables.
 --use_fasta_names Use headers in fasta file to name chromosomes rather than searching for names in DB cache.

=head1 DESCRIPTION

A contig_collection is the parent label used for a set of DNA sequences belonging to a 
single project (which may be a WGS or a completed whole genome sequence). Global properties 
such as strain, host etc are defined at the contig_collection level.  The contig_collection 
properties are defined in a hash that is written to file using Data::Dumper. Multiple values
are permitted for any data type with the exception of name or uniquename.  Multiple values are
passed as an array ref. The first item on the list is assigned rank 0, and so on.

Each sequence in the fasta files is labelled as a contig (whether is its a chromosome or true contig). 
The contig properties are obtained from the fasta file. Names for the contigs are obtained from 
the accessions in the fasta file.  The fasta file header lines are also used to define the mol_type 
as chromosome or plasmid.
  
=head2 Properties

	my %genome_properties = (
		name => 'lambda',
		uniquename => 'beta',
		mol_type => 'dna',
		serotype => 'O157:H3',
		strain => 'K12',
		keywords => 'a, really, bad, strain',
		isolation_host => 'H. sapiens',
		isolation_location => 'Canada',
		isolation_source => 'Blood'
		synonym => 'gamma',
		isolation_date => '1999-03-13',
		description => 'Its a genome!!',
		comment => 'infection from someone\'s nasty hot tub',
		owner => 'kermit the frog',
		isolation_age => 123.34,
		finished => 'yes',
		primary_dbxref => {
			db => 'refseq',
			acc => '12345',
			ver => '1',
			desc => 'Second home'
		},
		secondary_dbxref => {
			db => 'MyNCBI',
			acc => '12345',
			ver => '1',
			desc => 'Its second home'
		},
		pmid => [123456, 78901010]
	);
	
	# upload_params are only needed for a user uploaded sequence
	my %upload_params = (
		category => 'release',
		login_id => 10,
		tag => 'Isolates from Zombie Outbreak',
		release_date => '2013-05-31'
	);
	
	open(OUT,">dump.txt");
	print OUT Data::Dumper->Dump([\%genome_properties, \%upload_params], ['contig_collection_properties', 'upload_parameters']);
	close OUT;

=head2 NOTES

=over

=item Transactions

This application will, by default, try to load all of the data at
once as a single transcation.  This is safer from the database's
point of view, since if anything bad happens during the load, the 
transaction will be rolled back and the database will be untouched.

=item The run lock

The loader is not a multiuser application.  If two separate
bulk load processes try to load data into the database at the same
time, at least one and possibly all loads will fail.  To keep this from
happening, the bulk loader places a lock in the database to prevent
other processes from running at the same time.
When the application exits normally, this lock will be removed, but if
it crashes for some reason, the lock will not be removed.  To remove the
lock from the command line, provide the flag --remove_lock.  Note that
if the loader crashed necessitating the removal of the lock, you also
may need to rebuild the uniquename cache (see the next section).

=item The uniquename cache

The loader uses the chado database to create a table that caches
feature_ids, uniquenames, type_ids, and organism_ids of the features
that exist in the database at the time the load starts and the
features that will be added when the load is complete.  If it is possilbe
that new features have been added via some method that is not this
loader (eg, Apollo edits or loads with XORT) or if a previous load using
this loader was aborted, then you should supply
the --recreate_cache option to make sure the cache is fresh.

=back

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Adapted from original package developed by 
Allen Day E<lt>allenday@ucla.eduE<gt>, Scott Cain E<lt>scain@cpan.orgE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($CONFIGFILE, $ROOT, $NOLOAD,
    $RECREATE_CACHE, $SAVE_TMPFILES,
    $MANPAGE, $DEBUG,
    $REMOVE_LOCK,
    $VACUUM,
    $LOGFILE,
    $DEMO);

GetOptions(
	'config=s' => \$CONFIGFILE,
    'dir=s' => \$ROOT,
    'noload' => \$NOLOAD,
    'recreate_cache'=> \$RECREATE_CACHE,
    'remove_lock'  => \$REMOVE_LOCK,
    'save_tmpfiles'=>\$SAVE_TMPFILES,
    'manual' => \$MANPAGE,
    'debug' => \$DEBUG,
    'vacuum' => \$VACUUM,
    'log=s' => \$LOGFILE,
    'demo'  => \$DEMO
) 
or pod2usage(-verbose => 1, -exitval => 1);
pod2usage(-verbose => 2, -exitval => 1) if $MANPAGE;


$SIG{__DIE__} = $SIG{INT} = 'cleanup_handler';

croak "You must supply the path to the top-level results directory" unless $ROOT;
$ROOT .= '/' unless $ROOT =~ m/\/$/;
my $MINFASTASIZE = 3500000; # Fasta file must pass this threshold

# Initialize the chado adapter
my %argv;

$argv{config}           = $CONFIGFILE;
$argv{noload}           = $NOLOAD;
$argv{recreate_cache}   = $RECREATE_CACHE;
$argv{save_tmpfiles}    = $SAVE_TMPFILES;
$argv{vacuum}           = $VACUUM;
$argv{debug}            = $DEBUG;
$argv{feature_type}     = 'genome'; # Concurrently load pangenome, vfamr and genome features

my $chado = Sequences::ExperimentalFeatures->new(%argv);

# Lock table so no one else can upload
$chado->remove_lock() if $REMOVE_LOCK;
$chado->place_lock();
my $lock = 1;

# Prepare tmp files for storing upload data
$chado->file_handles();

# Basic log
my $log;
if($LOGFILE) {
	open $log, ">$LOGFILE" or die;
}

logit("START of genome_fasta_loader.pl log -- Loading genomes into DB", 1);

# Load genome sequences and meta data
genomes();

# Finalize and load into DB
logit("DB loading...");
unless ($NOLOAD) {
	$chado->load_data();
}
logit("complete.");

# Update genome locations

logit("Update of genome locations...");
unless($NOLOAD) {
	my @opts = ("perl $FindBin::Bin/../Data/superphy_update_location_latlong.pl", "--config $CONFIGFILE");
	my $cmd = join(' ', @opts);
	system($cmd) == 0 or die "Error: $cmd failed.\n";
}
logit("complete.");

# Compute checksums
logit("Update of genome contig checksums...");
my $fp = Modules::Footprint->new(dbh => $chado->dbh);
$fp->loadPublicFootprints();
logit("complete.");


$chado->remove_lock();

logit("END", 1);

exit(0);


=head2 cleanup_handler


=cut

sub cleanup_handler {
    warn "@_\nAbnormal termination, trying to clean up...\n\n" if @_;  
    #gets the message that the die signal sent if there is one
    if ($chado && $chado->dbh->ping) {
        
        if ($lock) {
            warn "Trying to remove the run lock (so that --remove_lock won't be needed)...\n";
            $chado->abort(); #remove any active locks, discard DB transaction
        }
        
        print STDERR "Exiting...\n";
    }
    exit(1);
}


=head2 genomes 

=cut

sub genomes {

	my $meta_dir = $ROOT . 'meta/';
	my $fasta_dir = $ROOT . 'fasta/';
	my $gbk_dir = $ROOT . 'genbank/';
	my $job_file = $ROOT . 'file_names.txt';

	# Load filenames
	my @jobs;
	open(IN, "<$job_file") or croak "Error: unable to read job file $job_file ($!).\n";
	while(<IN>) {
		chomp;
		push @jobs, $_;
	}
	close IN;

	# Only use first ~500 in demo
	@jobs = @jobs[0..500] if $DEMO;

	logit(scalar(@jobs)." genomes will be loaded.");

	foreach my $jobid (@jobs) {

		logit("Loading $jobid...");
		my $fasta_file = "$fasta_dir/$jobid.fasta";
		my $gbk_file = "$gbk_dir/$jobid\_fixed.gbk";
		my $prop_file = "$meta_dir/$jobid.txt";

		croak "Error: fasta file $fasta_file missing." unless -e $fasta_file && -f $fasta_file;

		croak "Error: genbank file $gbk_file missing." unless -e $gbk_file && -f $gbk_file;

		# Check length
		my $sz = -s $fasta_file;
		if($sz < $MINFASTASIZE) {
			logit("SKIPPING, genome too small <$sz>");
			next;
		} else {
			logit("Fasta size: $sz");
		}

		# Parse genbank file
		my @opts = ("$FindBin::Bin/genbank_to_genodo.pl", "--config $CONFIGFILE", "--prop $prop_file", "--gb $gbk_file");
		my $cmd = join(" ", @opts);
		my $rs = system($cmd);

		if($rs) {
			logit("\tSKIPPING, genbank mapping failed");
			next;
		} else {
			logit("\tgenbank mapping complete");
		}

		my ($genome_feature_properties) = load_input_parameters($prop_file);

		# Validate genome parameters
		my ($f, $fp, $dx) = validate_genome_properties($genome_feature_properties);

		logit("\tloading & validation complete");

		$rs = sufficient_meta_annotations($fp);
		unless($rs) {
			logit("\tSKIPPING, insufficient meta-data");
			next;
		} else {
			logit("\tmeta-data check complete");
		}


		# Contig collection feature
		my $is_public = 1;
	
		# Feature type of parent: contig_collection
		my $type = $chado->feature_types('contig_collection');
		
		# Feature_id 
		my $curr_feature_id = $chado->nextfeature($is_public);
		
		# Uniquename
		my $uniquename = $f->{'uniquename'};

		
		# Verifies if name is unique, otherwise modify uniquename so that it is unique
		# Note: not to be used for update-checks based on uniquename
		$uniquename = $chado->genome_uniquename($uniquename, $curr_feature_id, $is_public);
		    
		## Note uniquename may have changed and changed name will have been cached. Do we need to know original?
		
		# Name
		my $name = $f->{name};
		
		# Sequence Length
		my $seqlen = '\N';
		# Residues
		my $residues = '\N';
		
		
		# Properties
		if(%$fp) {
			$chado->handle_genome_properties($curr_feature_id, $fp, $is_public);
		}
		
		# Dbxref
		my $dbxref_id = '\N';
		if(%$dx) {
			$dbxref_id = $chado->handle_dbxref($curr_feature_id, $dx, $is_public);
		}

		# Print  
		$chado->print_f($curr_feature_id, $chado->organism_id, $name, $uniquename, $type, $seqlen, 
			$dbxref_id, $residues, $is_public);  
		$chado->nextfeature($is_public, '++');

		logit("\tgenome complete");

		# Load contigs
		my $fasta = Bio::SeqIO->new(-file   => $fasta_file, -format => 'fasta');
                              
    	my $numc = 0;
		while (my $entry = $fasta->next_seq) {
			$numc++ if load_contig($entry, $curr_feature_id, $uniquename);
		}

		logit("\t$numc contigs loaded");

	
		logit("SUCCESSful loading of $jobid.\n");

	}

}

=head2 load_input_parameters

loads hash produced by Data::Dumper with genome properties and upload user settings.

=cut

sub load_input_parameters {
	my $file = shift;
	
	open(IN, "<$file") or die "Error: unable to read file $file ($!).\n";

    local($/) = "";
    my($str) = <IN>;
    
    close IN;
    
    my $contig_collection_properties;
    eval $str;
    
    return ($contig_collection_properties);
}

=head2 validate_genome_properties

Examines data hash containing genome properties.
Makes sure keys are recognized and then splits data
into separate hashes corresponding to each DB table.

Returns

List of 3 data hashrefs contains key value pairs of:
1. Feature table properties
2. Featureprop table properties
3. Dbxref table properties

=cut

sub validate_genome_properties {
	my $hash = shift;
	
	my %valid_f_tags = qw/name 1 uniquename 1 organism 1 properties 1/;
	my %valid_fp_tags = qw/mol_type 1 serotype 1 strain 1 keywords 1 isolation_host 1 
		isolation_date 1 description 1 owner 1 finished 1 synonym 1
		comment 1 isolation_source 1 isolation_age 1 severity 1
		syndrome 1 pmid 1/;
	my %valid_dbxref_tags = qw/primary_dbxref 1 secondary_dbxref 1/;
	my %valid_l_tags = qw/isolation_location 1/; 
	
	# Make sure no unrecognized property types
	# Assign value to proper table hash
	my %f; my %fp; my %dx;
	foreach my $type (keys %$hash) {
		
		if($valid_f_tags{$type}) {
			if(ref $hash->{$type} eq 'ARRAY') {
				# Some scripts return every value as arrayref
				# Feature values are always singletons, so this
				# should be safe
				# There is no logical option for multiple names
				$f{$type} = pop @{$hash->{$type}}
			} else {
		
				$f{$type} = $hash->{$type};
			}
			
		} elsif($valid_fp_tags{$type}) {
			$fp{$type} = $hash->{$type};
			
		} elsif($valid_l_tags{$type}) {
			# Save locations as raw text under fp hash.
			# Will call genodo_update_location_latlong.pl after load
			# fill in correctly formatted locations
			$fp{$type} = $hash->{$type};

		} elsif($valid_dbxref_tags{$type}) {
			# Must supply hash with keys: acc, db
			# Optional: ver, desc
			
			my @entries;
			
			if(ref $hash->{$type} eq 'ARRAY') {
				@entries = @{$hash->{$type}}
			} else {
				@entries = ($hash->{$type});
			}
			
			foreach my $dbxref (@entries) {
				my $db = $dbxref->{db};
				croak 'Must provide a DB for foreign IDs.' unless $db;
				
				my $acc = $dbxref->{acc};
				croak 'Must provide a accession for foreign IDs.' unless $acc;
				
				my $ver = $dbxref->{ver};
				$ver ||= '';
				
				my $desc = $dbxref->{desc};
				$desc ||= '\N';
				
				if($type eq 'primary_dbxref') {
					croak 'Primary foreign ID re-defined.' if defined($dx{primary});
					$dx{primary} = { db => $db, acc => $acc, ver => $ver, desc => $desc };
				} else {
					$dx{secondary} = [] unless $dx{secondary};
					push @{$dx{secondary}}, { db => $db, acc => $acc, ver => $ver, desc => $desc };
				}
			}
			
		} else {
			croak "Invalid genome property type $type.";
		}
	}
	
	# Required types, no default values.
	croak 'Missing required genome property "uniquename".' unless $f{uniquename};
	croak 'Missing primary foreign ID (only required when secondary foreign ID defined)' if defined($dx{secondary}) && !defined($dx{primary});
	
	
	# Initialize other required properties with default values
	$f{name} = $f{uniquename} unless $f{name};
	if($f{organism}) {
		croak "Unexpected organism: $f{organism}.\n" unless $f{organism} eq 'Escherichia coli';
	} else {
		$f{organism} = 'Escherichia coli';
	}
	
	$fp{mol_type} = 'dna' unless $fp{mol_type};
	
	return(\%f, \%fp, \%dx);
}


=head2 sufficient_meta_annotations

Counts specific meta-data annotations in
data hash containing genome properties. 

Returns boolean
true => 1 or more meta-data annotations
false => 0 meta-data annotations

=cut

sub sufficient_meta_annotations {
	my $fp = shift;

	# Terms to look for in genome annotation
	my @tags = qw(
		serotype
		isolation_date
		isolation_location
		isolation_host
		isolation_source
		syndrome
	);

	my $count = 0;
		
	foreach my $tag (@tags) {
		if(defined $fp->{$tag}) {
			$count++;
		}
	}

	return($count > 0);
}

sub load_contig {
	my ($contig, $cc_id, $cc_uniquename) = @_;

	my $is_public = 1;
	
	# Feature type of child: contig
	my $type = $chado->feature_types('contig');
	
	# Feature_id 
	my $curr_feature_id = $chado->nextfeature($is_public);
		
	# Name
	my $name = $contig->display_id;
	
	# Description
	my $desc = $contig->description;
	
	# Sequence Length
	my $seqlen = $contig->length;

	# Residues
	my $residues = $contig->seq();
	
	
	# DBxref
	my $dbxref = '\N';
	
	# Contig properties
	my %contig_fp;
	
	# mol_type
	# if plasmid or chromosome is in header, change default
	my $mol_type = 'dna';
	
	# description
	if($desc) {
		# if plasmid or chromosome is in header, change default
		if($desc =~ m/plasmid/i || $name =~ m/plasmid/i) {
			$mol_type = 'plasmid';
		} elsif($desc =~ m/chromosome/i || $name =~ m/chromosome/i) {
			$mol_type = 'chromosome';
		}
	
		$contig_fp{description} = $desc;
	} else {
		if($name =~ m/plasmid/i) {
			$mol_type = 'plasmid';
		} elsif($name =~ m/chromosome/i) {
			$mol_type = 'chromosome';
		}
	}
	$contig_fp{mol_type} = $mol_type;
	
	$chado->handle_genome_properties($curr_feature_id, \%contig_fp, $is_public);
	
	# Create unique contig name derived from contig_collection uniquename
	# Since contig_collection uniquename is guaranteed unique, contig name should be unique.
	# Saves us from doing a DB query on the many contigs that could be in the fasta file.
	my $uniquename = $name;
	$uniquename .= "- part_of:$cc_uniquename";
	

	# Feature relationships
	$chado->handle_parent(subject => $curr_feature_id, genome => $cc_id, public => 1);


	# Print
	$chado->print_f($curr_feature_id, $chado->organism_id, $name, $uniquename, $type, $seqlen, $dbxref, $residues, $is_public);  
	$chado->nextfeature($is_public, '++');

	return 1;
}

sub logit {
	my $msg = shift;
	my $incl_dt = shift;

	if($incl_dt) {
		my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
		$msg = "$date: $msg"
	}
	
	print $log $msg."\n" if $log;
}

=cut

my ($CONFIGFILE, $FASTAFILE, $PROPFILE, $NOLOAD,
    $RECREATE_CACHE, $SAVE_TMPFILES,
    $MANPAGE, $DEBUG,
    $REMOVE_LOCK,
    $DBNAME, $DBUSER, $DBPASS, $DBHOST, $DBPORT, $DBI, $TMPDIR,
    $VACUUM,
    $WEBUPLOAD, $TRACKINGID, $NONAMECACHE);

GetOptions(
	'config=s'=> \$CONFIGFILE,
    'fasta=s'=> \$FASTAFILE,
    'attributes=s'=> \$PROPFILE,
    'noload'     => \$NOLOAD,
    'recreate_cache'=> \$RECREATE_CACHE,
    'remove_lock'   => \$REMOVE_LOCK,
    'save_tmpfiles'=>\$SAVE_TMPFILES,
    'manual'   => \$MANPAGE,
    'debug'   => \$DEBUG,
    'vacuum'  => \$VACUUM,
    'webupload' => \$WEBUPLOAD,
    'tracking_id:s' => \$TRACKINGID,
    'use_fasta_names' => \$NONAMECACHE
) 

or pod2usage(-verbose => 1, -exitval => 1);
pod2usage(-verbose => 2, -exitval => 1) if $MANPAGE;

$SIG{__DIE__} = $SIG{INT} = 'cleanup_handler';

croak "You must supply an fasta filename" unless $FASTAFILE;

# Load database connection info from config file
die "You must supply a configuration filename" unless $CONFIGFILE;
if(my $db_conf = new Config::Simple($CONFIGFILE)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
	$TMPDIR    = $db_conf->param('tmp.dir');
} else {
	die Config::Simple->error();
}
croak "Invalid configuration file." unless $DBNAME;

# Load the hash containing parent genome feature properties
# Values defined in the user form
croak "You must supply a genome properties filename" unless $PROPFILE;
my ($genome_feature_properties, $upload_params) = load_input_parameters($PROPFILE);

my ($f, $fp, $dx) = validate_genome_properties($genome_feature_properties);

# Initialize the chado adapter
my %argv;

$argv{fastafile}       = $FASTAFILE;
$argv{dbname}          = $DBNAME;
$argv{dbuser}          = $DBUSER;
$argv{dbpass}          = $DBPASS;
$argv{dbhost}          = $DBHOST;
$argv{dbport}          = $DBPORT;
$argv{dbi}             = $DBI;
$argv{tmp_dir}         = $TMPDIR;
$argv{noload}          = $NOLOAD;
$argv{recreate_cache}  = $RECREATE_CACHE;
$argv{save_tmpfiles}   = $SAVE_TMPFILES;
$argv{vacuum}          = $VACUUM;
$argv{debug}           = $DEBUG;
$argv{use_fasta_names} = $NONAMECACHE;
                       
my $chado = Sequences::Adapter->new(%argv);


# Lock table so no one else can upload
$chado->remove_lock() if $REMOVE_LOCK;
$chado->place_lock();
my $lock = 1;


# Prepare tmp files for storing upload data
$chado->file_handles();


# Save data for inserting into database
warn "Preparing data for inserting into the $DBNAME database\n";
warn "(This may take a while ...)\n";

# Create parent feature: contig_collection
contig_collection($f, $fp, $dx);


# Create child features from FASTA file (i.e. contigs)
my $in = Bio::SeqIO->new(-file   => $FASTAFILE,
                         -format => 'fasta');
                              
while (my $entry = $in->next_seq) {
	
	contig($entry);
}

# Finalize and load into DB
$chado->end_files();

$chado->flush_caches();

$chado->load_data() unless $NOLOAD;

$chado->remove_lock();

exit(0);

=cut

=head2 cleanup_handler

=over

=item Usage

  cleanup_handler

=item Function

Removes table lock and any entries added to the uniquename change in tmp table.

=item Returns

void

=item Arguments

filename of Data::Dumper file containing data hash.

=back

 =cut

sub cleanup_handler {
    warn "@_\nAbnormal termination, trying to clean up...\n\n" if @_;  #gets the message that the die signal sent if there is one
    if ($chado && $chado->dbh->ping) {
        
        $chado->cleanup_tmp_table;
        if ($lock) {
            warn "Trying to remove the run lock (so that --remove_lock won't be needed)...\n";
            $chado->remove_lock; #remove the lock only if we've set it
        }
        
        print STDERR "Exiting...\n";
    }
    exit(1);
}

=cut

=head2 load_input_parameters

=over

=item Usage

  my $properties_hash = load_input_parameters($filename)

=item Function

loads hash produced by Data::Dumper with genome properties and upload user settings.

=item Returns

A hash of containing property types and values

=item Arguments

filename of Data::Dumper file containing data hash.

=back

 =cut

sub load_input_parameters {
	my $file = shift;
	
	open(IN, "<$PROPFILE") or die "Error: unable to read file $PROPFILE ($!).\n";

    local($/) = "";
    my($str) = <IN>;
    
    close IN;
    
    my $contig_collection_properties;
    my $upload_parameters;
    eval $str;
    
    return ($contig_collection_properties, $upload_parameters);
}

=head2 validate_genome_properties

=over

=item Usage

  my $rv = validate_genome_properties($hash_ref)

=item Function

Examines data hash containing genome properties.
Makes sure keys are recognized and then splits data
into separate hashes corresponding to each DB table.

=item Returns

List of 3 data hashrefs contains key value pairs of:
1. Feature table properties
2. Featureprop table properties
3. Dbxref table properties

=item Arguments

A hashref containing all input parameters

=back

 =cut

sub validate_genome_properties {
	my $hash = shift;
	
	my %valid_f_tags = qw/name 1 uniquename 1 organism 1 properties 1/;
	my %valid_fp_tags = qw/mol_type 1 serotype 1 strain 1 keywords 1 isolation_host 1 
		isolation_location 1 isolation_date 1 description 1 owner 1 finished 1 synonym 1
		comment 1 isolation_source 1 isolation_latlng 1 isolation_age 1 severity 1
		syndrome 1 pmid 1/;
	my %valid_dbxref_tags = qw/primary_dbxref 1 secondary_dbxref 1/;
	
	# Make sure no unrecognized property types
	# Assign value to proper table hash
	my %f; my %fp; my %dx;
	foreach my $type (keys %$hash) {
		
		if($valid_f_tags{$type}) {
			if(ref $hash->{$type} eq 'ARRAY') {
				# Some scripts return every value as arrayref
				# Feature values are always singletons, so this
				# should be safe
				# There is no logical option for multiple names
				$f{$type} = pop @{$hash->{$type}}
			} else {
		
				$f{$type} = $hash->{$type};
			}
			
		} elsif($valid_fp_tags{$type}) {
			$fp{$type} = $hash->{$type};
			
		} elsif($valid_dbxref_tags{$type}) {
			# Must supply hash with keys: acc, db
			# Optional: ver, desc
			
			my @entries;
			
			if(ref $hash->{$type} eq 'ARRAY') {
				@entries = @{$hash->{$type}}
			} else {
				@entries = ($hash->{$type});
			}
			
			foreach my $dbxref (@entries) {
				my $db = $dbxref->{db};
				croak 'Must provide a DB for foreign IDs.' unless $db;
				
				my $acc = $dbxref->{acc};
				croak 'Must provide a accession for foreign IDs.' unless $acc;
				
				my $ver = $dbxref->{ver};
				$ver ||= '';
				
				my $desc = $dbxref->{desc};
				$desc ||= '\N';
				
				if($type eq 'primary_dbxref') {
					croak 'Primary foreign ID re-defined.' if defined($dx{primary});
					$dx{primary} = { db => $db, acc => $acc, ver => $ver, desc => $desc };
				} else {
					$dx{secondary} = [] unless $dx{secondary};
					push @{$dx{secondary}}, { db => $db, acc => $acc, ver => $ver, desc => $desc };
				}
			}
			
		} else {
			croak "Invalid genome property type $type.";
		}
	}
	
	# Required types, no default values.
	croak 'Missing required genome property "uniquename".' unless $f{uniquename};
	croak 'Missing primary foreign ID (only required when secondary foreign ID defined)' if defined($dx{secondary}) && !defined($dx{primary});
	
	
	# Initialize other required properties with default values
	$f{name} = $f{uniquename} unless $f{name};
	$f{organism} = 'Escherichia coli' unless $f{organism};
	$fp{mol_type} = 'dna' unless $fp{mol_type};
	
	return(\%f, \%fp, \%dx);
}

=head2 validate_upload_parameters

=over

=item Usage

  my $rv = validate_upload_parameters
=item Function

Examines data hash containing upload parameters.

=item Returns

Also initializes some required parameters
that have default values in the hash ref.

=item Arguments

Ref to data hash

=back

 =cut

sub validate_upload_parameters {
	my $hash = shift;
	
	my @valid_parameters = qw/login_id tag release_date upload_date category/;
		
	my %valid;
	map { $valid{$_} = 1 } @valid_parameters;
	
	# Make sure no unrecognized parameters
	foreach my $type (keys %$hash) {
		croak "Invalid upload parameter $type." unless $valid{$type};
	}
	
	# Required parameters, no default values.
	croak 'Missing required upload parameter "category".' unless $hash->{category};
	my %valid_cats = (public => 1, private => 1, release => 1);
	croak "Invalid category: ".$hash->{category} unless $valid_cats{$hash->{category}};
	
	if($hash->{category} eq 'release') {
		croak 'Missing required upload parameter "release_date".' unless $hash->{release_date};
	}
	
	# Set default parameters
	$hash->{login_id} = 0 unless $hash->{login_id};
	
	unless($hash->{upload_date}) {
		my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
		$hash->{upload_date} = $date;
	}
	$hash->{tag} = 'Unclassified' unless $hash->{tag};
	
	return(1);
}

=head2 contig_collection


 =cut

sub contig_collection {
	my ($f, $fp, $dx) = @_;
	
	# Make sure organism is one of the permitted Organisms
	$chado->organism('common_name' => $f->{organism});
	
	# Feature type of parent: contig_collection
	my $type = $chado->feature_types('contig_collection');
	
	# Feature_id 
	my $curr_feature_id = $chado->nextfeature();
	
	# Uniquename
	my $uniquename = $f->{'uniquename'};
	
	# Verifies if name is unique, otherwise modify uniquename so that it is unique.
	$uniquename = $chado->uniquename_validation($uniquename,
		$type,
	    $curr_feature_id);
	    
	## Note uniquename may have changed and changed name will have been cached. Do we need to know original?
	
	# Name
	my $name = $f->{name};
	
	# Sequence Length
	my $seqlen = '\N';
	# Residues
	my $residues = '\N';
	
	
	# Properties
	if(%$fp) {
		$chado->handle_reserved_properties($curr_feature_id, $fp);
	}
	
	
	# Dbxref
	if(%$dx) {
		$chado->handle_dbxref($curr_feature_id, $dx);
	}
	
	
	# Save as parent
	$chado->cache('const', 'contig_collection_id', $curr_feature_id);
	$chado->cache('const', 'contig_collection_uniquename', $uniquename);
	
	# Print  
	$chado->print_f($curr_feature_id, $chado->organism, $name, $uniquename, $type, $seqlen, $chado->cache('source', $curr_feature_id), $residues);  
	$chado->nextfeature('++');
	
}

=head2 contig


 =cut

sub contig {
	my ($contig) = @_;
	
	# Feature type of child: contig
	my $type = $chado->feature_types('contig');
	
	
	# Feature_id 
	my $curr_feature_id = $chado->nextfeature();
	
	my $name;
	my $desc;
	my $chr_num;
	
	if($NONAMECACHE) {
		# Get description and name from FASTA header
		
		# Uniquename and name
		$name = $contig->display_id;
		
		# Description
		$desc = $contig->description
		
	} else {
		# Get the user-submitted description and name from DB cache
		
		my $tmp_id = $contig->display_id;
		(my $trk_id, $chr_num) = ($tmp_id =~ m/lcl\|upl_(\d+)\|(\d+)/);
		
		croak "Invalid temporary ID ($tmp_id) for contig." unless $trk_id && $chr_num;
		croak "Tracking ID in temporary ID does not match supplied tracking ID ($tmp_id, $TRACKINGID)" unless $trk_id == $TRACKINGID;
		
		($name, $desc) = $chado->retrieve_chr_info($trk_id, $chr_num);
	}

	# Sequence Length
	my $seqlen = $contig->length;
	# Residues
	my $residues = $contig->seq();
	
	
	# DBxref
	my $dbxref = '\N';
	
	
	# Contig properties
	my %contig_fp;
	
	# mol_type
	# if plasmid or chromosome is in header, change default
	my $mol_type = 'dna';
	
	# description
	if($desc) {
		# if plasmid or chromosome is in header, change default
		if($desc =~ m/plasmid/i || $name =~ m/plasmid/i) {
			$mol_type = 'plasmid';
		} elsif($desc =~ m/chromosome/i || $name =~ m/chromosome/i) {
			$mol_type = 'chromosome';
		}
	
		$contig_fp{description} = $desc;
	} else {
		if($name =~ m/plasmid/i) {
			$mol_type = 'plasmid';
		} elsif($name =~ m/chromosome/i) {
			$mol_type = 'chromosome';
		}
	}
	$contig_fp{mol_type} = $mol_type;
	
	$chado->handle_reserved_properties($curr_feature_id, \%contig_fp);
	
	# Create unique contig name derived from contig_collection uniquename
	# Since contig_collection uniquename is guaranteed unique, contig name should be unique.
	# Saves us from doing a DB query on the many contigs that could be in the fasta file.
	my $uniquename = $name;
	my $cc_name = $chado->cache('const','contig_collection_uniquename');
	$uniquename .= "- part_of:$cc_name";
	
	
	# Feature relationships
	$chado->handle_parent($curr_feature_id);
	
	
	# Print  
	$chado->print_f($curr_feature_id, $chado->organism, $name, $uniquename, $type, $seqlen, $dbxref, $residues);  
	$chado->nextfeature('++');
	
	# Cache feature ID for newly loaded contig
	unless($NONAMECACHE) {
		$chado->cache_contig_id($TRACKINGID, $curr_feature_id, $chr_num);
	}
	
}


