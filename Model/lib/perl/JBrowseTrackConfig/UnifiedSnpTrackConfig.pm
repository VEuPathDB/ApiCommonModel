package ApiCommonModel::Model::JBrowseTrackConfig::UnifiedSnpTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

# TODO: Set border color here in new method
#sub getBorderColor {$_[0]->{border_color}}
#sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub getBaseUrl {$_[0]->{baseUrl} }
sub setBaseUrl {
    my($self, $baseUrl) = @_;
    die "required baseUrl not set" unless $baseUrl;
    $self->{baseUrl} = $baseUrl;
}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor($args->{color});
    $self->setCategory("Genetic Variation");
    $self->setDisplayType("JBrowse/View/Track/CanvasFeatures");
    $self->setId("SNPs by coding potential");
    $self->setLabel("SNPs by coding potential");
    $self->setSubcategory("DNA polymorphism");
    $self->setBaseUrl($args->{baseUrl});

    return $self;
}

sub getJBrowseObject{
        my $self = shift;

        my $jbrowseObject = $self->SUPER::getJBrowseObject();
    my $desc ="The SNPs in this track are gathered from the high-throughput sequencing data of multiple strains and isolates. For more details on the methods used, go to the Data menu, choose Analysis Methods, and then scroll down to the Genetic Variation and SNP calling section. SNPs in this track are represented as colored diamonds, where dark blue = non-synonymous, light blue = synonymous, red = nonsense, and yellow = non-coding.";
        $jbrowseObject->{onClick} = {content => "{snpTitleFxn}",};
        $jbrowseObject->{menuTemplate} = [
                            {label =>  "View Details", content => "{snpTitleFxn}",},
        ];
        $jbrowseObject->{style} = {color => "{snpColorFxn}", strandArrow => "function(){return false}", labelScale => 1000000000000000,};
        $jbrowseObject->{baseUrl}= $self->getBaseUrl();
        $jbrowseObject->{query} = {'feature' => "SNP:Population", 'edname' => "InsertSnps.pm NGS SNPs INTERNAL"};

    return $jbrowseObject;
}

# TODO:
sub getJBrowse2Object{
        my $self = shift;

        my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


        return $jbrowse2Object;
}


1;
