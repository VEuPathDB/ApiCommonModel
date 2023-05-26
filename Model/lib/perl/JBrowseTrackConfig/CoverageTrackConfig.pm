package ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getUrlTemplates {$_[0]->{url_templates}}
sub setUrlTemplates {$_[0]->{url_templates} = $_[1] || [] }

sub getCovMaxScoreDefault {$_[0]->{cov_max_score_default}}
sub setCovMaxScoreDefault {$_[0]->{cov_max_score_default} = $_[1]}

sub getScale {$_[0]->{scale}}
sub setScale {$_[0]->{scale} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplates($args->{url_templates});
    $self->setCovMaxScoreDefault($args->{cov_max_score_default});
    $self->setScale($args->{scale});

    return $self;
}


1;
