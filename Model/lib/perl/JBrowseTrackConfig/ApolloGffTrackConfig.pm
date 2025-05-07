package ApiCommonModel::Model::JBrowseTrackConfig::ApolloGffTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::GffTrack);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Gene Models");

    $self->setColor("{colorFunction}");
    $self->setId("Community annotations from Apollo");
    $self->setLabel("Community annotations from Apollo");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("gff:apolloTranscript");
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{apolloGeneDetails}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

#    $self->setColor("{processedApolloTranscriptColor}");
#    $self->setBorderColor("{processedTranscriptBorderColor}");

    $self->setDescription("Community annotation represents user provided effort to improve the current gene models and offer alternatives based on -omic level evidence. Users can utilise our Apollo instance for creating and editing functional annotation to be displayed in this track. Only when the status of the gene model is changed to 'Finished' will the model be displayed, normally within 24 hours of the status change.");

    return $self
}

sub getJBrowseStyle {
   my $self = shift;
   my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

   $jbrowseStyle->{borderColor} = "{processedTranscriptBorderColor}";
   $jbrowseStyle->{unprocessedTranscriptColor} = "{unprocessedApolloTranscriptColor}";
   $jbrowseStyle->{color} = "{processedApolloTranscriptColor}";
   return $jbrowseStyle;
}

sub getJBrowseObject{
        my $self = shift;

        my $jbrowseObject = $self->SUPER::getJBrowseObject();

        $jbrowseObject->{impliedUTRs} = "JSON::true";

    return $jbrowseObject;
}


# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


	return $jbrowse2Object;
}


1;
