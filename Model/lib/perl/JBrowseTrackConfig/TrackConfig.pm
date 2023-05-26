package ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig;

use strict;
use warnings;

# getters and setters
# To Do Add projectName
sub getDatasetName {$_[0]->{dataset_name}}
sub getApplicationType {$_[0]->{application_type}}
sub getStudyDisplayName {$_[0]->{study_display_name}}
sub getFileName {$_[0]->{file_name}}
sub getDisplayName {$_[0]->{display_name}}
sub getColor {$_[0]->{color}}
sub getLabel {$_[0]->{label}}
sub getCategory {$_[0]->{category}}
sub getStrand {$_[0]->{strand}}
sub getSummary {$_[0]->{summary}}

sub setDatasetName {$_[0]->{dataset_name} = $_[1]}
sub setApplicationType {$_[0]->{application_type} = $_[1]}
sub setStudyDisplayName {$_[0]->{study_display_name} = $_[1]}
sub setFileName {$_[0]->{file_name} = $_[1]}
sub setDisplayName {$_[0]->{display_name} = $_[1]}
sub setColor {$_[0]->{color} = $_[1]}
sub setLabel {$_[0]->{label}}
sub setCategory {$_[0]->{category} = $_[1]}
sub setStrand {$_[0]->{strand} = $_[1]}
sub setSummary {$_[0]->{summary} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    $self->{dataset_name} = $args->{dataset_name};
    $self->{application_type} = $args->{application_type};
    $self->{study_display_name} = $args->{study_display_name};
    $self->{file_name} = $args->{file_name};
    $self->{display_name} = $args->{display_name};
    $self->{color} = $args->{color};
    $self->{label} = $args->{label};
    $self->{category}= $args->{category};
    $self->{strand}= $args->{strand};
    $self->{summary}= $args->{summary};
    return $self;
}


sub getJBrowseObject {
    my $self = shift;
    die "Abstract method 'jbrowse' must be implemented by subclass";
}

sub getJBrowse2Object {
    my $self = shift;
    die "Abstract method 'jbrowse2' must be implemented by subclass";
}

sub getApolloObject {
    my $self = shift;
    die "Abstract method 'apollo' must be implemented by subclass";
}

sub getConfigurationObject {
        my $self = shift;
        my $applicationType = $self->getApplicationType();
#die $applicationType;
$applicationType = 'jbrowse';
        if($applicationType eq 'jbrowse') {
                return $self->getJBrowseObject();
        }
        elsif($applicationType eq 'jbrowse2') {
                return $self->getJBrowse2Object();
        }

        elsif($applicationType eq 'apollo') {
                return $self->getApolloObject();
        }

        elsif($applicationType eq 'apollo3') {
                return $self->getApolloObject();
        }

        else {
                die "Application Type not recognized " . $applicationType;
        }
}

1;
