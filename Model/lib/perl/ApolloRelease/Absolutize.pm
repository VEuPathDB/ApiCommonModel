package ApiCommonModel::Model::ApolloRelease::Absolutize;

use strict;
use warnings;

# Apollo embeds JBrowse and reads its config off disk, so every URL there must
# be absolute; the jbrowse* scripts emit site-relative "/a/..." because they
# normally serve a website.  A text pass rather than a typed transformation
# because many of these live inside free text -- HTML blobs, menuTemplate URLs,
# JavaScript bodies -- that a typed accessor cannot reach, and because the typed
# apollo code path upstream is still unimplemented.
#
# Deliberately IO-FREE: strings in, strings out, the caller owns the files.
# That is what lets all of it be tested with no fixtures.  Do not add a
# rewriteFile() convenience -- it pulls disk coupling into every test.

# rewrite() and assertNoRelative() MUST share this pattern.  The assertion is
# rewrite's post-condition, so it has to validate exactly what rewrite changes;
# tightening one definition of "relative" without the other either leaves URLs
# unverified or dies on a URL no rewrite could remove, silently either way.
#
# A NEGATIVE lookbehind so that a "/a/" at the very start of the string matches
# too -- a positive one has nothing to match there and misses it.  Any word or
# path character before "/a/" means continuation, not site root:
# "$projectUrl/a/service" already carries a base, and prefixing it again would
# yield "$projectUrlhttps://...".  Protocol-relative "//a/" is left alone for
# the same reason.
my $RELATIVE = qr{(?<![^'"(=\s])/a/};

sub rewrite {
  my ($class, $text, $base) = @_;

  return $text unless defined $text;

  die "Absolutize::rewrite requires a non-empty base URL\n"
    unless defined $base && $base =~ /\S/;

  # `my (...) = @_` copies, so this trims our own scalar, not the caller's.
  $base =~ s{/+$}{};

  # Idempotency is a guarantee only for a base that cannot itself end in a
  # character the lookbehind treats as a site root -- otherwise the base's own
  # last character re-triggers the match on a second pass, and no real base
  # looks like that, so nothing would catch it.
  die "Absolutize::rewrite requires a plain absolute http(s) base URL, got '$base'\n"
    unless $base =~ m{^https?://[^\s'"(=]+$};

  $text =~ s{$RELATIVE}{$base/a/}g;

  return $text;
}

# Idempotent by construction: after a rewrite the "/a/" is preceded by the last
# character of the base, which rewrite() has validated is not a delimiter.

sub assertNoRelative {
  my ($class, $text, $label) = @_;

  return 1 unless defined $text;

  my @found;
  my $count = 0;

  while ($text =~ m{$RELATIVE}g) {
    $count++;
    push @found, substr($text, $-[0], 60) if @found < 3;
  }

  return 1 unless $count;

  # The count is the diagnosis: one straggler is a missed edge case, hundreds
  # mean the rewrite never ran on this file.  So show a few, count them all.
  my $shown = @found;
  die "$label still contains $count site-relative URL(s) after absolutization"
    . ($count > $shown ? " (first $shown shown)" : "") . ":\n"
    . join('', map { "    $_\n" } @found);
}

1;
