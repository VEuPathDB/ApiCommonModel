package ApiCommonModel::Model::ApolloRelease::Rename;

use strict;
use warnings;

# Detects taxonomic renames: the same assembly appearing under a new organism
# abbrev.  Species taxon ID is deliberately NOT used -- it changed in both
# known cases (cneoJEC21 5207 -> cdenJEC21 40410).
#
# Strain abbrev narrows the candidate set; identical sequence names and
# lengths decide.
#
# Getting this wrong is not a cosmetic error.  Without it the tool sees the old
# abbrev vanish from the portal and the new one appear, proposes a prune plus an
# add, and orphans every annotation attached to the old Apollo organism
# (cneoJEC21 holds 14).  With it the caller repoints the existing organism and
# keeps both its id and its curation work.

# Warnings are COLLECTED, not printed -- same policy as Portal.pm.  Every path
# through detect() that declines to rename is recoverable (the organism simply
# stays a prune candidate for a human to judge), and a caller treating stderr
# as proof of failure must not read that as a broken release.
my @WARNINGS;

sub warnings { return @WARNINGS }

# name => length.  The remaining .fai columns are byte offsets into the FASTA,
# which differ between two copies of the same assembly purely because of line
# wrapping, so they carry no identity and are discarded.
#
# Returns undef -- not an empty hash -- for a file that cannot be opened, so a
# caller can tell "no index" from "index of an empty assembly".
sub readFai {
  my ($class, $path) = @_;

  # An unopenable index -- bad permissions, a missing parent directory, a dead
  # symlink -- must not degrade silently.  sameAssembly() turns this undef into
  # a plain 0, indistinguishable from "a genuinely different assembly", so
  # without this warning an environment problem reads to the operator as "the
  # genome really did change" and gets a prune approved.
  open(my $fh, '<', $path) or do {
    push @WARNINGS, "$path: cannot be read ($!); treating it as no evidence of a rename";
    return undef;
  };

  my %lengths;
  while (my $line = <$fh>) {
    chomp $line;
    next unless length $line;

    my ($name, $length) = split /\t/, $line;

    # A truncated final line (samtools killed mid-write, a partial scp) yields
    # a name with no length.  Silently reading that as length 0 would let two
    # different assemblies compare equal on their truncated tails, so refuse
    # the whole file rather than trust part of it.
    unless (defined $name && length $name && defined $length && $length =~ /^\d+$/) {
      # Read $. before closing -- an explicit close resets it.
      my $lineNumber = $.;
      close $fh;
      push @WARNINGS, "$path: malformed line $lineNumber; refusing to trust this index";
      return undef;
    }

    $lengths{$name} = $length + 0;
  }
  close $fh;

  return \%lengths;
}

sub sameAssembly {
  my ($class, $pathA, $pathB) = @_;

  my $a = $class->readFai($pathA) or return 0;
  my $b = $class->readFai($pathB) or return 0;

  return 0 unless scalar(keys %$a) == scalar(keys %$b);

  # An empty index matches every other empty index, which would make two
  # unrelated organisms with zero-byte .fai files look like a rename.  No
  # assembly has zero sequences, so treat it as no evidence, not as a match.
  return 0 unless scalar(keys %$a);

  foreach my $name (keys %$a) {
    return 0 unless defined $b->{$name};
    return 0 unless $b->{$name} == $a->{$name};
  }

  return 1;
}

# $orphans        - arrayref of Apollo abbrevs absent from the portal
# $portal         - the portal hash from Portal.pm
# $previousFai    - coderef: abbrev            -> path to last release's .fa.fai
# $currentFai     - coderef: portal organism   -> path to this build's .fai
# $strainByAbbrev - hashref: orphan abbrev     -> its strain abbrev
sub detect {
  my ($class, $orphans, $portal, $previousFai, $currentFai, $strainByAbbrev) = @_;

  @WARNINGS = ();
  my %renames;

  foreach my $orphan (@$orphans) {
    my $oldFai = $previousFai->($orphan);

    # "No previous index" is NOT "no rename".  If this were silent, an organism
    # whose old release directory has aged out would quietly become a prune
    # candidate and take its annotations with it.  Say so and let a human look.
    unless ($oldFai && -e $oldFai) {
      push @WARNINGS,
        "$orphan: no index from the previous release at "
        . ($oldFai || '(no path)')
        . "; cannot test for a rename. Treating as a prune candidate.";
      next;
    }

    my $strain = $strainByAbbrev->{$orphan};

    # The strain filter is an optimisation over an exhaustive scan, not a
    # correctness rule -- so an orphan whose strain could not be parsed out of
    # its Apollo commonName falls back to comparing against every portal
    # organism.  Declining instead would turn an unparseable name into a lost
    # rename, and the sequence comparison is what actually decides; the filter
    # only bounds how many files get opened.
    unless (defined $strain) {
      push @WARNINGS,
        "$orphan: no strain abbrev; comparing against all "
        . scalar(keys %$portal) . " portal organisms.";
    }

    my @candidates = grep {
      !defined($strain) || (defined($_->{strain_abbrev}) && $_->{strain_abbrev} eq $strain)
    } values %$portal;

    # Counted, not just skipped.  "I compared it and it differs" and "I never
    # got to compare it" are opposite conclusions for the operator, and below
    # they must not produce the same sentence.
    my @matches;
    my $checked   = 0;
    my $uncheckable = 0;

    foreach my $candidate (@candidates) {
      next if $candidate->{abbrev} eq $orphan;

      my $newFai = $currentFai->($candidate);
      unless ($newFai && -e $newFai) {
        $uncheckable++;
        next;
      }

      $checked++;
      push @matches, $candidate->{abbrev}
        if $class->sameAssembly($oldFai, $newFai);
    }

    if (@matches == 1) {
      $renames{$orphan} = $matches[0];
    }
    elsif (@matches > 1) {
      # Never guess.  Picking one repoints curated annotations at the wrong
      # genome -- silently, and in a way nothing downstream can detect.  A
      # prune candidate a human has to judge is strictly the lesser harm.
      push @WARNINGS,
        "$orphan: matches more than one portal organism ("
        . join(', ', sort @matches)
        . "); refusing to guess. Treating as a prune candidate.";
    }
    # Nothing matched -- but WHY nothing matched decides what the operator does
    # next.  "Its assembly is gone from the portal" invites approving a prune.
    # "I could not open the indexes" invites fixing the build.  Saying the
    # first when the second is true is how curated annotations get discarded
    # over a missing file, so the two cases get different sentences.
    elsif ($checked == 0 && $uncheckable) {
      push @WARNINGS,
        "$orphan: none of its $uncheckable candidate portal organisms could be checked "
        . "(no current index for any of them). This is NOT evidence the genome changed. "
        . "Treating as a prune candidate.";
    }
    elsif ($checked == 0) {
      push @WARNINGS,
        "$orphan: no portal organism was even a candidate"
        . (defined $strain ? " for strain '$strain'" : '')
        . ". Treating as a prune candidate.";
    }
    else {
      push @WARNINGS,
        "$orphan: none of the $checked portal organisms checked shares its assembly"
        . ($uncheckable ? " ($uncheckable more had no current index and were skipped)" : '')
        . ". Treating as a prune candidate.";
    }
  }

  return \%renames;
}

1;
