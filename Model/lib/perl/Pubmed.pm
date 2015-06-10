package ApiCommonShared::Model::Pubmed;

use strict;
require LWP::UserAgent;
use XML::LibXML;
use XML::XPath;
use XML::XPath::XMLParser;use Data::Dumper;

sub new {
  my ($class, $pmidList) = @_;

  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;

  my $pubmedUrl = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi";
  my @formdata;
  push(@formdata, "email", "support\@eupathdb.org");
  push(@formdata, "tool", "pubmedTool");
  push(@formdata, "db", "pubmed");
  push(@formdata, "id", join(',', @$pmidList));
  my $response = $ua->post($pubmedUrl, \@formdata);
  if (!($response->is_success)) {
    die $response->status_line;
  }

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

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item";
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

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item";
  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item[\@Name='Title']";
  my $nodeset = $self->{xp}->find($searchString);

  my $node = $nodeset->get_node(1);
  return $node ? $node->string_value : '';

}

sub getLastAuthor {
  my ($self, $pmid) = @_;

  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item";
  my $searchString = "/eSummaryResult/DocSum[Id='$pmid']/Item[\@Name='LastAuthor']";
  my $nodeset = $self->{xp}->find($searchString);

  my $node = $nodeset->get_node(1);
  return $node ? $node->string_value : '';

}

1;
