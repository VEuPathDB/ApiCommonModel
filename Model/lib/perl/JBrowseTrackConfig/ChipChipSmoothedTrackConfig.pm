package ApiCommonModel::Model::JBrowseTrackConfig::ChipChipSmoothedTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;
use Data::Dumper;

use ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getUrl {$_[0]->{url} }
sub setUrl {$_[0]->{url} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Epigenomics");
    $datasetConfig->setSubcategory("ChIP chip");

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    $self->setGlyph($args->{glyph});

    $self->setUrl($args->{relative_path_to_file});

#    $self->setDisplayMode(undef);
#    $self->setGlyph(undef);

    $self->setCovMaxScoreDefault(defined $args->{cov_max_score_default} ? $args->{cov_max_score_default} : 1000);
    $self->setCovMinScoreDefault(defined $args->{cov_min_score_default} ? $args->{cov_min_score_default} : 0);


    $self->setTrackTypeDisplay("XYPlot");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
	$store = ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore->new($args);
    }
    else {
        # TODO
	$store = ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore->new($args);
    }

    $self->setStore($store);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    $jbrowseStyle->{height} = 40;
    $jbrowseStyle->{neg_color} = "{chipColor}";
    $jbrowseStyle->{pos_color} = "{chipColor}";

    return $jbrowseStyle;
}


sub getJBrowseObject{
  my $self = shift;
  my $jbrowseObject = $self->SUPER::getJBrowseObject();

  $jbrowseObject->{max_score} =  "3";
  $jbrowseObject->{min_score} =  "-3";
 # $jbrowseObject->{scale} = undef;

  return $jbrowseObject;
}


# TODO:
sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}


1;
