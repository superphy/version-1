#!/usr/bin/env perl

=pod

=head1 NAME

t::QuickDB;

=head1 SNYNOPSIS

my $schema = t::QuickDB::connect()

=head1 DESCRIPTION

This module creates an DBICx::TestDatabase object, which is
an in-memory SQLlite instance of the Superphy DBIx::Class::Schema.
Some basic test data & users are be loaded.

This really only works for basic tests. Deeper testing on the database
will require the full PostgresDB.

See t::App on how to use this schema in the Superphy CGI::Application.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHOR

Matt Whiteside (matthew.whiteside@phac-aspc.gov.gc)

=cut

package t::lib::QuickDB;

use strict;
use warnings;
use Carp;
use FindBin;
use lib "$FindBin::Bin/../../";
use Modules::User;
use Data::Bridge;
use Data::Grouper;
use Modules::FormDataGenerator;
use Try::Tiny;
use DBICx::TestDatabase;
use Database::Chado::Schema;
use Test::More;
use Path::Tiny qw( path );
use File::Basename qw< dirname >;
     


## Globals
my $schema;
my $etc_directory = dirname(__FILE__) . '/../etc/';

=head2 make_schema

=cut
sub make_schema { 
    $schema ||= DBICx::TestDatabase->new( shift );
}

=head2 connect

=cut
sub connect {
    my $schema_name = 'Database::Chado::Schema';
    my $schema      = make_schema( $schema_name );
   
    try {
        create_ontology( $schema, $etc_directory.'testdb_cvterms.txt' );
        create_users( $schema );
        create_genome_features( $schema, $etc_directory.'sample1_public_genomes.txt' );
        create_private_genome_features( $schema, $etc_directory.'sample2_public_genomes.txt', 
            &login_crudentials()->{authen_username},
            'public'
        );
        create_private_genome_features( $schema, $etc_directory.'sample3_public_genomes.txt', 
            &evil_login_crudentials()->{authen_username},
            'private'
        );
    }
    catch {
        my $exception = $_;
        BAIL_OUT( 'Test data creation failed: ' . $exception );
    };

    return $schema;
}

=head2 create_users

Create test users

=cut
sub create_users {
    my $schema = shift; # DBICx schema object

    my @crudentials = (&login_crudentials(), &evil_login_crudentials());

    for my $i (0..1) {
        my $testuser_login_form = $crudentials[$i];

        my %test_user = (
            username => $testuser_login_form->{authen_username},
            password => Modules::User::_encode_password($testuser_login_form->{authen_password}),
            firstname => 'testbot-'.$i,
            lastname => '300'.$i,
            email => 'donotemailme@ever.com'
        );

        $schema->resultset('Login')->create( \%test_user )
            or croak "Error: insertion of new user into database failed ($!).\n";
    }

}

=head2 create_ontology

Add cv & cvterms

=cut
sub create_ontology {
    my $schema = shift; # DBICx schema object
    my $cv_file = shift; # File containing CV hash-ref string output by t::test_ontology.pl

    croak "Error: ontology hash-ref file $cv_file not found." unless $cv_file && -e $cv_file;

    # Load the genome feature hashref
    my $data = path($cv_file)->slurp;
    my $VAR1;
    eval $data;
    
    # Insert into the database
    $schema->resultset('Cv')->populate($VAR1);
}

=head2 login_crudentials

Test user login_crudentials

=cut
sub login_crudentials {

    return {
        authen_username => 'testbot',
        authen_password => 'password',
        authen_rememberuser => 0
    };
}

=head2 evil_login_crudentials

Second test user login_crudentials

=cut
sub evil_login_crudentials {

    return {
        authen_username => 'eviltestbot',
        authen_password => 'password',
        authen_rememberuser => 0
    };
}

=head2 create_genome_features

Add some public genome features and associated featureprops

=cut
sub create_genome_features {
    my $schema = shift; # DBICx schema object
    my $genome_file = shift; # File containing Feature hash-ref string output by t::test_genome_features.pl

    croak "Error: sample genome file $genome_file not found." unless $genome_file && -e $genome_file;

    # Load the genome feature hashref
    my $data = path($genome_file)->slurp;
    my $VAR1;
    eval $data;
    
    # Insert into the database
    $schema->resultset('Feature')->populate($VAR1);
}

=head2 create_private_genome_features

Add some private genome features and associated featureprops

=cut
sub create_private_genome_features {
    my $schema = shift; # DBICx schema object
    my $genome_file = shift; # File containing Feature hash-ref string output by t::test_genome_features.pl
    my $username = shift;
    my $category = shift;

    croak "Error: sample genome file $genome_file not found." unless $genome_file && -e $genome_file;
    croak "Error: missing/invalid upload category" unless $category && 
        ($category eq 'private' || $category eq 'public');

    # Load the genome feature hashref
    my $data = path($genome_file)->slurp;
    my $VAR1;
    eval $data;
   
    # Get login ID
    my $user = $schema->resultset('Login')->find({ username => $username });
    croak "Error: user $username not found." unless $user;
    my $login_id = $user->login_id;

    # Create upload entry
    # This is not transactionally-safe, but since this is a test DB, it should be ok.
    # I wanted to create the upload entry first since i wasnt sure if i embedded the 
    # upload hash in features/featureprops, the DBICx create command would connect all 
    # entries to the same upload row.
    my $upload = {
        login_id => $login_id,
        category => $category,
        permissions => [{
            can_modify => 1,
            can_share => 1,
            login_id => $login_id
        }]
    };
    my $upload_row = $schema->resultset('Upload')->create($upload);
    croak "Error: insertion of upload row into database failed.\n" unless $upload_row;
    my $upload_id = $upload_row->upload_id;
    
    # Convert public data into private data
    foreach my $feature (@$VAR1) {
        $feature->{upload_id} = $upload_id;
        foreach my $featureprop (@{$feature->{featureprops}}) {
            $featureprop->{upload_id} = $upload_id;
        }
        $feature->{private_featureprops} = $feature->{featureprops};
        delete $feature->{featureprops};
    }

    # Insert private genomes
    $schema->resultset('PrivateFeature')->populate($VAR1);
}

=head2 user

Test user for the quickdb database
    
=cut
sub user {

    return login_crudentials()->{authen_username};
}

=head2 evil_user

Test second user for the quickdb database
    
=cut
sub evil_user {

    return evil_login_crudentials()->{authen_username};
}

=head2 load_standard_groups

Load the standard data into the database

=cut
sub load_standard_groups {
    my $schema = shift;

    # Initialize DB interface objects via Bridge module
    my $dbBridge = Data::Bridge->new(schema => $schema);

    # Initialize Grouping module
    my $grouper = Data::Grouper->new(schema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory);

    # Initialize Data Retrival module
    my $data = Modules::FormDataGenerator->new(dbixSchema => $dbBridge->dbixSchema, cvmemory => $dbBridge->cvmemory);

    # Perform update / creation of standard groups
    $grouper->initializeStandardGroups(evil_user());
}


1;
