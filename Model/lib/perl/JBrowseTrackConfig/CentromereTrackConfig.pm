package ApiCommonModel::Model::JBrowseTrackConfig::CentromereTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfig();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("Sequence sites, features and motifs");

    $self->setId("Centromere");
    $self->setLabel("Centromere");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("Centromere:overview");
    }
    else {
        # TODO
    }

    $self->setStore($store);

    $self->setColor("blue")
    $self->setSubParts("sgap");

    my $detailsFunction = "{positionTitle}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);


    return $self;
}


# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
