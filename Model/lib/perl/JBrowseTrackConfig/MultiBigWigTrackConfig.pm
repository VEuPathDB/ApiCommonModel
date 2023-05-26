package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;


# # getters and setters

# TODO:  Why is this here??
sub getKey {$_[0]->{key}}
 sub setKey {$_[0]->{key} = $_[1]}
# TODO:  Why is this here?? seems like error
 sub getSubcategory {$_[0]->{subcategory}}
 sub setSubcategory {$_[0]->{subcategory} = $_[1]}

sub getJBrowseObject{
	my $self = shift;
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();
	my $file = $self->getFileName();
	my $urlTemplates = $self->getUrlTemplates();
	my $color = $self->getColor();
	my $label = $self->getLabel();
	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
	my $multiCovScale =  $self->getScale();
	my $category = $self->getCategory();
	my $key =$self->getKey();
	my $subCategory = $self->getSubcategory();
	my $shortAttribution = $self->getAttribution();
	my $summary = $self->getSummary();
	#my $summary = $self->getSummary();
	my $jbrowseObject = {storeClass => "MultiBigWig/Store/SeqFeature/MultiBigWig",
						 urlTemplate => $urlTemplates,
						 showTooltips => JSON::true,
						 yScalePosition => "left",
						 key => $key,
						 label => $datasetName  . " Density - Unique And Non-Unique PAUL",
						 type => "MultiBigWig/View/Track/MultiWiggle/MultiDensity",
						 category => "$category",
						 min_score => 0,
						 max_score => $covMaxScoreDefault,
						 style => {
							 "pos_color"         => "black",
								 "neg_color"         => "white",
						 },
						 scale => $multiCovScale,
						 metadata => {
							 subcategory => $subCategory,
							 dataset => $studyDisplayName,
							 trackType => "Multi-Density",
							 attribution => $shortAttribution,
							 description => $summary
						 },
						 fmtMetaValue_Dataset => "function() { return datasetLinkByDatasetName('${datasetName}', '${studyDisplayName}'); }",
						 #                     fmtMetaValue_Description => "function() { return datasetDescription('${summary}', ''); }"
	};

	return $jbrowseObject;
}

sub getJBrowse2Object{
	my $self = shift;
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();
	my $file = $self->getFileName();
	my $urlTemplates = $self->getUrlTemplates();
	my $color = $self->getColor();
	my $label = $self->getLabel();
	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
	my $multiCovScale =  $self->getScale();
	my $category = $self->getCategory();
	my $shortAttribution = $self->getAttribution();
	my $summary = $self->getSummary();
	my $subCategory = $self->getSubcategory();
	my $jbrowse2Object = {storeClass => "MultiBigWig/Store/SeqFeature/MultiBigWig",
						  yScalePosition => "left",
						  key => "$studyDisplayName - $displayName Coverage",
						  autoscale => "local",
						  style => {
							  "height" => "40"
						  },
						  urlTemplates => [{
							  url => $urlTemplates,
							  color => $color,
							  name => $datasetName
										   }],
						  metadata => {
							  subcategory => $subCategory,
							  dataset => $studyDisplayName,
							  trackType => "Multi-Density",
							  attribution => $shortAttribution,
							  dataset => $datasetName
						  },
						  label => "$datasetName $label Coverage",
						  type => "MultiBigWig/View/Track/MultiWiggle/MultiXYPlot",
						  category => "$category",
						  showTooltips => "true"
	};

	return $jbrowse2Object;
}

sub getApolloObject {

	my $self = shift;
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();
	my $file = $self->getFileName();
	my $urlTemplates = $self->getUrlTemplates();
	my $color = $self->getColor();
	my $label = $self->getLabel();
	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
	my $multiCovScale =  $self->getScale();
	my $category = $self->getCategory();
	#my $summary = $self->getSummary();
	my $apolloObject={storeClass => "JBrowse/Store/SeqFeature/BigWig",
					  key => "$studyDisplayName - $displayName Coverage",
					  yScalePosition => "left",
					  urlTemplate => $urlTemplates,
					  scale => "log",
					  max_score => $covMaxScoreDefault,
					  metadata => {
						  subcategory => "RNA-Seq",
						  trackType => "Coverage",
						  alignment => "unique",
						  dataset => $datasetName,
					  },
					  label => "$datasetName $label Coverage",
					  type => "JBrowse/View/Track/Wiggle/XYPlot",
					  min_score => 0,
					  max_score => 1000,
					  scale => "log",
					  fmtMetaValue_Dataset => "function() { return datasetLinkByDatasetName('${datasetName}', '${studyDisplayName}'); }",
					  #                  fmtMetaValue_Description => "function() { return datasetDescription('${summary}', ''); }"
	};

	return $apolloObject;
}

1;
