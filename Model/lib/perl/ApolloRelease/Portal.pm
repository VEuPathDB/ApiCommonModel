package ApiCommonModel::Model::ApolloRelease::Portal;

use strict;
use warnings;

use JSON;
use File::Temp;
use Scalar::Util qw(looks_like_number);

# Reads the organism list produced by Model/bin/jbrowseOrganismList and
# normalises it.  Keys arrive lowercase from DBD::Pg; booleans arrive as the
# strings "1"/"0".  Everything downstream sees plain 0/1 and an `abbrev` key.
#
# TWO abbrevs come through, and they are not interchangeable.  `abbrev` is
# apidb.organism.public_abbrev -- the hash key, what the portal shows, and what
# jbrowseTracks matches on.  `internal_abbrev` is apidb.organism.abbrev, which
# the five jbrowse track producers use to find auto_generated/<abbrev>/.  They
# are the same string for all but a handful of renamed organisms (cdenJEC21 /
# cneoJEC21), which is exactly why passing the wrong one is easy and fails far
# from the mistake -- exit 2 on a missing datasetAndPresenterProps.conf, or a
# query that quietly matches nothing.

# Warnings are COLLECTED, never written to stderr.  loadFromCommand treats any
# stderr byte from its child as proof that child's output is untrustworthy, and
# a caller applying that same policy to us -- the policy this module
# demonstrates -- would read a handled, recoverable skip as a release-breaking
# error.  The caller decides whether to print these.
my @WARNINGS;

sub warnings { return @WARNINGS }

sub loadFromCommand {
  my ($class, $projectName) = @_;

  my $gusHome = $ENV{GUS_HOME} or die "GUS_HOME is not set\n";

  # A private per-run capture file.  A fixed path in /tmp lets two concurrent
  # runs truncate or interleave each other's diagnostics, and the size check
  # below is only meaningful if nothing else can write to the file.
  my $errFile = File::Temp->new(TEMPLATE => 'apolloRelease.organismList.XXXXXXXX',
                                TMPDIR   => 1,
                                SUFFIX   => '.err');

  # Shell-quoted rather than run through a list-form exec.  We need the child's
  # stdout captured AND its stderr diverted to a file we can stat afterwards,
  # which one shell redirect does and a list-form open would need dup/restore
  # gymnastics to match.  $projectName arrives from a --project CLI flag, so a
  # typo -- not merely malice -- can otherwise reach the shell as syntax.
  my $quoted = "'" . ($projectName =~ s/'/'\\''/gr) . "'";
  my $cmd = "$gusHome/bin/jbrowseOrganismList $quoted";

  my $json = `$cmd 2>'$errFile'`;

  # On the failure paths keep the capture file behind for inspection; on the
  # happy path File::Temp removes it when $errFile goes out of scope.
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

# Public because it is the seam: it takes an already-decoded document, so the
# normalisation rules can be exercised without a fixture file, a subprocess or
# a database.  Both loaders are thin wrappers around it.
sub normalise {
  my ($class, $decoded) = @_;

  @WARNINGS = ();

  my %byAbbrev;

  foreach my $raw (@{$decoded->{organisms}}) {
    my $abbrev = $raw->{organism_abbrev};

    # Keying by abbrev means a duplicate would silently discard an organism.
    # Dying matches the sibling Apollo module, and matches this module's own
    # paranoia about a malformed flag.
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

# is_reference_strain / is_annotated_genome arrive as the strings "1"/"0".
# Coerce numerically: the string "0.0" is TRUE under Perl's boolean rules but
# 0 numerically, and treating it as true would silently invert the flag.
#
# The two bad-input paths differ ON PURPOSE.  A MISSING flag is plausible
# upstream (a NULL column) and must not stop a release over one row, so it
# warns and reads as false.  A flag that is PRESENT but non-numeric means the
# query changed shape; there is no safe reading of it, so it dies.
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

# The annotation version belonging to the highest build number.  Apollo names
# an organism "<full name> [<annotation version>]", so this string is part of
# the organism's identity there.  build_number is a string and is not always
# an integer ("19.9" occurs), so compare numerically by intent.
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
