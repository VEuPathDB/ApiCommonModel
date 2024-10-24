package ApiCommonModel::Model::JBrowseTrackConfig::BamStore;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Store);
use strict;
use warnings;

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {
    my($self, $urlTemplate) = @_;
    die "required urlTemplate not set" unless $urlTemplate;
    $self->{url_template} = $urlTemplate;
}

sub getIndexUrlTemplate {$_[0]->{index_url_template} }
sub setIndexUrlTemplate {
    my($self, $urlTemplate) = @_;
    die "required urlTemplate not set" unless $urlTemplate;
    $self->{index_url_template} = $urlTemplate;
}


sub getBigwigUrl {$_[0]->{bw_relative_path_to_file}}
sub setBigwigUrl {$_[0]->{bw_relative_path_to_file} = $_[1] }
#sub setBigwigUrl {
#    my($self, $bigwigUrl) = @_;
#    die "required bigwigUrl not set" unless $bigwigUrl;
#    $self->{bw_url_template} = $bigwigUrl;
#}

sub getBigWigStoreType {$_[0]->{bw_store_type}}
sub setBigWigStoreType {$_[0]->{bw_store_type} = $_[1] }

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplate($args->{url_template});
    $self->setBigwigUrl($args->{bw_relative_path_to_file});

    my $indexLocation = $args->{url_template} . ".bai";
    $self->setIndexUrlTemplate($indexLocation);

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setStoreType("JBrowse/Store/SeqFeature/BAM");
        $self->setBigWigStoreType("JBrowse/Store/SeqFeature/BigWig");
    }
    else {
        $self->setStoreType("BamAdapter");
    }

    return $self;
}

1;
