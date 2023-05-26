package ApiCommonModel::Model::JBrowseTrackConfig::RNASeqCoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);

use strict;
use warnings;
use Data::Dumper;
sub getUrlTemplate {
	my $self = shift;
	return $self->getUrlTemplates()->[0];
}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplates([$args->{url_template}]);

    return $self;
}


sub getJBrowseObject{
	my $self = shift;
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();
	my $file = $self->getFileName();
	my $urlTemplate = $self->getUrlTemplate();
	my $color = $self->getColor();
	my $label = $self->getLabel();
	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
	my $multiCovScale =  $self->getScale();
	my $category = $self->getCategory();
	my $summary = $self->getSummary();
	my $jbrowseObject = {storeClass => "JBrowse/Store/SeqFeature/BigWig",
						 urlTemplate => $urlTemplate,
						 yScalePosition => "left",
						 key => "$studyDisplayName - $displayName Coverage",
						 label => "$datasetName $label Coverage",
						 type => "JBrowse/View/Track/Wiggle/XYPlot",
						 category => "$category",
						 min_score => 0,
						 max_score => $covMaxScoreDefault,
						 style => {
							 "pos_color"         => $color,
								 "clip_marker_color" =>  "black",
								 "height" => 40
						 },
						 scale => $multiCovScale,
						 fmtMetaValue_Dataset => "function() { return datasetLinkByDatasetName('${datasetName}', '${studyDisplayName}'); }",
						 fmtMetaValue_Description => "function() { return datasetDescription('${summary}', ''); }"
	};

	return $jbrowseObject;
}

sub getJBrowse2Object{
	my $self = shift;
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();
	my $file = $self->getFileName();
	my $urlTemplate = $self->getUrlTemplate();
	my $color = $self->getColor();
	my $label = $self->getLabel();
	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
	my $multiCovScale =  $self->getScale();
	my $category = $self->getCategory();
	my $jbrowse2Object = {storeClass => "MultiBigWig/Store/SeqFeature/MultiBigWig",
						  yScalePosition => "left",
						  key => "$studyDisplayName - $displayName Coverage",
						  autoscale => "local",
						  style => {
							  "height" => "40"
						  },
						  urlTemplates => [{
							  url => $urlTemplate,
							  color => $color,
							  name => $datasetName
										   }],
						  metadata => {
							  subcategory => "RNA-Seq",
							  trackType => "Multi XY plot",
							  alignment => "Unique",
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

	my $apolloObject= $self->getJBrowseObject();
	my $project = $self->getProject();

	#TODO:  change the urltemplate
	# my $urlTemplate = $self->getUrlTemplate();
	# $urlTemplate =~ s/lc($project)/; (this is not right.  need to specify full url here)
	# $apolloObject->{urlTemplate} = $urlTemplate;

	return $apolloObject;
}

1;
