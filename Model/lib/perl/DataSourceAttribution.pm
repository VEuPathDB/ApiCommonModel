package ApiCommonShared::Model::DataSourceAttribution;

use strict;
use Data::Dumper;

sub new {
  my ($class, $resourceName, $parsedXml, $dataSourceAttributions) = @_;

  my $self = {#strings
              resourceName => $resourceName,
              displayName => $parsedXml->{displayName},
              displayCategory => $parsedXml->{displayCategory},
              summary => $parsedXml->{summary},
              protocol => $parsedXml->{protocol},
              caveat => $parsedXml->{caveat},
              acknowledgement => $parsedXml->{acknowledgement},
              releasePolicy => $parsedXml->{releasePolicy},
              description => $parsedXml->{description},
              overridingType => $parsedXml->{overridingType},
              overridingSubtype => $parsedXml->{overridingSubtype},
              ignore => $parsedXml->{ignore},

              #Array Objs
              wdkReference => $parsedXml->{wdkReference},
              contacts =>  $parsedXml->{contacts}->{contact},
              links => $parsedXml->{links}->{link}, 

              parsedXml => $parsedXml,
              dataSourceAttributions => $dataSourceAttributions,
             };

  bless($self,$class);

  return $self;
}

sub isNameRegex {
  my ($self) = @_;

  my $nameIsRegex =  $self->getNameIsRegex;

  if(lc($nameIsRegex) eq 'yes' || lc($nameIsRegex) eq 'true' ||
     lc($nameIsRegex) eq 'y' || lc($nameIsRegex) eq 't' ||
     lc($nameIsRegex) eq '1') {
    return 1;
  }
  return 0;
}


sub getNameIsRegex {
  return $_[0]->getParsedXml()->{nameIsRegEx};
}


sub dataSourceAttributions {
  my ($self) = @_;

  return $self->{dataSourceAttributions};
}

sub getParsedXml {
  my ($self) = @_;

  return $self->{parsedXml};
}

sub checkIgnore {
    my ($self) = @_;

    return $self->{ignore};
}

sub getOverridingType {
    my ($self) = @_;

    return $self->{overridingType};
}

sub getOverridingSubtype {
    my ($self) = @_;

    return $self->{overridingSubType};
}

sub getName {
    my ($self) = @_;

    return $self->{resourceName};
}

sub getDisplayName {
    my ($self) = @_;

    return $self->{displayName};
}

sub getDisplayCategory {
    my ($self) = @_;

    return $self->{displayCategory};
}

sub getContacts {
    my ($self) = @_;

    return $self->{contacts};
}

sub getProtocol {
    my ($self) = @_;

    return $self->{protocol};
}

sub getCaveat {
    my ($self) = @_;

    return $self->{caveat};
}

sub getAcknowledgement {
    my ($self) = @_;

    return $self->{acknowledgement};
}

sub getReleasePolicy {
    my ($self) = @_;

    return $self->{releasePolicy};
}

sub getSummary {
    my ($self) = @_;

    return $self->{summary};
}

sub getAssociatedLinks {
    my ($self) = @_;

    return $self->{links};
}

sub getDescription {
    my ($self) = @_;

    return $self->{description};
}

# returns reference to an array of hash references with keys:
#   pmid, doi, citation
sub getPublications {
    my ($self) = @_;

    my $parsedXml = $self->getParsedXml();

    if (!$self->{publications}) {

	my $publications = $parsedXml->{publications}->{publication};
        if  ($publications) {
	  foreach my $publication (@$publications) {
	      my $pubmedId = $publication->{pmid};
	      if ($pubmedId) {
	  	  $publication->{citation} = `pubmedIdToCitation $pubmedId`;
		  die "failed calling 'pubmedIdToCitation $pubmedId'" if $? >> 8;
	      }
	  }
        }
	$self->{publications} = $publications;
    }
    return $self->{publications};
}

# returns reference to an array of hash references with keys:
# recordClass, type, name
sub getWdkReferences {
    my ($self) = @_;

    return $self->{wdkReference};
}


1;
