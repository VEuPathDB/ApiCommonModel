package ApiCommonModel::Model::ApolloRelease::Rename;

use strict;
use warnings;

# Detects taxonomic renames: the same assembly under a new organism abbrev.
# Species taxon ID is deliberately NOT used -- it changed in every known case.
# Strain abbrev narrows the candidates; identical sequence names and lengths
# decide.
#
# Without this the tool sees one abbrev vanish and another appear, proposes a
# prune plus an add, and orphans every annotation on the old Apollo organism.
# With it the caller repoints the existing organism and keeps its curation.

# Warnings are COLLECTED, not printed.  Every path that declines to rename is
# recoverable -- the organism stays a prune candidate for a human -- and a caller
# treating stderr as failure must not read that as a broken release.
my @WARNINGS;

sub warnings { return @WARNINGS }

# name => length.  The other .fai columns are byte offsets that differ between
# two copies of one assembly purely from line wrapping, so they carry no
# identity.  Returns undef, not an empty hash, for an unopenable file so a
# caller can tell "no index" from "index of an empty assembly".
sub readFai {
  my ($class, $path) = @_;

  # sameAssembly() turns this undef into a plain 0, indistinguishable from "a
  # genuinely different assembly" -- so without the warning an environment
  # problem reads as "the genome changed" and gets a prune approved.
  open(my $fh, '<', $path) or do {
    push @WARNINGS, "$path: cannot be read ($!); treating it as no evidence of a rename";
    return undef;
  };

  my %lengths;
  while (my $line = <$fh>) {
    chomp $line;
    next unless length $line;

    my ($name, $length) = split /\t/, $line;

    # A truncated final line yields a name with no length; reading that as 0
    # would let two different assemblies compare equal on their truncated
    # tails, so refuse the whole file rather than trust part of it.
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

  # Two zero-byte indexes would otherwise match each other.  No assembly has
  # zero sequences, so treat it as no evidence rather than as a match.
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

    # "No previous index" is NOT "no rename": silently, an organism whose old
    # release directory aged out becomes a prune candidate and takes its
    # annotations with it.
    unless ($oldFai && -e $oldFai) {
      push @WARNINGS,
        "$orphan: no index from the previous release at "
        . ($oldFai || '(no path)')
        . "; cannot test for a rename. Treating as a prune candidate.";
      next;
    }

    my $strain = $strainByAbbrev->{$orphan};

    # The strain filter is an optimisation, not a correctness rule, so an
    # unparseable strain falls back to comparing every portal organism rather
    # than becoming a lost rename.  The sequence comparison is what decides.
    unless (defined $strain) {
      push @WARNINGS,
        "$orphan: no strain abbrev; comparing against all "
        . scalar(keys %$portal) . " portal organisms.";
    }

    my @candidates = grep {
      !defined($strain) || (defined($_->{strain_abbrev}) && $_->{strain_abbrev} eq $strain)
    } values %$portal;

    # Counted, not just skipped: "it differs" and "I never compared it" are
    # opposite conclusions and must not produce the same sentence below.
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
      # Never guess: picking one repoints curated annotations at the wrong
      # genome, undetectably.  A prune candidate a human judges is lesser harm.
      push @WARNINGS,
        "$orphan: matches more than one portal organism ("
        . join(', ', sort @matches)
        . "); refusing to guess. Treating as a prune candidate.";
    }
    # WHY nothing matched decides what the operator does next: "the assembly is
    # gone" invites approving a prune, "I could not open the indexes" invites
    # fixing the build.  Conflating them discards annotations over a missing
    # file, so the two cases get different sentences.
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
