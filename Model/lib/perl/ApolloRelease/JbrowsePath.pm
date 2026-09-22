package ApiCommonModel::Model::ApolloRelease::JbrowsePath;

use strict;
use warnings;

# Apollo's JBrowse data routes move to /jbrowse-apollo so they can be served
# and versioned apart from the public site's JBrowse.  A text pass for the same
# reason as Absolutize: these URLs live inside HTML blobs, JavaScript bodies and
# menuTemplate strings that no typed accessor reaches.
#
# Deliberately IO-FREE and base-free: strings in, strings out.  Run BEFORE
# Absolutize, so the exemption below still sees un-prefixed paths.

# rewrite() and assertRenamed() MUST share this pattern -- the assertion is
# rewrite's post-condition, so it has to validate exactly what rewrite changes.
#
# The lookahead is what makes "jbrowse" a whole path segment.  It earns three
# things at once: "jbrowse_embed.conf" keeps its filename, "jbrowse-apollo" is
# not re-matched (so rewrite is idempotent by construction), and a bare
# "baseUrl=/a/service/jbrowse" at end-of-line still matches.  It also picks up
# the JavaScript-escaped "\/jbrowse\/" form for free, since a backslash is
# neither a word character nor a hyphen.
#
# /a/app/jbrowse is the PUBLIC site's JBrowse application, which is not moving:
# Apollo links out to it, and renaming it would produce dead links.  Fixed-width
# lookbehind, as Perl requires.
my $SEGMENT = qr{(?<!/a/app)/jbrowse(?![\w-])};

sub rewrite {
  my ($class, $text) = @_;

  return $text unless defined $text;

  $text =~ s{$SEGMENT}{/jbrowse-apollo}g;

  return $text;
}

sub assertRenamed {
  my ($class, $text, $label) = @_;

  return 1 unless defined $text;

  my @found;
  my $count = 0;

  while ($text =~ m{$SEGMENT}g) {
    $count++;
    push @found, substr($text, $-[0], 60) if @found < 3;
  }

  return 1 unless $count;

  # The count is the diagnosis: one straggler is a missed edge case, hundreds
  # mean the rewrite never ran on this file.  So show a few, count them all.
  my $shown = @found;
  die "$label still contains $count un-renamed /jbrowse path(s)"
    . ($count > $shown ? " (first $shown shown)" : "") . ":\n"
    . join('', map { "    $_\n" } @found);
}

1;
