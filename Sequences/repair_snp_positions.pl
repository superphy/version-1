#!/usr/bin/env perl

use Inline (Config =>
            DIRECTORY => $ENV{"SUPERPHY_INLINEDIR"} || $ENV{"HOME"}.'/Inline' );
use Inline 'C';

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
use Bio::SeqIO;
use IO::CaptureOutput qw(capture_exec);

=head1 NAME

$0 - Deletes and reloads the snp_position and gap_position tables

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config          INI style config file containing DB connection parameters
 
=head1 DESCRIPTION

Changes to the SNP position algorithm required that the snp_position, private_snp_position
gap_position and private_gap_position be reloaded.

Its a good idea to backup the tables before preceding.  Option --backup will copy the snp_
and gap_position tables to tables named backup_snp_position, etc. You will need to drop
these manually when safe to do so.  Make sure you do

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2015

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


# Primary Key IDs
my $snp_pos_pkey_id = 1;
my $gap_pos_pkey_id = 1;


# File handles for table input
my $snp_pos_fh;
my $gap_pos_fh;
my $work_dir = tempdir('genodo_repair_XXXX', DIR => $root_dir, CLEANUP => 0 );
my $gap_pos_file = "$work_dir/gap_positions.txt";
my $snp_pos_file = "$work_dir/snp_positions.txt";
open($snp_pos_fh, ">$snp_pos_file") or die "Error: unable to write to file $snp_pos_file ($!).\n";
open($gap_pos_fh, ">$gap_pos_file") or die "Error: unable to write to file $gap_pos_file ($!).\n";


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


# Iterate through core regions
my $n = 1;
while(my $pg_row = $pg_rs->next) {

    my $pg_id = $pg_row->feature_id;
    update_region($work_dir, $pg_id, $pg_row->residues);

    get_logger->info("$n pangenome region $pg_id complete");
    $n++;

    last if $n > 5;
}

# Load data
#load_data();


########
## SUBS
########

sub prep_tables {

    my $dbh = $db_bridge->dbh();

    my @tables = (qw/gap_position snp_position/);

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
        my $file = $output_dir . "$loci_id\__snp_positions.txt";
        push @jobs, [$file, $loci_row->get_column('genome_id'), $loci_row->get_column('contig_id'), $pg_region_id, $loci_id, $loci_seq];

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

    # Compute positions
    foreach my $j (@jobs) {
        my $file = $j->[0];
        my $loci_id = $j->[4];
        my $loci_seq = $j->[5];
   
        my $rs = update_loci_snp_positions($refseq, $loci_seq, $file);

        croak "Error: Position algorithm failed for pangenome_region $pg_region_id and loci $loci_id\n" unless $rs;
    }

    # Prepare positions for loading
    foreach my $jarrayref (@jobs) {
        my @j = @$jarrayref;
        my $file = $j[0];
        open(my $in, "<$file") or croak "Error: unable to read file $file ($!).\n";
        while(my $snp_line = <$in>) {
            chomp $snp_line;
            my ($start1, $start2, $end1, $end2, $gap1, $gap2) = split(/\t/, $snp_line);
            croak "Error: invalid snp position format on line $snp_line." unless defined $gap2;
            handle_snp_alignment_block(@j[1..4], $start1, $start2, $end1, $end2, $gap1, $gap2);
        }
        close $in;
    }
}

sub update_loci_snp_positions {
    my ($pg_region_seq, $loci_seq, $file) = @_;

    eval {
        write_positions($pg_region_seq, $loci_seq, $file);
    };
   
    if($@) {
        return 0;
    }

    return 1;
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

        my $snp_id = retrieve_core_snp($ref_id, $start1, $gap1);
        croak "Error: SNP in reference pangenome region $ref_id (pos: $start1, gap-offset: $gap1) not found." unless $snp_id;

        print $gap_pos_fh join("\t", $gap_pos_pkey_id, $contig_collection, $contig, $ref_id, $locus, $snp_id, $start2) . "\n";
        $gap_pos_pkey_id++
        
    } else {
        # Create standard snp position entry: reference nuc aligned to gap or nuc in comparison strain
        print $snp_pos_fh join("\t", $snp_pos_pkey_id, $contig_collection, $contig, $ref_id, $locus, $start1, $start2, $end1, $end2, $gap2) . "\n";
        $snp_pos_pkey_id++
    }
    
    
    
}

sub retrieve_core_snp {
    my ($id, $pos, $gap_offset) = @_;
    
    my $snp_id = undef;
    my $key = "$id.$pos.$gap_offset";
    if(defined $snp_cache{$key}) {
        # Search for existing core snp entries in cached values
        $snp_id = $snp_cache{$key}

    } else {
        # Search for existing entries in snp_core table

        my $snp_row = $schema->resultset('SnpCore')->find(
            {
                pangenome_region_id => $id,
                position => $pos,
                gap_offset => $gap_offset
            }
        );

        if($snp_row) {
            $snp_id = $snp_row->snp_core_id;
            $snp_cache{$key} = $snp_id;
        }
                
    }
    
    return $snp_id;
}

sub load_data {

    my $dbh = $db_bridge->dbh();

    $dbh->{AutoCommit} = 0;  # Enable transactions
    $dbh->{RaiseError} = 1;

    eval {
    
        prep_tables();

        my @tables = (
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

__END__
__C__

void write_positions(char* refseq, char* seq, char* filename2) {
    
    FILE* fh2 = fopen(filename2, "w");
    int i;
    int g = 0; // gap
    int p = 0; // current position
    int s = 0; // start of alignment block
    int g2 = 0;
    int p2 = 0;
    int s2 = 0; 
    int gapoffset_state = 0; 
    // 0 = gap offset equal in reference and comparison sequence at current position
    // 1 = gap offset not equal
    
    // Alignment blocks are interupted by gaps.
    // See transition state diagram for full explanation of emission of alignment blocks.
    // Alignment blocks are printed as
    // ref_start, comp_start, ref_end, comp_end, ref_gap_offset, comp_gap_offset
    
    if (fh2 == NULL) {
        fprintf(stderr, "Can't open output file %s!\n",
            filename2);
        exit(1);
    }

    if (!refseq[1]) {
        fprintf(stderr, "Assumption violated! aligned sequence length >= 2.\n");
        exit(1);
    }
    

    // Starting state
    if(refseq[i] == '-') {
        // Gap in reference sequence
        
        if(seq[i] == '-') {
            // Gap in comparison sequence
            gapoffset_state = 0;
            g2++;

        }
        else {
            // Nt in comparison sequence
            gapoffset_state = 1;
            p2++;
        }

        g++;
    }
    else {
        // Nt in reference sequence

        if(seq[i] == '-') {
            // Gap in comparison sequence
            gapoffset_state = 1;
            g2++;
        }
        else {
            // Nt in comparison sequence
            gapoffset_state = 0;
            p2++;
        }

        p++;
    }

                                             
    for(i=1; refseq[i] && seq[i]; ++i) {

        if(gapoffset_state == 0) {
            // Present state: equal gap offset values in reference and comparison sequence

            // New column
            if(refseq[i] == '-') {
                // Gap in reference sequence
                
                if(seq[i] == '-') {
                    // Gap in comparison sequence
                    gapoffset_state = 0;
                    g2++;

                }
                else {
                    // Nt in comparison sequence
                    // Marks start of new block
                    // Print old block, update starting positions
                    fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
                    s = p;
                    s2 = p2;

                    gapoffset_state = 1;
                    p2++;
                    g2 = 0;
                }

                g++;
            }
            else {
                // Nt in reference sequence

                if(seq[i] == '-') {
                    // Gap in comparison sequence
                    // Marks start of new block
                    // Print old block, update starting positions
                    fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
                    s = p;
                    s2 = p2;

                    gapoffset_state = 1;
                    g2++;
                }
                else {
                    // Nt in comparison sequence
                    gapoffset_state = 0;
                    p2++;
                    g2 = 0;

                }

                p++;
                g = 0;
            }
        }
        else {
            // Present state: unequal gap offset values in reference and comparison sequence

            // New column
            if(refseq[i] == '-') {
                // Gap in reference sequence
                
                if(seq[i] == '-') {
                    // Gap in comparison sequence
                    // States stays unequal
                    // Marks start of new block
                    // Print old block, update starting positions
                    fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
                    s = p;
                    s2 = p2;

                    gapoffset_state = 1;
                    g2++;

                }
                else {
                    // Nt in comparison sequence
                    // Marks start of new block
                    // Print old block, update starting positions
                    fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
                    s = p;
                    s2 = p2;

                    gapoffset_state = 1;
                    p2++;
                    g2 = 0;
                }

                g++;
            }
            else {
                // Nt in reference sequence

                if(seq[i] == '-') {
                    // Gap in comparison sequence
                    // Marks start of new block
                    // Print old block, update starting positions
                    fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
                    s = p;
                    s2 = p2;

                    gapoffset_state = 1;
                    g2++;
                }
                else {
                    // Nt in comparison sequence
                    // Marks start of new block
                    // Print old block, update starting positions
                    fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
                    s = p;
                    s2 = p2;

                    gapoffset_state = 0;
                    p2++;
                    g2 = 0;

                }

                p++;
                g = 0;
            }
        }
                                                                            
    }
    
    // Print last block
    fprintf(fh2, "%i\t%i\t%i\t%i\t%i\t%i\n", s, s2, p, p2, g, g2);
    
    fclose(fh2);                                                                           

}