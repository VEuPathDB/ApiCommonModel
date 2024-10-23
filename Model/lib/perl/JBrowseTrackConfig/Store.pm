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


sub setUriTemplateForStore {
  my ($self) = @_;

  my $projectName = $self->getProjectName();
  my $buildNumber = $self->getBuildNumber();
  my $relativePathToFile = $self->getRelativePathToFile();
  
  my $applicationType = $self->getApplicationType();

  my $urlTemplate;

  if($applicationType eq 'jbrowse') {
    $urlTemplate = $JBROWSE_STORE_ENDPOINT . uri_escape_utf8($relativePathToFile);
  }
  elsif($applicationType eq 'apollo') {
    # TODO:  replace "/a" with https://lc(${projectName}).org 
    die "TODO:  make apollo work";
  }
  elsif($applicationType eq 'jbrowse2' || $applicationType eq 'apollo3') {
    $urlTemplate = "${projectName}/build-${buildNumber}/$relativePathToFile";
  }
  else {
    die "Unsupported application type for Store: $applicationType";
  }

  $self->setUrlTemplate($urlTemplate);
}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
#    my $self = bless {}, $class;
    $self->setStoreType($args->{store_type});

    return $self;
}

1;
