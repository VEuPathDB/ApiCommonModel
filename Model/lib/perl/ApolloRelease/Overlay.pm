package ApiCommonModel::Model::ApolloRelease::Overlay;

use strict;
use warnings;

# The human decisions layered over the live Apollo roster:
#
#   add    <abbrev>   # who approved it, when, why
#   remove <abbrev>   # who approved it, when, why
#
# The reason is mandatory.  This file exists to record provenance; a line
# without it is indistinguishable from the hardcoded __DATA__ block this
# replaces, which froze two builds ago and drifted silently.
#
# parseString returns { add => {abbrev => reason}, remove => {abbrev => reason} }.
# The values are plain reason STRINGS and must stay that way: Reconcile.pm
# passes them straight into curator-facing report output, so wrapping them in
# a richer structure would print ARRAY(0x...) into a report and fail silently.
# Line numbers are therefore tracked in a private hash used only for errors.

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

  # Where each accepted entry came from, so a duplicate or a contradiction can
  # name BOTH lines.  Deliberately not part of the returned structure -- see
  # the note at the top of the file.
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

    # A repeat of the same directive would silently discard the first line's
    # reason.  This file's whole purpose is provenance, so losing one is a
    # defect, not a merge: refuse it and make the author reconcile the two.
    die "roster overlay: $abbrev already appears as '$directive' on line $lineOf{$directive}{$abbrev}; "
      . "merge the reason from line $lineNumber into that line\n"
      if exists $overlay{$directive}{$abbrev};

    $overlay{$directive}{$abbrev} = $reason;
    $lineOf{$directive}{$abbrev}  = $lineNumber;
  }

  return \%overlay;
}

# Always dies.  Names the actual defect where it is identifiable, because
# "needs a reason" is actively misleading on a line that has one and is
# missing the organism instead.
sub _explainParseFailure {
  my ($class, $lineNumber, $line) = @_;

  my $prefix = "roster overlay line $lineNumber:";

  # No '#' at all: whatever else is wrong, the missing reason is the headline,
  # since the reason is the one thing this format exists to require.
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

  # Two tokens plus a '#' is the shape the main regex accepts, so reaching
  # here means the reason itself was empty or all whitespace.
  die "$prefix every entry needs a non-empty '# reason': '$line'\n"
    if @tokens == 2;

  die "$prefix could not parse '$line' as '<directive> <abbrev> # <reason>'\n";
}

1;
