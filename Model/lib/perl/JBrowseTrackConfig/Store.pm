package ApiCommonModel::Model::JBrowseTrackConfig::Store;

use strict;
use warnings;

sub getStoreType {$_[0]->{store_type}}
sub setStoreType {$_[0]->{store_type} = $_[1]}


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setStoreType($args->{store_type});

    return $self;
}

1;
