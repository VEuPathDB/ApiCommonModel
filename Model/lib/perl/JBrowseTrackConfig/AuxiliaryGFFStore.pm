package ApiCommonModel::Model::JBrowseTrackConfig::AuxiliaryGFFStore;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::GFFStore);
use strict;
use warnings;

use URI::Escape;

my $JBROWSE_AUXILIARY_ENDPOINT = "/a/service/jbrowse/auxiliary?data=";

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    return $self;
}

sub makeUrlTemplate {
    my ($self, $applicationType, $relativePathToFile, $projectName, $buildNumber) = @_;

    if($applicationType eq 'jbrowse' || $applicationType eq 'apollo') {
        return $JBROWSE_AUXILIARY_ENDPOINT . uri_escape_utf8($relativePathToFile);
    }
    elsif($applicationType eq 'jbrowse2' || $applicationType eq 'apollo3') {
        return "auxiliary/$relativePathToFile";
    }
    else {
        die "Unsupported application type for AuxiliaryGFFStore: $applicationType";
    }
}

1;
