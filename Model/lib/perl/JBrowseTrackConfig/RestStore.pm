package ApiCommonModel::Model::JBrowseTrackConfig::RestStore;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Store);
use strict;
use warnings;


sub getBaseUrl {$_[0]->{base_url}}
sub setBaseUrl {$_[0]->{base_url} = $_[1] }

sub getQuery {$_[0]->{query}}
sub setQuery {$_[0]->{query} = $_[1] }

sub getQueryParamsHash {$_[0]->{query_params_hash}}
sub setQueryParamsHash {$_[0]->{query_params_hash} = $_[1] }



sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setBaseUrl("/a/service/jbrowse");

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $self->setStoreType("JBrowse/Store/SeqFeature/REST");
    }
    else {
        die "No REST Equivalent For JBrowse2";
    }

    return $self;
}


1;
