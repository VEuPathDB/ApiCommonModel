package ApiCommonModel::Model::JBrowseTrackConfig::VariantTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig);

use strict;
use warnings;

# The merged, snpEff-annotated call set: one VCF per organism, and every position in it is
# a Short Variant record. That single fact is what this subclass exists to express, and
# everything here follows from it - which is why none of it belongs in VcfTrackConfig,
# whose other caller (addVCF's per-sample ebi_VCF tracks) has no Variant records and would
# get a popup linking to a 404.

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    # Diamonds for substitutions, boxes for indels; colour by most severe predicted effect.
    # Both need a per-feature decision, so both are functions from functions.conf.
    $self->setGlyph("{variantGlyphFxn}");
    $self->setColor("{variantEffectColorFxn}");

    $self->setTrackTypeDisplay("Merged VCF");

    return $self;
}

sub getJBrowseObject {
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();

    # Store-level fetch ceilings, not allocations: when a region needs more than this the
    # store abandons it rather than rendering. Sized for a merged multi-sample call set
    # (~800MB), far larger than the per-sample VCFs the base class defaults suit.
    $jbrowseObject->{chunkSizeLimit} = 50000000;
    $jbrowseObject->{fetchSizeLimit} = 150000000;

    # This - NOT chunkSizeLimit - is what produces "Too many features to show" when zoomed
    # out. CanvasFeatures.fillBlock refuses a block whose feature density exceeds it, and
    # the JBrowse default is 0.5 features/pixel. This call set runs about 6.8 variants/kb,
    # so in a ~1000px window a 300kb view is already ~2 features/pixel and a full 3.3Mb
    # P. falciparum chromosome ~22 - both far past 0.5. 50 clears a whole chromosome with
    # roughly 2x headroom. Deliberately not the 9999999 RNASeqJunctionTrackConfig uses:
    # that invites drawing 100k+ glyphs at genome scale.
    $jbrowseObject->{maxFeatureScreenDensity} = 50;

    # One row, no stacking: the merged call set is dense enough that "normal" spends most
    # of the track's height on layout rather than on variants. Set here rather than via a
    # setDisplayMode accessor because the base TrackConfig has none - display_mode is
    # declared independently in GffTrack and Segments, and this track's mode is fixed, not
    # a per-caller argument, so a third copy of the accessor would buy nothing.
    $jbrowseObject->{displayMode} = "compact";

    # Left-click opens the Short Variant record - Overview panel plus Predicted Effects -
    # in an iframe dialog. Both values are functions (see functions.conf): the record id
    # has to be computed from the locus because the merged VCF's ID column is ".".
    #
    # hideIframeDialogUrl suppresses the link JBrowse would otherwise add to the title bar,
    # whose href is this embed URL and whose text is the raw URL. The link users want - to
    # the full record page - is built into the title instead.
    #
    # menuTemplate is deliberately NOT set. Track config is merged onto
    # CanvasFeatures._defaultConfig with Util.deepUpdate (JBrowse/Util.js, @gmod/jbrowse
    # 1.16.x as pinned by JBrowse/package.json), which recurses into anything whose typeof
    # is 'object' - and an array is an object - so arrays merge INDEX-WISE. Supplying
    # a menuTemplate here would silently overwrite the default menu's first N entries; a
    # two-item one would destroy "View details" and "Zoom to this SNV". Leaving it alone
    # keeps the whole default right-click menu, whose "View details" already shows the raw
    # VCF fields (ANN, per-sample genotypes) - exactly the escape hatch we want.
    #
    # No application-type check is needed: TrackConfig::getConfigurationObject dispatches
    # jbrowse to this method, jbrowse2 to getJBrowse2Object and apollo/apollo3 to
    # getApolloObject, so this method is by construction the JBrowse path. The other
    # application types get no record popup, each for its own reason - getJBrowse2Object
    # builds a VariantTrack with no onClick handling, and apollo cannot build a VCF track
    # at all because Store.pm's makeUrlTemplate dies "TODO: make apollo work".
    $jbrowseObject->{onClick} = {
        action              => "iframeDialog",
        hideIframeDialogUrl => JSON::true,
        url                 => "{variantRecordUrlFxn}",
        title               => "{variantRecordTitleFxn}",
    };

    return $jbrowseObject;
}

1;
