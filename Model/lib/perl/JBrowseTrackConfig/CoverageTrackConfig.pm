package ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig;

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";


# getters and setters
sub getDatasetName {$_[0]->{_dataset_name}}
sub setDatasetName {$_[0]->{_dataset_name} = $_[1]}


 ....

sub new {
  my ($class, $args) = @_;

  my $self = bless($args, $class);

  $self->setDatasetName($args->{datasetName});

  return $self;
}


sub getJBrowseObject { }
sub getApolloObject { 
  $self = shift;

  # main difference is the url for the endpoint:  relative path vs full website specification
  # JBrowse: $storeEndpoint=/a/jbrowse/service/.....
  # Apollo: $storeEndpoint=plasmodb.org/a/jbrowse/service/.....
  my $obj = $self->getJBrowseObject ();
  $obj->setBlah("some different value");

}


sub getJBrowse2Object { 
  return undef;
}



1;
