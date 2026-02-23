package ApiCommonModel::Model::JBrowseTrackConfig::UnifiedPostTranslationalMod;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

use JSON;

#sub getGlyph {$_[0]->{glyph} }
#sub setGlyph {$_[0]->{glyph} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    #$self->setColor("{massSpecColor}");

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Proteomics");
    $datasetConfig->setSubcategory("Protein Expression");

    $self->setId("Unified Post Translational Modification MassSpec");
    $self->setLabel("Unified PTM MassSpecPeptides");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }
    else {
        # TODO
    }

    $self->setStore($store);
    
    #my $detailsFunction = "{massSpecDetails}";
    #$self->setOnClickContent($detailsFunction);
    #$self->setViewDetailsContent($detailsFunction);
    $self->setDisplayMode("compact");
    $self->setBorderColor("black");

    $self->setMaxFeatureScreenDensity(0.5);

    $self->setRegionFeatureDensities(JSON::true);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    $jbrowseStyle->{color} = "{unifiedPostTranslationalModColor}";
    #$jbrowseStyle->{labelScale} = 1000000000000000;
    $jbrowseStyle->{label} = "UnifiedMassSpecPeptides";
    return $jbrowseStyle;
}


# sub getJBrowseObject{
#     my $self = shift;

#     my $jbrowseObject = $self->SUPER::getJBrowseObject();
#  #   $jbrowseObject->{onClick} = {content => "{unifiedPostTranslationalModTitle}"};
#  #   $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => "{unifiedPostTranslationalModTitle}"}];

#     return $jbrowseObject;
#   }


# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();
	$jbrowse2Object->{metadata} = {trackType => 'Diamond'};	

        return $jbrowse2Object;
}


1;
