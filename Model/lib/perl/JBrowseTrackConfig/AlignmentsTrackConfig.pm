package ApiCommonModel::Model::JBrowseTrackConfig::AlignmentsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {$_[0]->{url_template} = $_[1]}

sub getIndexUrlTemplate {$_[0]->{index_url_template} }
sub setIndexUrlTemplate {$_[0]->{index_url_template} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplate($args->{url_template});

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

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    # TODO

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
