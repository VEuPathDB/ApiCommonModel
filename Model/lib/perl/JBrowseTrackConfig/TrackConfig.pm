package ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig;

use strict;
use warnings;

use Data::Dumper;

sub getOrganismAbbrev {$_[0]->{organism_abbrev}}
sub setOrganismAbbrev {$_[0]->{organism_abbrev} = $_[1]}

sub getDisplayName {$_[0]->{display_name}}
sub setDisplayName {$_[0]->{display_name} = $_[1]}

sub getApplicationType {$_[0]->{application_type}}
sub setApplicationType {$_[0]->{application_type} = $_[1]}

sub getLabel {$_[0]->{label}}
sub setLabel {$_[0]->{label} = $_[1]}

sub getKey {$_[0]->{key}}
sub setKey {$_[0]->{key} = $_[1]}

sub getProject {$_[0]->{project}}
sub setProject {$_[0]->{project} = $_[1]}

sub getStoreClass {$_[0]->{store_class}}
sub setStoreClass {$_[0]->{store_class} = $_[1]}

sub getViewType {$_[0]->{view_type}}
sub setViewType {$_[0]->{view_type} = $_[1]}

sub getTrackType {$_[0]->{track_type}}
sub setTrackType {$_[0]->{track_type} = $_[1]}

# Some basic metadata things
sub getCategory {$_[0]->{category}}
sub setCategory {$_[0]->{category} = $_[1]}

sub getSubcategory {$_[0]->{subcategory}}
sub setSubcategory {$_[0]->{subcategory} = $_[1]}

sub getSummary {$_[0]->{summary}  || ""}
sub setSummary {$_[0]->{summary} = $_[1]}

sub getAttribution {$_[0]->{attribution}}
sub setAttribution {$_[0]->{attribution} = $_[1]}

sub getStudyDisplayName {$_[0]->{study_display_name}}
sub setStudyDisplayName {$_[0]->{study_display_name} = $_[1]}

sub getDatasetName {$_[0]->{dataset_name}}
sub setDatasetName {$_[0]->{dataset_name} = $_[1]}


# Some basic style things
sub getColor {$_[0]->{color}}
sub setColor {$_[0]->{color} = $_[1]}

sub getHeight {$_[0]->{height}}
sub setHeight {$_[0]->{height} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;

    $self->setDisplayName($args->{display_name});
    $self->setApplicationType($args->{application_type});
    $self->setLabel($args->{label});
    $self->setProject($args->{project});
    $self->setCategory($args->{category});
    $self->setSubcategory($args->{subcategory});
    $self->setSummary($args->{summary});
    $self->setAttribution($args->{attribution});
    $self->setStudyDisplayName($args->{study_display_name});
    $self->setDatasetName($args->{dataset_name});
    $self->setColor($args->{color});
    $self->setHeight($args->{height});
    $self->setOrganismAbbrev($args->{organism_abbrev});

    return $self;
}


sub getJBrowseStyle {
    my $self = shift;

    my $color = $self->getColor();
    my $height = $self->getHeight();

    return undef unless(defined($color) || defined($height));

    my $style = {};

    $style->{color} = $color if($color);
    $style->{height} = $height if($height);

    return $style;
}


sub getJBrowseMetadata {
    my $self = shift;

    my $subcategory => $self->getSubcategory();
    my $trackType = $self->getTrackType();
    my $attribution = $self->getAttribution();
    my $summary = $self->getSummary();
    my $studyDisplayName = $self->getStudyDisplayName();

    unless(defined($subcategory) || defined($trackType)
           || defined($attribution) || defined($summary) || defined($studyDisplayName)) {
        return undef;
    }

    my $metadata = {};
    $metadata->{subcategory} = $subcategory if($subcategory);
    $metadata->{trackType} = $trackType if($trackType);
    $metadata->{attribution} = $attribution if($attribution);
    $metadata->{description} = $summary if($summary);
    $metadata->{dataset} = $studyDisplayName if($studyDisplayName);

    return $metadata;
}

sub getJBrowseObject{
    my $self = shift;

    my $datasetName = $self->getDatasetName();
    my $studyDisplayName = $self->getStudyDisplayName();
    my $summary = $self->getSummary();

    my $style = $self->getJBrowseStyle();
    my $metadata = $self->getJBrowseMetadata();

    my $key = $self->getKey();
    my $storeClass = $self->getStoreClass();
    my $label = $self->getLabel();
    my $viewType = $self->getViewType();
    my $category = $self->getCategory();

    unless($key && $storeClass && $label && $viewType && $category) {
        print Dumper $self;
        die "missing a required property (key, storeClass,label, viewType, category)";
    }

    my $jbrowseObject = {storeClass => $storeClass,
                         key => $key,
                         label => $label,
                         type => $viewType,
                         category => $category,
    };

    $jbrowseObject->{style} = $style if($style);
    $jbrowseObject->{metadata} = $metadata if($metadata);

    if($datasetName && $studyDisplayName && $summary) {
        $jbrowseObject->{fmtMetaValue_Dataset} = "function() { return datasetLinkByDatasetName('${datasetName}', '${studyDisplayName}'); }";
        $jbrowseObject->{fmtMetaValue_Description} = "function() { return datasetDescription('${summary}', ''); }";
    }


    return $jbrowseObject;
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
