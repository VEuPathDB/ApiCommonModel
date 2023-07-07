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

sub getId {$_[0]->{id}}
sub setId {$_[0]->{id} = $_[1]}

sub getProject {$_[0]->{project}}
sub setProject {$_[0]->{project} = $_[1]}

sub getStoreType {$_[0]->{store_type}}
sub setStoreType {$_[0]->{store_type} = $_[1]}

sub getDisplayType {$_[0]->{display_type}}
sub setDisplayType {$_[0]->{display_type} = $_[1]}

sub getTrackType {$_[0]->{track_type}}
sub setTrackType {$_[0]->{track_type} = $_[1]}

sub getTrackTypeDisplay {$_[0]->{track_type_display} || $_[0]->getTrackType()}
sub setTrackTypeDisplay {$_[0]->{track_type_display} = $_[1]}

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

    unless($self->getSubcategory()) {
        print Dumper $args;
        die "";
    }
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


sub getMetadata {
    my $self = shift;

    my $subcategory = $self->getSubcategory();
    my $trackType = $self->getTrackTypeDisplay();
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
    $metadata->{dataset} = $studyDisplayName if($studyDisplayName);

    return $metadata;
}

sub getJBrowseObject{
    my $self = shift;

    my $datasetName = $self->getDatasetName();
    my $studyDisplayName = $self->getStudyDisplayName();
    my $summary = $self->getSummary();

    my $style = $self->getJBrowseStyle();
    my $metadata = $self->getMetadata();

    my $id = $self->getId();
    my $storeType = $self->getStoreType();
    my $label = $self->getLabel();
    my $displayType = $self->getDisplayType();
    my $category = $self->getCategory();

    unless($id && $storeType && $label && $displayType && $category) {
        print Dumper $self;
        die "missing a required property (id, storeClass,label, displayType, category)";
    }

    my $jbrowseObject = {storeClass => $storeType,
                         id => $id,
                         label => $label,
                         type => $displayType,
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


sub getJBrowse2Metadata {

}

sub getJBrowse2Object {
    my $self = shift;

    my $datasetName = $self->getDatasetName();
    my $studyDisplayName = $self->getStudyDisplayName();
    my $summary = $self->getSummary();

    my $metadata = $self->getMetadata();

    my $id = $self->getId();
    my $label = $self->getLabel();

    my $storeType = $self->getStoreType();
    my $displayType = $self->getDisplayType();
    my $trackType = $self->getTrackType();

    my $category = $self->getCategory();
    my $subcategory = $self->getSubcategory();

    my @categoryHierarchy = ($category);
    if($subcategory) {
        push @categoryHierarchy, $subcategory;
        if($studyDisplayName) {
            push @categoryHierarchy, $studyDisplayName;
        }
    }


    unless($id && $storeType && $label && $displayType && $trackType && $category) {
        print Dumper $self;
        die "missing a required property (id, storeType,label, displayType, trackType category)";
    }

    my $jbrowseObject = {type => $trackType,
                         trackId => $id,
                         name => $label,
                         category => \@categoryHierarchy,
                         adapter => { type => $storeType },
                         assemblyNames =>  [ $self->getOrganismAbbrev() ],
                         displays => [{ type => $displayType }]
    };


    $jbrowseObject->{metadata} = $metadata if($metadata);

    return $jbrowseObject;



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
