package ApiCommonModel::Model::JBrowseTrackConfig::VCFStore;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Store);
use strict;
use warnings;

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {
    my($self, $urlTemplate) = @_;
    die "required urlTemplate not set" unless $urlTemplate;
    $self->{url_template} = $urlTemplate;
}


sub getChunkSizeLimit  {$_[0]->{chunk_size_limit} }
sub setChunkSizeLimit {$_[0]->{chunk_size_limit} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    #$self->setUrlTemplate($args->{url_template});
    #$self->setType("JBrowse/View/Track/CanvasVariants");

    $self->setChunkSizeLimit(10000000);

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setStoreType("JBrowse/Store/SeqFeature/VCFTabix");
    }
    else {
        #die "No VCF Equivalent For JBrowse2 YET";
	$self->setStoreType("VcfTabixAdapter");
    }

    return $self;
}


1;
