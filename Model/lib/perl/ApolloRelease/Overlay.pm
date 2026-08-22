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

sub parseFile {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or die "Cannot read roster overlay $path: $!";
  local $/;
  my $text = <$fh>;
  close $fh;

  return $class->parseString($text);
}

sub parseString {
  my ($class, $text) = @_;

  my %overlay = (add => {}, remove => {});
  my $lineNumber = 0;

  foreach my $line (split /\n/, $text) {
    $lineNumber++;

    next if $line =~ /^\s*$/;
    next if $line =~ /^\s*#/;

    my ($directive, $abbrev, $reason) =
      $line =~ /^\s*(\S+)\s+(\S+)\s*#\s*(\S.*?)\s*$/;

    unless (defined $directive) {
      my ($lone) = $line =~ /^\s*(\S+)\s*$/;
      die "roster overlay line $lineNumber: missing organism or reason: '$line'\n"
        if $lone;
      die "roster overlay line $lineNumber: every entry needs a non-empty '# reason': '$line'\n";
    }

    die "roster overlay line $lineNumber: unknown directive '$directive' (expected add or remove)\n"
      unless $directive eq 'add' || $directive eq 'remove';

    my $other = $directive eq 'add' ? 'remove' : 'add';
    die "roster overlay line $lineNumber: $abbrev is listed as both add and remove\n"
      if exists $overlay{$other}{$abbrev};

    # A repeat of the same directive would silently discard the first line's
    # reason.  This file's whole purpose is provenance, so losing one is a
    # defect, not a merge: refuse it and make the author reconcile the two.
    die "roster overlay line $lineNumber: $abbrev is listed as '$directive' more than once; "
      . "merge the reasons into one line\n"
      if exists $overlay{$directive}{$abbrev};

    $overlay{$directive}{$abbrev} = $reason;
  }

  return \%overlay;
}

1;
