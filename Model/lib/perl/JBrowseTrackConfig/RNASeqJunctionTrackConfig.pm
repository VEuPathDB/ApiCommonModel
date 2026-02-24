package ApiCommonModel::Model::JBrowseTrackConfig::RNASeqJunctionTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub getSummary {$_[0]->{summary} }
sub setSummary {$_[0]->{summary} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Transcriptomics");
    $datasetConfig->setSubcategory("RNA-Seq");
    $self->setSummary($args->{summary});
    


    my $store;
    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);

        $self->setDisplayType("EbrcTracks/View/Track/CanvasSubtracks");
        $self->setTrackTypeDisplay("Predicted Intron Junctions");
        $self->setId("RNA-Seq Evidence for Introns");
        $self->setLabel("RNA-Seq Evidence for Introns");
        $self->setColor("{gsnapIntronColorFromStrandAndScore}");
    }
    else {
        # TODO
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
	$self->setDisplayType("NeatCanvasFeatures/View/Track/NeatFeatures");
        $self->setGlyph("JBrowse/View/FeatureGlyph/ProcessedTranscript");

    }

    $self->setStore($store);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = {};

    $jbrowseStyle->{postHeight} = "{gsnapIntronPostHeight}";
    $jbrowseStyle->{lineThickness} = "{gsnapIntronLineThickness}";
    $jbrowseStyle->{showLabels} = JSON::false;
    $jbrowseStyle->{label} = "function(f){return \"Reads=\" + f.get(\"score\");}";
    $jbrowseStyle->{strandArrow} = JSON::false;
    $jbrowseStyle->{color} = "{gsnapIntronColorFromStrandAndScore}";
   
    return $jbrowseStyle;
}

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

	#my $url = $self->getUrl();
	my $summary = $self->getSummary();

	$jbrowseObject->{onClick} = {action => "iframeDialog", hideIframeDialogUrl => JSON::true, url => "/a/app/embed-record/junction/{name}?tables=SampleInfo"};        
        $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => "{gsnapUnifiedIntronJunctionTitleFxn}"}, {label => "Intron Record:  {name}", action => "iframeDialog",hideIframeDialogUrl => JSON::true, url => "/a/app/embed-record/junction/{name}?tables=SampleInfo"}, {label => "Highlight this Feature"}];
        $jbrowseObject->{fmtMetaValue_Description} =  "function(){return datasetDescription(\"$summary\", \"\");}";
        $jbrowseObject->{maxFeatureScreenDensity} = 9999999;
        $jbrowseObject->{subtracks} = [{featureFilters => {annotatedintron => "Yes", evidence => "Strong Evidence",},visible => 1, label => "Matches Annotation", metadata => {},},{featureFilters => {annotatedintron => "No",evidence => "Strong Evidence",},visible => 1,label => "Unannotated (Strong Evidence)",metadata => {},},{featureFilters => {annotatedintron => "No",evidence => "Weak Evidence",},visible => 0,label => "Unannotated (Weak Evidence)",metadata => {},}];
        $jbrowseObject->{glyph} = "EbrcTracks/View/FeatureGlyph/AnchoredSegment";
        $jbrowseObject->{unsafePopup} = JSON::true;
        $jbrowseObject->{displayMode} = "normal";


    return $jbrowseObject;
}
# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();
	

	return $jbrowse2Object;
}


1;
