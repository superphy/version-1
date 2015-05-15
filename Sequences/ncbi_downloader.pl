#!/usr/bin/env perl
#NCBI FTP Downloader
#Chad Laing and Peter Shen

use strict;
use warnings;
use Net::FTP;
use LWP;
use IO::File;
use Getopt::Long;
use Archive::Extract;
use File::Copy;

#sets up a debug version
my $DEBUG = 1;

#get command line info
my $settings = _getSettings(\@ARGV);

#creates a log file     
my $log = IO::File->new('>' . $settings->{'log'}) or die "Can't open download.log";
$log->print("Beginning run: " . localtime() . "\n");
main();

sub main{
    #get correct NCBI FTP directory and genome lists
    $log->print("In main\n");

    my $directory;
    my $genomesHashRef;
    if($settings->{'ncbi_database'} eq 'closed'){
        $directory='genbank/genomes/Bacteria/';
        #$hash->{'AE017220'}='Salmonella_enterica_Choleraesuis_uid9618' etc.
        $genomesHashRef = _downloadClosedGenomes($directory);
    }
    elsif($settings->{'ncbi_database'} eq 'wgs'){
        $directory = 'genbank/wgs/';
        $log->print("Attempting to get NCBI WGS sequence list\n");
        #$hash->{'ABAK'}='Salmonella enterica subsp. enterica serovar Kentucky str. CVM29188' etc.
        $genomesHashRef = _getWGSGenomes();
        _downloadGenomes($directory,$genomesHashRef);
    }
    else{
        $log->print("Incorrect ncbi_database setting\n");
        exit(1);
    } 

    $log->close();
}

sub _getSettings{
    my $arrayRef=shift;

    my %settings;
    #default log file location
    $settings{'log'}='>ncbi_downloader.log';

    #note that the search terms is an exact match, starting at the beginning of the text string on NCBI
    #this 'Salmonella' matches, 'Salmonella enterica' matches, but 'enterica' does not
    #include the wildcard '*enterica' to match all strings containing

    GetOptions(
        'ncbi=s' => \$settings{'ncbi_database'},
        'log:s' => \$settings{'log'},
        'terms=s' => \$settings{'search_terms'},
        'dir=s' => \$settings{'download_dir'}
    );    
    return \%settings;
}

sub _getWGSGenomes{
    #current list of project names and organisms is at:
    #http://www.ncbi.nlm.nih.gov/projects/WGS/WGSprojectlist.cgi seems deprecated
    #instead use http://www.ncbi.nlm.nih.gov/Traces/wgs/?&size=all&term=salmonella%20enterica for example
    #to download tab-delimited text
    #http://www.ncbi.nlm.nih.gov/Traces/wgs/?&size=1000000&term=salmonella%20enterica&order=prefix&dir=asc&version=last&state=live&update_date=any&create_date=any&retmode=text&page=1

    $log->print("Search terms: " . $settings->{'search_terms'} . "\n");
    my $url = 'http://www.ncbi.nlm.nih.gov/Traces/wgs/?&size=all&term=' 
        . $settings->{'search_terms'}
        . '&order=prefix&dir=asc&version=last&state=live&update_date=any&create_date=any&retmode=text&page=1';
    
    $log->print("Url:\n$url\n");

    my $browser = LWP::UserAgent->new();
    my $response = $browser->get($url);
    die "Can't get $url -- ", $response->status_line unless $response->is_success;

    #get each result entry as its own array item
    #create hash of 4-letter id and name
    my %strainsHash;
    my @strains = split('\n',$response->content);
    foreach my $strain(@strains){
        if($strain =~ /^\#/){
            next;
        }
        my @la = split('\t', $strain) or die "Cannot split $strain";
        my $id = $la[0];
        
        #we need to use the scaffold assembly if it exists in preference to the wgs
        #eg. NZ_ABAK02 supersedes ABAK02, so store the scaffold assembly in ABAK key, and not the WGS
        my $finalId;
        if(substr($id,2,1) eq '_'){
            $finalId = substr($id,3,4);
        }
        else{
            $finalId=substr($id,0,4);

             if($strainsHash{$finalId}){
                next;
             }
        }

        my $name = $la[4];
        $name =~ s/"//g;
        $strainsHash{$finalId}=$name;
    }

    return \%strainsHash;
}

sub _downloadGenomes{
    my $directory = shift;
    my $ncbiGenomesHashRef=shift;   

    if($DEBUG){
        $log->print("Strains retrieved from NCBI WGS:\n");
        foreach my $key(keys %{$ncbiGenomesHashRef}){
            $log->print("$key : " . $ncbiGenomesHashRef->{$key} . "\n");
        }
    }


    my $currentFilesHashRef = _getCurrentFileNames();
    
    #create array of new genomes for download on NCBI server
    my %genomesToDownload;
    foreach my $ncbiFile(keys %{$ncbiGenomesHashRef}){
        #skip downloading existing files
        if($currentFilesHashRef->{$ncbiFile}){
            next;
        }
        else{
            $genomesToDownload{$ncbiFile}=1;
        }
    }

    #download the genomes
    #change to genbank directory
     #sets up the parameters for ncbi ftp connection
    my $host = 'ftp.ncbi.nlm.nih.gov';

    #constructs the connection
    my $ftp = Net::FTP->new($host, Debug => 1,Passive => 0) or die "Cannot connect to genbank: $@";
    #log in as anonymous, use email as password
    $ftp->login("anonymous",'chadlaing@gmail.com') or die "Cannot login ", $ftp->message; 
    $ftp->cwd($directory) or die "Cannot change working directory ", $ftp->message;

    #get list of files on FTP
    my @ftpList = $ftp->ls();

    if($DEBUG){
        $log->print("Directory working in: " . $ftp->pwd() . "\n");
        $log->print("The directory contains : \n");
        $log->print(join("\n", @ftpList));
    }

    foreach my $ftpFile(@ftpList){
        my $fileID;
        if($ftpFile =~ m/^wgs\.(\w\w\w\w).+fsa_nt\.gz/){
            $fileID=$1;
        }
        else{
            next;
        }
        unless($genomesToDownload{$fileID}){
            next;
        }

        if($genomesToDownload{$fileID}){
            my $savedFile = $settings->{'download_dir'} . $fileID . '.gz';
            
            #ascii mode messes up the data, must use binary
            $ftp->binary();
            $ftp->get($ftpFile, $savedFile) or ($log->print("download of $ftpFile failed\n" and next));
            $ftp->ascii();

            #downloaded file is gz compressed
            #extract to fasta format
            my $extracter = Archive::Extract->new('archive'=>$savedFile);
            $extracter->extract('to'=>$settings->{'download_dir'}) or (die "Could not extract $savedFile\n" and next);
            
            #rename the extracted file via File::Copy
            my $extractedName = $settings->{'download_dir'}. $extracter->files->[0];
            my $newName = $settings->{'download_dir'} . $fileID . '.fasta';
            move($extractedName,$newName);      

            #delete the compressed file
            unlink $savedFile;

            if($DEBUG){
                 $log->print("extracted file: $extractedName\n");
                 $log->print("renamed to: $newName\n");
                 $log->print("deleted: $savedFile\n");
            }     
        }
        else{
            $log->print("\nCould not locate $fileID in remote FTP directory!\n");
        }
    }
    $ftp->quit();
}

sub _downloadClosedGenomes{
    my $directory=shift;
    #ftp://ftp.ncbi.nlm.nih.gov/genbank/genomes/Bacteria/

    #sets up the parameters for ncbi ftp connection
    my $host = 'ftp.ncbi.nlm.nih.gov';

    #constructs the connection
    my $ftp = Net::FTP->new($host, Debug => 0) or die "Cannot connect to genbank: $@";
    $ftp->binary();

    #log in as anonymous, use email as password
    $ftp->login("anonymous",'chadlaing@gmail.com') or die "Cannot login ", $ftp->message; 
    $ftp->cwd($directory) or die "Cannot change working directory ", $ftp->message;

    #get list of files on FTP
    my @ftpList = $ftp->ls();
  
    foreach my $dir(@ftpList){
        if($DEBUG){
             $log->print($dir . "\n");
        }
        my $name = $dir;
        $name =~ s/_/ /g;

        my $terms = $settings->{'search_terms'};
        if($name =~ m/\Q$terms\E/){
            $ftp->cwd($dir) or (die "Cannot change to $dir" and next);

            my @ftpStrainFiles = $ftp->ls();

            #get current filenames in directory
            my $currentFilesHashRef = _getCurrentFileNames();
            
            my @savedFiles;
            foreach my $strainFile(@ftpStrainFiles){
                if($strainFile =~ m/\.fna/){
                    #download the file
                    my $savedFile = $settings->{'download_dir'} . $strainFile;
                    $ftp->binary();
                    $ftp->get($strainFile, $savedFile) or ($log->print("download of $strainFile failed\n" and next));
                    $ftp->ascii();
                    push @savedFiles, $savedFile;
                }
            }
            #combine all chromosome + plasmid files into same file
            #the $dir contains the strain name, and is what the DIR on FTP is named
            my $combinedFH = IO::File->new('>' . $settings->{'download_dir'}.$dir) or (die "cannot create combined file");

            foreach my $singleFile(@savedFiles){
                my $inFH = IO::File->new('<' . $singleFile) or (die "Cannot open $singleFile");
                $combinedFH->print($inFH->getlines);
                $inFH->close();

                #remove local file after combining
                unlink $singleFile;
            }

            $combinedFH->close();

            #change back to parent directory
            $ftp->cdup();
        }
    }
}

sub _getCurrentFileNames{
    #get filenames from the current directory, only download new ones
    #file names as ABAK.fasta etc.
    opendir DIR, $settings->{'download_dir'};
    my @currentFiles = grep { $_ ne '.' && $_ ne '..' && $_ ne '.directory' } readdir DIR;
    closedir DIR;

    my %currentFiles;
    foreach my $currentFile(@currentFiles){
        my $name = $currentFile;
        $name =~ m/(^.+)\./;

        if($DEBUG){
            $log->print("currentFile name: $name\n"); 
        }
        $currentFiles{$name}=1;
    }
    return \%currentFiles;
}

