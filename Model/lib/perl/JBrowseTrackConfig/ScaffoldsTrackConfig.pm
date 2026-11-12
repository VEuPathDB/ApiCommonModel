package ApiCommonModel::Model::JBrowseTrackConfig::ScaffoldsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor("function( feature, variableName, glyphObject, track ){ var c = track.browser.config; return c.scaffoldColor(feature)}");
    $self->setHeight("function(feature, variableName, glyphObject, track){ var c = track.browser.config; return c.scaffoldHeight(feature)}");


    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Sequence Analysis") if $datasetConfig;
    $datasetConfig->setSubcategory("Sequence assembly") if $datasetConfig;

    $self->setId("Scaffolds and Gaps");
    $self->setLabel("Scaffolds");

    # jbrowse2: stock colour and details until VEuPathDBDisplay ships the scaffold functions.
    $self->setStore(ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args));

    $self->setSubParts("sgap");

    my $detailsFunction = "function(track, feature){ var c = track.browser.config; return c.scaffoldDetails(track, feature)}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    return $self;
}

1;
