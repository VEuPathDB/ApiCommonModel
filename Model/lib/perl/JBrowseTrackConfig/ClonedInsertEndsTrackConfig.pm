package ApiCommonModel::Model::JBrowseTrackConfig::ClonedInsertEndsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("Sequence assembly");

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    $self->setGlyph($args->{glyph});

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }
    else {
        # TODO
	$store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }

    $self->setStore($store);
    $self->setGlyph("JBrowse/View/FeatureGlyph/Segments") unless(defined $self->getGlyph());

    my $detailsFunction = "{genericEndFeatureTitle}";
    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);
    $self->setDisplayMode("compact");
    $self->setBorderColor("black");

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
