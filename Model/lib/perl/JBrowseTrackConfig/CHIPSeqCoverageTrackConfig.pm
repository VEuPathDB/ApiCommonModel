package ApiCommonModel::Model::JBrowseTrackConfig::CHIPSeqCoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;


sub getConfigurationObject {
  my $self = shift;

  if($self->{application_type} eq 'jbrowse') {
    return $self->getJBrowseObject();
  }
  elsif($self->{application_type} eq 'jbrowse2') {
    return $self->getJBrowse2Object();
  }

  elsif($self->{application_type} eq 'apollo') {
    return $self->getApolloObject();
  }

  elsif($self->{application_type} eq 'apollo3') {
    return $self->getApolloObject();
  }

  else {
    die "Application Type not recognized " . $self->{application_type};
  }
}


sub getJBrowseObject{

return $jbrowseObject;
}

sub getJBrowse2Object{

return $jbrowse2Object;
}

sub getApolloObject {

return $apolloObject;
}

1;
