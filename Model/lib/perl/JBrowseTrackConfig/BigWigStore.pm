package ApiCommonModel::Model::JBrowseTrackConfig::BigWigStore;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Store);
use strict;
use warnings;

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {$_[0]->{url_template} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setUrlTemplate($args->{url_template});

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setStoreType("JBrowse/Store/SeqFeature/BigWig");
    }
    else {
        $self->setStoreType("BigWigAdapter");
    }

    return $self;
}


1;
