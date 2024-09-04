package ApiCommonModel::Model::JBrowseTrackConfig::UnifiedMassSpecTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

use JSON;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor("{massSpecColor}");

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Proteomics");
    $datasetConfig->setSubcategory("Protein Expression");

    $self->setId("All MS/MS Peptides");
    $self->setLabel("UnifiedMassSpecPeptides");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("domain:UnifiedMassSpecPeptides");
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{massSpecDetails}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    $self->setMaxFeatureScreenDensity(0.01);

    # TODO - replace with:
    # $self->setRegionFeatureDensities(JSON::true);
    $self->setRegionFeatureDensities('function(){return_true}');

    $self->setDisplayMode("compact");
    $self->setGlyph("");

    return $self;
}


# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
