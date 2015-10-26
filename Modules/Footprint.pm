#!/usr/bin/env perl

=pod

=head1 NAME

Modules::Footprint - identifying duplicate genome sequences

=head1 DESCRIPTION

This module provides functions to digest genome sequences into easily comparable checksums
and to identify duplicate genomes being uploaded to the system.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.html

=head1 AUTHOR

Matthew WHiteside (matthew.whiteside at phac.aspc.gc.ca)

=cut

package Modules::Footprint;

use strict;
use warnings;
use Digest::MD5;
use Bio::SeqIO;
use Log::Log4perl qw/get_logger :easy/;


=head2 constructor

=cut
sub new {
	my ($class) = shift;
	my $self = {};
	bless( $self, $class );
	$self->_initialize(@_);
	
	return $self;
}

sub _initialize {
	my $self = shift;

	# Logging
	unless(Log::Log4perl->initialized()) {
		Log::Log4perl->easy_init($DEBUG);
    }
    $self->logger(Log::Log4perl->get_logger()); 

    $self->logger->info("Logger initialized in Modules::Footprint");  

    my %params = @_;

    # Initialize parameters
    foreach my $key(keys %params){
    	if($self->can($key)){
    		$self->$key($params{$key});
    	}
    	else{
            $self->logger->logconfess("$key is not a valid parameter in Modules::Footprint");
        }
    }
    
}

=head2 logger

Stores a logger object for the module.

=cut

sub logger {
	my $self=shift;
	$self->{'_logger'} = shift // return $self->{'_logger'};
}

=head2 dbh

A pointer to the DBI database handle object

=cut

sub dbh {
	my $self = shift;
	
	$self->{dbh} = shift // return $self->{dbh};
}

=head2 digest

Convert array of contig sequences to checksum

=cut

sub digest {
	my $self = shift;
	my $contigs = shift;

	my @tmp = sort { 
		length($a) <=> length($b) ||
		$a cmp $b
	} @$contigs;

	my $contig_checksum = Digest::MD5->new;

	foreach my $contig (@tmp) {
		$contig_checksum->add($contig);
	}

 	my $digest = $contig_checksum->hexdigest;

 	return $digest;
}

=head2 digestFile

Convert fasta file of contig sequences to checksum

=cut

sub digestFile {
	my $self = shift;
	my $fasta_file = shift;

	my $fasta = Bio::SeqIO->new(-file   => $fasta_file, -format => 'fasta') 
		or $self->logger->logconfess("Unable to open Bio::SeqIO stream to $fasta_file ($!).");

	my @contigs;
	while(my $entry = $fasta->next_seq()) {
		my $seq = $entry->seq;

		push @contigs, $seq;
	}

	return $self->digest(\@contigs);
}

=head2 validateFootprint
	
Checks for genomes with identical checksum values in same visible space (i.e. not private to different users).

Returns array of all genomes with identical checksums using notation (public_12334, upl_4, etc., Note:
upl_* refers to the upload ID assiged to the user-submitted genome. There may not be a feature ID
assigned yet).

=cut

sub validateFootprint {
    my ($self, %args) = @_;

    my $privacy_setting = $args{privacy};
    unless($privacy_setting && 
    	($privacy_setting eq 'public' || $privacy_setting eq 'private' || $privacy_setting eq 'release')) {
    	die "Error: invalid parameter 'privacy'";
    }

    my $footprint = $args{footprint};
    unless($footprint) {
    	die "Error: invalid parameter 'footprint'";
    }

    unless($self->dbh) {
    	die "Error: dbh not initialized in constructor.";
    }

    my $user_id = $args{user_id};
    my $username = $args{username};
   
    if($username) {
    	($user_id) = $self->dbh->selectrow_array("SELECT login_id FROM login WHERE username = '$username'");
    }
    die "Error: missing/invalid user info. Must provide parameter 'user_id' or 'username'" unless $user_id && $user_id =~ m/^\d+$/;

    my @duplicates;

	# Search public table for identical footprint genomes
	my $sql1 = "SELECT feature_id FROM contig_footprint WHERE footprint = ?";
	my $sth1 = $self->dbh->prepare($sql1);
	$sth1->execute($footprint);
	my @public_footprints;

	while(my ($feature_id) = $sth1->fetchrow_array()) {
		# This contig collection has an identical footprint
		# Could be identical, need to compare sequences

		push @public_footprints, $feature_id;
	}

	@duplicates = map { 'public_'.$_ } @public_footprints;

	return @duplicates if @duplicates;

	# Search private table for identical footprint genomes
	my $sql3 = "SELECT upload_id, access_category FROM tracker WHERE failed = FALSE AND footprint = ?;";
	my $sth3 = $self->dbh->prepare($sql3);
	$sth3->execute($footprint);

	# Check if private genomes are assigned to separate users (and can co-exist)
	my $sql4 = "SELECT permission_id FROM permission WHERE login_id = ? and upload_id = ?;";
	my $sth4 = $self->dbh->prepare($sql4);
	
	my @private_footprints;

	while(my ($upload_id, $access_category) = $sth3->fetchrow_array()) {
		# This contig collection has an identical footprint
		# Could be identical, need to compare sequences

		push @private_footprints, [$upload_id, $access_category];
	}

	if(@private_footprints) {
		# Need to dig deeper to determine if genomes are in same visible space
		# User cannot upload any genome that is identical to public/visible genome
		
		foreach my $set (@private_footprints) {

			my ($upload_id, $access_category) = @$set;

			my $dup = 0;
			if($privacy_setting eq 'private' && $access_category eq 'private') {

				# Check if private genome is visible to this user
				$sth4->execute($user_id, $upload_id);
				my ($perm_id) = $sth4->fetchrow_array();

			    if($perm_id) {
			    	# Genome is not in separate access space, hence clash and duplicate
			    	push @duplicates, "upl_$upload_id";
			    }
				
				
			} else {
				# One of duplicate uploads is in public space
				push @duplicates, "upl_$upload_id";
			}
		}
	}

	return @duplicates;
}

=head2 loadPublicFootprints
	
Computes checksums for all genome features in feature table and loads
them into the contig_footprint table.

=cut

sub loadPublicFootprints {
    my ($self) = @_;

    # Retrieve ontology terms
    my ($collection_term_id) = $self->dbh->selectrow_array("SELECT cvterm_id FROM cvterm WHERE name = 'contig_collection'");
    my ($contig_term_id) = $self->dbh->selectrow_array("SELECT cvterm_id FROM cvterm WHERE name = 'contig'");
    my ($partof_term_id) = $self->dbh->selectrow_array("SELECT cvterm_id FROM cvterm t, cv v WHERE t.name = 'part_of' AND  v.name = 'relationship' AND t.cv_id = v.cv_id");

	# Iterate through collections
	my $sth1 = $self->dbh->prepare("SELECT feature_id FROM feature WHERE type_id = ?");
	my $sql = "SELECT f.residues FROM feature f, feature_relationship r " .
		"WHERE r.type_id = ? AND r.object_id = ? AND r.subject_id = f.feature_id AND f.type_id = ?";
	my $sth2 = $self->dbh->prepare($sql);
	my $insert_sth = $self->dbh->prepare("INSERT INTO contig_footprint (feature_id, footprint) VALUES (?,?)");
	my $update_sth = $self->dbh->prepare("UPDATE contig_footprint SET footprint = ? WHERE feature_id = ?");
	my $search_sth = $self->dbh->prepare("SELECT count(*) FROM contig_footprint WHERE feature_id = ?");

	$sth1->execute($collection_term_id);

	while(my $feature_row = $sth1->fetchrow_arrayref) {
		my $genome_id = $feature_row->[0];

		# Iterate through contigs
		my @contigs;
		$sth2->execute($partof_term_id, $genome_id, $contig_term_id);

		while(my $feature_row = $sth2->fetchrow_arrayref) {
			my $contig_seq = $feature_row->[0];
			push @contigs, $contig_seq;
		}

		# Compute and load checksum
		my $checksum = $self->digest(\@contigs);
		
		$search_sth->execute($genome_id);
		my ($exists) = $search_sth->fetchrow_array;
		if($exists) {
			$update_sth->execute($checksum, $genome_id);
		} else {
			$insert_sth->execute($genome_id, $checksum);
		}

	}

	$self->dbh->commit unless $self->dbh->{AutoCommit};

}


1;
