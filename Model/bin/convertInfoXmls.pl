#!/usr/bin/perl

use strict;
use XML::Simple;

my $xs = XML::Simple->new(ForceArray => 1,  KeepRoot => 1, AttrIndent => 1, NoEscape => 1);
my $xmlFull = $xs->XMLin(join('', <DATA>));

my $template = pop @{$xmlFull->{dataSourceAttributions}->[0]->{dataSourceAttribution}};

my $templateOut = XML::Simple->new(ForceArray => 1, RootName => 'dataSourceAttribution');
my $templateXml = $templateOut->XMLout($template);

foreach my $fn (<*Info.xml>) {
  my $info = $xs->XMLin($fn);

  foreach my $ri (@{$info->{resourceInfos}->[0]->{resourceInfo}}) {
    my $resource = $ri->{resource};

    # make a copy of the template
    my $dsAttribution = $xs->XMLin($templateXml);
    my $attribution = $dsAttribution->{dataSourceAttribution}->[0];
    my $contactName = $ri->{contact};
    my $institution = $ri->{institution};
    my $email = $ri->{email};
    my $description = $ri->{description}->[0];

    my $wdkReferences = $ri->{wdkReference};
    my $publication = $ri->{publication};
    my $displayName = $ri->{displayName};
    my $publicUrl = $ri->{publicUrl};

    $attribution->{contacts}->[0]->{contact}->[0]->{name}->[0] = $contactName;
    $attribution->{contacts}->[0]->{contact}->[0]->{email}->[0] = $email;
    $attribution->{contacts}->[0]->{contact}->[0]->{institution}->[0] = $institution;
    $attribution->{description}->[0] = "<![CDATA[" . $description . "]]>";
    $attribution->{resource} = $resource;
    $attribution->{wdkReference} = $wdkReferences;
    $attribution->{publications}->[0]->{publication} = $publication;
    $attribution->{displayName}->[0] = $displayName;
    $attribution->{links}->[0]->{link}->[0]->{url} = $publicUrl;
    $attribution->{links}->[0]->{link}->[0]->{type} = 'publicUrl';

    push @{$xmlFull->{dataSourceAttributions}->[0]->{dataSourceAttribution}}, $attribution;
  }
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
