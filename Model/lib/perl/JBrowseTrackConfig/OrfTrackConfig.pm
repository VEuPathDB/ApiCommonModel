package ApiCommonModel::Model::JBrowseTrackConfig::OrfTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("Coding Potential");

    $self->setId("orfFinder Alignments");
    $self->setLabel("orfFinder Alignments");

    my $store;
    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }
    else {
        # TODO
	$store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }

    $self->setStore($store);

    $self->setColor("{orfColor}");
    #$self->setBorderColor("{processedTranscriptBorderColor}");

    $self->setDisplayMode("compact");
    $self->setGlyph("JBrowse/View/FeatureGlyph/Box");

    my $detailsFunction = "{orfRepeatDetailsFxn}";

    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    return $self;
}

sub getJBrowseStyle {
   my $self = shift;
   my $jbrowseStyle = $self->SUPER::getJBrowseStyle();


   return $jbrowseStyle;
}



sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();
	$jbrowseObject->{onClick} = {content => "{orfDetails}"};
        $jbrowseObject->{maxFeatureScreenDensity} = 0.5;        
        $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => "{orfDetails}"}]; 

    return $jbrowseObject;
}
# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


	return $jbrowse2Object;
}


1;
