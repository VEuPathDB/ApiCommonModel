package ApiCommonModel::Model::JBrowseTrackConfig::UnifiedSnpTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Genetic Variation");
    $datasetConfig->setSubcategory("DNA polymorphism");

    $self->setColor("{snpColorFxn}");

    $self->setId("SNPs by coding potential");
    $self->setLabel("SNPs by coding potential");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("SNP:Population");
        $store->setQueryParamsHash({edname => "InsertSnps.pm NGS SNPs INTERNAL"});
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{snpTitleFxn}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    $self->setMaxFeatureScreenDensity(0.01);
    $self->setRegionFeatureDensities(JSON::true);

    $self->setDisplayMode("compact");
    $self->setGlyph("EbrcTracks/View/FeatureGlyph/Diamond");

    $self->setTrackTypeDisplay("Unified SNPs");

    $self->setDescription("The SNPs in this track are gathered from the high-throughput sequencing data of multiple strains and isolates. For more details on the methods used, go to the Data menu, choose Analysis Methods, and then scroll down to the Genetic Variation and SNP calling section. SNPs in this track are represented as colored diamonds, where dark blue = non-synonymous, light blue = synonymous, red = nonsense, and yellow = non-coding.");
    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    $jbrowseStyle->{strandArrow} = JSON::false;
    $jbrowseStyle->{labelScale} = 1000000000000000;
    return $jbrowseStyle;
}



# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
