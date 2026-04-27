package ApiCommonModel::Model::JBrowseTrackConfig::BindingSitesTrackConfig;
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
    $datasetConfig->setSubcategory("Sequence sites, features and motifs");
    $datasetConfig->setDatasetName("pfal3D7_genomeFeature_Llinas_TransFactorBindingSites_GFF2_RSRC");
    $datasetConfig->setStudyDisplayName("Transcription factor binding sites");

    $self->setId("Pf Predicted AP2 Transcription Factor Binding Sites");
    $self->setLabel("BindingSites");

    my $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    $self->setStore($store);

    $self->setColor("{colorForBindingSitesByPvalueFxn}");
    $self->setBorderColor("darkgray");
    $self->setMaxFeatureScreenDensity(0.03);
    $self->setRegionFeatureDensities(JSON::true);

    my $detailsFunction = "{bindingSitesFxn}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;
    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();
    $jbrowseStyle->{strandArrow}     = JSON::false;
    $jbrowseStyle->{showLabels}      = JSON::false;
    $jbrowseStyle->{color_rev_strand} = "#EC8B8B";
    return $jbrowseStyle;
}


# TODO:
sub getJBrowse2Object{
        my $self = shift;
        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();
        return $jbrowse2Object;
}


1;
