package ApiCommonModel::Model::JBrowseTrackConfig::UnifiedSnpTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

#sub getProjectUrl {$_[0]->{project_url}}
#sub setProjectUrl {$_[0]->{project_url} = $_[1] }

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Genetic Variation");
    $datasetConfig->setSubcategory("DNA polymorphism");
    $datasetConfig->setSummary("The SNPs in this track are gathered from the high-throughput sequencing data of multiple strains and isolates. For more details on the methods used, go to the Data menu, choose Analysis Methods, and then scroll down to the Genetic Variation and SNP calling section. SNPs in this track are represented as colored diamonds, where dark blue = non-synonymous, light blue = synonymous, red = nonsense, and yellow = non-coding.");

    $self->setColor("{snpColorFxn}");

    $self->setId("SNPs by coding potential");
    $self->setLabel("SNPs by coding potential");
#    $self->setProjectUrl($args->{project_url}); 

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("SNP:Population");
        $store->setQueryParamsHash({edname => "InsertSnps.pm NGS SNPs INTERNAL"});
#	my $projectUrl = $self->getProjectUrl();
#        my $baseUrl = $projectUrl . "/a/service/jbrowse";
#        $store->setBaseUrl($baseUrl);
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{snpTitleFxn}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    $self->setMaxFeatureScreenDensity(0.01);

    # TODO - replace with:
    # $self->setRegionFeatureDensities(JSON::true);
    $self->setRegionFeatureDensities('function(){return true}');

    $self->setDisplayMode("normal");
    $self->setGlyph("EbrcTracks/View/FeatureGlyph/Diamond");

    $self->setTrackTypeDisplay("Unified SNPs");

#    $self->setDescription("The SNPs in this track are gathered from the high-throughput sequencing data of multiple strains and isolates. For more details on the methods used, go to the Data menu, choose Analysis Methods, and then scroll down to the Genetic Variation and SNP calling section. SNPs in this track are represented as colored diamonds, where dark blue = non-synonymous, light blue = synonymous, red = nonsense, and yellow = non-coding.");
    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    # TODO - replace with:
    # $jbrowseStyle->{strandArrow} = JSON::false;
    $jbrowseStyle->{strandArrow} = 'function(){return false}';
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
