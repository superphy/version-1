package Modules::Snp;

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../";
use parent 'Modules::App_Super';
use Modules::FormDataGenerator;
use CGI::Application::Plugin::AutoRunmode;
use Log::Log4perl qw/get_logger/;
use Phylogeny::Tree;
use JSON;
use Time::HiRes;
use Proc::Daemon;
use Data::Uniqid qw/uniqid/;

=head2 setup

Defines the start and run modes for CGI::Application and connects to the database.

=cut

sub setup {
    my $self=shift;
    my $logger = Log::Log4perl->get_logger();
    $logger->info("Logger initialized in Modules::Snp");
}

=head2 info

Main SNP page

=cut

sub info : Runmode {
    my $self = shift;

    my $logger = Log::Log4perl->get_logger();

    # Params
    my $q = $self->query();
    
    my $snp_id = $q->param('snp');
    die "Error: missing parameter 'snp'" unless $snp_id;

    # Possible subset of genomes
    my @genomes = $q->param("genome");

    # Retreive SNP data
    my %snp_data;

    # Summary
    my $snp_rs = $self->dbixSchema->resultset('SnpCore')->search(
        {
            'snp_core_id' => $snp_id,
            'featureprops.type_id' => [$self->cvmemory('match'), $self->cvmemory('panseq_function')]
        },
        {
            columns => [qw/allele pangenome_region_id frequency_a frequency_t 
                frequency_g frequency_c frequency_gap frequency_other/],
            prefetch => { 'pangenome_region' => 'featureprops' }
        }
    );

    my $snp_row = $snp_rs->first;
    die "Error: no SNP entry found in DB matching snp_id $snp_id.\n" unless $snp_row;

    my $fp_rs = $snp_row->pangenome_region->featureprops;
    my $blast_desc = 0;
    my $blast_id = 0;
    while(my $fp_row = $fp_rs->next) {
        if($fp_row->type_id eq $self->cvmemory('match')) {
            die "Error: multiple pangenome BLAST ID annotations" if $blast_id;
            $blast_id = $fp_row->value;
        } elsif($fp_row->type_id eq $self->cvmemory('panseq_function')) {
            die "Error: multiple pangenome BLAST description annotations" if $blast_desc;
            $blast_desc = $fp_row->value;
        } else {
            die "Error: unrecognized featureprop type ID ".$fp_row->type_id;
        }
    }

    # Genome alleles
    my $user = $self->authen->username;
    my $warden;
    if(@genomes) {
        $warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, genomes => \@genomes, user => $user, cvmemory => $self->cvmemory);
        my ($err, $bad1, $bad2) = $warden->error; 
        if($err) {
            # User requested invalid strains or strains that they do not have permission to view
            $self->session->param( status => '<strong>Permission Denied!</strong> You have not been granted access to uploaded genomes: '.join(', ',@$bad1, @$bad2) );
            return $self->redirect( $self->home_page );
        }
        
    } else {
        
        $warden = Modules::GenomeWarden->new(schema => $self->dbixSchema, user => $user, cvmemory => $self->cvmemory);
    }

    my ($public_genomes, $private_genomes) = $warden->featureList();

    # Get genomes with pangenome region and their variations
    my %genome_snps;
    my $present = 0;
    my $absent = 0;
    my %freq = (
        A => 0,
        T => 0,
        G => 0,
        C => 0,
        '-' => 0,
        'other' => 0,
    );
    my $nucPattern = "[ATGC\-]";
    my $bkg_allele = uc $snp_row->allele;
    $logger->info("BACKGROUND ALLELE: $bkg_allele");
    unless($bkg_allele =~ m/$nucPattern/) {
        $bkg_allele = 'other';
    }

    my $cond = {
        'me.type_id' => $self->cvmemory('derives_from'),
        'me.object_id' => $snp_row->pangenome_region_id
    };

    if($warden->numPublic) {
        # Retrieve SNP variations
        my $var_rs = $self->dbixSchema->resultset('SnpVariation')->search(
            {
                snp_id => $snp_id
            }
        );

        while (my $var_row = $var_rs->next) {
            # Store snp variations
            my $genome_label = 'public_'.$var_row->contig_collection_id;
            my $a = uc $var_row->allele;
            $genome_snps{$genome_label} = $a;
            
            if($a =~ m/$nucPattern/) {
                $freq{$a}++;
            } else {
                 $freq{'other'}++;
            }

            print STDERR "$genome_label has $a\n";
        }

        # Retrieve region hits
        $cond->{'feature_relationship_subjects.type_id'} = $self->cvmemory('part_of');
        $cond->{'feature_relationship_subjects.object_id'} = {'-in' => $public_genomes} if $warden->subset;

        my $pg_rs = $self->dbixSchema->resultset('FeatureRelationship')->search(
            $cond,
            {
                prefetch => {'subject' => 'feature_relationship_subjects'}
            }
        );

        while (my $pg_row = $pg_rs->next) {
            # Store background allele hits
            $present++;

            my $loci_row = $pg_row->subject;
            my $genome_label = 'public_'.$loci_row->feature_relationship_subjects->first->object_id;

            next if defined $genome_snps{$genome_label};

            # Matches background
            $genome_snps{$genome_label} = $bkg_allele;
            $freq{$bkg_allele}++;
        }


    }

    if($warden->numPrivate) {

        # Retrieve SNP variations
        my $var_rs = $self->dbixSchema->resultset('PrivateSnpVariation')->search(
            {
                snp_id => $snp_id
            }
        );

        while (my $var_row = $var_rs->next) {
            # Store snp variations
            my $genome_label = 'private_'.$var_row->contig_collection_id;
            my $a = uc $var_row->allele;
            $genome_snps{$genome_label} = $a;
            
            if($a =~ m/$nucPattern/) {
                $freq{$a}++;
            } else {
                 $freq{'other'}++;
            }
        }

        # Retrieve pangenome hits
        $cond->{'private_feature_relationship_subjects.type_id'} = $self->cvmemory('part_of');
        $cond->{'private_feature_relationship_subjects.object_id'} = {'-in' => $private_genomes};

        my $pg_rs = $self->dbixSchema->resultset('PripubFeatureRelationship')->search(
            $cond,
            {
                prefetch => {'subject' => 'private_feature_relationship_subjects'}
            }
        );

        while (my $pg_row = $pg_rs->next) {
            # Store background allele hits
            $present++;

            my $loci_row = $pg_row->subject;
            my $genome_label = 'private_'.$loci_row->private_feature_relationship_subjects->first->object_id;

            next if defined $genome_snps{$genome_label};

            # Matches background
            $genome_snps{$genome_label} = $bkg_allele;
            $freq{$bkg_allele}++;
        }
    }

     # Add missing
    foreach my $g (@{$warden->genomeList()}) {
        next if defined $genome_snps{$g};

        $absent++;
        $genome_snps{$g} = 'absent';
    }

    my $fdg = Modules::FormDataGenerator->new();
    $fdg->dbixSchema($self->dbixSchema);
    
    my $username = $self->authen->username;
    my ($pub_json, $pvt_json) = $fdg->genomeInfo($username);

   
    my $template = $self->load_tmpl('snps_info.tmpl', die_on_bad_params => 0);

    $template->param(snpid => $snp_id);
    $template->param(a_frequency => $freq{A});
    $template->param(t_frequency => $freq{T});
    $template->param(g_frequency => $freq{G});
    $template->param(c_frequency => $freq{C});
    $template->param(gap_frequency => $freq{'-'});
    $template->param(other_frequency => $freq{other});
    $template->param(pangenomeid => $snp_row->pangenome_region_id);
    $template->param(blast_desc => $blast_desc);
    $template->param(blast_id => $blast_id);
    if($blast_id && $blast_id =~ m/ref\|(\w\.)+/) {
        $template->param(refseq_id => $1);
    } 
    $template->param(blast_id => $blast_id);
    $template->param(pangenome_present => $present);
    $template->param(pangenome_absent => $absent);

    $template->param(public_genomes => $pub_json);
    $template->param(private_genomes => $pvt_json);

    $template->param(title1 => 'SNP');
    $template->param(title2 => 'INFORMATION');

    return $template->output();
}


=head2 submit

Initiate request to retrieve SNP positions

=cut

sub submit : Runmode {
    my $self = shift;

    my $logger = Log::Log4perl->get_logger();

    # Params
    my $q = $self->query();
    
    my $snp_id = $q->param('snp');
    die "Error: missing parameter 'snp'" unless $snp_id;

    # Start job
    my $config = { snp_core_id => $snp_id };
    my $cmd = "perl output_snp_positions.pl --config ".$self->config_file;
    my $job_id = $self->_submitJob(config => $config, cmd => $cmd);

    # Return result
    my $json_result = encode_json({ job => $job_id });

    return $json_result;
}

=head2 _submitJob

=cut

sub _submitJob {
    my $self = shift;
    my %p = @_;

    # Job parameters
    my $status = "Initializing";
    my $user_id = undef;
    my $username = $self->authen->username;
    my $raddr = $self->session->remote_addr();
    my $session = $self->session->id();
    die "Error: missing parameter in _submitJob call." unless $p{config} && $p{cmd};
    my $config = encode_json($p{config});
    my $results = undef;
    my $job_id = uniqid();

    my $new_job = $self->dbixSchema->resultset('JobResult')->new({
        'job_result_id' => $job_id,
        'remote_address' => $raddr,
        'session_id' => $session,
        'user_id' => $user_id,
        'username' => $username,
        'user_config' => $config,
        'job_result_status' => $status,
        'result' => $results
    });

    $new_job->insert();
    get_logger->info("Job $job_id for snp download submitted") if $new_job->in_storage() || die "Error: unable to initialize new snp download job.\n";

    # Fork job
    my $log_dir = $self->config_param('dir.log');
    my $cmd = $p{cmd} . " --job $job_id";

    my $daemon = Proc::Daemon->new(
        work_dir => "$FindBin::Bin/../../Data/",
        exec_command => $cmd,
        child_STDERR => "+>>$log_dir"."snp_download_jobs.log"
    );

    $self->teardown;

    my $kid_pid = $daemon->Init;
    get_logger->info("Job $job_id running under PID $kid_pid");

    return $job_id;
}


=head2 poll

Check if request is completed

=cut

sub poll : Runmode {
    my $self = shift;

    my $q = $self->query();
    
    my $job_id = $q->param('job');
    
    # Retrieve job data
    unless($job_id) {
        die("Missing query parameter: job")
    }
    my $job = $self->dbixSchema->resultset('JobResult')->find($job_id);
    unless($job) {
        die("No record matching ID $job_id in job_result table.");
    }
    
    # Check user
    my $user = $self->authen->username;
    my $submitter = $job->username;
    
    if($user ne $submitter) {
        # User requested invalid strains or strains that they do not have permission to view
        $self->session->param( status => '<strong>Permission Denied!</strong> You do not have access to job: '.$job_id );
        return $self->redirect( $self->home_page );
    }

    # Return job status
    my $status = $job->job_result_status;
    my $response = 'running';
    if($status eq 'Complete') {
        $response = 'ready';
    }

    return encode_json({status => $response});
}


=head2 download

Return completed SNP request

=cut

sub download : Runmode {
	my $self = shift;

    my $q = $self->query();
    
    my $job_id = $q->param('job');
    
    # Retrieve job data
	unless($job_id) {
		die("Missing query parameter: job")
	}
	my $job = $self->dbixSchema->resultset('JobResult')->find($job_id);
	unless($job) {
		die("No record matching ID $job_id in job_result table.");
	}
	
	# Check user
	my $user = $self->authen->username;
	my $submitter = $job->username;
	
	if($user ne $submitter) {
		# User requested invalid strains or strains that they do not have permission to view
		$self->session->param( status => '<strong>Permission Denied!</strong> You do not have access to job: '.$job_id );
		return $self->redirect( $self->home_page );
	}
	
	# Retrieve results
	my $result_json = $job->result;
	my $results = decode_json($result_json);
	
	unless($results) {
		die("No results for job $job_id");
	}
	
	# Produce CSV output
	my @rows;
	my @fields = qw/genome allele contig position gap_offset strand upstream downstream/;
	# Header
	my @header = qw/Genome Allele Contig Position Gap_Offset Strand 100bp_Upstream 100bp_Downstream/;
	push @rows, '#'.join("\t", @header);
	
	foreach my $k (keys %$results) {
		my $r = $results->{$k};
		my @row;
		
		foreach my $f (@fields) {
			my $d = $r->{$f};
			warn "Found undefined field $f in SNP job $job_id." unless $d;
			push @row, $d;
		}
		
		push @rows, join("\t", @row);
	}
	
	# Pipe text to user
	my $output = join("\n", @rows);
	
	$self->header_add( 
		-type => 'text/plain',
		-Content_Disposition => "attachment");
		
	return $output;
}

1;