package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;

use JSON;

sub getMultiUrls {$_[0]->{multi_urls} }
sub setMultiUrls {$_[0]->{multi_urls} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setMultiUrls($args->{multi_urls});

		$self->setStoreType("MultiBigWig/Store/SeqFeature/MultiBigWig");

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

	$jbrowseObject->{url_templates} = $self->getMultiUrls();
	$jbrowseObject->{showTooltips} = JSON::true;

	return $jbrowseObject;
}

sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


	return $jbrowse2Object;
}

# sub getApolloObject {

# 	my $self = shift;
# 	my $datasetName = $self->getDatasetName();
# 	my $displayName = $self->getDisplayName();
# 	my $studyDisplayName = $self->getStudyDisplayName();
# 		my $urlTemplates = $self->getMultiUrls();
# 	my $color = $self->getColor();
# 	my $label = $self->getLabel();
# 	my $covMaxScoreDefault = $self->getCovMaxScoreDefault();
# 	my $multiCovScale =  $self->getScale();
# 	my $category = $self->getCategory();
# 	#my $summary = $self->getSummary();
# 	my $apolloObject={storeClass => "JBrowse/Store/SeqFeature/BigWig",
# 					  key => "$studyDisplayName - $displayName Coverage",
# 					  yScalePosition => "left",
# 					  urlTemplate => $urlTemplates,
# 					  scale => "log",
# 					  max_score => $covMaxScoreDefault,
# 					  metadata => {
# 						  subcategory => "RNA-Seq",
# 						  trackType => "Coverage",
# 						  alignment => "unique",
# 						  dataset => $datasetName,
# 					  },
# 					  label => "$datasetName $label Coverage",
# 					  type => "JBrowse/View/Track/Wiggle/XYPlot",
# 					  min_score => 0,
# 					  max_score => 1000,
# 					  scale => "log",
# 					  fmtMetaValue_Dataset => "function() { return datasetLinkByDatasetName('${datasetName}', '${studyDisplayName}'); }",
# 					  #                  fmtMetaValue_Description => "function() { return datasetDescription('${summary}', ''); }"
# 	};

# 	return $apolloObject;
# }


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


    $self->setDisplayType("MultiBigWig/View/Track/MultiWiggle/MultiDensity");

		$self->setTrackType("Multi-Density");

		my $alignment = $self->getAlignment();

		my $alignmentDisplay = "Unique And Non-Unique";
		if($alignment && $alignment eq 'unique') {
			$alignmentDisplay = "Unique Only";
		}

		$self->setLabel("$datasetName Density - $alignmentDisplay");
		$self->setId("$displayName Density - $alignmentDisplay");

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

    $self->setDisplayType("MultiBigWig/View/Track/MultiWiggle/MultiXYPlot");

		$self->setTrackType("Multi XY plot");

		my $alignment = $self->getAlignment();

		my $alignmentDisplay = "Unique And Non-Unique";
		if($alignment && $alignment eq 'unique') {
			$alignmentDisplay = "Unique Only";
		}

		$self->setLabel("$datasetName XYPlot - $alignmentDisplay");
		$self->setId("$displayName XYPlot - $alignmentDisplay");

    return $self;
}

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

	$jbrowseObject->{autoscale} = "local";

	return $jbrowseObject;
}

1;