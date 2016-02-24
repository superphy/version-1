#!/usr/bin/env perl

=pod

=head1 NAME

lib::PipelineT.pm

=head1 DESCRIPTION

Test module for pipeline.t & pipeline-continue.t scripts

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

package t::lib::PipelineT;

use strict;
use warnings;
use Config::Tiny;
use FindBin;
use File::Basename qw< dirname >;
use lib dirname(__FILE__) . '/../../';
use Database::Chado::Schema;
use Data::Bridge;
use Modules::FormDataGenerator;
use Statistics::R;
use Test::Builder::Module;
use List::MoreUtils qw(all);
use Sub::Exporter -setup => { 
	exports => [qw/fasta_file genome_name upload_form genome_feature cmp_genome_properties tree_contains metadata_contains
			sandbox_directory tree_doesnt_contain metadata_doesnt_contain shiny_rdata_doesnt_contain
		/],
	groups => { default => [ qw(fasta_file genome_name upload_form genome_feature cmp_genome_properties tree_contains
			metadata_contains sandbox_directory tree_doesnt_contain metadata_doesnt_contain shiny_rdata_doesnt_contain
		) ] },
};

# Inputs for pipeline:
my $genome_name = 'Experimental strain Gamma-22';
#my $fasta_file = "$FindBin::Bin/etc/Escherichia_coli_JJ1886_uid218163.fasta";
my $geocode_id = 1;
my $fasta_file = "$FindBin::Bin/etc/AFVS.fasta";

sub fasta_file {
	
	return $fasta_file;
}
	
sub genome_name {
	
	return $genome_name;
}

sub upload_form {

	my $form = {
		g_name => $genome_name,
		g_serotype => 'O48:H6',
		g_strain => 'K12',
		g_date => '2001-02-03',
		g_mol_type => 'wgs',
		g_host => 'hsapiens',
		g_source => 'stool',
		geocode_id => $geocode_id,
		g_privacy => 'public',
		g_file => [
			$fasta_file,
			"genome.ffn",
			'Content-type' => 'text/plain'
		]
	};

	return $form;
}

# TODO: add location tests
sub form_cvterm_mapping {
	return {
		g_serotype => 'serotype',
		g_strain => 'strain',
		g_host => 'isolation_host',
		g_source => 'isolation_source',
		g_date => 'isolation_date'
	};
}

sub genome_feature {
	my ($feature_schema, $gname) = @_;

	$gname //= $genome_name;

	my $feature_row = $feature_schema->find({uniquename => $gname});

	return $feature_row;
}

# Validate genome feature
sub cmp_genome_properties {
	my ($schema, $feature_id, $form, $test_name) = @_;

	my $db_bridge = Data::Bridge->new(schema => $schema);
	my $host_mapping = $db_bridge->hostList;
	my $host_categories = $db_bridge->hostCategories;
	my $source_mapping = $db_bridge->sourceList;

	$test_name ||= '';

	my $Test = Test::Builder::Module->builder;

	my $fp_rs = $schema->resultset('PrivateFeatureprop')->search(
		{
			feature_id => $feature_id
		},
		{
			prefetch => 'type'
		}
	);

	my %genome_properties;
	while(my $fprop = $fp_rs->next) {
		$genome_properties{$fprop->type->name} = $fprop->value;
	}

	my $testable_params = form_cvterm_mapping();
	
	# Test result
	my $ok = 1;

	# Determine host category
	my $hostc;
	if($form->{g_host}) {
		$hostc = $host_categories->{$form->{g_host}};
	}
	foreach my $param (keys %$form) {
		
		my $att = $testable_params->{$param};
		if($att) {
			my $svalue = $form->{$param};
			my $dbvalue = $genome_properties{$att};
			if($att eq 'isolation_source' && $hostc) {
				# if host category not defined, it is 'other'
				$svalue = $source_mapping->{$hostc}->{$svalue};
			}
			elsif($att eq 'isolation_host') {
				$svalue = $host_mapping->{$svalue};
			}
			
			unless($svalue eq $dbvalue) {
				$ok = 0;
				$Test->diag("Attribute $att does not match submitted value: '$dbvalue' vs '$svalue' (form parameter: $param).");
			}
		}
	}

	return $Test->ok($ok, $test_name);
}
	

# Check for genome in global tree
sub tree_contains {
	my ($schema, $feature_id, $test_name, $pub) = @_;

	my $Test = Test::Builder::Module->builder;

	# Retrieve global tree
	my $genome_label = "private_$feature_id";
	$genome_label = "public_$feature_id" if $pub;
	my $tree = $schema->resultset('Tree')->find({name => 'global'});

	return $Test->like($tree->tree_string, qr/$genome_label/, $test_name);
}
sub tree_doesnt_contain {
	my ($schema, $feature_id, $test_name, $pub) = @_;

	my $Test = Test::Builder::Module->builder;

	# Retrieve global tree
	my $genome_label = "private_$feature_id";
	$genome_label = "public_$feature_id" if $pub;
	my $tree = $schema->resultset('Tree')->find({name => 'global'});

	return $Test->unlike($tree->tree_string, qr/$genome_label/, $test_name);
}


# Check for genome in user's meta data JSON object
sub metadata_contains {
	my ($schema, $feature_id, $user, $test_name, $pub) = @_;

	my $Test = Test::Builder::Module->builder;

	my $genome_label = "private_$feature_id";
	$genome_label = "public_$feature_id" if $pub;

	# Create FormDataGenerator object
	my $data = Modules::FormDataGenerator->new(dbixSchema => $schema);

	# Retrieve JSON string for user
	my ($public_json, $private_json) = $data->genomeInfo($user);

	return $Test->like($private_json, qr/$genome_label/, $test_name);
}
sub metadata_doesnt_contain {
	my ($schema, $feature_id, $user, $test_name, $pub) = @_;

	my $Test = Test::Builder::Module->builder;

	my $genome_label = "private_$feature_id";
	$genome_label = "public_$feature_id" if $pub;

	# Create FormDataGenerator object
	my $data = Modules::FormDataGenerator->new(dbixSchema => $schema);

	# Retrieve JSON string for user
	my ($public_json, $private_json) = $data->genomeInfo($user);

	return $Test->unlike($private_json, qr/$genome_label/, $test_name);
}

# Check for genome in shiny Rdata file containing public data
sub shiny_rdata_doesnt_contain {
	my ($genome_label, $test_name) = @_;

	# Find location of shiny data file
	my $conf = Config::Tiny->read($ENV{SUPERPHY_CONFIGFILE});
	my $shiny_file = $conf->{shiny}->{targetdir} . '/superphy-df_meta.RData';

	unless(-f $shiny_file) {
		warn "Shiny RData file $shiny_file not found.  Skipping test.";
		return;
	}
	
	# Load meta-data object
	my $R = Statistics::R->new();
    
    # Compare a few nominal values to ensure edits have made it to the shiny file
    # There are miltple potential issues with the display of meta-data in this R format
    # but they should be tested elsewhere.
    my $found = $R->run(
    	qq/load('$shiny_file')/,
    	qq/found <- any(grepl('$genome_label', row.names(df_meta)))/,
        q/cat(found)/
    );

	my $Test = Test::Builder::Module->builder;

	return $Test->like($found, qr/FALSE/, $test_name);
}

# Check if allele counts are equal in Panseq pan_genome.txt file and in DB
sub alleles_count_ok {
	my ($schema, $feature_id, $file, $test_name) = @_;

	my $Test = Test::Builder::Module->builder;

	# Count alleles in file
	my $num_a = 0;
	open(my $in, "<$file") or die "Error: unable to read file $file ($!).\n";
	while(<$in>) {
		$num_a++;
	}
	close $in;
	$num_a--; # Subtract header

	# Retrieve
	

	# Retrieve global tree
	my $genome_label = "private_$feature_id";
	my $tree = $schema->resultset('Tree')->find({name => 'global'});

	return $Test->like($tree->tree_string, qr/$genome_label/, $test_name);

}

sub sandbox_directory {

	my $cfg_file = $ENV{SUPERPHY_CONFIGFILE};

	my $cfg = Config::Tiny->read($cfg_file);
	unless($cfg) {
		die $Config::Tiny::errstr;
	}

	return $cfg->{dir}->{sandbox};
}



1;