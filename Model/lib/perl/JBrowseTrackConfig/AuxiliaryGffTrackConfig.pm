package ApiCommonModel::Model::JBrowseTrackConfig::AuxiliaryGffTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::AuxiliaryGFFStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory($args->{category} || "Gene Models");
    $datasetConfig->setSubcategory($args->{subcategory}) if $args->{subcategory};

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    $self->setColor("{auxiliaryUtrColor}");

    if ($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setDisplayType("NeatCanvasFeatures/View/Track/NeatFeatures");
        $self->setGlyph("NeatCanvasFeatures/View/FeatureGlyph/Gene");
        $self->setSubParts("CDS,five_prime_UTR,three_prime_UTR");
    }

    my $store = ApiCommonModel::Model::JBrowseTrackConfig::AuxiliaryGFFStore->new($args);
    $self->setStore($store);

    return $self;
}

sub getJBrowseObject {
    my $self = shift;
    my $obj = $self->SUPER::getJBrowseObject();
    $obj->{transcriptType}  = "{geneTranscriptType}";
    $obj->{noncodingType}   = ["nc_transcript"];
    return $obj;
}

1;
