package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;

use Data::Dumper;

use JSON;

use ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();

    my $multiUrls = $args->{multi_urls};
    my $store = ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigStore->new($args);
    $store->setUrlTemplatesFromMultiUrls($multiUrls);

    $self->setStore($store);
    $self->setAlignment($args->{alignment});
    $self->setScale($args->{scale});

    my $studyDisplayName = $datasetConfig->getStudyDisplayName() if ($datasetConfig);
    my $displayName = $self->getDisplayName();
    my $datasetName = $datasetConfig->getDatasetName();

    my $alignment = $self->getAlignment();

    my $alignmentDisplay;

    if($alignment && $alignment eq 'unique') {
      $alignmentDisplay = "Unique Only";
    } 
    else {
      $alignmentDisplay = "Unique And Non-Unique";
      $self->setAlignment("unique and non-unique");
    }

    my $subclassName = ref($self);
    if($subclassName =~ /Density/) {
      $self->setLabel("$datasetName Density - $alignmentDisplay");
      $self->setId("$studyDisplayName Density - $alignmentDisplay");
    }
    else {
      $self->setLabel("$datasetName XYPlot - $alignmentDisplay");
      $self->setId("$studyDisplayName XYPlot - $alignmentDisplay");
    }

    $self->setHeight($args->{height});

    unless($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
      $self->setTrackType("MultiQuantitativeTrack");

      $self->setLabel("$datasetName - $alignmentDisplay");
      $self->setId("$studyDisplayName - $alignmentDisplay");

    }


    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

		my $style = {pos_color => "black",
			     neg_color => "white",
			     height => $self->getHeight(),
		};

    return $style;
}

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

        # NOTE: For multibigwig we want url_templates
	$jbrowseObject->{urlTemplates} = $self->getStore()->getUrlTemplates();
	$jbrowseObject->{storeClass} = $self->getStore()->getStoreType();

	$jbrowseObject->{showTooltips} = JSON::true;
	$jbrowseObject->{scale} = $self->getScale();

	return $jbrowseObject;
}


sub getJBrowse2Object { 
  my ($self) = @_;

  $self->setDisplayType(undef);

  my $jbrowseObject = $self->SUPER::getJBrowse2Object();

  my $store =   $self->getStore();
  my $urlTemplates = $store->getUrlTemplates();


  $jbrowseObject->{displays}->[0]->{type} = "MultiLinearWiggleDisplay";


  $jbrowseObject->{displays}->[0]->{displayId} = "wiggle_" . scalar($self);
  $jbrowseObject->{displays}->[0]->{defaultRendering} = "multirowxy";

  foreach(@{$urlTemplates}) {
    my $name = $_->{name};
    my $uri = $_->{url};
    my $color = $_->{color};

    my $subadapter = {
      type => "BigWigAdapter",
      name => $name,
      color => $color,
      bigWigLocation => {
        uri => $uri,
        locationType => "UriLocation",

      }
    };

    push @{$jbrowseObject->{adapter}->{subadapters}}, $subadapter;
  }

  #$jbrowseObject->{displays} = [];

  return $jbrowseObject;
}



package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig::Density;

use base qw(ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig);
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setDisplayType("MultiBigWig/View/Track/MultiWiggle/MultiDensity");
    $self->setTrackTypeDisplay("Multi-Density");

    return $self;
}

# NOTE: for jbrowse 2 we only need one track with multiple displays
sub getJBrowse2Object { }


package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig::XY;

use base qw(ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig);
use strict;
use warnings;


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setDisplayType("MultiBigWig/View/Track/MultiWiggle/MultiXYPlot");
    $self->setTrackTypeDisplay("Multi XY plot");

    return $self;
}

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

	$jbrowseObject->{autoscale} = "local";

	return $jbrowseObject;
}


package ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig::XYLine;

use base qw(ApiCommonModel::Model::JBrowseTrackConfig::MultiBigWigTrackConfig::XY);
use strict;
use warnings;


sub getJBrowse2Object {
  my ($self) = @_;
  my $jbrowseObject = $self->SUPER::getJBrowse2Object();

  $jbrowseObject->{displays}->[0]->{defaultRendering} = "multiline";

  return $jbrowseObject;
}


1;
