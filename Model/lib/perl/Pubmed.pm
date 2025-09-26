package ApiCommonModel::Model::Pubmed;

use strict;
require LWP::UserAgent;
use XML::LibXML;
use XML::XPath;
use XML::XPath::XMLParser;
use Data::Dumper;
use Time::HiRes qw(usleep);

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
  # push(@formdata, "api_key", $apiKey);
  my $response = $ua->post($pubmedUrl, \@formdata);
  if (!($response->is_success)) {
    die $response->status_line;
  }

  # nap for a third of a second to observe NCBI's three-request-per-second limit
  usleep(333333);

  # print $response->decoded_content;

  my $xp = XML::XPath->new(xml => $response->decoded_content);

  my $self = {pmidList => $pmidList,
              xml => $response->decoded_content,
	      xp => $xp
	     };

  bless($self, $class);
  return $self;
}

sub getFullRecord {
  my ($self, $pmid) = @_;

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']";
  my $nodeset = $self->{xp}->find($searchString);

  my $node = $nodeset->get_node(1);
  return XML::XPath::XMLParser::as_string($node);
}

sub getDoi {
  my ($self, $pmid) = @_;

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item[\@Name='DOI']";
  my $nodeset = $self->{xp}->find($searchString);

#  foreach my $node ($nodeset->get_nodelist) {
#    print "in loop: " . $node->string_value . "\n";
#  }

  my $node = $nodeset->get_node(1);
  return $node ? $node->string_value : '';

}

sub getTitle {
  my ($self, $pmid) = @_;

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item[\@Name='Title']";
  my $nodeset = $self->{xp}->find($searchString);

  my $node = $nodeset->get_node(1);
  return $node ? $node->string_value : '';

}

sub getLastAuthor {
  my ($self, $pmid) = @_;

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item[\@Name='LastAuthor']";
  my $nodeset = $self->{xp}->find($searchString);

  my $node = $nodeset->get_node(1);
  return $node ? $node->string_value : '';

}

sub getAuthors {
  my ($self, $pmid) = @_;

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item[\@Name='AuthorList']/Item";
  my $nodeset = $self->{xp}->find($searchString);

  my @authors;
  foreach my $node ($nodeset->get_nodelist) {
    push(@authors, $node->string_value);
  }

  return join(', ', @authors);

}

sub getFirstAuthor {
  my ($self, $pmid) = @_;

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item[\@Name='AuthorList']/Item";
  my $nodeset = $self->{xp}->find($searchString);

  my $node = $nodeset->get_node(1);
  return $node ? $node->string_value : '';
}

1;
