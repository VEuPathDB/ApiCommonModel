package ApiCommonModel::Model::JBrowseTrackConfig::NrdbProteinTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("BLAT and Blast Alignments");

    $self->setId("NRDB Protein Alignments");
    $self->setLabel("NRDB Protein Alignments");

    my $store;
    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }
    else {
        # TODO
    }

    $self->setStore($store);

    my $detailsFunction = "{positionTitle}";
    $self->setOnClickContent($detailsFunction);
#    $self->setViewDetailsContent($detailsFunction); this is set below because of the extra title

    $self->setColor("{nrdbColor}");
    $self->setBorderColor("{processedTranscriptBorderColor}");

    $self->setDisplayMode("compact");

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

    $jbrowseObject->{fmtMetaValue_Description} =  "function(){return datasetDescription(\"$methodDescription\", \"\");}";



    return $jbrowseObject;
}
# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();


	return $jbrowse2Object;
}


1;
