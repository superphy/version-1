#!/usr/bin/env perl

use strict;
use warnings;
use Net::FTP;
use LWP;
use IO::File;
use Getopt::Long;
use Archive::Extract;
use File::Copy;
use Pod::Usage;

=head1 NAME

$0 - Download genbank files to retrieve meta data.

=head1 SYNOPSIS

  % $0 [arguments]

=head1 ARGUMENTS

 --dir             Directory to store files
 --file_prefix     File containing list of 4 letter prefixes for wgs sequences or 
                   longer bacteria names for complete genome sequences

=head1 DESCRIPTION

  Downloads master genbank files matching one of the the supplied 4 letter prefixes 
  from the genbank wgs ftp site.
  
  Downloads all closed chromosome / plasmids genbank files from the genbank genome
  ftp site.

=head1 AUTHORS

Matthew Whiteside E<lt>matthew.whiteside@phac-aspc.gc.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my ($DIR, $PRE_FILE, $DEBUG);

GetOptions(
	'dir=s'=> \$DIR,
    'file_prefix=s'=> \$PRE_FILE,
    'debug' => \$DEBUG
) || pod2usage(-verbose => 1) && exit;

# Load the WGS ID prefixes
open(IN, "<$PRE_FILE") or die "Error: unable to prefix file $PRE_FILE ($!).\n";

my @tmp = <IN>;

close IN;

my %wgs_prefixes;
my %closed_names;
map { chomp; if(m/^\w{4}$/) { $wgs_prefixes{$_} = 1 } else { $closed_names{$_} = 1 } } @tmp;

# Download the WGS genbank files
downloadWGSGenomes($DIR, \%wgs_prefixes);

# Download the completed genomes genbank files
downloadClosedGenomes($DIR, \%closed_names);


############
# Subs
############

=head2 _getCurrentFileNames

Get list of file prefixes that are already downloaded in download
directory.

=cut

sub downloadWGSGenomes {
	my $download_directory = shift;
	my $ncbiGenomesHashRef = shift;
	
	my $ftp_directory = 'genbank/wgs/';   

	# Get list of already downloaded genomes
    my $currentFilesHashRef = _getCurrentFileNames($download_directory);
    
    # Create array of new genomes for download on NCBI server
    my %genomesToDownload;
    foreach my $ncbiFile (keys %{$ncbiGenomesHashRef}) {
        #skip downloading existing files
        if($currentFilesHashRef->{$ncbiFile}) {
            next;
        } else{
            $genomesToDownload{$ncbiFile}=1;
		}
	}

	# download the genomes
    # change to genbank directory
	# sets up the parameters for ncbi ftp connection
    my $host = 'ftp.ncbi.nlm.nih.gov';

    # Connect to NCBI ftp site
    my $ftp = Net::FTP->new($host, Debug => 1, Passive => 1) or die "Cannot connect to genbank: $@";
    #log in as anonymous, use email as password
    $ftp->login("anonymous",'mdwhitesi@gmail.com') or die "Cannot login ", $ftp->message; 
    $ftp->cwd($ftp_directory) or die "Cannot change working directory ", $ftp->message;

    #get list of files on FTP
    my @ftpList = $ftp->ls();
    
    if($DEBUG) {
        print "Directory working in: " . $ftp->pwd() . "\n";
        print("The directory contains : \n");
        print(join("\n", @ftpList));
    }

    foreach my $ftpFile (@ftpList) {
        my $fileID;
        if($ftpFile =~ m/^wgs\.(\w\w\w\w)\.mstr\.gbff\.gz/) {
            $fileID=$1;
        } else{
            next;
        }

		# Check if this file is one in our prefix download list
		if($genomesToDownload{$fileID}){
			my $savedFile = $download_directory . $fileID . '.gbff.gz';
            
            # ascii mode messes up the data, must use binary
            $ftp->binary();
            $ftp->get($ftpFile, $savedFile) or (print("download of $ftpFile failed\n" and next));
            $ftp->ascii();

            # downloaded file is gz compressed
            # extract to fasta format
            my $extracter = Archive::Extract->new( 'archive' => $savedFile );
            $extracter->extract( 'to' => $download_directory ) or (die "Could not extract $savedFile\n" and next);
            
            # rename the extracted file via File::Copy
            my $extractedName = $download_directory . $extracter->files->[0];
            my $newName = $download_directory . $fileID . '.gbk';
            move($extractedName, $newName) or die "Could not move file $extractedName to $newName";      

            # delete the compressed file
            unlink $savedFile;
            
            $genomesToDownload{$fileID} = 0;

            if($DEBUG){
                 print("extracted file: $extractedName\n");
                 print("renamed to: $newName\n");
                 print("deleted: $savedFile\n");
            }     
        }
       
    }
    $ftp->quit();
    
    
    if($DEBUG) {
    	print "Genbank files were not obtained for the following IDs:";
    	foreach my $file (keys %genomesToDownload) {
    		print "Missing: $file" if $genomesToDownload{$file};
    	}
    }
}

=head2 downloadClosedGenomes

Get list of file prefixes that are already downloaded in download
directory.

=cut

sub downloadClosedGenomes {
    my $download_directory = shift;
    my $ncbiGenomesHashRef = shift;
    # ftp://ftp.ncbi.nlm.nih.gov/genbank/genomes/Bacteria/
    
    my $currentFilesHashRef = _getCurrentFileNames($download_directory);
    
    my %genomesToDownload;
    foreach my $ncbiFile (keys %{$ncbiGenomesHashRef}) {
        #skip downloading existing files
        if($currentFilesHashRef->{$ncbiFile}) {
            next;
        } else{
            $genomesToDownload{$ncbiFile}=1;
		}
	}

    #sets up the parameters for ncbi ftp connection
    my $host = 'ftp.ncbi.nlm.nih.gov';
    my $ftp_directory = 'genbank/genomes/Bacteria/';

    #constructs the connection
    my $ftp = Net::FTP->new($host, Debug => 0, Passive => 1) or die "Cannot connect to genbank: $@";
    $ftp->binary();

    #log in as anonymous, use email as password
    $ftp->login("anonymous",'mdwhitesi@gmail.com') or die "Cannot login ", $ftp->message; 
    $ftp->cwd($ftp_directory) or die "Cannot change working directory ", $ftp->message;

    #get list of files on FTP
    my @ftpList = $ftp->ls();
  
    foreach my $dir (@ftpList){
    	
        if($DEBUG){
             print($dir . "\n");
        }
        
        if($genomesToDownload{$dir}){
        	
            $ftp->cwd($dir) or (die "Cannot change to $dir" and next);

            my @ftpStrainFiles = $ftp->ls();

            #get current filenames in directory
            my @savedFiles;
            foreach my $strainFile (@ftpStrainFiles) {
            	
                if($strainFile =~ m/\.gbk/) {
                    #download the file
                    my $savedFile = $download_directory . $strainFile;
                    $ftp->binary();
                    $ftp->get($strainFile, $savedFile) or (warn("download of $strainFile failed\n" and next));
                    $ftp->ascii();
                    push @savedFiles, $savedFile;
                }
            }
            
            #combine all chromosome + plasmid files into same file
            #the $dir contains the strain name, and is what the DIR on FTP is named
            my $combinedFH = IO::File->new('>' . $download_directory . $dir . '.gbk') or (die "cannot create combined file");

            foreach my $singleFile (@savedFiles){
                my $inFH = IO::File->new('<' . $singleFile) or (die "Cannot open $singleFile");
                $combinedFH->print($inFH->getlines);
                $inFH->close();

                #remove local file after combining
                unlink $singleFile;
            }

            $combinedFH->close();

            #change back to parent directory
            $ftp->cdup();
            
            $genomesToDownload{$dir} = 0;
        }
    }
    
    if($DEBUG) {
    	print "Genbank files were not obtained for the following IDs:";
    	foreach my $file (keys %genomesToDownload) {
    		print "Missing: $file" if $genomesToDownload{$file};
    	}
    }
}


=head2 _getCurrentFileNames

Get list of file prefixes that are already downloaded in download
directory.

=cut

sub _getCurrentFileNames{
	my $download_dir = shift;

	opendir DIR, $download_dir;
	my @currentFiles = grep { $_ ne '.' && $_ ne '..' && $_ ne '.directory' } readdir DIR;
	closedir DIR;

	my %currentFiles;
	foreach my $currentFile(@currentFiles){
        my $name = $currentFile;
        
        if($name =~ m/^(.+)\./) {
        	$name = $1;
        };

        if($DEBUG){
            print "currentFile name: $name\n" ; 
        }
        $currentFiles{$name}=1;
	}
	return \%currentFiles;
}




 
