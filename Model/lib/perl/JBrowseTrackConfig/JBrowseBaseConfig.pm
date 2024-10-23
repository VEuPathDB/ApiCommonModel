package ApiCommonModel::Model::JBrowseTrackConfig::JBrowseBaseConfig;

use ApiCommonModel::Model::JBrowseTrackConfig::DatasetConfig;

use strict;
use warnings;


sub getApplicationType {$_[0]->{application_type}}
sub setApplicationType {$_[0]->{application_type} = $_[1]}

sub getDatasetConfigObj {$_[0]->{dataset_config}}
sub setDatasetConfigObj {$_[0]->{dataset_config} = $_[1]}

sub getProjectName {$_[0]->{project_name}}
sub setProjectName {$_[0]->{project_name} = $_[1]}

sub getBuildNumber {$_[0]->{build_number}}
sub setBuildNumber {$_[0]->{build_number} = $_[1]}

sub new { die ""}

1;
