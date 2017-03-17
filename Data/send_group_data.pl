#!/usr/bin/env perl 

=head1 NAME

$0 - Send SNP and pangenome presence/absence data file and optionally meta-data to proper directory on Giant server for R/Shiny app

=head1 SYNOPSIS

  % send_group_data.pl --config filename --pg filepath [--snp filepath] [--meta]

=head1 COMMAND-LINE OPTIONS

 --config         Must specify a .conf containing VPN connection parameters, remote filepaths and ssh credentials
 --pg             Filepath on local machine for pangenome binary matrix RData
 [--snp ]         Filepath on local machine for snp binary matrix RData. OPTIONAL since pangenome can change without altering snp set
 [--meta]         Include public meta-data and group data in data transmission
 
=head1 DESCRIPTION

Transfers files to backup directory and then copies to the destination file.  If --meta option selected, retrieves meta-data, converts
to R object and then also saves to destination.

=head1 AUTHOR

Matt Whiteside E<lt>mawhites@phac-aspc.gov.caE<gt>

Copyright (c) 2013

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Carp qw/croak carp/;
use Config::Tiny;
use Time::HiRes qw( time );
use IO::CaptureOutput qw(capture_exec);
use POSIX;
use constant DATETIME => strftime("%Y-%m-%d_%H-%M-%S", localtime);
use File::Copy;
use Log::Log4perl qw(get_logger);
#use WWW::Curl::Easy; # Commenting out Curl libs, can't get them to install on CentOS
#use WWW::Curl::Form; # but not needed on giant anyhow
use Statistics::R;
use JSON::MaybeXS qw(encode_json);
use Data::Bridge;
use Modules::FormDataGenerator;


# Get options
my ($config_filepath, 
	$pg_source_file,
	$snp_source_file,
	$user, $pass, $addr, $bkp_dir, $log_dir, $dest_dir,
	$callback, $total_size, $current_size,
    $do_meta
	);

my $test = 0;

GetOptions(
    'config=s'  => \$config_filepath,
    'pg=s'      => \$pg_source_file,
    'snp=s'     => \$snp_source_file,
    'test'      => \$test,
    'meta'      => \$do_meta,

) or ( system( 'pod2text', $0 ), exit -1 );

my $do_pg = $pg_source_file ? 1 : 0;
my $do_snps = $snp_source_file ? 1 : 0;

croak "Error: missing argument. You must supply a configuration filepath: --config file.\n" . system ('pod2text', $0) unless $config_filepath;
if(my $conf = Config::Tiny->read($config_filepath)) {
	$user    = $conf->{shiny}->{user};
	$pass    = $conf->{shiny}->{pass};
	$addr    = $conf->{shiny}->{address};
	$bkp_dir = $conf->{shiny}->{backupdir};
	$log_dir = $conf->{dir}->{log};
	$dest_dir = $conf->{shiny}->{targetdir};
} else {
	die Config::Tiny->error();
}

# Setup logger
my $logger = init($log_dir);
$logger->info("<<BEGIN Superphy R/Shiny data file transfer");

# Filenames
my $pg_rdata_file = $bkp_dir . 'superphyPg_' . DATETIME . '.RData';
my $snp_rdata_file = $bkp_dir . 'superphySnp_' . DATETIME . '.RData';
my $meta_json_file = $bkp_dir . 'public_meta_data_' . DATETIME . '.json';
my $meta_rdata_file = $bkp_dir . 'public_meta_data_' . DATETIME . '.RData';


if($test) {
	$pg_rdata_file = $bkp_dir . 'test_superphyPg_'. DATETIME . '.Rdata';
	$snp_rdata_file = $bkp_dir . 'test_superphySnp_' . DATETIME . '.RData';
    $meta_json_file = $bkp_dir . 'test_public_meta_data_' . DATETIME . '.json';
    $meta_rdata_file = $bkp_dir . 'test_public_meta_data_' . DATETIME . '.RData';
}

# Copy to archival directory
if($do_pg) {
    copy($pg_source_file, $pg_rdata_file) or croak "Error: unable to make copy of file $pg_source_file called $pg_rdata_file ($!).\n";
    $logger->info("Copied file:\n\t$pg_source_file");
}
if($do_snps) {
	copy($snp_source_file, $snp_rdata_file) or croak "Error: unable to make copy of file $snp_source_file called $snp_rdata_file ($!).\n";
    $logger->info("Copied files:\n\t$snp_source_file");
}


# Prepare meta-data file
if($do_meta) {
    &retrieve_meta_data($meta_json_file);
    &save_meta_data($meta_json_file, $meta_rdata_file);
}

#&upload() unless $test;

# Copy from achive directory to live directory
&copy_to_destination() unless $test;


$logger->info("END>>");

###############
## Subs
###############

# Setup logging
sub init {
	my $dir = shift;

    # config
    my $conf = q(
        log4perl.logger                    = INFO, FileApp
        log4perl.appender.FileApp          = Log::Log4perl::Appender::File
        log4perl.appender.FileApp.filename = ).$dir.q(send_group_data.log
        log4perl.appender.FileApp.layout   = PatternLayout
        log4perl.appender.FileApp.layout.ConversionPattern = %d> %m%n
    );

    # Initialize logging behaviour
    Log::Log4perl->init(\$conf);

    # Obtain a logger instance
    my $logger = get_logger();

    $logger->info("TEST MODE") if $test;
   
   return $logger;
}

# Transfer R binary file to R/Shiny server using cURL
# sub upload {

# 	my $curl = WWW::Curl::Easy->new();
# 	my $curlf = WWW::Curl::Form->new();

# 	$curl->setopt(CURLOPT_HEADER,1);
#     $curl->setopt(CURLOPT_URL, $addr);

# 	$curlf->formaddfile($rdata_file, 'shinydata', "multipart/form-data");

# 	$curl->setopt(CURLOPT_HTTPPOST, $curlf);

# 	# Do POST
# 	my $retcode = $curl->perform;

# 	# Return code
#     if ($retcode == 0) {
#     	$logger->info("cURL transfer complete.");

#         my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
       
#         unless($response_code eq '201') {
#         	$logger->logdie("Recieved unexpected HTTP response: $response_code.");

#     	} else {
#     		$logger->info("Recieved HTTP response $response_code.");
#     	}

#     } else {
# 		# Error code, type of error, error message
#     	$logger->logdie("cURL transfer failed ($retcode ".$curl->strerror($retcode)." ".$curl->errbuf."\n");
#     }
# }

# Transfer R binary file to data directory
# Works when superphy is on same server as Shiny
sub copy_to_destination {

	# Check permissions on destination directory
	my $mode = (stat($dest_dir))[2];
    $mode = $mode & 0777;

    if(($mode & 070) == 070) {
        # Group can write

        my @files = ();
        push @files, [$pg_rdata_file, $dest_dir . 'superphyPg.RData'] if $do_pg;
        push @files, [$snp_rdata_file, $dest_dir . 'superphySnp.RData'] if $do_snps;
        push @files, [$meta_rdata_file, $dest_dir . 'superphy-df_meta.RData'] if $do_meta;

        foreach my $f (@files) {
        	my $dest_file = $f->[1];
        	my $source_file = $f->[0];

        	if(-e $dest_file or -l $dest_file) {
        		croak "Error: expected destination file $dest_file to be symlink." unless -l $dest_file;
        		unlink $dest_file or croak "Error: could not unlink $dest_file ($!)\n";
                sleep 1;
        	}

        	# Create symlink in target dir
        	symlink($source_file, $dest_file) or croak "Error: could not symlink $source_file to $dest_file ($!)\n";
        	$logger->info("RData file $source_file linked to $dest_file");
        }
     	
    }
    else {
    	croak("Group does not have write permissions on destination directory: $dest_dir ($!).\n");
    }
}

# Build R data object for public meta-data
sub retrieve_meta_data {
    my $public_json_file = shift;

    # Connect to database
    my $dbBridge = Data::Bridge->new(config => $config_filepath);

    # Initialize Data Retrival module
    my $data = Modules::FormDataGenerator->new(dbixSchema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory);

    # Get Shiny data
    my $shiny_data = {};
    my $username = undef;
    $data->shiny_data($username, $shiny_data);
    $logger->info("Retrieved public meta-data");


    # Convert to JSON & write to file
    my $meta_json = encode_json($shiny_data);
    open(my $out, '>', $public_json_file) or croak "Error: unable to write to file $public_json_file ($!)\n";
    print $out $meta_json;
    close $out;
    $logger->info("Converted public meta-data to JSON.");

}

sub save_meta_data {
    my $input_file = shift;
    my $output_file = shift;

    my $R = Statistics::R->new();
    
    my @rcmds = (
        q/library('jsonlite')/,
        qq/l <- fromJSON('$input_file')/,
        q/df_meta <- as.data.frame(do.call(cbind, l$data))/,
        q/df_meta <- apply(df_meta, 2, as.character)/,
        q/df_meta[df_meta == 'NULL'] <- NA/,
        q/df_meta <- as.data.frame(df_meta)/,
        q/rownames(df_meta) <- l$genomes/,
        q/num_distinct <- sapply(df_meta, function(x) length(unique(x)))/,
        q/num_na <- sapply(df_meta, function(x) sum(is.na(x)))/,
        q/cols_df <- colnames(df_meta)/,
        q/ordered_cols_df <- cols_df[order(num_na, -num_distinct)]/,
        q/df_meta <- df_meta[, ordered_cols_df]/,
        q/print('SUCCESS')/
    );

    # Load and prepare data
    my $rs = $R->run(@rcmds);

    unless($rs =~ m'SUCCESS') {
        $logger->logdie("Error: R data loading failed ($rs).\n");
    } 
    else {
        $logger->info('Data loaded into R')
    }

    # Convert to R binary file
    my $rcmd = qq/save(df_meta, file='$output_file')/;
    my $rs2 = $R->run($rcmd, q/print('SUCCESS')/);

    unless($rs2 =~ m'SUCCESS') {
        $logger->logdie("Error: R save failed ($rs).\n");
    } else {
        $logger->info('R data saved to file '.$output_file)
    }
}


