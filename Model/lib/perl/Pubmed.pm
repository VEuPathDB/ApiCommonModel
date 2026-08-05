package ApiCommonModel::Model::Pubmed;

use strict;
require LWP::UserAgent;
use XML::LibXML;
use Data::Dumper;

sub new {
  my ($class, $apiKey, $pmidList) = @_;

  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;

  my $pubmedUrl = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi";
  my @formdata;
  push(@formdata, "email", "help\@eupathdb.org");
  push(@formdata, "db", "pubmed");
  push(@formdata, "id", join(',', @$pmidList));
  push(@formdata, "api_key", $apiKey);
  # NCBI intermittently returns 502s and other transient errors, so retry a few
  # times before giving up on the chunk
  my $MAXTRIES = 5;
  my $response;
  for (my $try = 1; $try <= $MAXTRIES; $try++) {
    $response = $ua->post($pubmedUrl, \@formdata);
    last if $response->is_success;

    print STDERR "NCBI request failed (attempt $try of $MAXTRIES): "
                 . $response->status_line . "\n";
    sleep($try) # increase sleep over retries.
      unless ($try == $MAXTRIES);
  }
  if (!($response->is_success)) {
    die $response->status_line;
  }

  # hand libxml2 the undecoded octets so that it honors the encoding declared in
  # the response; charset => 'none' still undoes any Content-Encoding
  my $xml = $response->decoded_content(charset => 'none');
  my $doc = XML::LibXML->load_xml(string => $xml, no_blanks => 1);

  my $self = {pmidList => $pmidList,
              xml => $xml,
	      doc => $doc
	     };

  bless($self, $class);

  $self->_indexDocSums();

  return $self;
}

# Walk the DocSum nodes once and index the values we need by PubMed ID.  Doing it
# here, rather than running an XPath search from the document root inside each
# getter, keeps the cost linear in the number of records per chunk instead of
# quadratic.
sub _indexDocSums {
  my ($self) = @_;

  my %byPmid;

  foreach my $docSum ($self->{doc}->findnodes('/eSummaryResult/DocSum')) {
    my ($idNode) = $docSum->getChildrenByTagName('Id');
    next unless $idNode;

    my $record = {node => $docSum, authors => []};

    foreach my $item ($docSum->getChildrenByTagName('Item')) {
      my $itemName = $item->getAttribute('Name');
      next unless defined $itemName;

      if ($itemName eq 'AuthorList') {
        # take every child Item, as the previous XPath did, so that entries such
        # as CollectiveName are not dropped
        push(@{$record->{authors}},
             map { $_->textContent } $item->getChildrenByTagName('Item'));
      }
      elsif ($itemName eq 'DOI' || $itemName eq 'Title' || $itemName eq 'LastAuthor') {
        $record->{$itemName} = $item->textContent;
      }
    }

    $byPmid{$idNode->textContent} = $record;
  }

  $self->{byPmid} = \%byPmid;
}

sub _getItem {
  my ($self, $pmid, $itemName) = @_;

  my $record = $self->{byPmid}->{$pmid};

  return (defined $record && defined $record->{$itemName})
    ? $record->{$itemName}
    : '';
}

sub _getAuthorList {
  my ($self, $pmid) = @_;

  my $record = $self->{byPmid}->{$pmid};

  return $record ? @{$record->{authors}} : ();
}

sub getFullRecord {
  my ($self, $pmid) = @_;

  my $record = $self->{byPmid}->{$pmid};

  return $record ? $record->{node}->toString() : '';
}

sub getDoi {
  my ($self, $pmid) = @_;

  return $self->_getItem($pmid, 'DOI');
}

sub getTitle {
  my ($self, $pmid) = @_;

  return $self->_getItem($pmid, 'Title');
}

sub getLastAuthor {
  my ($self, $pmid) = @_;

  return $self->_getItem($pmid, 'LastAuthor');
}

sub getAuthors {
  my ($self, $pmid) = @_;

  return join(', ', $self->_getAuthorList($pmid));
}

sub getFirstAuthor {
  my ($self, $pmid) = @_;

  my ($firstAuthor) = $self->_getAuthorList($pmid);

  return defined $firstAuthor ? $firstAuthor : '';
}

1;