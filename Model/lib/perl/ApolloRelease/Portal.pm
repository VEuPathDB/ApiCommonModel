package ApiCommonModel::Model::ApolloRelease::Portal;

use strict;
use warnings;

use JSON;
use File::Temp;
use Scalar::Util qw(looks_like_number);

# Reads and normalises the organism list from Model/bin/jbrowseOrganismList.
# Keys arrive lowercase from DBD::Pg and booleans as "1"/"0"; downstream sees
# plain 0/1 and an `abbrev` key.
#
# TWO abbrevs come through and are not interchangeable.  `abbrev` is
# public_abbrev -- the hash key, what the portal shows, what jbrowseTracks
# matches on.  `internal_abbrev` is apidb.organism.abbrev, which the track
# producers use to find auto_generated/<abbrev>/.  They are the same string for
# all but a handful of renamed organisms, so the wrong one is easy to pass and
# fails far from the mistake.

# Warnings are COLLECTED, never written to stderr: loadFromCommand treats any
# stderr byte from its child as proof of untrustworthy output, and a caller
# applying that policy here would read a recoverable skip as a broken release.
my @WARNINGS;

sub warnings { return @WARNINGS }

sub loadFromCommand {
  my ($class, $projectName) = @_;

  my $gusHome = $ENV{GUS_HOME} or die "GUS_HOME is not set\n";

  # Private per run: a fixed path lets concurrent runs interleave each other's
  # diagnostics, and the size check below needs a file nothing else writes.
  my $errFile = File::Temp->new(TEMPLATE => 'apolloRelease.organismList.XXXXXXXX',
                                TMPDIR   => 1,
                                SUFFIX   => '.err');

  # Shell-quoted rather than list-form exec: stdout must be captured AND stderr
  # diverted to a file we can stat, which one redirect does and list-form would
  # need dup/restore to match.  $projectName comes from a CLI flag, so a typo
  # can otherwise reach the shell as syntax.
  my $quoted = "'" . ($projectName =~ s/'/'\\''/gr) . "'";
  my $cmd = "$gusHome/bin/jbrowseOrganismList $quoted";

  my $json = `$cmd 2>'$errFile'`;

  # Kept for inspection on the failure paths; File::Temp removes it otherwise.
  if ($?) {
    $errFile->unlink_on_destroy(0);
    die "jbrowseOrganismList failed (exit " . ($? >> 8) . "); see $errFile\n";
  }

  my $errSize = -s "$errFile" || 0;
  if ($errSize) {
    $errFile->unlink_on_destroy(0);
    die "jbrowseOrganismList wrote $errSize bytes to stderr; refusing to trust its output.\n"
      . "See $errFile\n";
  }

  return $class->normalise(decode_json($json));
}

sub loadFromFile {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or die "Cannot read $path: $!";
  local $/;
  my $json = <$fh>;
  close $fh;

  return $class->normalise(decode_json($json));
}

# The seam: takes an already-decoded document, so the normalisation rules run
# with no fixture, subprocess or database.  Both loaders wrap it.
sub normalise {
  my ($class, $decoded) = @_;

  @WARNINGS = ();

  my %byAbbrev;

  foreach my $raw (@{$decoded->{organisms}}) {
    my $abbrev = $raw->{organism_abbrev};

    # Keying by abbrev means a duplicate would silently discard an organism.
    die "duplicate organism_abbrev '$abbrev' in the organism list\n"
      if exists $byAbbrev{$abbrev};

    $byAbbrev{$abbrev} = {
      abbrev                    => $abbrev,
      internal_abbrev           => $raw->{internal_abbrev},
      name                      => $raw->{name},
      name_for_filenames        => $raw->{name_for_filenames},
      strain_abbrev             => $raw->{strain_abbrev},
      species_taxon             => $raw->{species_ncbi_tax_id},
      is_reference              => _boolean($raw->{is_reference_strain}, $abbrev, 'is_reference_strain'),
      is_annotated              => _boolean($raw->{is_annotated_genome}, $abbrev, 'is_annotated_genome'),
      history                   => $raw->{history} || [],
      latest_annotation_version => $class->_latestAnnotationVersion($raw->{history}, $abbrev),
    };
  }

  return \%byAbbrev;
}

# Coerce numerically: "0.0" is TRUE under Perl's boolean rules but 0
# numerically, and reading it as true inverts the flag.
#
# The two bad-input paths differ ON PURPOSE.  A MISSING flag is plausible (a
# NULL column) and must not stop a release over one row, so it warns and reads
# as false.  A PRESENT non-numeric flag means the query changed shape, and there
# is no safe reading of it.
sub _boolean {
  my ($value, $abbrev, $field) = @_;

  unless (defined $value) {
    push @WARNINGS, "$abbrev: $field is missing; treating it as false";
    return 0;
  }

  die "$abbrev: expected a numeric flag for $field, got '$value'\n"
    unless looks_like_number($value);

  return $value + 0 ? 1 : 0;
}

# The annotation version at the highest build number.  Apollo names an organism
# "<full name> [<annotation version>]", so this is part of its identity there.
# build_number is a string and not always an integer, so compare numerically.
sub _latestAnnotationVersion {
  my ($class, $history, $abbrev) = @_;

  return undef unless $history && @$history;

  my $best;
  foreach my $h (@$history) {
    next unless defined $h->{annotation_version};

    unless (looks_like_number($h->{build_number})) {
      my $shown = defined $h->{build_number} ? $h->{build_number} : '(undef)';
      push @WARNINGS, "$abbrev: skipping history row with non-numeric build_number '$shown'";
      next;
    }

    $best = $h if !$best || ($h->{build_number} + 0) > ($best->{build_number} + 0);
  }

  return $best ? $best->{annotation_version} : undef;
}

sub qualifies {
  my ($class, $organism) = @_;
  return ($organism->{is_reference} && $organism->{is_annotated}) ? 1 : 0;
}

1;
