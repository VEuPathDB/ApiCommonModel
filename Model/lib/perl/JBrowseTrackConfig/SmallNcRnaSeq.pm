package ApiCommonModel::Model::JBrowseTrackConfig::SmallNcRnaSeq;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::BamStore;

sub getYScalePosition {$_[0]->{yscale_position}}
sub setYScalePosition {$_[0]->{yscale_position} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub getLabel {$_[0]->{label} }
sub setLabel {$_[0]->{label} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setId($args->{key});

    my $store = ApiCommonModel::Model::JBrowseTrackConfig::BamStore->new($args);

    $self->setStore($store);

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setDisplayType("SmallRNAPlugin/View/Track/smAlignments");
        $self->setTrackTypeDisplay("Small RNA");
    }
    else {
        $self->setTrackType("AlignmentsTrack");
        $self->setDisplayType("LinearAlignmentsDisplay");
        $self->setTrackTypeDisplay("Alignment");
    }

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Transcriptomics");
    $datasetConfig->setSubcategory("small non-coding RNA");

    $self->setYScalePosition("left");
    return $self;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    # TODO - replace with:
    #$jbrowseObject->{unsafePopup} = "JSON::true";
    $jbrowseObject->{unsafePopup} = 'true';

    $jbrowseObject->{yScalePosition} = $self->getYScalePosition();

    # TODO
    $jbrowseObject->{urlTemplate}= $self->getStore()->getUrlTemplate();

    return $jbrowseObject;
}

sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();

    my $indexLocation = $self->getIndexUrlTemplate();

    $jbrowse2Object->{adapter}->{index}->{location}->{uri} = $indexLocation;
    $jbrowse2Object->{adapter}->{bamLocation} = {uri => $self->getStore()->getUrlTemplate(),locationType => "UriLocation"};

    $jbrowse2Object->{displays}->[0]->{displayId} = "bam_" . scalar($self);

    return $jbrowse2Object;
}



1;
