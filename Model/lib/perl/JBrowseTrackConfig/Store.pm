package ApiCommonModel::Model::JBrowseTrackConfig::Store;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::JBrowseBaseConfig);

use strict;
use warnings;

use URI::Escape;

sub getStoreType {$_[0]->{store_type}}
sub setStoreType {$_[0]->{store_type} = $_[1]}

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {$_[0]->{url_template} = $_[1]}

sub getRelativePathToFile {$_[0]->{relative_path_to_file}}
sub setRelativePathToFile {$_[0]->{relative_path_to_file} = $_[1]}


my $JBROWSE_STORE_ENDPOINT = "/a/service/jbrowse/store?data=";

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setStoreType($args->{store_type});

    if(my $relativePathToFile = $args->{relative_path_to_file}) {
      $self->setRelativePathToFile($relativePathToFile);
    }

    $self->setUrlTemplateForStore();

    return $self;
}

sub setUrlTemplateForStore {
  my ($self) = @_;

  my $projectName = $self->getProjectName();
  my $buildNumber = $self->getBuildNumber();
  my $relativePathToFile = $self->getRelativePathToFile();
  
  return unless($projectName && $buildNumber && $relativePathToFile);

  my $applicationType = $self->getApplicationType();

  my $urlTemplate = $self->makeUrlTemplate($applicationType, $relativePathToFile, $projectName, $buildNumber);

  $self->setUrlTemplate($urlTemplate);
}

sub makeUrlTemplate {
  my ($self, $applicationType, $relativePathToFile, $projectName, $buildNumber) = @_;

  my $urlTemplate;

  if($applicationType eq 'jbrowse') {
    $urlTemplate = $JBROWSE_STORE_ENDPOINT . uri_escape_utf8($relativePathToFile);
  }
  elsif($applicationType eq 'apollo') {
    # TODO:  replace "/a" with https://lc(${projectName}).org 
    die "TODO:  make apollo work";
  }
  elsif($applicationType eq 'jbrowse2' || $applicationType eq 'apollo3') {
    # The store service prepends <project>/build-<n>/ itself, so the path stays relative to it.
    $urlTemplate = $JBROWSE_STORE_ENDPOINT . uri_escape_utf8($relativePathToFile, '^A-Za-z0-9\-._~/');
  }
  else {
    die "Unsupported application type for Store: $applicationType";
  }
  return $urlTemplate;
}

my %JBROWSE2_LOCATION_KEYS = (
  BigWigAdapter       => {data => 'bigWigLocation'},
  Gff3TabixAdapter    => {data => 'gffGzLocation', index => '.tbi'},
  BEDTabixAdapter     => {data => 'bedGzLocation', index => '.tbi'},
  VcfTabixAdapter     => {data => 'vcfGzLocation', index => '.tbi'},
  BamAdapter          => {data => 'bamLocation',   index => '.bai'},
  IndexedFastaAdapter => {data => 'fastaLocation', fai => '.fai'},
);

# Adapter location slots for a single-file store; empty when the store has no file
# (multi-file adapters such as MultiWiggleAdapter build their own subadapters).
sub getJBrowse2Locations {
  my ($self) = @_;

  my $url = $self->getUrlTemplate();
  my $keys = $JBROWSE2_LOCATION_KEYS{$self->getStoreType() || ''};
  return {} unless($url && $keys);

  my $locations = {$keys->{data} => _uriLocation($url)};
  $locations->{index} = {location => _uriLocation($url . $keys->{index})} if($keys->{index});
  $locations->{faiLocation} = _uriLocation($url . $keys->{fai}) if($keys->{fai});
  return $locations;
}

sub _uriLocation { return {uri => $_[0], locationType => 'UriLocation'} }


1;
