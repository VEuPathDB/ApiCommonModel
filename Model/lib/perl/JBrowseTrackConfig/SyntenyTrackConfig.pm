package ApiCommonModel::Model::JBrowseTrackConfig::SyntenyTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use ApiCommonModel::Model::JBrowseTrackConfig::SyntenyStore;

use strict;
use warnings;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {$_[0]->{url_template} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Comparative Genomics");
    $datasetConfig->setSubcategory("Orthology and Synteny");

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    $self->setDisplayType("EbrcTracks/View/Track/Synteny");
    $self->setUrlTemplate($args->{url_template});

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::SyntenyStore->new($args);
        $store->setQuery("gene:syntenyJBrowseScaled");
    }
    else {
        # TODO
    }

    $self->setStore($store);
    $self->setGlyph("function(f){return f.get('syntype') === 'span' ? 'JBrowse/View/FeatureGlyph/Box' : 'JBrowse/View/FeatureGlyph/Gene'; }");
    $self->setTrackTypeDisplay("Segments");

    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $style = {color => "{syntenyColorFxn}",
		 unprocessedTranscriptColor => "lightgrey",
		 utrColor => "grey",
		 connectorThickness => "function(f){return f.get('syntype') === 'span' ? 3 : 1; }",
		 showLabels => "function(){return false}",
		 strandArrow => "function(f){return f.get('syntype') === 'span' ? false : true; }",
		 height => "function(f){return f.get('syntype') === 'span' ? 2 : 5; }",
		 marginBottom => 0,
    };
    return $style;
}


sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    $jbrowseObject->{menuTemplate} = [
    {label => "View Details", content => "{syntenyTitleFxn}",},
    {label => "View Gene or Sequence Page", title => "function(track,f) { return f.get('syntype') == 'span' ? f.get('contig') : f.get('name'); }", iconClass => "dijitIconDatabase", action => "iframeDialog", url => "function(track,f) { return f.get('syntype') == 'span' ? '/a/app/record/genomic-sequence/' + f.get('contig') : '/a/app/record/gene/' + f.get('name') }"}
    ];
    # TODO - replace with:
    # $jbrowseObject->{unsafePopup} = "JSON::true";
    $jbrowseObject->{unsafePopup} = 'function(){return_true}';

    $jbrowseObject->{transcriptType} = "processed_transcript";
    $jbrowseObject->{noncodingType} = ["nc_transcript"];
    $jbrowseObject->{subParts} = "CDS,UTR,five_prime_UTR,three_prime_UTR,nc_exon,pseudogenic_exon";
    $jbrowseObject->{region_feature_densities} = "function(){return false}";
    $jbrowseObject->{geneGroupAttributeName} = "orthomcl_name";
    $jbrowseObject->{displayMode} = "normal";
    $jbrowseObject->{onClick} = {content => "{syntenyTitleFxn}"};


    return $jbrowseObject;
}


sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}

1;


