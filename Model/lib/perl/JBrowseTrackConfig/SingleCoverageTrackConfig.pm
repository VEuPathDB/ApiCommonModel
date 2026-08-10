package ApiCommonModel::Model::JBrowseTrackConfig::SingleCoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);

use strict;
use warnings;
use Data::Dumper;

use JSON;
use ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore;

sub getDbid {$_[0]->{dbid} }
sub setDbid {$_[0]->{dbid} = $_[1]}

sub getOrder {$_[0]->{order} }
sub setOrder {$_[0]->{order} = $_[1]}

sub getDisplayNameSuffix {$_[0]->{display_name_suffix} }
sub setDisplayNameSuffix {$_[0]->{display_name_suffix} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setOrder($args->{order});
    $self->setDbid($args->{dbid});
    $self->setDisplayNameSuffix($args->{display_name_suffix});
 
    my $store = ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore->new($args);
    $self->setStore($store);

    my $datasetConfig = $self->getDatasetConfigObj();
    my $studyDisplayName = $datasetConfig->getStudyDisplayName();
    my $displayName = $self->getDisplayName();
    my $displayNameSuffix = $self->getDisplayNameSuffix();
    #my $order = $self->getTrackOrderNum();
    my $order = $self->getOrder();
    my $dbid = $self->getDbid();
    my $datasetName = $datasetConfig->getDatasetName();


    if ($order){
    $self->setId("$studyDisplayName - $order - $displayName $displayNameSuffix");
    }
    else {
    $self->setId("$studyDisplayName - $displayName $displayNameSuffix");
    }

    # An explicit label wins. label is the JBrowse track id, so it must be unique across
    # the whole response; callers that emit several tracks per sample (dnaseq emits up to
    # five measures each) need that uniqueness by construction rather than by luck of the
    # sample names happening to be distinct. Both derived forms below remain the default,
    # so existing callers are unaffected.
    if (defined($args->{label}) && length($args->{label})) {
    $self->setLabel($args->{label});
    }
    elsif ($dbid){
    $self->setLabel("$datasetName $dbid Coverage");
    }
    else {
    $self->setLabel("$displayName $displayNameSuffix");
    }
    
    # An explicit track type display wins; this string is shown to users in the track
    # selector. The ploidy-normalised default below is only correct for the CNV coverage
    # track, which was the sole order-less and dbid-less caller when it was written; a
    # caller emitting other per-sample measures (SNP density, LOH, ...) must be able to
    # say what its track actually is instead of inheriting that label.
    if (defined($args->{track_type_display}) && length($args->{track_type_display})) {
    $self->setTrackTypeDisplay($args->{track_type_display});
    }
    elsif (!defined($order) && !defined($dbid)) {
    $self->setTrackTypeDisplay("Coverage (ploidy Normalized)");;
    }

    $self->setClipMarkerColor($args->{clip_marker_color});
    $self->setCovMaxScoreDefault($args->{cov_max_score_default});
    $self->setCovMinScoreDefault($args->{cov_min_score_default});
    $self->setScale($args->{scale});

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $style = {pos_color => $self->getColor(),
                 clip_marker_color => $self->getClipMarkerColor(),
                 height => $self->getHeight(),
    };
    return $style;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    $jbrowseObject->{urlTemplate} = $self->getStore()->getUrlTemplate();
    $jbrowseObject->{max_score} = $self->getCovMaxScoreDefault();
    $jbrowseObject->{min_score} = $self->getCovMinScoreDefault();
    $jbrowseObject->{scale} = $self->getScale();

    return $jbrowseObject;
}


sub getJBrowse2Object{
    my ($self, $doNotSkip) = @_;

    # JBrowse2 has nice multicoverage things for RNASeq and ChipSeq
    return undef unless($doNotSkip);

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();

    my $datasetConfig = $self->getDatasetConfigObj();
    my $studyDisplayName = $datasetConfig->getStudyDisplayName();

    $jbrowse2Object->{adapter}->{bigWigLocation} = {uri => $self->getStore()->getUrlTemplate(),locationType => "UriLocation"};
    #$jbrowse2Object->{adapter}->{bigWigLocation} = {uri => $uri,locationType => "UriLocation"};
    $jbrowse2Object->{displays}->[0]->{displayId} = "wiggle_" . scalar($self);
    $jbrowse2Object->{displays}->[0]->{defaultRendering} = "xyplot";
    $jbrowse2Object->{displays}->[0]->{renderers} = {XYPlotRenderer => {type => "XYPlotRenderer",
                                                                        color => $self->getColor()
                                                     },
                                                     DensityRenderer => {type => "DensityRenderer",
                                                                         color => $self->getColor()
                                                     },
    };

    return $jbrowse2Object;
}





package ApiCommonModel::Model::JBrowseTrackConfig::SingleCoverageTrackConfig::CNV;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::SingleCoverageTrackConfig);

use strict;

sub getJBrowse2Object{
    my $self = shift;
    my $jbrowse2Object = $self->SUPER::getJBrowse2Object(1);
}


1;
