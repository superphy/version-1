#!/usr/bin/env perl

=pod

=head1 NAME

Meta::bulk_add_to_queue.pl

=head1 SYNOPSIS

bulk_add_to_queue.pl --genomes file --config configfile

=head1 OPTIONS

  --config            Superphy config file containing DB connection parameters and dir.seq directory parameter for incoming genome files
  --genomes           A tab-delim file with 3 columns containing: genome_name, fasta_file, genome_metadata_file

=head1 DESCRIPTION

Iterates through genomes in the list provided by --genomes file argument, adding each genome into the Superphy loading queue. Performs
two basic validations 1) genome_name in file is unique 2) the MD5 checksum of the genome sequence is unique.  Assumes genome meta-data
is coming from a source such as the Miner.pm module and is valid.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/../';
use Data::Bridge;
use Modules::Footprint;
use Bio::SeqIO;
use Config::Tiny;
use File::Spec;
use Config::Simple;

# Scans command-line for DB connection parameters
my $data = Data::Bridge->new();

# Parse command-line arguments
my ($genome_file, $MANPAGE, $DEBUG);
print GetOptions(
    'genomes=s' => \$genome_file,
    'manual'    => \$MANPAGE,
    'debug'     => \$DEBUG,
) or pod2usage(-verbose => 1, -exitval => -1);

pod2usage(-verbose => 1, -exitval => 1) if $MANPAGE;

die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --genomes.") unless $genome_file;
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: invalid argument: --genomes. Must specify file.") unless -f $genome_file;

# Create Footprint object for generating fasta MD5 checksums
my $fp = Modules::Footprint->new(dbh => $data->dbh);

# Retrieve directory for upload config files
my $config_file = File::Spec->rel2abs($data->configFile);
my $inbox = readConfig($config_file);

# Iterate through genomes adding each to queue
open(my $in, '<', $genome_file) or die "Error: unable to read file $genome_file ($!).\n";

while(my $row = <$in>) {
	chomp $row;
	my ($genome_name, $fasta_file, $meta_file) = split(/\t/, $row);

	die "Error: invalid format on line $row. Missing genome_name\n" unless $genome_name;
	die "Error: invalid format on line $row. Missing/invalid fasta_file\n" unless $fasta_file && -f $fasta_file;
	die "Error: invalid format on line $row. Missing/invalid metadata file\n" unless $meta_file && -f $meta_file;

	my $upload_data = validate($genome_name, $fasta_file, $meta_file);
	die "Error encountered for genome $genome_name" unless $upload_data;

	# Insert into tracker table (i.e. queue)
	insert($upload_data);

}

close $in;


#########
## SUBS
#########

# Validate sequence and name
# Returns hashref of upload_data on success
sub validate {
	my ($genome_name, $fasta_file, $meta_file) = @_;

	# Record data needed for tracker table
	my %upload_data;

	# Load genome metadata and upload parameters
	my ($meta_data, $upload_parameters) = load_parameters($meta_file);
	unless(defined $meta_data && defined $upload_parameters) {
		warn "Invalid metadata file for genome $genome_name";
		return 0 
	}

	# Validate uniquename
	my $uname = $meta_data->{uniquename};
	unless($uname && length($uname) < 255 && length($uname) > 4) {
		warn "Missing/invalid uniquename $uname for genome $genome_name";
		return 0 
	}
	
	unless(genomename_does_not_exist($uname)) {
		warn "Duplicate uniquename $uname for genome $genome_name";
		return 0
	}
	$upload_data{feature_name} = $uname; 

	
	# Lookup username
	unless($upload_parameters->{login_id}) {
		warn "No login_id parameter defined for genome $genome_name in metadata file";
		return 0;
	}
	my $login_row = $data->dbixSchema->resultset('Login')->find($upload_parameters->{login_id});
	unless($login_row) {
		warn "Unknown login_id ".$upload_parameters->{login_id}."\n";
		return 0;
	}
	my $username = $login_row->username;
	$upload_data{login_id} = $login_row->login_id;

	# Lookup access category
	my $access = $upload_parameters->{category};
	unless($access && ($access eq 'private' || $access eq 'public')) {
		warn "Missing/invalid access category parameter for genome $genome_name in metadata file";
		return 0;
	}
	$upload_data{access_category} = $access;

	# Validate sequence
	my $footprint = valid_fasta_file($fasta_file, $username, $access);
	return 0 unless $footprint;
	$upload_data{footprint} = $footprint;

	return \%upload_data;
}

# Load genome meta-data and upload properties
sub load_parameters {
	my $file = shift;
	
	open(IN, "<$file") or die "Error: unable to read file $file ($!).\n";

    local($/) = "";
    my($str) = <IN>;
    
    close IN;
    
    my $contig_collection_properties;
    my $upload_parameters;
    eval $str;

    return ($contig_collection_properties, $upload_parameters);
}

# Check if genome name is unique.
sub genomename_does_not_exist {
	my ( $gname ) = @_;

	my $pub_rv = $data->dbixSchema->resultset('Feature')->find( { uniquename => $gname } );
	my $pri_rv = $data->dbixSchema->resultset('PrivateFeature')->find( { uniquename => $gname } );
	
	my $exists = defined($pub_rv) || defined($pri_rv);

	return ( !$exists );
}


# Check if fasta file is valid
sub valid_fasta_file {
	my ($file, $username, $access) = @_;

	open(my $fasta_handle, '<', $file) or die "Error: unable to read file $file ($!).\n";
	
	my $seqio;
	my $total_length = 0;
	my $too_short = 3500000;
	my $too_long = 7500000;
	my $too_many_contigs = 10000;
	my @contigs;

	eval {
			
		my $seqio = Bio::SeqIO->new(-fh => $fasta_handle, -format => 'fasta');
		my $num_contigs = 0;
		
		while(my $seq = $seqio->next_seq) {
			$total_length += $seq->length;
			# Check if nucleotide sequence (allow any IUPAC symbols)
			unless($seq->seq =~ m/^[ACGTUNXRYSWKMBDHVacgtunxryswkmbdhv\.-]+$/) {
					
				if($seq->seq =~ m/([^ACGTUNXRYSWKMBDHVacgtunxryswkmbdhv\.-])/) {
					my $message = "DNA sequence " . $seq->display_id . " contains invalid nucleotide characters: ".$1;
					warn($message);
				}
					
				return;
			}
				
			$num_contigs++;
			push @contigs, $seq->seq;
				
			if($num_contigs > $too_many_contigs) {
				my $message = "Detected over $too_many_contigs sequences in FASTA file. Only assembled genomes can be submitted";
				warn($message);
					
				return;
			}
		}
	};
	if($@) {
		warn("Error reading fasta file:\n$@\n");
		return();
	}
			
	if($total_length < $too_short) {
		my $message = "Sequence too short (total length: $total_length). Only whole genome sequences can be submitted\n";
		warn($message);
			
		return;
	}

	if($total_length > $too_long) {
		my $message = "Genome sequence too long (total length: $total_length). Only assembled genomes can be submitted";
		warn($message);
					
		return;
	}

	# Make sure no dublicates
	my $footprint = $fp->digest(\@contigs);
		
	my @dups = $fp->validateFootprint(username => $username, footprint => $footprint, privacy => $access);
		
	if(@dups) {
		my $message = "Duplicate of genome currently in database";
		$message .= '. Genome is duplicate of '.join(', ', @dups);
		warn($message);
	
		return;
	}

	close $fasta_handle;
	
	return($footprint);
}

# Insert into tracker table
# Create upload config file 
sub insert {
	my ($upload_data, $fasta_file, $meta_file) = @_;

	# Retrieve inbox directory from 

	my $login_id = $upload_data->{login_id};
	my $feature_name = $upload_data->{feature_name};
	my $access = $upload_data->{access_category};
	my $footprint = $upload_data->{footprint};

	my $tracking_row = $data->dbixSchema->resultset('Tracker')->create({ login_id => $login_id, step => 0});
	my $tracking_id = $tracking_row->tracker_id;

	# Save arguments to main config file
	my $optFile = $inbox . "genodo-options-$tracking_id.cfg";


	my $opt = new Config::Simple(syntax => 'ini') or die "Cannot create config object " . Config::Simple->error();
	
	# Save all options in config file
	$opt->param(
		-block => 'load', 
		-values => {
			'fastafile'    => File::Spec->rel2abs($fasta_file),
			'propfile'     => File::Spec->rel2abs($meta_file),
			'configfile'   => $config_file
			#'addon_args'   => '--save_tmpfiles --debug'
		}
	);
	$opt->param(
		-block => 'main',
		-values => {
			'tracking_id'  => $tracking_id
		}
	);
	$opt->write($optFile);

	$tracking_row->feature_name($feature_name);
	$tracking_row->access_category($access);
	$tracking_row->footprint($footprint);
	$tracking_row->step(1); # Step 1 complete
	$tracking_row->update;
}


# Retrieve inbox directory parameter from Superphy config file
sub readConfig {
	my ($config) = @_;

	my ($inboxdir);

	my $conf;
	unless($conf = Config::Tiny->read($config)) {
		die "Config Error: $Config::Tiny::errstr\n";
	}

	if($conf->{dir}->{seq}) {
		$inboxdir = $conf->{dir}->{seq}
	}
	else {
		die "Error: missing config file parameter: dir.seq"
	}
	

	return ($inboxdir);
}