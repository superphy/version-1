#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use DBI;
use lib "$FindBin::Bin/../";
use Log::Log4perl qw(:easy);
use Config::Simple;
use IO::File;
use IO::Dir;

#Updater script for SuperPhy analysis pipeline.

Log::Log4perl->easy_init({ level   => $DEBUG,
	file    => ">>/home/genodo/logs/update_data_loading.log" });

INFO('Updating datatables from SuperPhy analysis');

my $INPUTFILE = $ARGV[0];
my $DATATYPE = $ARGV[1];

die "Exit status received " , FATAL("Datatype not specified (ex. snp, binary, vir, amr).") unless $DATATYPE;

#Config params for connecting to the database. 
my $CONFIGFILE = "$FindBin::Bin/../Modules/genodo.cfg";
die "Exit status received " , FATAL("Unable to locate config file, or does not exist at specified location.") unless $CONFIGFILE;

my ($dbname, $dbuser, $dbpass, $dbhost, $dbport, $DBI, $TMPDIR);

if(my $db_conf = new Config::Simple($CONFIGFILE)) {
	$dbname    = $db_conf->param('db.name');
	$dbuser    = $db_conf->param('db.user');
	$dbpass    = $db_conf->param('db.pass');
	$dbhost    = $db_conf->param('db.host');
	$dbport    = $db_conf->param('db.port');
	$DBI       = $db_conf->param('db.dbi');
	$TMPDIR    = $db_conf->param('tmp.dir');
} 
else {
	die "Exit status received " , FATAL(Config::Simple->error());
}

die "Exit status received " , ERROR("Invalid configuration file.") unless $dbname;

my $dbh = DBI->connect(
	"dbi:Pg:dbname=$dbname;port=$dbport;host=$dbhost",
	$dbuser,
	$dbpass,
	{AutoCommit => 0, TraceLevel => 0}
	) or die "Exit status received " , FATAL("Unable to connect to database: " . DBI->errstr);

my @genomes; #List of new genomes
my @seqFeatures; #List of presence absence value for each genome

open my $binary_output , '<' , $INPUTFILE or die "Exit status received " , ERROR("Can't open data file $INPUTFILE: $!");

while (<$binary_output>) {
	$_ =~ s/\R//g;
	my @tempRow = split(/\t/, $_);
	if ($. == 1) {
		@genomes = @tempRow;
	}
	elsif ($. > 1) {
		push (@seqFeatures , \@tempRow);
		#Arbitrarily set cutoff for testing
		last if ($. == 1000);
	}
	else {
	}
}

#INFO("Total genomes in file: " . (scalar(@genomes) - 1));

INFO("Processing $INPUTFILE");
my $numGenomes = scalar(@genomes)-1;
INFO("Number of genomes: $numGenomes");
my $numLoci = scalar(@seqFeatures);
INFO("Number of loci: $numLoci");

open my $outDataFile , '>' , "$DATATYPE" . "_processed_data.txt" or die "Exit status received " , ERROR("Can't write to file: $!");

if ($DATATYPE eq 'binary') {
	for (my $j = 0; $j < $numLoci ; $j++) {
		my $parsed_header = parseHeader($seqFeatures[$j][0], $DATATYPE);
		my $feature_id = findFeatureId($parsed_header);
		die "Exit status received", ERROR ("Undefined feature id") unless defined($feature_id);
		writeOutBinaryData($parsed_header, $feature_id, $j);
	}
	print $outDataFile "\\.\n\n";
	$outDataFile->autoflush;
	close $outDataFile;
	INFO("\t...Adding loci to database");
	copyDataToDb($outDataFile);
}
elsif ($DATATYPE eq 'snp'){
	for (my $j = 0; $j < $numLoci ; $j++) {
		my $parsed_header = parseHeader($seqFeatures[$j][0], $DATATYPE);
		my $feature_id = findFeatureId($parsed_header);
		die "Exit status received", ERROR ("Undefined feature id") unless defined($feature_id);
		writeOutSnpData($parsed_header, $feature_id, $j);
	}
	print $outDataFile "\\.\n\n";
	$outDataFile->autoflush;
	close $outDataFile;
	INFO("\t...Adding snps to database");
	copyDataToDb($outDataFile); 
}
else {
	#Data is either for virulence or amr genes
	for (my $j = 0 ; $j < $numLoci ; $j++) {
		my $parsed_header = parseHeader($seqFeatures[$j][0], $DATATYPE);
		writeOutVIRAMRData($parsed_header, $j);
	}
	print $outDataFile "\\.\n\n";
	$outDataFile->autoflush;
	close $outDataFile;
	INFO("\t...Adding vf/amr data to database");
	copyDataToDb($outDataFile);
}

INFO("Done.");

unlink "$DATATYPE" . "_processed_data.txt";

#Helper Functions
sub writeOutBinaryData {
	my $_locusID = shift;
	my $_feature_id = shift;
	my $_locusIndex = shift;
	for (my $i = 1; $i < $numGenomes; $i++) {
		print $outDataFile $genomes[$i] . "\t" . $_feature_id . "\t" . $seqFeatures[$_locusIndex][$i] . "\n";
	}
	# if ($_locusIndex+1 % 1000 == 0) {
	# 	INFO("$_locusIndex+1 out of " . scalar(@seqFeatures) . " loci completed");
	# }
	# else {
	# }
}

sub writeOutSnpData {
	my $_snpID = shift;
	my $_feature_id = shift;
	my $_snpIndex = shift;
	for (my $i = 1; $i < $numGenomes; $i++) {
		#A
		if ($seqFeatures[$_snpIndex][$i] eq 'A') {
			print $outDataFile $genomes[$i] . "\t" . $_feature_id . "\t" . "1\t" . "0\t" . "0\t" . "0\n";
		}
		#T
		elsif ($seqFeatures[$_snpIndex][$i] eq 'T') {
			print $outDataFile $genomes[$i] . "\t" . $_feature_id . "\t" . "0\t" . "1\t" . "0\t" . "0\n";
		}
		#C
		elsif ($seqFeatures[$_snpIndex][$i] eq 'C') {
			print $outDataFile $genomes[$i] . "\t" . $_feature_id . "\t" . "0\t" . "0\t" . "1\t" . "0\n";
		}
		#G
		elsif ($seqFeatures[$_snpIndex][$i] eq 'G') {
			print $outDataFile $genomes[$i] . "\t" . $_feature_id . "\t" . "0\t" . "0\t" . "0\t" . "1\n";
		}
		# -
		else {
			print $outDataFile $genomes[$i] . "\t" . $_feature_id . "\t" . "0\t" . "0\t" . "0\t" . "0\n";
		}
	}
	# if ($_snpIndex+1 % 1000 == 0) {
	# 	INFO("$_snpIndex+1 out of " . scalar(@seqFeatures) . " snps completed");
	# }
	# else {
	# }
}

sub writeOutVIRAMRData {
	my $_vfamrID = shift;
	my $_viramrIndex = shift;
	for (my $i = 1; $i < $numGenomes; $i++) {
		print $outDataFile $genomes[$i] . "\t" . $_vfamrID . "\t" . $seqFeatures[$_viramrIndex][$i] . "\n";
	}
	# if ($_viramrIndex+1 % 100 == 0) {
	# 	INFO("$_viramrIndex+1 out of " . scalar(@seqFeatures) . " VF/AMR genes completed");
	# }
	# else {
	# }
}


sub parseHeader {	my $oldHeader = shift;
	my $_inputDataType = shift;
	my $newHeader;
	if ($_inputDataType eq "vir") {
		if ($oldHeader =~ /^(VF|vf)_([\w\d]+)(|)/) {
			$newHeader = $2;
		}
		else{
			INFO("Emptyheader: $oldHeader. Skipping...");
			next;
		}
	}
	elsif ($_inputDataType eq "amr") {
		if ($oldHeader =~ /^(AMR|amr)_([\w\d]+)(|)/) {
			$newHeader = $2;
		}
		else {
			INFO("Emptyheader: $oldHeader. Skipping...");
			next;
		}
	}
	#Locus ID (Numerical header)
	elsif  ($_inputDataType eq "binary") {
		#if ($oldHeader eq "") {
		#	INFO("Emptyheader: $oldHeader. Skipping...");
		#	next;
		#}
		#else {
			$newHeader = $oldHeader;
		#}
	}
	#SNP Data (Numerical header)
	elsif ($_inputDataType eq "snp") {
		#if ($oldHeader eq "") {
		#	INFO("Emptyheader: $oldHeader. Skipping...");
		#	next;
		#}
		#else {
			$newHeader = $oldHeader;
		#}
	}
	else{
		die "Exit status received", ERROR("Parsing locus headers failed.");
	}
	return $newHeader;
}

sub findFeatureId {
	my $anno_id = shift;
	my $sth = $dbh->prepare('SELECT feature_id from feature WHERE uniquename = ?') or die "Exit status received", ERROR("Could not prepare statement: " . $dbh->errstr);
	$sth->execute($anno_id) or die "Exit status received", ERROR("Could not execute statement: " . $sth->errstr);
	my $_feature_id;
	while (my @data = $sth->fetchrow_array()) {
		$_feature_id = $data[0];
	}
	return $_feature_id;
}

sub copyDataToDb {
	my $_outDataFile = shift;
	if ($DATATYPE eq "snp") {
		$dbh->do("COPY snps_genotypes(genome_id, feature_id, snp_a, snp_t, snp_c, snp_g) FROM STDIN");
		
		open my $fh , '<' , $DATATYPE . "_processed_data.txt" or die "Exit status received " , ERROR("Can't open data file " . $DATATYPE . "_processed_data.txt: $!");
		seek($fh,0,0);

		while (<$fh>) {
			if (! ($dbh->pg_putcopydata($_))) {
				$dbh->pg_putcopyend();
				$dbh->rollback;
				$dbh->disconnect;
				die "Exit status received ", ERROR("Error calling pg_putcopydata: $!");
			}
		}
		INFO("pg_putcopydata completed successfully.");
		$dbh->pg_putcopyend() or die "Exit status received ", ERROR("Error calling pg_putcopyend on line $.");
	}
	elsif ($DATATYPE eq "binary") {

		$dbh->do("COPY loci_genotypes(genome_id, feature_id, locus_genotype) FROM STDIN");
		
		open my $fh , '<' , $DATATYPE . "_processed_data.txt" or die "Exit status received " , ERROR("Can't open data file " . $DATATYPE . "_processed_data.txt: $!");
		seek($fh,0,0);

		while (<$fh>) {
			if (! ($dbh->pg_putcopydata($_))) {
				$dbh->pg_putcopyend();
				$dbh->rollback;
				$dbh->disconnect;
				die "Exit status received ", ERROR("Error calling pg_putcopydata: $!");
			}
		}
		INFO("pg_putcopydata completed successfully.");
		$dbh->pg_putcopyend() or die "Exit status received ", ERROR("Error calling pg_putcopyend on line $.");
	}
	elsif ($DATATYPE eq "vir") {
		$dbh->do("COPY raw_virulence_data(genome_id, gene_id, presence_absence) FROM STDIN");

		open my $fh, '<' , $DATATYPE . "_processed_data.txt" or die "Exit status received ", ERROR("Cant't open data file " . $DATATYPE . "_processed_data.txt: $!");
		seek($fh,0,0);

		while (<$fh>) {
			if (! ($dbh->pg_putcopydata($_))) {
				$dbh->pg_putcopyend();
				$dbh->rollback;
				$dbh->disconnect;
				die "Exit status received ", ERROR("Error calling pg_putcopydata: $!");
			}
		}
		INFO("pg_putcopydata completed successfully.");
		$dbh->pg_putcopyend() or die "Exit status received ", ERROR("Error calling pg_putcopyend on line $.");
	}
	elsif ($DATATYPE eq "amr") {
		$dbh->do("COPY raw_amr_data(genome_id, gene_id, presence_absence) FROM STDIN");

		open my $fh, '<' , $DATATYPE . "_processed_data.txt" or die "Exit status received ", ERROR("Cant't open data file " . $DATATYPE . "_processed_data.txt: $!");

		while (<$fh>) {
			if (! ($dbh->pg_putcopydata($_))) {
				$dbh->pg_putcopyend();
				$dbh->rollback;
				$dbh->disconnect;
				die "Exit status received ", ERROR("Error calling pg_putcopydata: $!");
			}
		}
		INFO("pg_putcopydata completed successfully.");
		$dbh->pg_putcopyend() or die "Exit status received ", ERROR("Error calling pg_putcopyend on line $.");
	}
	else{
	}
	$dbh->commit;
	$dbh->disconnect;
	INFO("Data table update complete.");
}
