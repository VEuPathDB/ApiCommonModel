package ApiCommonModel::Model::JBrowseTrackConfig::MicrosatelliteStsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use JSON;
use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("Linkage mapping");

    $self->setId("Microsatellite");
    $self->setLabel("Microsatellite");

    my $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    $self->setStore($store);

    $self->setColor("purple");
    $self->setGlyph("JBrowse/View/FeatureGlyph/Diamond");
    $self->setMaxFeatureScreenDensity(10);

    my $detailsFunction = "{microsatelliteTitleFxn}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;
    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();
    $jbrowseStyle->{strandArrow} = JSON::false;
    return $jbrowseStyle;
}


# TODO:
sub getJBrowse2Object{
        my $self = shift;
        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();
        return $jbrowse2Object;
}


1;
