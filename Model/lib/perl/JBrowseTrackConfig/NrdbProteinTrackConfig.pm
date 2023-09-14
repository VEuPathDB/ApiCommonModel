package ApiCommonModel::Model::JBrowseTrackConfig::NrdbProteinTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

# TODO: Set border color here in new method
sub getBorderColor {$_[0]->{border_color}}
sub setBorderColor {$_[0]->{border_color} = $_[1]}

sub getUrlTemplate {$_[0]->{url_template} }
sub setUrlTemplate {
    my($self, $urlTemplate) = @_;
    die "required urlTemplate not set" unless $urlTemplate;
    $self->{url_template} = $urlTemplate;
}

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $self->setColor($args->{color});
    $self->setBorderColor($args->{borderColor});
    $self->setCategory("Sequence Analysis");
    $self->setDisplayType("JBrowse/View/Track/CanvasFeatures");
    $self->setId("NRDB Protein Alignments");
    $self->setLabel("NRDB Protein Alignments");
    $self->setSubcategory("BLAT and Blast Alignments");
    $self->setUrlTemplate($args->{url_template});

    return $self;
}

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();
         my $methodDescription = "<p>NCBI's non redundant collection of proteins (nr) was filtered for deflines matching the Genus of this sequence.  These proteins were aligned using <a href='https://www.ebi.ac.uk/about/vertebrate-genomics/software/exonerate'>exonerate</a>. (protein to genomic sequence)</p>";
	$jbrowseObject->{onClick} = {content => "{nrdbGffDetails}", title => "----------------------------- {id} -----------------------------"};
        $jbrowseObject->{menuTemplate} = [
                            {label =>  "View Details", content => "{nrdbGffDetails}", title => "----------------------------- {id} -----------------------------",},
                            {label => "View in Genbank",title => "Genbank {name}", iconClass => "dijitIconDatabase", action => "newWindow", url => "https://www.ncbi.nlm.nih.gov/protein/{name}"}
        ];
        $jbrowseObject->{style} = {color => "{nrdbColor}", borderColor => "{processedTranscriptBorderColor}"};
        $jbrowseObject->{fmtMetaValue_Description} =  "function(){return datasetDescription(\"$methodDescription\", \"\");}";
        $jbrowseObject->{urlTemplate}= $self->getUrlTemplate();       


    return $jbrowseObject;
}
# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


	return $jbrowse2Object;
}


1;
