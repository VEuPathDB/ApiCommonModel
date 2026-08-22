package ApiCommonModel::Model::ApolloRelease::Report;

use strict;
use warnings;

# The artifact a release engineer reads, and then takes to the curation team to
# approve adds and prunes.  It is the ONLY place a human sees what the tool
# intends to do before anything is generated or run, so it is rendered from the
# reconciliation result itself rather than reconstructed later from the command
# files -- an unapproved add or prune never reaches those files at all
# (Commands::writeCommandFiles), and it is exactly those that need reading.
#
# Pure: data in, string out.  No I/O, no GUS_HOME, no database.  The CLI writes
# the return value to report.txt and to stdout.
#
# LAYOUT IS THE POINT.  A real build reconciles to roughly
#
#     update 457 | add_candidate 35 | prune_candidate 2 | rename 2
#     exception 4 | redundant_overlay ~1
#
# so 457 of the 500 rows need no reading at all, while the two renames are the
# rows whose loss costs curated annotations.  Everything below follows from
# that asymmetry: decisions first, routine bulk last, and the one irreversible
# mistake -- unpublishing an organism that holds human annotations -- shouted
# rather than tabulated.

# The marker a reader scans for, and the string the tests pin.  One constant so
# a reword cannot silently apply to prunes but not to the summary.
my $ANNOTATED_PRUNE_WARNING = 'ANNOTATIONS WILL BE HIDDEN';

my @BUCKETS = qw(update add_candidate prune_candidate rename exception redundant_overlay);

my $WIDTH = 78;

# What still needs a human.  Separated from render() because the CLI decides
# exit status and a caller should not have to grep the prose to learn whether
# the release is blocked.  Approval is the gate: an approved candidate is a
# decision already made, so it is NOT pending -- but an approved prune of an
# annotated organism is still counted as annotated work at risk, because the
# thing worth knowing there is what happens, not who agreed to it.
sub pendingDecisions {
  my ($class, $result) = @_;

  my @adds   = grep { !$_->{approved} } @{$result->{add_candidate}   || []};
  my @prunes = grep { !$_->{approved} } @{$result->{prune_candidate} || []};

  return {
    add             => scalar @adds,
    prune           => scalar @prunes,
    total           => scalar(@adds) + scalar(@prunes),
    annotated_prune => scalar(grep { _count($_->{annotation_count}) } @prunes),
  };
}

sub render {
  my ($class, $result, $context) = @_;

  $context ||= {};

  my @out;

  push @out, "Apollo release reconciliation\n";
  push @out, sprintf("build %s, environment %s\n\n",
                     _or($context->{build}, '?'), _or($context->{environment}, '?'));

  # Every bucket is listed even at zero.  A bucket that vanishes when empty
  # cannot be distinguished from a bucket the report forgot, and "0 renames" is
  # a fact a reader needs -- last release had two.
  push @out, "summary\n";
  push @out, sprintf("  %-20s %5d\n", $_, scalar @{$result->{$_} || []}) for @BUCKETS;
  push @out, "\n";

  push @out, $class->_decisionBanner($result);
  push @out, $class->_renames($result);
  push @out, $class->_prunes($result);
  push @out, $class->_adds($result);
  push @out, $class->_exceptions($result);
  push @out, $class->_redundantOverlay($result);
  push @out, $class->_updates($result);

  return join('', @out);
}

# Always emitted, including when nothing is pending.  This is the line the
# release engineer reads first and the one they quote in the ticket; rendering
# it only when there is something to say makes its absence ambiguous between
# "nothing to approve" and "this report predates the check".
sub _decisionBanner {
  my ($class, $result) = @_;

  my $pending = $class->pendingDecisions($result);

  unless ($pending->{total}) {
    return "DECISIONS REQUIRED: none -- nothing is waiting on a human.\n\n";
  }

  my @out;
  push @out, sprintf("DECISIONS REQUIRED: %d  (%d add, %d prune)\n",
                     $pending->{total}, $pending->{add}, $pending->{prune});
  push @out, sprintf("  %d of the pending prune(s) would hide human annotations -- see below.\n",
                     $pending->{annotated_prune})
    if $pending->{annotated_prune};
  push @out, "  Nothing is generated for an unapproved candidate; approve it in the\n";
  push @out, "  roster overlay and re-run.\n\n";

  return @out;
}

# Two rows among five hundred, and the only ones where getting it wrong loses
# work that cannot be regenerated.  Printed before anything else with content,
# with both abbrevs and the annotation count being preserved on one line, so
# the pair can be read back to a curator without cross-referencing.
sub _renames {
  my ($class, $result) = @_;

  my @renames = sort { $a->{from_abbrev} cmp $b->{from_abbrev} } @{$result->{rename} || []};
  return () unless @renames;

  my @out = ("renames -- the existing Apollo organism is repointed in place;\n",
             "          its id, and every annotation on it, are preserved\n");
  foreach my $r (@renames) {
    push @out, sprintf("  %-24s -> %-24s %4d annotation(s)  %s\n",
                       $r->{from_abbrev}, $r->{to_abbrev},
                       _count($r->{annotation_count}),
                       _name($r->{organism}));
  }
  push @out, "\n";

  return @out;
}

# The expensive mistake.  A prune unpublishes an organism; if that organism
# holds human annotations they stop being visible, and nobody notices until a
# curator goes looking for their own work.  The count is printed for every
# prune and the warning only for a non-zero one -- a marker on every line is a
# marker nobody reads.
sub _prunes {
  my ($class, $result) = @_;

  my @prunes = sort { $a->{abbrev} cmp $b->{abbrev} } @{$result->{prune_candidate} || []};
  return () unless @prunes;

  my @out = ("prune candidates -- gone from the portal; unpublish only, reversible.\n",
             "                    An UNAPPROVED line needs a decision.\n");
  foreach my $p (@prunes) {
    my $count = _count($p->{annotation_count});
    push @out, sprintf("  %s %-24s %4d annotation(s)  %s%s%s\n",
                       _box($p->{approved}), $p->{abbrev}, $count,
                       _or($p->{common_name}, ''),
                       _approvalNote($p),
                       $count ? "  <-- $ANNOTATED_PRUNE_WARNING" : '');
  }
  push @out, "\n";

  return @out;
}

sub _adds {
  my ($class, $result) = @_;

  my @adds = sort { $a->{abbrev} cmp $b->{abbrev} } @{$result->{add_candidate} || []};
  return () unless @adds;

  my @out = ("add candidates -- reference+annotated on the portal, absent from Apollo.\n",
             "                  An UNAPPROVED line needs a decision.\n");
  foreach my $a (@adds) {
    push @out, sprintf("  %s %-24s %s%s\n",
                       _box($a->{approved}), $a->{abbrev},
                       _name($a->{organism}), _approvalNote($a));
  }
  push @out, "\n";

  return @out;
}

# No action, and said so on the section header, because the natural reading of
# "in Apollo but not reference+annotated" is that something is broken.  It is
# not: it is a curation decision made once.  The criterion each one fails is
# printed so a reader can tell a demoted reference strain from an unannotated
# one without going back to the portal.
sub _exceptions {
  my ($class, $result) = @_;

  my @exceptions = sort { $a->{abbrev} cmp $b->{abbrev} } @{$result->{exception} || []};
  return () unless @exceptions;

  my @out = ("exceptions -- in Apollo but not reference+annotated.  NO ACTION is taken\n",
             "              or needed; these are deliberate, do not \"fix\" them.\n");
  foreach my $e (@exceptions) {
    push @out, sprintf("  %-24s %-28s %4d annotation(s)  %s\n",
                       $e->{abbrev}, _failedCriteria($e),
                       _count($e->{annotation_count}), _name($e->{organism}));
  }
  push @out, "\n";

  return @out;
}

sub _failedCriteria {
  my ($entry) = @_;

  my @failed;
  push @failed, 'not reference' unless $entry->{is_reference};
  push @failed, 'not annotated' unless $entry->{is_annotated};

  # Reachable only if a caller hands us an entry that does qualify; say so
  # rather than printing an empty column that reads as "no reason given".
  return 'criteria unknown' unless @failed;

  return join(', ', @failed);
}

# An overlay line that no longer does anything is not an error -- it is a human
# decision overtaken by events.  Printing it with its note is how the file gets
# tidied instead of accreting entries nobody dares delete.
sub _redundantOverlay {
  my ($class, $result) = @_;

  my @entries = sort { $a->{abbrev} cmp $b->{abbrev} } @{$result->{redundant_overlay} || []};
  return () unless @entries;

  my @out = ("redundant overlay entries -- these lines no longer have any effect\n",
             "                             and can be deleted from the overlay\n");
  foreach my $e (@entries) {
    push @out, sprintf("  %-24s %-8s %s%s\n",
                       $e->{abbrev}, _or($e->{directive}, '?'), _or($e->{note}, ''),
                       defined $e->{reason} && length $e->{reason}
                         ? "  (was: $e->{reason})" : '');
  }
  push @out, "\n";

  return @out;
}

# LAST, and compressed.  The judgement call in this module: 457 routine updates
# are printed, but as a wrapped list of abbrevs after every decision, not as
# 457 lines.
#
# Printing them one per line would make the update bucket ninety percent of the
# report and push the two renames off the first screen -- the exact failure the
# layout exists to avoid.  Omitting them entirely is worse than it looks: the
# question actually asked of this section is "the count moved by three since
# last build, which three?", and a bare count cannot answer it.  Wrapped, they
# cost about fifty lines at the very end, where a reader who has already found
# what they came for simply stops.
#
# The wrapped form is deliberately NOT the diffing surface -- inserting one
# abbrev reflows every later line.  renderTsv() is where a release-to-release
# diff is taken, one record per line.
sub _updates {
  my ($class, $result) = @_;

  my @updates = sort map { $_->{abbrev} } @{$result->{update} || []};
  return () unless @updates;

  my @out = (sprintf("routine updates -- %d organism(s) present in both Apollo and the\n",
                     scalar @updates),
             "                   portal; regenerated and repointed, no decision needed.\n",
             "                   Listed for diffing against the previous release only.\n");
  push @out, map { "  $_\n" } _wrap(\@updates, $WIDTH - 2);
  push @out, "\n";

  return @out;
}

sub _wrap {
  my ($items, $width) = @_;

  my @lines;
  my $line = '';
  foreach my $item (@$items) {
    my $piece = length($line) ? " $item" : $item;
    if (length($line) + length($piece) > $width) {
      push @lines, $line;
      $line = $item;
    }
    else {
      $line .= $piece;
    }
  }
  push @lines, $line if length $line;

  return @lines;
}

# The machine-readable form, for diffing one release against the next.  TSV
# rather than JSON because a diff is taken line by line: one record per line
# means an added organism is one added line, where a pretty-printed JSON object
# is several and a compact one is the whole file.  Columns are fixed and the
# rows are sorted, so two runs over the same reconciliation are byte-identical
# and `diff` shows decisions, not formatting.
#
# One column carries two meanings (a rename's destination, an overlay line's
# directive) rather than widening every row with columns that are empty for
# five of the six buckets; the header says so.
my @COLUMNS = qw(bucket abbrev to_abbrev_or_directive apollo_id
                 annotation_count approved name note);

sub renderTsv {
  my ($class, $result) = @_;

  my @out = ('#' . join("\t", @COLUMNS) . "\n");

  foreach my $bucket (@BUCKETS) {
    my @rows = map { _tsvRow($bucket, $_) } @{$result->{$bucket} || []};
    push @out, map { join("\t", map { _clean($_) } @$_) . "\n" }
               sort { $a->[1] cmp $b->[1] || $a->[2] cmp $b->[2] } @rows;
  }

  return join('', @out);
}

sub _tsvRow {
  my ($bucket, $e) = @_;

  my %row = (
    bucket                 => $bucket,
    abbrev                 => _or($e->{abbrev}, _or($e->{from_abbrev}, '')),
    to_abbrev_or_directive => _or($e->{to_abbrev}, _or($e->{directive}, '')),
    apollo_id              => _or($e->{apollo_id}, ''),
    annotation_count       => defined $e->{annotation_count} ? _count($e->{annotation_count}) : '',
    approved               => defined $e->{approved} ? ($e->{approved} ? 1 : 0) : '',
    name                   => _or($e->{common_name}, _name($e->{organism})),
    note                   => _or($e->{note}, _or($e->{reason}, '')),
  );

  $row{note} = _failedCriteria($e) if $bucket eq 'exception';

  return [map { $row{$_} } @COLUMNS];
}

# A tab or a newline reaching a TSV field would shift every later column, or
# split one record into two, in whatever reads the file.  Portal common names
# are free text from a database, so this is reachable without malice.
sub _clean {
  my ($value) = @_;
  $value = '' unless defined $value;
  $value =~ s/[\t\r\n]+/ /g;
  return $value;
}

sub _box   { return $_[0] ? '[x]' : '[ ]' }

sub _count { my ($n) = @_; return (defined $n && $n =~ /^\d+$/) ? $n + 0 : 0 }

sub _or {
  my ($value, $fallback) = @_;
  return (defined $value && length $value) ? $value : $fallback;
}

sub _name {
  my ($organism) = @_;
  return '' unless $organism;
  return _or($organism->{name}, '');
}

sub _approvalNote {
  my ($entry) = @_;
  return '' unless $entry->{approved};
  return defined $entry->{reason} && length $entry->{reason}
    ? "  (approved in overlay: $entry->{reason})"
    : '  (approved in overlay)';
}

1;
