package ApiCommonModel::Model::JBrowseTrackConfig::ChipChipPeakTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

use JSON;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor("{chipColor}");

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Epigenomics");
    $datasetConfig->setSubcategory("ChIP chip");

    $self->setId($args->{pan_name});
    $self->setLabel($args->{pan_name});

    $self->setDisplayMode(undef);
    $self->setGlyph(undef);

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("ChIP:ChIPchip_peaksjbrowse");
        $store->setQueryParamsHash($args->{query_params});
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{peakTitleChipSeqFxn}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);


    return $self;
}


sub getMetadata {
  my $self = shift;
  my $metadata = $self->SUPER::getMetadata();

  $metadata->{attribution} = undef;
  return $metadata;
}


# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
