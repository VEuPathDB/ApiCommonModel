package ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use ApiCommonModel::Model::JBrowseTrackConfig::VCFStore;

use strict;
use warnings;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Genetic Variation");
    $datasetConfig->setSubcategory("DNA polymorphism");

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    #$self->setDisplayType("JBrowse/View/Track/CanvasVariants");

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::VCFStore->new($args);
        $self->setDisplayType("JBrowse/View/Track/CanvasVariants");
    }
    else {
        # TODO
        $store = ApiCommonModel::Model::JBrowseTrackConfig::VCFStore->new($args);
        $self->setDisplayType("LinearVariantDisplay");
    }

    $self->setStore($store);

    # A caller may supply its own glyph, including a "{someFxn}" reference resolved per
    # feature, so one track can shape SNVs and indels differently. Defaults to the diamond
    # every existing caller expects.
    $self->setGlyph($args->{glyph} ? $args->{glyph} : "EbrcTracks/View/FeatureGlyph/Diamond");

    # The historic default names VectorBase because the only caller was VectorBase's
    # per-sample ebi_VCF tracks. It is shown to users in the track selector, so a caller
    # serving some other VCF must be able to say what it actually is rather than
    # mislabel it.
    $self->setTrackTypeDisplay($args->{track_type_display}
                                 ? $args->{track_type_display}
                                 : "VCF from VectorBase");

    return $self;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    $jbrowseObject->{urlTemplate}= $self->getStore()->getUrlTemplate();

    # Store-level fetch ceilings, not allocations: when a region needs more than this the
    # store abandons it rather than rendering. The merged multi-sample call sets are far
    # larger than the per-sample VCFs these were first sized for. Emitted as numbers
    # rather than the quoted string this used to send.
    $jbrowseObject->{chunkSizeLimit} = 50000000;
    $jbrowseObject->{fetchSizeLimit} = 150000000;

    # This - NOT chunkSizeLimit - is what produces "Too many features to show" when zoomed
    # out. CanvasFeatures.fillBlock refuses to draw a block whose feature density exceeds
    # it, and the JBrowse default is 0.5 features/pixel. The merged call set runs about 6.8
    # variants/kb, so in a ~1000px window a 300kb view is already ~2 features/pixel and a
    # full 3.3Mb P. falciparum chromosome is ~22 - both far past 0.5. 50 clears a whole
    # chromosome with roughly 2x headroom. Deliberately not the 9999999 that
    # RNASeqJunctionTrackConfig uses: that invites drawing 100k+ glyphs at genome scale.
    $jbrowseObject->{maxFeatureScreenDensity} = 50;

    $jbrowseObject->{glyph} = $self->getGlyph();
    return $jbrowseObject;
}


sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();
    my $datasetConfig = $self->getDatasetConfigObj();
    my $studyDisplayName = $datasetConfig->getStudyDisplayName();
    my $trackId = $self->getLabel();

    my $uri = $self->getStore()->getUrlTemplate();
    my $indexUri = $uri . "\.tbi";
    my $displayId = $trackId . "-LinearVariantDisplay";

    $jbrowse2Object->{type}= "VariantTrack";
    $jbrowse2Object->{adapter}->{vcfGzLocation} = {uri => $uri, locationType => "UriLocation"};
    $jbrowse2Object->{adapter}->{index}->{location} = {uri => $indexUri, locationType => "UriLocation"};
    $jbrowse2Object->{displays} = [{displayId => $displayId, type => "LinearVariantDisplay"}];

	    return $jbrowse2Object;
	}

1;


