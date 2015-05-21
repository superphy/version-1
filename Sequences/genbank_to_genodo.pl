#!/usr/bin/env perl

use strict;
use warnings;
use Bio::SeqIO;
use Getopt::Long;
use Pod::Usage;
use Carp;
use Sys::Hostname;
use Config::Simple;
use POSIX qw(strftime);
use Locale::Country;
use Locale::SubCountry;
use GenodoDateTime;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Config::Simple;
use Data::Dumper;

=head1 NAME

$0 - Extracts and prints relevent information from genbank file used in genodo application

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --prop       File name to dump hash of parent genome properties
 --gb         Genbank file containing all annotations and info for a genome
 --config     INI style config file containing DB connection parameters

=head1 DESCRIPTION

A contig_collection is the parent label used for a set of DNA sequences belonging to a 
single project (which may be a WGS or a completed whole genome sequence). Global properties 
such as strain, host etc are defined at the contig_collection level.  The contig_collection 
properties are defined in a hash that is written to file using Data::Dumper.

The tags used in genbank record are mapped to the tables and cvterms used in Genodo and then
saved in the proper hash format used by genodo_fasta_loader.pl

See genodo_fasta_loader.pl for current set of valid properties.

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

$|=1;

my ($GBFILE, $PROPFILE, $DEBUG, $CONFIG);

GetOptions(
	'gb=s'=> \$GBFILE,
    'prop=s'=> \$PROPFILE,
    'debug' => \$DEBUG,
    'config=s' => \$CONFIG,
) || (pod2usage(-verbose => 1) && exit);


# Connect to DB
croak "Missing argument. You must supply a configuration filename.\n" unless $CONFIG;
my ($dbsource, $dbpass, $dbuser);
if(my $db_conf = new Config::Simple($CONFIG)) {
	my $dbname    = $db_conf->param('db.name');
	$dbuser       = $db_conf->param('db.user');
	$dbpass       = $db_conf->param('db.pass');
	my $dbhost    = $db_conf->param('db.host');
	my $dbport    = $db_conf->param('db.port');
	my $dbi       = $db_conf->param('db.dbi');
	
	$dbsource = 'dbi:' . $dbi . ':dbname=' . $dbname . ';host=' . $dbhost;
	$dbsource . ';port=' . $dbport if $dbport;
	
} else {
	die Config::Simple->error();
}

my $schema = Database::Chado::Schema->connect($dbsource, $dbuser, $dbpass) or croak "Error: could not connect to database.";


## Mapping
## This may change in the future, and should be reviewed periodically

# Genbank tags mapped to genodo cvterm properties

# Priority of tags can be either primary (0) or secondary (1).
# Primary get unshifted on the front resulting in getting assiged a lower rank
# Secondary get pushed on the back and get a higher rank

# Static terms can only be defined once, there is no implicit ranking to multiple values

my %genbank_tags = (
	serotype => {
		cvterm => 'serotype',
		priority => 0
	},
	serovar => {
		cvterm => 'serotype',
		priority => 0
	},
	strain => {
		cvterm => 'strain',
		priority => 0
	},
	sub_strain => {
		cvterm => 'strain',
		priority => 1
	},
	culture_collection => {
		cvterm => 'strain',
		priority => 1
	},
	sub_species => {
		cvterm => 'strain',
		priority => 1
	},
	isolate => {
		cvterm => 'strain',
		priority => 1
	},
	collection_date => {
		cvterm => 'isolation_date',
		priority => 0
	},
	pubmed => {
		cvterm => 'pmid',
		priority => 0,
	},
	direct_submission => {
		cvterm => 'owner',
		priority => 0,
	},
	comment => {
		cvterm => 'comment',
		priority => 0
	},
	note => {
		cvterm => 'comment',
		priority => 1
	},
	keyword => {
		cvterm => 'keywords',
		priority => 0
	},
	mol_type => {
		cvterm => 'mol_type',
		priority => 0, 
		static => 1
	},
	finished => {
		cvterm => 'finished',
		priority => 0,
		static => 1
	},
	description => {
		cvterm => 'description',
		priority => 0,
	},
	secondary_dbxref => {
		cvterm => 'secondary_dbxref',
		priority => 0,
	},
	primary_dbxref => {
		cvterm => 'primary_dbxref',
		priority => 0,
		static => 1
	},
	country => {
		cvterm => 'isolation_location',
		priority => 0,
	},
	host => {
		cvterm => 'isolation_host',
		priority => 0,
	},
	isolation_source => {
		cvterm => 'isolation_source',
		priority => 0,
	},
	syndrome => {
		cvterm => 'syndrome',
		priority => 0,
	},
	name => {
		cvterm => 'name',
		priority => 0,
	},
	uniquename => {
		cvterm => 'uniquename',
		priority => 0,
	}
);

my %genodo_data;
my %discovered_syndromes;

# Countries
my %valid_countries;
map { $valid_countries{$_} = 1 } all_country_names();
map { if(m/,/) { s/, .+$//; $valid_countries{$_}=1 } } all_country_names(); # Drop the 'official gargon' name stuff, like Democratic republic of...

# Species
# Make sure these terms are unique to a host
# Any single occurence of these words will be used to identify host
# Only full words will be matched, cannot be part of a word
my %species_aliases = (
 human_aliases => ['Homo sapiens', 'human', 'patient', 'infant', 'child'],
 pig_aliases => ['Sus scrofa', 'pig', 'Piglet', 'Porcine'],
 cow_aliases => ['Bos taurus', 'cow', 'Calf', 'Bovine', 'Cattle'],
 horse_aliases => ['Equus caballus','horse','foal'],
 chicken_aliases => ['Gallus gallus', 'chicken', 'Hen', 'Rooster', 'Chick'],
 rabbit_aliases => ['Oryctolagus cuniculus', 'rabbit'],
 goat_aliases => ['Capra aegagrus hircus','goat'],
 dog_aliases => ['Canis lupus familiaris','dog'],
 sheep_aliases => ['Ovis aries','sheep'],
 bison_aliases => ['Bison bison', 'buffalo', 'bison'],
 cat_aliases => ['Felis catus', 'cat'],
 onion_aliases => ['Allium cepa', 'common onion'],
 mouse_aliases => ['Mus musculus', 'mouse'],
);

# Convert to giant alias hash
# Saved species names are a concatentation of the first two aliases in each list: the latin name and the common name
my %host_aliases;
foreach my $species_alias_list (values %species_aliases) {
	my $value = $species_alias_list->[0] . ' (' . $species_alias_list->[1] . ')';
	
	foreach my $alias (@$species_alias_list) {
		$host_aliases{$alias} = $value;
	}
}

# Sources
# Make sure these terms are unique to a source
# Any single occurence of these words will be used to identify source
# Only full words will be matched, cannot be part of a word
my %source_alias_lists = (
 Stool => [qw/feces stool diarrhea fecal faeces diarrhoeal/],
 Urine => [qw/urine/],
 Blood => [qw/blood/],
 Milk => [qw/milk/],
 Yolk => [qw/yolk/],
 Colon => [qw/colon/],
 Ileum => [qw/ileum/],
 Cecum => [qw/cecum/],
 Liver => [qw/liver/],
 'Cerebrospinal fluid' => [qw/cerebrospinal/],
 'Meat-based food' => [qw/beef meat hamburger sausage/],
 'Vegetable-based food' => [qw/spinach/],
 'Water' => [qw/water/]
);

my %environmental_sources = (
	'Meat-based food' => 1,
	'Vegetable-based food' => 1,
	'Water' => 1
);

# Convert to giant alias hash
my %source_aliases;
foreach my $source (keys %source_alias_lists) {
	
	foreach my $alias (@{$source_alias_lists{$source}}) {
		$source_aliases{$alias} = $source;
	}
}

# Certain hosts indicate the source
my %host_source_mapping = (
 'Allium cepa' => 'Vegetable-based food'
);

# Keywords indicating certain symptoms
my %symptom_keywords = (
 'Gastroenteritis' => 'Gastroenteritis',
 'Bloody diarrhea' => 'Bloody diarrhea',
 'Haemolytic-uremic' => 'Hemolytic-uremic syndrome',
 'Haemolytic uremic' => 'Hemolytic-uremic syndrome',
 'Hemorrhagic colitis' => 'Hemorrhagic colitis',
 'Hemolytic-uremic' => 'Hemolytic-uremic syndrome',
 'Hemolytic uremic' => 'Hemolytic-uremic syndrome',
 'Haemorrhagic colitis' => 'Hemorrhagic colitis',
 'Urinary tract infection' => 'Urinary tract infection',		
 'Crohn' => 'Crohn\'s Disease',
 'Ulcerateive colitis' => 'Ulcerateive colitis',
 'Pseumonia' => 'Pneumonia',
 'Meningitis' => 'Meningitis',
 'Mastitis' => 'Mastitis',
 'Diarrhea' => 'Diarrhea',
 'Diarrhoeal' => 'Diarrhea',
 'Septicaemia' => 'Septicaemia',
 'Peritonitis'  => 'Peritonitis',
 'Asymptomatic' => 'Asymptomatic',
 'Healthy' => 'Asymptomatic',
 'Pyelonephritis' => 'Pyelonephritis'
);



# Need to construct a master record
# from possibly multiple genbank records

my $io = Bio::SeqIO->new(-file => $GBFILE, -format => "genbank" );

# Some properties will be identical between records
my $seq_obj = $io->next_seq;



my $anno_collection = $seq_obj->annotation;

# References
my @references = $anno_collection->get_Annotations('reference');
	
for my $value ( @references ) {
	
	my $title = $value->title;
	
	# Use direct submission reference to fill in owner cvterm
	if($title =~ m/Direct Submission/i) {
		my $owners = $value->authors . ".  " . $value->location;
		
		saveTag('direct_submission', $owners);
		
	} elsif($value->location =~ m/unpublished/i) {
		warn "***WARNING: ignoring unpublished reference: ".$value->title."\n";
	} else {
		my $pmid = $value->pubmed;
		
		if($pmid) {
			saveTag('pubmed', $pmid);
		} else {
			warn "***WARNING: no pubmed ID for reference: ".$value->title."\n";
		}
	}
}

# Comment
my @comments = $anno_collection->get_Annotations('comment');
my @saved_comments;

for my $value ( @comments ) {
	push @saved_comments, $value->text;
	
	saveTag('comment', $value->text);
	
	my @syndromes = scanForKeywords(\%symptom_keywords, $value->text);
	map {$discovered_syndromes{$_}=1} @syndromes if @syndromes;
}

# Keywords
my $moltype_determined = 0;
for my $value ( $seq_obj->get_keywords ) {
	next unless $value;
	
	if($value =~ m/WGS/i) {
		if(!$moltype_determined) {
			saveTag('mol_type', 'wgs');
			saveTag('finished', 'no');
			$moltype_determined = 1;
		}
		
	} elsif($value =~ m/COMPLETE GENOME/i) {
		if(!$moltype_determined) {
			saveTag('mol_type', 'genome');
			saveTag('finished', 'yes');
			$moltype_determined = 1;
		}
		
	} elsif($value =~ m/DRAFT/i) {
		# Comment on draft quality
		# Save in genome description
		saveTag('description', $value);
		
	} else {
		saveTag('keyword', $value);
	}
}

# DBLinks
my @dblinks = $anno_collection->get_Annotations('dblink');

for my $link ( @dblinks ) {
	saveTag('secondary_dbxref', saveDbxref($link->database, $link->primary_id));
}

# WGS & WGS_SCAFLD
# Currently we ignore these tags
my @source_features = grep { $_->primary_tag eq 'source' } $seq_obj->get_SeqFeatures;

my $feat_obj = $source_features[0]; # There should only be one

# Db_xref
if($feat_obj->has_tag('db_xref')) {
	my @db_xrefs = $feat_obj->get_tag_values('db_xref');
	foreach my $db_xref (@db_xrefs) {
		my ($db, $acc) = ($db_xref =~ m/^(\w+)\:\s*(\w+)$/);
		
		unless($db && $acc) {
			warn "***WARNING: Unrecognized db_xref format: $db_xref\n";
			next;
		}
		saveTag('secondary_dbxref', saveDbxref($db, $acc));
	}
}

# Organism
# Save this in case strain is not defined elsewhere
my $organism;
if($feat_obj->has_tag('organism')) {
	my @orgs = $feat_obj->get_tag_values('organism');
	
	$organism = $orgs[0];
	warn "***WARNING: organism is not Eschericia coli: $organism\n" unless $organism =~ m/Escherichia coli/;
}

# Serotype or serovar
my $serotype;
if($feat_obj->has_tag('serotype') || $feat_obj->has_tag('serovar')) {
	my @types;
	push @types, $feat_obj->get_tag_values('serotype') if $feat_obj->has_tag('serotype');
	push @types, $feat_obj->get_tag_values('serovar') if $feat_obj->has_tag('serovar');
	
	foreach my $v (@types) {
		$v =~ s/\:\s+/\:/;
		$v =~ s/^0(\d+\:H|\d+\:N)/O$1/;
		saveTag('serotype', $v);
	}
	$serotype = $types[0];
	
	warn "***WARNING: no serotype defined.\n" unless @types;
}

# Strain and associated terms
my $strain;
if($feat_obj->has_tag('strain') || 
	$feat_obj->has_tag('culture_collection') ||
	$feat_obj->has_tag('isolate') ||
	$feat_obj->has_tag('sub_strain') ||
	$feat_obj->has_tag('sub_species')
) {
	my @types;
	# Order matters here
	push @types, $feat_obj->get_tag_values('strain') if $feat_obj->has_tag('strain');
	push @types, $feat_obj->get_tag_values('sub_species') if $feat_obj->has_tag('sub_species');
	push @types, $feat_obj->get_tag_values('sub_strain') if $feat_obj->has_tag('sub_strain');
	push @types, $feat_obj->get_tag_values('culture_collection') if $feat_obj->has_tag('culture_collection');
	push @types, $feat_obj->get_tag_values('isolate') if $feat_obj->has_tag('isolate');
	
	unless(@types) {
		warn "***WARNING: no strain defined.\n" unless @types;
	} else {
		# I just save them under a common umbrella term strain with different ranks
		foreach my $v (@types) {
			saveTag('strain', $v);
		}
		$strain = $types[0];
	}
}

# Note
if($feat_obj->has_tag('note')) {
	my @vals = $feat_obj->get_tag_values('note');
	
	foreach my $v (@vals) {
		push @saved_comments, $v;
		
		saveTag('note', $v);
		
		my @syndromes = scanForKeywords(\%symptom_keywords, $v);
		map {$discovered_syndromes{$_}=1} @syndromes if @syndromes;
	}
}

# Collection Date
if($feat_obj->has_tag('collection_date')) {
	my @vals = $feat_obj->get_tag_values('collection_date');
	
	foreach my $v (@vals) {
		my $datetime = Sequences::GenodoDateTime->parse_datetime($v);
		unless($datetime) {
			warn "***WARNING: unrecognized collection date format $v";
			next;
		}
		warn "***WARNING: collection date is in the futuer" unless Sequences::GenodoDateTime::beforeToday($datetime);
		
		saveTag('collection_date', $datetime->date);
	}
}

# Country
# This is a real crap-hole, need to do lots of guessing to try and pull out country, state and city
if($feat_obj->has_tag('country')) {
	my @vals = $feat_obj->get_tag_values('country');
	
	foreach my $v (@vals) {
		saveTag('country', guessLocation($v));
	}
}

# Source and host
my $source; my $host;
if($feat_obj->has_tag('isolation_source')) {
	my @vals = $feat_obj->get_tag_values('isolation_source');
	
	warn "***WARNING: more than one isolation source. Using first.\n" if @vals > 1;
	$source = $vals[0];
	
	# sometimes symptoms and diseases are hidden in the source field
	my @syndromes = scanForKeywords(\%symptom_keywords, $source);
	map {$discovered_syndromes{$_}=1} @syndromes if @syndromes;
}
if($feat_obj->has_tag('host')) {
	my @vals = $feat_obj->get_tag_values('host');
	
	warn "***WARNING: more than one host. Using first.\n" if @vals > 1;
	$host = $vals[0];
	
	# sometimes symptoms and diseases are hidden in the host field
	my @syndromes = scanForKeywords(\%symptom_keywords, $host);
	map {$discovered_syndromes{$_}=1} @syndromes if @syndromes;
}

my ($verified_host, $verified_source) = guessHostSource(host => $host, source => $source, notes => \@saved_comments);

if($verified_host) {
	saveTag('host', $verified_host);
} else {
	warn "***WARNING: No host defined.\n"
}

if($verified_source) {
	saveTag('isolation_source', $verified_source);
} else {
	warn "***WARNING: No source defined.\n"
}

# Mol_type
# They should all be genomic dna, thats the whole game here so don't bother storing it.
if($feat_obj->has_tag('mol_type')) {
	my @vals = $feat_obj->get_tag_values('mol_type');
	
	warn "***WARNING: Unexpected molecular type $vals[0] (expected: genomic DNA).\n" unless $vals[0] =~ m/genomic dna/i;
}

# Come up with uniquename
# SOURCE ORGANISM
# Use to create names for genome
my $current_name;
my $species_string = $seq_obj->species->node_name;

if($species_string =~ m/Escherichia coli (.+)$/) {
        $current_name = $1;

        $current_name =~ s/,(\S)/ $1/g; # replace comma with space
        $current_name =~ s/,(\s)/$1/g; # maintain space
        $current_name =~ s/'//g;
        $current_name =~ s/str/Str/;

} elsif($species_string =~ m/^Escherichia coli$/) {
        # No unique name after Ecoli
	# Create one
	croak "Error: insufficient information to uniquely name genome. No strain or full organism name." unless $strain;
	$current_name = $strain;
	$current_name = $serotype . ' Str. '. $current_name if $serotype;

} else {
    croak "Error: species tag missing or species is not Escherichia coli.\n";
}


# Save syndromes
# Remove compound keywords
delete $discovered_syndromes{'Diarrhea'} if $discovered_syndromes{'Bloody diarrhea'};
foreach my $s (keys %discovered_syndromes) {
	saveTag('syndrome',$s);
}

# Determine if chromosome or plasmid
my $is_plasmid = 0;
if($feat_obj->has_tag('plasmid') || $seq_obj->desc =~ m/plasmid/) {
	$is_plasmid = 1;
}

# Description
if($seq_obj->desc) {
	my $desc = $seq_obj->desc;
	
	if(!$moltype_determined && $desc =~ m/whole genome shotgun sequencing/i) {
		
		saveTag('mol_type', 'wgs');
		saveTag('finished', 'no');
		$moltype_determined=1;
		
	} elsif(!$moltype_determined && $desc =~ m/complete genome/i) {
		
		saveTag('mol_type', 'genome');
		saveTag('finished', 'yes');
		$moltype_determined=1;
	}
	
	# Save the chromosome description
	if(!$is_plasmid) {
		saveTag('description', $desc);
	}
}


# Accession
my %prim_accessions;

if(!$is_plasmid) {
	# Save the chromosome accession as the Primary
	$prim_accessions{$seq_obj->accession} = $seq_obj->seq_version
} else {
	# Save the plasmid accession as a secondary
	saveTag('secondary_dbxref', saveDbxref('genbank', $seq_obj->accession, $seq_obj->seq_version, 'plasmid'));
}

# Check other sequences
while(my $seq_obj = $io->next_seq) {
	
	# Grab the source features for this sequence
	@source_features = grep { $_->primary_tag eq 'source' } $seq_obj->get_SeqFeatures;
	$feat_obj = $source_features[0]; # There should only be one
		
	# Determine if chromosome or plasmid
	$is_plasmid = 0;
	
	if($feat_obj->has_tag('plasmid') || $seq_obj->desc =~ m/plasmid/) {
		$is_plasmid = 1;
	}
	
	# Description
	if($seq_obj->desc) {
		my $desc = $seq_obj->desc;
		
		if(!$moltype_determined && $desc =~ m/whole genome shotgun sequencing/i) {
			
			saveTag('mol_type', 'wgs');
			saveTag('finished', 'no');
			$moltype_determined=1;
			
		} elsif(!$moltype_determined && $desc =~ m/complete genome/i) {
			
			saveTag('mol_type', 'genome');
			saveTag('finished', 'yes');
			$moltype_determined=1;
		}
		
		# Save the chromosome description
		if(!$is_plasmid) {
			saveTag('description', $desc);
		}
	}
	
	
	# Accession
	if(!$is_plasmid) {
		# Save the chromosome accession as the Primary
		$prim_accessions{$seq_obj->accession} = $seq_obj->seq_version
	} else {
		# Save the plasmid accession as a secondary
		saveTag('secondary_dbxref', saveDbxref('genbank', $seq_obj->accession, $seq_obj->seq_version, 'plasmid'));
	}
}

# Save primary ID
my @accs = sort keys %prim_accessions;
croak "Error: no primary accession found." unless @accs;
warn "***WARNING: multiple chromosome accessions. Using the alphanumerically lowest as the primary ID." if @accs > 1;
	
saveTag('primary_dbxref', saveDbxref('genbank', $accs[0], $prim_accessions{$accs[0]}));

my $primary_accession = $accs[0];

# Decide upon final name
# Make sure it is unique, if not append the primary ID accession

my $public_row = $schema->resultset('Feature')->find({ uniquename => $current_name});
my $private_row = $schema->resultset('PrivateFeature')->find({ uniquename => $current_name});

if($public_row || $private_row) {
	$current_name .= " ($primary_accession)";
}

$public_row = $schema->resultset('Feature')->find({ uniquename => $current_name});
$private_row = $schema->resultset('PrivateFeature')->find({ uniquename => $current_name});

croak "Error: unable to create uniquename." if $public_row || $private_row;

saveTag('name', $current_name);
saveTag('uniquename', $current_name);

# Write out properties file
open(OUT,">$PROPFILE") or croak "Error: unable to write data to file $PROPFILE ($!).\n";
print OUT Data::Dumper->Dump([\%genodo_data], ['contig_collection_properties']);
close OUT;


###############
## Subs
###############

=head2 saveTag

Save in final data hash using genbank tag to cvterm mapping

=cut
sub saveTag {
	my ($genbank_tag, $value) = @_;
	
	my $cvterm = $genbank_tags{$genbank_tag}{cvterm};
	croak "Unrecognized genbank tag $genbank_tag\n" unless defined $cvterm;
	
	if(defined $genodo_data{$cvterm}) {
		croak "Attempt to redefine static cvterm: $cvterm (corresponding genbank tag: $genbank_tag)." if
			$genbank_tags{$genbank_tag}{static};
	} else {
		$genodo_data{$cvterm} = [];
	}
	
	if($genbank_tags{$genbank_tag}{priority} == 0) {
		unshift @{$genodo_data{$cvterm}}, $value;
	} else {
		push @{$genodo_data{$cvterm}}, $value;
	}
	
	if($DEBUG) {
		if(ref $value) {
			my @strs = map { $_ . ":" . $value->{$_} } keys(%$value);
			print "CVTERM: ".$cvterm.", VALUE: ".join(', ', @strs),"\n";
		} else {
			print "CVTERM: ".$cvterm.", VALUE: $value\n";
		}
	}
}

=head2 saveDbxref

Save sdbxref in proper format

=cut
sub saveDbxref {
	my ($db, $acc, $ver, $desc) = @_;
	
	$db = 'BioProject' if $db eq 'Project';
	
	$ver = '' unless defined $ver;
	
	my $dbref = {
		db => $db,
		acc => $acc,
		ver => $ver
	};
	
	$dbref->{desc} = $desc if $desc;
		
	return $dbref;
}

=head2 guessLocation

Try to parse a free-text field containing possibly
country, state and city in no particular format

=cut
sub guessLocation {
	my ($country_line) = @_;
	
	# Massage the text a bit
	$country_line =~ s/^USA/United States/;
	$country_line =~ s/\s+USA/ United States/;
	$country_line =~ s/Republic of the //;
	$country_line =~ s/GUYANA\: DUTCH GUIANA/Suriname/i; # Really only deals with one case
	
	
	my ($country, $state, $city);
	
	if($country_line =~ m/^[\w\-\s]+$/) {
		# Single word, probably a country
		# Check against our somewhat complete list of countries
		
		$country = $country_line;
		
		unless($valid_countries{$country}) {
			warn "***WARNING: unrecognized country in location $country_line\n";
		}
	} elsif($country_line =~ m/^([\w\-\s]+)\:\s*([\w\-\s]+)$/) {
		# Two words separated by a colon, probably a country and state
		# but a country and city occurs quite often too
		
		$country = $1;
		$state = $2;
		
		unless($valid_countries{$country}) {
			warn "***WARNING: unrecognized country in location $country_line\n";
		} else {
			my $subcountry = new Locale::SubCountry($country);
			
			if($subcountry && $subcountry->has_sub_countries) {
				
				my %states_keyed_by_code  = $subcountry->code_full_name_hash;
	            my %states_keyed_by_name  = $subcountry->full_name_code_hash;
	            
	            if($states_keyed_by_code{$state}) {
	            	# Get full name
	            	$state = $subcountry->full_name($state);
	            } elsif(!$states_keyed_by_name{$state}) {
	            	$city = $state;
	            	$state = undef;
	            	warn "***WARNING: unrecognized state $city, assuming it is a city.";
	            }
			} else {
				warn "***WARNING: no known states for country $country. Cannot verify correctness of state $state.\n" 
			}
			
		}
		
	} elsif($country_line =~ m/^([\w\-\s]+)\:\s*([\w\-\s\.\,]+),\s*([\w\-\s]+)$/) {
		# Three words separated by a colon and comma, probably a country: city,state
		
		$country = $1;
		$state = $2;
		$city = $3;
		
		unless($valid_countries{$country}) {
			warn "***WARNING: unrecognized country in location $country_line\n";
		} else {
			my $subcountry = new Locale::SubCountry($country);
			
			if($subcountry && $subcountry->has_sub_countries) {
				
				my %states_keyed_by_code  = $subcountry->code_full_name_hash;
	            my %states_keyed_by_name  = $subcountry->full_name_code_hash;
	            
	            if($states_keyed_by_code{$state}) {
	            	# Get full name
	            	$state = $subcountry->full_name($state);
	            } elsif(!$states_keyed_by_name{$state}) {
	            	warn "***WARNING: unrecognized state $state.";
	            }
			} else {
				warn "***WARNING: no known states for country $country. Cannot verify correctness of state $state or city $city.\n" 
			}
		}
	} else {
		croak "Error: unrecognized location format in '$country_line'.\n";
	}
	
	# Location: country, state, city should be populated now
	# Create location xml
	my $locale_xml = qq|<location><country>$country</country>|;
	
	$locale_xml .= qq|<state>$state</state>| if $state;
	$locale_xml .= qq|<city>$city</city>| if $city;
	$locale_xml .= q|</location>|;
	
	return $locale_xml;
}

=head2 guessHostSource

Try to parse a free-text fields host and source which are
sometimes used interchangeably.

Synonym nightmare

=cut

sub guessHostSource {
	my %args = @_;
	
	my $host = $args{host};
	my $source = $args{source};
	my $notes = $args{notes};
	
	my $final_host;
	my $final_source;
	
	# Host
	if($host) {
		# Recognized host
		unless($final_host = scanForAliases(\%host_aliases, $host)) {
			warn "***WARNING: Unrecognized host $host. Using the value as-is.\n";
			$final_host = $host;
		}
	} else {
		# Try to guess host from source
		if($source) {
			if($final_host = scanForAliases(\%host_aliases, $source)) {
				warn "***WARNING: No host tag, used isolation_source to guess host. Host $final_host pulled from source: $source.\n";
			}
		}
	}
	
	# Source
	my $no_source = 0;
	if($source) {
		# Recognized source
		unless($final_source = scanForAliases(\%source_aliases, $source)) {
			
			if(matchAliases(\%host_aliases, $source)) {
				# Try to alleviate some obvious host source confusion.
				# This only identifies the most obvious cases where source is a single host word.
				# We ignore cases where hosts words are found in a longer sentence, which may contain
				# other useful source info and are therefore saved as is.
				warn "***WARNING: Source $source field was used to identify host. Ignoring source value.\n";
				$no_source = 1;
			} else {
				warn "***WARNING: Unrecognized source $source. Using the value as-is.\n";
				$final_source = $source;
			}
			
		}
	} else {
		$no_source = 1;
	}
	
	if($no_source) {
		# Try to guess source from host
		if($final_host) {
			if($final_source = $host_source_mapping{$final_host}) {
				warn "***WARNING: No isolation_source tag, used host to guess source. Host $final_source predicted from host: $final_host.\n";
			}
		}
		# If guessing the source from the host was not successful, scan the notes and comments for keywords
		unless($final_source) {
			foreach my $note (@$notes) {
				if($final_source = scanForAliases(\%source_aliases, $note)) {
					# Found it;
					last;
				}
			}
		}
		
	}
	
	# Food and animal can be a fuzzy line
	# Classify source words beef, meat as Meat-based food, unless an animal host is defined
	# Then classify as meat
	
	# Also label environmental source hosts
	
	if($final_source && $final_host) {
		if($final_source eq 'Meat-based food') {
			$final_source = 'Meat';
		}
	} elsif($final_source && !$final_host) {
		if($environmental_sources{$final_source}) {
			$final_host = 'Environmental source';
		}
	}
		
	return($final_host, $final_source);
	
}

# Look for the first unique match
# Whole words must match (pig cannot be part of a larger word)
sub scanForAliases {
	my ($aliases, $value) = @_;
	
	foreach my $key (keys %$aliases) {
		
		if($value =~ m/\b\Q$key\E\b/i) {
			return($aliases->{$key});
		}
	}
	return(undef);
}

# Look for the first unique match
# The entire strings must be identical (case-insensitive)
sub matchAliases {
	my ($aliases, $value) = @_;
	
	foreach my $key (keys %$aliases) {
		
		if(uc($value) eq uc($key)) {
			return($aliases->{$key});
		}
	}
	return(undef);
}

# Return all matches
# Whole words must match (pig cannot be part of a larger word)
sub scanForKeywords {
	my ($aliases, $value) = @_;
	
	my @keywords;
	
	foreach my $key (keys %$aliases) {
		
		if($value =~ m/\b\Q$key\E\b/i) {
			# Possible hit
			
			if($key =~ m/Chron/i && $value =~ m/Effect of Crohn/i) {
				# This is the name of grant, which we need to avoid
				warn "***WARNING: detected keyword not indicating presence of syndrome: $value.\n";
				next;
			} elsif($key =~ m/Hemolytic/i && $value =~ m/Laboratory for/i) {
				# This is the name of lab, which we need to avoid
				warn "***WARNING: detected keyword not indicating presence of syndrome: $value.\n";
				next;
			}
			
			push @keywords, $aliases->{$key};
		}
	}
	return(@keywords);
}

