package ApiCommonModel::Model::ApolloRelease::Portal;

use strict;
use warnings;

use JSON;
use Scalar::Util qw(looks_like_number);

# Reads the organism list produced by Model/bin/jbrowseOrganismList and
# normalises it.  Keys arrive lowercase from DBD::Pg; booleans arrive as the
# strings "1"/"0".  Everything downstream sees plain 0/1 and a single
# `abbrev` key.

sub loadFromCommand {
  my ($class, $projectName) = @_;

  my $gusHome = $ENV{GUS_HOME} or die "GUS_HOME is not set\n";
  my $cmd = "$gusHome/bin/jbrowseOrganismList $projectName";

  my $json = `$cmd 2>/tmp/apolloRelease.organismList.err`;
  die "jbrowseOrganismList failed (exit " . ($? >> 8) . "); see /tmp/apolloRelease.organismList.err\n"
    if $?;

  my $errSize = -s "/tmp/apolloRelease.organismList.err" || 0;
  die "jbrowseOrganismList wrote $errSize bytes to stderr; refusing to trust its output.\n"
    . "See /tmp/apolloRelease.organismList.err\n"
    if $errSize;

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

  my %byAbbrev;

  foreach my $raw (@{$decoded->{organisms}}) {
    my $abbrev = $raw->{organism_abbrev};

    $byAbbrev{$abbrev} = {
      abbrev                    => $abbrev,
      name                      => $raw->{name},
      name_for_filenames        => $raw->{name_for_filenames},
      strain_abbrev             => $raw->{strain_abbrev},
      species_taxon             => $raw->{species_ncbi_tax_id},
      is_reference              => _boolean($raw->{is_reference_strain}),
      is_annotated              => _boolean($raw->{is_annotated_genome}),
      history                   => $raw->{history} || [],
      latest_annotation_version => $class->_latestAnnotationVersion($raw->{history}),
    };
  }

  return \%byAbbrev;
}

# is_reference_strain / is_annotated_genome arrive as the strings "1"/"0".
# Coerce numerically: the string "0.0" is TRUE under Perl's boolean rules but
# 0 numerically, and treating it as true would silently invert the flag.
# These are numeric flags in the database, so a non-numeric value means the
# upstream query changed shape -- fail rather than guess.
sub _boolean {
  my ($value) = @_;

  return 0 unless defined $value;
  die "expected a numeric flag, got '$value'\n" unless looks_like_number($value);

  return $value + 0 ? 1 : 0;
}

# The annotation version belonging to the highest build number.  Apollo names
# an organism "<full name> [<annotation version>]", so this string is part of
# the organism's identity there.  build_number is a string and is not always
# an integer ("19.9" occurs), so compare numerically by intent.
sub _latestAnnotationVersion {
  my ($class, $history) = @_;

  return undef unless $history && @$history;

  my $best;
  foreach my $h (@$history) {
    next unless defined $h->{annotation_version};

    unless (looks_like_number($h->{build_number})) {
      my $shown = defined $h->{build_number} ? $h->{build_number} : '(undef)';
      warn "skipping history row with non-numeric build_number '$shown'\n";
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
