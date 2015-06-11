#!/usr/bin/env perl

=pod

=head1 NAME

Meta::ValidationRoutines.pm

=head1 DESCRIPTION

Simple program to look and count the amount of serotypes in titles

=head1 COPYRIGHT

This work is released under the GNU General Public License v3  http://www.gnu.org/licenses/gpl.htm

=head1 AUTHORS

Nicolas Tremblay E<lt>nicolas.tremblay@phac-aspc.gc.caE<gt>

Matt Whiteside E<lt>matthew.whiteside@phac-aspc.gov.caE<gt>

=cut

package Meta::ValidationRoutines;

use strict;
use warnings;
use Data::Dumper;
use Role::Tiny;
use Locale::Country;
use Geo::Coder::Google::V3;
use JSON;

# use module
use XML::Simple;
use Data::Dumper;

# create object
my $xml = new XML::Simple;


my @files = glob("*.xml");
my $data;
my $title="";
my $found = 0;
my $notFountInAttribute = 0;
my $fountInTitleAndAttribute = 0;
my $total = 0;
my $totalSero = 0;
foreach my $file (@files) {
    # read XML file
  $data = $xml->XMLin($file);
  $title = $data->{BioSample}->{Description}->{Title};
  if($title =~ /:/&& $title !~ /Pathogen:/){
    
    foreach my $sero ($data->{BioSample}->{Attributes}->{Attribute}){
      if(ref($sero) eq 'ARRAY'){
        foreach my $spAttribute (@{$sero}){
          
          if($spAttribute->{attribute_name} eq "serovar"||$spAttribute->{attribute_name} eq "serotype"||$spAttribute->{attribute_name} eq "serogroup"){
            $found =1;
            $fountInTitleAndAttribute++;
            #print $title."---->".$spAttribute->{content};
            #print "\n";
          }
        }
      }else{
        if($sero->{attribute_name} eq "serovar"||$sero->{attribute_name} eq "serotype"||$sero->{attribute_name} eq "serogroup"){
          $found =1;
          $fountInTitleAndAttribute++;
          #print $title."---->".$sero->{content};
          #print "\n";
        }
      }


    }
    if($found eq 0){
      $notFountInAttribute++;
      print "In title only ".$title."\n";
    }
    $found = 0;
  }
  #count the number of serovar serotype attributes
  foreach my $sero ($data->{BioSample}->{Attributes}->{Attribute}){
      if(ref($sero) eq 'ARRAY'){
        foreach my $spAttribute (@{$sero}){
          
          if($spAttribute->{attribute_name} eq "serovar"||$spAttribute->{attribute_name} eq "serotype"||$spAttribute->{attribute_name} eq "serogroup"){
            $totalSero++;
          }
        }
      }else{
        if($sero->{attribute_name} eq "serovar"||$sero->{attribute_name} eq "serotype" ||$sero->{attribute_name} eq "serogroup"){
          $totalSero++;
        }
      }
  }
  
  $total++;
}
print "Total samples is ".$total."\nNumber of serotype/serovar/serogroup in Attributes = ".$totalSero."\nSero in title and attribute = ".$fountInTitleAndAttribute."\nSero Only in title = ".$notFountInAttribute,"\n";




