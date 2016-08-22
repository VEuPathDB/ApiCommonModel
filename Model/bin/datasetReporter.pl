#!/usr/bin/perl

use strict;


use DBI;
use DBD::Oracle;
use Getopt::Long;
use CBIL::Util::PropertySet;

use ApiCommonShared::Model::DataSourceAttributions;
use ApiCommonShared::Model::DataSourceAttribution;
use ApiCommonShared::Model::DataSourceWdkReferences;
use ApiCommonShared::Model::DataSourceList;

use Data::Dumper;

my ($help, $projectId, $instanceName, $gusConfigFile);

&GetOptions('help|h' => \$help,
            'projectId=s' => \$projectId,
            'instanceName=s' => \$instanceName,
            'gusConfigFile=s' => \$gusConfigFile,
            );

if($help) {
  &usage();
}

unless($projectId && $instanceName) {
  &usage("projectId and instanceName are required");
}

my $attributionsDirectory = $ENV{GUS_HOME} . "/lib/xml/dataSourceAttributions";

my $globalXml = $attributionsDirectory . "/global.xml";
my $projectXml = $attributionsDirectory . "/${projectId}.xml";

my $dtdErrors = `xmllint --valid --noout  $globalXml $projectXml 2>&1`;
chomp($dtdErrors);

if($dtdErrors) {
  print STDERR "$dtdErrors\n\n";
  die "\nxml did not pass xml validation.";
}

$instanceName = "dbi:Oracle:$instanceName";

$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);
die "gus config file $gusConfigFile does not exist" unless(-e $gusConfigFile);

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};

my $dbh = DBI->connect($instanceName, $u, $pw) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;


my $dsList = ApiCommonShared::Model::DataSourceList->new($dbh);
my $dataSourcesAsHash = $dsList->getDataSources();


my $dsWdkRefXmlPath = $attributionsDirectory . "/dataSourceWdkReferences.xml";
my $dataSourceWdkReferences = ApiCommonShared::Model::DataSourceWdkReferences->new($dsWdkRefXmlPath);


my $globalAttributions = ApiCommonShared::Model::DataSourceAttributions->new($globalXml, 
                                                                             $dataSourceWdkReferences,
                                                                             $dsList
                                                                             );

my $projectAttributions = ApiCommonShared::Model::DataSourceAttributions->new($projectXml, 
                                                                              $dataSourceWdkReferences,
                                                                              $dsList
                                                                              );

my @globalDsNames = $globalAttributions->getDataSourceAttributionNames();
my @projectDsNames = $projectAttributions->getDataSourceAttributionNames();


my $test = $globalAttributions->getDataSourceAttribution('_dbEST_RSRC$');
print $test->getNameIsRegex . "**** \n";


# Check that nothing is included in BOTH global and project
&report("****** found in both project.xml and global.xml ****** ");
foreach my $globalDsName (@globalDsNames) {
  foreach my $projectDsName (@projectDsNames) {
    if($globalDsName eq $projectDsName) {
      &report($globalDsName);
    }
  }
}

# check that everything in global & project exist in dslist
&report("****** global resource  not found in the database ****** ");
foreach my $globalDsName (@globalDsNames) {
  my $attr = $globalAttributions->getDataSourceAttribution($globalDsName);

  my @matching;
  if($attr->isNameRegex()) {
    @matching = grep {/$globalDsName/} ($dsList->getDbDataSourceNames());
  }
  else {
    push @matching, $globalDsName;
  }

  # regex didn't match anything
  if(scalar @matching < 1) {
    &report($globalDsName);
  }

  foreach(@matching) {
    if($dataSourcesAsHash->{$_}) {
      $dataSourcesAsHash->{$_}->{_seen} = 1;
    }
    else {
      &report($globalDsName);
    }
  }
}


# check that everything in global & project exist in dslist
&report("****** project specific resource  not found in the database ****** ");
foreach my $projectDsName (@projectDsNames) {
  my $attr = $projectAttributions->getDataSourceAttribution($projectDsName);

  my @matching;
  if($attr->isNameRegex()) {
    @matching = grep {/$projectDsName/} ($dsList->getDbDataSourceNames());
  }
  else {
    push @matching, $projectDsName;
  }

  # regex didn't match anything
  if(scalar @matching < 1) {
    &report($projectDsName);
  }

  foreach(@matching) {
    if($dataSourcesAsHash->{$_}) {
      $dataSourcesAsHash->{$_}->{_seen} = 1;
    }
    else {
      &report($projectDsName);
    }
  }
}


my @internalGlobalNames = $globalAttributions->getInternalDataSourceNames();
my @internalProjectNames = $projectAttributions->getInternalDataSourceNames();


my @allinternal = (@internalGlobalNames, @internalProjectNames);

my @internalButAttributed;

&report("***** Data Source found in internal list but not in Database *****");
foreach my $resource (@allinternal) {
  next unless $resource;

  my @matching;

  if(ref($resource) eq 'HASH') {
    my $content = $resource->{content};
    my $nameIsRegex = $resource->{nameIsRegex};

    @matching = grep {/$content/} ($dsList->getDbDataSourceNames());
  }
  else {
    push @matching, $resource;
  }
  

  foreach(@matching) {
    if($dataSourcesAsHash->{$_}) {
      if($dataSourcesAsHash->{$_}->{_seen}) {
        push @internalButAttributed, $_;
      }
      else {
        $dataSourcesAsHash->{$_}->{_seen} = 1;
      }
    }
    else {
      &report($_);
    }
  }
}

&report("**** Internal Datasource reported but it ALSO had attribution ****");
foreach(@internalButAttributed) {
  &report($_);
}



# report extra from ds list that are missing from both global and project
&report("****** data source was loaded but no attribution was found in either global or project ****** ");
foreach my $ds (sort {$a->{NAME} cmp $b->{NAME} } values %{$dataSourcesAsHash}) {
  my $dsName = $ds->{NAME};
  unless($ds->{_seen}) {
    &report($dsName);
  }
}


$dbh->disconnect();


sub report {
  my $m = shift;
  print $m . "\n";
}

sub usage {
  my $m = shift;

  if($m) {
    print STDERR "$m\n\n";
  }

  print STDERR "usage:\nperl datasourceReporter.pl --projectId=s --instanceName=s gusConfigFile <GUS_CONFIG>\n";
  exit;
}

1;



