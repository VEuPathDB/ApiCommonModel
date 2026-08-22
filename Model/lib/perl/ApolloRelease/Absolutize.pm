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

  $text =~ s{$RELATIVE}{$base/a/}g;

  return $text;
}

# Idempotent by construction: after a rewrite the "/a/" is preceded by the last
# character of the base (a host character), which the lookbehind rejects.

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
