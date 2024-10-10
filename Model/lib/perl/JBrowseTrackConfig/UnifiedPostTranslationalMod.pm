package ApiCommonModel::Model::JBrowseTrackConfig::UnifiedPostTranslationalMod;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Proteomics");

    $self->setId("Unified Post Translational Modification MassSpec");
    $self->setLabel("UnifiedMassSpecPeptides");
    $self->setDisplayType("JBrowse/View/Track/CanvasFeatures");
    $self->setGlyph("EbrcTracks/View/FeatureGlyph/Diamond");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
	$store->setQueryParamsHash($args->{query_params});
    }
    else {
        # TODO
    }

    $self->setStore($store);
    

    my $detailsFunction = "{massSpecDetails}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);
    $self->setDisplayMode("compact");

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    $jbrowseStyle->{color} = "{unifiedPostTranslationalModColor}";
    $jbrowseStyle->{labelScale} = 1000000000000000;
    return $jbrowseStyle;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    $jbrowseObject->{metadata} = {trackType => 'Diamond'};   
    $jbrowseObject->{onClick} = {content => "{unifiedPostTranslationalModTitle}"};
    $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => "{unifiedPostTranslationalModTitle}"}]; 

    return $jbrowseObject;
  }

# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
