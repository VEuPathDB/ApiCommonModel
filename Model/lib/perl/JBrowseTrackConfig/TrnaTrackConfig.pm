package ApiCommonModel::Model::JBrowseTrackConfig::TrnaTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("Sequence sites, features and motifs");

    $self->setId("tRNAscan");
    $self->setLabel("tRNAscan");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
        $store->setQuery("domain:tRNA");
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{positionTitle}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    $self->setColor("white");


    return $self
}

sub getJBrowseStyle {
    my $self = shift;
    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    $jbrowseStyle->{borderColor} = "{processedTranscriptBorderColor}";

    return $jbrowseStyle;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    #$jbrowseObject->{metadata} = {featureType => 'tRNA'};

    return $jbrowseObject;
  }



# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


	return $jbrowse2Object;
}


1;
