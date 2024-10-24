package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigStore;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Store);

use strict;

sub getUrlTemplates {$_[0]->{url_templates} }
sub setUrlTemplates {$_[0]->{url_templates} = $_[1]}

sub setUrlTemplatesFromMultiUrls {
  my ($self, $multiUrls) = @_;

  my @res;

  my $projectName = $self->getProjectName();
  my $buildNumber = $self->getBuildNumber();

  my $applicationType = $self->getApplicationType();

  # {relative_path_to_file => $relativePathToFile, name => $displayName, color => $color, alignment => $alignment};
  foreach(@$multiUrls) {

    my $relativePathToFile = $_->{relative_path_to_file};
    my $name = $_->{name};
    my $color = $_->{color};
    my $alignment = $_->{alignment};
    my $displayName = $_->{display_name};
  
    return unless($projectName && $buildNumber);

    my $urlTemplate = $self->makeUrlTemplate($applicationType, $relativePathToFile, $projectName, $buildNumber);

    push @res, {url => $urlTemplate, name => $displayName, color => $color, alignment => $alignment};
  }


  $self->setUrlTemplates(\@res);

  return \@res;
}


1;


