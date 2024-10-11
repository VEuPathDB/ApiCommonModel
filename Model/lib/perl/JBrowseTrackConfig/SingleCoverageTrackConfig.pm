package ApiCommonModel::Model::JBrowseTrackConfig::SingleCoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);

use strict;
use warnings;
use Data::Dumper;

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {$_[0]->{url_template} = $_[1]}

sub getDbid {$_[0]->{dbid} }
sub setDbid {$_[0]->{dbid} = $_[1]}

sub getOrder {$_[0]->{order} }
sub setOrder {$_[0]->{order} = $_[1]}

sub getDisplayNameSuffix {$_[0]->{display_name_suffix} }
sub setDisplayNameSuffix {$_[0]->{display_name_suffix} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplate($args->{url_template});
    $self->setOrder($args->{order});
    $self->setDbid($args->{dbid});
    $self->setDisplayNameSuffix($args->{display_name_suffix});

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

    if ($dbid){
    $self->setLabel("$datasetName $dbid Coverage");        
    }
    else {
    $self->setLabel("$displayName $displayNameSuffix");
    }
    
    if (!defined($order) && !defined($dbid)) {
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

    $jbrowseObject->{urlTemplate} = $self->getUrlTemplate();
    $jbrowseObject->{max_score} = $self->getCovMaxScoreDefault();
    $jbrowseObject->{min_score} = $self->getCovMinScoreDefault();
    $jbrowseObject->{scale} = $self->getScale();

    return $jbrowseObject;
}

sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();

    my $studyDisplayName = $self->getStudyDisplayName();

    $jbrowse2Object->{adapter}->{bigWigLocation} = {uri => $self->getUrlTemplate(),locationType => "UriLocation"};
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


1;
