package ApiCommonModel::Model::JBrowseTrackConfig

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";


# getters and setters
sub getDatasetName {$_[0]->{_dataset_name}}
sub getDisplayName {$_[0]->{_display_name}}
sub getStudyDisplayName {$_[0]->{_study_display_name}}
sub getApplicationType {$_[0]->{_application_type}}

sub setDatasetName {$_[0]->{_dataset_name} = $_[1]}
sub setDatasetDisplayName {$_[0]->{_display_name} = $_[1]}
sub setStudyDisplayName {$_[0]->{_study_display_name} = $_[1]}
sub setApplicationType {$_[0]->{_application_type} = $_[1]}

sub new {
  my ($class, $args, $datasetName, $displayName, $studyDisplayName, $applicationType) = @_;

  my $self = $class->SUPER::new($args);

  $self->setDatasetName($datasetName);
  $self->setDatasetDisplayName($displayName);
  $self->setStudyDisplayName($studyDisplayName);
  $self->setApplicationType($applicationType);

  return $self;
}

sub getConfigurationObject {
  my $self = shift;

  if($self->getApplicationType eq 'jbrowse') {
    return $self->getJBrowseObject();
  }
  elsif($self->getApplicationType eq 'jbrowse2') {
    return $self->getJBrowse2Object();
  }

  elsif($self->getApplicationType eq 'apollo') {
    return $self->getApolloObject();
  }

  elsif($self->getApplicationType eq 'apollo3') {
    return $self->getApollo3Object();
  }

  else {
    die "ApplicationType not recognized " . $self->applicationType;
  }
}
