package ApiCommonModel::Model::JBrowseTrackConfig::RNASeqCoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);

use strict;
use warnings;
use Data::Dumper;

sub getUrlTemplate {
    my $self = shift;
    return $self->getUrlTemplates()->[0];
}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplates([$args->{url_template}]);

    my $studyDisplayName = $self->getStudyDisplayName();
    my $displayName = $self->getDisplayName();
    $self->setKey("$studyDisplayName - $displayName Coverage");

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

    my $studyDisplayName = $self->getStudyDisplayName();

    my $jbrowse2Object = {type => "QuantitativeTrack",
                          trackId => $self->getLabel(),
                          name => $self->getKey(),
                          category => ["RNASeq", $studyDisplayName],
                          adapter => {type => "BigWigAdapter",
                                      bigWigLocation => {uri => $self->getUrlTemplate(),
                                                         locationType => "UriLocation"
                                      }
                          },
                          assemblyNames =>  [
                              $self->getOrganismAbbrev()
                              ],
                          displays => [
                              {type => "LinearWiggleDisplay",
                               displayId => "rnaseq_wiggle_" . scalar($self),
                               minScore => 1,
                               maxScore => 1000,
                               scaleType => "log",
                               defaultRendering => "xyplot",
                               renderers => {XYPlotRenderer => {type => "XYPlotRenderer",
                                                                color => $self->getColor()
                                             },
                                             DensityRenderer => {type => "DensityRenderer",
                                                                 color => $self->getColor()
                                             },
                               }
                              }
                              ]
    };

    return $jbrowse2Object;
}


1;
