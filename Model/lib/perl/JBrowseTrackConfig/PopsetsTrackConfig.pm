package ApiCommonModel::Model::JBrowseTrackConfig::PopsetsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);


    my $datasetConfig = $self->getDatasetConfig();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("BLAT and Blast Alignments");

    $self->setId("Popset Isolate Sequence Alignments");
    $self->setLabel("popsetIsolates");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("match:IsolatePopset");
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{popsetDetails}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    $self->setColor("{popsetColor}");
    $self->setBorderColor("{processedTranscriptBorderColor}");

    $self->setMaxFeatureScreenDensity(0.03);
    $self->setRegionFeatureDensities(JSON::true);
    $self->setDisplayMode("compact");


    return $self;
}


# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
