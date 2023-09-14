package ApiCommonModel::Model::JBrowseTrackConfig::VcfTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

sub getGlyph {$_[0]->{glyph} }
sub setGlyph {$_[0]->{glyph} = $_[1]}

sub getDisplayMode {$_[0]->{display_mode} }
sub setDisplayMode {$_[0]->{display_mode} = $_[1]}

sub getChunkSizeLimit {$_[0]->{chunk_size_limit} }
sub setChunkSizeLimit {$_[0]->{chunk_size_limit} = $_[1]}

sub getFmtMetaValueDescription {$_[0]->{fmtMetaValue_Description} }
sub setFmtMetaValueDescription {$_[0]->{fmtMetaValue_Description} = $_[1]}

sub getFmtMetaValueDataset {$_[0]->{fmtMetaValue_Dataset} }
sub setFmtMetaValueDataset {$_[0]->{fmtMetaValue_Dataset} = $_[1]}

sub getChunkSizeLimit  {$_[0]->{chunk_size_limit} }
sub setChunkSizeLimit {$_[0]->{chunk_size_limit} = $_[1]}

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {
    my($self, $urlTemplate) = @_;
    die "required urlTemplate not set" unless $urlTemplate;
    $self->{url_template} = $urlTemplate;
}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setDisplayType($args->{display_type});
    $self->setGlyph($args->{glyph});
    $self->setDisplayMode($args->{display_mode});
    $self->setFmtMetaValueDescription($args->{fmtMetaValue_Description});
    $self->setFmtMetaValueDataset($args->{fmtMetaValue_Dataset});
    $self->setTrackTypeDisplay("VCF from VectorBase");

    return $self;
}

sub getJBrowseObject{
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    my $glyph = $self->getGlyph();
    my $displayMode = $self->getDisplayMode();
    my $fmtMetaValueDescription = $self->getFmtMetaValueDescription();
    my $fmtMetaValueDataset = $self->getFmtMetaValueDataset();

    $jbrowseObject->{glyph} = $glyph if($glyph);
    $jbrowseObject->{displayMode} = $displayMode if($displayMode);
    $jbrowseObject->{fmtMetaValue_Description} = $fmtMetaValueDescription if($fmtMetaValueDescription);
    $jbrowseObject->{fmtMetaValue_Dataset} = $fmtMetaValueDataset if($fmtMetaValueDataset);

    return $jbrowseObject;
}

sub getJBrowse2Object{
    my $self = shift;

    my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


    return $jbrowse2Object;
}

1;


