#!/usr/bin/env perl

use strict;
use warnings;


use Carp;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use POSIX qw(strftime);
use Try::Tiny;
use File::Basename;
use lib dirname (__FILE__) . "/../";
use Data::Bridge;


=head1 NAME

$0 - Populate the 'reference_pangenome_alignment' features.

=head1 SYNOPSIS

  % $0 [options]

=head1 OPTIONS

 --config   INI style config file containing DB connection parameters
 

=head1 DESCRIPTION

This needs to only be called once to initialize the reference_pangenome_alignment sequences
(it can be called to sync the reference_pangenome_alignment sequences with the snp table records).

The reference_pangenome_alignment sequences contain gaps matching the currently aligned pangenome region.
They are used to position the reference pangenome sequence against newly aligned pangenome regions to identify new
snps and gaps.


=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Adapted from original package developed by 
Allen Day E<lt>allenday@ucla.eduE<gt>, Scott Cain E<lt>scain@cpan.orgE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($DEBUG, $LOGFILE);

my $TEST = 0;
my $LOG = undef;

# Initialize DB interface objects via Bridge module
my $db_bridge;
my $schema;
try {
    $db_bridge = Data::Bridge->new();
    $schema = $db_bridge->dbixSchema;
    #$config_filepath = $db_bridge->configFile();
} catch {
    croak "Error: Initialization of Pg DB handle failed ($_).\n";
};


# Process remaining command-line args
GetOptions(
    'debug' => \$DEBUG,
    'test' => \$TEST,
    'log=s' => \$LOGFILE
) 
or pod2usage(-verbose => 1, -exitval => 1);

# SET UP LOGGER
if($LOGFILE) {
	open($LOG, ">", $LOGFILE) or croak "Unable to open $LOGFILE for write operation ($!)\n";
	print $LOG "****START OF populate_reference_pangenome_alignments.pl LOG ENTRY****\n";
}

# Get feature terms
my ($ft, $rt) = feature_types();
logger("RPA type_id: $ft, relationship_type ID: $rt");

my $organism_id = organism_id();
logger("RPA organism_id: $organism_id");

my $alignments = compute();
logger("RPA sequences: ".scalar(keys %$alignments));

populate($alignments);
logger("populate_reference_pangenome_alignments script complete");


=head2 feature_type

Check 'reference_pangenome_alignment' and 'aligned_sequence_of' types exists.

Returns cvterm_ids

=cut
sub feature_types {

    my @terms = ('reference_pangenome_alignment', 'aligned_sequence_of');
    my @cvterm_ids;

    my $ont = 'local';
    
    foreach my $term (@terms) {
        my $type_row = $schema->resultset('Cvterm')->find(
            {
                'me.name' => $term,
                'cv.name' => $ont
            },
            {
                join => [qw/cv/],
                columns => ['cvterm_id', 'name']
            }
        );

        unless($type_row) {
            croak "Error: cvterm '$term' not found.\n\tPlease update the cvterm table by running script 'Database/genodo_add_ontology.pl'.";
        }

        push @cvterm_ids, $type_row->cvterm_id
    }
    
    return @cvterm_ids;
}


=head2 organism_id

Returns the default organism ID for new features

=cut
sub organism_id {

    my @latin = qw(Escherichia coli);
    my $org_row = $schema->resultset('Organism')->find(
        {
            genus => $latin[0],
            species => $latin[1]
        },
        {
            key => 'organism_c1'
        }
    );

    unless($org_row) {
        croak "Error: organism ".join(' ', @latin)." not found.";
    }

    return $org_row->organism_id;
}


=head2 compute

Compute reference pangenome alignments using SNP core records

=cut

sub compute {

    # Retrieve core pangenome regions
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

    # Iterate through pangenome regions
    my %alignments;
    while(my $pg_row = $pg_rs->next) {

        my $pg_id = $pg_row->feature_id;
        my $seq = $pg_row->residues;

        croak "Error: pangenome region $pg_id sequence contains 'alignment' characters" if $seq =~ m/\-/;

        # Insert gaps, using snp_core info as guide

        # Retrieve snp_core gaps for this region
        my $gap_rs = $schema->resultset('SnpCore')->search(
            {
                pangenome_region_id => $pg_id,
                allele => '-'
            },
            {
                columns => [qw/position gap_offset/],
                order_by => { -desc => [qw/position gap_offset/] }
            }
        );

        # Insert each gap at required position
        # The gaps are sorted by position in descending order, so the relative char position will not be affected
        # by the insertions for remaining gaps in list
        my $total_gap_chars = 0;
        my %total_gaps;

        while(my $gap_row = $gap_rs->next) {
            my $pos = $gap_row->position;
            substr($seq, $pos, 0) = '-';
            $total_gap_chars++;
            $total_gaps{$pos} = $gap_row->gap_offset unless defined $total_gaps{$pos}
        }

        # Do some checks on the sequence
        my $err_details = "Pangenome region id $pg_id\n".
            "Expected gaps: ".scalar(keys(%total_gaps))."\n".
            "Expected gap positions: $total_gap_chars\n".
            "Reformated sequence:\n$seq\n";
        my $total_found = $seq =~ tr/-/-/;
        croak "Error: the expected number of gaps does not match the instances of '-' in the reformated sequence string ($total_found).\n$err_details" 
            unless $total_found == $total_gap_chars;

        my $pos_adj = 0;
        foreach my $gap_pos (sort {$a <=> $b} keys %total_gaps) {
            my $gap_len = $total_gaps{$gap_pos};
            my $gap = ('-')x$gap_len;

            my $this_pos = $gap_pos+$pos_adj;
            my $obs_gap = substr($seq, $this_pos, $gap_len);
            if($gap ne $obs_gap) {
                croak "Error: gap at position $this_pos (absolute position: $gap_pos) not correct ($obs_gap). Expected a gap of length $gap_len.\n$err_details"
            }
           
            $pos_adj += $gap_len;
        }

        if($DEBUG) {
            print $err_details;
        }

        $alignments{$pg_id} = $seq;
    }

    return \%alignments;
}



=head2 populate

Delete existing features 

Insert new features

=cut
sub populate {
    my $alignments = shift;

    my $updated = 0;
    my $created = 0;

    for my $pg_id (keys %$alignments) {

        my $seq = $alignments->{$pg_id};
        my $seqlen = length($seq);

        my $rpa_rs = $schema->resultset('Feature')->search(
            {
                'me.type_id' => $ft,
                'feature_relationship_subjects.object_id' => $pg_id,
                'feature_relationship_subjects.type_id' => $rt
            },
            {
                join => 'feature_relationship_subjects'
            }
        );

        if($rpa_rs->count > 1) {
            croak "Error: multiple reference_pangenome_alignment features for pangenome region $pg_id";
        }

        my $rpa_row = $rpa_rs->first();

        if($rpa_row) {

            $rpa_row->residues($seq);
            $rpa_row->seqlen($seqlen);
            $rpa_row->update;

            $updated++;
            if($DEBUG) {
                print "UPDATED RPA feature ".$rpa_row->feature_id." for pangenome feature $pg_id\n"
            }

        } else {

            my $name =  "aligned sequence of pangenome region $pg_id";
            my $rpa_row = $rpa_rs->create(
                {
                    name => $name,
                    uniquename => $name,
                    type_id => $ft,
                    organism_id => $organism_id,
                    is_analysis => 1,
                    dbxref_id => undef,
                    seqlen => $seqlen,
                    residues => $seq,
                    feature_relationship_subjects => [
                        {
                            type_id => $rt,
                            object_id => $pg_id,
                            rank => 0
                        }
                    ]
                }
            
            );

            $created++;
            if($DEBUG) {
                print "Created RPA feature ".$rpa_row->feature_id." for pangenome feature $pg_id\n"
            }
        }
    }

    logger("$updated RPA features updated. $created RPA features created.");

}

=head2 log

Add entry with timestamp to log file

=cut
sub logger {
    my $msg = shift;

    if($LOG) {
        my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
        print $LOG "$date: $msg\n";
    }
    
}



