#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Time::HiRes qw/gettimeofday/;
use FindBin;
use lib "$FindBin::Bin/../";
use Log::Log4perl qw(:easy);
use Carp;
use File::Temp qw(tempdir);
use Data::Bridge;
use DBI;
use JSON::MaybeXS;
use Bio::SeqIO;
use IO::CaptureOutput qw(capture_exec);

=head1 NAME

$0 - Deletes and reloads the all snp tables

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config          INI style config file containing DB connection parameters
 
=head1 DESCRIPTION

Rebuilds data in tables snp_core, snp_variation, snp_position, gap_position

Backups are created for each table. You will need to drop these manually when safe to do so.  
Make sure you do.

Follow up with rebuild_snp_alignment.pl and rebuild_snp_trees.pl

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2016

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# Globals
my ($workdir, $test, $backup, $muscle_exe, $root_dir);

# Set to muscle executable path
$muscle_exe = 'muscle';

# Set to writable work directory
# A unique tmp dir will be created under this
# that will be deleted at the end of program
$root_dir = '/tmp/';


# Initialize logger
Log::Log4perl->easy_init($DEBUG);
	

# Connect to database (looks for --config option)
my $db_bridge = Data::Bridge->new();
my $schema = $db_bridge->dbixSchema();
my $dbh = $db_bridge->dbh();

$dbh->{AutoCommit} = 0;  # Enable transactions
$dbh->{RaiseError} = 1;


# Primary Key IDs
my $snp_pos_pkey_id = 1;
my $gap_pos_pkey_id = 1;
my $snp_cor_pkey_id = 1;
my $snp_var_pkey_id = 1;


# File handles for table input
my $snp_pos_fh;
my $gap_pos_fh;
my $snp_cor_fh;
my $snp_var_fh;
my $work_dir = tempdir('genodo_repair_XXXX', DIR => $root_dir, CLEANUP => 0 );
my $gap_pos_file = "$work_dir/gap_positions.txt";
my $snp_pos_file = "$work_dir/snp_positions.txt";
my $snp_cor_file = "$work_dir/snp_core.txt";
my $snp_var_file = "$work_dir/snp_variation.txt";
open($snp_pos_fh, ">$snp_pos_file") or die "Error: unable to write to file $snp_pos_file ($!).\n";
open($gap_pos_fh, ">$gap_pos_file") or die "Error: unable to write to file $gap_pos_file ($!).\n";
open($snp_cor_fh, ">$snp_cor_file") or die "Error: unable to write to file $snp_cor_file ($!).\n";
open($snp_var_fh, ">$snp_var_file") or die "Error: unable to write to file $snp_var_file ($!).\n";


# Snp ID cache
my %snp_cache;

# Retrieve list of pangenome core regions
my $pg_rs = $schema->resultset('Feature')->search(
    {
        type_id => $db_bridge->cvmemory('pangenome'),
        'feature_cvterms.cvterm_id' => $db_bridge->cvmemory('core_genome'),
        'feature_cvterms.is_not' => 0
    },
    {
        join => 'feature_cvterms',
        columns => [qw/feature_id residues/]
    }
);

# Initialize store
prepare_kv_store();

# Iterate through core regions
my $n = 1;
while(my $pg_row = $pg_rs->next) {

    my $pg_id = $pg_row->feature_id;
    update_region($work_dir, $pg_id, $pg_row->residues);

    get_logger->info("$n pangenome region $pg_id complete");
    $n++;

    last if $n > 5;
}

# Write core snp data to file
write_core_snps();

# Load data
#load_data();


########
## SUBS
########

sub prep_tables {

    my @tables = (qw/gap_position snp_position snp_variation snp_core/);

    foreach my $stable (@tables) {
        my $ttable = unique_tablename($stable);
    
        # Copy data and basic structure from source table
        my $sql1 = "CREATE TABLE $ttable AS SELECT * FROM $stable";
        $dbh->do($sql1) or croak("Error when executing: $sql1 ($!).\n");

        get_logger->debug("Table $stable copied to $ttable");

        # Delete contents of source table
        my $sql2 = "TRUNCATE TABLE $stable";
        $dbh->do($sql2) or croak("Error when executing: $sql2 ($!).\n");

        # Reset primary keys
        my $id = "$stable\_$stable\_id";
        my $sql3 = "ALTER SEQUENCE $id RESTART WITH 1";
        $dbh->do($sql3) or croak("Error when executing: $sql3 ($!).\n");

        get_logger->debug("Table $stable emptied");
    }
}

sub unique_tablename {
    my $name = shift;
    my $timestamp = int (gettimeofday * 1000);
    my $uname = "$name\_backup_$timestamp";
    return $uname;
}

sub update_region {
    my $root_dir = shift;
    my $pg_region_id = shift;
    my $pg_region_seq = shift;

    my $output_dir = "$root_dir/$pg_region_id/";
    mkdir $output_dir or croak "Error: unable to make directory $output_dir ($!)\n";

    my @jobs;

    # Retrieve all loci sequences mapped to this pangenome region
    my $loci_rs = $schema->resultset('Feature')->search(
        {
            'me.type_id' => $db_bridge->cvmemory('locus'),
            'feature_relationship_subjects.type_id' => $db_bridge->cvmemory('derives_from'),
            'feature_relationship_subjects.object_id' => $pg_region_id,
            'feature_relationship_subjects_2.type_id' => $db_bridge->cvmemory('part_of'),
            'feature_relationship_subjects_3.type_id' => $db_bridge->cvmemory('located_in'),
        },
        {
            join => ['feature_relationship_subjects', 'feature_relationship_subjects', 'feature_relationship_subjects'],
            columns => [qw/feature_id name uniquename seqlen residues/],
            '+select' => [qw/feature_relationship_subjects_2.object_id feature_relationship_subjects_3.object_id/],
            '+as' => [qw/genome_id contig_id/]
        }
    );

    # Align reference sequence
    my $fasta_file = "$output_dir/loci.fasta";
    my $ref_file = "$output_dir/reference.fasta";
    my $aln_file = "$output_dir/alignment.fasta";
    open(my $out, ">$fasta_file") or croak "Error: unable to write to file $fasta_file ($!).\n";
    while(my $loci_row = $loci_rs->next) {
        my $loci_id = $loci_row->feature_id;
        my $loci_seq = $loci_row->residues;
        
        push @jobs, [$loci_row->get_column('genome_id'), $loci_row->get_column('contig_id'), $pg_region_id, $loci_id, $loci_seq];

       print $out ">$loci_id\n$loci_seq\n";
    }
    close $out;

    my $refheader = "refseq_$pg_region_id";
    open($out, ">$ref_file") or croak "Error: unable to write to file $ref_file ($!).\n";
    print $out ">$refheader\n$pg_region_seq\n";
    close $out;

    my @loading_args = ($muscle_exe, "-profile -in1 $fasta_file -in2 $ref_file -out $aln_file");
    my $cmd = join(' ',@loading_args);
    
    my ($stdout, $stderr, $success, $exit_code) = capture_exec($cmd);

    unless($success) {
        croak "Muscle profile alignment failed for pangenome $pg_region_id ($stderr).";
    }

    # Retrieve aligned reference pangenome sequence
    my $refseq;
    my $fasta = Bio::SeqIO->new(-file   => $aln_file,
        -format => 'fasta') or croak "Unable to open Bio::SeqIO stream to $aln_file ($!).";
    while (my $entry = $fasta->next_seq) {
        my $id = $entry->display_id;
        
        if($id eq $refheader) {
            # Save reference sequence alignment string
            $refseq = $entry->seq;
           
        }
    }
    croak "Error: unless muscle alignment file does not contain sequence $refheader." unless $refseq;

     # Create output hashes
    my %variations = ();
    my %positions = ();
    snp_positions(\@jobs, \%variations, \%positions, $refseq);

    # my $put_sth = dbput($dbh, $pg_region_id, 'variation', \%variations);
    # dbput($dbh, $pg_region_id, 'position', \%positions, $put_sth);

    # # Commit inserts
    # dbcommit($dbh);

    # Load snp variations & positions
    foreach my $jarrayref (@jobs) {
            my @j = @$jarrayref;

            my $loci_id = $j[3];
            my $positions_arrayref = $positions{$loci_id};
            die "Error: no snp positions for $loci_id" unless $positions_arrayref && @$positions_arrayref;
            my $variations_arrayref = $variations{$loci_id};
            die "Error: no snp variations for $loci_id" unless $variations_arrayref && @$variations_arrayref;

            foreach my $var_row (@$variations_arrayref) { 
                handle_snp(@j[0..3], @$var_row)
            }

            foreach my $pos_row (@$positions_arrayref) {
                handle_snp_alignment_block(@j[0..3], @$pos_row);
            }
            
    }
}

sub handle_snp {
    my $self = shift;
    my ($contig_collection, $contig, $ref_id, $locus, $ref_pos, $rgap_offset, $c2, $c1) = @_;
    
    croak "Positioning violation! $c2 character with gap offset value $rgap_offset for core sequence." if ($rgap_offset && $c2 ne '-') || (!$rgap_offset && $c2 eq '-');

    # Retrieve reference snp, if it exists
    my $snp_hash = retrieve_core_snp($ref_id, $ref_pos, $rgap_offset);

    unless($snp_hash) {
        # Create new core snp entry
        $snp_hash = add_core_snp($ref_id, $ref_pos, $rgap_offset, $c2, $c1);  
    } else {
        # Update frequency
        my @frequencyArray = _update_frequency_array($c1, @{$snp_hash->{freq}});
        $snp_hash->{freq} = \@frequencyArray;
    }
    my $ref_snp_id = $snp_hash->{snp_id};
        
    # Create variation entry
    print $snp_var_fh join("\t", $snp_var_pkey_id, $ref_snp_id, $contig_collection, $contig, $locus, $c1)."\n";
    $snp_var_pkey_id++;
   
}

sub handle_snp_alignment_block {
    my ($contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2) = @_;


    # Block transitions should occur at:
    # termination of a gap in one sequence
    #   or
    # A gap column at the start of a new block (which could be a run-on of a previous gap)
    if($gap1 == 0 && $gap2 != 0 && ($start2 != $end2 || ($start1+1) != $end1)) {
        croak "Positioning violation in alignment block! gap in reference sequence aligned with nt in comparison sequence must be of length 1\n\tdetails: ".
            join(', ',$contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2)."\n";
    } elsif($gap2 == 0 && $gap2 != 0 && ($start1 != $end1 || ($start2+1) != $end2+1)) {
        croak "Positioning violation in alignment block! gap in comparison sequence aligned with nt in reference sequence must be of length 1\n\tdetails: ".
            join(', ',$contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2)."\n";
    } elsif($gap2 != $gap1 && (($start2+1) < $end2 || ($start1+1) < $end1)) {
        croak "Positioning violation in alignment block! in extended alignment blocks, gaps must be equal representing gap columns in both sequences\n\tdetails: ".
            join(', ',$contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap1, $gap2)."\n";
    }
    
    
    if($gap1 && $start1 == $end1) {
        # Reference gaps go into 'special' table
        # Note: When there are gap offset values for both reference and comparison sequence (not necessarily equal if there was preceding gaps), 
        # implies that a gap column was encountered. Gap columns inside alignment blocks are ignored.

        my $snp_hash = retrieve_core_snp($ref_id, $start1, $gap1);
        croak "Error: SNP in reference pangenome region $ref_id (pos: $start1, gap-offset: $gap1) not found." unless $snp_hash;
        my $snp_id = $snp_hash->{snp_id};

        print $gap_pos_fh join("\t", $gap_pos_pkey_id, $contig_collection, $contig, $ref_id, $locus, $snp_id, $start2) . "\n";
        $gap_pos_pkey_id++
        
    } else {
        # Create standard snp position entry: reference nuc aligned to gap or nuc in comparison strain
        print $snp_pos_fh join("\t", $snp_pos_pkey_id, $contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap2) . "\n";
        $snp_pos_pkey_id++
    }
}

sub add_core_snp {
    my ($ref_id, $ref_pos, $rgap_offset, $ref_c, $c) = @_;

    # Allele frequency > 1 in order to add to snp alignment,
    # so at this point snp will not be in alignment
        
    # Starting frequency counts
    # NOTE: background (or SNPs with char matching the snp_core allele char) are not counted
    my @frequencyArray = _update_frequency_array($c);
        
    my $ref_snp_id = $snp_cor_pkey_id;
    $snp_cor_pkey_id++;
    my $key = "$ref_id.$ref_pos.$rgap_offset";
    $snp_cache{$key} = {
        snp_id => $ref_snp_id, freq => \@frequencyArray, pos => $ref_pos, gapo => $rgap_offset,
        pangenome_region => $ref_id, allele => $ref_c 
    };

    return $snp_cache{$key};
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


sub retrieve_core_snp {
    my ($id, $pos, $gap_offset) = @_;
    
    my $snp_id = undef;
    my $key = "$id.$pos.$gap_offset";
    if(defined $snp_cache{$key}) {
        # Search for existing core snp entries in cached values
        $snp_id = $snp_cache{$key}

    }
    
    return $snp_id;
}

sub write_core_snps {
    # Save core data to file

    foreach my $snp_row (values %snp_cache) {
        print $snp_cor_fh join("\t", $snp_row->{snp_id}, $snp_row->{pangenome_region}, $snp_row->{allele},
            $snp_row->{pos}, $snp_row->{gapo}, undef, @{$snp_row->{freq}})."\n"
    }
}

sub load_data {

    
    eval {
    
        prep_tables();

        my @tables = (
            [
                $snp_cor_fh,
                'snp_core',
                '(snp_core_id,pangenome_region_id,allele,position,gap_offset,aln_column,frequency_a,frequency_t,frequency_g,frequency_c,frequency_gap,frequency_other)',
                $snp_cor_file,
                'snp_core_snp_core_id_seq',
                $snp_cor_pkey_id
            ],
            [
                $snp_var_fh,
                'snp_variation',
                '(snp_variation_id,snp_id,contig_collection_id,contig_id,locus_id,allele)',
                $snp_var_file,
                'snp_variation_snp_variation_id_seq',
                $snp_var_pkey_id
            ],
            [
                $snp_pos_fh,
                'snp_position',
                '(snp_position_id,contig_collection_id,contig_id,pangenome_region_id,locus_id,region_start,locus_start,region_end,locus_end,locus_gap_offset)',
                $snp_pos_file,
                'snp_position_snp_position_id_seq',
                $snp_pos_pkey_id
            ],
            [
                $gap_pos_fh,
                'gap_position',
                '(gap_position_id,contig_collection_id,contig_id,pangenome_region_id,locus_id,snp_id,locus_pos)',
                $gap_pos_file,
                'gap_position_gap_position_id_seq',
                $gap_pos_pkey_id
            ],
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
    my $sequence = shift;
    my $nextval  = shift;

    my $dbh      = $db_bridge->dbh();

    get_logger->info("Loading data into $table table ...\n");

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

    # update the sequence so that later inserts will work
    $dbh->do("SELECT setval('$sequence', $nextval) FROM $table")
        or croak("Error when executing:  setval('$sequence', $nextval) FROM $table: $!"); 
}

sub snp_positions {
    my $jobs = shift;
    my $variations = shift;
    my $positions = shift;
    my $refseq = shift;

    my @refseq_array = split(//,$refseq);

    for(my $i=0; $i < @$jobs; $i++) {
        my $job_row = $jobs->[$i];
        my $seq = $job_row->[4];
        my $genomename = $job_row->[3];
        my @seq_array = split(//, $seq);
       
        write_positions(\@refseq_array, \@seq_array, $variations, $positions, $genomename)
    }

}

sub write_positions {
    my $refseq = shift;
    my $seq = shift;
    my $variations = shift;
    my $positions = shift;
    my $genomename = shift;

    my @varlist; 
    my @poslist;

    $variations->{$genomename} = \@varlist;
    $positions->{$genomename} = \@poslist;

    my $i = 0;
    my $g = 0;
    my $p = 0; # current position
    my $s = 0; # start of alignment block
    my $g2 = 0;
    my $p2 = 0;
    my $s2 = 0; 
    my $gapoffset_state = 0; 
    # 0 = gap offset equal in reference and comparison sequence at current position
    # 1 = gap offset not equal
    
    # Alignment blocks are interupted by gaps.
    # See transition state diagram for full explanation of emission of alignment blocks.
    # Alignment blocks are printed as
    # ref_start, comp_start, ref_end, comp_end, ref_gap_offset, comp_gap_offset
        
    # Starting state
    if($refseq->[$i] eq '-') {
        # Gap in reference sequence
        
        if($seq->[$i] eq '-') {
            # Gap in comparison sequence
            $gapoffset_state = 0;
            $g2++;

        }
        else {
            # Nt in comparison sequence
            $gapoffset_state = 1;
            $p2++;
        }

        $g++;
    }
    else {
        # Nt in reference sequence

        if($seq->[$i] eq '-') {
            # Gap in comparison sequence
            $gapoffset_state = 1;
            $g2++;
        }
        else {
            # Nt in comparison sequence
            $gapoffset_state = 0;
            $p2++;
        }

        $p++;
    }

    # Print SNP                                      
    if($refseq->[$i] ne $seq->[$i]) {
        push(@varlist, [$p, $g, $refseq->[$i], $seq->[$i]]);
    }

                                             
    for($i=1; $i < @$refseq; $i++) {

        if($gapoffset_state eq 0) {
            # Present state: equal gap offset values in reference and comparison sequence

            # New column
            if($refseq->[$i] eq '-') {
                # Gap in reference sequence
                
                if($seq->[$i] eq '-') {
                    # Gap in comparison sequence
                    $gapoffset_state = 0;
                    $g2++;

                }
                else {
                    # Nt in comparison sequence
                    # Marks start of new block
                    # Print old block, update starting positions
                    push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
                    $s = $p;
                    $s2 = $p2;

                    $gapoffset_state = 1;
                    $p2++;
                    $g2 = 0;
                }

                $g++;
            }
            else {
                # Nt in reference sequence

                if($seq->[$i] eq '-') {
                    # Gap in comparison sequence
                    # Marks start of new block
                    # Print old block, update starting positions
                    push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
                    $s = $p;
                    $s2 = $p2;

                    $gapoffset_state = 1;
                    $g2++;
                }
                else {
                    # Nt in comparison sequence
                    $gapoffset_state = 0;
                    $p2++;
                    $g2 = 0;

                }

                $p++;
                $g = 0;
            }
        }
        else {
            # Present state: unequal gap offset values in reference and comparison sequence

            # New column
            if($refseq->[$i] eq '-') {
                # Gap in reference sequence
                
                if($seq->[$i] eq '-') {
                    # Gap in comparison sequence
                    # States stays unequal
                    # Marks start of new block
                    # Print old block, update starting positions
                    push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
                    $s = $p;
                    $s2 = $p2;

                    $gapoffset_state = 1;
                    $g2++;

                }
                else {
                    # Nt in comparison sequence
                    # Marks start of new block
                    # Print old block, update starting positions
                    push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
                    $s = $p;
                    $s2 = $p2;

                    $gapoffset_state = 1;
                    $p2++;
                    $g2 = 0;
                }

                $g++;
            }
            else {
                # Nt in reference sequence

                if($seq->[$i] eq '-') {
                    # Gap in comparison sequence
                    # Marks start of new block
                    # Print old block, update starting positions
                    push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
                    $s = $p;
                    $s2 = $p2;

                    $gapoffset_state = 1;
                    $g2++;
                }
                else {
                    # Nt in comparison sequence
                    # Marks start of new block
                    # Print old block, update starting positions
                    push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);
                    $s = $p;
                    $s2 = $p2;

                    $gapoffset_state = 0;
                    $p2++;
                    $g2 = 0;

                }

                $p++;
                $g = 0;
            }
        }
        
        # Print SNP                                        
        if($refseq->[$i] ne $seq->[$i]) {
            push(@varlist, [$p, $g, $refseq->[$i], $seq->[$i]]);
        }
                                                                             
    }

    # Print last block
    push(@poslist, [$s, $s2, $p, $p2, $g, $g2]);

}

=head2 prepare_kv_store

Set up key/value store in postgres DB for this run

=cut
sub prepare_kv_store {
    my $dbparams = shift;

    $dbh->do(q/CREATE TABLE IF NOT EXISTS tmp_parallel_kv_store (
        store_id varchar(40),
                json_value text,
        CONSTRAINT store_id_c1 UNIQUE(store_id)
    )/) or croak $dbh->errstr;

    $dbh->do(q/
            DELETE FROM tmp_parallel_kv_store
        /) or croak $dbh->errstr;

}

sub dbput {
    my $dbh = shift;
    my $pg_id = shift;
    my $data_type = shift;
    my $data_hashref = shift;
    my $put_sth = shift;

    croak "Error: invalid argument: pangenome ID $pg_id." unless $pg_id =~ m/^\d+$/;
    croak "Error: invalid argument: data type $data_type." unless $data_type =~ m/^(?:variation|position)$/;
    croak "Error: invalid argument: data hash ref." unless ref($data_hashref) eq 'HASH';

    # Serialize hashes using JSON
    my $data_json = encode_json($data_hashref);

    # Unique key
    my $key = "$pg_id\_$data_type";

    unless($put_sth) {
        $put_sth = $dbh->prepare("INSERT INTO tmp_parallel_kv_store(store_id, json_value) VALUES (?,?)")
            or croak $dbh->errstr;
    }
    
    $put_sth->execute($key, $data_json) or croak $dbh->errstr;

    return $put_sth;
}

sub dbfinish {
    my $dbh = shift;

    $dbh->disconnect();
}

sub dbget {
    my $dbh = shift;
    my $pg_id = shift;
    my $data_type = shift;
    my $get_sth = shift;

    croak "Error: invalid argument: pangenome ID $pg_id." unless $pg_id =~ m/^\d+$/;
    croak "Error: invalid argument: data type $data_type." unless $data_type =~ m/^(?:variation|position)$/;

    # Unique key
    my $key = "$pg_id\_$data_type";

    unless($get_sth) {
        $get_sth = $dbh->prepare("SELECT json_value FROM tmp_parallel_kv_store WHERE store_id = ?")
            or croak $dbh->errstr;
    }
    
    $get_sth->execute($key) or croak $dbh->errstr;

    my ($data_string) = $get_sth->fetchrow_array();

    return ($data_string, $get_sth);
}

sub dbcommit {
    my $dbh = shift;

    $dbh->commit() or croak $dbh->errstr;
}