package ApiCommonModel::Model::JBrowseTrackConfig::ChipChipPeakTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;
use Data::Dumper;

use ApiCommonModel::Model::JBrowseTrackConfig::BedStore;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getUrl {$_[0]->{url} }
sub setUrl {$_[0]->{url} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor("{chipColor}");

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Epigenomics");
    $datasetConfig->setSubcategory("ChIP chip");

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    $self->setGlyph($args->{glyph});

    $self->setUrl($args->{relative_path_to_file});
    my $uu = $self->getUrl();
    #print Dumper "PEAK CCPT url = $uu";
    
#    $self->setDisplayMode(undef);
#    $self->setGlyph(undef);

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
	$store = ApiCommonModel::Model::JBrowseTrackConfig::BedStore->new($args);
    }
    else {
        # TODO
	$store = ApiCommonModel::Model::JBrowseTrackConfig::BedStore->new($args);
    }

    $self->setStore($store);
    $self->setGlyph("JBrowse/View/FeatureGlyph/Segments") unless(defined $self->getGlyph());
    
    my $detailsFunction = "{peakTitleChipSeqFxn}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

#    $jbrowseStyle->{color} = "";
#    $jbrowseStyle->{label} = "Sample,sample,name";
    return $jbrowseStyle;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();


    return $jbrowseObject;
  }

# TODO:
sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}


1;
