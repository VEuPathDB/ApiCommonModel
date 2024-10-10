package ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;
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
        $self->setStoreType("JBrowse/Store/SeqFeature/GFF3Tabix");
    }
    else {
        die "No GFF Equivalent For JBrowse2 YET";
    }

    return $self;
}


1;
