#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use File::Basename;
use Database::Chado::Schema;
use Modules::FET;
use Carp qw/croak carp/;
use Config::Simple;
use DBIx::Class::ResultSet;
use DBIx::Class::Row;
use IO::File;
use File::Temp;
use JSON;
use Time::HiRes qw( time );

BEGIN { $ENV{DBIC_TRACE} = 1; }

my ($JOBID, $CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $log_dir);

# get script location via File::Basename
my $SCRIPT_LOCATION = dirname(__FILE__) . '/../../config';

print STDERR $SCRIPT_LOCATION . "\n";

# Load config options
$CONFIG = new Config::Simple($SCRIPT_LOCATION.'/genodo.cfg');

GetOptions('job_id=s' => \$JOBID) or (exit -1);
croak "Job ID not specified\n" unless $JOBID;
croak "Missing user specific config\n" unless $CONFIG;

# Set up the db connection params
if(my $db_conf = $CONFIG) {
    $DBNAME = $db_conf->param('db.name');
    $DBUSER = $db_conf->param('db.user');
    $DBPASS = $db_conf->param('db.pass');
    $DBHOST = $db_conf->param('db.host');
    $DBPORT = $db_conf->param('db.port');
    $DBI = $db_conf->param('db.dbi');

    # log directory
    $log_dir = $db_conf->param('dir.log');
    croak "Error: missing config file parameter 'dir.log'." unless $log_dir;
}
else {
    die Config::Simple->error();
}

# Connect to db
my $dbsource = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dbsource . ';port=' . $DBPORT if $DBPORT;

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS);

# TODO: Need to handle connection errors here and notify the client, or re-init the job

if (!$schema) {
    croak "Could not connect to database: $!\n";
}

# Get user requested strains from the database,
my $userConfigRs = $schema->resultset('JobResult')->find({job_result_id => $JOBID});
my $userConfig = decode_json($userConfigRs->user_config);

my $user_g1 = $userConfig->{'group1'};
my $user_g2 = $userConfig->{'group2'};

my ($pub_g1, $pri_g1, $pub_g2, $pri_g2) = parse_genome_ids($user_g1, $user_g2);

# Two very ginormous important subs:!
my $binFETResults = queryBinData($pub_g1, $pri_g1, $pub_g2, $pri_g2, $user_g1, $user_g2);
my $snpFETResults = querySnpData($pub_g1, $pri_g1, $pub_g2, $pri_g2, $user_g1, $user_g2);

sub queryBinData {
    # TODO: Need to store the FET results into a json object and write it to the database
    my ($_pub_g1, $_pri_g1, $_pub_g2, $_pri_g2, $_user_g1, $_user_g2) = @_;
    my ($g1_totals, $g2_totals) = countLoci($schema, $_pub_g1, $_pri_g1, $_pub_g2, $_pri_g2);

    my (@g1_ordered_rows, @g2_ordered_rows); 
    foreach my $l (keys %$g1_totals) {
        push @g1_ordered_rows, $g1_totals->{$l};
        push @g2_ordered_rows, $g2_totals->{$l};
    }

    my $fet = Modules::FET->new();
    $fet->group1($_user_g1);
    $fet->group2($_user_g2);
    $fet->group1Markers(\@g1_ordered_rows);
    $fet->group2Markers(\@g2_ordered_rows);
    $fet->testChar('1');
    #Returns hash ref of results
    my $results = $fet->run('locus_count');
}

sub querySnpData {
    # TOD0: Need to store the FET results into a json object and write it to the database
    my ($_pub_g1, $_pri_g1, $_pub_g2, $_pri_g2, $_user_g1, $_user_g2) = @_;

    my $tot1 = scalar(@$_user_g1);
    my $tot2 = scalar(@$_user_g2);
    my ($g1_totals, $g2_totals) = countSnps($schema, $_pub_g1, $_pri_g1, $_pub_g2, $_pri_g2, $tot1, $tot2);
    
    my @g1_ordered_rows; 
    my @g2_ordered_rows; 
    foreach my $s (keys %$g1_totals) {
        push @g1_ordered_rows, $g1_totals->{$s};
        push @g2_ordered_rows, $g2_totals->{$s};
    }
    
    my $fet = Modules::FET->new();
    $fet->group1($_user_g1);
    $fet->group2($_user_g2);
    $fet->group1Markers(\@g1_ordered_rows);
    $fet->group2Markers(\@g2_ordered_rows);
    
    # Merge results as each nucleotide is analyzed
    my @combineAllResults;
    my @combineSigResults;
    my $combineSigCount = 0;
    my $combineTotalComparisons = 0;
    foreach my $nuc (qw/A C G T/) {
        
        $fet->testChar($nuc);
        my $a_results = $fet->run($nuc);
        
        push @combineAllResults, @{$a_results->[0]{'all_results'}};
        push @combineSigResults, @{$a_results->[1]{'sig_results'}};
        $combineSigCount += $a_results->[2]{'sig_count'};
        $combineTotalComparisons += $a_results->[3]{'total_comparisons'};
    }

    my @results;

    my @sortedAllResults = sort({$a->{'pvalue'} <=> $b->{'pvalue'}} @combineAllResults);
    my @sortedSigResults = sort({$a->{'pvalue'} <=> $b->{'pvalue'}} @combineSigResults);

    push(@results, {'all_results' => \@sortedAllResults}, {'sig_results' => \@sortedSigResults}, {'sig_count' => $combineSigCount}, {'total_comparisons' => $combineTotalComparisons});

}

### Helper Methods ###

sub parse_genome_ids {
    my ($_user_g1, $_user_g2) = @_;
    my ($_pub_g1, $_pub_g2, $_pri_g1, $_pri_g2);
    # Parse input
    foreach my $g (@$_user_g1) {
        if($g =~ m/public_(\d+)/) {
            push @$_pub_g1, $1;
        } elsif($g =~ m/private_(\d+)/) {
            push @$_pri_g1, $1;
        } else {
            croak "[Error] Invalid genome ID $g.\n";
        }
    }
    foreach my $g (@$_user_g2) {
        if($g =~ m/public_(\d+)/) {
            push @$_pub_g2, $1;
        } elsif($g =~ m/private_(\d+)/) {
            push @$_pri_g2, $1;
        } else {
            croak "[Error] Invalid genome ID $g.\n";
        }
    }
    return($_pub_g1, $_pri_g1, $_pub_g2, $_pri_g2);
}

sub countLoci {
    my ($schema, $_pub_g1, $_pri_g1, $_pub_g2, $_pri_g2) = @_;
    
    my %g1_totals; my %g2_totals;
    
    if(@$_pub_g1) {
        my $g1_counts = $schema->resultset('Feature')->search(
            {
                'me.type_id' => $type_ids->{pangenome},
                'feature_relationship_objects.type_id' => $type_ids->{derives_from},
                'feature_relationship_subjects.type_id' => $type_ids->{part_of},
                'feature_relationship_subjects.object_id' => $_pub_g1,
                'featureprops.type_id' => $type_ids->{panseq_function} 
            },
            {
                join => [
                    {'feature_relationship_objects' => {'subject' => 'feature_relationship_subjects'}},
                    'featureprops'
                ],
                select => ['me.feature_id', 'me.uniquename', 'featureprops.value', {count => 'feature_relationship_objects.subject_id'}],
                as => ['feature_id', 'id', 'function', 'locus_count'],
                group_by => [qw/me.feature_id me.uniquename featureprops.value/],
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        );
        
        map { $g1_totals{$_->{feature_id}} = $_; $g2_totals{$_->{feature_id}}->{locus_count} = 0 } $g1_counts->all;
    }

    if(@$_pri_g1) {
        my $pri_g1_counts = $schema->resultset('Feature')->search(
            {
                'me.type_id' => $type_ids->{pangenome},
                'pripub_feature_relationships.type_id' => $type_ids->{derives_from},
                'private_feature_relationship_subjects.type_id' => $type_ids->{part_of},
                'feature_relationship_subjects.object_id' => $_pri_g1,
                'private_featureprops.type_id' => $type_ids->{panseq_function} 
            },
            {
                join => [
                    {'pripub_feature_relationships' => {'subject' => 'private_feature_relationship_subjects'}},
                    'private_featureprops'
                ],
                select => ['me.feature_id', {count => 'pripub_feature_relationships.subject_id'}],
                as => ['feature_id', 'id', 'function', 'locus_count'],
                group_by => [qw/me.feature_id me.uniquename private_featureprops.value/]
            }
        );
        
        # Combine totals
        while (my $rhash = $pri_g1_counts->next) {
            
            if(defined $g1_totals{$rhash->{feature_id}}) {
                $g1_totals{$rhash->{feature_id}}->{locus_count} += $rhash->{locus_count}
            } else {
                $g1_totals{$rhash->{feature_id}} = $rhash;
                $g2_totals{$rhash->{feature_id}}->{locus_count} = 0;
            }   
        }
    }
    
    if(@$_pub_g2) {
        my $g2_counts = $schema->resultset('Feature')->search(
            {
                'me.type_id' => $type_ids->{pangenome},
                'feature_relationship_objects.type_id' => $type_ids->{derives_from},
                'feature_relationship_subjects.type_id' => $type_ids->{part_of},
                'feature_relationship_subjects.object_id' => $_pub_g2,
                'featureprops.type_id' => $type_ids->{panseq_function} 
            },
            {
                join => [
                    {'feature_relationship_objects' => {'subject' => 'feature_relationship_subjects'}},
                    'featureprops'
                ],
                select => ['me.feature_id', 'me.uniquename', 'featureprops.value', {count => 'feature_relationship_objects.subject_id'}],
                as => ['feature_id', 'id', 'function', 'locus_count'],
                group_by => [qw/me.feature_id me.uniquename featureprops.value/],
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        );
        
        # Combine totals
        while (my $rhash = $g2_counts->next) {
            
            if(defined $g2_totals{$rhash->{feature_id}}) {
                $g2_totals{$rhash->{feature_id}}->{locus_count} += $rhash->{locus_count}
            } else {
                my $num = $rhash->{locus_count};
                $rhash->{locus_count} = 0;
                $g1_totals{$rhash->{feature_id}} = $rhash;
                $g2_totals{$rhash->{feature_id}}->{locus_count} = $num;
            }   
        }
    }

    if(@$_pri_g2) {
        my $pri_g2_counts = $schema->resultset('Feature')->search(
            {
                'me.type_id' => $type_ids->{pangenome},
                'pripub_feature_relationships.type_id' => $type_ids->{derives_from},
                'private_feature_relationship_subjects.type_id' => $type_ids->{part_of},
                'feature_relationship_subjects.object_id' => $_pri_g2,
                'private_featureprops.type_id' => $type_ids->{panseq_function} 
            },
            {
                join => [
                    {'pripub_feature_relationships' => {'subject' => 'private_feature_relationship_subjects'}},
                    'private_featureprops'
                ],
                select => ['me.feature_id', {count => 'pripub_feature_relationships.subject_id'}],
                as => ['feature_id', 'id', 'function', 'locus_count'],
                group_by => [qw/me.feature_id me.uniquename private_featureprops.value/]
            }
        );
        
        # Combine totals
        while (my $rhash = $pri_g2_counts->next) {
            
            if(defined $g2_totals{$rhash->{feature_id}}) {
                $g2_totals{$rhash->{feature_id}}->{locus_count} += $rhash->{locus_count}
            } else {
                my $num = $rhash->{locus_count};
                $rhash->{locus_count} = 0;
                $g1_totals{$rhash->{feature_id}} = $rhash;
                $g2_totals{$rhash->{feature_id}}->{locus_count} = $num;
            }   
        }
    }
    
    return (\%g1_totals, \%g2_totals);
}

sub countSnps {
    my ($schema, $_pub_g1, $_pri_g1, $_pub_g2, $_pri_g2, $tot1, $tot2) = @_;
    
    my (%g1_snps, %g2_snps);
    
    if(@$_pub_g1) {
        
        my $g1_counts = snpQuery(1, $_pub_g1);
        
        while (my $snp_row = $g1_counts->next) {
            my $snp_id = $snp_row->{snp};
            my $snp = $snp_row->{allele};
            my $bkg = $snp_row->{background};
            my $num = $snp_row->{count};
            
            unless($g1_snps{$snp_id}) {
                #my ($frag, $func) = $schema->resultset('SnpCore')->find($snp_id,{}
                
                my $frag = $snp_row->{fragment};
                my $func = $snp_row->{function};
                
                $g1_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                $g2_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                
                $g1_snps{$snp_id}{$bkg} = $tot1;
                $g2_snps{$snp_id}{$bkg} = $tot2;
                
                # Functional descriptors only needed for group1
                $g1_snps{$snp_id}{feature_id} = $snp_id;
                $g1_snps{$snp_id}{id} = "Snp $snp_id in pan-genome fragment $frag";
                $g1_snps{$snp_id}{function} = $func;
            }
            
            $g1_snps{$snp_id}{$snp} = $num;
            $g1_snps{$snp_id}{$bkg} -= $num;
            
            
        }
    }
    
    if(@$_pri_g1) {
        
        my $g1_counts = snpQuery(0, $_pri_g1);
        
        while (my $snp_row = $g1_counts->next) {
            my $snp_id = $snp_row->{snp};
            my $snp = $snp_row->{allele};
            my $bkg = $snp_row->{background};
            my $num = $snp_row->{count};
            
            unless($g1_snps{$snp_id}) {
                my $frag = $snp_row->{fragment};
                my $func = $snp_row->{function};
                
                $g1_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                $g2_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                
                $g1_snps{$snp_id}{$bkg} = $tot1;
                $g2_snps{$snp_id}{$bkg} = $tot2;
                
                # Functional descriptors only needed for group1
                $g1_snps{$snp_id}{feature_id} = $snp_id;
                $g1_snps{$snp_id}{id} = "Snp $snp_id in pan-genome fragment $frag";
                $g1_snps{$snp_id}{function} = $func;
            }
            
            $g1_snps{$snp_id}{$snp} += $num;
            $g1_snps{$snp_id}{$bkg} -= $num;
        }
    }
    
    if(@$_pub_g2) {
        
        my $g2_counts = snpQuery(1, $_pub_g2);
        
        while (my $snp_row = $g2_counts->next) {
            my $snp_id = $snp_row->{snp};
            my $snp = $snp_row->{allele};
            my $bkg = $snp_row->{background};
            my $num = $snp_row->{count};
            
            unless($g2_snps{$snp_id}) {
                # Never seen this snp position before
                my $frag = $snp_row->{fragment};
                my $func = $snp_row->{function};
                
                $g1_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                $g2_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                
                $g1_snps{$snp_id}{$bkg} = $tot1;
                $g2_snps{$snp_id}{$bkg} = $tot2;
                
                # Functional descriptors only needed for group1
                $g1_snps{$snp_id}{feature_id} = $snp_id;
                $g1_snps{$snp_id}{id} = "Snp $snp_id in pan-genome fragment $frag";
                $g1_snps{$snp_id}{function} = $func;
            }
            
            $g2_snps{$snp_id}{$snp} += $num;
            $g2_snps{$snp_id}{$bkg} -= $num;
            
        }
    }
    
    if(@$_pri_g2) {
        
        my $g2_counts = snpQuery(0, $_pri_g2);
        
        while (my $snp_row = $g2_counts->next) {
            my $snp_id = $snp_row->{snp};
            my $snp = $snp_row->{allele};
            my $bkg = $snp_row->{background};
            my $num = $snp_row->{count};
            
            unless($g2_snps{$snp_id}) {
                # Never seen this snp position before
                my $frag = $snp_row->{fragment};
                my $func = $snp_row->{function};
                
                $g1_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                $g2_snps{$snp_id} = {A => 0, G => 0, C => 0, T => 0};
                
                $g1_snps{$snp_id}{$bkg} = $tot1;
                $g2_snps{$snp_id}{$bkg} = $tot2;
                
                # Functional descriptors only needed for group1
                $g1_snps{$snp_id}{feature_id} = $snp_id;
                $g1_snps{$snp_id}{id} = "Snp $snp_id in pan-genome fragment $frag";
                $g1_snps{$snp_id}{function} = $func;
            }
            
            $g2_snps{$snp_id}{$snp} += $num;
            $g2_snps{$snp_id}{$bkg} -= $num;
        }
    }
    
    return(\%g1_snps, \%g2_snps);
}
