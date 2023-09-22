package ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use ApiCommonModel::Model::JBrowseTrackConfig::VCFStore;

use strict;
use warnings;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfig();
    $datasetConfig->setCategory("Genetic Variation");
    $datasetConfig->setSubcategory("DNA polymorphism");

    $self->setId($args->{key});
    $self->setLabel($args->{label});

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::VCFStore->new($args);
    }
    else {
        # TODO
    }

    $self->setStore($store);
    $self->setGlyph("EbrcTracks/View/FeatureGlyph/Diamond");
    $self->setTrackTypeDisplay("VCF from VectorBase");

    return $self;
}


sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}

1;


