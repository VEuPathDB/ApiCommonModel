package ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use ApiCommonModel::Model::JBrowseTrackConfig::VCFStore;

use strict;
use warnings;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Genetic Variation");
    $datasetConfig->setSubcategory("DNA polymorphism");

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    #$self->setDisplayType("JBrowse/View/Track/CanvasVariants");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::VCFStore->new($args);
        $self->setDisplayType("JBrowse/View/Track/CanvasVariants");
    }
    else {
        # TODO
        $store = ApiCommonModel::Model::JBrowseTrackConfig::VCFStore->new($args);
        $self->setDisplayType("LinearVariantDisplay");
    }

    $self->setStore($store);
    $self->setGlyph("EbrcTracks/View/FeatureGlyph/Diamond");
    $self->setTrackTypeDisplay("VCF from VectorBase");

    return $self;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    $jbrowseObject->{urlTemplate}= $self->getStore()->getUrlTemplate();
    $jbrowseObject->{chunkSizeLimit} = '10000000';
    $jbrowseObject->{glyph} = $self->getGlyph();
    return $jbrowseObject;
}


sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();
    my $datasetConfig = $self->getDatasetConfigObj();
    my $studyDisplayName = $datasetConfig->getStudyDisplayName();
    my $trackId = $self->getLabel();

    my $uri = $self->getStore()->getUrlTemplate();
    my $indexUri = $uri . "\.tbi";
    my $displayId = $trackId . "-LinearVariantDisplay";

    $jbrowse2Object->{type}= "VariantTrack";
    $jbrowse2Object->{adapter}->{vcfGzLocation} = {uri => $uri, locationType => "UriLocation"};
    $jbrowse2Object->{adapter}->{index}->{location} = {uri => $indexUri, locationType => "UriLocation"};
    $jbrowse2Object->{displays} = [{displayId => $displayId, type => "LinearVariantDisplay"}];

	    return $jbrowse2Object;
	}

1;


