package ApiCommonModel::Model::JBrowseTrackConfig::AlignmentsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::BamStore;

sub getMin {$_[0]->{min}}
sub setMin {$_[0]->{min} = $_[1]}

sub getMax {$_[0]->{max}}
sub setMax {$_[0]->{max} = $_[1]}

sub getYScalePosition {$_[0]->{yscale_position}}
sub setYScalePosition {$_[0]->{yscale_position} = $_[1]}

sub getChunkSizeLimit {$_[0]->{chunk_size}}
sub setChunkSizeLimit {$_[0]->{chunk_size} = $_[1]}

sub skipHistograms {$_[0]->{_skip_histograms}}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $store = ApiCommonModel::Model::JBrowseTrackConfig::BamStore->new($args);
    $self->setStore($store);

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setDisplayType("JBrowse/View/Track/Alignments2");
        $self->setTrackTypeDisplay("Coverage (Read Alignments zoomed)");
    }
    else {
        $self->setTrackType("AlignmentsTrack");
        $self->setDisplayType("LinearAlignmentsDisplay");
        $self->setTrackTypeDisplay("Alignment");
    }

    my $displayName = $self->getDisplayName();
    my $datasetName = $self->getDatasetName();

    $self->setId("${datasetName}_${displayName}_Alignments");
    $self->setColor("black");
    $self->setMin(0);
    $self->setMin(500);
    $self->setYScalePosition("left");
    $self->setChunkSizeLimit(50000000);

    if($args->{skip_histograms}) {
      $self->{_skip_histograms} = 1;
    }

    return $self;
}


sub getHistograms {
    my $self = shift;

    my $store = $self->getStore();

    my $bigwigUrl = $store->getBigwigUrl();

    my $histograms = {};
    $histograms->{color} = $self->getColor();
    $histograms->{storeClass} = $store->getBigWigStoreType();
    $histograms->{min} = $self->getMin();
    $histograms->{urlTemplate} = $bigwigUrl ;
    $histograms->{max} = $self->getMax();;
    return $histograms;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();


    $jbrowseObject->{yScalePosition} = $self->getYScalePosition();
    $jbrowseObject->{chunkSizeLimit} = $self->getChunkSizeLimit();;

    $jbrowseObject->{urlTemplate}= $self->getUrlTemplate();

    unless($self->skipHistograms()) {
      my $histograms = $self->getHistograms();
      $jbrowseObject->{histograms} = $histograms;
    }

    return $jbrowseObject;
}

sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();

    my $indexLocation = $self->getIndexUrlTemplate();

    $jbrowse2Object->{adapter}->{index}->{location}->{uri} = $indexLocation;
    $jbrowse2Object->{adapter}->{bamLocation} = {uri => $self->getUrlTemplate(),locationType => "UriLocation"};

    $jbrowse2Object->{displays}->[0]->{displayId} = "bam_" . scalar($self);

    return $jbrowse2Object;
}



1;
