package ApiCommonModel::Model::ApolloRelease::Apollo;

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

# Reads the live prod Apollo organism roster.  This is the SEED for the
# release roster -- it is the only record of what curators actually decided.
#
# Organisms are keyed by the abbrev parsed out of `directory`, never by
# commonName: `directory` is machine-written by our own update commands,
# while commonName is editable in the Apollo GUI.

sub loadFromApi {
  my ($class) = @_;

  my $url  = $ENV{APOLLO_API_URL}  || 'https://apollo-api.veupathdb.org';
  my $user = $ENV{APOLLO_API_USER} or die "APOLLO_API_USER is not set\n";
  my $pass = $ENV{APOLLO_API_PASS} or die "APOLLO_API_PASS is not set\n";

  my $agent = LWP::UserAgent->new(timeout => 900);
  my $response = $agent->request(
    POST "$url/organism/findAllOrganisms",
    Content_Type => 'form-data',
    Content      => [username => $user, password => $pass],
  );

  die "Apollo API request failed: " . $response->status_line . "\n"
    unless $response->is_success;

  my $decoded = decode_json($response->content);

  # An empty roster would make every organism look new, and the generated
  # commands would try to re-add the entire set.  Fail instead.
  die "Apollo returned no organisms from $url.\n"
    . "Check APOLLO_API_USER/PASS, and check that you are running this on a\n"
    . "Penn host -- the API is IP-restricted.\n"
    unless @$decoded;

  return $class->normalise($decoded);
}

sub loadFromFile {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or die "Cannot read $path: $!";
  local $/;
  my $json = <$fh>;
  close $fh;

  return $class->normalise(decode_json($json));
}

# Public because it is the seam: it takes an already-decoded document, so the
# normalisation rules can be exercised without a fixture file, an HTTP call or
# API credentials.  Both loaders are thin wrappers around it.
sub normalise {
  my ($class, $decoded) = @_;

  my %byAbbrev;

  foreach my $raw (@$decoded) {
    my $directory = $raw->{directory} || '';
    $directory =~ s{/+$}{};

    my ($abbrev) = $directory =~ m{([^/]+)$};

    unless ($abbrev) {
      warn "Apollo organism id $raw->{id} has an unparseable directory '$raw->{directory}'; skipping\n";
      next;
    }

    # Two Apollo organisms sharing a directory is corruption, not a shape we
    # can normalise.  Overwriting silently would drop one of them from the
    # roster, and the diff against the portal would then generate commands
    # for whichever one happened to be last -- including deleting curated
    # annotations that belong to the other.  Refuse to guess.
    if (exists $byAbbrev{$abbrev}) {
      die "Apollo has two organisms with directory '$raw->{directory}' "
        . "(ids $byAbbrev{$abbrev}{id} and $raw->{id}).\n"
        . "Resolve this in Apollo before generating release commands.\n";
    }

    $byAbbrev{$abbrev} = {
      abbrev           => $abbrev,
      id               => $raw->{id},
      common_name      => $raw->{commonName},
      directory        => $raw->{directory},
      blatdb           => $raw->{blatdb},
      annotation_count => $raw->{annotationCount} || 0,
      public_mode      => $raw->{publicMode} ? 1 : 0,
    };
  }

  return \%byAbbrev;
}

# Apollo names an organism "<full name> [<annotation version>]".  Compare only
# the part before the bracket.
sub commonNameDisagrees {
  my ($class, $apolloOrganism, $portalName) = @_;

  my $live = $apolloOrganism->{common_name} || '';
  $live =~ s{\s*\[[^\]]*\]\s*$}{};

  return ($live eq $portalName) ? 0 : 1;
}

1;
