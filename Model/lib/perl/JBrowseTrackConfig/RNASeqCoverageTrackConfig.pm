package ApiCommonModel::Model::JBrowseTrackConfig::RNASeqCoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);

use strict;
use warnings;
use Data::Dumper;



sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplate($args->{url_template});

    my $studyDisplayName = $self->getStudyDisplayName();
    my $displayName = $self->getDisplayName();

    my $label = $self->getLabel();
    my $datasetName = $self->getDatasetName();

    $self->setId("${datasetName}_${displayName}_Coverage");
    $self->setLabel("$studyDisplayName - $displayName Coverage");

    $self->setHeight(40);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $style = {pos_color => $self->getColor(),
                 clip_marker_color => "black",
                 height => $self->getHeight(),
    };
    return $style;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    $jbrowseObject->{url_template} = $self->getUrlTemplate();

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
