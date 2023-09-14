package ApiCommonModel::Model::JBrowseTrackConfig::Segments;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getDisplayMode {$_[0]->{display_mode} }
sub setDisplayMode {$_[0]->{display_mode} = $_[1]}

sub getFmtMetaValueDescription {$_[0]->{fmtMetaValue_Description} }
sub setFmtMetaValueDescription {$_[0]->{fmtMetaValue_Description} = $_[1]}

sub getMaxFeatureScreenDensity {$_[0]->{max_feature_screen_density} }
sub setMaxFeatureScreenDensity {$_[0]->{max_feature_screen_density} = $_[1]}

sub getRegionFeatureDensities {$_[0]->{region_feature_densities} }
sub setRegionFeatureDensities {$_[0]->{region_feature_densities} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setDisplayType($args->{display_type});
    $self->setGlyph($args->{glyph});
    $self->setDisplayMode($args->{display_mode});
    $self->setFmtMetaValueDescription($args->{fmtMetaValue_Description});
    $self->setTrackTypeDisplay("Segments");
    $self->setMaxFeatureScreenDensity($args->{max_feature_screen_density});
    $self->setRegionFeatureDensities($args->{region_feature_densities});

    return $self;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    my $glyph = $self->getGlyph();
    my $displayMode = $self->getDisplayMode();
    my $fmtMetaValueDescription = $self->getFmtMetaValueDescription();
    my $maxFeatureScreenDensity = $self->getMaxFeatureScreenDensity();
    my $regionFeatureDensities = $self->getRegionFeatureDensities();
   
    $jbrowseObject->{glyph} = $glyph if($glyph);
    $jbrowseObject->{displayMode} = $displayMode if($displayMode);
    $jbrowseObject->{fmtMetaValue_Description} = $fmtMetaValueDescription if($fmtMetaValueDescription);
    $jbrowseObject->{max_feature_screen_density} = $maxFeatureScreenDensity if($maxFeatureScreenDensity);
    $jbrowseObject->{region_feature_densities} = $regionFeatureDensities if($regionFeatureDensities);

    return $jbrowseObject;
}

sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}

1;
