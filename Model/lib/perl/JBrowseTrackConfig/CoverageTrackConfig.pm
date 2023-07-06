package ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getUrlTemplates {$_[0]->{url_templates} || [] }
sub setUrlTemplates {$_[0]->{url_templates} = $_[1]}

sub getCovMaxScoreDefault {$_[0]->{cov_max_score_default} || 1000}
sub setCovMaxScoreDefault {$_[0]->{cov_max_score_default} = $_[1]}

sub getCovMinScoreDefault {$_[0]->{cov_min_score_default} || 0 }
sub setCovMinScoreDefault {$_[0]->{cov_min_score_default} = $_[1]}

sub getScale {$_[0]->{scale} || "log"}
sub setScale {$_[0]->{scale} = $_[1]}

sub getYScalePosition {$_[0]->{yscale_position} || "left"}
sub setYScalePosition {$_[0]->{yscale_position} = $_[1]}

# These are optional  metadata
sub getStrand {$_[0]->{strand}}
sub setStrand {$_[0]->{strand} = $_[1]}

sub getAlignment {$_[0]->{alignment}}
sub setAlignment {$_[0]->{alignment} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplates($args->{url_templates});

    $self->setCovMaxScoreDefault($args->{cov_max_score_default});
    $self->setCovMinScoreDefault($args->{cov_min_score_default});
    $self->setScale($args->{scale});

    $self->setStoreClass("JBrowse/Store/SeqFeature/BigWig");

    $self->setViewType("JBrowse/View/Track/Wiggle/XYPlot");

    $self->setTrackType("Coverage");

    # These are optional
    $self->setStrand($args->{strand});
    $self->setAlignment($args->{alignment});

    return $self;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    my $scale = $self->getScale();
    my $minScore = $self->getCovMinScoreDefault();
    my $maxScore = $self->getCovMinScoreDefault();
    my $yScalePosition = $self->getYScalePosition();

    $jbrowseObject->{yScalePosition} = $yScalePosition;
    $jbrowseObject->{min_score} = $minScore;
    $jbrowseObject->{max_score} = $maxScore;
    $jbrowseObject->{scale} = $scale;

    return $jbrowseObject;
}

sub getJBrowseMetadata {
    my $self = shift;

    my $strand = $self->getStrand();
    my $alignment = $self->getAlignment();

    my $metadata = $self->SUPER::getJBrowseMetadata();
    $metadata->{strand} = $strand if($strand);
    $metadata->{alignment} = $alignment if($alignment);

    return $metadata;
}





1;
