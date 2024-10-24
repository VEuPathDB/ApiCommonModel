package ApiCommonModel::Model::JBrowseTrackConfig::RNASeqJunctionTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getUrl {$_[0]->{url} }
sub setUrl {$_[0]->{url} = $_[1]}

sub getSummary {$_[0]->{summary} }
sub setSummary {$_[0]->{summary} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Transcriptomics");
    $datasetConfig->setSubcategory("RNA-Seq");
    $self->setSummary($args->{summary});
    


    my $store;
    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("gsnap:unifiedintronjunctionnew");

        $self->setDisplayType("EbrcTracks/View/Track/CanvasSubtracks");
        $self->setTrackTypeDisplay("Predicted Intron Junctions");
#        $self->setGlyph("EbrcTracks/View/FeatureGlyph/AnchoredSegment");
        $self->setId("RNA-Seq Evidence for Introns");
        $self->setLabel("RNA-Seq Evidence for Introns");
        $self->setColor("{gsnapIntronColorFromStrandAndScore}");
    }
    else {
        # TODO
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

	my $url = $self->getUrl();
	my $summary = $self->getSummary();

	$jbrowseObject->{onClick} = {action => "iframeDialog", hideIframeDialogUrl => "JSON::true", url => "/a/app/embed-record/junction/{name}?tables=SampleInfo"};        
        $jbrowseObject->{menuTemplate} = [{label =>  "View Details", content => "{gsnapUnifiedIntronJunctionTitleFxn}"}, {label => "Intron Record:  {name}", action => "iframeDialog",hideIframeDialogUrl => "JSON::true", url => "/a/app/embed-record/junction/{name}?tables=SampleInfo"}, {label => "Highlight this Feature"}];
        $jbrowseObject->{fmtMetaValue_Description} =  "function(){return datasetDescription(\"$summary\", \"\");}";
        $jbrowseObject->{maxFeatureScreenDensity} = 0.5;
        $jbrowseObject->{subtracks} = [{featureFilters => {annotated_intron => "Yes", evidence => "Strong Evidence",},visible => 1, label => "Matches Annotation", metadata => {},},{featureFilters => {annotated_intron => "No",evidence => "Strong Evidence",},visible => 1,label => "Unannotated (Strong Evidence)",metadata => {},},{featureFilters => {annotated_intron => "No",evidence => "Weak Evidence",},visible => 0,label => "Unannotated (Weak Evidence)",metadata => {},}];
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
