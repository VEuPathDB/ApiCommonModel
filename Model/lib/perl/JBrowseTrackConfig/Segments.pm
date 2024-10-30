package ApiCommonModel::Model::JBrowseTrackConfig::Segments;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getDisplayMode {$_[0]->{display_mode} }
sub setDisplayMode {$_[0]->{display_mode} = $_[1]}

sub getMaxFeatureScreenDensity {$_[0]->{max_feature_screen_density} }
sub setMaxFeatureScreenDensity {$_[0]->{max_feature_screen_density} = $_[1]}

sub getRegionFeatureDensities {$_[0]->{region_feature_densities} }
sub setRegionFeatureDensities {$_[0]->{region_feature_densities} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub getSubParts {$_[0]->{sub_parts}}
sub setSubParts {$_[0]->{sub_parts} = $_[1]}

sub getOnClickContent {$_[0]->{on_click_content}}
sub setOnClickContent {$_[0]->{on_click_content} = $_[1]}

sub getViewDetailsContent {$_[0]->{view_details_content}}
sub setViewDetailsContent {$_[0]->{view_details_content} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);


    $self->setMaxFeatureScreenDensity($args->{max_feature_screen_density});
    $self->setRegionFeatureDensities($args->{region_feature_densities});

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setDisplayType("JBrowse/View/Track/CanvasFeatures");
        $self->setTrackTypeDisplay("Segments");
        $self->setGlyph("JBrowse/View/FeatureGlyph/Box") unless($self->getGlyph());
    }
    else {
        # TODO
    }
    if ($args->{display_mode}){
      $self->setDisplayMode($args->{display_mode});
    } else {
      $self->setDisplayMode("normal");
    }

    return $self;
}


sub getJBrowseStyle {
    my $self = shift;
    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();


    $jbrowseStyle->{borderColor} = $self->getBorderColor() if($self->getBorderColor());

    return $jbrowseStyle;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    my $glyph = $self->getGlyph();
    my $displayMode = $self->getDisplayMode();
    my $maxFeatureScreenDensity = $self->getMaxFeatureScreenDensity();
    my $regionFeatureDensities = $self->getRegionFeatureDensities();
   
    $jbrowseObject->{glyph} = $glyph if($glyph);
    $jbrowseObject->{displayMode} = $displayMode if($displayMode);
    $jbrowseObject->{maxFeatureScreenDensity} = $maxFeatureScreenDensity if($maxFeatureScreenDensity);
    $jbrowseObject->{region_feature_densities} = $regionFeatureDensities if($regionFeatureDensities);
    $jbrowseObject->{subParts} = $self->getSubParts() if($self->getSubParts());


    my $onClickContent = $self->getOnClickContent();
    my $viewDetailsContent = $self->getViewDetailsContent();

    $jbrowseObject->{onClick} = {content => $onClickContent} if($onClickContent);
    $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => $viewDetailsContent,}];


    return $jbrowseObject;
}




sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}

1;
