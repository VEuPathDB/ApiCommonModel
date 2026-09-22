package ApiCommonModel::Model::ApolloRelease::Report;

use strict;
use warnings;

# The only place a human sees what the tool intends before anything is generated
# or run.  Rendered from the reconciliation result rather than from the command
# files, because an unapproved add or prune never reaches those files at all --
# and those are exactly the ones needing to be read.
#
# Pure: data in, string out.  The CLI writes it to report.txt and stdout.
#
# LAYOUT IS THE POINT.  A real build is overwhelmingly routine updates, with a
# handful of renames that are the rows whose loss costs curated annotations.
# Everything below follows from that asymmetry: decisions first, routine bulk
# last, and the one irreversible mistake shouted rather than tabulated.

# One constant so a reword cannot apply to prunes but not to the summary.
my $ANNOTATED_PRUNE_WARNING = 'ANNOTATIONS WILL BE HIDDEN';

my @BUCKETS = qw(update add_candidate prune_candidate rename exception redundant_overlay);

my $WIDTH = 78;

# What still needs a human, separated from render() so the CLI can decide exit
# status without grepping prose.
#
# THREE of these four count PENDING decisions; `annotated_prune` does not.
# Approval gates the ACTION, not the CONSEQUENCE -- approving a prune does not
# make the annotations it hides any less hidden -- so that field counts every
# annotated prune, approved or not, matching what the text flags.  Deriving it
# from the unapproved subset was the original bug, and a quiet one: the prose
# and the field a caller reads disagreed.
sub pendingDecisions {
  my ($class, $result) = @_;

  my @allPrunes = @{$result->{prune_candidate} || []};

  my @adds   = grep { !$_->{approved} } @{$result->{add_candidate} || []};
  my @prunes = grep { !$_->{approved} } @allPrunes;

  return {
    add             => scalar @adds,
    prune           => scalar @prunes,
    total           => scalar(@adds) + scalar(@prunes),
    annotated_prune => scalar(grep { _count($_->{annotation_count}) } @allPrunes),
  };
}

sub render {
  my ($class, $result, $context) = @_;

  $context ||= {};

  my @out;

  push @out, "Apollo release reconciliation\n";
  push @out, sprintf("build %s, environment %s\n\n",
                     _or($context->{build}, '?'), _or($context->{environment}, '?'));

  # Listed even at zero: a bucket that vanishes when empty is indistinguishable
  # from one the report forgot, and "0 renames" is a fact a reader needs.
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

# Always emitted, including when nothing is pending: this is the line quoted in
# the ticket, and its absence would be ambiguous between "nothing to approve"
# and "this report predates the check".
sub _decisionBanner {
  my ($class, $result) = @_;

  my $pending = $class->pendingDecisions($result);

  my @out;

  push @out, $pending->{total}
    ? sprintf("DECISIONS REQUIRED: %d  (%d add, %d prune)\n",
              $pending->{total}, $pending->{add}, $pending->{prune})
    : "DECISIONS REQUIRED: none -- nothing is waiting on a human.\n";

  # OUTSIDE the pending branch: an approved annotated prune still hides
  # annotations, and that is the case where the release looks ready to run
  # unread.
  push @out, sprintf("  %d prune candidate(s) here would hide human annotations -- see below.\n",
                     $pending->{annotated_prune})
    if $pending->{annotated_prune};

  push @out, "  Nothing is generated for an unapproved candidate; approve it in the\n",
             "  roster overlay and re-run.\n"
    if $pending->{total};

  push @out, "\n";

  return @out;
}

# The only rows where getting it wrong loses work that cannot be regenerated.
# Both abbrevs and the preserved annotation count go on one line, so the pair
# can be read back to a curator without cross-referencing.
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

# The expensive mistake: unpublishing an organism whose annotations then stop
# being visible, unnoticed until a curator looks for their own work.  The count
# prints for every prune, the warning only for a non-zero one -- a marker on
# every line is a marker nobody reads.
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

# "No action" is on the section header because the natural reading of "in Apollo
# but not reference+annotated" is that something is broken; it is a curation
# decision made once.  The failed criterion is printed so a demoted reference
# strain is distinguishable from an unannotated one.
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

  # Reachable only if a caller passes an entry that does qualify; say so rather
  # than print an empty column reading as "no reason given".
  return 'criteria unknown' unless @failed;

  return join(', ', @failed);
}

# Not an error -- a human decision overtaken by events.  Printing it with its
# note is how the file gets tidied instead of accreting undeletable entries.
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

# LAST, and compressed to a wrapped list of abbrevs rather than one line each.
# One per line would make this bucket most of the report and push the renames
# off the first screen; omitting it cannot answer the question actually asked of
# it, which is "the count moved by three, which three?".
#
# NOT the diffing surface -- inserting one abbrev reflows every later line.
# renderTsv() is where a release-to-release diff is taken.
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

# TSV rather than JSON because the diff is taken line by line: an added organism
# is one added line, where pretty JSON is several and compact JSON is the whole
# file.  Fixed columns and sorted rows, so two runs are byte-identical and
# `diff` shows decisions rather than formatting.
#
# One column carries two meanings -- a rename's destination, an overlay line's
# directive -- rather than widening every row with mostly-empty columns.
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

# A tab or newline in a field would shift every later column, or split one
# record into two.  Common names are free text from a database, so this is
# reachable without malice.
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
