package ApiCommonModel::Model::JBrowseTrackConfig::RNASeqCoverageTrackConfig;

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";


sub getApplicationType {$_[0]->{_application_type}}
sub setApplicationType {$_[0]->{_application_type} = $_[1]}

sub new {
  my ($class, $args) = @_;

  my $self = bless($args, $class);

  $self->setApplicationType($args->{applicationType});
  # can we get access to these env vars??
  # LEGACY_WEBAPP_BASE_URL=/toxo.jbrestel                                                                                                                                                                      # LOCALHOST=https://jbrestel.toxodb.org 


  return $self;
}

# all Track Config 
sub getConfigurationObject {
  my $self = shift;

  if($self->applicationType eq 'jbrowse') {
    return $self->getJBrowseObject();
  }
  elsif($self->applicationType eq 'jbrowse2') {
    return $self->getJBrowse2Object();
  }

  elsif($self->applicationType eq 'apollo') {
    return $self->getApolloObject();
  }

  elsif($self->applicationType eq 'apollo3') {
    return $self->getApolloObject();
  }

  else {
    die "ApplicationType not recognized " . $self->applicationType;
  }
}


1;
