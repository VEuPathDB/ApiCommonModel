package ApiCommonModel::Model::JBrowseTrackConfig::ScaffoldsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

# TODO: Set border color here in new method
#sub getBorderColor {$_[0]->{border_color}}
#sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub getBaseUrl {$_[0]->{baseUrl} }
sub setBaseUrl {
    my($self, $baseUrl) = @_;
    die "required baseUrl not set" unless $baseUrl;
    $self->{baseUrl} = $baseUrl;
}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);


    $self->setColor("function( feature, variableName, glyphObject, track ){ var c = track.browser.config; return c.scaffoldColor(feature)}");
    $self->setHeight("function(feature, variableName, glyphObject, track){ var c = track.browser.config; return c.scaffoldHeight(feature)}");
    $self->setCategory("Sequence Analysis");
    $self->setDisplayType("JBrowse/View/Track/CanvasFeatures");
    $self->setId("Scaffolds and Gaps");
    $self->setLabel("Scaffolds");
    $self->setSubcategory("Sequence assembly");
    $self->setBaseUrl($args->{baseUrl});

    return $self;
}

sub getJBrowseObject{
        my $self = shift;

        my $jbrowseObject = $self->SUPER::getJBrowseObject();
        $jbrowseObject->{onClick} = {content => "{function(track, feature){ var c = track.browser.config; return c.scaffoldDetails(track, feature)}"};
        $jbrowseObject->{menuTemplate} = [
                            {label =>  "View Details", content => "function(track, feature){ var c = track.browser.config; return c.scaffoldDetails(track, feature)}",}
        ];
        $jbrowseObject->{baseUrl}= $self->getBaseUrl();
        $jbrowseObject->{query} = {'feature' => "scaffold:genome"};
        $jbrowseObject->{subParts} = "sgap";


    return $jbrowseObject;
}

# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
