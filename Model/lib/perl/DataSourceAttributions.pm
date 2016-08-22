package ApiCommonShared::Model::DataSourceAttributions;

use strict;

use ApiCommonShared::Model::DataSourceAttribution;

use XML::Simple;
use Data::Dumper;

sub new {
  my ($class, $dataAttributionsXmlFile, $dataSourceWdkReferences, $dbDataSourceList) = @_;

  my $self = {};
  
  bless($self,$class);

  my %displayCategories;

  $self->{dataAttributionsXmlFile} = $dataAttributionsXmlFile;
  $self->{dataSourceWdkReferences} = $dataSourceWdkReferences;
  $self->{dbDataSourceList} = $dbDataSourceList;
  $self->{displayCategories} = %displayCategories;
  
  $self->_parseXmlFile();

  return $self;
}

# Deprecated
sub getXmlFile { $_[0]->getDataAttributionsXmlFile() }

sub getDataAttributionsXmlFile {
  my ($self) = @_;
  return $self->{dataAttributionsXmlFile};
}

sub getDataSourceWdkReferences {
  my ($self) = @_;
  return $self->{dataSourceWdkReferences};
}


sub getDisplayCategories {
  my ($self) = @_;
  return $self->{displayCategories};
}

sub setProjectId {
  my ($self,$projectId) = @_;
  return $self->{projectId} = $projectId;
}


sub getInternalDataSourceNames {
  my ($self) = @_;

  if(my $internalDataSources = $self->{data}->{internalDataSources}) {
    return wantarray ? @{$internalDataSources->{resource}} : $internalDataSources->{resource};;
  }
}

sub getDataSourceAttributionNames {
  my ($self) = @_;

  my $attributionObj = $self->{data}->{dataSourceAttribution};

  return keys(%$attributionObj);
}


sub checkIfRegEx {
  my ($self, $dsName) = @_;

  return $self->{data}->{dataSourceAttribution}->{$dsName}->{nameIsRegEx};
}




sub getDataSourceAttribution {
    my ($self, $dataSourceName) = @_;

    die "can't find resourceInfo '$dataSourceName' in xml file $self->{dataAttributionsXmlFile}"
      unless $self->{data}->{dataSourceAttribution}->{$dataSourceName};

    return ApiCommonShared::Model::DataSourceAttribution->new($dataSourceName, $self->{data}->{dataSourceAttribution}->{$dataSourceName}, $self);
}

sub _parseXmlFile {
  my ($self) = @_;

  my $dataAttributionsXmlFile = $self->getDataAttributionsXmlFile();
  my %displayCatg;

  my $xmlString = `cat $dataAttributionsXmlFile`;
  my $xml = new XML::Simple();
  $self->{data} = eval{ $xml->XMLin($xmlString, SuppressEmpty => 1, KeyAttr => 'resource', ForceArray=>['dataSourceAttribution','contact','publication','link','wdkReference','resource']) } ;
  die "$@\n$xmlString\nerror processing XML file $dataAttributionsXmlFile\n" if($@);

  if(my $dataSourceWdkRefs = $self->getDataSourceWdkReferences()) {

    my $dbDataSourceObj = $self->{dbDataSourceList};

    foreach my $resourceName (keys %{$self->{data}->{dataSourceAttribution}}) {

      my $attributionObj = $self->{data}->{dataSourceAttribution}->{$resourceName};
    

      my $nameIsRegEx = $self->checkIfRegEx($resourceName);
      if ($nameIsRegEx eq "true") {
         $resourceName = qq($resourceName);
         my ($dbDataSourceName) = grep {$_ =~ /$resourceName/} ($dbDataSourceObj->getDbDataSourceNames());
         ($resourceName = $dbDataSourceName) unless (!$dbDataSourceName);
      }

      #set Type and Subtype for Display Category (when not specified).
      my $dataSourceType = $attributionObj->{overridingType};
      if ($dataSourceType eq '') { 
        my $dbDataSource = $dbDataSourceObj->dataSourceHashByName($resourceName);
        $dataSourceType = $dbDataSource->{TYPE};
      }

      my $dataSourceSubType = $attributionObj->{overridingSubtype};
      if ($dataSourceSubType eq '') {
        my $dbDataSource = $dbDataSourceObj->dataSourceHashByName($resourceName);
        $dataSourceSubType = $dbDataSource->{SUBTYPE};
      }

      my $resourceWdkRefs = $attributionObj->{wdkReference} ? $attributionObj->{wdkReference} : [];
      my $baseWdkRefs = $dataSourceWdkRefs->getDataSourceWdkRefsByName("$dataSourceType:$dataSourceSubType");
      my $displayCategory = $dataSourceWdkRefs->getDisplayCategoryByName("$dataSourceType:$dataSourceSubType");
      $displayCategory = 'Miscellaneous' if (!$displayCategory);
   
     foreach my $baseRef (@$baseWdkRefs) {
       my $baseRefType = $baseRef->{type};
       my $baseRefName = $baseRef->{name};
       $baseRefName =~ s/\@RESOURCE\@/$resourceName/;

       my $concat = 'false';
       if (($baseRefType) && ($baseRefName)){
         foreach my $wdkRef (@$resourceWdkRefs) {
           if (($wdkRef->{type} eq $baseRefType) && ($wdkRef->{name} eq $baseRefName)) {
             foreach my $txt (@{$wdkRef->{text}}) {
               if ($txt->{name} eq 'citation') {
                  foreach my $baseTxt (@{$baseRef->{text}}){
                    $txt->{content} = $baseTxt->{content}."\n".$txt->{content} unless ($baseTxt->{name} ne 'citation');
                    $concat = 'true';
                  }
               }
             }
           }
         }
         push (@$resourceWdkRefs,$baseRef) unless $concat eq 'true';
       }   
     }      

      $attributionObj->{wdkReference} = $resourceWdkRefs;

      #download links for genome attributions
      if ($dataSourceType eq 'genome' || $dataSourceType eq 'gene_annotation') {
        my $attrLinks = $attributionObj->{links}->{link} ? $attributionObj->{links}->{link} : [];
        my %downloadLink;
         $downloadLink{"url"}  = "http://PROJECT_ID.org/common/downloads/Current_Release/ORGANISM_ABBREV";
         $downloadLink{"type"}  = "downloadLink";
         $downloadLink{"linkDescription"}  = "Data files for Genome and Annotations";
       push @$attrLinks, \%downloadLink ;
       $attributionObj->{links}->{link} = $attrLinks;
      }
      
      $displayCatg{$resourceName} = $displayCategory;

      }
    $self->{displayCategories} = \%displayCatg;
   }

}

sub validateWdkReference {
  my ($self, $project, $record_class, $type, $name) = @_;

  $self->getWdkModel($project);

  # validate record class
  $record_class =~ /^(\S+)\.(\S+)$/ || die "invalid record class name '$record_class'";
  my $recordClassSet = $1;
  my $recordClass = $2;
  return 0 unless $self->{wdkModel}->{recordClassSets}->{$recordClassSet};
  return 0 unless $self->{wdkModel}->{recordClassSets}->{$recordClassSet}->{$recordClass};

  # validate question
  if ($type eq 'question') {
    $name =~ /^(\S+)\.(\S+)$/ || die "invalid question name '$name'";
    return 0 unless $self->{wdkModel}->{questionSets}->{$1};
    return $self->{wdkModel}->{questionSets}->{$1}->{$2};
  }

  # validate attribute
  elsif ($type eq 'attribute') {
    return 0 unless $self->{wdkModel}->{recordClassSets}->{$recordClassSet}->{$recordClass}->{attributes};
    return $self->{wdkModel}->{recordClassSets}->{$recordClassSet}->{$recordClass}->{attributes}->{$name};
  }

  # validate table
  elsif ($type eq 'table') {
    return 0 unless $self->{wdkModel}->{recordClassSets}->{$recordClassSet}->{$recordClass}->{tables};
    return $self->{wdkModel}->{recordClassSets}->{$recordClassSet}->{$recordClass}->{tables}->{$name};
  }

  else {
    die "invalid reference type";
  }

}

# parse the output of the wdkXml program to snatch the names of
# questions, records, tables and attributes
sub getWdkModel {
  my ($self, $project) = @_;

  return if $self->{wdkModel};  # already got it

  $self->{wdkModel}->{recordClassSets} = {};
  $self->{wdkModel}->{questionSets} = {};

  my $recordClassSet;
  my $recordClass;
  my $questionSet;
  my $gatheringAttributes;
  my $gatheringTables;
  my $gatheringQuestions;

  my $cmd = "wdkXml -model $project";
  open(WDKXML, "$cmd|") || die "Can't run '$cmd'";

  while (<WDKXML>) {
    chomp;
    if (/^RecordClassSet\: name=\'(.*)\'/) {
      $recordClassSet = $1;
    } elsif (/^Record\: name=\'(.*)\'/) {
      $self->{wdkModel}->{recordClassSets}->{$recordClassSet}->{$1} = {};
      $recordClass = $self->{wdkModel}->{recordClassSets}->{$recordClassSet}->{$1};
    } elsif (/^--- Attributes/) {
      $gatheringAttributes = 1;
    } elsif (/^--- Tables/) {
      $gatheringTables = 1;
      $gatheringAttributes = 0;
    } elsif (/^$/ || /^\s/) {
      $gatheringTables = 0;
      $gatheringAttributes = 0;
    } elsif (/^QuestionSet: name=\'(.*)\'/) {
      $self->{wdkModel}->{questionSets}->{$1} = {};
      $questionSet = $self->{wdkModel}->{questionSets}->{$1};
    } elsif (/^Question: name=\'(.*)\'/) {
      $questionSet->{$1} = 1;
    } elsif ($gatheringAttributes) {
      $recordClass->{attributes}->{$_} = 1
    } elsif ($gatheringTables) {
      $recordClass->{tables}->{$_} = 1
    }
  }
}

# JB: WHere is this used??
sub _substituteConstants {
  my ($self, $xmlFile) = @_;

  my $xmlString;
  open(FILE, $xmlFile) || die "Cannot open resource info XML file '$xmlFile'\n";
  my $constants;
  while (<FILE>) {
    my $line = $_;
    if (/\<constant/) {
	if (/\<constant\s+name\s*=\s*\"\(.*\)"\s+value\s*=\s*\"\(.*\)\"/) {
	    $constants->{$1} = $2;
	} else {
	    die "Can't parse <constant> element on line $. of $xmlFile.  Must be in form of:
    <constant name=\"xxx\" value=\"yyy\"/>\n";
	}
    }
    my @macroKeys = /\$\$([\w.]+)\$\$/g;   # allow keys of the form nrdb.release
    foreach my $macroKey (@macroKeys) {
      my $val = $constants->{$macroKey};
      die "Undefined constant '\$\$$macroKey\$\$' in xml file $xmlFile" unless defined $val;
      $line =~ s/\$\$$macroKey\$\$/$val/g;
    }
    $xmlString .= $line;
  }
  return $xmlString;
}

1;
