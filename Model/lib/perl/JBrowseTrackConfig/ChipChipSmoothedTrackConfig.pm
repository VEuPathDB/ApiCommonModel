package ApiCommonModel::Model::JBrowseTrackConfig::ChipChipSmoothedTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

use JSON;

sub getPanName {$_[0]->{pan_name}}
sub setPanName {$_[0]->{pan_name} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Epigenomics");
    $datasetConfig->setSubcategory("ChIP chip");

    $self->setPanName($args->{pan_name});
    my $panName = $self->getPanName();
    $self->setId($panName);
    $self->setLabel($panName);
    $self->setCovMaxScoreDefault($args->{cov_max_score_default});
    $self->setCovMinScoreDefault($args->{cov_min_score_default});

    #TODO
    $self->setTrackTypeDisplay("XYPlot");
    ###  $self->setDisplayType("JBrowse/View/Track/CanvasFeatures");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("ChIP:ChIPchip_smoothedjbrowse");
        $store->setQueryParamsHash($args->{query_params});

    }
    else {
        # TODO
    }

    $self->setStore($store);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = {};

    $jbrowseStyle->{height} = 40;
    $jbrowseStyle->{neg_color} = "{chipColor}";
    $jbrowseStyle->{pos_color} = "{chipColor}";

    return $jbrowseStyle;
}

sub getMetadata {
    my $self = shift;

    my $metadata = $self->SUPER::getMetadata();

    $metadata->{attribution} = undef;


    return $metadata;
}


sub getJBrowseObject{
  my $self = shift;
  my $jbrowseObject = $self->SUPER::getJBrowseObject();

  $jbrowseObject->{max_score} =  "3";
  $jbrowseObject->{min_score} =  "-3";
 # $jbrowseObject->{scale} = undef;

  return $jbrowseObject;

}


# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
