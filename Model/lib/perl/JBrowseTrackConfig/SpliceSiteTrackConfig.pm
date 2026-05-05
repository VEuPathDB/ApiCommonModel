package ApiCommonModel::Model::JBrowseTrackConfig::SpliceSiteTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use JSON;
use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub getFeatureType {$_[0]->{feature_type}}
sub setFeatureType {$_[0]->{feature_type} = $_[1]}

my $COLOR_LEGEND = "<table>"
    . "<tr><th align='left' width='100'>Strand</th><th align='left' width='100'>Color</th><th align='left'>Count</th></tr>"
    . "<tr><td>forward</td><td><font color='blue'><b>blue</b></font></td><td>over 10</td></tr>"
    . "<tr><td>forward</td><td><font color='cornflowerblue'><b>light blue</b></font></td><td>between 1 and 10</td></tr>"
    . "<tr><td>forward</td><td><font color='lightskyblue'><b>pale blue</b></font></td><td>equal to 1</td></tr>"
    . "<tr><td>reverse</td><td><font color='firebrick'><b>dark red</b></font></td><td>over 10</td></tr>"
    . "<tr><td>reverse</td><td><font color='red'><b>red</b></font></td><td>between 1 and 10</td></tr>"
    . "<tr><td>reverse</td><td><font color='tomato'><b>tomato</b></font></td><td>equal to 1</td></tr>"
    . "</table>";

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $featureType = $args->{feature_type};
    $self->setFeatureType($featureType);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Gene Models");
    $datasetConfig->setSubcategory($featureType eq 'Poly A' ? "Poly A Sites" : "Splice Sites");

    $self->setId($args->{key});
    $self->setLabel($args->{label});

    $self->setStore(ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args));

    $self->setColor("{colorSpliceSiteFxn}");
    $self->setGlyph("EbrcTracks/View/FeatureGlyph/Diamond");
    $self->setMaxFeatureScreenDensity(0.01);
    $self->setRegionFeatureDensities(JSON::true);

    return $self;
}

sub getJBrowseObject {
    my $self = shift;
    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    my $datasetConfig = $self->getDatasetConfigObj();
    my $summary = $datasetConfig->getSummary();

    $jbrowseObject->{style}{strandArrow} = JSON::false;
    $jbrowseObject->{onClick} = {content => "{spliceSiteTitleFxn}"};
    $jbrowseObject->{menuTemplate} = [{label => "View Details", content => "{spliceSiteTitleFxn}"}];

    if ($summary) {
        $jbrowseObject->{fmtMetaValue_Description} = "function() { return datasetDescription('${summary}  $COLOR_LEGEND', ''); }";
    }

    return $jbrowseObject;
}

sub getJBrowse2Object {
    my $self = shift;
    return $self->SUPER::getJBrowse2Object();
}

1;
