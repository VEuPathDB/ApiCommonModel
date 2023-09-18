package ApiCommonModel::Model::JBrowseTrackConfig::ScaffoldsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor("function( feature, variableName, glyphObject, track){ var c = track.browser.config; return c.scaffoldColor(feature)}");
    $self->setHeight("function(feature, variableName, glyphObject, track){ var c = track.browser.config; return c.scaffoldHeight(feature)}");

    my $datasetConfig = $self->getDatasetConfig();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("Sequence assembly");

    $self->setId("Scaffolds and Gaps");
    $self->setLabel("Scaffolds");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("scaffold:genome");
    }
    else {
        # TODO
    }

    $self->setStore($store);

    $self->setSubParts("sgap");

    my $detailsFunction = "{function(track, feature){ var c = track.browser.config; return c.scaffoldDetails(track, feature)}";
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
