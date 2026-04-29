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

    my $store = ApiCommonModel::Model::JBrowseTrackConfig::AuxiliaryGFFStore->new($args);
    $self->setStore($store);

    return $self;
}

1;
