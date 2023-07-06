package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;

use JSON;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplates($args->{url_templates});

		$self->setStoreClass("MultiBigWig/Store/SeqFeature/MultiBigWig");

    my $studyDisplayName = $self->getStudyDisplayName();
    my $displayName = $self->getDisplayName();
		my $datasetName = $self->getDatasetName();

    $self->setHeight(40);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

		my $style = {pos_color => "black",
								 neg_color => "white",
		};

    return $style;
}

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

	$jbrowseObject->{url_templates} = $self->getUrlTemplates();
	$jbrowseObject->{showTooltips} = JSON::true;

	return $jbrowseObject;
}

sub getJBrowse2Object{
	my $self = shift;
	my $datasetName = $self->getDatasetName();
	my $displayName = $self->getDisplayName();
	my $studyDisplayName = $self->getStudyDisplayName();

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


package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig::Density;

use base qw(ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig);
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $studyDisplayName = $self->getStudyDisplayName();
    my $displayName = $self->getDisplayName();
		my $datasetName = $self->getDatasetName();


    $self->setViewType("MultiBigWig/View/Track/MultiWiggle/MultiDensity");

		$self->setTrackType("Multi-Density");

		my $alignment = $self->getAlignment();

		my $alignmentDisplay = "Unique And Non-Unique";
		if($alignment && $alignment eq 'unique') {
			$alignmentDisplay = "Unique Only";
		}

		$self->setLabel("$datasetName Density - $alignmentDisplay");
		$self->setKey("$displayName Density - $alignmentDisplay");

    return $self;
}

package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig::XY;

use base qw(ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig);
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $studyDisplayName = $self->getStudyDisplayName();
    my $displayName = $self->getDisplayName();
		my $datasetName = $self->getDatasetName();

    $self->setViewType("MultiBigWig/View/Track/MultiWiggle/MultiXYPlot");

		$self->setTrackType("Multi XY plot");

		my $alignment = $self->getAlignment();

		my $alignmentDisplay = "Unique And Non-Unique";
		if($alignment && $alignment eq 'unique') {
			$alignmentDisplay = "Unique Only";
		}

		$self->setLabel("$datasetName XYPlot - $alignmentDisplay");
		$self->setKey("$displayName XYPlot - $alignmentDisplay");

    return $self;
}

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

	$jbrowseObject->{autoscale} = "local";

	return $jbrowseObject;
}

1;
