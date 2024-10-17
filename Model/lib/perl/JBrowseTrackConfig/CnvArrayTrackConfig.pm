package ApiCommonModel::Model::JBrowseTrackConfig::CnvArrayTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::CoverageTrackConfig);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::RestStore;

sub getName {$_[0]->{name}}
sub setName {$_[0]->{name} = $_[1] }

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {$_[0]->{url_template} = $_[1]}

sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Genetic Variation");
    $datasetConfig->setSubcategory("CGH Array");

    $self->setId("SNPs by coding potential");
    $self->setLabel("SNPs by coding potential");
    $self->setName($args->{name});
    #$self->setDisplayType("JBrowse/View/Track/Wiggle/XYPlot");

    my $name = $self->getName();

    my $store;

    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::RestStore->new($args);
        $store->setQuery("cnv:ArrayJBrowse"); 
        $store->setQueryParamsHash({sample => $name});
    }
    else {
        # TODO
    }

    $self->setStore($store);

    $self->setTrackTypeDisplay("XYPlot");

    $self->setYScalePosition("left");

    $self->setDescription("Comparative Genomic Hybridization to determine regions of significant Copy Number Variation in <i>T. cruzi</i> strains with strain CL Brener as reference. Type I strains used include: Brazil, Chinata, Colombiana, M78, Montalvania, PalDa1 (clone 9), SylvioX10/4, TCC, TEDa2 (clone 4), TEP6 (clone 5). Type II-VI strains used include: Esmeraldo, M5631, Tu18 (clone 1), Tulahuen, wtCL, Y. Scores from Type I strain is shown in Green and from Type II-VI are show in Brown. Score value represents the number of strains showing CNV , with a postive score implying amplification and a negative score implying deletion with respect to CL Brener. CNV criteria: minimum log2 ratio of signal intensities (test strain/reference) +/- 0.6, minimum number of probes 5. For more details refer the following manuscript: <a href=\"http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3060142/\">Widespread, focal copy number variations (CNV) and whole chromosome aneuploidies in Trypanosoma cruzi strains revealed by array comparative genomic hybridization</a> ");
    return $self;
}

sub getJBrowseStyle {
    my $self = shift;

    my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

    $jbrowseStyle->{height} = 40;
    return $jbrowseStyle;
}

sub getJBrowseObject{
        my $self = shift;
	my $jbrowseObject = $self->SUPER::getJBrowseObject();

    my $desc = $self->getDescription();
    $jbrowseObject->{max_score} =  "3";
    $jbrowseObject->{min_score} =  "-3";
    return $jbrowseObject;

}


# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
