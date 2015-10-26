#!/usr/bin/env perl

=pod

=head1 NAME

Meta::insert_upload_parameters.pl

=head1 SYNOPSIS

insert_upload_parameters.pl --prop_directory dir --access setting --login_id user_login_id --config configfile

=head1 OPTIONS

  --prop_directory    Directory containing property files for each genome (used as input to loading pipeline)
  --login_id          Login_id to insert into upload properties
  --access            Genome release access setting [public|private]
  --copy              Make copy of parameter file before inserting new text

=head1 DESCRIPTION

A utility script that inserts a couple of additional upload parameters into the Meta/Miner.pm's meta-data loading pipeline input files.

Add login_id and access setting needed in the property file.  You need to look up corresponding login_id in login table matching upload user.
Access setting currently is either [public|private]. 'Release'-mode has not been implemented but should be easy to do, when needed.

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

use v5.18; # Needed since someone decided to use some experimental features

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use File::Basename qw/dirname/;
use lib dirname(__FILE__) . '/../';
use Data::Dumper;
use File::Copy;

# Parse command-line arguments
my ($login_id, $access, $propdir, $make_copy, $DEBUG, $MANPAGE);
print GetOptions(
    'access=s'     => \$access,
    'login_id=s'    => \$login_id,
    'prop_directory=s' => \$propdir,
    'copy'             => \$make_copy,
    'manual'   => \$MANPAGE,
    'debug'    => \$DEBUG,
) or pod2usage(-verbose => 1, -exitval => -1);

pod2usage(-verbose => 1, -exitval => 1) if $MANPAGE;

die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --login_id.") unless $login_id;
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --access.") unless $access;
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: invalid argument: --access $access. Allowed values: public|private.") 
	unless $access eq 'public' || $access eq 'private';
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: invalid argument: --login_id. Must be numeric ID from login table.") 
	unless $login_id =~ m/^\d+$/;
die pod2usage(-verbose => 1, -exitval => -1, -msg => "Error: missing argument: --prop_directory.") unless $propdir;


# Get property files in directory
opendir(my $in, $propdir) or die "Error: unable to read directory $propdir ($!)\n";
my @files = readdir($in);

my @prop_files = grep(/superphy.+params/, @files);

closedir($in);

print "\nFound ".scalar(@prop_files)." superphy parameter files in directory $propdir.\n";

my $upload_params = {
	login_id => $login_id,
	category => $access
};

my $upload_string = Data::Dumper->Dump([$upload_params], ['upload_parameters']);
print "Adding:\n$upload_string\n";

foreach my $f (@prop_files) {

	my $target_f = "$propdir/$f";
	if($make_copy) {
		$target_f =~ s/params\./upload-params\./;
		copy("$propdir/$f",$target_f) or die "Error: copy failed ($!)";
	}
	open(my $in2, '>>', $target_f) or die "Error: unable to append to file $target_f ($!).\n";

	print $in2 $upload_string;

	close $in2;
}

print "complete\n";
