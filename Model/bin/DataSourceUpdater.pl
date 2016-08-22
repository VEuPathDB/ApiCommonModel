#!/usr/bin/perl

use strict;

use XML::Simple;

use Getopt::Long;

use Data::Dumper;

my ($ResourceXML, $DatasetAttributionXML, $mappingFile);

GetOptions("sourceFile=s" => \$ResourceXML,
           "outputFile=s" => \$DatasetAttributionXML,
           "mappingFile=s" => \$mappingFile);

  my $sourceData = new XML::Simple;
  my $source = $sourceData->XMLin($ResourceXML, ForceArray => 1, KeyAttr => { resource => '+resource',  NoAttr => 0}) if ($ResourceXML);


#   open my $fh, '>', $DatasetAttributionXML or die "open ( $DatasetAttributionXML): $!";
#   XMLout($source,OutputFile => $fh);
#   close $fh;
#   print STDERR Dumper($source);


my $usage = " usage - DataSourceUpdater.pl --sourceFile [old resource.xml file name] --outputFile [new data source attribution file name] --mappingFile [mapping tab file name]";

my $fh;
unless ($DatasetAttributionXML) {
  print STDERR "outputFile is required/n$usage";
}
else {
#  print STDERR $DatasetAttributionXML;
  open $fh, '>', $DatasetAttributionXML or die "open ( $DatasetAttributionXML): $!/n$usage";
}

my %mapping;
unless ($mappingFile) {
  print STDERR "mappingFile is required/n$usage";
}

else {
  open (FILE, $mappingFile);
  while (<FILE>) {
    chomp;
    my($oldName,$newName) = split("\t");
    $mapping{$newName} = $oldName unless $newName =~m/^#/;
  }
  close (FILE);
}

while (my ($newName, $oldName) = each %mapping ) {
  my $resource =  $newName;
  my $publication = $legacyResource -> { 'publication' }[0]->{pmid};
  my $contact_name = $legacyResource -> { 'manualGet' }[0] -> { 'contact' };
  my $contact_email = $legacyResource -> { 'manualGet' }[0] -> { 'email' };
  my $contact_institution = $legacyResource -> { 'manualGet' }[0] -> { 'institution' };
  my $displayName = $legacyResource -> {'displayName'};
  my $descriptionText = $legacyResource -> { 'description' }[0];
  if(ref($descriptionText) eq 'HASH') {
    print STDERR "I AM A HASH...\n";
    print STDERR Dumper $descriptionText;
  }
  my $description = "<![CDATA[ $descriptionText ]]>";
  my $xmlNode ="
  <dataSourceAttribution resource=\"$resource\" overridingType=\"\" overridingSubtype=\"\" ignore=\"\">
       <displayCategory></displayCategory>
       <publications>
         <publication  pmid=\"$publication\" />
       </publications>

       <contacts>
          <contact isPrimaryContact=\"true\">
             <name>\"$contact_name\"</name>
             <email>\"$contact_email\"</email>
             <institution>\"$contact_institution\"</institution>
             <address></address>
             <city></city>
             <state></state>
             <country></country>
             <zip></zip>
          </contact>
       </contacts>

       <displayName><![CDATA[$displayName]]></displayName>

       <summary></summary>

       <protocol></protocol>
       <caveat></caveat>
       <acknowledgement></acknowledgement>
       <releasePolicy></releasePolicy>

       <description>$description</description>

       <links>
          <link>
             <type>publicUrl</type>
             <url></url>
             <linkDescription></linkDescription>
          </link>
       </links>

       <wdkReference recordClass=\"\" type=\"\" name=\"\" />
    </dataSourceAttribution>
 ";

print $fh $xmlNode;

}
