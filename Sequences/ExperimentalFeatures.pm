package Sequences::ExperimentalFeatures;

use strict;

use Inline (Config =>
			DIRECTORY => $ENV{"SUPERPHY_INLINEDIR"} || $ENV{"HOME"}.'/Inline' );
use Inline 'C';
Inline->init;

use warnings;

use DBI;
use Carp qw/croak carp confess/;
use Sys::Hostname;
use File::Temp;
use Time::HiRes qw( time );
use Data::Dumper;
use File::Basename;
use lib dirname (__FILE__) . "/../";
use Phylogeny::Typer;
use Phylogeny::Tree;
use Phylogeny::TreeBuilder;
use Modules::FormDataGenerator;
use Data::Bridge;
use Data::Grouper;
use JSON qw/encode_json/;
use IO::CaptureOutput qw(capture_exec);
use Config::Tiny;
use POSIX qw(strftime);
use List::Util qw(any);

=head1 NAME

Sequences::ExperimentalFeatures;

=head1 DESCRIPTION

Based on perl package: Bio::GMOD::DB::Adapter

Provides interface to CHADO database for loading Genodo data.

=cut

my $DEBUG = 0;
my $root_directory = dirname (__FILE__) . "/../";

# Pangenome content cutoffs
my $CORE_REGION_CUTOFF = 1500;
my $ORGANISM_MARKER_CUTOFF = 3;

# Tables in order that data is inserted
my @tables = (
	"upload",
	"permission",
	"feature",
	"private_feature",
	"feature_relationship",
	"private_feature_relationship",
	"pripub_feature_relationship",
	"feature_cvterm",
	"private_feature_cvterm",
	"featureloc",
	"private_featureloc",
	"featureprop",
	"private_featureprop",
	"genome_location",
	"private_genome_location",
	"db",
	"dbxref",
	"feature_dbxref",
	"tree",
	"feature_tree",
	"private_feature_tree",
	"snp_core",
	"snp_variation",
	"private_snp_variation",
	"snp_position",
	"private_snp_position",
	"gap_position",
	"private_gap_position",
	"core_region",
	"accessory_region",
	"feature_group",
	"private_feature_group",
);

# Tables in order that data is updated
my @update_tables = (
	"tfeature",
	"tprivate_feature",
	"tfeatureloc",
	"tprivate_featureloc",
	"tfeatureprop",
	"tprivate_featureprop",
	"ttree",
	"tsnp_core",
	"tsnp_core2"
);

my %update_table_names = (
	"tfeature" => 'feature',
	"tprivate_feature" => 'private_feature',
	"tfeatureloc" => 'featureloc',
	"tprivate_featureloc" => 'tprivate_featureloc',
	"tfeatureprop" => 'featureprop',
	"tprivate_featureprop" => 'private_featureprop',
	"ttree" => 'tree',
	"tsnp_core" => 'snp_core',
	"tsnp_core2" => 'snp_core'
);

# Primary key sequence names
my %sequences = (
	feature                      => "feature_feature_id_seq",
	feature_relationship         => "feature_relationship_feature_relationship_id_seq",
	featureprop                  => "featureprop_featureprop_id_seq",
	featureloc                   => "featureloc_featureloc_id_seq",
	feature_cvterm               => "feature_cvterm_feature_cvterm_id_seq",
	private_feature              => "private_feature_feature_id_seq",
	private_feature_relationship => "private_feature_relationship_feature_relationship_id_seq",
	pripub_feature_relationship  => "pripub_feature_relationship_feature_relationship_id_seq",
	private_featureprop          => "private_featureprop_featureprop_id_seq",
	private_featureloc           => "private_featureloc_featureloc_id_seq",
	private_feature_cvterm       => "private_feature_cvterm_feature_cvterm_id_seq",
	tree                         => "tree_tree_id_seq",
	feature_tree                 => "feature_tree_feature_tree_id_seq",
  	private_feature_tree         => "private_feature_tree_feature_tree_id_seq",
  	snp_core                     => "snp_core_snp_core_id_seq",
  	snp_variation                => "snp_variation_snp_variation_id_seq",
  	private_snp_variation        => "private_snp_variation_snp_variation_id_seq",
  	snp_position                 => "snp_position_snp_position_id_seq",
  	private_snp_position         => "private_snp_position_snp_position_id_seq",
  	gap_position                 => "gap_position_gap_position_id_seq",
  	private_gap_position         => "private_gap_position_gap_position_id_seq",
  	core_region                  => "core_region_core_region_id_seq",
  	accessory_region             => "accessory_region_accessory_region_id_seq",
  	upload                       => "upload_upload_id_seq",
    db                           => "db_db_id_seq",
    dbxref                       => "dbxref_dbxref_id_seq",
    feature_dbxref               => "feature_dbxref_feature_dbxref_id_seq",
    permission                   => "permission_permission_id_seq",
    feature_group                => "feature_group_feature_group_id_seq",
    private_feature_group        => "private_feature_group_feature_group_id_seq",
);

# Primary key ID names
my %table_ids = (        
	feature                      => "feature_id",
	feature_relationship         => "feature_relationship_id",
	featureprop                  => "featureprop_id",
	featureloc                   => "featureloc_id",
    feature_cvterm               => "feature_cvterm_id",
    private_feature              => "feature_id",
	private_feature_relationship => "feature_relationship_id",
	pripub_feature_relationship  => "feature_relationship_id",
	private_featureprop          => "featureprop_id",
	private_featureloc           => "featureloc_id",
    private_feature_cvterm       => "feature_cvterm_id",
    tree                         => "tree_id",
    feature_tree                 => "feature_tree_id",
  	private_feature_tree         => "feature_tree_id",
  	snp_core                     => "snp_core_id",
  	snp_variation                => "snp_variation_id",
  	private_snp_variation        => "snp_variation_id",
  	snp_position                 => "snp_position_id",
  	private_snp_position         => "snp_position_id",
  	gap_position                 => "gap_position_id",
  	private_gap_position         => "gap_position_id",
  	core_region                  => "core_region_id",
  	accessory_region             => "accessory_region_id",
  	db                           => "db_id",
	dbxref                       => "dbxref_id",
	feature_dbxref               => "feature_dbxref_id",
	upload                       => "upload_id",
	permission                   => "permission_id",
	feature_group                => "feature_group_id",
    private_feature_group        => "feature_group_id",
);

# Valid cvterm types for featureprops table
# hash: name => cv
my %fp_types = (
	copy_number_increase => 'sequence',
	match => 'sequence',
	panseq_function => 'local',
	stx1_subtype => 'local',
	stx2_subtype => 'local',
	mol_type => 'feature_property',
	keywords => 'feature_property',
	description => 'feature_property',
	owner => 'feature_property',
	finished => 'feature_property',
	strain => 'local',
	serotype => 'local',
	isolation_host => 'local',
	isolation_location => 'local',
	isolation_date => 'local',
	synonym => 'feature_property',
	comment => 'feature_property',
	isolation_source => 'local',
	isolation_age => 'local',
	#isolation_latlng => 'local',
	syndrome => 'local',
	pmid     => 'local'
);

# Used in DB COPY statements
my %copystring = (
   feature                      => "(feature_id,organism_id,name,uniquename,type_id,seqlen,dbxref_id,residues)",
   feature_relationship         => "(feature_relationship_id,subject_id,object_id,type_id,rank)",
   featureprop                  => "(featureprop_id,feature_id,type_id,value,rank)",
   feature_cvterm               => "(feature_cvterm_id,feature_id,cvterm_id,pub_id,is_not,rank)",
   featureloc                   => "(featureloc_id,feature_id,srcfeature_id,fmin,fmax,strand,locgroup,rank)",
   private_feature              => "(feature_id,organism_id,name,uniquename,type_id,seqlen,dbxref_id,upload_id,residues)",
   private_feature_relationship => "(feature_relationship_id,subject_id,object_id,type_id,rank)",
   pripub_feature_relationship  => "(feature_relationship_id,subject_id,object_id,type_id,rank)",
   private_featureprop          => "(featureprop_id,feature_id,type_id,value,upload_id,rank)",
   private_feature_cvterm       => "(feature_cvterm_id,feature_id,cvterm_id,pub_id,is_not,rank)",
   private_featureloc           => "(featureloc_id,feature_id,srcfeature_id,fmin,fmax,strand,locgroup,rank)",
   tree                         => "(tree_id,name,format,tree_string)",
   feature_tree                 => "(feature_tree_id,feature_id,tree_id,tree_relationship)",
   private_feature_tree         => "(feature_tree_id,feature_id,tree_id,tree_relationship)",
   snp_core                     => "(snp_core_id,pangenome_region_id,allele,position,gap_offset,aln_column,frequency_a,frequency_t,frequency_g,frequency_c,frequency_gap,frequency_other)",
   snp_variation                => "(snp_variation_id,snp_id,contig_collection_id,contig_id,locus_id,allele)",
   private_snp_variation        => "(snp_variation_id,snp_id,contig_collection_id,contig_id,locus_id,allele)",
   snp_position                 => "(snp_position_id,contig_collection_id,contig_id,pangenome_region_id,locus_id,region_start,locus_start,region_end,locus_end,locus_gap_offset)",
   private_snp_position         => "(snp_position_id,contig_collection_id,contig_id,pangenome_region_id,locus_id,region_start,locus_start,region_end,locus_end,locus_gap_offset)",
   gap_position                 => "(gap_position_id,contig_collection_id,contig_id,pangenome_region_id,locus_id,snp_id,locus_pos,locus_gap_offset)",
   private_gap_position         => "(gap_position_id,contig_collection_id,contig_id,pangenome_region_id,locus_id,snp_id,locus_pos,locus_gap_offset)",
   core_region                  => "(core_region_id,pangenome_region_id,aln_column)",
   accessory_region             => "(accessory_region_id,pangenome_region_id,aln_column)",
   dbxref                       => "(dbxref_id,db_id,accession,version,description)",
   feature_dbxref               => "(feature_dbxref_id,feature_id,dbxref_id)",
   db                           => "(db_id,name,description)",
   upload                       => "(upload_id,login_id,category,tag,release_date,upload_date)",
   permission                   => "(permission_id,upload_id,login_id,can_modify,can_share)",
   genome_location              => "(feature_id,geocode_id)",
   private_genome_location      => "(feature_id,geocode_id)",
   feature_group                => "(feature_group_id,feature_id,genome_group_id,featureprop_id)",
   private_feature_group        => "(feature_group_id,feature_id,genome_group_id,featureprop_id)",
);

my %updatestring = (
	tfeature                      => "seqlen = s.seqlen, residues = s.residues",
	tfeatureloc                   => "fmin = s.fmin, fmax = s.fmin, strand = s.strand, locgroup = s.locgroup, rank = s.rank",
	tfeatureprop                  => "value = s.value",
	tprivate_feature              => "seqlen = s.seqlen, residues = s.residues",
	tprivate_featureloc           => "fmin = s.fmin, fmax = s.fmin, strand = s.strand, locgroup = s.locgroup, rank = s.rank",
	tprivate_featureprop          => "value = s.value",
	ttree                         => "tree_string = s.tree_string",
	tsnp_core                     => "position = s.position, gap_offset = s.gap_offset",
	tsnp_core2                    => "aln_column = s.aln_column, frequency_a = s.frequency_a, frequency_t = s.frequency_t, ".
									 "frequency_g = s.frequency_g, frequency_c = s.frequency_c, frequency_gap = s.frequency_gap, frequency_other = s.frequency_other"
);

my %tmpcopystring = (
	tfeature                      => "(feature_id,organism_id,uniquename,type_id,seqlen,residues)",
	tfeatureprop                  => "(feature_id,type_id,value,rank)",
	tfeatureloc                   => "(feature_id,fmin,fmax,strand,locgroup,rank)",
	tprivate_feature              => "(feature_id,organism_id,uniquename,type_id,seqlen,residues,upload_id)",
	tprivate_featureprop          => "(feature_id,type_id,value,rank,upload_id)",
	tprivate_featureloc           => "(feature_id,fmin,fmax,strand,locgroup,rank)",
	ttree                         => "(tree_id,name,tree_string)",
	tsnp_core                     => "(snp_core_id,pangenome_region_id,position,gap_offset)",
	tsnp_core2                    => "(snp_core_id,pangenome_region_id,position,aln_column,frequency_a,frequency_t,frequency_g,frequency_c,frequency_gap,frequency_other)"
);

my %joinstring = (
	tfeature                      => "s.feature_id = t.feature_id",
	tfeatureloc                   => "s.feature_id = t.feature_id",
	tfeatureprop                  => "s.feature_id = t.feature_id AND s.type_id = t.type_id",
	tprivate_feature              => "s.feature_id = t.feature_id",
	tprivate_featureloc           => "s.feature_id = t.feature_id",
	tprivate_featureprop          => "s.feature_id = t.feature_id AND s.type_id = t.type_id",
	ttree                         => "s.tree_id = t.tree_id",
	tsnp_core                     => "s.snp_core_id = t.snp_core_id",
	tsnp_core2                    => "s.snp_core_id = t.snp_core_id"
);

my %joinindices = (
	tfeature                      => "feature_id",
	tfeatureloc                   => "feature_id",
	tfeatureprop                  => "feature_id, type_id",
	tprivate_feature              => "feature_id",
	tprivate_featureloc           => "feature_id",
	tprivate_featureprop          => "feature_id, type_id",
	ttree                         => "tree_id",
	tsnp_core                     => "snp_core_id",
	tsnp_core2                    => "snp_core_id"
);


# Key values for loci cache
my $ALLOWED_LOCI_CACHE_KEYS = "feature_id|uniquename|genome_id|query_id|is_public|insert|update|feature_type";
               
# Tables for which caches are maintained
my $ALLOWED_CACHE_KEYS = 
	"collection|contig|feature|sequence|core|core_snp|snp_alignment|uploaded_feature|".
	"core_alignment|core_region|acc_region|db|dbxref|snp_genome|function|uploaded_meta";

# Valid feature types
# Note: party_mix => ExperimentalFeatures.pm initialized to manage all feature types concurrently
my $ALLOWED_FEATURE_TYPES = "vfamr|pangenome|genome|party_mix";

# Tmp file names for storing upload data
my %files = map { $_ => 'FH'.$_; } @tables, @update_tables, 'snp_column', 'snp_alignment', 'pg_alignment';

# common SQL
use constant VERIFY_TMP_TABLE => "SELECT count(*) FROM pg_class WHERE relname=? and relkind='r'";

# For system calls
my $perl_interpreter = $^X;           
            
=head2 new

Constructor

=cut

sub new {
	my $class = shift;
	my %arg   = @_;

	$DEBUG = 1 if $arg{debug};
	
	my $self  = bless {}, ref($class) || $class;
	
	$self->{now} = time();

	# Parse config file
	my $config_filepath = $arg{config};
	my $dsn;
	my $dbname;
	my $dbport;
	my $dbhost;
	my $dbuser;
	my $dbpass;
	my $tmp_dir;
	my $fasttree_exe;
	croak "Missing argument: config." unless $config_filepath;
	if(my $conf = Config::Tiny->read($config_filepath)) {
		$dsn       = $conf->{db}->{dsn};
		$dbname    = $conf->{db}->{name};
		$dbuser    = $conf->{db}->{user};
		$dbpass    = $conf->{db}->{pass};
		$dbhost    = $conf->{db}->{host};
		$dbport    = $conf->{db}->{port};
		$tmp_dir   = $conf->{tmp}->{dir};
		$fasttree_exe = $conf->{ext}->{fasttreemp};
	} else {
		croak Config::Tiny->errstr();
	}

	croak "Missing argument: tmp_dir." unless $tmp_dir;

	$dbpass ||= '';
	unless($dsn) {
		$dsn = "dbi:Pg:dbname=$dbname;port=$dbport;host=$dbhost";
	}

	$self->{dbi_connection_parameters} = {
		dsn    => $dsn,
		dbuser => $dbuser,
		dbpass => $dbpass
	};
	
	my $dbh = DBI->connect(
		$dsn,
		$dbuser,
		$dbpass,
		{AutoCommit => 0,
		 TraceLevel => 0}
	) or croak "Unable to connect to database";

	# Save fasttree path from config file
	$self->{fasttree_exe} = $fasttree_exe;
	
	$self->dbh($dbh);
	$self->tmp_dir($tmp_dir);
	$self->config($config_filepath);
	$self->noload($arg{noload});
	$self->recreate_cache($arg{recreate_cache});
	$self->save_tmpfiles($arg{save_tmpfiles});
	$self->vacuum($arg{vacuum});
	$self->test($arg{test});
	$self->{db_cache} = 0;
	$self->{db_cache} = 1 if $arg{use_cached_names};
	
	my $ft = $arg{feature_type};
	croak "Missing argument: feature_type. Must be (allele|pangenome|genome|party_mix)" unless $ft;
	unless ($ft =~ m/$ALLOWED_FEATURE_TYPES/) {
		croak "Invalid argument: feature_type. Must be (vfamr|pangenome|genome|party_mix)"
	}
	$self->{feature_type} = $ft;
	
	$self->{snp_aware} = 0;
	$self->{snp_aware} = 1 if $ft eq 'pangenome' || $ft eq 'party_mix';

	$self->{threshold_override} = 0;
	$self->{threshold_override} = 1 if $arg{override};

	$self->{supertree} = 0;
	$self->{supertree} = 1 if $arg{use_supertree};

	$self->{assign_groups} = 0;
	$self->{assign_groups} = 1 if $arg{assign_to_groups};
	
	$self->initialize_sequences();
	$self->initialize_ontology();
	$self->initialize_db_caches('pangenome') if $ft eq 'pangenome' || $ft eq 'party_mix';
	$self->initialize_db_caches('vfamr') if $ft eq 'vfamr' || $ft eq 'party_mix';
	$self->initialize_db_caches('genome') if $ft eq 'genome' || $ft eq 'party_mix';
	$self->initialize_snp_caches() if $self->{snp_aware};
	$self->initialize_group_caches() if $self->{assign_groups};
	$self->prepare_queries();
	
	return $self;
}

#################
# Initialization
#################

=head2 initialize_ontology

=over

=item Usage

  $obj->initialize_ontology()

=item Function

Initializes cvterm IDs for commonly used types

These are static and predefined.

=item Returns

void

=item Arguments

none

=back

=cut

sub initialize_ontology {
    my $self = shift;
    
    # Commonly used cvterms
    my $fp_sth = $self->dbh->prepare("SELECT t.cvterm_id FROM cvterm t, cv v WHERE t.name = ? AND v.name = ? AND t.cv_id = v.cv_id"); 

	# Part of ID
	$fp_sth->execute('part_of', 'relationship');
    my ($part_of) = $fp_sth->fetchrow_array();
    
    # Located In ID
	$fp_sth->execute('located_in', 'relationship');
    my ($located_in) = $fp_sth->fetchrow_array();
    
    # Similar To ID
	$fp_sth->execute('similar_to', 'sequence');
    my ($similar_to) = $fp_sth->fetchrow_array();
    
    # Derives From ID
	$fp_sth->execute('derives_from', 'relationship');
    my ($derives_from) = $fp_sth->fetchrow_array();
    
    # Derives From ID
	$fp_sth->execute('contained_in', 'relationship');
    my ($contained_in) = $fp_sth->fetchrow_array();

    # Contig collection ID
    $fp_sth->execute('contig_collection', 'sequence');
    my ($contig_col) = $fp_sth->fetchrow_array();
    
    # Contig ID
    $fp_sth->execute('contig', 'sequence');
    my ($contig) = $fp_sth->fetchrow_array();
    
    # Allele ID
    $fp_sth->execute('allele', 'sequence');
    my ($allele) = $fp_sth->fetchrow_array();
    
    # Experimental Feature ID
    $fp_sth->execute('experimental_feature', 'sequence');
    my ($experimental_feature) = $fp_sth->fetchrow_array();
    
    # SNP ID
    $fp_sth->execute('sequence_variant', 'sequence');
    my ($snp) = $fp_sth->fetchrow_array();
    
    # Pangenome Loci ID
    $fp_sth->execute('locus', 'local');
    my ($locus) = $fp_sth->fetchrow_array();
    
    # Pangenome Reference ID
    $fp_sth->execute('pangenome', 'local');
    my ($pan) = $fp_sth->fetchrow_array();
    
    # core_genome ID
    $fp_sth->execute('core_genome', 'local');
    my ($core) = $fp_sth->fetchrow_array();
    
    # Typing gene ID
    $fp_sth->execute('typing_sequence', 'local');
    my ($typing) = $fp_sth->fetchrow_array();
    
    # Allele fusion ID
    $fp_sth->execute('allele_fusion', 'local');
    my ($fusion) = $fp_sth->fetchrow_array();
    
    # Fusion of relationship ID
    $fp_sth->execute('fusion_of', 'local');
    my ($fusion_of) = $fp_sth->fetchrow_array();
    
    # Variant of relationship ID
    $fp_sth->execute('variant_of', 'sequence');
    my ($variant_of) = $fp_sth->fetchrow_array();

    # Marker region ID
    $fp_sth->execute('ecoli_marker_region', 'local');
    my ($ecoli_marker) = $fp_sth->fetchrow_array();

    # RFA ID
    $fp_sth->execute('reference_pangenome_alignment', 'local');
    my ($rpa) = $fp_sth->fetchrow_array();

    # Variant of relationship ID
    $fp_sth->execute('aligned_sequence_of', 'local');
    my ($alignment_of) = $fp_sth->fetchrow_array();
    
    
    $self->{feature_types} = {
    	contig_collection => $contig_col,
    	contig => $contig,
    	allele => $allele,
    	experimental_feature => $experimental_feature,
    	snp => $snp,
    	locus => $locus,
    	pangenome => $pan,
    	core_genome => $core,
    	typing_sequence => $typing,
    	allele_fusion => $fusion,
    	ecoli_marker_region => $ecoli_marker,
    	reference_pangenome_alignment => $rpa,
    };
    
	$self->{relationship_types} = {
    	part_of => $part_of,
    	similar_to => $similar_to,
    	located_in => $located_in,
    	derives_from => $derives_from,
    	contained_in => $contained_in,
    	fusion_of => $fusion_of,
    	variant_of => $variant_of,
    	aligned_sequence_of => $alignment_of,
    };
    
    # Feature property types
    foreach my $type (keys %fp_types) {
    	my $cv = $fp_types{$type};
    	$fp_sth->execute($type, $cv);
    	my ($cvterm_id) = $fp_sth->fetchrow_array();
    	croak "Featureprop cvterm type $type not in database." unless $cvterm_id;
    	$self->{featureprop_types}->{$type} = $cvterm_id;
    }

	# Place-holder publication ID
	my $p_sth = $self->dbh->prepare("SELECT pub_id FROM pub WHERE uniquename = 'null'");
	$p_sth->execute();
	($self->{pub_id}) = $p_sth->fetchrow_array();
	
    # Default organism
    my $o_sth = $self->dbh->prepare("SELECT organism_id FROM organism WHERE common_name = ?"); 
    my @organisms = ('Escherichia coli');
    foreach my $common_name (@organisms) {
    	$o_sth->execute($common_name);
    	my ($o_id) = $o_sth->fetchrow_array();
    	croak "Organism with common name $common_name not in database." unless $o_id;
    	$self->{organisms}->{$common_name} = $o_id;
    }

    return;
}

=head2 initialize_sequences

=over

=item Usage

  $obj->initialize_sequences()

=item Function

Initializes sequence counter variables

=item Returns

void

=item Arguments

none

=back

=cut

sub initialize_sequences {
	my $self = shift;
	
	foreach my $table (@tables) {
		
		unless($sequences{$table}) {
			carp "Table $table does not have primary ID. Skipping primary key initialization.";
			next;
		}
		
		my $sth = $self->dbh->prepare("select nextval('$sequences{$table}')");
		$sth->execute;
		my ($nextoid) = $sth->fetchrow_array();
		$self->nextoid($table, $nextoid);
		
		print "$table, $nextoid\n" if $DEBUG;
	}
	
	return;
}


=head2 update_sequences

=over

=item Usage

  $obj->update_sequences()

=item Function

Checks the maximum value of the primary key of the sequence's table
and modifies the nextval of the sequence if they are out of sync.
It then (re)initializes the sequence cache.

=item Returns

Nothing

=item Arguments

None

=back

=cut

sub update_sequences {
    my $self = shift;

	foreach my $table (@tables) {
		
		my $id_name      = $table_ids{$table};

		unless($id_name) {
			carp "Table $table does not have primary ID. Skipping primary key update.";
			next;
		}
		

		my $table_name   = $table;
		my $max_id_query = "SELECT max($id_name) FROM $table_name";
		my $sth          = $self->dbh->prepare($max_id_query);
		$sth->execute;
		my ($max_id)     = $sth->fetchrow_array();
		
		$max_id = 1 unless $max_id; # Empty table
		
		my $curval_query = "SELECT nextval('$sequences{$table}')";
		$sth             = $self->dbh->prepare($curval_query);
		$sth->execute;
		my ($curval)     = $sth->fetchrow_array();      
		
		if ($max_id > $curval) {
		    my $setval_query = "SELECT setval('$sequences{$table}',$max_id)";
		    $sth             = $self->dbh->prepare($setval_query);
		    $sth->execute;
		    
		    $self->nextoid($table, ++$max_id);
		    
		} else {
			$self->nextoid($table, $curval);
		}
	}

    return;
}


=head2 initialize_db_cache

=over

=item Usage

  $obj->initialize_db_cache()

=item Function

Creates an intermediary cache of all key features to ensure no dublication in the DB

=item Returns

void

=item Arguments

none

=back

=cut

sub initialize_db_caches {
    my $self = shift;
    my $cache_type = shift;

    # Use memory to track altered or added features during this run
    $self->{feature_cache}{$cache_type}{new} = {}; 
    $self->{feature_cache}{$cache_type}{updated} = {}; 

    if($cache_type eq 'vfamr' || $cache_type eq 'pangenome') {
    	
	    my $is_pg = 0;
	    $is_pg = 1 if $cache_type eq 'pangenome';
	    
	    my $table = 'tmp_allele_cache';
	    my $type_id = $self->feature_types('allele');
	    if($is_pg) {
	    	$table = 'tmp_loci_cache';
	    	$type_id = $self->feature_types('locus');
	    }
	    $self->{feature_cache}{$cache_type}{table} = $table;
	    $self->{feature_cache}{$cache_type}{type} = $type_id;
	    
	    # Initialize cache table 
	    my $dbh = $self->dbh;
	    my $sth = $dbh->prepare(VERIFY_TMP_TABLE); 
	    $sth->execute($table);
	    my ($table_exists) = $sth->fetchrow_array;

	    if (!$table_exists || $self->recreate_cache() ) {
	    	# Rebuild cache
	        print STDERR "(Re)creating the $table cache in the database... ";
	        
	        # Discard old table
	        if ($self->recreate_cache() and $table_exists) {
	        	my $sql = "DROP TABLE $table";
	        	$dbh->do($sql); 
	        }

			# Create new table
	        print STDERR "\nCreating table...\n";
	        my $sql = "CREATE TABLE $table (
				feature_id int,
				uniquename varchar(1000),                
				genome_id int,                   
				query_id int,                 
				pub boolean
			)";
	        $dbh->do($sql); 
	    	
	        # Populate table
	        my $reltype = $is_pg ? 'derives_from' : 'similar_to';
	        print STDERR "Populating table...\n";
	        $sql = "INSERT INTO $table
			SELECT f.feature_id, f.uniquename, f1.object_id, f2.object_id, TRUE
			FROM feature f, feature_relationship f1, feature_relationship f2
			WHERE f.type_id = $type_id AND
			  f1.type_id = ".$self->relationship_types('part_of')." AND f1.subject_id = f.feature_id AND
			  f2.type_id = ".$self->relationship_types($reltype)." AND f2.subject_id = f.feature_id";
	        $dbh->do($sql);
	        $sql = "INSERT INTO $table
			SELECT f.feature_id, f.uniquename, f1.object_id, f2.object_id, FALSE
			FROM private_feature f, private_feature_relationship f1, private_feature_relationship f2
			WHERE f.type_id = $type_id AND
			  f1.type_id = ".$self->relationship_types('part_of')." AND f1.subject_id = f.feature_id AND
			  f2.type_id = ".$self->relationship_types($reltype)." AND f2.subject_id = f.feature_id";
	        $dbh->do($sql);
	        
	        # Add typing features if working with gene alleles
	        unless ($is_pg) {
	        	$type_id = $self->feature_types('allele_fusion');
	        	$reltype = 'variant_of';
	        	$sql = "INSERT INTO $table
				SELECT f.feature_id, f.uniquename, f1.object_id, f2.object_id, TRUE
				FROM feature f, feature_relationship f1, feature_relationship f2
				WHERE f.type_id = $type_id AND
				  f1.type_id = ".$self->relationship_types('part_of')." AND f1.subject_id = f.feature_id AND
				  f2.type_id = ".$self->relationship_types($reltype)." AND f2.subject_id = f.feature_id";
		        $dbh->do($sql);
		        $sql = "INSERT INTO $table
				SELECT f.feature_id, f.uniquename, f1.object_id, f2.object_id, FALSE
				FROM private_feature f, private_feature_relationship f1, private_feature_relationship f2
				WHERE f.type_id = $type_id AND
				  f1.type_id = ".$self->relationship_types('part_of')." AND f1.subject_id = f.feature_id AND
				  f2.type_id = ".$self->relationship_types($reltype)." AND f2.subject_id = f.feature_id";
		        $dbh->do($sql);
	        }
	       	
	       	# Build indices
	        print STDERR "Creating indexes...\n";
	        $sql = "CREATE INDEX $table\_idx1 ON $table (genome_id,query_id,pub)";
	        $dbh->do($sql);
	        $sql = "CREATE INDEX $table\_idx2 ON $table (uniquename)";
	        $dbh->do($sql);
	       
	        print STDERR "Done.\n";
	    }
	    
	    my $file_path = $self->{tmp_dir};
	    my $tmpfile = new File::Temp(
			TEMPLATE => "chado-$cache_type-cache-XXXX",
			SUFFIX   => '.dat',
			UNLINK   => $self->save_tmpfiles() ? 0 : 1, 
			DIR      => $file_path,
		);
		chmod 0644, $tmpfile;
		$self->{feature_cache}{$cache_type}{fh} = $tmpfile;

		# Need placeholder upload_id to fulfill foreign constraints in temporary table
		# This value should not be copied
		my $sql = "SELECT upload_id FROM upload LIMIT 1;";
		my ($upload_id) = $dbh->selectrow_array($sql);
		# Note: if this is the first upload, upload_id will be NULL,
		# however this value will not be needed since there are no previous upload features
		# to update
		$self->placeholder_upload_id($upload_id);
		
		unless($is_pg) {
			# Cache allele data needed for typing
			
			# Retrieve query gene Ids needed in typing
			$type_id = $self->feature_types('typing_sequence');
			my $rel_id = $self->relationship_types('fusion_of');
			
			my $sql = "SELECT r.object_id, r.subject_id, r.rank, f.uniquename
			FROM feature f, feature_relationship r 
			WHERE f.type_id = $type_id AND
			  r.subject_id = f.feature_id AND
			  r.type_id = $rel_id";
			  
			my $feature_arrayref = $dbh->selectall_arrayref($sql);
			
			my %typing_constructs;
			my %typing_watchlists;
			my %typing_seq_names;
			
			map { 
				$typing_constructs{$_->[1]}{$_->[2]} = $_->[0]; 
				$typing_watchlists{$_->[0]} = {}; 
				$typing_seq_names{$_->[1]} = $_->[3]; 
			} @$feature_arrayref;
			
			# Record order that alleles are concatenated to form typing sequence
			$self->{feature_cache}{$cache_type}{typing_construct} = \%typing_constructs;
			
			# Record query gene IDs to watch for to build typing sequences
			$self->{feature_cache}{$cache_type}{typing_watchlist} = \%typing_watchlists;
			
			# Name to ID mapping
			$self->{feature_cache}{$cache_type}{typing_names} = \%typing_seq_names;
			
			# Name to Featureprop mapping
			$self->{feature_cache}{$cache_type}{typing_featureprops} = {
				'stx1_subunit' => 'stx1_subtype',
				'stx2_subunit' => 'stx2_subtype',
			};
			
		}
		
	    $dbh->commit || croak "Initialization of $table failed: ".$self->dbh->errstr();
	}
	    
    return;
}

=head2 initialize_snp_caches

=over

=item Usage

  $obj->initialize_snp_caches()

=item Function

Creates the helper tables in the database for recording core pan-genome
alignment of SNPs.

UPDATE: also creates helper cache tables for recording core pan-genome region
presence/absence

=item Returns

void

=item Arguments

none

=back

=cut

sub initialize_snp_caches {
    my $self = shift;

	my $dbh = $self->dbh;
	
	# Store the core snp alignment in memory for faster access
	my $sql = "SELECT aln_column FROM snp_alignment WHERE name = 'core'";
	my $sth = $dbh->prepare($sql);
    $sth->execute();
    my ($pos) = $sth->fetchrow_array();
    $self->{snp_alignment}->{core_alignment} = '';
    $self->{snp_alignment}->{core_position} = $pos // 0;
    print "Starting SNP column: ".$self->{snp_alignment}->{core_position}."\n";
    
	# Create tmp table
	$sql = "DROP TABLE IF EXISTS tmp_snp_cache";
	$dbh->do($sql);
    
   $sql = 
	"CREATE TABLE public.tmp_snp_cache (
		name varchar(100),
		snp_id int,
		aln_column int,
		nuc char(1)
	)";
    $dbh->do($sql);
    
    # Prepare bulk insert
    my $bulk_set_size = 10000;
    my $insert_query = 'INSERT INTO tmp_snp_cache (name,snp_id,aln_column,nuc) VALUES (?,?,?,?)';
    $insert_query .= ', (?,?,?,?)' x ($bulk_set_size-1);
    $self->{snp_alignment}{insert_tmp_variations} = $dbh->prepare($insert_query);
    $self->{snp_alignment}{bulk_set_size} = $bulk_set_size;
    
    
    # Prepare update column
    my $update_query = 'UPDATE tmp_snp_cache SET aln_column = ? WHERE snp_id = ?';
    $self->{snp_alignment}{update_tmp_variations} = $dbh->prepare($update_query);
    
    
    # Setup up insert buffer
	$self->{snp_alignment}{buffer_stack} = []; 
	$self->{snp_alignment}{buffer_num} = 0; 
	$self->{snp_alignment}{new_columns} = {};
	$self->{snp_alignment}{modified_columns} = {};
	
	
	# Setup core region cache
	$sql = "SELECT core_column FROM pangenome_alignment WHERE name = 'core'";
	$sth = $dbh->prepare($sql);
    $sth->execute();
    ($pos) = $sth->fetchrow_array();
    $self->{core_alignment}->{added_columns} = 0;
    $self->{core_alignment}->{core_position} = $pos // 0;
	
	# Create tmp table
	$sql = "DROP TABLE IF EXISTS tmp_core_pangenome_cache";
	$dbh->do($sql);
   
   $sql = 
	"CREATE TABLE public.tmp_core_pangenome_cache (
		genome varchar(100),
		aln_column int
	)";
    $dbh->do($sql);
    
    # Prepare bulk insert
    $bulk_set_size = 1000;
    $insert_query = 'INSERT INTO tmp_core_pangenome_cache (genome,aln_column) VALUES (?,?)';
    $insert_query .= ', (?,?)' x ($bulk_set_size-1);
    $self->{core_alignment}{insert_tmp_presence} = $dbh->prepare($insert_query);
    $self->{core_alignment}{bulk_set_size} = $bulk_set_size;
    
    # Setup up insert buffer
	$self->{core_alignment}{buffer_stack} = [];
	$self->{core_alignment}{buffer_num} = 0; 
	

	# Setup accessory region cache
	$sql = "SELECT acc_column FROM pangenome_alignment WHERE name = 'core'";
	$sth = $dbh->prepare($sql);
    $sth->execute();
    ($pos) = $sth->fetchrow_array();
    $self->{acc_alignment}->{added_columns} = 0;
    $self->{acc_alignment}->{core_position} = $pos // 0;
	
	# Create tmp table
	$sql = "DROP TABLE IF EXISTS tmp_acc_pangenome_cache";
	$dbh->do($sql);
   
   $sql = 
	"CREATE TABLE public.tmp_acc_pangenome_cache (
		genome varchar(100),
		aln_column int
	)";
    $dbh->do($sql);
    
    # Prepare bulk insert
    $bulk_set_size = 1000;
    $insert_query = 'INSERT INTO tmp_acc_pangenome_cache (genome,aln_column) VALUES (?,?)';
    $insert_query .= ', (?,?)' x ($bulk_set_size-1);
    $self->{acc_alignment}{insert_tmp_presence} = $dbh->prepare($insert_query);
    $self->{acc_alignment}{bulk_set_size} = $bulk_set_size;
    
    # Setup up insert buffer
	$self->{acc_alignment}{buffer_stack} = [];
	$self->{acc_alignment}{buffer_num} = 0;

	# Retrieve organism marker regions
	my $marker_count = 0;
	$sql = "SELECT f.feature_id, r.aln_column FROM feature_cvterm f ".
		" LEFT JOIN core_region AS r ON r.pangenome_region_id = f.feature_id ".
		" WHERE f.is_not = FALSE AND f.cvterm_id = ".$self->feature_types('ecoli_marker_region');

	$sth = $dbh->prepare($sql);
	$sth->execute();
	while(my ($marker_id, $col) = $sth->fetchrow_array) {
		croak "Error: pangenome feature $marker_id classified as ecoli_marker_region does not have core_region alignment column assigned." unless $col;
		$self->{organism_pangenome_markers}{column}{$col} = $marker_id;
		$marker_count++
	}
	print "$marker_count Ecoli pangenome marker regions found.";
	croak "Error: insufficient pangenome markers for current threshold setting (threshold: $ORGANISM_MARKER_CUTOFF, markers: $marker_count)."
		if $marker_count <= $ORGANISM_MARKER_CUTOFF && !$self->{threshold_override};


    $dbh->commit || croak "Initialization of SNP caches failed: ".$self->dbh->errstr();
    
    return;
}

=head2 initialize_group_caches

=over

=item Usage

  $obj->initialize_group_caches()

=item Function

Creates the objects for recording genome group assignments

=item Returns

void

=item Arguments

none

=back

=cut

sub initialize_group_caches {
    my $self = shift;

	my $dbh = $self->dbh;

	# Create DBIx::Class::Schema connection
	my $db_bridge = Data::Bridge->new( dbh => $dbh );

	# Create Grouper object
	my $grouper = Data::Grouper->new(schema => $db_bridge->dbixSchema, cvmemory => $db_bridge->cvmemory);

	# Retrieve group IDs and corresponding values
	my $assignments = $grouper->group_assignments();

	# Split into logical parts
	my %fp_assignments = ( 
		'serotype' => $assignments->{'serotype'},
		'isolation_host' => $assignments->{'isolation_host'}, 
		'syndrome' => $assignments->{'syndrome'},
		'isolation_source' => $assignments->{'isolation_source'}
	);

	my %st_assignments = (
		'stx1_subtype' => $assignments->{'stx1_subtype'}, 
		'stx2_subtype' => $assignments->{'stx2_subtype'}
	);


	$self->{groups}{featureprop_group_assignments} = \%fp_assignments;
	$self->{groups}{subtype_group_assignments} = \%st_assignments;

}

#################
# Files
#################


=head2 file_handles

=over

=item Usage

  $obj->file_handles()

=item Function

Creates and keeps track of file handles for temp files

=item Returns

On create, void.  With an arguement, returns the requested file handle

=item Arguments

If the 'short hand' name of a file handle is given, returns the requested
file handle.  The short hand file names are 'FH'.$tablename

=back

=cut

sub file_handles {
    my ($self, $argv) = @_;

    if ($argv && $argv ne 'close') {
        my $fhhame= ($argv =~ /^FH/) ? $argv : 'FH'.$argv;
        return $self->{file_handles}{$fhhame};
    }
    else {
        my $file_path = $self->{tmp_dir};
     
        for my $key (keys %files) {
            my $tmpfile = new File::Temp(
                                 TEMPLATE => "chado-$key-XXXX",
                                 SUFFIX   => '.dat',
                                 UNLINK   => $self->save_tmpfiles() ? 0 : 1, 
                                 DIR      => $file_path,
                                );
			chmod 0644, $tmpfile;
			$self->{file_handles}{$files{$key}} = $tmpfile;         
        }
        
        return;
    }
}

=head2 end_files

=over

=item Usage

  $obj->end_files()

=item Function

Appends proper bulk load terminators

=item Returns

void

=item Arguments

none

=back

=cut

sub end_files {
	my $self = shift;

	foreach my $file (@tables, @update_tables) {
		my $fh = $self->file_handles($files{$file});
		print $fh "\\.\n\n";
	}
    
}

=head2 flush_caches

=over

=item Usage

  $obj->flush_caches()

=item Function

Initiate garbage collection?

=item Returns

void

=item Arguments

none

=back

=cut

sub flush_caches {
    my $self = shift;

    $self->{cache}            = '';
    $self->{uniquename_cache} = '';

    return;
}


=head2 nextoid

=over

=item Usage

  $obj->nextoid($table)        #get existing value
  $obj->nextoid($table,$newval) #set new value

=item Function

=item Returns

value of next table id (a scalar)

=item Arguments

new value of next table id (to set)

=back

=cut

sub nextoid {  
  my $self = shift;
  my $table= shift;
  my $arg  = shift if @_;
  
  if (defined($arg) && $arg eq '++') {
      return $self->{'nextoid'}{$table}++;
  } elsif (defined($arg)) {
      return $self->{'nextoid'}{$table} = $arg;
  }
  return $self->{'nextoid'}{$table} if ($table);
}

=head2 abort

=over

=item Usage

  $obj->abort()

=item Function

Discards current transaction and releases lock.
This function is called by external error handlers. The rollback is
critical to discard any changes/additions to the DB before removing
the DB lock (which does a commit). 

=item Returns

Nothing

=item Arguments

None

=back

=cut

sub abort {
    my ($self, %argv) = @_;

    my $dbh = $self->dbh;

    # Abort any pending DB transactions
    $dbh->rollback;
   
    $self->remove_lock();

    return;
}


=head2 remove_lock

=over

=item Usage

  $obj->remove_lock()

=item Function

To remove the row in the gff_meta table that prevents other loading scripts from running while the current process is running.

=item Returns

Nothing

=item Arguments

None

=back

=cut

sub remove_lock {
    my ($self, %argv) = @_;

    my $dbh = $self->dbh;

    # Abort any pending DB transactions
    $dbh->rollback;
   
    my $sql = "SELECT name,hostname,starttime FROM gff_meta";
    my $select_query = $dbh->prepare($sql) or carp "Select prepare failed";
    $select_query->execute() or carp "Select from meta failed";

	$sql = "DELETE FROM gff_meta WHERE name = ? AND hostname = ?";
    my $delete_query = $dbh->prepare($sql) or carp "Delete prepare failed";

    while (my @result = $select_query->fetchrow_array) {
        my ($name,$host,$time) = @result;

        $delete_query->execute($name,$host) or carp "Removing the lock failed!";
        $dbh->commit;
        
    }

    return;
}


=head2 place_lock

=over

=item Usage

  $obj->place_lock()

=item Function

To place a row in the gff_meta table (creating that table if necessary) 
that will prevent other users/processes from doing GFF bulk loads while
the current process is running.

=item Returns

Nothing

=item Arguments

None

=back

=cut

sub place_lock {
    my ($self, %argv) = @_;

    # first determine if the meta table exists
    my $dbh = $self->dbh;
    my $sth = $dbh->prepare(VERIFY_TMP_TABLE);
    $sth->execute('gff_meta');

    my ($table_exists) = $sth->fetchrow_array;

    if (!$table_exists) {
		carp "Creating gff_meta table...\n";
		my $sql =  
		"CREATE TABLE gff_meta (
			name        varchar(100),
			hostname    varchar(100),
			starttime   timestamp not null default now() 
		)";
       $dbh->do($sql);
       
    } else {
    	# check for existing lock
    	
    	my $sql = "SELECT name,hostname,starttime FROM gff_meta";
	    my $select_query = $dbh->prepare($sql);
	    $select_query->execute();
	
	    while (my @result = $select_query->fetchrow_array) {
	        my ($name,$host,$time) = @result;
	        my ($progname,$pid)  = split /\-/, $name;
	
	        
	            carp "\n\n\nWARNING: There is another $progname process\n".
	            "running on $host, with a process id of $pid\n".
	            "which started at $time\n".
	            "\nIf that process is no longer running, you can remove the lock by providing\n".
	            "the --remove_lock flag when running $progname.\n\n".
	            "Note that if the last bulk load process crashed, you may also need the\n".
	            "--recreate_cache option as well.\n\n";
	
	            exit(-2);
	        
	    }
    }

    my $pid = $$;
    my $progname = $0;
    my $name = "$progname-$pid";
    my $hostname = hostname;

	my $sql = "INSERT INTO gff_meta (name,hostname) VALUES (?,?)";
    my $insert_query = $dbh->prepare($sql);
    $insert_query->execute($name,$hostname);
    $dbh->commit;

    return;
}

=head2 feature_cache

=over

=item Usage

  $obj->feature_cache()

=item Function

Maintains a cache of unique features added/updated during this run

=item Returns

See Arguements.

=item Arguments

feature_cache takes a hash as input. If the key 'insert' is included,
values are added to new cache hash. If the key 'update' is included,
values are added to the update cache hash. 

Allowed hash keys:

  feature_id
  uniquename
  update|insert
  

=back

=cut

sub feature_cache {
	my ($self, %argv) = @_;
	
	my @bogus_keys = grep {!/($ALLOWED_LOCI_CACHE_KEYS)/} keys %argv;
	
	if (@bogus_keys) {
		for (@bogus_keys) {
		    carp "Error in feature_cache input: I don't know what to do with the key ".$_.
		   " in the feature_cache method; it's probably because of a typo\n";
		}
		croak;
	}

	# Check which feature we are dealing with
	my $cache_type = $self->{feature_type};
	if($cache_type eq 'party_mix') {
		my $ft = $argv{feature_type};
		croak "Error in feature_cache input: in multi-feature mode, must specify a feature cache type: feature_type => 'feature'." unless $ft;
		unless ($ft =~ m/$ALLOWED_FEATURE_TYPES/) {
			croak "Error in feature_cache input: invalid feature_type. Must be (allele|pangenome|genome)";
		}
		$cache_type = $ft;
	}
		
	my ($insert) = ($argv{insert} ? 1 : 0);
	my ($update) = ($argv{update} ? 1 : 0);
	
	if($update && $insert) {
		croak "Error in loci_cache input: either 'insert' or 'update' must be specified."
	}
	unless($update || $insert) {
		croak "Error in loci_cache input: 'insert' or 'update' must be specified.";
	}
	
	my %info = %argv;
	
	if($insert) {
		$self->{feature_cache}{$cache_type}{new}{$argv{uniquename}} = \%info;
		my $fh = $self->{feature_cache}{$cache_type}{fh};
		print $fh join("\t", ($info{feature_id},$info{uniquename},$info{genome_id},$info{query_id},$info{is_public})),"\n" if $fh;
	} else {
		$self->{feature_cache}{$cache_type}{updated}{$argv{uniquename}} = $info{feature_id};
	}
	
	return;
}


=head2 cache

=over

=item Usage

  $obj->cache()

=item Function

Handles generic data cache hash

=item Returns

The cached value

=item Arguments

The name of one of several top level cache keys (see variable $ALLOWED_CACHE_KEYS)
and a tag and optional value that gets stored in the cache.
If no value is passed, it is returned, otherwise void is returned.


=back

=cut

sub cache {
    my ($self, $top_level, $key, $value) = @_;

    if ($top_level !~ /($ALLOWED_CACHE_KEYS)/) {
        confess "I don't know what to do with the key '$top_level'".
            " in the cache method; it's probably because of a typo";
    }
    
    return $self->{cache}{$top_level} unless defined($key);
    
    return $self->{cache}{$top_level}{$key} unless defined($value);

    return $self->{cache}{$top_level}{$key} = $value;
    
}

=head2 cache_contig_id

=over

=item Usage

  $obj->cache_contig_id(tracker_id, genome_id, contig_id, contig_num)

=item Function

Saves the new contig collection and contig feature IDs in the DB cache table:
pipeline_cache.

=item Returns

Nothing

=item Arguments

1) tracker_id in the table pipeline_cache table,
2) Genome feature ID,
3) Contig feature ID,
4) Contig number in fasta file

=back

=cut

sub cache_contig_id {
	my ($self, $tracking_id, $genome_feature, $contig_feature, $contig_num) = @_;

	my $cache_name = 'uploaded_feature';
	my $cache_key = "tracker_id:$tracking_id.chr_num:$contig_num";
	
	$self->cache($cache_name, $cache_key, [$genome_feature, $contig_feature]);

	$self->{'queries'}{'genome'}{'update_contig_name'}->execute($genome_feature, $contig_feature, 
		$tracking_id, $contig_num);
	
}

=head2 cache_genome_id

=over

=item Usage

  $obj->cache_genome_id(genome_feature_id, $is_public, $uniquename, [$access_category])

=item Function

Saves the new contig collections uploaded in this run in memory. New snp alignment entries, tree
entries will be added for these genomes.

=item Returns

Nothing

=item Arguments

1) Genome feature ID,
2) Boolean indicating if in public/private table
3) Genome uniquename
4) Genome access category, if exists (e.g. public, private, release)

=back

=cut

sub cache_genome_id {
	my ($self, $genome_feature_id, $is_public, $uniquename, $organism, $access_category,
		$upload_id) = @_;

	my $cache_name = 'snp_genome';
	my $cache_key = $is_public ? "public_$genome_feature_id" : "private_$genome_feature_id";
	my $user_genome = !$is_public;

	unless($access_category) {
		$access_category = 'public' if $is_public;
	}
	
	$self->cache($cache_name, $cache_key, 
		{ 
			uniquename => $uniquename, visible => $access_category, 
			displayname => Modules::FormDataGenerator::displayname($uniquename, $user_genome, $access_category),
			feature_id => $genome_feature_id,
			public => $is_public,
		}
	);

	# Save some general properties for needed for all genomes
	# (new genomes need to be saved explicitly since this data cannot be
	# retrieved from DB)
	$cache_name = 'collection';
	unless($self->cache($cache_name, $cache_key)) {
		my $collection_cache = {
			name => $uniquename,
			organism => $organism
		};

		if($upload_id) {
			$collection_cache->{upload} = $upload_id;
		}

		$self->cache($cache_name, $cache_key, $collection_cache);
	}
		

}


=head2 collection

=over

=item Usage

  $obj->collection($contig_collection_id, $is_public)        # get existing value

=item Function

=item Returns

A hash of contig_collection data. Keys:
	name
	organism
	upload

=item Arguments

A feature table ID for a contig_collection and a boolean indicating
if feature is in public or private table.

=back

=cut

sub collection {
    my $self = shift;
    my ($feature_id, $public) = @_;
    
    my $cc = $public ? "public_$feature_id" : "private_$feature_id";
    
    if($self->cache('collection', $cc)) {
    	return $self->cache('collection', $cc);
    } else {
    	if($public) {
    		
    		$self->{'queries'}{'select_from_public_feature'}->execute(
			    $feature_id         
			);
			my ($uname, $org_id) = $self->{'queries'}{'select_from_public_feature'}->fetchrow_array(); 
			croak "Contig collection $feature_id not found in feature table." unless $uname;
			
			my $hash = {
				name => $uname,
				organism => $org_id
			};
			
			$self->cache('collection', $cc, $hash);
			return $hash;
			
    	} else {
    		
    		$self->{'queries'}{'select_from_private_feature'}->execute(
			    $feature_id         
			);
			my ($uname, $org_id, $upl_id) = $self->{'queries'}{'select_from_private_feature'}->fetchrow_array(); 
			croak "Contig collection $feature_id not found in feature table." unless $uname;
			
			my $hash = {
				name => $uname,
				organism => $org_id,
				upload => $upl_id
			};
			
			$self->cache('collection', $cc, $hash);
			return $hash;
    		
    	}
    }
}

=head2 contig

=over

=item Usage

  NOT WORKING!!! NEED TO save this data for new genomes so
  that later contig calls will have info in pipeline_loader.pl
  script... not used so didnt bother.

  $obj->contig($contig_id, $is_public)        # get existing value

=item Function

=item Returns

A hash of contig data. Keys:
	seq
	name
	len
	sequence

=item Arguments

A feature table ID for a contig and a boolean indicating
if feature is in public or private table.

=back



sub contig {
    my $self = shift;
    my ($feature_id, $public) = @_;
    
    my $cc = $public ? "public_$feature_id" : "private_$feature_id";
    
    if($self->cache('contig', $cc)) {
    	return $self->cache('contig', $cc);
    } else {
    	if($public) {
    		
    		$self->{'queries'}{'select_from_public_feature'}->execute(
			    $feature_id         
			);
			my ($uname, $org_id, $residues, $seqlen) = $self->{'queries'}{'select_from_public_feature'}->fetchrow_array(); 
			croak "Contig $feature_id not found in feature table." unless $uname;
			
			my $hash = {
				name => $uname,
				organism => $org_id,
				sequence => $residues,
				len => $seqlen
			};
			
			$self->cache('contig', $cc, $hash);
			return $hash;
			
    	} else {
    		
    		$self->{'queries'}{'select_from_private_feature'}->execute(
			    $feature_id         
			);
			my ($uname, $org_id, $upl_id, $residues, $seqlen) = $self->{'queries'}{'select_from_private_feature'}->fetchrow_array(); 
			croak "Contig $feature_id not found in feature table." unless $uname;
			
			my $hash = {
				name => $uname,
				organism => $org_id,
				upload => $upl_id,
				sequence => $residues,
				len => $seqlen
			};
			
			$self->cache('contig', $cc, $hash);
			return $hash;
    		
    	}
    }
}
=cut


=head2 nextfeature

=over

=item Usage

  $obj->nextfeature()        #get existing value
  $obj->nextfeature($newval) #set new value

=item Function

=item Returns

value of nextfeature (a scalar)

=item Arguments

new value of nextfeature (to set)

=back

=cut

sub nextfeature {
    my $self = shift;
    my $public = shift;

	my $fid;
	if($public) {
		$fid = $self->nextoid('feature',@_);
	    if (!$self->first_feature_id() ) {
	        $self->first_feature_id( $fid );
	    }
	} else {
		$fid = $self->nextoid('private_feature',@_);
	    if (!$self->first_private_feature_id() ) {
	        $self->first_private_feature_id( $fid );
	    }
	}
    
    return $fid;
}


=head2 first_feature_id

=over

=item Usage

  $obj->first_feature_id()        #get existing value
  $obj->first_feature_id($newval) #set new value

=item Function

=item Returns

value of first_feature_id (a scalar), that is, the feature_id of the first
feature parsed in the current session.

=item Arguments

new value of first_feature_id (to set)

=back

=cut

sub first_feature_id {
    my $self = shift;
    my $first_feature_id = shift if @_;
    return $self->{'first_feature_id'} = $first_feature_id if defined($first_feature_id);
    return $self->{'first_feature_id'};
}

sub first_private_feature_id {
    my $self = shift;
    my $first_feature_id = shift if @_;
    return $self->{'first_private_feature_id'} = $first_feature_id if defined($first_feature_id);
    return $self->{'first_private_feature_id'};
}

=head2 placeholder_upload_id

=over

=item Usage

  $obj->placeholder_upload_id()        #get existing value
  $obj->placeholder_upload_id($newval) #set new value

=item Function

=item Returns

value of an upload_id in the table (a scalar), if any exist.

Used in temporary table copied from live table to fulfill
constraints.

=item Arguments

new value of upload_id (to set)

=back

=cut

sub placeholder_upload_id {
	my $self = shift;
	my $upl_id = shift if @_;
    return $self->{'placeholder_upload_id'} = $upl_id if defined($upl_id);
    return $self->{'placeholder_upload_id'}; 
}

=head2 prepare_queries

=over

=item Usage

  $obj->prepare_queries()

=item Function

Does dbi prepare on several cached queries

=item Returns

void

=item Arguments

none

=back

=cut

sub prepare_queries {
    my $self = shift;
    my $dbh  = $self->dbh();
    
	# Queries for obtaining feature info
	my $sql = "SELECT uniquename, organism_id, residues, seqlen FROM feature WHERE feature_id = ?";
	$self->{'queries'}{'select_from_public_feature'} = $dbh->prepare($sql);
	$sql = "SELECT uniquename, organism_id, upload_id, residues, seqlen FROM private_feature WHERE feature_id = ?";
	$self->{'queries'}{'select_from_private_feature'} = $dbh->prepare($sql);

	# Cache queries
	my $ft = $self->{feature_type};
	if($ft eq 'genome' || $ft eq 'party_mix') {
		$sql = "SELECT feature_id FROM feature WHERE uniquename = ?";
		$self->{'queries'}{'genome'}{'validate_public'} = $dbh->prepare($sql);
		$sql = "SELECT feature_id FROM private_feature WHERE uniquename = ?";
		$self->{'queries'}{'genome'}{'validate_private'} = $dbh->prepare($sql);
		$sql= "SELECT db_id FROM db WHERE name = ?";
		$self->{'queries'}{'dbxref'}{'database'} = $dbh->prepare($sql);
		$sql = "SELECT dbxref_id FROM dbxref WHERE db_id = ? AND accession = ? AND version = ?";
		$self->{'queries'}{'dbxref'}{'accession'} = $dbh->prepare($sql);
	}

	if($ft eq 'vfamr' || $ft eq 'party_mix') {
		my $table = $self->{feature_cache}{vfamr}{table};
		$sql = "SELECT feature_id FROM $table WHERE uniquename = ? AND pub = ? ";
		$self->{'queries'}{'vfamr'}{'validate'} = $dbh->prepare($sql);
	}

	if($ft eq 'pangenome' || $ft eq 'party_mix') {
		my $table = $self->{feature_cache}{pangenome}{table};
		$sql = "SELECT feature_id FROM $table WHERE uniquename = ? AND pub = ? ";
		$self->{'queries'}{'pangenome'}{'validate'} = $dbh->prepare($sql);
		$sql = "SELECT feature_id FROM $table WHERE genome_id = ? AND query_id = ? AND pub = ? ";
		$self->{'queries'}{'pangenome'}{'validate_2'} = $dbh->prepare($sql);
	}
	
	# Tree table
	$sql = "SELECT tree_id FROM tree WHERE name = ?";
	$self->{'queries'}{'validate_tree'} = $dbh->prepare($sql);
	
	# Pangenome utilities
	$sql = "SELECT feature_id FROM feature WHERE uniquename = ? AND type_id = ?";
	$self->{'queries'}{'retrieve_pangenome_id'} = $dbh->prepare($sql);
	
	# Cache table
	if($self->{db_cache}) {
		$sql = "SELECT collection_id, contig_id FROM pipeline_cache WHERE tracker_id = ? AND chr_num = ?";
		$self->{'queries'}{'genome'}{'retrieve_id'} = $dbh->prepare($sql);
		$sql = "SELECT name, description FROM pipeline_cache WHERE tracker_id = ? AND chr_num = ?";
		$self->{'queries'}{'genome'}{'retrieve_contig_meta'} = $dbh->prepare($sql);
		$sql = "UPDATE pipeline_cache SET collection_id = ?, contig_id = ? WHERE tracker_id = ? ".
			"AND chr_num = ?";
		$self->{'queries'}{'genome'}{'update_contig_name'} = $dbh->prepare($sql);
	}
	
	# SNP stuff
	if($self->{snp_aware}) {
		# SNP tables
		$sql = "SELECT snp_core_id, aln_column, position, gap_offset, allele, frequency_a, frequency_t, frequency_g, frequency_c, frequency_gap, frequency_other ".
		       "FROM snp_core WHERE pangenome_region_id = ? AND position = ? AND gap_offset = ?";
		$self->{'queries'}{'validate_core_snp'} = $dbh->prepare($sql);
		$sql = "SELECT snp_variation_id FROM snp_variation WHERE snp_id = ? AND contig_collection_id = ?";
		$self->{'queries'}{'validate_public_snp'} = $dbh->prepare($sql);
		$sql = "SELECT snp_variation_id FROM private_snp_variation WHERE snp_id = ? AND contig_collection_id = ?";
		$self->{'queries'}{'validate_private_snp'} = $dbh->prepare($sql);
		# SNP alignment tables
		$sql = "SELECT count(*) FROM snp_alignment WHERE name = ?";
		$self->{'queries'}{'validate_snp_alignment'} = $dbh->prepare($sql);
		$sql = "SELECT contig_collection_id, locus_id, allele FROM snp_variation WHERE snp_id = ?";
		$self->{'queries'}{'retrieve_public_snp_column'} = $dbh->prepare($sql);
		$sql = "SELECT contig_collection_id, locus_id, allele FROM private_snp_variation WHERE snp_id = ?";
		$self->{'queries'}{'retrieve_private_snp_column'} = $dbh->prepare($sql);
		# Core alignment queries
		$sql = "SELECT count(*) FROM pangenome_alignment WHERE name = ?";
		$self->{'queries'}{'validate_core_alignment'} = $self->{'queries'}{'validate_acc_alignment'} = $dbh->prepare($sql);
		$sql = "SELECT aln_column FROM core_region WHERE pangenome_region_id = ?";
		$self->{'queries'}{'validate_core_region'} = $dbh->prepare($sql);
		# Accessory alignment queries
		$sql = "SELECT aln_column FROM accessory_region WHERE pangenome_region_id = ?";
		$self->{'queries'}{'validate_acc_region'} = $dbh->prepare($sql);
	}
	
	
	return;
}


=head2 load_data

=over

=item Usage

  $obj->load_data();

=item Function

Initiate loading of data for all tables and commit
to DB. 

Optionally, perform vacuum of DB after loading complete.

=item Returns

Nothing

=item Arguments

void

=back

=cut
sub load_data {
	my $self = shift;
	my $log = shift;

	logger($log, "start of load_data()");

	my $ft = $self->{feature_type};

	# Print mutable in-memory values to file,
	# now that program has terminated.
	
	my $found_snps;
	if($self->{snp_aware}) {
		logger($log,"Printing snp data to file");
		$found_snps = defined($self->cache('core_snp'));
		if ($found_snps) {
			$self->print_snp_data() 
		} else {
			warn "Warning: No SNPs were found in this run (either new SNP positions or variations at existing positions).";
		}
		logger($log,"complete");
	}

	# Compute typing assignments
	if($ft eq 'vfamr' || $ft eq 'party_mix') {
		logger($log,"Computing subtypes");
		$self->typing($self->tmp_dir());
		logger($log,"complete");
	}

	$self->end_files();

	# This step does not permanently alter DB data
	# Build tree using supertree or whole tree approach

	# Tree files
	my $input_tree_file = $self->tmp_dir() . 'genodo_genome_tree_inputs.txt';
	my $public_tree_file = $self->tmp_dir() . 'genodo_genome_tree_public.txt';
	my $global_tree_file = $self->tmp_dir() . 'genodo_genome_tree_global.txt';
	

	# Matrix R data files
	my $tmp_pg_rfile;
	my $tmp_snp_rfile;
	
	if($self->{snp_aware}) {

		logger($log,"Generating new PG alignments");

		# Make temp tables to load core and snp data
		$self->clone_alignment_tables();
		$self->dbh->commit() || croak "Commit failed: ".$self->dbh->errstr();

		my @new_genomes;
		open(my $in, ">$input_tree_file") or croak "Unable to write to file $input_tree_file ($!)";
		foreach my $key (keys %{$self->{cache}{snp_genome}}){
			my $ghash = $self->{cache}{snp_genome}{$key};
			print $in join("\t", $key, $ghash->{uniquename}, $ghash->{displayname}, $ghash->{visible},
				$ghash->{feature_id}),"\n";
			push @new_genomes, $key;
		}
		close $in;

		# Compute pangenome alignment
		$self->push_pg_alignment(\@new_genomes);
		$self->dbh->commit() || croak "Commit failed: ".$self->dbh->errstr();
		logger($log,"complete");

		# Compute new pangenome matrix file
		logger($log,"Computing new PG matrix for R/Shiny");
		### UNCOMMENT -- DISABLED TREE FOR STEPWISE LOADING OF FWS genomes
		#($tmp_pg_rfile) = $self->binary_state_pg_matrix('pipeline_pangenome_alignment');
		###
		logger($log,"complete");


		if($found_snps) {
			# Compute snp alignment
			logger($log,"Generating new SNP alignments");
			$self->push_snp_alignment(\@new_genomes);
			$self->dbh->commit() || croak "Commit failed: ".$self->dbh->errstr();
			logger($log,"complete");

			# Compute new tree, output to file
			logger($log,"Building global genome tree");
			### UNCOMMENT -- DISABLED TREE FOR STEPWISE LOADING OF FWS genomes
			#$self->build_tree($input_tree_file, $public_tree_file, $global_tree_file);
			#logger($log,"Skipping");
			###
			logger($log,"complete");

			# Compute new snp matrix file
			logger($log,"Computing new snp matrix for R/Shiny");
			### UNCOMMENT -- DISABLED TREE FOR STEPWISE LOADING OF FWS genomes
			#($tmp_snp_rfile) = $self->binary_state_snp_matrix('pipeline_snp_alignment');
			###
			logger($log,"complete");
		}
	}
	
	my %nextvalue = $self->nextvalueHash();

	logger($log,"Updating data in DB");
	foreach my $table (@update_tables) {
	
		$self->file_handles($files{$table})->autoflush;
		
		if (-s $self->file_handles($files{$table})->filename <= 4) {
			warn "Skipping $table table since the load file is empty...\n";
			next;
		}
		
		$self->update_from_stdin(
			$update_table_names{$table},
			$table,
			$tmpcopystring{$table},
			$updatestring{$table},
			$joinstring{$table},
			$files{$table}, #file_handle name
			$joinindices{$table}
		);
	}
	logger($log,"complete");

	logger($log,"Inserting data in DB");
	foreach my $table (@tables) {
	
		$self->file_handles($files{$table})->autoflush;
		
		if (-s $self->file_handles($files{$table})->filename <= 4) {
			warn "Skipping $table table since the load file is empty...\n";
			next;
		}
		
		$self->copy_from_stdin($table,
			$copystring{$table},
			$files{$table}, #file_handle name
			$sequences{$table},
			$nextvalue{$table});
	}
	logger($log,"complete");

	if($self->{snp_aware}) {
		logger($log,"Transfering R/Shiny files");
		# Hot swap temp core and snp tables with live tables
		$self->swap_alignment_tables();

		# Copy pangenome and snp matrix files to final destination on VPN
		# Load genome tree
		if($found_snps) {
			$self->load_tree($public_tree_file, $global_tree_file);
			$self->send_matrix_files($tmp_pg_rfile, $tmp_snp_rfile);
	
		} else {
			# No core regions so no SNPs
			$self->send_matrix_files($tmp_pg_rfile);
		}
		logger($log,"complete");
	}

	
	# Update cache with newly created loci/allele features added in this run
	logger($log,"Updating caches");
	if($ft eq 'party_mix') {
		$self->push_cache('vfamr');
		$self->push_cache('pangenome');
	} elsif($ft eq 'vfamr' || $ft eq 'pangenome') {
		$self->push_cache($ft);
	}
	logger($log,"complete");

	# Commit this giant transaction
	logger($log,"Committing to DB");
	$self->dbh->commit() || croak "Commit failed: ".$self->dbh->errstr();
	logger($log,"complete");
	
	if($ft eq 'party_mix' || $ft eq 'vfamr' || $ft eq 'genome') {
		logger($log,"Recomputing pre-computed data objects");
		# Update and reload meta data since either stx types or genome properties changed
		$self->recompute_metadata();
		logger($log,"complete");
	}

	$self->flush_caches();
	
	if($self->vacuum) {
		warn "Optimizing database (this may take a while) ...\n";
		warn "  ";
		
		foreach (@tables) {
			warn "$_ ";
			$self->dbh->do("VACUUM ANALYZE $_");
		}
		$self->dbh->do("VACUUM ANALYZE snp_alignment") if $self->{snp_aware};
		$self->dbh->do("VACUUM ANALYZE pangenome_alignment") if $self->{snp_aware};
		
		warn "\nWhile this script has made an effort to optimize the database, you\n"
		."should probably also run VACUUM FULL ANALYZE on the database as well.\n";
		
		warn "\nDone.\n";
	}

	logger($log,"load_data() complete");
	
}

=head2 copy_from_stdin

=over

=item Usage

  $obj->copy_from_stdin($table, $fields, $file, $sequence, $nextvalue);

=item Function

Load data  for a single table into DB using COPY ... FROM STDIN; command.

=item Returns

Nothing

=item Arguments

Array containing:
1. table name
2. string containing column field order (i.e. '(primary_id, value1, value2)')
3. name of file containing tab-delim values
4. name of primary key sequence in DB
5. next value in primary key's sequence

=back

=cut

sub copy_from_stdin {
	my $self = shift;
	my $table    = shift;
	my $fields   = shift;
	my $file     = shift;
	my $sequence = shift;
	my $nextval  = shift;

	my $dbh      = $self->dbh();

	warn "Loading data into $table table ...\n";

	my $fh = $self->file_handles($file);
	$fh->autoflush;
	seek($fh,0,0);

	my $query = "COPY $table $fields FROM STDIN;";

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

	#update the sequence so that later inserts will work
	if($sequence) {
		$dbh->do("SELECT setval('$sequence', $nextval) FROM $table")
			or croak("Error when executing:  setval('$sequence', $nextval) FROM $table: $!"); 
	}
	else {
		carp "Table $table does not have primary ID. Primary key not incremented.";
	}
}

=head2 update_from_stdin

=over

=item Usage

  $obj->update_from_stdin($table, $fields, $file, $sequence, $nextvalue);

=item Function

Update data by loading into temporary table and then copying into destination table.

=item Returns

Nothing

=item Arguments

Array containing:
1. table name
2. string containing column field order (i.e. '(primary_id, value1, value2)')
3. name of file containing tab-delim values
4. name of primary key sequence in DB
5. next value in primary key's sequence

=back

=cut

sub update_from_stdin {
	my $self          = shift;
	my $ttable        = shift;
	my $stable        = shift;
	my $copy_fields   = shift;
	my $update_fields = shift;
	my $join          = shift;
	my $file          = shift;
	my $index         = shift;

	my $dbh           = $self->dbh();

	warn "Updating data in $ttable table ...\n";

	my $fh = $self->file_handles($file);
	$fh->autoflush;
	seek($fh,0,0);
	
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

=head2 clone_alignment_tables

=over

=item Usage

  $obj->clone_alignment_tables()

=item Function

Makes a copy of the core- and snp_alignment tables (to do live table swaps). 
DOES NOT call commit. You must do this when desired.

NOTE: the copied table will share sequences with the source table. This is ok since we will be
dropping the source table and replacing it.

=item Returns

Nothing

=item Arguments

1) Name of target table in DB to copy
2) Name of destination table to create and copy data to

=back

=cut

sub clone_alignment_tables {
	my $self = shift;

	my $dbh = $self->dbh();

	my @table_sets = (
		['snp_alignment', 'pipeline_snp_alignment'],
		['pangenome_alignment','pipeline_pangenome_alignment']
	);

	foreach my $ts (@table_sets) {
		my $stable = $ts->[0];
		my $ttable = $ts->[1];
	
		# Delete existing tmp table
		my $sql0 = "DROP TABLE IF EXISTS $ttable";
		$dbh->do($sql0);

		# Copy data and basic structure from source table
		my $sql1 = "CREATE TABLE $ttable AS SELECT * FROM $stable";
		$dbh->do($sql1) or croak("Error when executing: $sql1 ($!).\n");

		# Add schema objects

		# Link sequence to target table, set as primary key
		my $sql2 = "ALTER TABLE ONLY $ttable ALTER COLUMN $stable\_id SET DEFAULT ".
			"nextval('$stable\_$stable\_id_seq'::regclass)";
		$dbh->do($sql2) or croak("Error when executing: $sql2 ($!).\n");

		my $sql3 = "ALTER TABLE ONLY $ttable ".
			"ADD CONSTRAINT $ttable\_pkey PRIMARY KEY ($stable\_id)";
		$dbh->do($sql3) or croak("Error when executing: $sql3 ($!).\n");
		
		# Add index
		my $sql4 = "ALTER TABLE ONLY $ttable ADD CONSTRAINT $ttable\_c1 UNIQUE (name)";
		$dbh->do($sql4) or croak("Error when executing: $sql4 ($!).\n");

		# Set ownership
		### OWNERSHIP SHOULD MATCH current user!!
		#my $sql5 = "ALTER TABLE public.$ttable OWNER TO genodo";
		#$dbh->do($sql5) or croak("Error when executing: $sql5 ($!).\n");
	}

}

=head2 swap_alignment_tables

=over

=item Usage

  $obj->swap_alignment_tables()

=item Function

Replaces source core_ & snp_alignment table with destination table. DOES NOT call commit. 
You must do this when desired.

=item Returns

Nothing

=item Arguments

Nothing

=back

=cut

sub swap_alignment_tables {
	my $self = shift;

	my $dbh = $self->dbh();

	my @table_sets = (
		['snp_alignment', 'pipeline_snp_alignment', 'drop_snp_alignment'],
		['pangenome_alignment','pipeline_pangenome_alignment', 'drop_pangenome_alignment']
	);

	foreach my $ts (@table_sets) {
		my $stable = $ts->[0];
		my $ttable = $ts->[1];
		my $dtable = $ts->[2];

		# Link sequence to target table column
		my $sql1 = "ALTER SEQUENCE $stable\_$stable\_id_seq OWNED BY $ttable.$stable\_id;";
		$dbh->do($sql1) or croak("Error when executing: $sql1 ($!).\n");

		# Rename table and indices for drop table
		my $sql2 = "ALTER TABLE $stable RENAME TO $dtable";
		$dbh->do($sql2) or croak("Error when executing: $sql2 ($!).\n");

		my $sql3 = "ALTER INDEX $stable\_pkey RENAME TO $dtable\_pkey";
		$dbh->do($sql3) or croak("Error when executing: $sql3 ($!).\n");

		my $sql4 = "ALTER INDEX $stable\_c1 RENAME TO $dtable\_c1";
		$dbh->do($sql4) or croak("Error when executing: $sql4 ($!).\n");

		# Move target table to live
		my $sql5 = "ALTER TABLE $ttable RENAME TO $stable";
		$dbh->do($sql5) or croak("Error when executing: $sql5 ($!).\n");

		my $sql6 = "ALTER INDEX $ttable\_pkey RENAME TO $stable\_pkey";
		$dbh->do($sql6) or croak("Error when executing: $sql6($!).\n");

		my $sql7 = "ALTER INDEX $ttable\_c1 RENAME TO $stable\_c1";
		$dbh->do($sql7) or croak("Error when executing: $sql7 ($!).\n");

		# Drop source table
		my $sql8 = "DROP TABLE $dtable";
		$dbh->do($sql8) or croak("Error when executing: $sql8 ($!).\n");

	}

}

=head2 build_tree

=over

=item Usage

  $obj->build_tree($genome_input_filename, $public_tree_output_filename, $global_tree_output_filename)

=item Function

Calls external program to build new genome tree

=item Returns

Nothing

=item Arguments

1 - Filename containing input set of genomes to add to tree. Tab-delim file organized:
    - genome label (e.g. private_123344)
    - uniquename
    - displayname
    - access category (e.g. public|private|release)
    - feature_id
2 - Filename to output PERL-format global tree (all private and publicly-viewable genomes)
3 - Filename to output PERL-format public tree (only publicly viewable genomes)

=back

=cut

sub build_tree {
	my $self = shift;
	my ($input_file, $public_file, $global_file) = @_;

	my $tmp_dir = $self->tmp_dir();

	my @program = ($perl_interpreter, "$root_directory/Phylogeny/add_to_tree.pl",
		"--pipeline",
		"--dsn '".$self->{dbi_connection_parameters}->{dsn}."'",
		"--dbuser '".$self->{dbi_connection_parameters}->{dbuser}."'",
		"--tmpdir ".$tmp_dir,
		"--input ".$input_file,
		"--globalf ".$global_file,
		"--publicf ".$public_file,
		"--fasttree ".$self->{fasttree_exe}
	);

	push @program, "--dbpass '".$self->{dbi_connection_parameters}->{dbpass}."'";
	

	if($self->{supertree}) {
		push @program, "--supertree";
	}
		
	my $cmd = join(' ',@program);
	warn "BUILD TREE COMMAND: $cmd\n";
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		croak "Error: Phylogenetic tree build failed ($stderr).\n";
	}
}

=head2 load_tree

=over

=item Usage

  $obj->load_tree($global_tree_output_filename, $public_tree_output_filename)

=item Function

Updates entries in tree table for the global genome trees

=item Returns

Nothing

=item Arguments

1 - Filename with PERL-format global tree (all private and publicly-viewable genomes)
2 - Filename with PERL-format public tree (only publicly viewable genomes)

=back

=cut

sub load_tree {
	my $self = shift;
	my ($public_file, $global_file) = @_;

	# Load trees into memory
	my ($ptree, $ptree_string) = $self->read_tree_file($public_file);

	my ($gtree, $gtree_string) = $self->read_tree_file($global_file);

	# Update or create tree entries
	my $jtree_string = encode_json($ptree);
	my $dbh = $self->dbh();

	my $select_sth = $dbh->prepare("SELECT count(*) FROM tree WHERE name = ?");
	my $update_sth = $dbh->prepare("UPDATE tree SET tree_string = ? WHERE name = ?");
	my $insert_sth = $dbh->prepare("INSERT INTO tree (name, format, tree_string) VALUES (?,?,?)");
	my @row;

	# Global
	$select_sth->execute('global');
	if(@row = $select_sth->fetchrow_array() && $row[0]) {
		$update_sth->execute($gtree_string, 'global');
	} else {
		$insert_sth->execute('global', 'perl', $gtree_string);
	}

	# Perl public
	$select_sth->execute('perlpub');
	if(@row = $select_sth->fetchrow_array() && $row[0]) {
		$update_sth->execute($ptree_string, 'perlpub');
	} else {
		$insert_sth->execute('perlpub', 'perl', $ptree_string);
	}

	# JSON public
	$select_sth->execute('jsonpub');
	if(@row = $select_sth->fetchrow_array() && $row[0]) {
		$update_sth->execute($jtree_string, 'jsonpub');
	} else {
		$insert_sth->execute('jsonpub', 'json', $jtree_string);
	}

}

=head2 read_tree_file

=over

=item Usage

  $obj->read_tree_file(filename)

=item Function

Loads a perl-formatted string from the file into memory

=item Returns

A perl variable containing pointer to tree root hashref and string representation of
tree

=item Arguments

1 - Filename with PERL-format tree string

=back

=cut

sub read_tree_file {
	my $self = shift;
	my $file = shift;
	
	open(my $in, "<$file") or die "Error: unable to read file $file ($!).\n";

    local($/) = "";
    my ($str) = <$in>;
   
    close $in;
    
    my $tree;
    eval $str;

    return ($tree, $str);
}

=head2 recompute_metadata

=over

=item Usage

  $obj->recompute_metadata()

=item Function

Updates the json objects that contain genomes and their properties

=item Returns

Nothing

=item Arguments

None

=back

=cut

sub recompute_metadata {
	my $self = shift;

	my @program = ($perl_interpreter, "$root_directory/Database/load_meta_data.pl",
		"--dsn '".$self->{dbi_connection_parameters}->{dsn}."'",
		"--dbuser '".$self->{dbi_connection_parameters}->{dbuser}."'",
	);

	push @program, "--dbpass '".$self->{dbi_connection_parameters}->{dbpass}."'";
	
	my $cmd = join(' ',@program);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		croak "Loading of Metadata JSON objects failed ($stderr).";
	}

}

=head2 send_matrix_files

=over

=item Usage

  $obj->send_matrix_files(
    $pangenome_matrix_filepath, $pangenome_functions_filepath,
  	[$snps_matrix_filepath, $snps_functions_filepath]
  )

=item Function

Transfers pangenome and SNP matrix files to remote R/Shiny server on NML VPN

=item Returns

Nothing

=item Arguments

None

=back

=cut

sub send_matrix_files {
	my $self = shift;
	my ($pg_rfile, $snp_rfile) = @_;

	my @program = ($perl_interpreter, "$root_directory/Data/send_group_data.pl",
		"--config ".$self->config(),
		"--pg ".$pg_rfile,
		"--meta"
	);

	if($snp_rfile) {
		push @program, 
			"--snp ".$snp_rfile
	}

	if($self->test) {
		push @program, '--test';
	}
	
	my $cmd = join(' ',@program);
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		croak "Transfer of SNP/Pangenome matrix files failed ($stderr).";
	}

}


=head2 update_tracker

=over

=item Usage

  $obj->update_tracker(tracker_id)

=item Function

Updates the upload_id column in the tracker table
for the provided tracker_id.

upload_id must be in upload to prevent foreign key
violation.

Make sure 

=item Returns

Nothing

=item Arguments

A tracker_id in the tracker table

=back

=cut

sub update_tracker {
	my ($self, $tracking_id, $upload_id) = @_;
	
	my $sth = $self->dbh->prepare("SELECT count(*) FROM upload WHERE upload_id = $upload_id");
	$sth->execute();
	my ($found) = $sth->fetchrow_array();
	
	croak "Method must be called after upload table has been loaded with the provided upload_id: $upload_id." unless $found;
	
	$self->dbh->do("UPDATE tracker SET upload_id = $upload_id WHERE tracker_id = $tracking_id");
	$self->dbh->commit || croak "Tracker table update failed: ".$self->dbh->errstr();
}

=head2 validate_[feature]

=over

=item Usage

  $obj->validate_feature(hashref)

=item Function

Checks if feature is in caches (DB or hash). Returns feature_id if found.
Also indicates if this is a new feature added during current run, or is in DB from
previous run. Returns a result string as follows:

  1. new - feature entirely new (not in db or mem cache)
  2. new_conflict - feature already loaded in this run
  3. db - feature in db (so loaded in previous run, being updated in this run)
  4. db_conflict - feature in db already been updated in this run

=item Arguments

Hash-ref containing:

  feature_type  => (pangenome|genome|vfamr),
  uniquename    => string,
  public        => boolean
    -- the following are for pangenome features only --
  genome => genome_id
  query => query_fragment_id


=item Returns

Array containing:
  1. Result string (new|new_conflict|db|db_conflict)
  2. Feature ID or undef

=item Arguments

The feature_id for the query gene feature, contig collection, the uniquename and a boolean indicating public or private

=back

=cut

sub validate_feature {
    my $self = shift;
	my %arg = @_;

	my $ft = $arg{feature_type};
	croak "Missing argument in validate_feature: feature_type. Must be (vfamr|pangenome|genome)" unless $ft;
	unless ($ft =~ m/$ALLOWED_FEATURE_TYPES/) {
		croak "Invalid argument in validate_feature: feature_type ($ft). Must be (vfamr|pangenome|genome|)"
	}

	# Check memory caches
	my $un = $arg{uniquename};
	croak "Missing argument in validate_feature: uniquename" unless $un;

	if($self->{feature_cache}{$ft}{new}{$un}) {
		return('new_conflict', $self->{feature_cache}{$ft}{new}{$un}{feature_id});
	}
	if($self->{feature_cache}{$ft}{updated}{$un}) {
		return('db_conflict', $self->{feature_cache}{$ft}{updated}{$un});
	}
	
	# Check DB
	my $feature_id = undef;
	my $pub = $arg{public};
	croak "Missing argument in validate_feature: public" unless defined $pub;

	if($ft eq 'genome') {
		# Searching for existing uniquename in DB matching this one is weak
		# check for duplicates
		if($pub) {
			$self->{queries}{genome}{validate_public}->execute($un);
			($feature_id) = $self->{queries}{genome}{validate_public}->fetchrow_array;
		} else {
			$self->{queries}{genome}{validate_private}->execute($un);
			($feature_id) = $self->{queries}{genome}{validate_private}->fetchrow_array;
		}

	} elsif($ft eq 'vfamr') {
		# The allele uniquename contains: query.contig.start.stop.public
		# Duplicate uniquenames indicate multiple gene alleles for same query gene at
		# same position in contig -- a violation!
		# Gene alleles at different positions for the same query, or different query
		# genes at the same position are OK
		$self->{queries}{vfamr}{validate}->execute($un, $pub);
		($feature_id) = $self->{queries}{vfamr}{validate}->fetchrow_array;

	} elsif($ft eq 'pangenome') {
		# Only one pangenome fragment can be mapped to each region of the genome.
		# The pangenome uniquename contains: contig.start.stop.public and
		# is specific to a region of the genome
		$self->{queries}{pangenome}{validate}->execute($un, $pub);
		($feature_id) = $self->{queries}{pangenome}{validate}->fetchrow_array;

		# Only the single highest scoring region is identified for each 
		# pangenome fragment in a genome.
		# Presence of additional pangenome regions with distinct uniquenames
		# indicates a violation of this property.
		my $query_id = $arg{query};
		my $genome_id = $arg{genome};
		$self->{queries}{pangenome}{validate_2}->execute($genome_id, $query_id, $pub);

		while(my ($this_id) = $self->{queries}{pangenome}{validate_2}->fetchrow_array) {
			if($feature_id ne $this_id) {
				return('db_conflict', $this_id);
			}
		}
	
	}

	if($feature_id) {
		# return existing allele ID
		return('db',$feature_id);
		
	} else {
		# no existing allele
		return('new',undef);
	}
}

=head2 genome_uniquename

=over

=item Usage

  $obj->genome_uniquename(uniquename, feature_id)

=item Function

Create uniquename for new genome

=item Returns

uniquename string (possible altered to create uniquename)

=item Arguments

Array containing uniquename string, feature ID for the genome feature.

=back

=cut

sub genome_uniquename {
	my $self = shift;
	my ($uniquename, $nextfeature, $pub) = @_;

	my ($rs, $feature_id) = $self->validate_feature(feature_type => 'genome', 
		uniquename  => $uniquename, public => $pub );

	
	if($rs ne 'new') {
		# Uniquename aleady in DB or already used by another genome in this run
		# Need to generate true uniquename

		$uniquename = "$uniquename ($nextfeature)"; # Should be unique, if not something is screwy

		($rs, $feature_id) = $self->validate_feature(feature_type => 'genome', uniquename  => $uniquename, 
			public => $pub );
		
		croak "Error: uniquename collision ($rs). Unable to generate uniquename using feature_id for $uniquename." 
			if $rs ne 'new';
	}

	# Cache feature
	$self->feature_cache(insert => 1, feature_id => $nextfeature, 
		uniquename => $uniquename, is_public => $pub, feature_type => 'genome');

	return $uniquename;
}




# =head2 validate_snp_alignment

# =over

# =item Usage

#   $obj->validate_snp_alignment($genome_feature_id, $is_public)

# =item Function

# Determines if snp alignment exists for given genome.

# =item Returns

# 1 if not found, else 0 if entry already exists

# =item Arguments

# The feature_id for the contig collection feature, and a boolean indicating public or private

# =back

# =cut

# sub validate_snp_alignment {
#     my $self = shift;
# 	my $genome_id = shift;
# 	my $is_public = shift;
	
# 	my $pre = $is_public ? 'public_':'private_';
# 	my $genome = $pre . $genome_id;
	
# 	unless($self->cache('snp_alignment', $genome)) {
	
# 		$self->{queries}{'validate_snp_alignment'}->execute($genome);
# 		my ($found) = $self->{queries}{'validate_snp_alignment'}->fetchrow_array;
		
# 		if($found) {
# 			$self->cache('snp_alignment', $genome, 1);
# 			return 0;
# 		} else {
# 			return 1;
# 		}
		
# 	} else {
# 		return 0;
# 	}
	
# }

=head2 retrieve_core_snp

=over

=item Usage

  $obj->retrieve_core_snp($query_id, $pos, $gap_offset)

=item Function



=item Returns

Hash:
  snp_id => snp_core_id in snp_core table,
  col    => column in snp_alignment string containing this snp
  freq   => allele frequency array ref
  pos    => position/column in pangenome region alignment where snp arises
  gapo   => gap offset in pangenome region alignment where snp arises (if snp is gap)

=item Arguments

The feature_id for the query pangenome feature, and position of snp in pangenome region

=back

=cut

sub retrieve_core_snp {
    my $self = shift;
	my ($id, $pos, $gap_offset) = @_;
	
	
	my $snp_hash = undef;
	
	if(defined $self->cache('core_snp', "$id.$pos.$gap_offset")) {
		# Search for existing core snp entries in cached values
		$snp_hash = $self->cache('core_snp', "$id.$pos.$gap_offset");

	} else {
		# Search for existing entries in snp_core table

		$self->{queries}{'validate_core_snp'}->execute($id,$pos,$gap_offset);
		my ($core_snp_id, $col, $pos, $gapo, $allele, @frequencyArray) = $self->{queries}{'validate_core_snp'}->fetchrow_array;

		if($core_snp_id) {
			$snp_hash = { snp_id => $core_snp_id, col => $col, freq => \@frequencyArray, pos => $pos, gapo => $gapo,
				pangenome_region => $id, allele => $allele, new => 0 };
		} else {
			$snp_hash = undef;
		}
				
	}
	
	return ($snp_hash);
}

# =head2 validate_core_alignment

# =over

# =item Usage

#   $obj->validate_core_alignment($genome_feature_id, $is_public)

# =item Function

# Determines if core alignment exists for given genome.

# =item Returns

# 1 if not found, else 0 if entry already exists

# =item Arguments

# The feature_id for the contig collection feature, and a boolean indicating public or private

# =back

# =cut

# sub validate_core_alignment {
#     my $self = shift;
# 	my $genome_id = shift;
# 	my $is_public = shift;
	
# 	my $pre = $is_public ? 'public_':'private_';
# 	my $genome = $pre . $genome_id;
	
# 	unless($self->cache('core_alignment', $genome)) {
	
# 		$self->{queries}{'validate_core_alignment'}->execute($genome);
# 		my ($found) = $self->{queries}{'validate_core_alignment'}->fetchrow_array;
		
# 		if($found) {
# 			$self->cache('core_alignment', $genome, 1);
# 			return 0;
# 		} else {
# 			return 1;
# 		}
		
# 	} else {
# 		return 0;
# 	}
	
# }

=head2 retrieve_core_column

=over

=item Usage

  $obj->retrieve_core_column($query_id)

=item Function

Returns and caches the column associated with a
core pangenome region

=item Returns

Column id associated with the core pangenome feature

=item Arguments

The feature_id for the query pangenome feature

=back

=cut

sub retrieve_core_column {
    my $self = shift;
	my ($id) = @_;
	
	# Search for existing core snp entries in cached values
	my $column;
	
	if(defined $self->cache('core_region', $id)) {
		$column = $self->cache('core_region', $id);
	} else {
		# Search for existing entries in snp_core table
		$self->{queries}{'validate_core_region'}->execute($id);
		$column = $self->{queries}{'validate_core_region'}->fetchrow_array;
		
		$self->cache('core_region', $id,  $column) if defined $column;
	}
	
	return $column;
}

=head2 retrieve_acc_column

=over

=item Usage

  $obj->retrieve_acc_column($query_id)

=item Function

Returns and caches the column associated with a
accessory pangenome region

=item Returns

Column id associated with the accessory pangenome feature

=item Arguments

The feature_id for the query pangenome feature

=back

=cut

sub retrieve_acc_column {
    my $self = shift;
	my ($id) = @_;
	
	# Search for existing entries in cached values
	my $column;
	
	if(defined $self->cache('acc_region', $id)) {
		$column = $self->cache('acc_region', $id);
	} else {
		# Search for existing entries in accessory_region table
		$self->{queries}{'validate_acc_region'}->execute($id);
		$column = $self->{queries}{'validate_acc_region'}->fetchrow_array;
		
		$self->cache('acc_region', $id,  $column) if defined $column;
	}
	
	return $column;
}


=head2 retrieve_contig_info

=over

=item Usage

  $obj->retrieve_contig_info(tracker_id, chr_num)

=item Function

Returns the chromosome information for given tmp
chromosome/contig ID

=item Returns

Feature IDs for contig_collection and contig matching
the arguments

=item Arguments

A tracker_id and chr_num in the table pipeline_cache table

=back

=cut

sub retrieve_contig_info {
	my ($self, $tracking_id, $chr_num) = @_;
	
	my ($contig_collection_id, $contig_id);
	my $cache_name = 'uploaded_feature';
	my $cache_key = "tracker_id:$tracking_id.chr_num:$chr_num";
	
	if(defined $self->cache($cache_name, $cache_key)) {
		# Search for matching entries in cached values
		($contig_collection_id, $contig_id) = @{$self->cache($cache_name, $cache_key)};
	} else {
		# Search for existing entries in DB pipeline cache table
		$self->{'queries'}{'genome'}{'retrieve_id'}->execute($tracking_id, $chr_num);
		($contig_collection_id, $contig_id) = $self->{'queries'}{'retrieve_id'}->fetchrow_array();
		
		$self->cache($cache_name, $cache_key, [$contig_collection_id, $contig_id]) if $contig_id;
	}
	
	return ($contig_collection_id, $contig_id);
}

=head2 retrieve_contig_meta

=over

=item Usage

  $obj->retrieve_contig_meta(tracker_id, chr_num)

=item Function

Get operation

=item Returns

Returns the chromosome name and description submitted by user

=item Arguments

A tracker_id and chr_num in the table pipeline_cache table

=back

=cut

sub retrieve_contig_meta {
	my ($self, $tracking_id, $chr_num) = @_;
	
	my ($name, $desc);
	my $cache_name = 'uploaded_meta';
	my $cache_key = "tracker_id:$tracking_id.chr_num:$chr_num";
	
	if(defined $self->cache($cache_name, $cache_key)) {
		# Search for matching entries in cached values
		($name, $desc) = @{$self->cache($cache_name, $cache_key)};
	} else {
		# Search for existing entries in DB pipeline cache table
		$self->{'queries'}{'genome'}{'retrieve_contig_meta'}->execute($tracking_id, $chr_num);
		($name, $desc) = $self->{'queries'}{'genome'}{'retrieve_contig_meta'}->fetchrow_array();
		
		$self->cache($cache_name, $cache_key, [$name, $desc]) if $name;
	}
	
	return ($name, $desc);
}

=head2 handle_parent

=over

=item Usage

  $obj->handle_parent($child_feature_id, $contig_collection_id, $conti_id, $is_public)

=item Function

Create 'part_of' and 'located_in' entries in feature_relationship table.

=item Returns

Nothing

=item Arguments

Hash containing:
  subject => child feature_id
  genome => contig_collection feature_id
  contig => contig feature_id
  public => boolean indicating public or private

=back

=cut

sub handle_parent {
    my $self = shift;
    my %args = @_;

    my $child_id = $args{subject} or croak "Error: missing argument 'subject' in handle_parent().\n";
    my $pub = $args{public};
    croak "Error: missing argument 'public' in handle_parent().\n" unless defined($pub);

    my @rtypes;
    my @parents;
    if($args{genome}) {
    	push @rtypes, $self->relationship_types('part_of');
    	push @parents, $args{genome};
    }

    if($args{contig}) {
    	push @rtypes, $self->relationship_types('located_in');
    	push @parents, $args{contig};
    }
   
    my $rank = 0; 
    my $table = $pub ? 'feature_relationship' : 'private_feature_relationship';
    foreach my $parent_id (@parents) {
    	
    	my $type = shift @rtypes;
		$self->print_frel($self->nextoid($table),$child_id,$parent_id,$type,$rank,$pub);
		$self->nextoid($table,'++');
		
    }
}


=head2 handle_query_hit

=over

=item Usage

  $obj->handle_query_hit($child_feature_id, $query_gene_id, $is_public)

=item Function

Create 'similar_to' entry in feature_relationship table.

=item Returns

Nothing

=item Arguments

The feature_id for the child feature, query gene and a boolean indicating public or private

=back

=cut

sub handle_query_hit {
    my $self = shift;
    my ($child_id, $parent_id, $pub) = @_;
    
    # vf/amr query features are always in public table, so if genome is private
    # this requires the pripub_feature_relationship table
    unless($pub) {
    	$self->add_relationship($child_id, $parent_id, 'similar_to', 0, 1); 
    } else {
    	$self->add_relationship($child_id, $parent_id, 'similar_to', $pub); 
    }
}

=head2 handle_pangenome_loci

=over

=item Usage

  $obj->handle_pangenome_loci($child_feature_id, $query_gene_id, $is_public)

=item Function

Create 'derives_from' entry in feature_relationship table. Adds presence
symbol to core pangenome alignment strings

=item Returns

Nothing

=item Arguments

The feature_id for the child feature, query gene and a boolean indicating public or private

=back

=cut

sub handle_pangenome_loci {
    my $self = shift;
    my ($child_id, $parent_id, $pub, $genome_id) = @_;
    
    # pangenome query features are always in public table, so if genome is private
    # this requires the pripub_feature_relationship table
    unless($pub) {
    	$self->add_relationship($child_id, $parent_id, 'derives_from', 0, 1); 
    } else {
    	$self->add_relationship($child_id, $parent_id, 'derives_from', $pub); 
    }
    
    if($self->cache('core', $parent_id)) {
    	# This is core region
    	
    	# Retrieve column for core region
		my $column = $self->retrieve_core_column($parent_id);
		
		croak "Error: no alignment column assigned to core pangenome region $parent_id." unless defined $column;
		
		# Update value in core region alignment for genome
		$self->has_core_region($genome_id,$pub,$column);

    } else {
    	# This is accessory region
    	
    	# Retrieve column for accessory region
		my $column = $self->retrieve_acc_column($parent_id);
		
		croak "Error: no alignment column assigned to accessory pangenome region $parent_id." unless defined $column;
		
		# Update value in core region alignment for genome
		$self->has_acc_region($genome_id,$pub,$column);
    }
}


=head2 handle_location

=over

=item Usage

  $obj->handle_location($child_feature_id, $contig_id, $start, $end, $is_public)

=item Function

Perform creation of featureloc entry.

=item Returns

Nothing

=item Arguments

The feature_id for the child feature, contig, start and end coords from BLAST and a boolean indicating public or private

=back

=cut

sub handle_location {
	my $self = shift;
    my ($f_id, $src_id, $min, $max, $strand, $pub) = @_;
    
    my $locgrp = 0;
    my $rank = 0;
    
    my $table = $pub ? 'featureloc' : 'private_featureloc';
	                              	
	$self->print_floc($self->nextoid($table),$f_id,$src_id,$min,$max,$strand,$locgrp,$rank,$pub);
	$self->nextoid($table,'++');
    
}

=cut

=head2 handle_allele_properties

=over

=item Usage

  $obj->handle_allele_properties($feature_id, $percent_identity, $is_public, $upload_id)

=item Function

Create featureprop table entries for BLAST results

=item Returns

Nothing

=item Arguments

percent identity, 

=back

=cut

sub handle_allele_properties {
	my $self = shift;
	my ($feature_id, $allele_copy, $pub, $upload_id) = @_;
	
	# assign the copy number
	my $tag = 'copy_number_increase';
      
 	my $property_cvterm_id = $self->featureprop_types($tag);
	unless($property_cvterm_id) {
		carp "Unrecognized feature property type $tag.";
	}
 	
 	my $rank=0;
 	
    my $table = $pub ? 'featureprop' : 'private_featureprop';
	                        	
	$self->print_fprop($self->nextoid($table),$feature_id,$property_cvterm_id,$allele_copy,$rank,$pub,$upload_id);
    $self->nextoid($table,'++');
    
}

=cut

=head2 handle_phylogeny

=over

=item Usage

  $obj->handle_phylogeny($seq_group)

=item Function

  Save tree in table. Link allele and query to tree entry.

=item Returns

Nothing

=item Arguments

??

=back

=cut

sub handle_phylogeny {
	my $self = shift;
	my ($tree, $query_id, $seq_group) = @_;
	
	my $tree_name = "q$query_id"; # Base name on the query gene used to search for the alleles
	
	# check if tree entry already exists
	$self->{queries}{validate_tree}->execute($tree_name);
	my ($tree_id) = $self->{queries}{validate_tree}->fetchrow_array();
	
	if($tree_id) {
		# update existing tree
		$self->print_utree($tree_id, $tree_name, $tree);
		
		# add new tree-feature relationships
		foreach my $genome_hash (@$seq_group) {
			my $allele_id = $genome_hash->{allele};
			if($genome_hash->{is_new}) {
				my $pub = $genome_hash->{public};
				my $table = $pub ? 'feature_tree' : 'private_feature_tree';
				
				$self->print_ftree($self->nextoid($table),$tree_id,$allele_id,'allele',$pub);
				$self->nextoid($table,'++');
			}
		}
		
	} else {
		# create new tree
		
		$tree_id = $self->nextoid('tree');
		
		# build tree-feature relationships
		# query
		                                  	
		$self->print_ftree($self->nextoid('feature_tree'),$tree_id,$query_id,'locus',1);
		$self->nextoid('feature_tree','++');
		
		# alleles
		foreach my $genome_hash (@$seq_group) {
			my $allele_id = $genome_hash->{allele};
			my $pub = $genome_hash->{public};
			my $table = $pub ? 'feature_tree' : 'private_feature_tree';
			                              	
			$self->print_ftree($self->nextoid($table),$tree_id,$allele_id,'allele',$pub);
			$self->nextoid($table,'++');
		}
		
		# print tree
		$self->print_tree($tree_id,$tree_name,'perl',$tree);
		$self->nextoid('tree','++');
	}

}

=cut

=head2 handle_pangenome_segment

=over

=item Usage

  $obj->handle_pangenome_segment()

=item Function

Handles the insertion of a new pangenome segment. Only call on 
NEW segements.


=item Returns

Nothing

=item Arguments



=back

=cut

sub handle_pangenome_segment {
	my $self = shift;
	my ($in_core, $func, $func_id, $seq) = @_;
	
	# Create pangenome feature
	
	# Public Feature ID
	my $is_public = 1;
	my $curr_feature_id = $self->nextfeature($is_public);
	
	# Default organism
	my $organism = $self->organism_id();
		
	# Null external accession
	my $dbxref = '\N';
	
	# Feature type
	my $type = $self->feature_types('pangenome');
	
	# Sequence length
	my $seqlen = length $seq;
		
	# uniquename & name
	my $pre = $in_core ? 'core ' : 'accessory ';
	my $name = my $uniquename = $pre ."pan-genome fragment $curr_feature_id";
	
	# Core designation
	my $core_value = $in_core ? 'FALSE' : 'TRUE';
	my $core_type = $self->feature_types('core_genome');
    my $rank = 0;

	my $table = 'feature_cvterm';
	                             	
	$self->print_fcvterm($self->nextoid($table), $curr_feature_id, $core_type, $self->publication_id, $rank, $is_public, $core_value);
	$self->nextoid($table,'++');
		
	# assign pangenome function properties
	my @tags;
	my @values;
	if($func) {
		push @tags, 'panseq_function';
		push @values, $func;
	}
	if($func_id) {
		push @tags, 'match';
		push @values, $func_id;
	}
	
	foreach my $tag (@tags) {
		
		my $property_cvterm_id = $self->featureprop_types($tag);
		unless($property_cvterm_id) {
			carp "Unrecognized feature property type $tag.";
		}
		
	 	my $rank=0;
	 	
	    my $table = 'featureprop';
	    my $value = shift @values;
		
		$self->print_fprop($self->nextoid($table),$curr_feature_id,$property_cvterm_id,$value,$rank,$is_public);
	    $self->nextoid($table,'++');
	}
	
	# Print pangenome feature
	$self->print_f($curr_feature_id, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $seq, $is_public);  
	$self->nextfeature($is_public, '++');

	# Update caches

	# Feature ID
	$self->cache('feature', $uniquename, $curr_feature_id);
	
	# Core status
	$self->cache('core', $curr_feature_id, $in_core);

	# Function
	$self->cache('function', $curr_feature_id, [$func_id, $func]) if $func_id && $func;
	
	if($in_core) {
		# Sequence
		$self->cache('sequence',$curr_feature_id,$seq);

		# Create column in core alignment for this new core region
		my $column = $self->add_core_column();
		$table = 'core_region';
		my $ref_core_id = $self->nextoid($table);	                                 	
		$self->print_cr($ref_core_id,$curr_feature_id,$column);
		$self->nextoid($table,'++');
		$self->cache('core_region',$curr_feature_id, $column);

	} else {
		# Create column in accessory alignment for this new accessory region
		my $column = $self->add_acc_column();
		$table = 'accessory_region';
		my $ref_acc_id = $self->nextoid($table);	                                 	
		$self->print_ar($ref_acc_id,$curr_feature_id,$column);
		$self->nextoid($table,'++');
		$self->cache('acc_region',$curr_feature_id, $column);
	}
	
	return($curr_feature_id);
}

=cut

=head2 handle_pangenome_alignment

=over

=item Usage

  $obj->handle_pangenome_alignment()

=item Function

Handles the insertion of a new pangenome alignment. Only call on 
NEW segements.

=item Returns

Nothing

=item Arguments



=back

=cut

sub handle_pangenome_alignment {
	my $self = shift;
	my ($pg_id, $aligned_seq) = @_;
	
	# Create pangenome alignment feature
	
	# Public Feature ID
	my $is_public = 1;
	my $curr_feature_id = $self->nextfeature($is_public);
	
	# Default organism
	my $organism = $self->organism_id();
		
	# Null external accession
	my $dbxref = '\N';
	
	# Feature type
	my $type = $self->feature_types('reference_pangenome_alignment');
	
	# Sequence length
	my $seqlen = length $aligned_seq;
		
	# uniquename & name
	my $name = my $uniquename = "aligned sequence of pangenome region $pg_id";

	# Assign relationship to pangenome region
	$self->add_relationship($curr_feature_id, $pg_id, 'aligned_sequence_of', $is_public);
	
	# Print pangenome alignment feature
	$self->print_f($curr_feature_id, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $aligned_seq, $is_public);  
	$self->nextfeature($is_public, '++');
	
	return($curr_feature_id);
}




=cut

=head2 handle_snp

=over

=item Usage

  $obj->handle_snp()

=item Function

  Save snp

=item Returns

Nothing

=item Arguments



=back

=cut

sub handle_snp {
	my $self = shift;
	my ($ref_id, $c2, $ref_pos, $rgap_offset, $contig_collection, $contig, $locus, $c1, $is_public) = @_;
	
	croak "Positioning violation! $c2 character with gap offset value $rgap_offset for core sequence." if ($rgap_offset && $c2 ne '-') || (!$rgap_offset && $c2 eq '-');
	
	if($DEBUG) {
		warn "LOADING SNP FOR :".join(', ', $ref_id, $c2, $ref_pos, $rgap_offset, $contig_collection, $contig, $locus, $c1, $is_public) . "\n";
	}


	# Retrieve reference snp, if it exists
	my $uniquename = "$ref_id.$ref_pos.$rgap_offset";
	my $snp_hash = $self->retrieve_core_snp($ref_id, $ref_pos, $rgap_offset);

	my ($ref_snp_id, $column);
	
	unless($snp_hash) {
		# Create new core snp
		$ref_snp_id = $self->add_core_snp($ref_id, $ref_pos, $rgap_offset, $c2, $c1);

		if($DEBUG) {
			warn "ADDING new core snp $ref_id.$ref_pos.$rgap_offset\n";
		}
		
	} else {
		# Existing core snp
		$ref_snp_id = $snp_hash->{snp_id};
		$column = $snp_hash->{col};

		my @frequencyArray = @{$snp_hash->{freq}};

		if($DEBUG) {
			warn "EXISTING core snp $ref_id.$ref_pos.$rgap_offset with ID $ref_snp_id.\n";
			my ($word) = (defined($column) ? 'IS assigned - '.$column : 'NOT assigned');
			warn "\tSnp alignment column $word.\n";
			warn "\tSnp frequency: ".join(", ",@frequencyArray)."\n";
		}

		
		# Update frequency
		@frequencyArray = _update_frequency_array($c1, @frequencyArray);
		$snp_hash->{freq} = \@frequencyArray;


		
		# Does the updated allele frequency indicate that this is now a polymorphism
		if(!defined($column) && _is_polymorphism($c2, @frequencyArray)) {
			# Now officially snp, add new snp column to alignment

			($column) = $self->add_snp_column($c2, $ref_snp_id);
			$snp_hash->{col} = $column;
			$self->{snp_alignment}{new_columns}{$ref_snp_id} = [$column, $ref_id, $uniquename];

# REMOVE IF MEMORY LOOK UPS ARE FAST
#			# Set all previous variations to new column value
#			$self->{snp_alignment}{update_tmp_variations}->execute($column, $ref_snp_id);
#			$self->dbh->commit || croak "Update of tmp_snp_cache column for snp $ref_snp_id failed: ".$self->dbh->errstr();

			# print "ASSIGNING COLUMN $column to NEW SNP $ref_snp_id\n" if $DEBUG;

		} elsif(defined $column) {
			# Snp in alignment
			
			# Record modified snp column
			$self->{snp_alignment}{modified_columns}{$ref_snp_id} = [$column, $ref_id];
		}

		$self->cache('core_snp', $uniquename, $snp_hash);
		
	}
		
	# Create variation entry
	my $table = $is_public ? 'snp_variation' : 'private_snp_variation';
	$self->print_sv($self->nextoid($table),$ref_snp_id,$contig_collection,$contig,$locus,$c1,$is_public);
	$self->nextoid($table,'++');

	# Record all variations in cache
	$self->alter_snp($contig_collection,$is_public,$ref_snp_id,$column,$c1);

}

sub _update_frequency_array {
	my $nuc = shift;
	my @frequencyArray = @_;
	
	@frequencyArray = (0) x 6 unless @frequencyArray;
	
	if($nuc eq 'A') {
		$frequencyArray[0]++;
	} elsif($nuc eq 'T') {
		$frequencyArray[1]++;
	} elsif($nuc eq 'G') {
		$frequencyArray[2]++;
	} elsif($nuc eq 'C') {
		$frequencyArray[3]++;
	} elsif($nuc eq '-') {
		$frequencyArray[4]++;
	} else {
		$frequencyArray[5]++;
	} 
	
	return @frequencyArray;
}

sub _is_polymorphism {
	my ($bkg, @frequencyArray) = @_;

	my $states = 0;

	$states++ if $bkg =~ m/[ATGC]/i;

	$states++ if $frequencyArray[0] >= 1 && $bkg ne 'A';

	$states++ if $frequencyArray[1] >= 1 && $bkg ne 'T';

	$states++ if $frequencyArray[2] >= 1 && $bkg ne 'G';

	$states++ if $frequencyArray[3] >= 1 && $bkg ne 'C';
	
	return 1 if $states > 1;

	return 0;
}

=cut

=head2 add_core_snp

=over

=item Usage

  $obj->add_core_snp($pg_id, $align_pos, $gap_offset, $ref_c, $c)

=item Function

  Create new reference SNP entry.

  At time point only one genome will have variation.

=item Returns

ID for newly added snp_core entry

=item Arguments

  1. Int: pangenome fragment ID
  2. Int: position in pangenome alignment
  3. Int: gap offset in pangenome alignment
  4. Char: background allele character
  5. Char: genome variation charater

=back

=cut

sub add_core_snp {
	my $self = shift;
	my ($ref_id, $ref_pos, $rgap_offset, $ref_c, $c) = @_;

	# Allele frequency > 1 in order to add to snp alignment,
	# so at this point snp will not be in alignment
		
	# Starting frequency counts
	# NOTE: background (or SNPs with char matching the snp_core allele char) are not counted
	my @frequencyArray = _update_frequency_array($c);
		
	my $table = 'snp_core';
	my $ref_snp_id = $self->nextoid($table);
	#$self->cache('new_core_snp',"$ref_id.$ref_pos.$rgap_offset", [$ref_snp_id,$ref_id,$ref_c,$ref_pos,$rgap_offset]);
	$self->nextoid($table,'++');
	$self->cache('core_snp',"$ref_id.$ref_pos.$rgap_offset", 
		{ snp_id => $ref_snp_id, col => undef, freq => \@frequencyArray, pos => $ref_pos, gapo => $rgap_offset,
			pangenome_region => $ref_id, allele => $ref_c, new => 1 }
	);

	return $ref_snp_id;
}

=cut

=head2 handle_snp_alignment_block

=over

=item Usage

  $obj->handle_snp_alignment_block()

=item Function

  Save pairwise alignment encodings

=item Returns

Nothing

=item Arguments



=back

=cut

sub handle_snp_alignment_block {
	my $self = shift;
	my ($contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public) = @_;

	if($DEBUG) {
		warn "LOADING POSITIONS FOR :".join(', ', $contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public) . "\n";
	}

	# Block transitions should occur at:
	# termination of a gap in one sequence
	#   or
	# A gap column at the start of a new block (which could be a run-on of a previous gap)
	if($gap1 == 0 && $gap2 != 0 && ($start2 != $end2 || ($start1+1) != $end1)) {
		croak "Positioning violation in alignment block! gap in reference sequence aligned with nt in comparison sequence must be of length 1\n\tdetails: ".
			join(', ',$contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public)."\n";
	} elsif($gap2 == 0 && $gap2 != 0 && ($start1 != $end1 || ($start2+1) != $end2+1)) {
		croak "Positioning violation in alignment block! gap in comparison sequence aligned with nt in reference sequence must be of length 1\n\tdetails: ".
			join(', ',$contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public)."\n";
	} elsif($gap2 != $gap1 && (($start2+1) < $end2 || ($start1+1) < $end1)) {
		croak "Positioning violation in alignment block! in extended alignment blocks, gaps must be equal representing gap columns in both sequences\n\tdetails: ".
			join(', ',$contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2, $is_public)."\n";
	}
	
	
	if($gap1 && $start1 == $end1) {
		# Reference gaps go into 'special' table
		# Note: When there are gap offset values for both reference and comparison sequence (not necessarily equal if there was preceding gaps), 
		# implies that a gap column was encountered. Gap columns inside alignment blocks are ignored.
		
		my $snp_hash = $self->retrieve_core_snp($ref_id, $start1, $gap1);
		croak "Error: SNP in reference pangenome region $ref_id (pos: $start1, gap-offset: $gap1) not found." unless defined $snp_hash && defined $snp_hash->{snp_id};
		my $core_snp_id = $snp_hash->{snp_id};
		# Cache it for faster look-ups
		$self->cache('core_snp',"$ref_id.$start1.$gap1", $snp_hash) unless defined $self->cache('core_snp',"$ref_id.$start1.$gap1");
		
		my $table = $is_public ? 'gap_position' : 'private_gap_position';
		$self->print_gp($self->nextoid($table),$contig_collection, $contig, $ref_id, $locus, $core_snp_id, $start2, $gap2, $is_public);
		$self->nextoid($table,'++');
		
	} else {
		# Create standard snp position entry: reference nuc aligned to gap or nuc in comparison strain
		
		my $table = $is_public ? 'snp_position' : 'private_snp_position';
		$self->print_sp($self->nextoid($table), $contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap2, $is_public);
		$self->nextoid($table,'++');
	}
	
	
	
}

=cut

=head2 handle_genome_properties

=over

=item Usage

  $obj->handle_genome_properties($feature_id, $featureprop_hashref, $is_genome, $is_public, $upload_id)

=item Function

Create featureprop table entries. Create groups when feature is genome (and not contig)

=item Returns

Nothing

=item Arguments

1) Hash with valid fp_types keys.
2) Boolean which is True when feature is genome
3) Boolean which is True when genome/contig is public
4) Upload ID[Optional] when is_public = False

=back

=cut

sub handle_genome_properties {
	my $self = shift;
	my ($feature_id, $fprops, $is_genome, $pub, $upl_id) = @_;

	my $table = $pub ? 'featureprop' : 'private_featureprop';

	my %fprop_ids;

	foreach my $tag (keys %$fprops) {
      
      	my $property_cvterm_id = $self->featureprop_types($tag);
		unless($property_cvterm_id) {
      		carp "Unrecognized feature property type $tag.";
      		next;
      	}
      	
		# All property values can be single value scalars or array ref of multiple values
		# Rank is assigned based on a FIFO scheme
		my $value = $fprops->{$tag};
		my @value_stack;
		
		if(ref $value eq 'ARRAY') {
			@value_stack = @$value;
		} else {
			push @value_stack, $value;
		}
		
      	my $rank=0;
      	foreach my $value (@value_stack) {
      		my $fp_id = $self->nextoid($table);
			$self->print_fprop($fp_id,$feature_id,$property_cvterm_id,$value,$rank,$pub,$upl_id);
        	$self->nextoid($table,'++');
        	$rank++;

        	$fprop_ids{$tag}{$value} = $fp_id;
      	}
    }

    if($is_genome) {
	    # Assign standard groups based on meta-data values
	    $table = $pub ? 'feature_group' : 'private_feature_group';
	    my $default_fp_id = undef;
	    if($self->{assign_groups}) {
	    	 foreach my $meta_type (keys %{$self->{groups}{featureprop_group_assignments}}) {
	    	 	if(defined $fprops->{$meta_type}) {
	    	 		# Find corresponding standard group ID matching meta-data values

	    	 		my $value = $fprops->{$meta_type};
					my @value_stack;
					
					if(ref $value eq 'ARRAY') {
						@value_stack = @$value;
					} else {
						@value_stack = ($value);
					}

	    	 		foreach my $v (@value_stack) {

	    	 			my $group_id = $self->{groups}{featureprop_group_assignments}{$meta_type}{$v};
						$group_id = $self->{groups}{featureprop_group_assignments}{$meta_type}{"$v\_other"} unless $group_id;
						# TODO need to add groups on the fly for Other and NA groups
						croak "Error: no group for value $v in data type $meta_type." unless $group_id;

						my $fp_id = $fprop_ids{$meta_type}{$v};
						$self->print_fgroup($self->nextoid($table),$feature_id,$group_id,$fp_id,$pub);
						$self->nextoid($table,'++');
					}

	    	 	} 
	    	 	else {
	    	 		# No meta-data value, assign to 'unassigned' group
	    	 		my $default_value = "$meta_type\_na";
					my $default_group = $self->{groups}{featureprop_group_assignments}{$meta_type}{$default_value};
					croak "Error: no default 'unassigned' group for data type $meta_type." unless $default_group;

					$self->print_fgroup($self->nextoid($table),$feature_id,$default_group,$default_fp_id,$pub);
					$self->nextoid($table,'++');

	    	 	}
	    	}
	    }
	}

}



=head2 handle_dbxref

=over

=item Usage

  $obj->handle_dbxref($feature_id, $dbxref_hashref)

=item Function

  Create db, dbxref and feature_dbxref table entries as needed. Save the primary
  dbxref for later loading in the feature table.

=item Returns

Nothing

=item Arguments

  Nested hashs, keyed as:
    a. primary => dbxref hashref
    b. secondary => array of dbxref hashrefs
  
  There must be a primary if there is any secondary dbxref. Each dbxref hash
  must contain keys:
    i.   db
    ii.  acc
  and optionally
    iii. ver
    iv.  desc

=back

=cut

sub handle_dbxref {
    my $self = shift;
    my ($feature_id, $dbxhash_ref, $pub) = @_;
    
    # Primary dbxref is first on list
    # primary dbxref_id stored in feature table and in feature_dbxref table
    # secondary dbxref_id stored only in feature_dbxref table
    croak 'Must define a primary dbxref before defining secondary dbxrefs.' unless $dbxhash_ref->{primary};
    my @dbxrefs = ($dbxhash_ref->{primary});
    push @dbxrefs, @{$dbxhash_ref->{secondary}} if $dbxhash_ref->{secondary};
    my $primary_dbxref_id;

    my $table = $pub ? 'feature_dbxref' : 'private_feature_dbxref';
    
	foreach my $dbxref (@dbxrefs) {
		my $database  = $dbxref->{db};
		my $accession = $dbxref->{acc};
      	my $version   = $dbxref->{ver};
		my $desc      = $dbxref->{desc};
		
		my $dbxref_id;
		if($dbxref_id = $self->cache('dbxref',"$database|$accession|$version")) {
			# dbxref has been created previously in this run
			carp "Database cross-reference used multiple times ($database|$accession|$version for feature $feature_id).";
			
			$self->print_fdbx($self->nextoid($table), $feature_id, $dbxref_id, $pub);
          	$self->nextoid($table,'++');
        	
      	} else {
      		# New dbxref for this run
      		
      		# Search for database
          	unless ($self->cache('db', $database)) {
          		
				$self->{queries}{dbxref}{database}->execute("$database");
				my ($db_id) = $self->{queries}{dbxref}{database}->fetchrow_array;
				
				unless($db_id) { 
					# DB not found. Create db entry
					carp "Couldn't find database '$database' in db table. Adding new DB entry";
					$db_id = $self->nextoid('db');
				  	$self->print_dbname($db_id, $database, "autocreated:$database");
				  	$self->nextoid('db','++');
				}
				
				$self->cache('db', $database, $db_id);
          	}
          	
          	# Search for existing dbxref
          	$self->{queries}{dbxref}{accession}->execute($self->cache('db', $database), $accession, $version);
			($dbxref_id) = $self->{queries}{dbxref}{accession}->fetchrow_array;

			if($dbxref_id) {
				# Found existing dbxref
				
				carp "Database cross-reference used multiple times ($database|$accession|$version for feature $feature_id).";
            		
        		$self->print_fdbx($self->nextoid($table), $feature_id, $dbxref_id, $pub);
          		$self->nextoid($table,'++');
            	
            	$self->cache('dbxref',"$database|$accession|$version", $dbxref_id);
            	
			} else {
				# New dbxref
				
				$dbxref_id = $self->nextoid('dbxref');
				
        		$self->print_fdbx($self->nextoid($table), $feature_id, $dbxref_id, $pub);
          		$self->nextoid($table,'++'); #$nextfeaturedbxref++;
            	
				$self->print_dbx($dbxref_id, $self->cache('db',$database), $accession, $version, $desc);
				$self->cache('dbxref', "$database|$accession|$version", $dbxref_id);
				$self->nextoid('dbxref', '++');
			}
      	}
      	
      	$primary_dbxref_id = $dbxref_id unless defined($primary_dbxref_id);
	}
	
	return $primary_dbxref_id;
}

=cut

=head2 handle_genome_location

=over

=item Usage

  $obj->handle_genome_location($feature_id, $geocoded_location_id, $is_public)

=item Function

Create genome_location table entries.

=item Returns

Nothing

=item Arguments

Hash with valid fp_types keys.

=back

=cut

sub handle_genome_location {
	my $self = shift;
	my ($feature_id, $loc, $pub) = @_;

	my $location_id = $loc->{isolation_location};

	croak "Error: Genome $feature_id location is missing / contains invalid 'isolation_location' value.\n" 
		unless $location_id || $location_id =~ m/^\d+$/;

	$self->print_gloc($feature_id,$location_id,$pub);
}


=head2 add_types

=over

=item Usage

  $obj->add_types($child_feature_id, $is_public)

=item Function

Add 'experimental feature' type in feature_cvterm table.

=item Returns

Nothing

=item Arguments

The feature_id for the child feature.

=back

=cut

sub add_types {
    my $self = shift;
    my ($child_id, $pub) = @_;
    
    my $ef_type = $self->feature_types('experimental_feature');
    my $rank = 0;

	my $table = $pub ? 'feature_cvterm' : 'private_feature_cvterm';
	                                 	
	$self->print_fcvterm($self->nextoid($table), $child_id, $ef_type, $self->publication_id, $rank, $pub);
	$self->nextoid($table,'++');
}

=head2 handle_query_hit

=over

=item Usage

  $obj->handle_query_hit($child_feature_id, $query_gene_id, $is_public)

=item Function

Create 'similar_to' entry in feature_relationship table.

=item Returns

Nothing

=item Arguments

The feature_id for the child feature, query gene and a boolean indicating public or private

=back

=cut

sub add_relationship {
    my $self = shift;
    my ($child_id, $parent_id, $reltype, $pub, $xpub) = @_;
    
  	my $rtype = $self->relationship_types($reltype);
  	croak "Unrecognized relationship type: $reltype." unless $rtype;
    my $rank = 0;
    
    # If this relationship is unique, add it.
    my $table;
    my $pub_type;
    if($pub) {
    	$table = 'feature_relationship';
    	$pub_type = 1;
    } else {
    	if($xpub) {
    		$table = 'pripub_feature_relationship';
    		$pub_type = 2;
    	} else {
    		$table = 'private_feature_relationship';
    		$pub_type = 0;
    	}
    }
    	                               	
	$self->print_frel($self->nextoid($table),$child_id,$parent_id,$rtype,$rank,$pub,$xpub);
	$self->nextoid($table,'++');
   
}


#################
# Printing
#################

# Prints to file handles for later COPY run

sub print_dbname {
	my $self = shift;
	my ($db_id,$name,$description) = @_;
	
	$description ||= '\N';
	
	my $fh = $self->file_handles('db');
	
	print $fh join("\t",($db_id,$name,$description)),"\n";
	
}

sub print_fdbx {
	my $self = shift;
	my ($fd_id,$f_id,$dx_id,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('feature_dbxref');		
	} else {
		$fh = $self->file_handles('private_feature_dbxref');
	}
	
	print $fh join("\t",($fd_id,$f_id,$dx_id)),"\n";
	
}

sub print_dbx {
	my $self = shift;
	my ($dbx_id,$db_id,$acc,$vers,$desc) = @_;
	
	my $fh = $self->file_handles('dbxref');
	
	print $fh join("\t",($dbx_id,$db_id,$acc,$vers,$desc)),"\n";
	
}

sub print_fprop {
	my $self = shift;
	my ($fp_id, $f_id, $cvterm_id, $value, $rank, $pub, $upl_id) = @_;

	if($pub) {
		my $fh = $self->file_handles('featureprop');
		print $fh join("\t",($fp_id,$f_id,$cvterm_id,$value,$rank)),"\n";		
	} else {
		my $fh = $self->file_handles('private_featureprop');
		print $fh join("\t",($fp_id,$f_id,$cvterm_id,$value,$upl_id,$rank)),"\n";
	}
  
}

sub print_gloc {
	my $self = shift;
	my ($f_id,$l_id,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('genome_location');		
	} else {
		$fh = $self->file_handles('private_genome_location');
	}
	
	print $fh join("\t", ($f_id,$l_id)),"\n";
}

sub print_fcvterm {
	my $self = shift;
	my ($nextfeaturecvterm,$nextfeature,$type,$ref,$rank,$pub,$is_not) = @_;
	
	$is_not = 'FALSE' unless $is_not; # Default
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('feature_cvterm');		
	} else {
		$fh = $self->file_handles('private_feature_cvterm');
	}
	
	print $fh join("\t", ($nextfeaturecvterm,$nextfeature,$type,$ref,$is_not,$rank)),"\n";
}

sub print_frel {
	my $self = shift;
	my ($nextfeaturerel,$nextfeature,$parent,$part_of,$rank,$pub,$xpub) = @_;
	
	my $fh;
	if($pub) {
		
		$fh = $self->file_handles('feature_relationship');
			
	} else {
		if($xpub) {
			$fh = $self->file_handles('pripub_feature_relationship');
		} else {
			$fh = $self->file_handles('private_feature_relationship');
		}
	}
	
	print $fh join("\t", ($nextfeaturerel,$nextfeature,$parent,$part_of,$rank)),"\n";
}

sub print_floc {
	my $self = shift;
	my ($nextfeatureloc,$nextfeature,$src,$min,$max,$str,$lg,$rank,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('featureloc');		
	} else {
		$fh = $self->file_handles('private_featureloc');
	}
	
	print $fh join("\t", ($nextfeatureloc,$nextfeature,$src,$min,$max,$str,$lg,$rank)),"\n";
}

sub print_f {
	my $self = shift;
	my ($nextfeature,$organism,$name,$uniquename,$type,$seqlen,$dbxref,$residues,$pub,$upl_id) = @_;
	
	$dbxref ||= '\N';
	
	if(!$pub) {
		my $fh = $self->file_handles('private_feature');
		print $fh join("\t", ($nextfeature, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $upl_id, $residues)),"\n";		
	} else {
		my $fh = $self->file_handles('feature');
		print $fh join("\t", ($nextfeature, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $residues)),"\n";
	}
}

sub print_tree {
	my $self = shift;
	my ($tree,$name,$format,$string) = @_;
	
	my $fh = $self->file_handles('tree');		

	print $fh join("\t", ($tree,$name,$format,$string)),"\n";
}

sub print_ftree {
	my $self = shift;
	my ($nextft,$tree_id,$feature_id,$type,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('feature_tree');		
	} else {
		$fh = $self->file_handles('private_feature_tree');
	}	

	print $fh join("\t", ($nextft,$feature_id,$tree_id,$type)),"\n";
}

sub print_fgroup {
	my $self = shift;
	my ($nextfeaturegroup,$feature,$group,$fp,$pub) = @_;

	# fp can be null
	$fp = '\N' unless defined $fp;
	
	my $fh;
	if($pub) {
		
		$fh = $self->file_handles('feature_group');
			
	} else {
		
		$fh = $self->file_handles('private_feature_group');
	}
	
	print $fh join("\t", $nextfeaturegroup,$feature,$group,$fp),"\n";
}

sub print_sc {
	my $self = shift;
	my ($sc_id,$ref_id,$nuc,$pos,$gap,$col,$freqA) = @_;

	# col can be null
	$col = '\N' unless defined $col;

	my $fh = $self->file_handles('snp_core');		

	print $fh join("\t", ($sc_id,$ref_id,$nuc,$pos,$gap,$col,@$freqA)),"\n";
}

sub print_cr {
	my $self = shift;
	my ($cr_id,$ref_id,$col) = @_;
	
	my $fh = $self->file_handles('core_region');		

	print $fh join("\t", ($cr_id,$ref_id,$col)),"\n";
}

sub print_ar {
	my $self = shift;
	my ($ar_id,$ref_id,$col) = @_;
	
	my $fh = $self->file_handles('accessory_region');		

	print $fh join("\t", ($ar_id,$ref_id,$col)),"\n";
}

sub print_sv {
	my $self = shift;
	my ($nextft,$snp_id,$genome_id,$contig_id,$locus,$nuc,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('snp_variation');		
	} else {
		$fh = $self->file_handles('private_snp_variation');
	}	

	print $fh join("\t", ($nextft,$snp_id,$genome_id,$contig_id,$locus,$nuc)),"\n";
}

sub print_sp {
	my $self = shift;
	my ($nextft,$genome_id,$contig_id,$ref,$locus,$s1,$s2,$e1,$e2,$g,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('snp_position');		
	} else {
		$fh = $self->file_handles('private_snp_position');
	}	

	print $fh join("\t", ($nextft,$genome_id,$contig_id,$ref,$locus,$s1,$s2,$e1,$e2,$g)),"\n";
}

sub print_gp {
	my $self = shift;
	my ($nextft,$genome_id,$contig_id,$ref,$locus,$snp,$s2,$g2,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('gap_position');		
	} else {
		$fh = $self->file_handles('private_gap_position');
	}	

	print $fh join("\t", ($nextft,$genome_id,$contig_id,$ref,$locus,$snp,$s2,$g2)),"\n";
}


# Print to tmp tables for update

sub print_uf {
	my $self = shift;
	my ($nextfeature,$uname,$type,$seqlen,$residues,$pub,$upl) = @_;
	
	my $org_id = 13; # just need to put in some value to fulfill non-null constraint
	
	my $fh;
	my @fields;	
	if($pub) {
		$fh = $self->file_handles('tfeature');
		@fields = ($nextfeature, $org_id, $uname, $type, $seqlen, $residues);
	} else {
		$fh = $self->file_handles('tprivate_feature');
		@fields = ($nextfeature, $org_id, $uname, $type, $seqlen, $residues, $upl);
	}
	
	print $fh join("\t", @fields),"\n";
	
}

sub print_ufprop {
	my $self = shift;
	my ($f_id,$cvterm_id,$value,$rank,$pub,$upl) = @_;
	
	$rank = 0 unless defined $rank;
	
	my $fh;
	my @fields;	
	if($pub) {
		$fh = $self->file_handles('tfeatureprop');
		@fields = ($f_id,$cvterm_id,$value,$rank);		
	} else {
		$fh = $self->file_handles('tprivate_featureprop');
		@fields = ($f_id,$cvterm_id,$value,$rank,$upl);
	}

	print $fh join("\t",@fields),"\n";
	
}

sub print_ufloc {
	my $self = shift;
	my ($nextfeature,$min,$max,$str,$lg,$rank,$pub) = @_;
	
	my $fh;
	if($pub) {
		$fh = $self->file_handles('tfeatureloc');		
	} else {
		$fh = $self->file_handles('tprivate_featureloc');
	}
	
	print $fh join("\t", ($nextfeature,$min,$max,$str,$lg,$rank)),"\n";
}

sub print_utree {
	my $self = shift;
	my ($tree,$name,$string) = @_;
	
	my $fh = $self->file_handles('ttree');		

	print $fh join("\t", ($tree,$name,$string)),"\n";
}

sub print_usc {
	my $self = shift;
	my ($snp_core_id,$pangenome_region,$position,$gap_offset) = @_;
	
	my $fh = $self->file_handles('tsnp_core');		

	print $fh join("\t", ($snp_core_id,$pangenome_region,$position,$gap_offset)),"\n";
}

sub print_usc2 {
	my $self = shift;
	my ($snp_core_id,$pangenome_region,$pos,$aln_coln,$freqA) = @_;
	
	my $fh = $self->file_handles('tsnp_core2');		

	print $fh join("\t", ($snp_core_id,$pangenome_region,$pos,$aln_coln,@$freqA)),"\n";
}



sub nextvalueHash {  
	my $self = shift;
	
	my %nextval = ();
	for my $t (@tables) {
		$nextval{$t} = $self->{'nextoid'}{$t};
	}
	
	return %nextval;
}

#################
# Accessors
#################

=head2 dbh

=over

=item Usage

  $obj->dbh()        #get existing value
  $obj->dbh($newval) #set new value

=item Function

=item Returns

value of dbh (a scalar)

=item Arguments

new value of dbh (to set)

=back

=cut

sub dbh {
    my $self = shift;

    my $dbh = shift if @_;
    return $self->{'dbh'} = $dbh if defined($dbh);
    return $self->{'dbh'};
}

=head2 tmp_dir

=over

=item Usage

  $obj->tmp_dir()        #get existing value
  $obj->tmp_dir($newval) #set new value

=item Function

=item Returns

file path to a tmp directory

=item Arguments

new value of tmp_dir (to set)

=back

=cut

sub tmp_dir {
    my $self = shift;

    my $tmp_dir = shift;
    return $self->{'tmp_dir'} = $tmp_dir if defined($tmp_dir);
    return $self->{'tmp_dir'};
}

=head2 config

=over

=item Usage

  $obj->config()        #get existing value
  $obj->config($newval) #set new value

=item Function

=item Returns

value of the config filepath (a scalar)

=item Arguments

new value of config filepath (to set)

=back

=cut

sub config {
    my $self = shift;

    my $c = shift if @_;
    return $self->{'configfp'} = $c if defined($c);
    return $self->{'configfp'};
}

=head2 noload

=over

=item Usage

  $obj->noload()        #get existing value
  $obj->noload($newval) #set new value

=item Function

=item Returns

value of noload (a scalar)

=item Arguments

new value of noload (to set)

=back

=cut

sub noload {
    my $self = shift;

    my $noload = shift;
    return $self->{'noload'} = $noload if defined($noload);
    return $self->{'noload'};
}

=head2 vacuum

=over

=item Usage

  $obj->vacuum()        #get existing value
  $obj->vacuum($newval) #set new value

=item Function

=item Returns

Boolean value of vacuum parameter (0/1)

=item Arguments

Boolean value of vacuum parameter (0/1)

=back

=cut

sub vacuum {
    my $self = shift;

    my $v = shift if @_;
    return $self->{'vacuum'} = $v if defined($v);
    return $self->{'vacuum'};
}


=head2 test

=over

=item Usage

  $obj->test()        #get existing value
  $obj->test($newval) #set new value

=item Function

=item Returns

Boolean value of test parameter (0/1)

=item Arguments

Boolean value of test parameter (0/1)

=back

=cut

sub test {
    my $self = shift;

    my $v = shift if @_;
    return $self->{'test'} = $v if defined($v);
    return $self->{'test'};
}


=head2 save_tmpfiles

=over

=item Usage

  $obj->save_tmpfiles()        #get existing value
  $obj->save_tmpfiles($newval) #set new value

=item Function

=item Returns

value of save_tmpfiles (a scalar)

=item Arguments

new value of save_tmpfiles (to set)

=back

=cut

sub save_tmpfiles {
    my $self = shift;
    my $save_tmpfiles = shift if @_;
    return $self->{'save_tmpfiles'} = $save_tmpfiles if defined($save_tmpfiles);
    return $self->{'save_tmpfiles'};
}


=head2 recreate_cache

=over

=item Usage

  $obj->recreate_cache()        #get existing value
  $obj->recreate_cache($newval) #set new value

=item Function

=item Returns

value of recreate_cache (a scalar)

=item Arguments

new value of recreate_cache (to set)

=back

=cut

sub recreate_cache {
    my $self = shift;
    my $recreate_cache = shift if @_;

    return $self->{'recreate_cache'} = $recreate_cache if defined($recreate_cache);
    return $self->{'recreate_cache'};
}

=head2 feature_types

=over

=item Usage

  $obj->feature_types('featuretypename')        #get existing value

=item Function

=item Returns

value of cvterm_id for featuretypename

=item Arguments

name of feature type

=back

=cut

sub feature_types {
    my $self = shift;
    my $type = shift;

    return $self->{'feature_types'}->{$type};
}

=head2 relationship_types

=over

=item Usage

  $obj->relationship_types('relationshiptypename')        #get existing value

=item Function

=item Returns

value of cvterm_id for relationshiptypename

=item Arguments

name of relationship type

=back

=cut

sub relationship_types {
    my $self = shift;
    my $type = shift;

    return $self->{'relationship_types'}->{$type};
}

=head2 featureprop_types

=over

=item Usage

  $obj->featureprop_types('featurepropname') #get existing value for featurepropname

=item Function

=item Returns

cvterm_id for a valid featureprop type.

=item Arguments

a featurprop type

=back

=cut

sub featureprop_types {
    my $self = shift;
    my $fp = shift;
    
    return $self->{featureprop_types}->{$fp};
}


=head2 publication_id

=over

=item Usage

  $obj->publication_id #get existing value for null publication type

=item Function

=item Returns

pub_id for a null publication needed in the feature_cvterm table

=back

=cut

sub publication_id {
    my $self = shift;
    
    return $self->{pub_id};
}

=head2 organism_id

=over

=item Usage

  $obj->organism_id #get existing value for default organism type

=item Function

=item Returns

Default organism_id needed in the feature table

=back

=cut

sub organism_id {
    my $self = shift;
    
    return $self->{organisms}->{'Escherichia coli'};
}

=head2 reverse_complement

=over

=item Usage

  $obj->reverse_complement($dna) #return rev comp of dna sequence

=item Function

=item Returns

  Reverse complement of DNA sequence

=item Arguments

  dna string consisting of IUPAC characters

=back

=cut

sub reverse_complement {
	my $self = shift;
	my $dna = shift;
	
	# reverse the DNA sequence
	my $revcomp = reverse($dna);
	
	# complement the reversed DNA sequence
	$revcomp =~ tr/ABCDGHMNRSTUVWXYabcdghmnrstuvwxy/TVGHCDKNYSAABWXRtvghcdknysaabwxr/;
	
	return $revcomp;
}

sub elapsed_time {
	my ($self, $mes) = @_;
	
	my $time = $self->{now};
	my $now = time();
	printf("$mes: %.2f\n", $now - $time);
	
	$self->{now} = $now;
}

=head2 add_snp_column

=over

=item Usage

  $obj->add_snp_column($nuc); 

=item Function

  For new snp, add char in each genome's SNP alignment string and in the default 'core' string

=item Returns

  The block and column number of the new SNP alignment column

=item Arguments

  The nucleotide char in the core pangenome

=back

=cut

sub add_snp_column {
	my $self = shift;
	my $nuc = shift;
	my $ref_id = shift;
		
	my $c = $self->{snp_alignment}{core_position}++;
	$self->{snp_alignment}{core_alignment} .= $nuc;
	
	return($c);
}

# =head2 add_snp_row

# =over

# =item Usage

#   $obj->add_snp_row($genome_id, $is_public); 

# =item Function

#   For new genome, add the default 'core' SNP alignment string in table

# =item Returns

#   Nothing

# =item Arguments

#   The genome featureID and boolean indicating if genome is in public or private
#   feature table.

# =back
# =cut

# sub add_snp_row {
# 	my $self = shift;
# 	my $genome_id = shift;
# 	my $is_public = shift;
	
# 	my $pre = $is_public ? 'public_' : 'private_';
# 	my $genome = $pre . $genome_id;
	
# 	if ($self->validate_snp_alignment($genome_id, $is_public) ) {
		
# 		# Record new genomes;
# 		push @{$self->{snp_alignment}{new_rows}}, $genome;
# 		$self->cache('snp_alignment', $genome, 1);
# 	}
# }

=cut

=head2 add_core_column

=over

=item Usage

  $obj->add_core_column($nuc); 

=item Function

  For new core pangenome region, add column in each genome's alignment string and in the default 'core' string

=item Returns

  The column number of the new core alignment column

=item Arguments

  None

=back

=cut

sub add_core_column {
	my $self = shift;
		
	my $c = $self->{core_alignment}->{core_position}++;
	$self->{core_alignment}->{added_columns}++;
	
	return($c);
}

=cut

=head2 add_acc_column

=over

=item Usage

  $obj->add_acc_column($nuc); 

=item Function

  For new accessory pangenome region, add column in each genome's alignment string and in the default 'core' string

=item Returns

  The column number of the new accessory alignment column

=item Arguments

  None

=back

=cut

sub add_acc_column {
	my $self = shift;
		
	my $c = $self->{acc_alignment}->{core_position}++;
	$self->{acc_alignment}->{added_columns}++;
	
	return($c);
}

# =head2 add_snp_row

# =over

# =item Usage

#   $obj->add_core_row($genome_id, $is_public); 

# =item Function

#   For new genome, add the default 'core' alignment string in table

# =item Returns

#   Nothing

# =item Arguments

#   The genome featureID and boolean indicating if genome is in public or private
#   feature table.

# =back
# =cut

# sub add_core_row {
# 	my $self = shift;
# 	my $genome_id = shift;
# 	my $is_public = shift;
	
# 	my $pre = $is_public ? 'public_' : 'private_';
# 	my $genome = $pre . $genome_id;
	
# 	if ($self->validate_core_alignment($genome_id, $is_public) ) {
		
# 		# Record new genomes;
# 		push @{$self->{core_alignment}{new_rows}}, $genome;
# 		$self->cache('core_alignment', $genome, 1);
# 	}
# }



=head2 alter_snp

=over

=item Usage

  $obj->alter_snp($genome_id, $is_public, $block, $pos, $nuc); 

=item Function

  Change the SNP alignment string at a single position for a genome

=item Returns

  Nothing

=item Arguments

  The genome featureID, boolean indicating if genome is in public or private
  feature table, the position in the alignment and the
  character to assign at that position

=back

=cut

sub alter_snp {
	my $self = shift;
	my $genome_id = shift;
	my $is_public = shift;
	my $ref_id = shift;
	my $col = shift;
	my $nuc = shift;
	
	# Validate nucleotide
	$nuc = uc($nuc);
	croak "Invalid nucleotide character '$nuc'." unless $nuc =~ m/^[A-Z\-]$/;
	
	my $pre = $is_public ? 'public_' : 'private_';
	my $genome = $pre . $genome_id;
	
	push @{$self->{snp_alignment}{buffer_stack}}, $genome, $ref_id, $col, $nuc;
	$self->{snp_alignment}{buffer_num}++;

	if($self->{snp_alignment}{buffer_num} == $self->{snp_alignment}{bulk_set_size}) {
		
		$self->{snp_alignment}{insert_tmp_variations}->execute(@{$self->{snp_alignment}{buffer_stack}});
		$self->dbh->commit || croak "Insertion of snp variations into tmp_snp_cache table failed: ".$self->dbh->errstr();
		$self->{snp_alignment}{buffer_num} = 0;
		$self->{snp_alignment}{buffer_stack} = [];
	}
}

=head2 has_core_region

=over

=item Usage

  $obj->has_core_region($genome_id, $is_public, $column); 

=item Function

  Change the core alignment string at a single position for a genome

=item Returns

  Nothing

=item Arguments

  The genome featureID, boolean indicating if genome is in public or private
  feature table, the alignment column number

=back

=cut

sub has_core_region {
	my $self = shift;
	my $genome_id = shift;
	my $is_public = shift;
	my $col = shift;
	
	# Validate alignment positions
	my $maxc = $self->{core_alignment}->{core_position};
	croak "Invalid core alignment position $col (max: $maxc)." unless $col <= $maxc;
	
	my $pre = $is_public ? 'public_' : 'private_';
	my $genome = $pre . $genome_id;
	
	push @{$self->{core_alignment}{buffer_stack}}, $genome, $col;
	$self->{core_alignment}{buffer_num}++;

	if($self->{core_alignment}{buffer_num} == $self->{core_alignment}{bulk_set_size}) {
		
		$self->{core_alignment}{insert_tmp_presence}->execute(@{$self->{core_alignment}{buffer_stack}});
		$self->dbh->commit || croak "Insertion of core presence/absence values into tmp_core_cache table failed: ".$self->dbh->errstr();
		$self->{core_alignment}{buffer_num} = 0;
		$self->{core_alignment}{buffer_stack} = [];
	}
}

=head2 has_acc_region

=over

=item Usage

  $obj->has_acc_region($genome_id, $is_public, $column); 

=item Function

  Change the accessory alignment string at a single position for a genome

=item Returns

  Nothing

=item Arguments

  The genome featureID, boolean indicating if genome is in public or private
  feature table, the alignment column number

=back

=cut

sub has_acc_region {
	my $self = shift;
	my $genome_id = shift;
	my $is_public = shift;
	my $col = shift;
	
	# Validate alignment positions
	my $maxc = $self->{acc_alignment}->{core_position};
	croak "Invalid core alignment position $col (max: $maxc)." unless $col <= $maxc;
	
	my $pre = $is_public ? 'public_' : 'private_';
	my $genome = $pre . $genome_id;
	
	push @{$self->{acc_alignment}{buffer_stack}}, $genome, $col;
	$self->{acc_alignment}{buffer_num}++;

	if($self->{acc_alignment}{buffer_num} == $self->{acc_alignment}{bulk_set_size}) {
		
		$self->{acc_alignment}{insert_tmp_presence}->execute(@{$self->{acc_alignment}{buffer_stack}});
		$self->dbh->commit || croak "Insertion of accessory presence/absence values into tmp_accessory_cache table failed: ".$self->dbh->errstr();
		$self->{acc_alignment}{buffer_num} = 0;
		$self->{acc_alignment}{buffer_stack} = [];
	}
}

=head2 print_snp_data

=over

=item Usage

  $obj->print_snp_data(); 

=item Function

  Snp counts change over progression of program. Print final values
  to file at end of run.

=item Returns

  Nothing

=item Arguments

  None

=back

=cut

sub print_snp_data {
	my $self = shift;
	
	my $dbh = $self->dbh;
	my $filler_pg = 1;
	my @new_snps;

	while( my ($snp_name, $snp_data) = each %{$self->cache('core_snp')} ) {
		
		if($snp_data->{new}) {
			# Print data for new core snp entry
			my $c = $snp_data->{col} || '\N';
			push @new_snps, [$snp_data->{snp_id}, $snp_data->{pangenome_region},
				$snp_data->{allele}, $snp_data->{pos}, $snp_data->{gapo}, $c, $snp_data->{freq}];
			#warn "NEW: ".join(',',@$new_snp_data, $c, @{$snp_data->{freq}});
			
		} else {
			# Print data for updated core snp
			# pangenome region ID cannot be NULL, and pangenome id, position, gap_offset must be unique
			# so just plugin some value to satisfy constraint in temp update table.
			# Note: this value is not used to join or update values in target table.
			my $c = $snp_data->{col} || '\N';
			my $filler_pos = $snp_data->{snp_id};
			$self->print_usc2($snp_data->{snp_id},$filler_pg,$filler_pos,$c,$snp_data->{freq});
			#warn "UPDATEDOLD: $snp_data->{snp_id}\t$c,".join(',',@{$snp_data->{freq}});
		}
		#print "\n";
	}
	
	foreach my $snp_row (sort {$a->[0] <=> $b->[0]} @new_snps) {
		$self->print_sc(@$snp_row);
	}

}

=head2 push_snp_alignment

=over

=item Usage

  $obj->push_snp_alignment($new_genomes); 

=item Function

  Add the current tmp_snp_cache to the snp_alignment table

=item Returns

  Nothing

=item Arguments

 array-ref containing list of new genomes

=back

=cut

sub push_snp_alignment {
	my $self = shift;
	my $new_genomes = shift;
	
	my $dbh = $self->dbh;
	
	# Insert the remaining rows in the buffer
	my $num_rows = scalar(@{$self->{snp_alignment}{buffer_stack}});
	if($num_rows) {
		$num_rows = $num_rows/4;
		my $insert_query = 'INSERT INTO tmp_snp_cache (name,snp_id,aln_column,nuc) VALUES (?,?,?,?)';
	    $insert_query .= ', (?,?,?,?)' x ($num_rows-1);
	    my $insert_sth = $dbh->prepare($insert_query);
	    $insert_sth->execute(@{$self->{snp_alignment}{buffer_stack}});
	}
	
	# Index by genome name
	my $sql = "CREATE INDEX tmp_snp_cache_idx1 ON public.tmp_snp_cache (name)";
    $dbh->do($sql);
    $sql = "CLUSTER tmp_snp_cache USING tmp_snp_cache_idx1";
    $dbh->do($sql);
    
    # Index by snp_id
    $sql = "CREATE INDEX tmp_snp_cache_idx2 ON public.tmp_snp_cache (snp_id)";
    $dbh->do($sql);
	
	# Print the new snp column assignments to a separate table for loading/updating.
	foreach my $snp_id (keys %{$self->{snp_alignment}{new_columns}}) {
		my $snp_row = $self->{snp_alignment}{new_columns}{$snp_id};
		my $col = $snp_row->[0];
		
		$self->print_scol($snp_id, $col);
	}
	# Print the modified snp columns
	foreach my $snp_id (keys %{$self->{snp_alignment}{modified_columns}}) {
		my $snp_row = $self->{snp_alignment}{modified_columns}{$snp_id};
		next if $self->{snp_alignment}{new_columns}{$snp_id}; 
		my $col = $snp_row->[0];
		
		$self->print_scol($snp_id, $col);
	}
	# Create tmp snp column table
	$sql = "DROP TABLE IF EXISTS tmp_snp_column";
	$dbh->do($sql);
	
	$sql = 
	"CREATE TABLE public.tmp_snp_column (
		snp_id int,
		aln_column int
	)";
    $dbh->do($sql);
    
	# Load table
	my $fh = $self->file_handles('snp_column');
	seek($fh,0,0);
	my $query = "COPY tmp_snp_column (snp_id,aln_column) FROM STDIN;";
	$dbh->do($query) or croak("Error when executing: $query: $!");
	while (<$fh>) {
		if ( ! ($dbh->pg_putline($_)) ) {
			# error, disconecting
			$dbh->pg_endcopy;
			$dbh->rollback;
			$dbh->disconnect;
			croak("error while copying data's of file ".$fh->filename.", line $.");
		} # putline returns 1 if succesful
	}
	$dbh->pg_endcopy or croak("calling endcopy for 'snp_column' failed: $!");
   
    # Index by snp_id
    $sql = "ALTER TABLE tmp_snp_column ADD CONSTRAINT tmp_snp_column_idx1 UNIQUE (snp_id)";
    $dbh->do($sql);
    
    $dbh->commit || croak "Insertion of snp variations into tmp_snp_cache and tmp_snp_column tables failed: ".$self->dbh->errstr();

	# New additions to core
	my $new_core_aln = $self->{snp_alignment}->{core_alignment};
	my $curr_column = $self->{snp_alignment}->{core_position};

	# Retrieve the full core snp alignment string (not just the new snps appended in this run)
	$sql = "SELECT alignment FROM snp_alignment WHERE name = 'core'";
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	my ($old_core_aln) = $sth->fetchrow_array();
	$old_core_aln = '' unless defined $old_core_aln;
	my $full_core_aln = $old_core_aln . $new_core_aln;
	croak "Alignment length does not match position counter $curr_column (length:".length($full_core_aln).")" unless length($full_core_aln) == $curr_column;
	
	# Genomes
	my $genomes = $self->_genomeList;
	
	# Core pangenome regions
	my $pgregions = $self->_coreRegionList;	
	
	# SNPs
	my ($db_snps, $new_snps) = $self->_snpsList;
	
	# Pangenome map: genome -> core regions
	my $pgmap = $self->_coreRegionMap($pgregions);
	
	my $tmpfh = $self->file_handles('snp_alignment');
	
	# Print core alignment additions to loading file
	print $tmpfh join("\t", ('core',$curr_column,$new_core_aln)),"\n";
	
	my $retrieve_snp_sth = $dbh->prepare('SELECT b.aln_column, a.nuc FROM tmp_snp_cache a, tmp_snp_column b  WHERE name = ? AND a.snp_id = b.snp_id ORDER BY b.aln_column DESC');
	my $retrieve_col_sth = $dbh->prepare('SELECT aln_column FROM snp_alignment WHERE name = ?');
	foreach my $g (@$new_genomes) {
		
		$genomes->{$g} = 0;

		$retrieve_col_sth->execute($g);
		my ($col) = $retrieve_col_sth->fetchrow_array();

		my $genome_string;
		my $offset;
		if($col) {
			$genome_string = $new_core_aln;
			$offset = length($old_core_aln);
		} else {
			$genome_string = $full_core_aln;
			$offset = 0;
		}
		
		# Make genome snp changes to core string
		$retrieve_snp_sth->execute($g);

		#print "$g, SNP OFFSET: $offset, alignment length: ".length($genome_string).", new length: ".length($new_core_aln)." current col: $curr_column\n";
		while (my $bunch_of_rows = $retrieve_snp_sth->fetchall_arrayref(undef, 20000)) {
			snp_edits($offset, $genome_string, $bunch_of_rows);
		}
		
		# Remove snps for regions not in genome
		my $missing_regions = &_absentCoreRegions($g, $pgregions, $pgmap->{$g});
		$genome_string = $self->mask_missing_in_new($genome_string, $missing_regions, $db_snps, $new_snps, $offset);

		# Print to DB file
		print $tmpfh join("\t", ($g,$curr_column,$genome_string)),"\n";
	}
	
	# Iterate through old genomes (no SNP-finding performed on these genomes)
	# Add core snps to their strings
	my $offset = length($old_core_aln);
	my $public_sth = $dbh->prepare('SELECT allele FROM snp_variation WHERE contig_collection_id = ? AND snp_id = ?');
	my $private_sth = $dbh->prepare('SELECT allele FROM private_snp_variation WHERE contig_collection_id = ? AND snp_id = ?');
	foreach my $g (keys %$genomes) {
		
		next unless $genomes->{$g};

		my ($access, $id) = ($g =~ m/(public|private)_(\d+)/);

		# Pull down any variations for the new columns
		my @modifications;
		my $sth = ($access eq 'public') ? $public_sth : $private_sth;
		foreach my $snp_id (keys %{$self->{snp_alignment}{new_columns}}) {
			
			my $snp_row = $self->{snp_alignment}{new_columns}{$snp_id};
			
			$sth->execute($id, $snp_id);
			while(my ($nuc) = $sth->fetchrow_array()) {
				push @modifications, [$snp_row->[0], $nuc]
			}
		}
		my $editted_aln = $new_core_aln;
		#print "$g, SNP OFFSET: $offset, alignment length: ".length($editted_aln).", new length: ".length($new_core_aln)." current col: $curr_column\n";
		snp_edits($offset, $editted_aln, \@modifications) if @modifications;
		
		# Change snps for regions not in genome to gaps
		my $missing_regions = &_absentCoreRegions($g, $pgregions, $pgmap->{$g});
		$editted_aln = $self->mask_missing_in_db($editted_aln, $missing_regions, $new_snps, $offset);
		
		print $tmpfh join("\t", ($g,$curr_column,$editted_aln)),"\n";
	}
	
	# Run upsert operation
	warn "Upserting data in snp_alignment table ...\n";
	$tmpfh->autoflush;
	seek($tmpfh,0,0);
	
	my $ttable = 'pipeline_snp_alignment';
	my $stable = 'tmp_snp_alignment';
	my $query0 = "DROP TABLE IF EXISTS $stable";
	my $query1 = "CREATE TABLE $stable (LIKE $ttable INCLUDING ALL)";
	$dbh->do($query0) or croak("Error when executing: $query0 ($!).\n");
	$dbh->do($query1) or croak("Error when executing: $query1 ($!).\n");
	
	my $query2 = "COPY $stable (name,aln_column,alignment) FROM STDIN;";
	$dbh->do($query2) or croak("Error when executing: $query2 ($!).\n");

	while (<$tmpfh>) {
		if ( ! ($dbh->pg_putline($_)) ) {
			# error, disconecting
			$dbh->pg_endcopy;
			$dbh->rollback;
			$dbh->disconnect;
			croak("error while copying data's of file ".$tmpfh->filename." line $.");
		} # putline returns 1 if succesful
	}

	$dbh->pg_endcopy or croak("calling endcopy for $stable failed: $!");
	
	# update the target table
	my $query3 = 
"WITH upsert AS
(UPDATE $ttable t SET alignment = overlay(t.alignment placing s.alignment from t.aln_column+1), 
 aln_column = s.aln_column 
 FROM $stable s WHERE t.name = s.name
 RETURNING t.name
)
INSERT INTO $ttable (name,aln_column,alignment)
SELECT name,aln_column,alignment
FROM $stable tmp
WHERE NOT EXISTS (SELECT 1 FROM upsert up WHERE up.name = tmp.name);";

	$dbh->do("$query3") or croak("Error when executing: $query3 ($!).\n");

	$dbh->commit || croak "Insertion of snp alignment failed: ".$self->dbh->errstr();
	
	# Check for duplicate SNP alignment strings
	# A red-flag for duplicate genomes in DB
	# NOT RELIABLE, distinct genomes can have identical SNP alignents
=cut
	unless($self->{threshold_override}) {
		my $query4 = 
"SELECT * FROM (
  SELECT name,
  ROW_NUMBER() OVER(PARTITION BY alignment ORDER BY name ASC) AS Row
  FROM $ttable
) dups
WHERE 
dups.Row > 1";

		my $sth5 = $dbh->prepare($query4);
		$sth5->execute();
		
		while(my ($name) = $sth5->fetchrow_array()) {
			croak('FATAL: Identical SNP strings found for genome: '.$name.'. Might indicate duplicate genomes in DB.');
		}
	}
=cut	

}

=head2 push_pg_alignment

=over

=item Usage

  $obj->push_pg_alignment($new_genomes); 

=item Function

  Add the current tmp_core_cache to the core_alignment table
  Ditto accessory

=item Returns

  Nothing

=item Arguments

 array-ref containing list of new genomes

=back

=cut

sub push_pg_alignment {
	my $self = shift;
	my $new_genomes = shift;
	
	my $dbh = $self->dbh;
	
	# Insert the remaining rows in the buffer
	foreach my $cache_tables (['core_alignment', 'tmp_core_pangenome_cache'], ['acc_alignment', 'tmp_acc_pangenome_cache']) {
		my $cache = $cache_tables->[0];
		my $table = $cache_tables->[1];

		my $num_rows = scalar(@{$self->{$cache}{buffer_stack}});
		if($num_rows) {
			$num_rows = $num_rows/2;
			my $insert_query = "INSERT INTO $table (genome,aln_column) VALUES (?,?)";
		    $insert_query .= ', (?,?)' x ($num_rows-1);
		    my $insert_sth = $dbh->prepare($insert_query);
		    $insert_sth->execute(@{$self->{$cache}{buffer_stack}});
		}
		my $sql = "CREATE INDEX $table\_idx1 ON public.$table (genome)";
	    $dbh->do($sql);
	}
	# Index needed for marker check
	my $sql = "CREATE INDEX tmp_core_pangenome_cache_idx2 ON public.tmp_core_pangenome_cache (genome,aln_column)";
	$dbh->do($sql);

	$dbh->commit || croak "Insertion of pangenome presence values failed: ".$self->dbh->errstr();
	
	# New additions to core string
	my $new_core_cols = $self->{core_alignment}->{added_columns};
	my $new_core_aln = '0' x $new_core_cols;
	my $curr_core_column = $self->{core_alignment}->{core_position};

	# New additions to acc string
	my $new_acc_cols = $self->{acc_alignment}->{added_columns};
	my $new_acc_aln = '0' x $new_acc_cols;
	my $curr_acc_column = $self->{acc_alignment}->{core_position};

	# Retrieve the full core alignment string (not just the new columns appended in this run)
	$sql = "SELECT core_alignment FROM pangenome_alignment WHERE name = 'core'";
	my $sth = $dbh->prepare($sql);
	$sth->execute;
	my ($old_core_aln) = $sth->fetchrow_array();
	$old_core_aln = '' unless defined $old_core_aln;
	my $full_core_aln = $old_core_aln . $new_core_aln;
	croak "Core alignment length does not match position counter $curr_core_column (length:".length($full_core_aln).")" unless length($full_core_aln) == $curr_core_column;

	$sql = "SELECT acc_alignment FROM pangenome_alignment WHERE name = 'core'";
	$sth = $dbh->prepare($sql);
	$sth->execute;
	my ($old_acc_aln) = $sth->fetchrow_array();
	$old_acc_aln = '' unless defined $old_acc_aln;
	my $full_acc_aln = $old_acc_aln . $new_acc_aln;
	croak "Accessory alignment length does not match position counter $curr_acc_column (length:".length($full_acc_aln).")" unless length($full_acc_aln) == $curr_acc_column;
	
	# Genomes
	my $genomes = $self->_genomeList;
	
	my $tmpfh = $self->file_handles('pg_alignment');
	
	# Print core alignment additions to loading file
	print $tmpfh join("\t", ('core',$curr_core_column,$new_core_aln,$curr_acc_column,$new_acc_aln)),"\n";
	
	# Iterate through new genomes
	my $retrieve_core_sth = $dbh->prepare("SELECT aln_column, '1' FROM tmp_core_pangenome_cache WHERE genome = ?");
	my $retrieve_acc_sth = $dbh->prepare("SELECT aln_column, '1' FROM tmp_acc_pangenome_cache WHERE genome = ?");
	my $retrieve_col_sth = $dbh->prepare("SELECT core_column, acc_column FROM pangenome_alignment WHERE name = ?");
	my %marker_hash = %{$self->{organism_pangenome_markers}{column}};
	my @marker_columns = keys %marker_hash;

	foreach my $g (@$new_genomes) {
		
		$genomes->{$g} = 0;
		
		# Insert presence indicators into core/acc strings for genome
		$retrieve_core_sth->execute($g);
		$retrieve_acc_sth->execute($g);
		$retrieve_col_sth->execute($g);

		# In incremental approach, some genomes that are 'newly' processed in this run
		# may have existing core strings
		my ($core_col, $acc_col) = $retrieve_col_sth->fetchrow_array();

		my $genome_core_string;
		my $core_offset;
		if($core_col) {
			# Previous alignment
			$genome_core_string = $new_core_aln;
			$core_offset = length($old_core_aln);
		} else {
			# No previous alignment
			$genome_core_string = $full_core_aln;
			$core_offset = 0;
		}
		 
		# Count core content for new genomes
		# Too little is red-flag for non-Ecoli species
		my $num_core_regions = 0;
		while (my $bunch_of_rows = $retrieve_core_sth->fetchall_arrayref(undef, 20000)) {
			$num_core_regions += scalar(@$bunch_of_rows);
			snp_edits($core_offset, $genome_core_string, $bunch_of_rows);
		}

		croak "FATAL: genome $g core pangenome content is below allowable threshold (has $num_core_regions regions, $CORE_REGION_CUTOFF needed). May indicate attempt to load non-E.coli species"
			if $num_core_regions < $CORE_REGION_CUTOFF && !$self->{threshold_override};

		# Check that genome has regions that identify it as an Ecoli species
		my $organism_marker_count = 0;
		foreach my $col (@marker_columns) {
			$organism_marker_count += substr($genome_core_string, $col, 1);
		}
		croak "FATAL: genome $g missing sufficient E.coli pangenome markers (has $organism_marker_count markers, $ORGANISM_MARKER_CUTOFF needed). May indicate attempt to load non-E.coli species"
			if $organism_marker_count < $ORGANISM_MARKER_CUTOFF && !$self->{threshold_override};

		my $genome_acc_string;
		my $acc_offset;
		if($acc_col) {
			# Previous alignment
			$genome_acc_string = $new_acc_aln;
			$acc_offset = length($old_acc_aln);
		} else {
			# No previous alignment
			$genome_acc_string = $full_acc_aln;
			$acc_offset = 0;
		}

		while (my $bunch_of_rows = $retrieve_acc_sth->fetchall_arrayref(undef, 20000)) {
			snp_edits($acc_offset, $genome_acc_string, $bunch_of_rows);
		}
		
		# Print to DB file
		print $tmpfh join("\t", ($g,$curr_core_column,$genome_core_string,$curr_acc_column,$genome_acc_string)),"\n";
	}
	
	# Iterate through old genomes that have no new changes
	# Add pangenome columns to their strings
	foreach my $g (keys %$genomes) {
		
		next unless $genomes->{$g};
		
		print $tmpfh join("\t", ($g,$curr_core_column,$new_core_aln,$curr_acc_column,$new_acc_aln)),"\n";
	}
	
	# Run upsert operation
	warn "Upserting data in pipeline_pangenome_alignment table ...\n";
	$tmpfh->autoflush;
	seek($tmpfh,0,0);
	
	my $ttable = 'pipeline_pangenome_alignment';
	my $stable = 'tmp_pangenome_alignment';
	my $query0 = "DROP TABLE IF EXISTS $stable";
	my $query1 = "CREATE TABLE $stable (LIKE $ttable INCLUDING ALL)";
	$dbh->do($query0) or croak("Error when executing: $query0 ($!).\n");
	$dbh->do($query1) or croak("Error when executing: $query1 ($!).\n");
	
	my $query2 = "COPY $stable (name,core_column,core_alignment,acc_column,acc_alignment) FROM STDIN;";
	$dbh->do($query2) or croak("Error when executing: $query2 ($!).\n");

	while (<$tmpfh>) {
		if ( ! ($dbh->pg_putline($_)) ) {
			# error, disconecting
			$dbh->pg_endcopy;
			$dbh->rollback;
			$dbh->disconnect;
			croak("error while copying data's of file ".$tmpfh->filename.", line $.");
		} # putline returns 1 if succesful
	}

	$dbh->pg_endcopy or croak("calling endcopy for $stable failed: $!");
	
	# update the target table
	my $query3 = 
"WITH upsert AS
(UPDATE $ttable t SET core_alignment = overlay(t.core_alignment placing s.core_alignment from t.core_column+1), 
 core_column = s.core_column,
 acc_alignment = overlay(t.acc_alignment placing s.acc_alignment from t.acc_column+1), 
 acc_column = s.acc_column
 FROM $stable s WHERE t.name = s.name
 RETURNING t.name
)
INSERT INTO $ttable (name,core_column,core_alignment,acc_column,acc_alignment)
SELECT name,core_column,core_alignment,acc_column,acc_alignment
FROM $stable tmp
WHERE NOT EXISTS (SELECT 1 FROM upsert up WHERE up.name = tmp.name);";

	$dbh->do("$query3") or croak("Error when executing: $query3 ($!).\n");

	$dbh->commit || croak "Insertion of pangenome alignment failed: ".$self->dbh->errstr();

}


=head2 binary_state_snp_matrix

=over

=item Usage

  $obj->binary_state_snp_matrix($curr_snp_alignment_table); 

=item Function

  Convert snp_alignment into a binary snp matrix 1/0 indicating presence/absence of allele
  This file is loaded into R/Shiny module for group comparisons.

=item Returns

  Array of filenames for: 
    1) new RData file

=item Arguments

  Name of DB cache table containing up-to-date snp alignment for all genomes

=back

=cut

sub binary_state_snp_matrix {
	my $self = shift;

	my $tmp_dir = $self->tmp_dir();

	# Generate list of SNPs and associated functions
	my $snp_columns = $self->_snpsColumns();
	my $snpo_file = $tmp_dir . "pipeline_snp_order.txt";

	# Print SNP order to file
	open(my $out, '>', $snpo_file) or croak "Error: unable to write to file $snpo_file ($!).\n";
	for my $col ( sort { $a <=> $b } keys %$snp_columns) {
		print $out join("\t", @{$snp_columns->{$col}}),"\n";
	}
	close $out;

	# Run binary conversion script
	my $rfile = "$tmp_dir/shinySnp.RData";
	my $pathroot = "$tmp_dir/snp";
	my @program = ($perl_interpreter, "$root_directory/Data/snp_alignment_to_binary.pl",
		"--pipeline",
		"--snp_order $snpo_file",
		"--rfile $rfile",
		"--path $pathroot",
		"--config ".$self->config()
	);
	
	my $cmd = join(' ',@program);
	
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		croak "Error: SNP binary conversion failed ($stderr).\n";
	}

	return ($rfile);
}

=head2 binary_state_pg_matrix

=over

=item Usage

  $obj->binary_state_pg_matrix($curr_pg_alignment_table); 

=item Function

  Convert snp_alignment into a binary snp matrix 1/0 indicating presence/absence of allele
  This file is loaded into R/Shiny module for group comparisons.

=item Returns

  Array of filenames for: 
    1) new RData file

=item Arguments

  Name of DB cache table containing up-to-date pg alignment for all genomes

=back

=cut

sub binary_state_pg_matrix {
	my $self = shift;
	my $pg_table = shift;

	my $tmp_dir = $self->tmp_dir();

	# Generate list of PGs and associated functions
	my $pg_columns = $self->_pgColumns();
	my $pgo_file = $tmp_dir . "pipeline_pg_order.txt";

	# Print PG order to file
	open(my $out, '>', $pgo_file) or croak "Error: unable to write to file $pgo_file ($!).\n";
	# Print core
	for my $col ( sort { $a <=> $b } keys %{$pg_columns->{core}}) {
		print $out join("\t", @{$pg_columns->{core}{$col}}),"\n";
	}
	# Print accessory
	for my $col ( sort { $a <=> $b } keys %{$pg_columns->{acc}}) {
		print $out join("\t", @{$pg_columns->{acc}{$col}}),"\n";
	}
	close $out;

	# Run binary conversion script
	my $rfile = "$tmp_dir/shinyPg.RData";
	my $pathroot = "$tmp_dir/pg";
	my @program = ($perl_interpreter, "$root_directory/Data/pg_alignment_to_binary.pl",
		"--pipeline",
		"--pg_order $pgo_file",
		"--rfile $rfile",
		"--path $pathroot",
		"--config ".$self->config()
	);
	
	my $cmd = join(' ',@program);
	
	my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);
	
	unless($success) {
		croak "Error: PG binary compression failed ($stderr).\n";
	}

	return ($rfile);
}

# List of all genomes
sub _genomeList {
	my $self = shift;
	
	my $dbh = $self->dbh;
	
	my %genomes;
	my $cc_id = $self->feature_types('contig_collection');
	my $sql1 = "SELECT feature_id, uniquename FROM feature WHERE type_id = ?";
	my $sql2 = "SELECT feature_id, uniquename FROM private_feature WHERE type_id = ?";
	
	# Public
	my $sth1 = $dbh->prepare($sql1);
	$sth1->execute($cc_id);
	
	while(my ($id) = $sth1->fetchrow_array()) {
		$genomes{"public_$id"} = [$id, 1];
	}
	
	# Private
	my $sth2 = $dbh->prepare($sql2);
	$sth2->execute($cc_id);
	
	while(my ($id) = $sth2->fetchrow_array()) {
		$genomes{"private_$id"} = [$id, 0];
	}
	
	return \%genomes;
}

# List of core pangenome regions
sub _coreRegionList {
	my $self = shift;
	
	my $dbh = $self->dbh;
	
	# Core pangenome regions in DB
	my %pgregions;
	my $pg_id = $self->feature_types('pangenome');
	my $core_type = $self->feature_types('core_genome');
	my $sql3 = "SELECT f.feature_id FROM feature f, feature_cvterm c".
		" WHERE f.feature_id = c.feature_id and f.type_id = $pg_id and c.cvterm_id = $core_type and c.is_not = FALSE";
	
	my $sth3 = $dbh->prepare($sql3);
	$sth3->execute();
	
	while(my ($id) = $sth3->fetchrow_array()) {
		$pgregions{$id}=1;
	}
	
	# New core pangenome regions in this run
	# Assumes that 'core' cache has been populated with new core pangenome regions added during this run
	my $core_cache = $self->cache('core');
	
	if(defined $core_cache) {
		foreach my $pg_id (keys %{$core_cache}) {
			$pgregions{$pg_id} = 1 if $core_cache->{$pg_id};
		}
	}
	
	return \%pgregions;
}

# List of altered snps
sub _snpsList {
	my $self = shift;
	
	# Build list of new and existing SNPs
	# DB Snps
	my %db_snps;
	
	while(my ($snp_id, $snp_row) = each %{$self->{snp_alignment}{modified_columns}}) {
		next if $self->{snp_alignment}{new_columns}{$snp_id};

		$db_snps{$snp_row->[1]} = [] unless defined $db_snps{$snp_row->[1]};
		push @{$db_snps{$snp_row->[1]}}, [$snp_id, $snp_row->[0]];
	}
	
	# New Snps
	my %new_snps;
	while(my ($snp_id, $snp_row) = each %{$self->{snp_alignment}{new_columns}}) {
		
		$new_snps{$snp_row->[1]} = [] unless defined $new_snps{$snp_row->[1]};
		push @{$new_snps{$snp_row->[1]}}, [$snp_id, $snp_row->[0]];
	}
	
	return (\%db_snps, \%new_snps);
}

# Map snp alignment columns -> snp_id mapping
sub _snpsColumns {
	my $self = shift;
	
	my %snp_columns;

	# Get list of snp alignment columns already in DB
	my $sql = "WITH fps AS ( " .
		"SELECT feature_id, value FROM featureprop WHERE type_id = ".$self->featureprop_types('panseq_function') .
		") ".
		"SELECT snp_core_id, pangenome_region_id, aln_column, p.value, allele ".
		"FROM snp_core c, feature f ".
		"LEFT JOIN fps p ON f.feature_id = p.feature_id ".
	    "WHERE c.pangenome_region_id = f.feature_id AND ".
	    "c.aln_column IS NOT NULL AND c.is_polymorphism = TRUE ORDER BY c.aln_column";
	my $sth = $self->dbh->prepare($sql);
	$sth->execute();

	while(my $snp_row = $sth->fetchrow_arrayref) {
		my ($snp_id, $pg_id, $col, $func, $allele ) = @$snp_row;

		if(defined $snp_columns{$col}) {
			croak "Error: snp $snp_id assigned to the same alignment column $col as ".$snp_columns{$col};

		} 
		else {
			# Record column
			$snp_columns{"$col"} = [$snp_id, $func // 'NA'];
		}
	}
	
	# Get list of snp alignment columns being added to DB
	my %new_snps;
	while(my ($snp_id, $snp_row) = each %{$self->{snp_alignment}{new_columns}}) {
		my $uniquename = $snp_row->[2];
		my $col = $snp_row->[0];
		my $snp_hash = $self->cache('core_snp', $uniquename);
		
		croak "Error: no core snp in cache matching uniquename $uniquename" unless $snp_hash;
		       
		# Store function
		my $pg_id = $snp_hash->{pangenome_region};
		my $func_array = $self->cache('function',$pg_id);
		my $func = $func_array ? $func_array->[1] : 'NA';
		
		if(defined $snp_columns{$col}) {
			croak "Error: snp $snp_id assigned to the same alignment column $col as ".$snp_columns{$col};

		} 
		else {
			# Record column
			$snp_columns{"$col"} = [$snp_id, $func];
		}
	}
	
	return (\%snp_columns);
}

# Map pg alignment columns -> pangenome region feature_id mapping
sub _pgColumns {
	my $self = shift;
	
	my %pg_columns;
	
	# Get list of pg core alignment columns already in DB
	my $sql = "WITH fps AS ( " .
		"SELECT feature_id, value FROM featureprop WHERE type_id = ".$self->featureprop_types('panseq_function') .
		") ".
		"SELECT c.pangenome_region_id, c.aln_column, p.value FROM core_region c ".
		"LEFT JOIN fps p ON c.pangenome_region_id = p.feature_id ".
		"ORDER by c.aln_column";
	my $sth = $self->dbh->prepare($sql);
	$sth->execute();

	while(my $core_row = $sth->fetchrow_arrayref) {
		my ($pg_id, $col, $func) = @$core_row;

		if(defined($pg_columns{core}{"$col"})) {
			croak "Error: core pangenome region assigned to the same alignment column $col";
		} 
                else {
			$pg_columns{core}{"$col"} = [ $pg_id, $func // 'NA' ];
		}
	}

	# Get list of pg accessory alignment columns already in DB
	$sql = "WITH fps AS ( " .
		"SELECT feature_id, value FROM featureprop WHERE type_id = ".$self->featureprop_types('panseq_function') .
		") ".
		"SELECT c.pangenome_region_id, c.aln_column, p.value FROM accessory_region c ".
		"LEFT JOIN fps p ON c.pangenome_region_id = p.feature_id ".
		"ORDER by c.aln_column";

	$sth = $self->dbh->prepare($sql);
	$sth->execute();

	while(my $acc_row = $sth->fetchrow_arrayref) {
		my ($pg_id, $col, $func) = @$acc_row;

		if(defined $pg_columns{acc}{"$col"}) {
			croak "Error: accessory pangenome region assigned to the same alignment column $col";
		} else {
			$pg_columns{acc}{"$col"} = [ $pg_id, $func // 'NA' ];
		}
	}
	
	# Get list of core pangenome region alignment columns being added to DB
	if($self->cache('core_region')) {
		while(my ($pg_id, $col) = each %{$self->cache('core_region')}) {
			my $func_array = $self->cache('function',$pg_id);
			my $func = $func_array ? $func_array->[1] : 'NA';

			$pg_columns{core}{"$col"} = [ $pg_id, $func];
		}
	}
	
	# Get list of accessory pangenome region alignment columns being added to DB
	if($self->cache('acc_region')) {
		while(my ($pg_id, $col) = each %{$self->cache('acc_region')}) {
			my $func_array = $self->cache('function',$pg_id);
			my $func = $func_array ? $func_array->[1] : 'NA';

			$pg_columns{acc}{"$col"} = [ $pg_id, $func ];
		}
	}
	
	
	return (\%pg_columns);
}


# Map genomes to array of core regions
sub _coreRegionMap {
	my $self = shift;
	my $pgregions = shift;
	
	my $dbh = $self->dbh;
	
	my %genome_regions;
	# Add new genome -> core region mappings
	foreach my $data_hash (values %{$self->{feature_cache}{pangenome}{new}}) {
		my $genome_id = $data_hash->{genome_id};
		my $query_id = $data_hash->{query_id};
		if($pgregions->{$query_id}) {
			# Core region, add it to list
			$genome_regions{$genome_id}{$query_id} = 1;
		}
	}
	
	# Add genome -> core region mappings already in DB
	my $sql = 'SELECT genome_id, pub, query_id FROM tmp_loci_cache WHERE query_id IN ('.join(',', keys %{$pgregions}).')';
	my $sth = $dbh->prepare($sql);
	$sth->execute();
		
	while(my $row = $sth->fetchrow_arrayref) {
		my ($genome, $pub, $query_id) = @$row;
		my $genome_id = $pub ? "public_$genome" : "private_$genome";
		$genome_regions{$genome_id}{$query_id} = 1;
	}
	
	return \%genome_regions;
}

=head2 mask_missing_in_db

=over

=item Usage

  $obj->mask_missing_in_db(); 

=item Function

  In snp alignment, overwrite sections of alignment with '-' coresponding to pangenome regions not found in genome
  
  This function handles existing genomes already in DB

=item Returns

  Updated alignment string

=item Arguments

  1. new alignment segment string being appended to existing alignments
  2. hashref containing core pangenome regions absent in genome
  3. hashref containing all new SNPs added in this run. 
     Each hash value contains 2 element array: [snp_id, snp_alignment_column]
  4. Alignment column assigned to start of new alignment segment

=back

=cut

sub mask_missing_in_db {
	my $self = shift;
	my $alignment = shift;
	my $missing_regions = shift;
	my $new_snps = shift;
	my $position_offset = shift;
	
	my $dbh = $self->dbh;
	
	# Genome already in DB, 
	# Alignment is new portion concatenated onto end of existing alignment
	
	# Find any new snps in the missing regions
	# Replace those snp alignment positions with '-'
	my @edits;
	foreach my $pg_id (%$new_snps) {
		if($missing_regions->{$pg_id}) {
			foreach my $snp (@{$new_snps->{$pg_id}}) {
				push @edits, [$snp->[1], '-'];
			}
		}
	}
		
	snp_edits($position_offset, $alignment, \@edits) if @edits;
	
	return $alignment;
}

=head2 mask_missing_in_new

=over

=item Usage

  $obj->mask_missing_in_new(); 

=item Function

  In snp alignment, overwrite sections of alignment with '-' coresponding to pangenome regions not found in genome
  
  This function handles new genomes inserted in this run

=item Returns

  Updated alignment string

=item Arguments

  1. Full alignment string for new genomes added in this run
  2. hashref containing core pangenome regions absent in genome
  3. hashref containing all SNPs in DB 
     Each hash value contains 2 element array: [snp_id, snp_alignment_column]
  4. hashref containing all new SNPs added in this run. 
     Each hash value contains 2 element array: [snp_id, snp_alignment_column]

=back

=cut

sub mask_missing_in_new {
	my $self = shift;
	my $alignment = shift;
	my $missing_regions = shift;
	my $db_snps = shift;
	my $new_snps = shift;
	my $position_offset = shift;
	
	
	# Find any snps in the missing regions
	# Replace those snp alignment positions with '-'
	my @edits;
	foreach my $pg_id (%$new_snps) {
		if($missing_regions->{$pg_id}) {
			foreach my $snp (@{$new_snps->{$pg_id}}) {
				my $pos = $snp->[1];
				push @edits, [$pos, '-'];
			}
		}
	}
	
	foreach my $pg_id (%$db_snps) {
		if($missing_regions->{$pg_id}) {
			foreach my $snp (@{$new_snps->{$pg_id}}) {
				my $pos = $snp->[1];
				push @edits, [$pos, '-'];
			}
		}
	}
	
	snp_edits($position_offset, $alignment, \@edits) if @edits;
		
	return $alignment;
}

# Compute set of core regions not found in genome
sub _absentCoreRegions {
	my $genome = shift;
	my $core_list = shift;
	my $genome_regions = shift;
	
	my %missing_regions;
	unless(defined $genome_regions) {
		#warn "WARNING: genome $genome has no associated pangenome regions. All snps will be marked as missing (e.g. '-').\n";
		return \%missing_regions; 
	}
		
	# Build 'missing' list - pangenome regions not present in genome
	foreach my $region (keys %$core_list) {
		$missing_regions{$region} = 1 unless $genome_regions->{$region};
	}
	
	return \%missing_regions;
}


=head2 push_cache

=over

=item Usage

  $obj->push_cache(); 

=item Function

  Add the current tmp_snp_cache to the snp_alignment table

=item Returns

  Nothing

=item Arguments

  None

=back

=cut

sub push_cache {
	my $self = shift;
	my $cache_type = shift;
	
	my $dbh = $self->dbh;
	my $fh = $self->{feature_cache}{$cache_type}{fh};
	my $file = $fh->filename;
	$fh->autoflush;
	
	if (-s $file <= 0) {
		warn "Skipping cache table since the load file is empty...\n";
		return;
	}
		
	warn "Loading data into cache table ...\n";
	seek($fh,0,0);

	my $table = $self->{feature_cache}{$cache_type}{table};
	my $fields = "(feature_id,uniquename,genome_id,query_id,pub)";
	my $query = "COPY $table $fields FROM STDIN;";

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


=head2 snp_audit

Scan the reference pangenome sequence alignment for regions of ambiguity (consequetive gaps where at least one gap is new).
Can't tell which gap is new and which is old.

=cut

sub snp_audit {
	my $self = shift;
	my $refid = shift;
	my $refseq = shift;
	
	# Search sequence for extended indels
	my @regions;
	my $l = length($refseq)-1;
	my $pos = 0;
	my $gap = 0;
		
	for my $i (0 .. $l) {
        my $c = substr($refseq, $i, 1);
        
        # Advance position counters
        if($c eq '-') {
        	$gap++;
        } 
        else {
        	if($gap > 1) {
        		# extended indel
        		my @old_snps;
        		
        		# find if any columns are new
        		my $n = 0;
        		for(my $j=1; $j <= $gap; $j++) {
        			my $snp_hash = $self->retrieve_core_snp($refid, $pos, $j);
        			
					unless($snp_hash) {
						# new insert
						$n++;
					} else {
						push @old_snps, $snp_hash;
					}
        		}
        		
        		if($n && $n != $gap) {
        			# Have some new columns mixed with some old, region of ambiguity
        			my %indel_hash;
        			$indel_hash{p} = $pos;
					$indel_hash{g} = $gap;
					$indel_hash{insert_ids} = \@old_snps;
					$indel_hash{aln_start} = $i-$gap;
					$indel_hash{n} = $n;
					push @regions, \%indel_hash;
        		}
        		
        	}
        	$pos++;
        	$gap=0 if $gap;
        }
	}
	
	return \@regions;
}


=head2 handle_ambiguous_blocks

Handle regions of ambiguity (new gap inserted into existing gap), identifying
old and new alignment columns. Update positioning as needed.

=cut

sub handle_ambiguous_blocks {
	my $self = shift;
	my $regions = shift;
	my $ref_id = shift;
	my $refseq = shift;
	my $loci_hash = shift;
	
	my $v = 0;
	
	# Find new snps, update old snps in reach region of ambiguity
	foreach my $region (@$regions) {
	
		my $pos = $region->{p};
		my $gap = $region->{g};
		my $aln = $region->{aln_start};
		my $n   = $region->{n};
		my @current_insert_ids = @{$region->{insert_ids}};
		
		# Compare each insert position with known column characters to distinguish old and new
        
        # Obtain identifying characters for the first old insert column in alignment
        my $insert_column = $self->snp_variations_in_column($current_insert_ids[0]->{snp_id});
		
		if($v) {
			print "REF FRAGMENT: $ref_id\n$refseq\n";
			print "REGION: p: $pos, g: $gap, a: $aln, n: $n\n";
			print "CURRENT SNPS IN REGION: ",Dumper(\@current_insert_ids),"\n";
			print "ALIGNMENT COLUMNS IN REGION: ",Dumper($insert_column),"\n";
			print "SEQUENCES FOR OTHER GENOMES:\n",Dumper($loci_hash),"\n";
		}
	
		for(my $i=1; $i <= $gap; $i++) {
			
			# Compare alignment chars to chars in DB for a single alignment column
			# genome_label: private_genome_id|loci_id
			my $col_match = 1;
			foreach my $genome_label (keys %$insert_column) {
				my $c1 = $insert_column->{$genome_label};
				my $c2 = substr($loci_hash->{$genome_label}, $aln+$i-1,1);
				print "Genome $genome_label -- SNP char: $c1, alignment char: $c2 for column: $i, $aln, ",$aln+$i-1,"\n" if $v;
				
				if($c1 ne $c2) {
					croak "Error: Unable to position new and old insertion columns in SNP alignment (encountered non-gap character in genome row that is currently in DB)." unless $c2 eq '-';
					
					# Found new snp column
					$self->add_core_snp($ref_id, $pos, $i, $c2, $c1);
					
					$col_match = 0;
					$n--;
					last;
				}
			}
			
        	if($col_match) {
        		# This gap position matches the current insert column
        		
        		# Update the position of the insert column
        		croak "Error: The snps in the DB and the current alignment are out of sync." unless @current_insert_ids;
        		#my ($snp_core_id, $column) 
        		my $snp_hash = $current_insert_ids[0];
        		$self->print_usc($snp_hash->{snp_id},$ref_id,$pos,$i);
				
				$snp_hash->{pos} = $pos;
				$snp_hash->{gapo} = $i;

				$self->cache('core_snp',"$ref_id.$pos.$i",$snp_hash);
				
        		shift @current_insert_ids;
        		$insert_column = $self->snp_variations_in_column($current_insert_ids[0]->{snp_id}) if @current_insert_ids;

        		###
        		## IF @current_insert_ids empty, add rest as new snps
        		###
        		
        		print "MATCHED ".$snp_hash->{snp_id}." to $pos, $i in ALIGNMENT.\n" if $v;
        		
        	} else {
        		print "NEW GAP COLUMN IN ALIGNMENT at $pos, $i.\n" if $v;
        	}
        	
        }
        
        # Reached the end of the region
        # All new and old insert columns should be accounted for
        croak "Error: an insert column $current_insert_ids[0] in database was not located in the region of ambiguity in the alignment." if(@current_insert_ids);
        croak "Error: A new insert column was not located in the region of ambiguity in the alignment." if $n;
		
	}
	
}

=head2 snp_variations_in_column

Handle regions of ambiguity (new gap inserted into existing gap), identifying
old and new alignment columns. Update positioning as needed.

=cut

sub snp_variations_in_column {
	my $self = shift;
	my $snp_id = shift;
	
	my %variations;
	
	$self->{'queries'}{'retrieve_public_snp_column'}->execute($snp_id);
	
	while( my ($cc, $l, $a) = $self->{'queries'}{'retrieve_public_snp_column'}->fetchrow_array ) {
		my $lab = "public_$cc|$l";
		$variations{$lab} = $a;
	}
	
	$self->{'queries'}{'retrieve_private_snp_column'}->execute($snp_id);
	
	while( my ($cc, $l, $a) = $self->{'queries'}{'retrieve_private_snp_column'}->fetchrow_array ) {
		my $lab = "private_$cc|$l";
		$variations{$lab} = $a;
	}
	
	return(\%variations);
}

=head2 print_alignment_lengths

=cut

sub print_alignment_lengths {
	my $self = shift;
	
	my $sql = q/select length(alignment),block,name from tmp_snp_cache order by block,name/;
	
	$self->{'queries'}{'print_alignment_lengths'} = $self->dbh->prepare($sql) unless $self->{'queries'}{'print_alignment_lengths'};
	
	$self->{'queries'}{'print_alignment_lengths'}->execute();
	
	print "LENGTHS:\n---------\n";
	while (my ($len,$b,$n) = $self->{'queries'}{'print_alignment_lengths'}->fetchrow_array) {
		print "$n - $b: $len\n";
	}
	print "\n";
}

=head2 record_typing_sequences

Checks if query gene is needed to generate a in silico
subtype classification. If yes, the sequence_group hash
is cached. The hash, used elsewhere, includes key/values:

  genome => contig_collection feature ID
  public => T/F indicating if private/public feature
  allele => the allele feature ID
  seq    => the allele sequence
  is_new => T/F indicating if new sequence

=cut

sub record_typing_sequences {
	my $self = shift;
	my $query_id = shift;
	my $sequence_group = shift;
	
	return 0 unless defined $self->{feature_cache}{vfamr}{typing_watchlist}{$query_id};
	
	my $genome_id = $sequence_group->{genome};
	my $public = $sequence_group->{public};
	my $genome = $public ? 'public_' : 'private_';
	$genome .= $genome_id;
	
	$self->{feature_cache}{vfamr}{typing_watchlist}{$query_id}{$genome} = [] unless defined
		$self->{feature_cache}{vfamr}{typing_watchlist}{$query_id}{$genome};
	
	push @{$self->{feature_cache}{vfamr}{typing_watchlist}{$query_id}{$genome}}, $sequence_group;
	
	print "Recording $genome set for $query_id\n" if $DEBUG;
}

=head2 is_typing_sequence

Checks if query gene is needed to generate a in silico
subtype classification.

=cut

sub is_typing_sequence {
	my $self = shift;
	my $query_id = shift;
	
	return defined $self->{feature_cache}{vfamr}{typing_watchlist}{$query_id};
}

=head2 typing

Perform typing and load data and results into DB

=cut

sub typing {
	my $self = shift;
	my $work_dir = shift;

	
	# Prepare aligned concatenated sequences for each typing segment
	my $typing_sets = $self->construct_typing_sequences();
	warn "Construction complete\n";
	
	# Typing and Tree objects
	my $typer = Phylogeny::Typer->new(tmp_dir => $work_dir);
	my $tree_builder = Phylogeny::TreeBuilder->new(fasttree_exe => $self->{fasttree_exe});
	my $tree_io = Phylogeny::Tree->new(dbix_schema => 1);

	# Prepare sql queries
	my $rtype1 = $self->relationship_types('variant_of');
	my $rtype2 = $self->relationship_types('part_of');
	my $ftype = $self->feature_types('allele_fusion');
	my $sql = 
	qq/SELECT f.feature_id, f.residues, r2.object_id
	FROM feature f, feature_relationship r1, feature_relationship r2
	WHERE f.type_id = $ftype AND r1.type_id = $rtype1 AND r2.type_id = $rtype2 AND
	f.feature_id = r1.subject_id AND f.feature_id = r2.subject_id AND r1.object_id = ?
	/;

	my $sql2 = 
	qq/SELECT f.feature_id, f.residues, r2.object_id
	FROM private_feature f, pripub_feature_relationship r1, private_feature_relationship r2
	WHERE f.type_id = $ftype AND r1.type_id = $rtype1 AND r2.type_id = $rtype2 AND
	f.feature_id = r1.subject_id AND f.feature_id = r2.subject_id AND r1.object_id = ?
	/;

	my $pub_sth = $self->dbh->prepare($sql);
	my $pri_sth = $self->dbh->prepare($sql2);
	
	# Run insilico typing on each typing segment
	foreach my $typing_ref_seq (keys %$typing_sets) {
		
		warn "Number of typable subunits for $typing_ref_seq: ". scalar(@{$typing_sets->{$typing_ref_seq}}),"\n";

		next unless @{$typing_sets->{$typing_ref_seq}};

		# Hash to record subtypes/na for each genome
		my $subtype_groups;
		
		my %waiting_subtype;
		my %fasta;
		#my @sequence_group;
		foreach my $typing_hashref (@{$typing_sets->{$typing_ref_seq}}) {
			# Prepare fasta inputs
			# Only include allele_fusions not currently in the DB
			
			my $is_new = 0;
			
			my $genome_id = $typing_hashref->{genome};
			my $public = $typing_hashref->{public};
			my $uniquename = $typing_hashref->{uniquename};
			
			# Check if typing_seq is in cache
			# Check if this allele is already in DB
			my ($result, $allele_id) = $self->validate_feature(query => $typing_ref_seq, genome => $genome_id, uniquename => $uniquename,
				public => $public, feature_type => 'vfamr');
	
			if($result eq 'new_conflict') {
				warn "Attempt to add allele_fusion feature multiple times. Dropping duplicate of allele_fusion $uniquename.";
				next;
			}
			if($result eq 'db_conflict') {
				warn "Attempt to update existing allele_fusion feature multiple times. Skipping duplicate allele_fusion $uniquename.";
				next;
			}
			if($result eq 'db' || defined($allele_id)) {
				warn "Attempt to load allele_fusion feature already in database. Skipping duplicate allele_fusion $uniquename.";
				next;
			}
	
			unless($allele_id) {
				# A typing feature matching this one has not been loaded before
				# Add to list of type-ready sequences
				my $header = $typing_hashref->{header};
				$waiting_subtype{$header} = $typing_hashref;
				$fasta{$header} = $typing_hashref->{seq};
				$is_new = 1;
			}
			
			$typing_hashref->{allele} = $allele_id;
			$typing_hashref->{is_new} = $is_new;
			
			#push @sequence_group, $typing_hashref;
			
		}
		
		# Run typing
		my $typing_unit_name = $self->{feature_cache}{vfamr}{typing_names}{$typing_ref_seq};
		my $typing_results_file = "$work_dir/$typing_unit_name\_subtypes.txt";
		my $typing_tree_file = "$work_dir/$typing_unit_name\_subtypes.phy";
		my $subtype_prop = $self->{feature_cache}{vfamr}{typing_featureprops}{$typing_unit_name};
		
		$typer->subtype($typing_unit_name, \%fasta, $typing_tree_file, $typing_results_file);
		
		# Load subtype assignments
		open(my $in, "<", $typing_results_file) or croak "Error: unable to read file $typing_results_file ($!).\n";
		
		while(my $row = <$in>) {
			chomp $row;
			my ($header, $assignment) = split("\t", $row);
			
			$self->handle_typing_sequence($subtype_prop, $typing_ref_seq, $assignment, $waiting_subtype{$header});

			# Save subtype group assignment
			$self->record_subtype_group($subtype_groups, $subtype_prop, $assignment, 
				$waiting_subtype{$header}) if $self->{assign_groups};
		}
		
		close $in;
		
		# Build tree for concatentated stx subunits

		# This is not the complete sequence group. It does not contain Stx allele_fusions from the DB.
		# Since this is only being used in handle_phylogeny method, that is ok as it only makes tree->gene
		# linkages for new genomes.
		my @sequence_group = values %waiting_subtype;

		# Write alignment file
		my $tmp_file = $work_dir . '/genodo_allele_aln.txt';
		open(my $out, ">", $tmp_file) or croak "Error: unable to write to file $tmp_file ($!).\n";

		# Write new stx constructs
		foreach my $allele_hash (@sequence_group) {
			my $header = $allele_hash->{public} ? 'public_':'private_';

			$header .= $allele_hash->{genome} . '|' . $allele_hash->{allele};
			print $out join("\n",">".$header,$allele_hash->{seq}),"\n";
		}

		# Retrieve and write stx constructs already in DB
		$pub_sth->execute($typing_ref_seq);
		while(my ($allele_id, $seq, $genome_id) = $pub_sth->fetchrow_array) {
			my $header .= "public_$genome_id|$allele_id";
			print $out join("\n",">".$header,$seq),"\n";
		}

		$pri_sth->execute($typing_ref_seq);
		while(my ($allele_id, $seq, $genome_id) = $pri_sth->fetchrow_array) {
			my $header .= "private_$genome_id|$allele_id";
			print $out join("\n",">".$header,$seq),"\n";
		}
		close $out;

		
		# clear output file for safety
		my $tree_file = $work_dir . '/genodo_allele_tree.txt';
		open($out, ">", $tree_file) or croak "Error: unable to write to file $tree_file ($!).\n";
		close $out;
		
		# build newick tree
		$tree_builder->build_tree($tmp_file, $tree_file) or croak;
		
		# slurp tree and convert to perl format
		my $tree = $tree_io->newickToPerlString($tree_file);
		
		# store tree in tables
		$self->handle_phylogeny($tree, $typing_ref_seq, \@sequence_group);

		# Print group assignments for all genomes
		if($self->{assign_groups}) {
		
			# Default, assign genome to unassigned group
			my $default_value = "$subtype_prop\_na";
			my $default_group = $self->{groups}{subtype_group_assignments}{$subtype_prop}{$default_value};
			croak "Error: no default 'unassigned' group for data type $subtype_prop." unless $default_group;
			my $default_fp = undef;

			foreach my $key (keys %{$self->{cache}{snp_genome}}){
				my $ghash = $self->{cache}{snp_genome}{$key};

				my $feature_id = $ghash->{feature_id};
				my $is_public = $ghash->{public};

				 my $table = $is_public ? 'feature_group' : 'private_feature_group';

				if(defined $subtype_groups->{$is_public}{$feature_id}{$subtype_prop}) {
					# Subtype group assigned

					foreach my $grp_arrayref (@{$subtype_groups->{$is_public}{$feature_id}{$subtype_prop}}) {
						my ($g, $fp) = @{$grp_arrayref};
						$self->print_fgroup($self->nextoid($table),$feature_id,$g,$fp,$is_public);
						$self->nextoid($table,'++');
					}

				} else {
					# No group assigned, use default
					$self->print_fgroup($self->nextoid($table),$feature_id,$default_group,$default_fp,$is_public);
					$self->nextoid($table,'++');

				}
			}
		}
		
	}
}

=head2 construct_typing_sequences

Produces a typing sequence by concatenating the individual aligned 
allele sequences that make up a typing sequence

=cut

sub construct_typing_sequences {
	my $self = shift;
	
	my %typing_sets;
	
	foreach my $typing_ref_gene (keys %{$self->{feature_cache}{vfamr}{typing_construct}}) {
		warn "Construction step for SUBUNIT: $typing_ref_gene\n";
		
		$typing_sets{$typing_ref_gene} = [];
		my @ordered_keys = sort keys %{$self->{feature_cache}{vfamr}{typing_construct}{$typing_ref_gene}};
		my @ordered_seqs;
		
		# Record the order of the query genes in this typing sequence
		foreach my $i (@ordered_keys) {
			my $query_id = $self->{feature_cache}{vfamr}{typing_construct}{$typing_ref_gene}{$i};
			push @ordered_seqs, $query_id;
		}
		
		warn "Alleles in subunit: ".join(', ',@ordered_seqs),"\n";
		
		# Iterate through each genome, concatenting the sequences
		# Skip genomes that do not have all needed sequences
		my $query_gene1 = $ordered_seqs[0];
		my @genome_list = keys %{$self->{feature_cache}{vfamr}{typing_watchlist}{$query_gene1}};
		warn "Number of potential genomes: ".scalar(@genome_list)."\n";
		
		foreach my $genome (@genome_list) {
			
			# Typing sequence properties
			my @seqs = ();
			my @headers = ();
			my @alleles = ();
			my $public;
			my $genome_id;
			my $upload_id;
			my $missing = 0;
			
			# Concatenate all alleles for each query gene in typing sequence
			foreach my $query_gene (@ordered_seqs) {
				my $alleles_list = $self->{feature_cache}{vfamr}{typing_watchlist}{$query_gene}{$genome};

				# Track all alleles for this query gene
				my @next_seqs;
				my @next_headers;
				my @next_alleles;
				
				unless(defined $alleles_list) {
					# One of the needed alleles is missing in the genome, skip genome
					$missing = 1;
					last;
					
				} else {
					
					# Iterate through each allele copy for this query gene
					foreach my $allele_data (@$alleles_list) {
						
						if(@seqs) {
							# Concatenate this set of alleles with all earlier alleles in construct
							my $allele_id = $allele_data->{allele};
							
							foreach my $s (@seqs) {
								push @next_seqs, $s.$allele_data->{seq};
							}
							foreach my $a (@alleles) {
								push @next_alleles, [@$a, $allele_id];
							}
							foreach my $h (@headers) {
								my $thish = "|$query_gene\_$allele_id";
								push @next_headers, $h.$thish;
							}
							
						} else {
							# Start of typing sequence, record all alleles in first position
							my $allele_id = $allele_data->{allele};
							push @next_seqs, $allele_data->{seq};
							push @next_alleles, [$allele_id];
							push @next_headers, "$query_gene\_$allele_id";
							$public = $allele_data->{public};
							$genome_id = $allele_data->{genome};
							$upload_id = $allele_data->{upload_id};
						}
						
					
					}
				}

				@seqs = @next_seqs;
				@headers = @next_headers;
				@alleles = @next_alleles;
						
			}
					
			# Finalize typing sequence data
			# Each array row represent a single typing sequence in a genome
			if(!$missing) {
				while (@seqs) {
					my $seq = shift @seqs;
					my $h = shift @headers;
					my $allele_list = shift @alleles;
						
					my $uniquename = "typer:$h";
					my $header = "$genome|$h";
					
					my $typing_hash = {
						genome => $genome_id,
						uniquename => $uniquename,
						public => $public,
						alleles => $allele_list,
						header => $header,
						seq => $seq,
						upload_id => $upload_id
					};
					
					push @{$typing_sets{$typing_ref_gene}}, $typing_hash;
				}
			}
		}
	}
	
	return(\%typing_sets);

}

sub handle_typing_sequence {
	my $self = shift;
	my ($subtype_name, $typing_ref_id, $subtype_asmt, $typing_dataset) = @_;
	
	my $contig_collection_id = $typing_dataset->{genome};
	my $uniquename = $typing_dataset->{uniquename};
	my $is_public = $typing_dataset->{public}; 
	my $alleles_list = $typing_dataset->{alleles};
	my $upload_id = $typing_dataset->{upload_id};
	croak "Missing upload_id for stx feature $subtype_name in private genome $contig_collection_id\n" unless $is_public || $upload_id;

	
	# Create allele_fusion feature
		
	# ID
	my $curr_feature_id = $self->nextfeature($is_public);

	# Use default organism
	my $organism = $self->organism_id();
	
	# external accessions
	my $dbxref = '\N';
	
	# name
	my $name = "$subtype_name subtype for genome $contig_collection_id";
	
	# Feature relationships
	
	# Link to contig_collection
    $self->add_relationship($curr_feature_id,$contig_collection_id,'part_of',$is_public);
	
	# Link to typing reference gene
    $self->add_relationship($curr_feature_id,$typing_ref_id,'variant_of',$is_public, 1);
	
	# Link to alleles, which have ranks
	my $rank = 0;
    my $table1 = $is_public ? 'feature_relationship' : 'private_feature_relationship';
	my $rtype = $self->relationship_types('fusion_of');
	foreach my $allele_id (@$alleles_list) {
    	$self->print_frel($self->nextoid($table1),$curr_feature_id,$allele_id,$rtype,$rank,$is_public);
		$self->nextoid($table1,'++');
		$rank++
	}
	
	# Feature property
	# save subtype classification
 	my $property_cvterm_id = $self->featureprop_types($subtype_name);
	unless($property_cvterm_id) {
		croak "Unrecognized feature property type $subtype_name.";
	}
 	
 	$rank=0;
    my $table = $is_public ? 'featureprop' : 'private_featureprop';
	
	my $fp_id = $self->nextoid($table);                       	
	$self->print_fprop($fp_id,$curr_feature_id,$property_cvterm_id,$subtype_asmt,$rank,$is_public,$upload_id);
    $self->nextoid($table,'++');
	
	# Print feature
	my $seq = $typing_dataset->{seq};
	my $seqlen = length($seq);
	my $type = $self->feature_types('allele_fusion');
	$self->print_f($curr_feature_id, $organism, $name, $uniquename, $type, $seqlen, $dbxref, $seq, $is_public, $upload_id);  
	$self->nextfeature($is_public, '++');

	# Save feature ID
	$typing_dataset->{allele} = $curr_feature_id;

	# Save featureprop ID
	$typing_dataset->{featureprop} = $curr_feature_id;

		
}

=head2 record_subtype_group

Identify and save group ID corresponding
to subtype assignment.

=cut

sub record_subtype_group {
	my $self = shift;
	my $subtype_groups = shift; # hash of genome group assignments
	my $subtype_prop = shift; # Data type (stx1_subtype|stx2_subtype)
	my $assignment = shift; # Subtype assignment string
	my $typing_dataset = shift; # Genome data hash-ref

	my $contig_collection_id = $typing_dataset->{genome};
	my $is_public = $typing_dataset->{public};
	my $fp_id = $typing_dataset->{featureprop};

	my $group_id = $self->{groups}{subtype_group_assignments}{$subtype_prop}{$assignment};
	$group_id = $self->{groups}{subtype_group_assignments}{$subtype_prop}{"$subtype_prop\_other"} unless $group_id;
	croak "Error: no group for value $assignment in data type $subtype_prop." unless $group_id;

	$subtype_groups->{$is_public}{$contig_collection_id}{$subtype_prop} = [] unless 
		defined $subtype_groups->{$is_public}{$contig_collection_id}{$subtype_prop};
	push @{$subtype_groups->{$is_public}{$contig_collection_id}{$subtype_prop}}, [$group_id, $fp_id];

}


=head2 handle_upload

=over

=item Usage

  $obj->handle_upload(login_id => $id,
  					  category => $cat,
  					  tag => $desc,
  					  release_date => '0000-00-00',
  					  upload_date => '0000-00-00')

=item Function

Perform creation of upload entry which is printed to file handle. Caches upload id.
Does the same for the permission table.

=item Returns

Nothing

=item Arguments

Hash with following keys: login_id, category, tag, release_date, upload_date

=back

=cut

sub handle_upload {
	my ($self, %argv) = @_;
	
	my %valid_cats = (public => 1, private => 1, release => 1);
	
	# Category
	my $category = $argv{category};
	croak "Missing argument: category" unless $category;
	croak "Invalid category: $category" unless $valid_cats{$category};
	
	# Login id
	my $login_id = $argv{login_id};
	croak "Missing argument: login_id" unless defined $login_id;
	
	# Tag
	my $tag = $argv{tag};
	$tag = 'Unclassified' unless $tag;
	
	# Release date
	my $rel_date = '3955-01-01'; # Apes will rule, so whatever
	if($category eq 'release') {
		$rel_date = $argv{release_date};
		croak "Missing argument: release_date" unless defined($rel_date);
		croak "Improperly formatted date: release_date (expected format: 0000-00-00)." unless $rel_date =~ m/^\d\d\d\d-\d\d-\d\d$/;
	}
	
	# Upload date
	my $upl_date = $argv{upload_date};
	croak "Missing argument: upload_date" unless defined($upl_date);
	croak "Improperly formatted date/time: upload_date (expected format: 0000-00-00 00:00:00)." unless $upl_date =~ m/^\d\d\d\d-\d\d-\d\d \d\d\:\d\d:\d\d$/;
	
	# Cache upload value
	my $upload_id = $self->nextoid('upload');
	
	# Save in file
	$self->print_upl($upload_id, $login_id, $category, $tag, $rel_date, $upl_date);
	$self->nextoid('upload','++');
	
	# Now fill in permission entry
	
	# Uploader is given full permissions;
	my $can_share = my $can_modify = 1;
	my $perm_id = $self->nextoid('permission');
	
	$self->print_perm($perm_id, $upload_id, $login_id, $can_modify, $can_share);
	$self->nextoid('permission','++');
	
	return($upload_id);
}

sub print_upl {
	my $self = shift;
	my ($upl_id,$login_id,$cat,$tag,$rdate,$udate) = @_;

	my $fh = $self->file_handles('upload');
 
	print $fh join("\t",($upl_id,$login_id,$cat,$tag,$rdate,$udate)),"\n";
  
}

sub print_perm {
	my $self = shift;
	my ($perm_id,$upl_id,$login_id,$mod,$share) = @_;

	my $fh = $self->file_handles('permission');
 
	print $fh join("\t",($perm_id,$upl_id,$login_id,$mod,$share)),"\n";
  
}

sub print_scol {
	my $self = shift;
	my ($snp_id,$col) = @_;

	my $fh = $self->file_handles('snp_column');
 
	print $fh join("\t",($snp_id,$col)),"\n";
  
}

=head2 is_different_sequence

Given feature_id and sequence,
return true if sequence is different from DB sequence

=cut
sub is_different_sequence {
	my $self = shift;
	my ($feature_id, $seq, $is_public) = @_;

	if($is_public) {
		$self->{'queries'}{'select_from_public_feature'}->execute(
		    $feature_id         
		);
		my @row = $self->{'queries'}{'select_from_public_feature'}->fetchrow_array();
		croak "Feature $feature_id not found in feature table." unless @row;
		my $dbseq = $row[2];

		return $dbseq ne $seq;	
	}
	else {
		$self->{'queries'}{'select_from_private_feature'}->execute(
		    $feature_id         
		);
		my @row = $self->{'queries'}{'select_from_private_feature'}->fetchrow_array();
		croak "PrivateFeature $feature_id not found in feature table." unless @row;
		my $dbseq = $row[2];

		return $dbseq ne $seq;	
	}

}


=head2 log

Add entry with timestamp to print stmt

=cut
sub logger {
	my $log_ok = shift;
	my $msg = shift;

	my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
	print "$date: $msg\n" if $log_ok;
	
}


1;

__DATA__
__C__

// Make a series of edits to a dna string
// Edits are stored in an array of arrays:
// [[position, nucleotide],[...]]
void snp_edits(int offset, SV* dna, SV* snps_arrayref) {
	AV* snps;
	AV* snp_row;
	
	snps = (AV*)SvRV(snps_arrayref);
	int n = av_len(snps);
	int i;
	
	char* dna_string = (char*)SvPV_nolen(dna);
	
	// Rewrite 
	for(i=0; i <= n; ++i) {
		SV* row = av_shift(snps);
		snp_row = (AV*)SvRV(row);
		
		SV* pos = av_shift(snp_row);
		SV* nuc = av_shift(snp_row);
		int p = (int)SvIV(pos);
		int j = p - offset;
		//printf("%i, %i, %i\n", p, offset, j);
		char* c = (char*)SvPV_nolen(nuc);
		
		dna_string[j] = *c;
	}
}




