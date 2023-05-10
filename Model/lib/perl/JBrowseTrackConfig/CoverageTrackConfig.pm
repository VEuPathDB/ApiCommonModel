package ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

#use parent 'TrackConfig';
use strict;
use warnings;

## To Do: 
# getters and setters
sub getUrlTemplates {$_[0]->{url_template}}
sub getCovMaxScoreDefault {$_[0]->{cov_max_score_default}}
sub getScale {$_[0]->{scale}}

sub setUrlTemplate {$_[0]->{url_template} = $_[1]}
sub setCovMaxScoreDefault {$_[0]->{cov_max_score_default} = $_[1]}
sub setScale {$_[0]->{scale} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    $self->{url_template} = $args->{url_template};
    $self->{cov_max_score_default} = $args->{cov_max_score_default};
    $self->{scale} = $args->{scale};

    return $self;
}


1;
