#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long;
use IO::File;
use IO::Dir;
use Bio::SeqIO;
use FindBin;
use lib "$FindBin::Bin/../";
use Config::Simple;
use Database::Chado::Schema;
use Carp qw/croak carp/;

#This script should parse the headers for the virluence factors from http://www.mgc.ac.cn/VFs/main.htm
	# An example of a fasta header from the multi-fasta file downloaded:

	# >R008730 sfaC (ECP_0291) - fimbrial transcription regulator protein FaeA [Escherichia coli str. 536 (UPEC)]

	# This should incorporate the tags:
		# Name: sfaC
		# Uniquename: ECP_0291

		#It will also be tagged with the type_id of pathogenesis in the feature table.

		#These tags will be incorporated as attributes in the featureprop table:
		# name: sfaC
		# uniquename: ECP_0291
		# description: fimbrial transcription regulator protein FaeA
		# organism: Escherichia coli
		# strain: 536
		# Keywords: Virulence Factor
		# comment: UPEC <- commented out for now since we cannot upload comments into chado
		# mol_type: plasmid <- this may or may not be there so we should just default to mol_type : dna


		my $VFFile = $ARGV[0];
		my $VFName;
		my $VFNumber = 0;
		my $VFfileName;

		parseVirulenceFactors();

		sub parseVirulenceFactors {
			system("mkdir VFfastaTemp") == 0 or die "System with args failed: $?\n";
			system("mkdir VFgffsTemp") == 0 or die "System with args failed: $?\n";
			system("mkdir VFgffsToUpload") == 0 or die "System with args failed: $?\n";
			readInHeaders();
			aggregateGffs();
			uploadSequences();
			system("rm -r VFfastaTemp") == 0 or die "System with args failed: $?";
			system("rm -r VFgffsTemp") == 0 or die "System with args failed: $?";
			system("rm -r VFgffsToUpload") == 0 or die "System with args failed: $?";
			print $VFNumber . " virulence factors have been parsed and uploaded to the database \n";
		}

		sub readInHeaders {
			my $in = Bio::SeqIO->new(-file => "$VFFile" , -format => 'fasta');
			my $out;
			while(my $seq = $in->next_seq()) {
				$VFfileName = "VirluenceFactor" . $seq->id . ".fasta";
				$VFNumber++;
				$out = Bio::SeqIO->new(-file => '>' . "VFfastaTemp/$VFfileName" , -format => 'fasta') or die "$!\n";
				$out->write_seq($seq) or die "$!\n";
				my $seqHeader = $seq->desc();
				my $seqId = $seq->id();
				my $attributeHeaders = parseHeader($seqId , $seqHeader);
				appendAttributes($attributeHeaders , $VFfileName);
			}
		}

		sub parseHeader {
			my $_seqId = shift;
			my $_seqHeader = shift;
			my $_seqTag = "$_seqId $_seqHeader";
			my %_seqHeaders;
			if ($_seqTag =~ m/^(R\d{6})\s([\w\d\/]+)/) {
				my $name = $2;
				my $virulence_id = $1;
				$_seqHeaders{'VIRULENCE_ID'} = $virulence_id;
				$_seqHeaders{'NAME'} = $name;
				$_seqHeaders{'UNIQUENAME'} = $name;
			}
			if ($_seqTag =~ m/(\()([\w\d\]*_?[\w\d]*)(\))/) {
				my $uniquename = $2;
				$_seqHeaders{'UNIQUENAME'} = $uniquename;
			}
			if ($_seqTag =~ m/\[(Escherichia coli)\s(str\.)\s([\w\d\W\D]*)\s(\()([\w\d\W\D]*)(\))\]/){
				my $organism = $1;
				$_seqHeaders{'ORGANISM'} = $organism;
				my $strain = $3;
				$_seqHeaders{'STRAIN'} = $strain;
				my $comment = $5;
				$_seqHeaders{'COMMENT'} = $comment;
			}
			if ($_seqTag =~ m/\s\-\s([w\d\W\D]*)\s(\[)/) {
				my $desc = $1;
				$_seqHeaders{'DESCRIPTION'} = $desc;
			}
			if ($_seqTag =~ m/(str\.)\s([\w\d\W\D]*)\s(\()([\w\d\W\D]*)(\))\s(plasmid)\s(.*)\]/) {
				my $plasmid = $7;
				my $strain = $2;
				$_seqHeaders{'MOLTYPE'} = "plasmid";
				$_seqHeaders{'PLASMID'} = $plasmid;
				$_seqHeaders{'ORGANISM'} = "Escherichia coli";
				$_seqHeaders{'STRAIN'} = $strain;
			}
			else {
				$_seqHeaders{'MOLTYPE'} = "dna";
				$_seqHeaders{'PLASMID'} = "none";
			}
			$_seqHeaders{'KEYWORDS'} = "Virulence Factor";

			foreach my $key (keys %_seqHeaders) {
				print "$key: " . $_seqHeaders{$key} . "\n";
			}

			return \%_seqHeaders;
		}

		sub appendAttributes {
			my $attHeaders = shift;
			my $VFfileName = shift;
			my $attributes = getAtrributes($attHeaders);
			my $inSeq = Bio::SeqIO->new(-file => "VFfastaTemp/$VFfileName" , -format => 'fasta');

			my $outFile = "VFgffsTemp/tempout$VFNumber.gff";

			my $args = "gmod_fasta2gff3.pl" . " $VFfileName" . " --type gene" . " --attributes " . "\"$attributes\"" . " --fasta_dir VFfastaTemp " . "--gfffilename VFgffsTemp/tempout$VFNumber.gff";
			system($args) == 0 or die "System with $args failed: $? \n";
			#printf "System executed $args with value %d\n", $? >> 8;
			open my $in, '<' , "$outFile" or die "Can't read $VFfileName: $!";
			open my $out, '>' , "VFgffsTemp/new_tempout$VFNumber.gff";
			#Files need to be fixed before uploading
			while(<$in>) {
				my $tag;
				if ($. == 1 || $. == 2 || $. == 4 || $. == 6) {
					print $out $_;
				}
				if ($. == 3) {
					if ($_ =~ /(\t.\t(gene)\t([\d]*)\t([\d]*)\t.\t.\t.\t)/) {
						$tag = $1;
					}
					else {
						die "$!";
					}
					print $out $attHeaders->{UNIQUENAME}.$tag."ID=".$attHeaders->{UNIQUENAME}.";Name=".$attHeaders->{NAME}.";$attributes\n";
				}
				if ($. == 5){
					print $out ">".$attHeaders->{UNIQUENAME}."\n";
				}
				else {
				}
			}
			close $in;
			close $out;
			unlink "VFfastaTemp/$VFfileName";
			unlink "$outFile";
			unlink "VFfastaTemp/directory.index";
		}

		sub getAtrributes {
			my $_attHeaders = shift;

			if (($_attHeaders->{NAME} eq "") || 
				($_attHeaders->{UNIQUENAME} eq "") || 
				($_attHeaders->{DESCRIPTION} eq "") || 
				($_attHeaders->{KEYWORDS} eq "") || 
				($_attHeaders->{MOLTYPE} eq "") || 
				($_attHeaders->{PLASMID} eq "") || 
				($_attHeaders->{ORGANISM} eq "") ||
				($_attHeaders->{STRAIN} eq "")) 
			{
				print "Name: " . $_attHeaders->{NAME} . "\n";
				print "Virulence ID: " . $_attHeaders->{VIRULENCE_ID} . "\n";
				print "uniquename: " . $_attHeaders->{UNIQUENAME} . "\n";
				print "Description: " . $_attHeaders->{DESCRIPTION} . "\n";
				print "Keywords: " . $_attHeaders->{KEYWORDS} . "\n";
				print "Mol_Type: " . $_attHeaders->{MOLTYPE} . "\n";
				print "Plasmid: " . $_attHeaders->{PLASMID} . "\n";
				print "Organism: " . $_attHeaders->{ORGANISM} . "\n";
				print "Strain: " . $_attHeaders->{STRAIN} . "\n";
				print "Unsuccessful header parsing! \n";
				die "!$\n";
			}
			else {
				my $_attributes = "name=".$_attHeaders->{NAME} . ";".
				"uniquename=". $_attHeaders->{UNIQUENAME} . ";".
				"virulence_id=". $_attHeaders->{VIRULENCE_ID} . ";".
				"description=". $_attHeaders->{DESCRIPTION} . ";".
				"keywords=". $_attHeaders->{KEYWORDS} . ";".
				"mol_type=". $_attHeaders->{MOLTYPE} . ";".
				"plasmid=". $_attHeaders->{PLASMID} . ";" .
				"organism=". $_attHeaders->{ORGANISM} . ";".
				"strain=". $_attHeaders->{STRAIN} . ";" .
				"biological_process=pathogenesis";
				print "Header parsed succesfully! \n";
				return $_attributes;
			}
		}

		sub aggregateGffs {
			opendir (TEMP , "VFgffsTemp") or die "Couldn't open directory VFgffsTemp , $!\n";
			while (my $file = readdir TEMP)
			{
				writeOutFile($file);
				unlink "VFgffsTemp/$file";
			}
			mergeFiles();
			closedir TEMP;
		}

		sub writeOutFile {
			my $file = shift;
			my $tempTagFile = "VFgffsToUpload/tempTagFile";
			my $tempSeqFile = "VFgffsToUpload/tempSeqFile";
			open my $in , '<' , "VFgffsTemp/$file" or die "Can't read $file: $!";
			open my $outTags, '>>' , $tempTagFile or die "Cant write to the $tempTagFile: $!";
			open my $outSeqs, '>>' , $tempSeqFile or die "Cant write to the $tempSeqFile: $!";
			#Need to print out line 3 and (5 + 6) specifically
			while (<$in>) {
				if ($. == 3) {
					print $outTags $_;
				}
				if ($. == 5 || $. == 6){
					print $outSeqs $_;
				}
				else{
				}
			}
			close $outTags;
			close $outSeqs;
		}

		sub mergeFiles {
		#Merge tempFiles into a single gff file.
		my $tempTagFile = "VFgffsToUpload/tempTagFile";
		my $tempSeqFile = "VFgffsToUpload/tempSeqFile";
		if ($tempTagFile && $tempSeqFile) {
			my $genomeFileName = "out.gff";
			open my $inTagFile, '<' , $tempTagFile or die "Can't read $tempTagFile: $!";
			open my $inSeqFile, '<' , $tempSeqFile or die "Can't read $tempSeqFile: $!";
			open my $out, '>>' , "VFgffsToUpload/$genomeFileName";
			while (my $line = <$inTagFile>) {
				print $out $line;
			}
			close $inTagFile;
			print $out "##FASTA\n";
			while (my $line = <$inSeqFile>) {
				print $out $line;
			}
			close $inSeqFile;
			close $out;
			unlink "$tempTagFile";
			unlink "$tempSeqFile";
		}
		else {
		}
	}

	sub uploadSequences {
		opendir (GFF , "VFgffsToUpload") or die "Couldn't open directory VFgffsToUpload , $!\n";
		my ($dbName , $dbUser , $dbPass) = hashConfigSettings();
		while (my $gffFile = readdir GFF) {
			if ($gffFile eq "." || $gffFile eq "..") {
			}
			else {
				my $dbArgs = "gmod_bulk_load_gff3.pl --dbname $dbName --dbuser $dbUser --dbPass $dbPass --organism \"Escherichia coli\" --gfffile VFgffsToUpload/$gffFile";
				system($dbArgs) == 0 or die "System failed with $dbArgs: $? \n";
				printf "System executed $dbArgs with value %d\n", $? >> 8;
			}
		}
		closedir GFF;
	}

	sub hashConfigSettings {
		my $configLocation = "$FindBin::Bin/../Modules/genodo.cfg";
		open my $in, '<' , $configLocation or die "Cannot open $configLocation: $!\n";
		my ($dbName , $dbUser , $dbPass);
		while (my $confLine = <$in>) {
			if ($confLine =~ /name = ([\w\d]*)/){
				$dbName = $1;
				next;
			}
			if ($confLine =~ /user = ([\w\d]*)/){
				$dbUser = $1;
				next;
			}
			if ($confLine =~ /pass = ([\w\d]*)/){
				$dbPass = $1;
				next;
			}
			else{
			}
		}
		return ($dbName , $dbUser , $dbPass);
	}
