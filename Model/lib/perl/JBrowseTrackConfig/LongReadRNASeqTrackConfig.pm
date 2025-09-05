package ApiCommonModel::Model::JBrowseTrackConfig::LongReadRNASeqTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getUrl {$_[0]->{url} }
sub setUrl {$_[0]->{url} = $_[1]}

sub getSummary {$_[0]->{summary} }
sub setSummary {$_[0]->{summary} = $_[1]}

sub getDisplayName {$_[0]->{type} }
sub setDisplayName {$_[0]->{type} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Gene Models");
    $datasetConfig->setSubcategory("Long Read RNA-Seq");

    $self->setId($args->{key});
    $self->setUrl($args->{url});
    $self->setSummary($args->{summary});
    $self->setLabel($args->{label});
    $self->setDisplayType($args->{type});

    my $store;
    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);

        $self->setTrackTypeDisplay("All Gene Models");
        $self->setGlyph("JBrowse/View/FeatureGlyph/ProcessedTranscript");

    }
    else {
        # TODO
	$store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);

        $self->setTrackType("FeatureTrack");
	#$self->setDisplayType("LinearFeatureDisplay");
	$self->setTrackTypeDisplay("Alignment"); 
    }

    $self->setStore($store);

    $self->setColor("{processedApolloTranscriptColor}");
    $self->setBorderColor("{processedTranscriptBorderColor}");

    $self->setDisplayMode("normal");

    return $self;
}


sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

	my $url = $self->getUrl();
	my $summary = $self->getSummary();

	$jbrowseObject->{transcriptType} = "transcript";
        $jbrowseObject->{topLevelFeatures} = "transcript";
        $jbrowseObject->{subParts} = "exon"; 
        $jbrowseObject->{impliedUTRs} = "JSON::true";
        $jbrowseObject->{topLevelFeaturesPercent} =  33;       
	$jbrowseObject->{onClick} = {action => "iframeDialog", hideIframeDialogUrl =>  "JSON::true", url => $url};        
        $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => "{longReadRnaSeqGffDetails}"},];
        $jbrowseObject->{fmtMetaValue_Description} =  "function(){return datasetDescription(\"$summary\", \"\");}";


    return $jbrowseObject;
}
# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();

        my $uri = $self->getStore()->getUrlTemplate();
	my $indexLocation = $uri . "\.tbi";
        $jbrowse2Object->{adapter}->{gffGzLocation} = {uri => $uri, locationType => "UriLocation"};
	$jbrowse2Object->{adapter}->{index}->{location} = {uri => $indexLocation, locationType => "UriLocation"};
	#$jbrowse2Object->{adapter}->{type} = "Gff3TabixAdapter";
	$jbrowse2Object->{displays}->[0]->{displayId} = "gff_" . scalar($self);

	return $jbrowse2Object;
}


1;
