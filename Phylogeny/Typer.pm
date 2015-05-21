#!/usr/bin/env perl

=pod

=head1 NAME

  Phylogeny::Typer

=head1 DESCRIPTION

  This class provides utilities for in silico typing based
  on phylogenetic tree positions (relative to genes with known types).

=head1 AUTHOR

  Matt Whiteside (matthew.whiteside@phac-aspc.gov.ca)

=cut

{
	package StxNode;
	
	sub new {
		my $class = shift;
		my %args = @_;
		
		my $self = {};
		
		$self->{'leaf'} = 1;
		$self->{'children'} = [];
		$self->{'stx'} = 0;
		$self->{'is_signpost'} = 0;
		$self->{'name'} = '';
		$self->{'root'} = 0;
		$self->{'assigned'} = 0;
		$self->{'length'} = 0;
		$self->{'branch_type'} = 0;
		
		
		bless $self, $class;
		return $self;
	}
	
	sub is_leaf {
		my $self = shift;
		return $self->{'leaf'};
	}
	
	sub is_root {
		my $self = shift;
		return $self->{'root'};
	}
	
	sub is_signpost {
		my $self = shift;
		return $self->{'is_signpost'};
	}
	
	sub length {
		my $self = shift;
		$self->{'length'} = shift // return $self->{'length'};
	}
	
	sub name {
		my $self = shift;
		
		if(@_) {
			$self->{'name'} = shift;
			if($self->{'name'} =~ m/\#REF\#Stx(\w+)-/) {
				$self->{'stx'} = $1;
				$self->{'is_signpost'} = 1;
			}
		}
		return $self->{'name'};
	}
	
	sub children {
		my $self = shift;
		if(@_) {
			push @{$self->{'children'}}, @_;
			$self->{'leaf'} = 0;
		}
		return $self->{'children'};
	}
	
	sub stx_marker {
		my $self = shift;
		return $self->{'stx'};
	}
	
	sub set_type {
		my $self = shift;
		$self->{'stx'} = shift;
		$self->{'assigned'} = 1;
	}
	
	sub finalized {
		my $self = shift;
		if(@_) {
			$self->{'assigned'} = shift;
		}
		return  $self->{'assigned'};
	}
	
	sub waiting_ancestor_type {
		my $self = shift;
		if(@_) {
			$self->{'branch_type'} = shift;
		}
		return  $self->{'branch_type'};
	}
	
}


package Phylogeny::Typer;

use strict;
use warnings;

use Carp qw/croak carp/;
use File::Basename;
use lib dirname (__FILE__) . "/../";
use Role::Tiny::With;
with 'Roles::DatabaseConnector';
use Config::Tiny;
use Phylogeny::TreeBuilder;
use Bio::SeqIO;

my $type_id_hash;
my $sql_stmt_hash;
my $seq_hash;

my $multiple_type_name = 'multiple';


=head2 new


=cut

sub new {
	my ($class) = shift;
	my %params = @_;
	
	my $self = {};
	bless( $self, $class );

	my $dirname = dirname(__FILE__);
	
	# DB connection
	my $config_file = $params{config} //= "$dirname/../../config/genodo.cfg";
	if($params{dbix_schema}) {
		# Use existing DBIx::Class::Schema connection
		$self->setDbix($params{dbix_schema});

	}
	else {
		# Establish new DB connection using config file parameters
		$self->connectDatabaseConf($config_file);
	}

	# Reference sequences
	$self->{stx1_superaln_reference} = $params{stx1_reference_sequences} //= "$dirname/stx1_superaln_reference.affn";
	$self->{stx2_superaln_reference} = $params{stx2_reference_sequences} //= "$dirname/stx2_superaln_reference.affn";
	croak "Error: cannot find alignment file for Stx1 reference genes.\n" unless -r $self->{stx1_superaln_reference};
	croak "Error: cannot find alignment file for Stx2 reference genes.\n" unless -r $self->{stx2_superaln_reference};

	if(my $conf = Config::Tiny->read($config_file)) {
		# Muscle exe
		$self->{muscle} = $params{muscle} //= $conf->{ext}->{muscle};
		croak "Error: cannot find muscle exe." unless -x $self->{muscle};

		# FastTree exe
		$self->{fasttree} = $conf->{ext}->{fasttreemp};
		croak "Error: cannot find fasttree exe." unless -x $self->{fasttree};

		# Tree object
		$self->{tree_builder} = Phylogeny::TreeBuilder->new(fasttree_exe => $self->{fasttree});
	
		# Tmp directory
		$self->{tmp_dir} = $params{tmp_dir} //= $conf->{tmp}->{dir};
		croak "Error: cannot find temp directory." unless -d $self->{tmp_dir};
	}
	else {
		croak $Config::Tiny::errstr;
	}
	
	return $self;
}

=head2 subtypeList

Return subtypes and their possible values

=cut

sub subtypeList {
	my $self = shift;


	my %subtype_values;

	my $tmp = $self->referenceSubtypes(1);
	foreach my $v (values %$tmp) {
		$subtype_values{stx1} = $v;
	}
	# Add the 'multiple' value
	$subtype_values{stx1} = $multiple_type_name;

	$tmp = $self->referenceSubtypes(2);
	foreach my $v (values %$tmp) {
		$subtype_values{stx2} = $v;
	}
	# Add the 'multiple' value
	$subtype_values{stx2} = $multiple_type_name;

	return \%subtype_values;
}

sub referenceSubtypes {
	my $self = shift;
	my $type = shift; # 1 or 2

	croak "Error: invalid type argument: $type." unless $type == 1 or $type == 2;

	my $ref_fasta_file;
	if($type == 1) {
		$ref_fasta_file = $self->{stx1_superaln_reference};
	} else {
		$ref_fasta_file = $self->{stx2_superaln_reference};
	}


	# Load reference sequences
	my $fasta = Bio::SeqIO->new(-file   => $ref_fasta_file, -format => 'fasta') 
		or croak "Error: unable to open Bio::SeqIO stream to $ref_fasta_file ($!).";

	# Parse subtype from header
	my %subtypes;
	while (my $entry = $fasta->next_seq) {
		my $id = $entry->display_id;
		my $refseq;
		
		if($id =~ m/\#REF\#(Stx\w+-.+)$/) {
			$refseq = $1;
		} else {
			croak "Error: invalid header format in stx typing reference file: $id."
		}

		my ($subtype) = ($refseq =~ m/Stx(\w+)-/);

		$subtypes{$refseq} = $subtype;
		
	}

	return \%subtypes;
}

=head2 insertTypingObjects

  Setup feature objects to represent Stx1/2 sequences. Needs to only be
  called once.

=cut

sub insertTypingObjects {
	my $self = shift;
	
	# Retrieve need cvterm type_ids
	my @type_names = qw/typing_sequence fusion_of virulence_factor/;
	my $type_rs = $self->dbixSchema->resultset('Cvterm')->search(
		{
			name => \@type_names,
		},
		{
			columns => ['name','cvterm_id']
		}
	);
	
	my %type;
	while (my $type_row = $type_rs->next) {
		$type{$type_row->name} = $type_row->cvterm_id;
	}
	
	croak "Error: Missing ontology type in cvterm table." unless scalar(keys %type) == scalar(@type_names);
	
	# Get organism ID
	my $organism_row = $self->dbixSchema->resultset('Organism')->find({
		genus => 'Escherichia',
		species => 'coli'
	});
	my $organism_id = $organism_row->organism_id;
	
	# Insert missing features 
	for my $g (1..2) {
		
		# Find query genes that make up each typing sequence
		my $sua = "stx$g".'A';
		my $sub = "stx$g".'B';
		my $stx_rs = $self->dbixSchema->resultset('Feature')->search(
			{
				'name' => { '-in' => [$sua, $sub] },
				'type_id' => $type{virulence_factor}
			},
			{
				columns => ['name', 'feature_id']
			}
		);
		
		my %query_genes;
		my $i = 0;
		while (my $stx_row = $stx_rs->next) {
			$query_genes{$stx_row->name} = $stx_row->feature_id;
			$i++;
		}
		croak "Error: Could not find all virulence_factor genes associated with stx$g." unless $i == 2;
		
		# Create a stx1/2 typing sequence references.
		# All instances of stx1 or stx2 sequences in individual genomes will
		# be linked to these reference features via 'variant_of' relationship
		my $nm = "Shiga-toxin Subunit $g Reference Typing Sequence";
		my $un = "stx$g\_subunit";
		my $feature_hash = {
			name => $nm,
			uniquename => $un,
			organism_id => $organism_id,
			is_analysis => 'true',
			type_id => $type{typing_sequence}
		};
		
		my $f = $self->dbixSchema->resultset('Feature')->find_or_create(
			$feature_hash,
			{
				'key' => 'feature_c1'
			}
		);
		
		# Link to query genes
		$self->dbixSchema->resultset('FeatureRelationship')->find_or_create(
			{
				subject_id => $f->feature_id,
				object_id => $query_genes{$sua},
				type_id => $type{fusion_of},
				rank => 0
			},
			{
				'key' => 'feature_relationship_c1'
			}
		);
		$self->dbixSchema->resultset('FeatureRelationship')->find_or_create(
			{
				subject_id => $f->feature_id,
				object_id => $query_genes{$sub},
				type_id => $type{fusion_of},
				rank => 1
			},
			{
				'key' => 'feature_relationship_c1'
			}
		);
		
	}
	
}

=head2 dbAlignments

  Get alignment sequences from DB. Write as stx1/2 super-alignments
  in FASTA format.

=cut

sub dbAlignments {
	my $self = shift;
	my $file_prefix = shift;
	my $gp_ids = shift;
	
	# Get the stx Feature IDs
	my $stx_rs = $self->dbixSchema->resultset('Feature')->search(
		{
			'me.name' => { '-in' => ['stx1A', 'stx1B', 'stx2A', 'stx2B'] },
			'type.name' => 'virulence_factor'
		},
		{
			join => ['type'],
			columns => ['me.name', 'feature_id']
		}
	);
	
	my %stx_genes;
	my $n = 0;
	print "FEATURE IDs:\n";
	map { print $_->name.": ".$_->feature_id."\n"; $stx_genes{$_->feature_id} = $_->name; $n++; } $stx_rs->all;
	croak "Error: Missing/incorrect stx genes." unless $n == 4;
	
	if($gp_ids) {
		# Obtain alignments for selected genomes
		my @private_ids = map m/private_(\d+)/ ? $1 : (), @$gp_ids;
		my @public_ids = map m/public_(\d+)/ ? $1 : (), @$gp_ids;
		croak "NOT IMPLEMENTED";
		
	} else {
		# Obtain alignments for all public genomes
		my $allele_rs = $self->dbixSchema->resultset('Feature')->search(
			{
		        'feature_relationship_subjects.object_id' => { '-in' => [ keys %stx_genes ]},
		        'type.name' => "allele",
		        'type_2.name' => "similar_to",
		        'type_3.name' => "part_of",
			},
			{
				columns   => [qw/feature_id residues md5checksum/],
				'+select' => [qw/feature_relationship_subjects.object_id feature_relationship_subjects_2.object_id/],
				'+as'     => [qw/query_gene contig_collection/],
				join      => 
					[
						'type', 
						{'feature_relationship_subjects' => 'type'},
						{'feature_relationship_subjects' => 'type'}
					],
				order_by => ['feature_id']
			}
		);
		
		# Build super-alignments and write to file
		my %stx;
		while (my $allele = $allele_rs->next) {
			my $gene_name = $stx_genes{$allele->get_column('query_gene')};
			
			my ($gene, $copy) = ($gene_name =~ m/stx(1|2)(A|B)/);
			
			$stx{$allele->get_column('contig_collection')}{$gene}{$copy} = {
				seq => $allele->residues,
				allele => $allele->feature_id
			};
		}
		
		my $f1 = "$file_prefix\_stx1.ffn";
		my $f2 = "$file_prefix\_stx2.ffn";
		open my $out1, ">", $f1 or croak "Error: Unable to write to file $f1 ($!)\n";
		open my $out2, ">", $f2 or croak "Error: Unable to write to file $f2 ($!)\n";
		my @fhs = (undef, $out1, $out2);
		foreach my $genome (keys %stx) {
			my $genome_alleles = $stx{$genome};
			
			foreach my $gene (1..2) {
				if($genome_alleles->{$gene}) {
					unless ($genome_alleles->{$gene}->{'A'}) {
						warn "[Warning] $genome is missing A subunit gene for stx$gene.\n";
						next;
					}
					unless ($genome_alleles->{$gene}->{'B'}) {
						warn "[Warning] $genome is missing B subunit gene for stx$gene.\n";
						next;
					}
					
					my $superaln = $genome_alleles->{$gene}->{'A'}->{seq} .  $genome_alleles->{$gene}->{'B'}->{seq};
					my $a1 = $genome_alleles->{$gene}->{'A'}->{allele};
					my $a2 = $genome_alleles->{$gene}->{'B'}->{allele};
					my $fh = $fhs[$gene];
					my $gene_name1 = "stx$gene" . 'A';
					my $gene_name2 = "stx$gene" . 'B';
					print $fh ">public_$genome|$gene_name1\_$a1|$gene_name2\_$a2\n$superaln\n";
				}
			}
		}
		close $out1; close $out2;
		
		return($f1, $f2);
	}
}


=head2 stxTyping


=cut

sub stxTyping {
	my $self = shift;
	my $file_prefix = shift;
	my @stx_files = @_;
	
	# Compute stx type
	my $gene = 1;
	my @results;
	# foreach my $stx_aln_file (@stx_files) {
	# 	my $ref_file = $self->{"stx$gene\_superaln_reference"};
	# 	my $result_file = $file_prefix . "_stx$gene\_type.txt";
	# 	my $tree_file = $file_prefix . "_stx$gene\_tree.phy";
	# 	$self->run($stx_aln_file, $ref_file, $result_file, $tree_file);

	# 	$gene++;
	# 	push @results, $result_file;
	# }

	foreach my $stx_aln_file (@stx_files) {
		
		my $result_file = $file_prefix . "_stx$gene\_type.txt";
		
		$gene++;
		push @results, $result_file;
	}

	# Load results into db
	$type_id_hash = $self->initialize_ontology();
	$sql_stmt_hash = $self->prepare_sql_statements();

	$gene = 1;
	foreach my $result_file (@results) {
		$self->loading($gene, $result_file, $stx_files[$gene-1]);

		$gene++;
	}

	$self->restore_dbh_settings;
}

=head2 initialize_ontology 

Retrieve cvterm and feature IDs needed for loading

=cut

sub initialize_ontology {
	my $self = shift;

	
	# Commonly used cvterms
    my $fp_sth = $self->dbh->prepare("SELECT t.cvterm_id FROM cvterm t, cv v WHERE t.name = ? AND v.name = ? AND t.cv_id = v.cv_id"); 

	# Part of ID
	$fp_sth->execute('part_of', 'relationship');
    my ($part_of) = $fp_sth->fetchrow_array();
    
    # Allele ID
    $fp_sth->execute('allele', 'sequence');
    my ($allele) = $fp_sth->fetchrow_array();
   
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

    # Stx type ID
    $fp_sth->execute('stx1_subtype', 'local');
    my ($stx1_type) = $fp_sth->fetchrow_array();

    $fp_sth->execute('stx2_subtype', 'local');
    my ($stx2_type) = $fp_sth->fetchrow_array();
    
    
    my $types = {
    	allele => $allele,
    	typing_sequence => $typing,
    	allele_fusion => $fusion,
    	part_of => $part_of,
    	fusion_of => $fusion_of,
    	variant_of => $variant_of,
    	stx1 => $stx1_type,
    	stx2 => $stx2_type
    };

    # Default organism
    my $o_sth = $self->dbh->prepare("SELECT organism_id FROM organism WHERE common_name = 'Escherichia coli'");
    $o_sth->execute();
    my ($o_id) = $o_sth->fetchrow_array();
    $types->{organism} = $o_id;
   
	# Place-holder publication ID
	my $p_sth = $self->dbh->prepare("SELECT pub_id FROM pub WHERE uniquename = 'null'");
	$p_sth->execute();
	($types->{pub_id}) = $p_sth->fetchrow_array();

	# Get reference stx typing sequences
	my $sql = "SELECT f.feature_id, f.uniquename
	FROM feature f
	WHERE f.type_id = $typing";
			  
	my $feature_arrayref = $self->dbh->selectall_arrayref($sql);
			
	foreach my $row (@$feature_arrayref) {
		if($row->[1] eq 'stx1_subunit') {
			$types->{'stx1_refseq'} = $row->[0]
		} elsif($row->[1] eq 'stx2_subunit') {
			$types->{'stx2_refseq'} = $row->[0]
		}
	}

	croak "Error: reference typing sequence for Stx gene 1 not found" unless $types->{stx1_refseq};
	croak "Error: reference typing sequence for Stx gene 2 not found" unless $types->{stx2_refseq};

	# print "Stx1 reference typing sequence ID: ".$types->{stx1_refseq}."\n";
	# print "Stx2 reference typing sequence ID: ".$types->{stx2_refseq}."\n";

	# Get reference gene IDs that make up holotoxin typing sequence
	$sql = "SELECT r.object_id
	FROM feature_relationship r
	WHERE r.type_id = ".$types->{'fusion_of'}." AND r.subject_id = ? ORDER BY r.rank";

	my $subu_sth = $self->dbh->prepare($sql);
  
  	$subu_sth->execute($types->{'stx1_refseq'});
	my $stx1_subunit_arrayref = $subu_sth->fetchall_arrayref();
	my $stx1a_gene = $stx1_subunit_arrayref->[0]->[0] || croak "Error: missing stx1a gene ID.\n";
	my $stx1b_gene = $stx1_subunit_arrayref->[1]->[0] || croak "Error: missing stx1b gene ID.\n";

	$types->{'stx1a'} = $stx1a_gene;
	$types->{'stx1b'} = $stx1b_gene;

	$subu_sth->execute($types->{'stx2_refseq'});
	my $stx2_subunit_arrayref = $subu_sth->fetchall_arrayref();
	my $stx2a_gene = $stx2_subunit_arrayref->[0]->[0] || croak "Error: missing stx2a gene ID.\n";
	my $stx2b_gene = $stx2_subunit_arrayref->[1]->[0] || croak "Error: missing stx2b gene ID.\n";

	$types->{'stx2a'} = $stx2a_gene;
	$types->{'stx2b'} = $stx2b_gene;
	
	return $types;
}

=head2 prepare_sql_statements

Prepare commonly used sql statements, turn on transactions

=cut

sub prepare_sql_statements {
	my $self = shift;

	my $stmt_hash;

	# Find existing entry
	my $sql = "SELECT f.feature_id, fp.value ".
		'FROM feature_relationship r1, feature_relationship r2, feature f, featureprop fp '.
		'WHERE r1.type_id = '.$type_id_hash->{fusion_of}.' AND r1.object_id = ? AND f.feature_id = r1.subject_id '.
		'AND r2.type_id = '.$type_id_hash->{fusion_of}.' AND r2.object_id = ? AND f.feature_id = r2.subject_id '.
		'AND fp.type_id = ? AND f.feature_id = fp.feature_id';

	my $sth = $self->dbh->prepare($sql);

	$stmt_hash->{search} = $sth;

	# Insert feature
	$sql = 'INSERT INTO feature (name,uniquename,type_id,residues,seqlen,organism_id) VALUES(?,?,?,?,?,?) RETURNING feature_id';
	$sth = $self->dbh->prepare($sql);

	$stmt_hash->{insert_feature} = $sth;

	# Insert property
	$sql = 'INSERT INTO featureprop (feature_id,type_id,value,rank) VALUES(?,?,?,?)';
	$sth = $self->dbh->prepare($sql);

	$stmt_hash->{insert_featureprop} = $sth;

	# Insert relationship
	$sql = 'INSERT INTO feature_relationship (subject_id,object_id,type_id,rank) VALUES(?,?,?,?)';
	$sth = $self->dbh->prepare($sql);

	$stmt_hash->{insert_relationship} = $sth;

	# Transactions
	$self->{prev_dbh_settings}{AutoCommit} = $self->dbh->{AutoCommit};
	$self->dbh->{AutoCommit} = 0;
	$self->{prev_dbh_settings}{RaiseError} = $self->dbh->{RaiseError};
	$self->dbh->{RaiseError} = 1;

	return $stmt_hash;
}

=head2 restore_dbh_settings

=cut

sub restore_dbh_settings {
	my $self = shift;

	$self->dbh->{AutoCommit} = $self->{prev_dbh_settings}{AutoCommit};
	$self->dbh->{RaiseError} = $self->{prev_dbh_settings}{RaiseError};

}



=head2 loading

Perform checks and update/insert operations for each
stx subtype assignment

=cut

sub loading {
	my ($self, $stx_gene, $afile, $sfile) = @_;

	# Load assignments
	my %data_hash;
	open(my $in, "<$afile") or croak "Error: unable to read file $afile ($!).\n";
	while(my $line = <$in>) {
		chomp $line;
		
		my $typing_hash = _parse_id($line, $stx_gene);
		$data_hash{$typing_hash->{genome_label}}{$typing_hash->{id}} = $typing_hash;
	}
	close $in;

	# Load sequences
	my $fasta = Bio::SeqIO->new(-file   => $sfile,
							    -format => 'fasta') or die "Error: unable to open Bio::SeqIO stream to $sfile ($!).";
	while (my $entry = $fasta->next_seq) {
		my $id = $entry->display_id;
		my $seq = $entry->seq;

		$seq_hash->{$id} = $seq;
	}
	
	# Check assignments and insert/update as needed
	foreach my $genome (keys %data_hash) {
		my $typing_hashes = $data_hash{$genome};
		$self->upsert($typing_hashes);
	}

}

sub _parse_id {
	my $line = shift;
	my $gene = shift;

	my ($id, $asmt) = split(/\t/, $line);

	my $subunitA = "stx$gene".'A_';
	my $subunitB = "stx$gene".'B_';

	my ($access, $genome_id, $allele_id1, $allele_id2) = ($id =~ m/(public|private)_(\d+)\|$subunitA(\d+)\|$subunitB(\d+)/);

	croak "Error: invalid stx ID format $id.\n" unless $access && $genome_id && $allele_id1 && $allele_id2;

	return {
		access => $access,
		genome => $genome_id,
		allele1 => $allele_id1,
		allele2 => $allele_id2,
		gene => $gene,
		assignment => $asmt,
		is_public => ($access eq 'public' ? 1 : 0),
		genome_label => "$access\_$genome_id",
		id => $id
	};
}

sub upsert {
	my ($self, $typing_hashes) = @_;

	my $genome_id;
	my $gene;
	my $is_public;

	# One or more stx assignments may exist for a genome
	foreach my $typing_hash (values %$typing_hashes) {
		unless($genome_id) {
			$genome_id = $typing_hash->{'genome'};
			$gene = $typing_hash->{'gene'};
			$is_public = $typing_hash->{'is_public'};
		}

		# 0 = present with correct assmt, 1 = present with different assignment, 2 = absent
		my $r = $self->_check_entry($typing_hash->{'allele1'}, $typing_hash->{'allele2'}, $is_public,
			$gene, $typing_hash->{'assignment'});

		my $msg = $r == 0 ? "correct" : ($r == 1 ? "incorrect" : "not in db");
		my $gn = $typing_hash->{access}.'_'.$typing_hash->{genome};
		print "Genome $gn stx".$typing_hash->{gene}." entry is $msg\n";

		if($r == 2) {
			$self->insert($typing_hash);
			print "\tnew entry loaded\n";

		} elsif($r == 1) {
			$self->update();
			print "\tnew entry updated\n";

		} else {
			print "\tskipped\n";
		}

		$self->dbh->commit;
		last;

	}

	
	
	
}

# 0 = present with correct assmt, 1 = present with different assignment, 2 = absent
sub _check_entry {
	my $self = shift;
	my $allele1_id = shift;
	my $allele2_id = shift;
	my $is_public = shift;
	my $stx_gene = shift;
	my $stx_asmt = shift;

	my $stx_name = 'stx'.$stx_gene;
	my $stx_prop_id = $type_id_hash->{$stx_name};

	if($is_public) {
		
		$sql_stmt_hash->{search}->execute($allele1_id, $allele2_id, $stx_prop_id);
		my ($feature_id, $stx_value) = $sql_stmt_hash->{search}->fetchrow_array();

		if($feature_id) {
			if($stx_asmt eq $stx_value) {
				return 0;
			} else {
				return 1;
			}
		} else {
			return 2;
		}


	} else {
		croak "Error: private _check_entry() functionality not implemented.\n";
	}

}

sub update {
	croak "Error: update() method not implemented.\n";
}

sub insert {
	my ($self, $typing_hash) = @_;

	my $h;
	my $subtype_name;
	my $stx_refseq;
	if($typing_hash->{gene} == 1) {
		$subtype_name = 'stx1';
		$stx_refseq = $type_id_hash->{'stx1_refseq'};
		$h = $type_id_hash->{stx1a}.'_'.$typing_hash->{allele1}.'|'.$type_id_hash->{stx1b}.'_'.$typing_hash->{allele2};

	} elsif($typing_hash->{gene} == 2) {
		$subtype_name = 'stx2';
		$stx_refseq = $type_id_hash->{'stx2_refseq'};
		$h = $type_id_hash->{stx2a}.'_'.$typing_hash->{allele1}.'|'.$type_id_hash->{stx2b}.'_'.$typing_hash->{allele2};

	} else {
		croak;
	}

	# Insert new feature
	my $uniquename = "typer:$h";
	my $organism = $type_id_hash->{organism};
	my $name = "$subtype_name subtype for genome ".$typing_hash->{genome};
	my $seq = $seq_hash->{$typing_hash->{'id'}} || croak "Error: missing typing sequence for ".$typing_hash->{'id'}."\n";
	my $seqlen = length($seq);
	my $type = $type_id_hash->{'allele_fusion'};
	my $feature_id = _add_public_feature($name,$uniquename,$type,$seq,$seqlen,$organism);

	# Assign subtype property
	my $value = $typing_hash->{'assignment'};
	my $rank = 0;
	my $prop_type = $type_id_hash->{$subtype_name};
	_add_public_property($feature_id,$prop_type,$value,$rank);

	# Link to genome
	my $genome_id = $typing_hash->{'genome'};
	my $rel_type1 = $type_id_hash->{'part_of'};
	$rank = 0;
	_add_public_relationship($feature_id,$genome_id,$rel_type1,$rank);

	# Link to typing reference sequence
	my $rel_type2 = $type_id_hash->{'variant_of'};
	$rank = 0;
	_add_public_relationship($feature_id,$genome_id,$rel_type2,$rank);

	# Link to alleles
	my $rel_type3 = $type_id_hash->{'fusion_of'};
	$rank = 0;
	_add_public_relationship($feature_id,$typing_hash->{allele1},$rel_type3,$rank);
	$rank++;
	_add_public_relationship($feature_id,$typing_hash->{allele2},$rel_type3,$rank);

}



sub _add_public_relationship {
	my ($subject_id,$object_id,$type_id,$rank) = @_;

	$sql_stmt_hash->{insert_relationship}->execute($subject_id,$object_id,$type_id,$rank);
}

sub _add_public_feature {
	my ($name,$uniquename,$type,$seq,$seqlen,$organism) = @_;

	$sql_stmt_hash->{insert_feature}->execute($name,$uniquename,$type,$seq,$seqlen,$organism);

	my $fid = $sql_stmt_hash->{insert_feature}->fetch()->[0];

	return $fid;
}

sub _add_public_property {
	my ($feature_id,$type_id,$value,$rank) = @_;

	$sql_stmt_hash->{insert_featureprop}->execute($feature_id,$type_id,$value,$rank);
}



=head2 subtype

Used in ExperimentalFeatures.pm

=cut

sub subtype {
	my $self = shift;
	my $typing_gene = shift;
	my $fasta_hashref = shift;
	my $tree_file = shift;
	my $result_file = shift;
	
	# map known typing genes to stored reference alignments
	my $ref_file;
	
	if($typing_gene eq 'stx1_subunit') {
		$ref_file = $self->{"stx1_superaln_reference"};
	} elsif($typing_gene eq 'stx2_subunit') {
		$ref_file = $self->{"stx2_superaln_reference"};
	} else {
		croak "Error: unknown typing sequence $typing_gene. Need reference alignment with assigned subtypes\n"
	}
	
	$self->run($ref_file, $fasta_hashref, $result_file, $tree_file);
	
}

=head2 run

Subtyping pipeline

=cut

sub run {
	my $self        = shift;
	my $ref_file    = shift; # fasta-format reference alignment
	my $typing_seqs = shift; # fasta-format untyped sequences alignment
	my $res_file    = shift; # tab-delimited subtype assigments
	my $tree_file   = shift; # Newick tree with reference and untyped sequences
	
	# Merge reference and target alignments
	my $aln_file = $self->{tmp_dir} . 'typer.aln';
	my $aln_file2 = $self->{tmp_dir} . 'typer_in.aln';
	my $muscle_cmd = $self->{muscle};
	
	if(ref($typing_seqs) eq 'HASH') {
		open(OUT, ">$aln_file2") or die "Error: Unable to write to file $aln_file2 ($!)\n";
		foreach my $header (keys %$typing_seqs) {
			print OUT ">$header\n".$typing_seqs->{$header}."\n";
		}
		close OUT;
		
		$muscle_cmd .= " -profile -in1 $ref_file -in2 $aln_file2 -out $aln_file";
		
	} elsif(-e $typing_seqs) {
		
		$muscle_cmd .= " -profile -in1 $ref_file -in2 $typing_seqs -out $aln_file";
		
	} else {
		
		croak "Error: Invalid or missing arguments in run() method.\n";
	}
	
	
	unless(system($muscle_cmd) == 0) {
		croak "Error: Muscle profile alignment failed (command: $muscle_cmd).\n";
	}
	print "MUSCLE COMPLETE\n";
	
	# Build tree
	my $tmp_tree_file = $self->{tmp_dir} . 'typer.phy';
	$self->{tree_builder}->build_tree($aln_file, $tmp_tree_file);
	
	print "TREE COMPLETE\n";
	
	# Convert Newick tree to Perl structure
	my $root = _newickToPerl($tmp_tree_file);
	
	print "LOADING COMPLETE\n";
	
	# Assign types
	_computeTypes($root);
	
	print "TYPING COMPLETE\n";
	
	# Write results
	_perlToNewick($root, $res_file, $tree_file);
	
	print "PRINTING COMPLETE\n";
}


=head2 _newickToPerl

Convert from Newick to Perl structure.

Input: file name containing Newick string
Returns: hash-ref

=cut

sub _newickToPerl {
	my $newick_file = shift;
	
	my $newick;
	open(IN, "<$newick_file") or die "Error: Unable to read file $newick_file ($!)\n";
	
	while(my $line = <IN>) {
		chomp $line;
		$newick .= $line;
	}
	
	close IN;
	
	my @tokens = split(/\s*(;|\(|\)|:|,)\s*/, $newick);
	my @ancestors;
	my $tree = new StxNode();
	
	for(my $i=0; $i < @tokens; $i++) {
		
		my $tok = $tokens[$i];
		
		if($tok eq '(') {
			my $subtree = new StxNode();
			$tree->children($subtree);
			push @ancestors, $tree;
			$tree = $subtree;
			
		} elsif($tok eq ',') {
			my $subtree = new StxNode();
			$ancestors[$#ancestors]->children($subtree);
			$tree = $subtree;
			
		} elsif($tok eq ')') {
			$tree = pop @ancestors;
			
		} elsif($tok eq ':') {
			# optional length next
			
		} else {
			my $x = $tokens[$i-1];
        	
        	if( $x eq ')' || $x eq '(' || $x eq ',') {
				$tree->name($tok);
          	} elsif ($x eq ':') {
          		$tree->length($tok+=0);  # Force number
          	}
		}
	}
	
	$tree->{'root'} = 1;
	
	return $tree;
}

=head2 _computeTypes

Assigns Stx types based on clade distribution.

Input: StxNode object
Returns: nothing

=cut

sub _computeTypes {
	my $curr_node = shift;
	
	# Look for descendants with types
	my @subtrees;
	my @descendant_types;
	my @descendant_dists;
	
	foreach my $node (@{$curr_node->children}) {
		if($node->is_leaf && $node->is_signpost) {
			# This node can be used to assign type to descendants
			push @descendant_types, $node->stx_marker;
			push @descendant_dists, $node->length;
		} elsif(!$node->is_leaf) {
			# This node is a subtree which may have a type.
			push @subtrees, $node;
		}
	}
	
	# Determine the types of the subtrees
	foreach my $descendant (@subtrees) {
		my ($this_type, $distance) = _computeTypes($descendant);
		
		if($this_type) {
			push @descendant_types, $this_type;
			push @descendant_dists, $distance;
		}
		
	}
	
	if(@descendant_types > 1) {
		# Multiple descendants have a type, compute the overall type of the internal node
		
		my %all_types;
		map { $all_types{$_}++ } @descendant_types;
		
		my $curr_type;
		my @possible_types = keys %all_types;
		if(@possible_types == 1) {
			$curr_type = shift @possible_types;
		} else {
			# Mixed types
			$curr_type = $multiple_type_name;
		}
		
		_assignTypes($curr_node, $curr_type);
		
		# Find the most recent descendant
		my $min_d = $descendant_dists[0];
		my $min_i = 0;
		my $i = 0;
		
		foreach my $d (@descendant_dists[1..$#descendant_dists]) {
			$i++;
			if($d < $min_d) {
				$min_d = $d;
				$min_i = $i;
			}
		}
		
		return($descendant_types[$min_i], $min_d+$curr_node->length);
		
	} elsif(@descendant_types == 1) {
		# Only a single descendant has a type, others are unknown.
		# Set tentative type that will be defined once ancestor type is known
		$curr_node->waiting_ancestor_type($descendant_types[0]);
		
		return($descendant_types[0],$descendant_dists[0]+$curr_node->length);
		
	} else {
		# A leaf node
		return ($curr_node->stx_marker, $curr_node->length);
	}
}


=head2 _assignTypes

Labels descendants with given type if they are undefined.

Input: StxNode object, stx type
Returns: nothing

=cut

sub _assignTypes {
	my $curr_node = shift;
	my $type = shift;
	
	return if $curr_node->finalized();
	
	my $relabel_children = 0;
	if($type ne $multiple_type_name && $curr_node->waiting_ancestor_type && $type eq $curr_node->waiting_ancestor_type) {
		# Found internal node that has at least one genome that matches ancestor type
		$relabel_children = 1;
	} 
	
	foreach my $child (@{$curr_node->children}) {
		
		if($child->is_leaf && !$child->stx_marker) {
			# Regular assignment
			$child->set_type($type);
			$child->finalized(1) unless $type eq $multiple_type_name;
		} elsif($relabel_children && $child->is_leaf && !$child->is_signpost) {
			$child->set_type($type);
			$child->finalized(1);
		} elsif(!$child->is_leaf) {
			_assignTypes($child, $type);
		}	
	}
	
	$curr_node->set_type($type);
	$curr_node->finalized(1) unless $type eq $multiple_type_name;
}


=head2 perlToNewick

Write given tree object in newick format

Input: StxNode object, filename
Returns: nothing

=cut

sub _perlToNewick {
	my $root = shift;
	my $text_file = shift;
	my $newick_file = shift;
	
	open(my $fh, ">", $text_file) or die "Error: Unable to write to file $text_file ($!)\n";
	open(my $fh2, ">", $newick_file) or die "Error: Unable to write to file $newick_file ($!)\n";
	
	_printNode($root, $fh, $fh2);
	
	close $fh; close $fh2
}

sub _printNode {
	my $node = shift;
	my $fh = shift;
	my $fh2 = shift;
	
	# Print out merged tree
	my @children = @{$node->children};
	if(@children) {
		print $fh2 '(';
		my $num = 1;
		foreach my $child (@children) {
			_printNode($child, $fh, $fh2);
			print $fh2 ',' unless $num == @children;
			$num++;
		}
		print $fh2 ')';
	}
	
	if($node->is_leaf && $node->stx_marker) {
		print $fh2 $node->name . '__' . $node->stx_marker . '__:'.$node->length();
	} elsif($node->is_leaf && !$node->stx_marker) {
		print $fh2 $node->name . '__NA__:'.$node->length();
	}  elsif($node->is_root) {
		#print $fh 'root';
	} else {
		print $fh2 $node->stx_marker . ':' . $node->length();
	}
	
	# Print out target genome types
	if($node->is_leaf && !$node->is_signpost) {
		if($node->stx_marker) {
			print $fh $node->name ."\t".$node->stx_marker."\n";
		} else {
			print $fh $node->name ."\tunassigned\n";
		}
	}
}




1;