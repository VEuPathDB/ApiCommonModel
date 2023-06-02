package ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig;

use strict;
use warnings;

sub getDatasetName {$_[0]->{dataset_name}}
sub setDatasetName {$_[0]->{dataset_name} = $_[1]}

sub getApplicationType {$_[0]->{application_type}}
sub setApplicationType {$_[0]->{application_type} = $_[1]}

sub getStudyDisplayName {$_[0]->{study_display_name}}
sub setStudyDisplayName {$_[0]->{study_display_name} = $_[1]}

sub getFileName {$_[0]->{file_name}}
sub setFileName {$_[0]->{file_name} = $_[1]}

sub getDisplayName {$_[0]->{display_name}}
sub setDisplayName {$_[0]->{display_name} = $_[1]}

sub getColor {$_[0]->{color}}
sub setColor {$_[0]->{color} = $_[1]}

sub getLabel {$_[0]->{label}}
sub setLabel {$_[0]->{label} = $_[1]}

sub getCategory {$_[0]->{category}}
sub setCategory {$_[0]->{category} = $_[1]}

sub getStrand {$_[0]->{strand}}
sub setStrand {$_[0]->{strand} = $_[1]}

sub getSummary {$_[0]->{summary}}
sub setSummary {$_[0]->{summary} = $_[1] || ""}

sub getProject {$_[0]->{project}}
sub setProject {$_[0]->{project} = $_[1]}

sub getAttribution {$_[0]->{attribution}}
sub setAttribution {$_[0]->{attribution} = $_[1]}

sub getUniqueOnly {$_[0]->{is_unique_only}}
sub setUniqueOnly {$_[0]->{is_unique_only} = $_[1]}

sub getSubcategory {$_[0]->{subcategory}}
sub setSubcategory {$_[0]->{subcategory} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;

    $self->setDatasetName($args->{dataset_name});
    $self->setApplicationType($args->{application_type});
    $self->setStudyDisplayName($args->{study_display_name});
    $self->setFileName($args->{file_name});
    $self->setDisplayName($args->{display_name});
    $self->setColor($args->{color});
    $self->setLabel($args->{label});
    $self->setCategory($args->{category});
    $self->setStrand($args->{strand});
    $self->setSummary($args->{summary});
    $self->setProject($args->{project});
    $self->setAttribution($args->{attribution});
    $self->setUniqueOnly($args->{is_unique_only});
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
