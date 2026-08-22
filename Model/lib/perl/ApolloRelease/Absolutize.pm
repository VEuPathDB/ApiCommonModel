package ApiCommonModel::Model::ApolloRelease::Absolutize;

use strict;
use warnings;

# Apollo embeds JBrowse and reads its config off disk, so every URL in that
# config must be absolute.  The jbrowse* scripts emit site-relative "/a/..."
# because they normally serve a website.
#
# This is a text pass rather than a typed transformation because roughly 25 of
# these live inside free text -- HTML blobs, onClick and menuTemplate URLs, and
# JavaScript function bodies -- where a typed getApolloObject() cannot reach.
# (The applicationType=apollo code path that was supposed to handle this is
# unimplemented: Store::makeUrlTemplate is a `die "TODO"`, and 39 track classes
# implement getJBrowseObject against exactly 1 implementing getApolloObject.)
#
# The post-condition check is not optional.  The previous script did the same
# rewrite with no verification, so a missed URL became a track that silently
# 404s inside Apollo: the config loads, the track appears, and it is empty.
#
# This module is deliberately IO-FREE: it takes and returns strings, and the
# caller owns reading and writing the files.  That is what lets the whole of it
# be unit tested with no fixtures and no temp directories.  Do not add a
# rewriteFile()/rewriteDir() convenience here -- it would pull disk coupling
# back into every test that touches this logic.

# ---------------------------------------------------------------------------
# SHARED PATTERN -- rewrite() and assertNoRelative() MUST use this exact qr//.
#
# assertNoRelative is the post-condition for rewrite: it validates precisely
# what rewrite changes, no more and no less.  That equivalence is what makes
# the check meaningful, and it holds only because both read the same $RELATIVE.
# Tightening or loosening one definition of "relative" without the other breaks
# it silently and in whichever direction you chose:
#   - a pattern rewrite matches but the assertion does not  -> URLs get
#     prefixed with nothing verifying them;
#   - a pattern the assertion matches but rewrite does not  -> every release
#     dies on a "relative" URL that no rewrite could ever remove.
# Neither shows up as a test failure unless you also change the tests.  If the
# definition of a site-root URL really must change, change it HERE, once.
# ---------------------------------------------------------------------------
#
# A site-root URL is "/a/" that is NOT preceded by an ordinary path or word
# character.  Written as a NEGATIVE lookbehind rather than a positive one so
# that a "/a/" at the very start of the string also matches -- a positive
# lookbehind has nothing to match there and silently misses it.
#
# The class was not guessed; it is the measured set.  Across the generated
# config ($GUS_HOME/lib/jbrowse/{functions,jbrowse,jbrowse_embed,
# apollo_gene_tracks,tracks}.conf and auto_generated/*/tracks.conf) the only
# characters that ever precede "/a/" are:  = (91), ' (14), " (13).  Across
# Model/lib/perl the set is:  " (27), ' (7), = (1), and one `l`.
#
# That `l` is the case this pattern exists to EXCLUDE -- "$projectUrl/a/service/..."
# already carries an absolute base, and prefixing it again would produce
# "$projectUrlhttps://...".  Any word or path character before "/a/" means the
# "/a/" is a continuation, not a site root.
#
# "//a/" is therefore also left alone: it is protocol-relative, already carries
# a host position, and prefixing it would yield "//https://...".  Zero occur in
# the real config; the behaviour is pinned by test rather than left to accident.
my $RELATIVE = qr{(?<![^'"(=\s])/a/};

sub rewrite {
  my ($class, $text, $base) = @_;

  return $text unless defined $text;

  die "Absolutize::rewrite requires a non-empty base URL\n"
    unless defined $base && $base =~ /\S/;

  # @_ is aliased, but `my (...) = @_` copies, so this trims our own scalar and
  # never reaches through to the caller's variable.  Pinned by test.
  $base =~ s{/+$}{};

  # Idempotency is a GUARANTEE, not a hope -- and it is only a guarantee for a
  # base that cannot itself end in a delimiter the lookbehind treats as a site
  # root.  A base ending in one of [ ' " ( = \s ] would make its own last
  # character re-trigger the match on a second pass:
  #     rewrite('"/a/x"', "https://foo.org'")  -> "https://foo.org'/a/x"
  #     rewrite(that,     same base)           -> "https://foo.org'https://foo.org'/a/x"
  # No real base looks like that, which is exactly why nothing would catch it.
  # So constrain the base to a plain absolute http(s) URL with no delimiter
  # characters ANYWHERE in it, and the comment below is then true by
  # construction rather than true by luck.
  die "Absolutize::rewrite requires a plain absolute http(s) base URL, got '$base'\n"
    unless $base =~ m{^https?://[^\s'"(=]+$};

  $text =~ s{$RELATIVE}{$base/a/}g;

  return $text;
}

# Idempotent by construction: after a rewrite the "/a/" is preceded by the last
# character of the base, which rewrite() has validated cannot be a delimiter,
# and which the lookbehind therefore rejects.

sub assertNoRelative {
  my ($class, $text, $label) = @_;

  return 1 unless defined $text;

  my @found;
  my $count = 0;

  while ($text =~ m{$RELATIVE}g) {
    $count++;
    # Show the first few in context, but keep counting all of them.  The count
    # is the diagnosis: one straggler is a missed edge case, four hundred means
    # the rewrite never ran on this file at all.
    push @found, substr($text, $-[0], 60) if @found < 3;
  }

  return 1 unless $count;

  my $shown = @found;
  die "$label still contains $count site-relative URL(s) after absolutization"
    . ($count > $shown ? " (first $shown shown)" : "") . ":\n"
    . join('', map { "    $_\n" } @found);
}

1;
