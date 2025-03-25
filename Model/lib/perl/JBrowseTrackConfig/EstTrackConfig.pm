package ApiCommonModel::Model::JBrowseTrackConfig::EstTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Transcriptomics");

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

    $self->setColor("{estColor}");
    $self->setBorderColor("{estBorderColor}");

    $self->setDisplayMode("compact");
    $self->setGlyph("JBrowse/View/FeatureGlyph/Segments");

    return $self;
}


sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();

        $jbrowseObject->{maxFeatureScreenDensity} = 0.03;
        $jbrowseObject->{region_feature_densities} = "function(){return false}";
        $jbrowseObject->{onClick} = {content => "{estDetails}"};
	$jbrowseObject->{menuTemplate} = [
        {label =>  "View Details", content => "{estDetails}"},
        {label => "View EST Page", title => "EST {name}", iconClass => "dijitIconDatabase", action => "newWindow", url => "/a/app/record/est/{name}"}
        ];


    return $jbrowseObject;
}
# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


	return $jbrowse2Object;
}


1;
