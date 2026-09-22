package ApiCommonModel::Model::ApolloRelease::Overlay;

use strict;
use warnings;

# The human decisions layered over the live Apollo roster:
#
#   add    <abbrev>   # who approved it, when, why
#   remove <abbrev>   # who approved it, when, why
#
# The reason is mandatory: this file exists to record provenance, and a line
# without one is indistinguishable from the frozen hardcoded block it replaces.
#
# parseString returns { add => {abbrev => reason}, remove => {abbrev => reason} }.
# The values must stay plain STRINGS -- Reconcile.pm passes them into
# curator-facing report output, so a richer structure would print ARRAY(0x...)
# into a report and fail silently.  Line numbers live in a private hash.

sub parseFile {
  my ($class, $path) = @_;

  open(my $fh, '<:encoding(UTF-8)', $path)
    or die "Cannot read roster overlay $path: $!\n";
  local $/;
  my $text = <$fh>;
  close $fh;

  return $class->parseString($text);
}

sub parseString {
  my ($class, $text) = @_;

  my %overlay = (add => {}, remove => {});

  # So a duplicate or contradiction can name BOTH lines.  Deliberately not part
  # of the returned structure -- see the note at the top of the file.
  my %lineOf;

  my $lineNumber = 0;

  foreach my $line (split /\n/, $text) {
    $lineNumber++;

    next if $line =~ /^\s*$/;
    next if $line =~ /^\s*#/;

    #            (1) directive   (2) abbrev      (3) reason, to end of line
    my ($directive, $abbrev, $reason) =
      $line =~ /^\s*(\S+)\s+(\S+)\s*#\s*(\S.*?)\s*$/;

    $class->_explainParseFailure($lineNumber, $line) unless defined $directive;

    die "roster overlay line $lineNumber: unknown directive '$directive' (expected add or remove)\n"
      unless $directive eq 'add' || $directive eq 'remove';

    my $other = $directive eq 'add' ? 'remove' : 'add';

    die "roster overlay: $abbrev already appears as '$other' on line $lineOf{$other}{$abbrev}; "
      . "line $lineNumber lists it as '$directive' -- an organism cannot be both\n"
      if exists $overlay{$other}{$abbrev};

    # A repeated directive would discard the first line's reason.  Provenance is
    # the point, so that is a defect rather than a merge.
    die "roster overlay: $abbrev already appears as '$directive' on line $lineOf{$directive}{$abbrev}; "
      . "merge the reason from line $lineNumber into that line\n"
      if exists $overlay{$directive}{$abbrev};

    $overlay{$directive}{$abbrev} = $reason;
    $lineOf{$directive}{$abbrev}  = $lineNumber;
  }

  return \%overlay;
}

# Always dies, naming the actual defect: "needs a reason" is misleading on a
# line that has one and is missing the organism instead.
sub _explainParseFailure {
  my ($class, $lineNumber, $line) = @_;

  my $prefix = "roster overlay line $lineNumber:";

  # No '#' at all: the missing reason is the headline, since that is the one
  # thing this format exists to require.
  unless ($line =~ /#/) {
    my ($lone) = $line =~ /^\s*(\S+)\s*$/;
    die "$prefix missing organism and reason: '$line'\n" if $lone;
    die "$prefix every entry needs a '# reason': '$line'\n";
  }

  # There is a '#'.  Count the tokens before it to name the defect.
  my ($before) = $line =~ /^(.*?)#/;
  my @tokens = split ' ', $before;

  die "$prefix missing organism: '$line'\n"
    if @tokens == 1;

  # Two tokens plus a '#' is what the main regex accepts, so the reason itself
  # was empty or all whitespace.
  die "$prefix every entry needs a non-empty '# reason': '$line'\n"
    if @tokens == 2;

  die "$prefix could not parse '$line' as '<directive> <abbrev> # <reason>'\n";
}

1;
