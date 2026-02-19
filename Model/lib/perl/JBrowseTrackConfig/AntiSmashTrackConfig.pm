package ApiCommonModel::Model::JBrowseTrackConfig::AntiSmashTrackConfig;
use base qw(ApiCommonModel::Model::JBrowseTrackConfig::Segments);
#use base qw(ApiCommonModel::Model::JBrowseTrackConfig::TrackConfig);

use strict;
use warnings;

use ApiCommonModel::Model::JBrowseTrackConfig::GFFStore;

#sub getSubParts {$_[0]->{sub_parts}}
#sub setSubParts {$_[0]->{sub_parts} = $_[1]}

#sub getGeneLegend {$_[0]->{gene_legend}}
#sub setGeneLegend {$_[0]->{gene_legend} = $_[1]}

#sub getRegionLegend {$_[0]->{region_legend}}
#sub setRegionLegend {$_[0]->{region_legend} = $_[1]}

#sub getBorderColor {$_[0]->{border_color}}
#sub setBorderColor {$_[0]->{border_color} = $_[1]}

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
    }
    else {
        # TODO
	$store = ApiCommonModel::Model::JBrowseTrackConfig::GFFStore->new($args);
    }

    $self->setStore($store);

    $self->setColor("{antismashColor}");
    #$self->setSubParts("CDS,UTR,five_prime_UTR,three_prime_UTR,nc_exon,pseudogenic_exon,proto_core");
    $self->setGlyph("JBrowse/View/FeatureGlyph/Segments");

    return $self;
}

sub getJBrowseStyle {
   my $self = shift;
   my $jbrowseStyle = $self->SUPER::getJBrowseStyle();

   $jbrowseStyle->{borderColor} = "black";
   $jbrowseStyle->{utrColor} = "white";
   $jbrowseStyle->{label} = "{antismashLabel}";


   return $jbrowseStyle;
}

# sub getMetadata {
#     my $self = shift;

#     my $geneLegend = $self->getGeneLegend();
#     my $regionLegend = $self->getRegionLegend();

#     my $metadata = $self->SUPER::getMetadata();
#     $metadata->{GeneLegend} = $geneLegend if($geneLegend);
#     $metadata->{RegionLegend} = $regionLegend if($regionLegend);

#     return $metadata;
# }

sub getJBrowseObject{
	my $self = shift;

	my $jbrowseObject = $self->SUPER::getJBrowseObject();
        $jbrowseObject->{unsafePopup} = "JSON::true";
        #$jbrowseObject->{subParts} = $self->getSubParts() if($self->getSubParts());
        #$jbrowseObject->{transcriptType} = "function(f) { return f.children()[0].get(\"type\")}";


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
        #$jbrowse2Object->{adapter}->{type} = "Gff3TabixAdapter";
        $jbrowse2Object->{displays}->[0]->{displayId} = "gff_" . scalar($self);

	return $jbrowse2Object;
}


1;
