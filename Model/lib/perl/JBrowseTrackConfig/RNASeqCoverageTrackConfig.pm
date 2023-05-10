package ApiCommonModel::Model::JBrowseTrackConfig::RNASeqCoverageTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;

### move to superclass TrackConfig
#sub getConfigurationObject {
#	my $self = shift;

#	if($self->{application_type} eq 'jbrowse') {
#		return $self->getJBrowseObject();
#	}
#	elsif($self->{application_type} eq 'jbrowse2') {
#		return $self->getJBrowse2Object();
#	}

#	elsif($self->{application_type} eq 'apollo') {
#		return $self->getApolloObject();
#	}

#	elsif($self->{application_type} eq 'apollo3') {
#		return $self->getApolloObject();
#	}

#	else {
#		die "Application Type not recognized " . $self->{application_type};
#	}
#}

### To Do: Add getter and setter for urlTemplates
sub getUrlTemplate{
	my $self = shift;


	return $self->getUrlTemplates([0]);
}


sub getJBrowseObject{
	my $self = shift;
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();
	my $file = $self->getFileName();
	my $urlTemp = $self->getUrlTemplate();
	my $color = $self->getColor();
	my $label = $self->getLabel();
	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
	my $multiCovScale =  $self->getScale();
	my $category = $self->getCategory();
#my $summary = $self->getSummary();
	my $jbrowseObject = {storeClass => "JBrowse/Store/SeqFeature/BigWig",
		urlTemplate => $urlTemp,
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
	my $urlTemp = $self->getUrlTemplate();
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
			url => $urlTemp,	
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
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();
	my $file = $self->getFileName();
	my $urlTemp = $self->getUrlTemplate();
	my $color = $self->getColor();
	my $label = $self->getLabel();
	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
	my $multiCovScale =  $self->getScale();
	my $category = $self->getCategory();
#my $summary = $self->getSummary();
	my $apolloObject={storeClass => "JBrowse/Store/SeqFeature/BigWig",
		key => "$studyDisplayName - $displayName Coverage",
		yScalePosition => "left",
		urlTemplate => $urlTemp,		  
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
