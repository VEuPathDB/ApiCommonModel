package ApiCommonShared::Model::DataSourceWdkReferences;

use strict;
use XML::Simple;

sub new {
  my ($class, $xmlFile) = @_;

  my $self = {xml_file => $xmlFile};

  bless($self,$class);

  $self->setParsedXml();
  $self->setData();

  return $self;
}

sub getXmlFile {
  my ($self) = @_;

  return $self->{xml_file};
}


sub setParsedXml {
  my ($self) = @_;

  my $xmlFile = $self->getXmlFile();

  my $xmlString = `cat $xmlFile`;
  my $xml = new XML::Simple();
  $self->{parsed_xml} = eval{ $xml->XMLin($xmlString, SuppressEmpty => undef, KeyAttr => {dataSourceWdkReference => "wdkReference"}, ForceArray => 1) };
  die "$@\n$xmlString\nerror processing XML file $xmlFile\n" if($@);

  print Dumper $self->{parsed_xml};
}

sub getParsedXml {
  my ($self) = @_;

  return $self->{parsed_xml};
}

sub setData {
  my ($self) = @_;

  my $parsedXml = $self->getParsedXml();

  my %data;
  my %display;

  foreach my $refCat (@{$parsedXml->{dataSourceWdkReference}}) {
    my $type = $refCat->{dataSourceType};
    my $references = $refCat->{wdkReferences};
 
    foreach my $reference (@{$references}) {
      my $subType = $reference->{dataSourceSubType};
      if ($subType =~ /,/){
        my @subtypes = split(/,/,$subType);
        foreach my $element (@subtypes) {
        $data{"$type:$element"} = $reference->{wdkReference};
        $display{"$type:$element"} = $reference->{display};
        }
      } else {
        $data{"$type:$subType"} = $reference->{wdkReference};
        $display{"$type:$subType"} = $reference->{display};
      } 
    } 
  }
  $self->{data} = \%data;
  $self->{display} = \%display;
}


sub getData {
  my ($self) = @_;

  return $self->{data};
}


sub getDisplay {
  my ($self) = @_;

  return $self->{display};
}

sub getDataSourceWdkRefsByName {
  my ($self, $dataSourceType) = @_;

  my $data = $self->getData();

  return $data->{$dataSourceType} || [];
}

sub getDisplayCategoryByName {
  my ($self, $dataSourceType) = @_;

  my $data = $self->getDisplay();
  return $data->{$dataSourceType} || '';
}


1;
