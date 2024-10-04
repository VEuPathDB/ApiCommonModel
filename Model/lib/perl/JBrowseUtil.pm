package ApiCommonModel::Model::JBrowseUtil;

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";

use DBI;
use DBD::Oracle;
use WDK::Model::ModelConfig;
use Data::Dumper;

sub getDbh {
  my ($self) = @_;

  my $projectName = $self->getProjectName();

  my $modelConfig = new WDK::Model::ModelConfig($projectName);
  my $dbh = DBI->connect( $modelConfig->getAppDbDbiDsn(),
                            $modelConfig->getAppDbLogin(),
                            $modelConfig->getAppDbPassword()
        )
    || die "unable to open db handle to ", $modelConfig->getAppDbDbiDsn();

  $dbh->{LongTruncOk} = 0;
  $dbh->{LongReadLen} = 10000000;
  return $dbh;
}

# this is invariant - hard coded below
#my $datasetAndPresenterPropertiesBaseName = "datasetAndPresenterProps.conf";

# getters and setters for all class attributes
sub getCacheFile {$_[0]->{_cache_file}}
sub setCacheFile {$_[0]->{_cache_file} = $_[1]}

sub getFileName {$_[0]->{_fileName}}
sub setFileName {$_[0]->{_fileName} = $_[1]}

sub getType {$_[0]->{_type}}
sub setType {$_[0]->{_type} = $_[1]}

sub getOrganismAbbrev {$_[0]->{_organism_abbrev}}
sub setOrganismAbbrev {$_[0]->{_organism_abbrev} = $_[1]}

sub getProjectName {$_[0]->{_project_name}}
sub setProjectName {$_[0]->{_project_name} = $_[1]}

sub getBuildNumber {$_[0]->{_build_number}}
sub setBuildNumber {$_[0]->{_build_number} = $_[1]}

sub getType {$_[0]->{_type}}
sub setType {$_[0]->{_type} = $_[1]}

sub getBuildProperties {$_[0]->{_build_properties}}
sub setBuildProperties {$_[0]->{_build_properties} = $_[1]}

sub getWebserviceProperties {$_[0]->{_webservice_properties}}
sub setWebserviceProperties {$_[0]->{_webservice_properties} = $_[1]}

sub getWebservicesDir {$_[0]->{web_service_dir}}
sub setWebservicesDir {$_[0]->{web_service_dir} = $_[1]}

sub getwebServicePropertiesFilePath{$_[0]->{web_service_file_path}}
sub setwebServicePropertiesFilePath{$_[0]->{web_service_file_path} = $_[1]}

sub getDatasetProperties {$_[0]->{_dataset_properties}}
sub setDatasetProperties {$_[0]->{_dataset_properties} = $_[1]}

# standard to put new method first.
sub new {
  my ($class, $args) = @_;

  # we want class attributes to be private, so make an empty hash and bless that with your class
  my $self = {};
  bless ($self, $class);

  # now user your setters to populate it 
  $self->setProjectName($args->{projectName});
  $self->setOrganismAbbrev($args->{organismAbbrev});
  $self->setBuildNumber($args->{buildNumber});
  $self->setWebservicesDir($args->{webservicesDir});
  $self->setFileName($args->{fileName});

  my $type = lc($args->{type}) eq 'protein' ? 'protein' : 'genome';
  $self->setType($type);
 
 # this one is a bit odd because it calls a function that calls the setter
 # not sure if you need this
  $self->setCacheFileName();


  #my $organismAbbrev ="tgonME49"; # $args->{organismAbbrev};;$self->getOrganismAbbrev();
  my $organismAbbrev = $self->getOrganismAbbrev();
  return $self unless $organismAbbrev;

  my $buildPropertiesFile = $ENV{GUS_HOME} . "/lib/jbrowse/auto_generated/$organismAbbrev/datasetAndPresenterProps.conf"; 

  my $buildPropsHash = $self->makeProperties($buildPropertiesFile);
  #$self->setDatasetProperties($datasetProperties);  
  
  # as above, this calls a function that calls the setter
  #$self->makeBuildProperties();
  #my $buildProperties = $self->getBuildProperties();
   

    #my $orgHash = ($buildProperties->{'organism'});
    my $orgHash = ($buildPropsHash->{'organism'});
    my $nameForFileNames = ($orgHash->{organismNameForFiles});
    my $projectName = $self->getProjectName();
    my $buildNumber = $self->getBuildNumber();
    my $webservicesDir = $self->getWebservicesDir();
    my $webServicePropsHash;

	if($buildNumber && $webservicesDir && $nameForFileNames ) {
  	#todo:  construct the path
        #/var/www/Common/apiSiteFilesMirror/webServices/ToxoDB/build-68/TgondiiME49
	my $webServicePropertiesFile = "$webservicesDir/$projectName/build-$buildNumber/$nameForFileNames/config/jbrowse.conf";
	$webServicePropsHash = $self->makeProperties($webServicePropertiesFile);
	}

    #Combine the buildProps and webService hashes
    #my $datasetPropsHash = {%$buildPropsHash, %$webServicePropsHash};

    foreach my $hashkey (keys %$webServicePropsHash){
	#if (defined $buildPropsHash->{$_}){
	if (defined $buildPropsHash->{$hashkey}){
	#print "webservice property $hashkey already exists in buildPropsHash\n";
	next;
	}
	else {
		$buildPropsHash->{$hashkey} = $webServicePropsHash->{$hashkey};
	}
    }
    my $datasetPropsHash = {%$buildPropsHash};	

    $self->setDatasetProperties($datasetPropsHash);	

  return $self;
}

# this function makes the build properties has and sets it as a class attribute
sub makeBuildProperties {
    my ($self) = @_; 

    my $organismAbbrev = $self->getOrganismAbbrev();

    my $buildPropertiesFile = $ENV{GUS_HOME} . "/lib/jbrowse/auto_generated/$organismAbbrev/datasetAndPresenterProps.conf";
    
    open(FILE, $buildPropertiesFile) or die "Cannot open file $buildPropertiesFile for reading: $!";

    my $buildProperties = {};
    while(<FILE>) {
        chomp;
        next unless ($_);
        next if /^\s*#/;
        my ($propString, $value) = split(/\=/, $_);
        my @props = split(/::/, $propString);

        &toNestedHash($buildProperties, \@props, $value);
    }

    $self->setBuildProperties($buildProperties);

}


#sub makeWebserviceProperties {
#    my ($self) = @_;
#
#   my $webservicePropertiesFile = $self->getwebServicePropertiesFilePath();
# 
#   open(FILE, $webservicePropertiesFile) or die "Cannot open file $webservicePropertiesFile for reading: $!";
#
#    my $webserviceProperties = {};
#    while(<FILE>) {
#        chomp;
#        next unless ($_);
#        next if /^\s*#/;
#        my ($propString, $value) = split(/\=/, $_);
#        my @props = split(/::/, $propString);
#
#        &toNestedHash($webserviceProperties, \@props, $value);
#    }
#
#    $self->setWebserviceProperties($webserviceProperties);
#
#}


sub makeProperties {
    my ($self, $file) = @_;

   open(FILE, $file) or die "Cannot open file $file for reading: $!";

    my $properties = {};
    while(<FILE>) {
        chomp;
        next unless ($_);
        next if /^\s*#/;
        my ($propString, $value) = split(/\=/, $_);
        my @props = split(/::/, $propString);

        &toNestedHash($properties, \@props, $value);
    }

    #$self->setWebserviceProperties($properties);
    return $properties;
}





# this function makes the cacheFileName and sets it as a class attribute
sub setCacheFileName {
    my ($self) = @_;

    my $organismAbbrev = $self->getOrganismAbbrev();
    my $fileName = $self->getFileName();

    my $cacheFile = $self->getType() eq 'protein' 
        ? $ENV{GUS_HOME} . "/lib/jbrowse/auto_generated/$organismAbbrev/aa/$fileName" 
        : $ENV{GUS_HOME} . "/lib/jbrowse/auto_generated/$organismAbbrev/$fileName";

    $self->setCacheFile($cacheFile);
}

# didn't touch anything below here

sub toNestedHash {
  my ($hash, $props, $value) = @_;

  my $key = shift @$props;

  if(scalar @$props == 0) {
    $hash->{$key} = $value;
    return $hash;
  }

  my $subHash = $hash->{$key} || {};
  $hash->{$key} = $subHash;

  &toNestedHash($subHash, $props, $value);
}


sub intronJunctionsQueryParams {
  my ($self, $level) = @_;

  my $projectName = $self->{projectName};

  my $querieParams = { 'PlasmoDB' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 3000,
                                                     minIntronPercent => .01,
                                                     minNonContainedRatio => .2,
                                                     minContainedRatio => .05,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 20,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .05,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                      annotated_intron => "ALL",
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunctioninclusive",
                                                     intronSizeLimit => 5000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .05,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                      annotated_intron => "ALL",
                                                   },
                                    },
                       'HostDB' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 200000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .02,
                                                     minContainedRatio => .2,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                      annotated_intron => "ALL",
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunctioninclusive",
                                                     intronSizeLimit => 500000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 1,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                      annotated_intron => "ALL",
                                                   },
                                    },
                       'GiardiaDB' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 5000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .02,
                                                     minContainedRatio => .2,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .01,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                      annotated_intron => "ALL",
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunctioninclusive",
                                                     intronSizeLimit => 5000,
                                                     minIntronPercent => .00001,
                                                     minNonContainedRatio => .000001,
                                                     minContainedRatio => .000001,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 50,
                                                     isrpmRatio => .01,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                      annotated_intron => "ALL",
                                                   },
                                    },
                       'VectorBase' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 500000,
                                                     minIntronPercent => .05,
                                                     minNonContainedRatio => .1,
                                                     minContainedRatio => .05,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                      annotated_intron => "ALL",
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunctioninclusive",
                                                     intronSizeLimit => 600000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 1,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                      annotated_intron => "ALL",
                                                   },
                                    },
                       'default' => { 'refined' => { feature => "gsnap:unifiedintronjunction",
                                                     intronSizeLimit => 30000,
                                                     minIntronPercent => .01,
                                                     minNonContainedRatio => .1,
                                                     minContainedRatio => .05,
                                                     minContainedScore => 2,
                                                     minNonContainedScore => 10,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 3,
                                                      annotated_intron => "ALL",
                                                   },
                                      'inclusive' => {
                                                     feature => "gsnap:unifiedintronjunctioninclusive",
                                                     intronSizeLimit => 30000,
                                                     minIntronPercent => .001,
                                                     minNonContainedRatio => .0001,
                                                     minContainedRatio => .0001,
                                                     minContainedScore => 1,
                                                     minNonContainedScore => 4,
                                                     maxIsrpmMult => 5,
                                                     isrpmRatio => .5,
                                                     externalDatabaseName => "ALL",
                                                     minReadsMaxSample => 1,
                                                      annotated_intron => "ALL",
                                                   },
                                    },
  };

  if($querieParams->{$projectName}->{$level}) {
    return $querieParams->{$projectName}->{$level};
  }

  return $querieParams->{default}->{$level};
}

sub printFromCache {
  my ($self) = @_;

  my $cacheFile = $self->getCacheFile();

  if(-e $cacheFile) {
    open(FILE, $cacheFile) or die "Cannot open file $cacheFile for reading: $!";
    print <FILE>;
    close FILE;
    return 1
  }
  return 0;
}

1;
