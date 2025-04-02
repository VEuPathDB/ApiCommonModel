package ApiCommonModel::Model::JBrowseTrackConfig::GffTrack;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getDisplayMode {$_[0]->{display_mode} }
sub setDisplayMode {$_[0]->{display_mode} = $_[1]}

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

    $self->setDisplayMode($args->{display_mode});

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setDisplayType("NeatCanvasFeatures/View/Track/NeatFeatures");
        $self->setTrackTypeDisplay("Processed transcript from Apollo");
        $self->setSubParts("CDS,UTR,five_prime_UTR,three_prime_UTR,nc_exon");
    }
    else {
        # TODO
    }

    $self->setDisplayMode("normal") unless($self->getDisplayMode());

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
    my $displayMode = $self->getDisplayMode();
   
    $jbrowseObject->{displayMode} = $displayMode if($displayMode);
    $jbrowseObject->{subParts} = $self->getSubParts() if($self->getSubParts());


    my $onClickContent = $self->getOnClickContent();
    my $viewDetailsContent = $self->getViewDetailsContent();

    $jbrowseObject->{onClick} = {content => $onClickContent} if($onClickContent);
    $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => $viewDetailsContent,}];
    $jbrowseObject->{unsafePopup} = JSON::true;
    $jbrowseObject->{noncodingType} = "nc_transcript";

    return $jbrowseObject;
}




sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}

1;
