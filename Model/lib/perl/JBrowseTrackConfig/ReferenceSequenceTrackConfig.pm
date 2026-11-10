package ApiCommonModel::Model::JBrowseTrackConfig::ReferenceSequenceTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::FastaStore;

sub getUrl {$_[0]->{url}}
sub setUrl {$_[0]->{url} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Reference Sequence");

    $self->setId($args->{key});
    $self->setLabel($args->{label});
    $self->setUrl($args->{relative_path_to_file});

    my $store = ApiCommonModel::Model::JBrowseTrackConfig::FastaStore->new($args);

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setDisplayType("Sequence");
        $self->setTrackTypeDisplay("Reference Sequence");
    }
    else {
        $self->setTrackType("ReferenceSequenceTrack");
        $self->setDisplayType("LinearReferenceSequenceDisplay");
    }

    $self->setStore($store);

    return $self;
}


sub getJBrowseObject {
    my $self = shift;

    my $jbrowseObject = $self->SUPER::getJBrowseObject();
    $jbrowseObject->{urlTemplate} = $self->getUrl();
    $jbrowseObject->{useAsRefSeqStore} = "true";
    $jbrowseObject->{unsafePopup} = "true";

    return $jbrowseObject;
}


# JBrowse 2 draws the reference from the assembly's own sequence track (0008).
sub getJBrowse2Object {
    return undef;
}


1;
