package ApiCommonModel::Model::JBrowseTrackConfig::InterproDomainsTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

#sub getUrl {$_[0]->{url} }
#sub setUrl {$_[0]->{url} = $_[1]}



sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Protein targeting and localization");

    $self->setId($args->{key});
    $self->setLabel($args->{label}); 
    $self->setGlyph($args->{glyph});
#    $self->setUrl($args->{relative_path_to_file});

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
        $self->setDisplayType("EbrcTracks/View/Track/CanvasSubtracks");
        $self->setDisplayMode("normal");
    }
    else {
        # TODO
    }

    $self->setStore($store);
    
    $self->setGlyph("JBrowse/View/FeatureGlyph/Box") unless(defined $self->getGlyph());

    my $detailsFunction = "{interproTitleFxn}";

    $self->setOnClickContent($detailsFunction);
    $self->setViewDetailsContent($detailsFunction);

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    $jbrowseStyle->{color} = "{interproColorFxn}";
    $jbrowseStyle->{showLabels} = JSON::false;
    $jbrowseStyle->{strandArrow} = JSON::false;
    $jbrowseStyle->{subParts} = JSON::true;
    $jbrowseStyle->{label} = "{source} {name}";
    return $jbrowseStyle;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    $jbrowseObject->{featureTooltips} = JSON::true;
    $jbrowseObject->{showTooltips} = JSON::true;
    $jbrowseObject->{topLevelFeatures} = "protein_match";
    $jbrowseObject->{subtracks} = [
        {featureFilters => {source => "CDD"},              visible => 1, label => "CDD",              metadata => {}},
        {featureFilters => {source => "Coils"},            visible => 1, label => "Coils",            metadata => {}},
        {featureFilters => {source => "FunFam"},           visible => 1, label => "FunFam",           metadata => {}},
        {featureFilters => {source => "Gene3D"},           visible => 1, label => "Gene3D",           metadata => {}},
        {featureFilters => {source => "Hamap"},            visible => 1, label => "Hamap",            metadata => {}},
        {featureFilters => {source => "MobiDBLite"},       visible => 1, label => "MobiDBLite",       metadata => {}},
        {featureFilters => {source => "NCBIfam"},          visible => 1, label => "NCBIfam",          metadata => {}},
        {featureFilters => {source => "PANTHER"},          visible => 1, label => "PANTHER",          metadata => {}},
        {featureFilters => {source => "Pfam"},             visible => 1, label => "Pfam",             metadata => {}},
        {featureFilters => {source => "PIRSF"},            visible => 1, label => "PIRSF",            metadata => {}},
        {featureFilters => {source => "PIRSR"},            visible => 1, label => "PIRSR",            metadata => {}},
        {featureFilters => {source => "PRINTS"},           visible => 1, label => "PRINTS",           metadata => {}},
        {featureFilters => {source => "ProSitePatterns"},  visible => 1, label => "ProSitePatterns",  metadata => {}},
        {featureFilters => {source => "ProSiteProfiles"},  visible => 1, label => "ProSiteProfiles",  metadata => {}},
        {featureFilters => {source => "SFLD"},             visible => 1, label => "SFLD",             metadata => {}},
        {featureFilters => {source => "SMART"},            visible => 1, label => "SMART",            metadata => {}},
        {featureFilters => {source => "SUPERFAMILY"},      visible => 1, label => "SUPERFAMILY",      metadata => {}},
    ];
    $jbrowseObject->{displayMode} = "compact";
    return $jbrowseObject;
  }

# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
