#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Bio::SeqIO;

=head1 NAME

$0 - Count and summarize the attribute tags for the source feature in genbank files

=head1 SYNOPSIS

  % $0 [arguments]

=head1 ARGUMENTS

 --genbank_dir             Directory containing genbank files (with ext .gbk)
 --log_file                Results log file name

=head1 DESCRIPTION

  Counts occurences of attribute tags and their values for the source feature in a series
  of genbank files (.gbk). Used to summarize the scope of the attribute tags.

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

$|=1;

my ($DIR, $LOGFILE, $DEBUG);

GetOptions(
	'genbank_dir=s'=> \$DIR,
    'log_file=s'=> \$LOGFILE,
    'debug' => \$DEBUG
) || pod2usage(-verbose => 1) && exit;

# Log file contains results
open(LOG, ">$LOGFILE") or die "Cannot open log file $LOGFILE ($!).\n";

my $genbank_files = _getGenbankFileNames($DIR);
my $total_files = scalar(@$genbank_files);
my $val_length = 30;

my %fp_records;
my %anno_records;
my %gb_records;

my $num_processed=0;
my $total_seqobjs;
foreach my $gbfile (@$genbank_files) {
	my $io;
	eval {
		$io = Bio::SeqIO->new(-file => $gbfile, -format => "genbank" );
	};
	if($@) {
		print "CAUGHT ERROR: $@\n" if $DEBUG;
	}
	
	my $seq_count=0;
	
	while(my $seq_obj = $io->next_seq) {
		
		my $anno_collection = $seq_obj->annotation;
	
		_summarizeAnnotations($anno_collection, \%anno_records);
		
		my $sf_count=0;
		foreach my $src_feat ( $seq_obj->get_SeqFeatures('source') ) {
			_summarizeFeatureProps($src_feat, \%fp_records);
			$sf_count++;
		}
		
		if($sf_count > 1) {
			$fp_records{more_than_one_source_feature}++;
			
		} elsif($sf_count == 0) {
			$fp_records{no_source_feature}++;
			
		}
		$seq_count++;
		$total_seqobjs++;
	}
	
	if($seq_count > 1) {
		$gb_records{more_than_one_sequence_obj}++;
		
	} elsif($seq_count == 0) {
		$gb_records{no_sequence_obj}++;
		
	}
	$num_processed++;     
	print "$num_processed of $total_files processed.\n" if $num_processed % 10 == 0;
}

_writeReport(\%anno_records,\%fp_records,\%gb_records);

close LOG;


############
# Subs
############



=head2 _getCurrentFileNames

Get list of genbank files in a directory (*.gbk).

=cut

sub _getGenbankFileNames{
	my $download_dir = shift;

	opendir DIR, $download_dir;
	my @genbankFiles = grep { /gbk/ } readdir DIR;
	closedir DIR;

	
	if($DEBUG) {
		print "genbank files:\n",join("\n",@genbankFiles); 
	}
	
	my @final = map { $download_dir . $_ } @genbankFiles;
       
	return \@final;
}


=head2 _summarizeAnnotations

Summerize the annotations in a genbank file

=cut

sub _summarizeAnnotations {
	my ($anno_collection, $record) = @_;

	for my $key ( $anno_collection->get_all_annotation_keys ) {
		
		my @annotations = $anno_collection->get_Annotations($key);
	
		for my $value ( @annotations ) {
			my $tag = uc $value->tagname;
			my $val = substr(uc $value->display_text, 0, $val_length);
			$record->{count}->{$tag}++;
			$record->{vals}->{$tag}->{$val}++;
			$record->{num_tag_occ}++;
		}
		$record->{num_files_with_given_tags}++;
	}
	$record->{num_annotation_blocks}++;
}

=head2 _summarizeFeatureProps

Summerize the tags under the SOURCE feature in a genbank file

=cut

sub _summarizeFeatureProps {
	my ($source_feature, $record) = @_;

	for my $tag ($source_feature->get_all_tags) {
		my $ftag = uc $tag;
		                       
		for my $value ($source_feature->get_tag_values($tag)) {                
			my $fval = substr(uc $value, 0, $val_length);
			$record->{count}->{$ftag}++;
			$record->{vals}->{$ftag}->{$fval}++;
			$record->{num_tag_occ}++;      
		}
		$record->{num_files_with_given_tags}++;         
	}
	$record->{num_source_features}++;   
}

=head2 _writeReport

Print out report

=cut

sub _writeReport {
	my ($anno_records, $fp_records, $gb_records) = @_;
	
	my %repeated_values;
	
	print LOG "# Results from explore_genbank_tags.pl\n# Date: " . localtime() . "\n";
	
	print LOG "\n## --- MAIN ---\n";
	print LOG "Number of genbank files: $total_files\n";
	print LOG "Number of genbank sequence objects: $total_seqobjs\n";
	print LOG "Number of genbank files with no sequence objects: $gb_records->{no_sequence_obj}\n" if $gb_records->{no_sequence_obj};
	print LOG "Number of genbank files with more than one sequence objects: $gb_records->{more_than_one_sequence_obj}\n" if $gb_records->{more_than_one_sequence_obj};
	
	print LOG "\n## --- ANNOTATIONS ---\n";
	print LOG "Number of genbank files: $total_files\n";
	print LOG "Number of genbank sequence objects: $total_seqobjs\n";
	print LOG "Number of annotation blocks: $anno_records->{num_annotation_blocks} (" . 
		sprintf("%.3f", ($anno_records->{num_annotation_blocks}/$total_seqobjs*100)) . "%)\n";
	print LOG "Ave number of tags in annotation blocks: " . 
		sprintf("%.3f", ($anno_records->{num_tag_occ} / $anno_records->{num_annotation_blocks})) . "\n";
	print LOG "Ave number of of distinct tags in annotation blocks: " . 
		sprintf("%.3f", ($anno_records->{num_files_with_given_tags} / $anno_records->{num_annotation_blocks})) . "\n";
	print LOG "VALUES:\n";
	
	my @tags = sort { $anno_records->{count}->{$b} <=> $anno_records->{count}->{$a} } keys %{$anno_records->{count}};
	my $line_num=1;
	foreach my $tag (@tags) {
		print LOG "$line_num\.  $tag ($anno_records->{count}->{$tag} occ)\n";
		my @vals = sort { $anno_records->{vals}->{$tag}->{$b} <=> $anno_records->{vals}->{$tag}->{$a} } keys %{$anno_records->{vals}->{$tag}};
		
		foreach my $val (@vals) {
			print LOG "\t$val seen  $anno_records->{vals}->{$tag}->{$val} times.\n";
		}
		$line_num++;
	}
	
	print LOG "\n## --- FEATURE PROPERTIES ---\n";
	print LOG "Number of genbank files: $total_files\n";
	print LOG "Number of genbank sequence objects: $total_seqobjs\n";
	print LOG "Number of SOURCE features: $fp_records->{num_source_features} (" . 
		sprintf("%.3f", ($fp_records->{num_source_features}/$total_seqobjs*100)) . "%)\n";
	print LOG "Number of genbank files with no SOURCE features: $fp_records->{no_source_feature}\n" if $fp_records->{no_source_feature};
	print LOG "Number of genbank files with more than one SOURCE feature: $fp_records->{more_than_one_source_feature}\n" if $fp_records->{more_than_one_source_feature};
	print LOG "Ave number of tags in SOURCE: " . 
		sprintf("%.3f", ($fp_records->{num_tag_occ} / $fp_records->{num_source_features})) . "\n";
	print LOG "Ave number of of distinct tags in SOURCE: " . 
		sprintf("%.3f", ($fp_records->{num_files_with_given_tags} / $fp_records->{num_source_features})) . "\n";
	print LOG "VALUES:\n";
	
	my @tags2 = sort { $fp_records->{count}->{$b} <=> $fp_records->{count}->{$a} } keys %{$fp_records->{count}};
	my $line_num2=1;
	foreach my $tag (@tags2) {
		print LOG "$line_num2\.  $tag ($fp_records->{count}->{$tag} occ)\n";
		my @vals = sort { $fp_records->{vals}->{$tag}->{$b} <=> $fp_records->{vals}->{$tag}->{$a} } keys %{$fp_records->{vals}->{$tag}};
		
		foreach my $val (@vals) {
			print LOG "\t$val seen  $fp_records->{vals}->{$tag}->{$val} times.\n";
			$repeated_values{$val}{$tag}++;
		}
		$line_num2++;
	}
	
	my @synonyms;
	foreach my $val (keys %repeated_values) {
		if(scalar(keys %{$repeated_values{$val}}) > 1) {
			push @synonyms, $val;
		}
	}
	
	print LOG "REPEATED VALUES FOR DIFFERENT TAGS:\n";
	my $line_num3 = 1;
	foreach my $val (@synonyms) {
		print LOG "$line_num3\.  Value $val\n";
		my @tags = sort { $repeated_values{$val}{$b} <=> $repeated_values{$val}{$a} } keys %{$repeated_values{$val}};
		
		foreach my $tag (@tags) {
			
			print LOG "\t$tag tag used $repeated_values{$val}{$tag} times.\n";
		}
		$line_num3++;
	}
	
}