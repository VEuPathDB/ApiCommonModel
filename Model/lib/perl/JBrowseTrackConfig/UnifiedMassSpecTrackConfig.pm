package ApiCommonModel::Model::JBrowseTrackConfig::UnifiedMassSpecTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

use JSON;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor("{massSpecColor}");

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Proteomics");
    $datasetConfig->setSubcategory("Protein Expression");

    $self->setId("All MS/MS Peptides");
    $self->setLabel("UnifiedMassSpecPeptides");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{massSpecDetails}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);
    $self->setDisplayMode("compact");
    $self->setBorderColor("black");

    $self->setMaxFeatureScreenDensity(0.5);

    $self->setRegionFeatureDensities(JSON::true);
    #$self->setGlyph("");

    return $self;
}

sub getJBrowseStyle {
	my $self = shift;

	my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

	# 'massSpecColor' function does NOT work as we are not running SQL
	# $jbrowseStyle->{color} = "{massSpecColor}";
	$jbrowseStyle->{label} = "Sample,sample,name";
	return $jbrowseStyle;
}

# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
