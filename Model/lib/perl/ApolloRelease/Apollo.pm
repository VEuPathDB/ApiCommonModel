package ApiCommonModel::Model::ApolloRelease::Apollo;

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

# Reads the live Apollo organism roster: the SEED for the release, and the only
# record of what curators actually decided.  Organisms are keyed by the abbrev
# parsed out of `directory`, never commonName -- `directory` is machine-written
# by our own update commands, commonName is editable in the Apollo GUI.

# The one place the API base is decided.  The CLI reports which source the
# roster came from, and a second copy of this default there let the report
# attribute the roster to a host it never read.
sub apiUrl {
  return $ENV{APOLLO_API_URL} || 'https://apollo-api.veupathdb.org';
}

sub loadFromApi {
  my ($class) = @_;

  my $url  = $class->apiUrl();
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

  my $decoded = $class->_decodeRoster($response->content, $url);

  # An empty roster makes every organism look new, so the commands would try to
  # re-add the entire set.
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

  return $class->normalise($class->_decodeRoster($json, $path));
}

# A 200 carrying an HTML login page or a truncated body would otherwise die with
# a bare "malformed JSON string" from inside the JSON module, naming neither the
# source nor the cause.  An unauthenticated request served a login page with a
# 200 has already happened here.
sub _decodeRoster {
  my ($class, $body, $source) = @_;

  my $decoded = eval { decode_json($body) };

  die "Apollo returned a non-JSON body from $source.\n"
    . "This is usually an HTML login or error page served with a 200 status:\n"
    . "check APOLLO_API_USER/PASS and network access to the API.\n"
    unless $decoded;

  die "Apollo response from $source was not a list of organisms.\n"
    unless ref $decoded eq 'ARRAY';

  return $decoded;
}

# The seam: takes an already-decoded document, so the normalisation rules run
# with no fixture, HTTP call or credentials.  Both loaders wrap it.
sub normalise {
  my ($class, $decoded) = @_;

  my %byAbbrev;

  foreach my $raw (@$decoded) {
    my $directory = $raw->{directory} || '';

    # Whitespace and trailing slashes in one pass, so a mixture of both is
    # fully removed.  A single stray trailing byte is not cosmetic: the tainted
    # abbrev matches no portal organism, so reconciliation reports the real
    # genome as an add and the tainted one as a prune -- the add-plus-prune case
    # this project exists to prevent.
    $directory =~ s{^\s+}{};
    $directory =~ s{[\s/]+$}{};

    my ($abbrev) = $directory =~ m{([^/]+)$};

    unless (defined $abbrev && length $abbrev) {
      warn "Apollo organism id $raw->{id} has an unparseable directory '$raw->{directory}'; skipping\n";
      next;
    }

    # Interior junk cannot be trimmed without inventing an identity, so validate
    # the shape instead.  Skipping is the safe failure: an organism absent from
    # this hash can only become an approval-gated add downstream, never a prune,
    # since prune requires presence in Apollo.
    unless ($abbrev =~ m{\A[A-Za-z0-9_.-]+\z}) {
      warn "Apollo organism id $raw->{id} has a malformed abbrev '$abbrev' "
        . "from directory '$raw->{directory}'; skipping\n";
      next;
    }

    # Corruption, not a shape we can normalise: overwriting drops one from the
    # roster, and the portal diff then generates commands for whichever came
    # last -- including discarding annotations belonging to the other.
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
