package ApiCommonModel::Model::JBrowseTrackConfig::AntiSmashTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
#use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;


sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    my $datasetConfig = $self->getDatasetConfigObj();
    $datasetConfig->setCategory("Sequence Analysis");
    $datasetConfig->setSubcategory("Secondary Metabolites");

    $self->setId("Secondary Metabolites (antiSMASH)");
    $self->setLabel("antibiotics and Secondary Metabolites Analysis SHell (antiSMASH)");


    my $store;
    if($self->getApplicationType() eq 'jbrowse' || $self->getApplicationType() eq 'apollo') {
        $store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
        $self->setSubParts("CDS,UTR,five_prime_UTR,three_prime_UTR,nc_exon,pseudogenic_exon,proto_core");
        # this required to prevent fall-through to Box glyph in Segments.pm
        $self->setGlyph(undef);
    }
    else {
        # TODO
	$store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }

    $self->setStore($store);

    $self->setColor("{antismashColor}");

    return $self;
}

sub getJBrowseStyle {
   my $self = shift;
   my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

   $jbrowseStyle->{borderColor} = "black";
   $jbrowseStyle->{utrColor} = "white";
   $jbrowseStyle->{label} = "{antismashLabel}";
   # hides empty description string from popup and mouseover
   $jbrowseStyle->{description} = undef;


   return $jbrowseStyle;
}


sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();
    $jbrowseObject->{unsafePopup} = \1;
    $jbrowseObject->{transcriptType} = "function(f) { return f.children()[0].get(\"type\")}";

    # Hides the description from the body of the popup if the string is empty. 
    # Shows the description if it contains something.
    # In the JS layer, the empty string from the GFF becomes a string containing two quotes
    # Horrible escaping to handle this!
    $jbrowseObject->{fmtDetailField_description} = "function(fieldname, feature) { var value = feature.get(\"description\"); return (value === \"\\\"\\\"\" || value === null || value === undefined) ? null : fieldname; }";

    # repurpose the Type tag as a link to the gene page for gene features
    # show the Type for other types of feature
    $jbrowseObject->{fmtDetailField_Type} = "function(fieldname, feature) { if (feature.get(\"type\") !== \"gene\") { return fieldname; } return \"Gene Page\"; }";
    $jbrowseObject->{fmtDetailValue_Type} = "function(value, feature) { if (feature.get(\"type\") !== \"gene\") { return value; } var id = feature.get(\"id\"); return \"<a href='/a/app/record/gene/\" + id + \"' target='_blank'>\" + id + \"</a>\"; }";

    return $jbrowseObject;
}
# TODO:
sub getJBrowse2Object{
	my $self = shift;

	my $jbrowse2Object = $self->SUPER::getJBrowse2Object();
	my $uri = $self->getStore()->getUrlTemplate();
	my $indexLocation = $uri . "\.tbi";

    $jbrowse2Object->{adapter}->{gffGzLocation} = {uri => $uri, locationType => "UriLocation"};
    $jbrowse2Object->{adapter}->{index}->{location} = {uri => $indexLocation, locationType => "UriLocation"};
    $jbrowse2Object->{displays}->[0]->{displayId} = "gff_" . scalar($self);

	return $jbrowse2Object;
}


1;
