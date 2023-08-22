package ApiCommonModel::Model::JBrowseTrackConfig::AlignmentsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {
    my($self, $urlTemplate) = @_;
    die "required urlTemplate not set" unless $urlTemplate;
    $self->{url_template} = $urlTemplate;
}

sub getIndexUrlTemplate {$_[0]->{index_url_template} }
sub setIndexUrlTemplate {
    my($self, $urlTemplate) = @_;
    die "required urlTemplate not set" unless $urlTemplate;
    $self->{index_url_template} = $urlTemplate;
}

sub getColor {$_[0]->{color}}
sub setColor {$_[0]->{color} = $_[1]}

sub getStoreClass {$_[0]->{storeClass}}
sub setStoreClass {$_[0]->{storeClass} = $_[1]}

sub getMin {$_[0]->{min}}
sub setMin {$_[0]->{min} = $_[1]}

sub getMax {$_[0]->{max}}
sub setMax {$_[0]->{max} = $_[1]}

sub getBigwigUrl {$_[0]->{bw_url_template}}
sub setBigwigUrl {
    my($self, $bigwigUrl) = @_;
    die "required bigwigUrl not set" unless $bigwigUrl;
    $self->{bw_url_template} = $bigwigUrl;
}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplate($args->{url_template});
    $self->setStoreClass($args->{storeClass});
    $self->setMin($args->{min});
    $self->setMax($args->{max});
    $self->setBigwigUrl($args->{bw_url_template});

    my $indexLocation = $args->{url_template} . ".bai";
    $self->setIndexUrlTemplate($indexLocation);

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setStoreType("JBrowse/Store/SeqFeature/BAM");
        $self->setDisplayType("JBrowse/View/Track/Alignments2");
        $self->setTrackTypeDisplay("Alignments");
    }
    else {
        $self->setStoreType("BamAdapter");
        $self->setTrackType("AlignmentsTrack");
        $self->setDisplayType("LinearAlignmentsDisplay");
        $self->setTrackTypeDisplay("Alignment");
    }

    my $displayName = $self->getDisplayName();
    my $datasetName = $self->getDatasetName();

    $self->setId("${datasetName}_${displayName}_Alignments");

    return $self;
}


sub getHistograms {
    my $self = shift;

    my $bigwigUrl = $self->getBigwigUrl();

    my $histograms = {};
    $histograms->{color} = "black";
    $histograms->{storeClass} = "JBrowse/Store/SeqFeature/BigWig";
    $histograms->{min} = 0;
    $histograms->{urlTemplate} = $bigwigUrl ;
    $histograms->{max} = 500;
    return $histograms;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    $jbrowseObject->{yScalePosition}="left";
    $jbrowseObject->{chunkSizeLimit}=50000000;
    $jbrowseObject->{urlTemplate}= $self->getUrlTemplate();

    my $histograms = $self->getHistograms();
    $jbrowseObject->{histograms} = $histograms;

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
