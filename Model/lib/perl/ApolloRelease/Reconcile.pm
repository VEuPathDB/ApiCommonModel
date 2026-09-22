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
        # Report-only: no command is generated from an exception, so this is
        # never echoed back to Apollo.  Carried so a reader can judge the entry
        # without the report reaching into $live for one field.
        public_mode      => $apollo->{public_mode},
      };
      next;
    }

    push @{$result{update}}, {
      abbrev      => $abbrev,
      apollo_id   => $apollo->{id},
      organism    => $organism,
      # Echoed straight back in the update command: some organisms are
      # deliberately hidden, and forcing publicMode would re-publish them.
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

# The one input with no machine source: a human asserts two abbrevs are the same
# genome.  Every way of quietly ignoring such an assertion loses something, so
# the incoherent shapes die here rather than in the generated commands.
sub _validateRenames {
  my ($class, $portal, $live, $renames) = @_;

  my %renameTarget;

  foreach my $from (sort keys %$renames) {
    my $to = $renames->{$from};

    die "rename target for $from is empty\n"
      unless defined $to && length $to;

    # A source not in Apollo has nothing to repoint, and dropping it silently
    # still marks the target as spoken for -- so the add loop skips it and the
    # organism disappears from the release entirely.
    die "rename source $from is not in Apollo; nothing to rename\n"
      unless $live->{$from};

    # Renaming onto an abbrev the portal does not know produces an Apollo
    # organism pointing at a directory that will never be built.
    die "rename target $to is not on the portal\n"
      unless $portal->{$to};

    # Two organisms sharing one directory is what the Apollo loader refuses to
    # read at all next run.  Catch it while it is still a text file.
    die "two organisms renamed to $to ($renameTarget{$to} and $from)\n"
      if exists $renameTarget{$to};

    # Both a source and a target means the map describes a chain, and there is
    # no defensible order to apply it in.
    die "$to is both a rename source and a rename target\n"
      if exists $renames->{$to};

    # A merge, not a rename: the same two-organisms-one-directory corruption the
    # check above prevents, reached from the other side, and whichever curation
    # set loses is orphaned.
    die "rename target $to is already in Apollo; that is a merge, not a rename\n"
      if $live->{$to};

    $renameTarget{$to} = $from;
  }

  return %renameTarget;
}

# Not an error -- an organism approved last release is legitimately still listed
# -- but a recorded human decision the tool did nothing with, so it is reported
# rather than swallowed.
#
# The rename map is consulted here, not just $live and $portal: a rename consumes
# BOTH abbrevs, silently disarming an overlay line naming either end, and neither
# shows up in any other bucket.
#
# Only true no-ops qualify: a `remove` naming an organism on the portal but not
# in Apollo really does suppress an add.
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

# An add plus a prune for the same genome creates an empty Apollo organism and
# orphans the one holding the curation work -- from the same inputs and API as
# the correct behaviour.  The failure mode that must never ship.
#
# reconcile() as written cannot reach it, so this guards tomorrow's control flow
# rather than today's: the two skips that prevent it are one `next` each, in
# loops that will grow conditions, and the bug is invisible in the output because
# an add and a prune each look correct alone.  Public so it is tested at its own
# seam.
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
