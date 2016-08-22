#!/usr/bin/perl

use strict;
use XML::Simple;
use Data::Dumper;

# This script is adapted from convertInfoXml.pl to generate dataSourceAttribution xml for a list Data
# Sources. Optionally the old name for the resource can be specified in the input file (2nd Col) along
# with the *Resources.xml file (ex. cryptoResources.xml file) which has the resource info under the old
# names for populating the contents into the  new xml format (for those attributes that can be mapped). 

if (!@ARGV) {
 die  "\nusage: perl\tgenerateDataSourceAttrXml.pl\tmapping_file\told_resource_file\n\nFormat of mapping_file: new_data_source_name\told_data_source_name(optional)\n\n";
} 

my %extDBTranslator;
open (fileHandle, shift);
while (<fileHandle>) {
  chomp;
  my $name = $_;
  my @names = split(/\t/,$name);
  $names[0] =~ s/ //g;
  $extDBTranslator{$names[0]} = $names[1];
}
close(fileHandle);


my $xs = XML::Simple->new(ForceArray => 1,  KeepRoot => 1, AttrIndent => 1, NoEscape => 1);
my $xmlFull = $xs->XMLin(join('', <DATA>));

my $template = pop @{$xmlFull->{dataSourceAttributions}->[0]->{dataSourceAttribution}};

my $templateOut = XML::Simple->new(ForceArray => 1, RootName => 'dataSourceAttribution');
my $templateXml = $templateOut->XMLout($template);


my $xsRes = XML::Simple->new(KeyAttr => {resource => "resource"},ForceArray => 1,NoEscape => 1);
my $oldResourceInfo = $xsRes->XMLin(shift);

#print Dumper $oldResourceInfo;

foreach my $dsName (keys %extDBTranslator) {

  # make a copy of the template
  my $dsAttribution = $xs->XMLin($templateXml);
  my $attribution = $dsAttribution->{dataSourceAttribution}->[0];

  if ($extDBTranslator{$dsName}) {
    my $ri = $oldResourceInfo->{resource}->{$extDBTranslator{$dsName}};
   
    my $resource = $ri->{resource};
    my $category = $ri->{category};
    my $publication = $ri->{publication};
    my $manGet = $ri->{manualGet};
    my $element = @$manGet[0];
    my $contactName = $element->{contact};
    my $email = $element->{email};
    my $institution = $element->{institution};

    my $description = $ri->{description}->[0];
    my $displayName = $ri->{displayName};
    my $publicUrl = $ri->{publicUrl};


    $attribution->{contacts}->[0]->{contact}->[0]->{name}->[0] = $contactName;
    $attribution->{contacts}->[0]->{contact}->[0]->{email}->[0] = $email;
    $attribution->{contacts}->[0]->{contact}->[0]->{institution}->[0] = $institution;
    $attribution->{description}->[0] = "<![CDATA[" . $description . "]]>";
    $attribution->{resource} = $dsName;
    $attribution->{publications}->[0]->{publication} = $publication;
    $attribution->{displayName}->[0] = $displayName;
    $attribution->{links}->[0]->{link}->[0]->{url} = $publicUrl;
    $attribution->{links}->[0]->{link}->[0]->{type} = 'publicUrl';
   } else {
    my $attribution = $dsAttribution->{dataSourceAttribution}->[0];
    $attribution->{resource} = $dsName;
   }    
   push @{$xmlFull->{dataSourceAttributions}->[0]->{dataSourceAttribution}}, $attribution;
}

my $out = $xs->XMLout($xmlFull);
print $out;


__DATA__
<?xml version="1.0"?>
<!DOCTYPE dataSourceAttributions SYSTEM "dataSourceAttributions.dtd">

<dataSourceAttributions>

  <dataSourceAttribution  resource="" overriddingType="" overridingSubtype="" ignore="true">

    <publications>
      <publication pmid="2"/>
      <publication pmid="1"/>
    </publications>

    <contacts>
       <contact isPrimaryContact="true">
           <name></name>
           <email></email>
           <institution></institution>
           <address></address>
           <city></city>
           <state></state>
           <country></country>
           <zip></zip>
       </contact>
    </contacts>

    <displayName><![CDATA[]]> </displayName>
    <summary><![CDATA[]]></summary>
    <protocol><![CDATA[]]></protocol>
    <caveat><![CDATA[]]></caveat>
    <acknowledgement><![CDATA[]]></acknowledgement>
    <releasePolicy></releasePolicy>
    <description><![CDATA[]]></description>

    <links>
        <link>
           <!-- downloadFile, SupplementartyData, sampleStrategy, publicUrl -->
           <type>downloadFile</type>
           <url><![CDATA[]]></url>
           <linkDescription></linkDescription>
        </link>
    </links>

    <wdkReference recordClass="" type="" name=""/>
  
  </dataSourceAttribution>

</dataSourceAttributions>
