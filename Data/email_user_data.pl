#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/../";
use Database::Chado::Schema;
use Modules::FET;
use Carp qw/croak carp/;
use Config::Simple;
use DBIx::Class::ResultSet;
use DBIx::Class::Row;
use IO::File;
use File::Temp;
use Email::Simple;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS;
use IO::All;

open(STDERR, ">>/home/genodo/logs/group_wise_comparisons.log") || die "Error stderr: $!";

my ($CONFIG, $DBNAME, $DBUSER, $DBHOST, $DBPASS, $DBPORT, $DBI, $mailUname, $mailPass);
my ($USERCONFIG, $USEREMAIL, $USERGP1STRAINIDS, $USERGP2STRAINIDS, $USERGP1STRAINNAMES, $USERGP2STRAINNAMES);

GetOptions('config=s' => \$CONFIG, 'user_config=s' => \$USERCONFIG) or (exit -1);
croak "Missing db config file\n" unless $CONFIG;
croak "Missing email config file\n" unless $USERCONFIG;

if(my $db_conf = new Config::Simple($CONFIG)) {
	$DBNAME    = $db_conf->param('db.name');
	$DBUSER    = $db_conf->param('db.user');
	$DBPASS    = $db_conf->param('db.pass');
	$DBHOST    = $db_conf->param('db.host');
	$DBPORT    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
	$mailUname = $db_conf->param('mail.address'); 
	$mailPass = $db_conf->param('mail.pass');
} 
else {
	die Config::Simple->error();
}

if (my $user_conf = new Config::Simple($USERCONFIG)) {
	$USEREMAIL = $user_conf->param('user.email');
	$USERGP1STRAINIDS = $user_conf->param('user.gp1IDs');
	$USERGP2STRAINIDS = $user_conf->param('user.gp2IDs');
	$USERGP1STRAINNAMES = $user_conf->param('user.gp1Names');
	$USERGP2STRAINNAMES = $user_conf->param('user.gp2Names');
}
else {
	die Config::Simple->error();
}

my $dbsource = 'dbi:' . $DBI . ':dbname=' . $DBNAME . ';host=' . $DBHOST;
$dbsource . ';port=' . $DBPORT if $DBPORT;

my $schema = Database::Chado::Schema->connect($dbsource, $DBUSER, $DBPASS);

if (!$schema) {
	die "Could not connect to database: $!\n"
}

####################
####################

print STDERR "New comparison for user email $USEREMAIL\n";

my $binaryFETResults = getBinaryData($USERGP1STRAINIDS, $USERGP2STRAINIDS, $USERGP1STRAINNAMES, $USERGP2STRAINNAMES);
my $snpFETResults = getSnpData($USERGP1STRAINIDS, $USERGP2STRAINIDS, $USERGP1STRAINNAMES, $USERGP2STRAINNAMES);

print STDERR "Sending email\n";

my $transport = Email::Sender::Transport::SMTP::TLS->new(
	host     => 'smtp.gmail.com',
	port     => 587,
	username => $mailUname,
	password => $mailPass,
	);

my $message = Email::MIME->create(
	header => [
	To => $USEREMAIL,
	From => $mailUname,
	Subject        => 'Your SuperPhy group wise comparison results are ready.',
	'Content-Type' => 'text/html'
	],
	parts => [
	Email::MIME->create(
		body => "Your results are ready for download in the provided attachments. This is an automated message, please do not reply to this.\n"
		. "SuperPhy Team.\n"
		),
	Email::MIME->create(
		attributes => {
			filename => 'group_wise_SNP_results.txt',
			disposition  => "attachment",
			},
			body => io($snpFETResults->[5]{'file_name'})->all,
			),
	Email::MIME->create(
		attributes => {
			filename => 'group_wise_loci_results.txt',
			disposition  => "attachment",
			},
			body => io($binaryFETResults->[4]{'file_name'})->all,
			)
	],
	);

sendmail( $message, {transport => $transport} ) or die "$!\n";

#####################
#####################
sub getBinaryData {
	my $group1GenomeIds = shift;
	my $group2GenomeIds = shift;
	my $group1GenomeNames = shift;
	my $group2GenomeNames = shift;

	my $group1lociDataTable = $self->dbixSchema->resultset('Feature')->search(
		{'loci_genotypes.genome_id' => $group1GenomeIds, 'type.name' => 'pangenome'},
		{
			join => ['loci_genotypes', 'type', 'featureprops'],
			select => ['me.feature_id', 'me.uniquename', 'featureprops.value', {sum => 'loci_genotypes.locus_genotype'}],
			as => ['feature_id', 'id', 'function', 'locus_count'],
			group_by => [qw/me.feature_id me.uniquename me.name featureprops.value/]
		}
		);

	my $group2lociDataTable = $self->dbixSchema->resultset('Feature')->search(
		{'loci_genotypes.genome_id' => $group2GenomeIds, 'type.name' => 'pangenome'},
		{
			join => ['loci_genotypes', 'type', 'featureprops'],
			select => ['me.feature_id', 'me.uniquename', 'featureprops.value', {sum => 'loci_genotypes.locus_genotype'}],
			as => ['feature_id', 'id', 'function', 'locus_count'],
			group_by => [qw/me.feature_id me.uniquename me.name featureprops.value/]
		}
		);

	my @group1Loci = $group1lociDataTable->all;
	my @group2Loci = $group2lociDataTable->all;

	my $fet = Modules::FET->new();
	$fet->group1($group1GenomeIds);
	$fet->group2($group2GenomeIds);
	$fet->group1Markers(\@group1Loci);
	$fet->group2Markers(\@group2Loci);
	$fet->testChar('1');
	#Returns hash ref of results
	my $results = $fet->run('locus_count');

	# #Print results to file
	my $tmp = File::Temp->new(	TEMPLATE => 'tempXXXXXXXXXX',
		DIR => '/home/genodo/group_wise_data_temp/',
		UNLINK => 0);

	print $tmp "Group 1: " . join(", ", @{$group1GenomeNames}) . "\n" . "Group 2: " . join(", ", @{$group2GenomeNames}) . "\n";   

	print $tmp "Locus ID \t Group 1 Present \t Group 1 Absent \t Group 2 Present \t Group 2 Absent \t p-value \n";

	my $allResultArray =  $results->[0]{'all_results'};
	foreach my $allResultRow (@{$allResultArray}) {
		print $tmp $allResultRow->{'marker_id'} . "\t" . $allResultRow->{'group1Present'} . "\t" . $allResultRow->{'group1Absent'} . "\t" . $allResultRow->{'group2Present'} . "\t" . $allResultRow->{'group2Absent'} . "\t" . $allResultRow->{'pvalue'} . "\n";
	}

	my $temp_file_name = $tmp->filename;

	my @group1NameArray;
	foreach my $name (@{$group1GenomeNames}) {
		my %nameHash;
		$nameHash{'name'} = $name;
		push (@group1NameArray , \%nameHash);
	}

	my @group2NameArray;
	foreach my $name (@{$group2GenomeNames}) {
		my %nameHash;
		$nameHash{'name'} = $name;
		push (@group2NameArray , \%nameHash);
	}

	push($results, {'file_name' => $temp_file_name});
	push($results, {'gp1_names' => \@group1NameArray});
	push($results, {'gp2_names' => \@group2NameArray});

	return $results;
}

################
################
sub getSnpData {
	my $group1GenomeIds = shift;
	my $group2GenomeIds = shift;
	my $group1GenomeNames = shift;
	my $group2GenomeNames = shift;

	my $group1SnpDataTable = $self->dbixSchema->resultset('Feature')->search(
		{'snps_genotypes.genome_id' => $group1GenomeIds, 'type.name' => 'pangenome'},
		{
			join => ['snps_genotypes', 'type', 'featureprops'],
			select => ['me.feature_id', 'me.uniquename', 'featureprops.value', {sum => 'snps_genotypes.snp_a'}, {sum => 'snps_genotypes.snp_t'}, {sum => 'snps_genotypes.snp_c'}, {sum => 'snps_genotypes.snp_g'}],
			as => ['feature_id', 'id', 'function', 'a_count', 't_count', 'c_count', 'g_count'],
			group_by => [qw/me.feature_id me.uniquename me.name featureprops.value/]
		}
		);

	my $group2SnpDataTable = $self->dbixSchema->resultset('Feature')->search(
		{'snps_genotypes.genome_id' => $group2GenomeIds, 'type.name' => 'pangenome'},
		{
			join => ['snps_genotypes' , 'type', 'featureprops'],
			select => ['me.feature_id', 'me.uniquename','featureprops.value', {sum => 'snps_genotypes.snp_a'}, {sum => 'snps_genotypes.snp_t'}, {sum => 'snps_genotypes.snp_c'}, {sum => 'snps_genotypes.snp_g'}],
			as => ['feature_id', 'id', 'function', 'a_count', 't_count', 'c_count', 'g_count'],
			group_by => [qw/me.feature_id me.uniquename me.name featureprops.value/]
		}
		);

	my @group1Snps = $group1SnpDataTable->all;
	my @group2Snps = $group2SnpDataTable->all;

	my $fet = Modules::FET->new();
	$fet->group1($group1GenomeIds);
	$fet->group2($group2GenomeIds);
	$fet->group1Markers(\@group1Snps);
	$fet->group2Markers(\@group2Snps);

	my @results;
	#Returns hash ref of results
	$fet->testChar('A');
	my $a_results = $fet->run('a_count');
	$fet->testChar('T');
	my $t_results = $fet->run('t_count');
	$fet->testChar('C');
	my $c_results = $fet->run('c_count');
	$fet->testChar('G');
	my $g_results = $fet->run('g_count');

	#Merge all results and resort them
	my @combineAllResults = (@{$a_results->[0]{'all_results'}}, @{$t_results->[0]{'all_results'}}, @{$c_results->[0]{'all_results'}}, @{$g_results->[0]{'all_results'}});
	my @combineSigResults = (@{$a_results->[1]{'sig_results'}}, @{$t_results->[1]{'sig_results'}}, @{$c_results->[1]{'sig_results'}}, @{$g_results->[1]{'sig_results'}});
	my $combineSigCount = $a_results->[2]{'sig_count'} + $t_results->[2]{'sig_count'} + $c_results->[2]{'sig_count'} + $g_results->[2]{'sig_count'};	
	my $combineTotalComparisons = $a_results->[3]{'total_comparisons'} + $t_results->[3]{'total_comparisons'} + $c_results->[3]{'total_comparisons'} + $g_results->[3]{'total_comparisons'};

	my @sortedAllResults = sort({$a->{'pvalue'} <=> $b->{'pvalue'}} @combineAllResults);
	my @sortedSigResults = sort({$a->{'pvalue'} <=> $b->{'pvalue'}} @combineSigResults);

	push(@results, {'all_results' => \@sortedAllResults}, {'sig_results' => \@sortedSigResults}, {'sig_count' => $combineSigCount}, {'total_comparisons' => $combineTotalComparisons});

	# #Print results to file
	my $tmp = File::Temp->new(	TEMPLATE => 'tempXXXXXXXXXX',
		DIR => '/home/genodo/group_wise_data_temp/',
		UNLINK => 0);

	print $tmp "Group 1: " . join(", ", @{$group1GenomeNames}) . "\n" . "Group 2: " . join(", ", @{$group2GenomeNames}) . "\n";   

	print $tmp "SNP ID \t Nucleotide \t Group 1 Present \t Group 1 Absent \t Group 2 Present \t Group 2 Absent \t p-value \n";

	foreach my $sortedAllResultRow (@sortedAllResults) {
		print $tmp $sortedAllResultRow->{'marker_id'} . "\t" . $sortedAllResultRow->{'test_char'} . "\t" . $sortedAllResultRow->{'group1Present'} . "\t" . $sortedAllResultRow->{'group1Absent'} . "\t" . $sortedAllResultRow->{'group2Present'} . "\t" . $sortedAllResultRow->{'group2Absent'} . "\t" . $sortedAllResultRow->{'pvalue'} . "\n";
	}

	my $temp_file_name = $tmp->filename;

	my @group1NameArray;
	foreach my $name (@{$group1GenomeNames}) {
		my %nameHash;
		$nameHash{'name'} = $name;
		push (@group1NameArray , \%nameHash);
	}

	my @group2NameArray;
	foreach my $name (@{$group2GenomeNames}) {
		my %nameHash;
		$nameHash{'name'} = $name;
		push (@group2NameArray , \%nameHash);
	}
	
	push(@results, {'results' => \@results});
	push(@results, {'file_name' => $temp_file_name});
	push(@results, {'gp1_names' => \@group1NameArray});
	push(@results, {'gp2_names' => \@group2NameArray});

	return \@results;
}