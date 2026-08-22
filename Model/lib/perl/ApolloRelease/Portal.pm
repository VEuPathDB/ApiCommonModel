package ApiCommonModel::Model::ApolloRelease::Portal;

use strict;
use warnings;

use JSON;

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

  return $class->_normalise(decode_json($json));
}

sub loadFromFile {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or die "Cannot read $path: $!";
  local $/;
  my $json = <$fh>;
  close $fh;

  return $class->_normalise(decode_json($json));
}

sub _normalise {
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
      is_reference              => $raw->{is_reference_strain} ? 1 : 0,
      is_annotated              => $raw->{is_annotated_genome} ? 1 : 0,
      history                   => $raw->{history} || [],
      latest_annotation_version => $class->_latestAnnotationVersion($raw->{history}),
    };
  }

  return \%byAbbrev;
}

# The annotation version belonging to the highest build number.  Apollo names
# an organism "<full name> [<annotation version>]", so this string is part of
# the organism's identity there.
sub _latestAnnotationVersion {
  my ($class, $history) = @_;

  return undef unless $history && @$history;

  my $best;
  foreach my $h (@$history) {
    next unless defined $h->{annotation_version};
    $best = $h if !$best || $h->{build_number} > $best->{build_number};
  }

  return $best ? $best->{annotation_version} : undef;
}

sub qualifies {
  my ($class, $organism) = @_;
  return ($organism->{is_reference} && $organism->{is_annotated}) ? 1 : 0;
}

1;
