package ApiCommonModel::Model::JBrowseTrackConfig::DatasetConfig;

use strict;
use warnings;

use Data::Dumper;


sub getOrganismAbbrev {$_[0]->{organism_abbrev}}
sub setOrganismAbbrev {$_[0]->{organism_abbrev} = $_[1]}

sub getProject {$_[0]->{project}}
sub setProject {$_[0]->{project} = $_[1]}

# Some basic metadata things
sub getCategory {$_[0]->{category}}
sub setCategory {$_[0]->{category} = $_[1]}

sub getSubcategory {$_[0]->{subcategory}}
sub setSubcategory {$_[0]->{subcategory} = $_[1]}

sub getSummary {$_[0]->{summary}  || ""}
sub setSummary {$_[0]->{summary} = $_[1]}

sub getAttribution {$_[0]->{attribution}}
sub setAttribution {
    my ($self, $attribution) = @_;
    # Make attribution null if property has not been set
    return if ($attribution && $attribution eq '${shortAttribution}');
    $self->{attribution} = $attribution;
}


sub getStudyDisplayName {$_[0]->{study_display_name}}
sub setStudyDisplayName {$_[0]->{study_display_name} = $_[1]}

sub getDatasetName {$_[0]->{dataset_name}}
sub setDatasetName {$_[0]->{dataset_name} = $_[1]}

sub getDatasetPresenterId {$_[0]->{dataset_presenter_id}}
sub setDatasetPresenterId {$_[0]->{dataset_presenter_id} = $_[1]}

# this is the track description if we need one
sub getDescription {$_[0]->{description}}
sub setDescription {$_[0]->{description} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;

    $self->setCategory($args->{category});
    $self->setSubcategory($args->{subcategory});
    $self->setAttribution($args->{attribution});
    $self->setStudyDisplayName($args->{study_display_name});
    $self->setDatasetName($args->{dataset_name});
    $self->setOrganismAbbrev($args->{organism_abbrev});
    $self->setDatasetPresenterId($args->{dataset_presenter_id});
    $self->setDescription($args->{description});

    my $summary = $args->{summary};
    $summary =~ s/\n//g if $summary;
    $self->setSummary($summary) if $summary;

#    unless($self->getSubcategory()) {
#        print Dumper $args;
#        die "Error: Subcategory isn't defined\n ";
#    }
    return $self;
}

1;
