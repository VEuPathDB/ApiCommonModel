package ApiCommonModel::Model::ApolloRelease::Reconcile;

use strict;
use warnings;

use ApiCommonModel::Model::ApolloRelease::Portal;

# Pure set logic over the three inputs.  Produces five buckets:
#
#   update          in Apollo and on the portal          -> regenerate + update
#   add_candidate   qualifies, not in Apollo             -> needs approval
#   prune_candidate in Apollo, gone from the portal      -> needs approval
#   rename          same genome under a new abbrev       -> repoint in place
#   exception       in Apollo, fails the criteria        -> no action, reported
#
# plus one report-only bucket:
#
#   redundant_overlay  an overlay line that changed nothing
#
# The roster is SEEDED FROM APOLLO.  reference+annotated only ever proposes an
# add; it never removes anything.

sub reconcile {
  my ($class, $portal, $live, $overlay, $renames) = @_;

  $renames ||= {};

  my %result = (
    update            => [],
    add_candidate     => [],
    prune_candidate   => [],
    rename            => [],
    exception         => [],
    redundant_overlay => [],
  );

  my %renameTarget = $class->_validateRenames($portal, $live, $renames);

  foreach my $abbrev (sort keys %$live) {
    my $apollo = $live->{$abbrev};

    if (exists $renames->{$abbrev}) {
      my $newAbbrev = $renames->{$abbrev};
      my $target    = $portal->{$newAbbrev};

      push @{$result{rename}}, {
        from_abbrev      => $abbrev,
        to_abbrev        => $newAbbrev,
        apollo_id        => $apollo->{id},
        annotation_count => $apollo->{annotation_count},
        organism         => $target,
        # Same reason as `update` below: a rename must not change visibility.
        public_mode      => $apollo->{public_mode},
      };
      next;
    }

    my $organism = $portal->{$abbrev};

    unless ($organism) {
      push @{$result{prune_candidate}}, {
        abbrev           => $abbrev,
        apollo_id        => $apollo->{id},
        common_name      => $apollo->{common_name},
        annotation_count => $apollo->{annotation_count},
        approved         => $overlay->{remove}{$abbrev} ? 1 : 0,
        reason           => $overlay->{remove}{$abbrev},
      };
      next;
    }

    # In Apollo but failing the criteria: a decision made once, reported so
    # nobody "fixes" it, and so a newly-demoted organism becomes visible.
    unless (ApiCommonModel::Model::ApolloRelease::Portal->qualifies($organism)) {
      push @{$result{exception}}, {
        abbrev           => $abbrev,
        apollo_id        => $apollo->{id},
        organism         => $organism,
        annotation_count => $apollo->{annotation_count},
        is_reference     => $organism->{is_reference},
        is_annotated     => $organism->{is_annotated},
      };
      next;
    }

    push @{$result{update}}, {
      abbrev      => $abbrev,
      apollo_id   => $apollo->{id},
      organism    => $organism,
      # Echoed straight back in the update command.  17 organisms are hidden
      # by curators; forcing publicMode=true would silently re-publish them.
      public_mode => $apollo->{public_mode},
    };
  }

  foreach my $abbrev (sort keys %$portal) {
    next if $live->{$abbrev};
    next if $renameTarget{$abbrev};
    next if $overlay->{remove}{$abbrev};

    my $organism = $portal->{$abbrev};
    next unless ApiCommonModel::Model::ApolloRelease::Portal->qualifies($organism)
             || $overlay->{add}{$abbrev};

    push @{$result{add_candidate}}, {
      abbrev   => $abbrev,
      organism => $organism,
      approved => $overlay->{add}{$abbrev} ? 1 : 0,
      reason   => $overlay->{add}{$abbrev},
    };
  }

  $result{redundant_overlay} =
    $class->_redundantOverlay($portal, $live, $overlay, $renames, \%renameTarget);

  $class->assertInvariants(\%result);

  return \%result;
}

# The rename map is the one input with no machine source: a human asserts that
# two abbrevs are the same genome.  Every way of quietly ignoring one of those
# assertions loses something -- so all three incoherent shapes die here, before
# any bucket is built, rather than being discovered by whoever reads the
# generated commands.
sub _validateRenames {
  my ($class, $portal, $live, $renames) = @_;

  my %renameTarget;

  foreach my $from (sort keys %$renames) {
    my $to = $renames->{$from};

    die "rename target for $from is empty\n"
      unless defined $to && length $to;

    # A source that is not in Apollo has nothing to repoint.  Dropping it
    # silently is worse than it sounds: the target abbrev is still treated as
    # "spoken for" and so is skipped by the add loop, leaving the organism
    # neither renamed into nor added -- it simply disappears from the release.
    die "rename source $from is not in Apollo; nothing to rename\n"
      unless $live->{$from};

    # Renaming onto an abbrev the portal does not know produces an Apollo
    # organism pointing at a directory that will never be built.
    die "rename target $to is not on the portal\n"
      unless $portal->{$to};

    # Two organisms repointed at one directory: Apollo would then hold two
    # organisms sharing a directory, which the Apollo loader refuses to read
    # at all on the next run.  Catch it while it is still a text file.
    die "two organisms renamed to $to ($renameTarget{$to} and $from)\n"
      if exists $renameTarget{$to};

    # An abbrev that is both a rename source and a rename target means the map
    # describes a chain; there is no defensible order to apply it in.
    die "$to is both a rename source and a rename target\n"
      if exists $renames->{$to};

    # Repointing onto an abbrev Apollo already holds is a merge, not a rename:
    # it would leave two Apollo organisms sharing one directory -- the same
    # corruption the two-sources check above prevents, reached from the other
    # side.  Whichever curation set loses the coin toss is orphaned.
    die "rename target $to is already in Apollo; that is a merge, not a rename\n"
      if $live->{$to};

    $renameTarget{$to} = $from;
  }

  return %renameTarget;
}

# An overlay line that changes nothing is not an error -- an organism approved
# last release is legitimately still listed -- but it is a recorded human
# decision the tool did nothing with, so it is reported rather than swallowed.
#
# The rename map has to be consulted here, not just $live and $portal: a rename
# consumes BOTH abbrevs of the pair, so it silently disarms an overlay line
# naming either end.  Neither is visible in any other bucket -- the add loop
# skips a rename target outright, and a rename source never becomes a prune
# candidate, so its `approved` flag is never read.
#
# Only true no-ops qualify.  A `remove` naming an organism that is on the portal
# but not in Apollo really does suppress an add, so it is NOT redundant.
sub _redundantOverlay {
  my ($class, $portal, $live, $overlay, $renames, $renameTarget) = @_;

  my @redundant;

  foreach my $abbrev (sort keys %{$overlay->{add}}) {
    my $note = $live->{$abbrev}          ? 'already in Apollo'
             : $renameTarget->{$abbrev}  ? "already arriving as a rename from $renameTarget->{$abbrev}"
             : !$portal->{$abbrev}       ? 'not on the portal'
             :                             undef;
    next unless $note;

    push @redundant, {
      abbrev    => $abbrev,
      directive => 'add',
      reason    => $overlay->{add}{$abbrev},
      note      => $note,
    };
  }

  foreach my $abbrev (sort keys %{$overlay->{remove}}) {
    my $note = $renames->{$abbrev}
                 ? "being renamed to $renames->{$abbrev}, not pruned"
             : (!$live->{$abbrev} && !$portal->{$abbrev})
                 ? 'in neither Apollo nor the portal'
             :     undef;
    next unless $note;

    push @redundant, {
      abbrev    => $abbrev,
      directive => 'remove',
      reason    => $overlay->{remove}{$abbrev},
      note      => $note,
    };
  }

  return \@redundant;
}

# An add plus a prune for the same genome creates a new Apollo organism with no
# annotations and orphans the one holding the curation work -- from the same
# inputs and the same API as the correct behaviour.  This is the failure mode
# that must never ship.
#
# reconcile() as written cannot reach either state: the add loop skips every
# rename target, and a live organism named as a rename source takes the rename
# branch and never falls through to prune.  So this is not a guard on today's
# control flow -- it is a guard on tomorrow's.  Both of those skips are one
# `next` each, in loops that will grow conditions, and the bug they prevent is
# invisible in the output (an add and a prune both look correct in isolation).
# It is a public class method so it can be, and is, tested at its own seam, and
# so a caller assembling a result by other means can assert on it.
sub assertInvariants {
  my ($class, $result) = @_;

  my %renamedFrom = map { $_->{from_abbrev} => 1 } @{$result->{rename}};
  my %renamedTo   = map { $_->{to_abbrev}   => 1 } @{$result->{rename}};

  foreach my $add (@{$result->{add_candidate}}) {
    die "INVARIANT VIOLATED: $add->{abbrev} is both a rename target and an add candidate\n"
      if $renamedTo{$add->{abbrev}};
  }

  foreach my $prune (@{$result->{prune_candidate}}) {
    die "INVARIANT VIOLATED: $prune->{abbrev} is both a rename source and a prune candidate\n"
      if $renamedFrom{$prune->{abbrev}};
  }

  return 1;
}

1;
