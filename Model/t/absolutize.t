use strict;
use warnings;
use Test::More;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Absolutize;

my $A = 'ApiCommonModel::Model::ApolloRelease::Absolutize';
my $BASE = 'https://veupathdb.org';

is($A->rewrite('"urlTemplate":"/a/service/jbrowse/store?data=x"', $BASE),
   '"urlTemplate":"https://veupathdb.org/a/service/jbrowse/store?data=x"',
   'store URL in JSON');

is($A->rewrite("<img src='/a/images/legend.png'/>", $BASE),
   "<img src='https://veupathdb.org/a/images/legend.png'/>",
   'URL inside an HTML blob');

is($A->rewrite("function(t,f) { return '/a/app/record/gene/' + f.get('name') }", $BASE),
   "function(t,f) { return 'https://veupathdb.org/a/app/record/gene/' + f.get('name') }",
   'URL inside a JavaScript function body');

is($A->rewrite('"baseUrl":"/a/service/jbrowse"', $BASE),
   '"baseUrl":"https://veupathdb.org/a/service/jbrowse"',
   'bare service base with no trailing path');

is($A->rewrite('already https://veupathdb.org/a/x', $BASE),
   'already https://veupathdb.org/a/x',
   'an already-absolute URL is not rewritten twice');

is($A->rewrite('a path like /data/a/thing', $BASE),
   'a path like /data/a/thing',
   'a mid-path /a/ that is not a site-root URL is left alone');

eval { $A->assertNoRelative('{"url":"/a/service/x"}', 'trackList.json') };
like($@, qr/trackList\.json/, 'the assertion names the offending file');

# Every character measured to precede "/a/" in the real generated config and in
# Model/lib/perl.  The lookbehind was validated against this set, not assumed.

is($A->rewrite('"url":"?data=/a/service/jbrowse/tracks/tgonME49"', $BASE),
   '"url":"?data=https://veupathdb.org/a/service/jbrowse/tracks/tgonME49"',
   'preceded by "=" -- the single most common case (91 of 118) in real config');

is($A->rewrite(q{href='/a/app/record/gene/X'}, $BASE),
   q{href='https://veupathdb.org/a/app/record/gene/X'},
   'preceded by a single quote');

is($A->rewrite('baseUrl => "/a/service/jbrowse"', $BASE),
   'baseUrl => "https://veupathdb.org/a/service/jbrowse"',
   'preceded by a double quote');

# A word character before "/a/" means it already carries an absolute base;
# rewriting would produce "$projectUrlhttps://...".  The case the lookbehind
# exists to reject.
is($A->rewrite('my $u = "$projectUrl/a/service/jbrowse/store?data=x";', $BASE),
   'my $u = "$projectUrl/a/service/jbrowse/store?data=x";',
   'an interpolated absolute base already precedes it -- left alone');

# Not seen in the config, but in the character class, so pin the intent.
is($A->rewrite("/a/service/x", $BASE),
   'https://veupathdb.org/a/service/x',
   'at the very start of the string -- a positive lookbehind would miss this');

is($A->rewrite("line one\n/a/service/x", $BASE),
   "line one\nhttps://veupathdb.org/a/service/x",
   'at the start of a line inside a multi-line blob');

is($A->rewrite('(/a/images/x.png)', $BASE),
   '(https://veupathdb.org/a/images/x.png)',
   'preceded by an open paren');

# rewrite() trims a trailing slash from $base.  @_ is aliased in Perl, so the
# worry is real -- but `my (...) = @_` copies, so the caller's is untouched.
my $caller_base = 'https://veupathdb.org/';
$A->rewrite('"/a/x"', $caller_base);
is($caller_base, 'https://veupathdb.org/',
   "rewrite does not mutate the caller's base variable through \@_ aliasing");

is($A->rewrite('"/a/x"', 'https://veupathdb.org///'), '"https://veupathdb.org/a/x"',
   'trailing slashes on the base are trimmed, not doubled');

# Idempotence: after one pass the "/a/" is preceded by the base's last
# character, which the lookbehind rejects.  Assert it rather than reason it.
my $once  = $A->rewrite('"baseUrl":"/a/service/jbrowse","img":"/a/images/x.png"', $BASE);
my $twice = $A->rewrite($once, $BASE);
is($twice, $once, 'rewrite is idempotent -- a second pass does not double-prefix');

# A URL absolute to a DIFFERENT host is left alone: the real config carries
# deliberate off-site links, and assertNoRelative is about RELATIVE URLs.
is($A->rewrite('"u":"https://other.org/a/x"', $BASE), '"u":"https://other.org/a/x"',
   'a URL absolute to a different host is left alone');
ok($A->assertNoRelative('"u":"https://other.org/a/x"', 'tracks.conf'),
   'assertNoRelative does not flag a foreign absolute host');

# Protocol-relative "//a/" already occupies the host position, so prefixing it
# would yield "//https://...".  None occur in the real config, so this is pinned
# to keep it a decision rather than an accident.
is($A->rewrite('"u":"//a/service/x"', $BASE), '"u":"//a/service/x"',
   'a protocol-relative //a/ is left alone');

# The cap on shown findings is a summary, not a truncation: the COUNT is what
# distinguishes one missed edge case from a file the rewrite never touched.
my $many = join(' ', map { qq{"/a/service/$_"} } 1 .. 10);
eval { $A->assertNoRelative($many, 'tracks.conf') };
like($@, qr/10 site-relative URL/, 'the assertion reports the total count, not just the samples');
like($@, qr/first 3 shown/,        'and says the listing is a sample');
my @lines = grep { /^    / } split /\n/, $@;
is(scalar @lines, 3, 'exactly three findings are listed');

ok($A->assertNoRelative($A->rewrite($many, $BASE), 'tracks.conf'),
   'assertNoRelative passes on text that rewrite has processed');

ok($A->assertNoRelative(undef, 'tracks.conf'), 'undef text is vacuously clean');
is($A->rewrite(undef, $BASE), undef, 'undef text rewrites to undef');

# An empty base would leave every URL still relative while reporting success.
eval { $A->rewrite('"/a/x"', '') };
like($@, qr/non-empty base/, 'an empty base is refused rather than silently no-op');

# Idempotency holds only for a base that cannot itself end in a character the
# lookbehind treats as a site root -- otherwise the base's own trailing byte
# satisfies the lookbehind and a second pass double-prefixes.  rewrite()
# enforces that rather than assuming it.
for my $bad ("https://foo.org'", 'https://foo.org"', 'https://foo.org(',
             'https://foo.org=', 'https://foo.org ') {
  eval { $A->rewrite('"/a/x"', $bad) };
  like($@, qr/plain absolute http\(s\) base URL/,
       "a base ending in a delimiter is refused: '$bad'");
}

# Not a URL at all, and a scheme we do not serve: both would produce nonsense
# that still looks like a successful rewrite.
for my $bad ('veupathdb.org', '/veupathdb', 'ftp://veupathdb.org') {
  eval { $A->rewrite('"/a/x"', $bad) };
  like($@, qr/plain absolute http\(s\) base URL/,
       "a base that is not an absolute http(s) URL is refused: '$bad'");
}

# ...and for every character a validated base MAY end in, a second pass is a
# no-op: the guarantee itself, exercised rather than reasoned.
for my $good ('https://veupathdb.org',        # letter
              'http://veupathdb.org',         # the other permitted scheme
              'https://veupathdb.org:8080',   # digit
              'https://beta-w1.veupathdb.org',# hyphen (interior) / letter
              'https://veupathdb.org/a_b',    # underscore
              'https://veupathdb.org/x~',     # tilde
              'https://veupathdb.org/x.',     # dot
              'https://veupathdb.org/x-',     # hyphen
             ) {
  my $one = $A->rewrite('"baseUrl":"/a/service","img":"/a/images/x.png"', $good);
  is($A->rewrite($one, $good), $one, "idempotent for a base ending as in '$good'");
  ok($A->assertNoRelative($one, 'tracks.conf'),
     "and one pass satisfies the post-condition for '$good'");
}

# A PARTIALLY rewritten string is the realistic shape of a half-failed rewrite,
# and the count diagnoses it.  The other count test uses identical relatives,
# which cannot show that the absolute ones are excluded from the total.
my $partial = join(' ',
  qq{"a":"$BASE/a/service/1"},
  qq{"b":"/a/service/2"},
  qq{"c":"$BASE/a/images/3.png"},
  qq{"d":"/a/service/4"},
  qq{"e":"https://other.org/a/x"},
  qq{"f":"//a/service/5"},
  qq{"g":"/data/a/thing"},
  qq{"h":"/a/service/6"},
);
eval { $A->assertNoRelative($partial, 'tracks.conf') };
like($@, qr/3 site-relative URL/,
     'a partially rewritten string counts only the STILL-relative URLs');
unlike($@, qr/first \d+ shown/,
       'and lists them all when there are no more than three');
ok($A->assertNoRelative($A->rewrite($partial, $BASE), 'tracks.conf'),
   'rewriting the partially rewritten string finishes the job');
is($A->rewrite($partial, $BASE), $A->rewrite($A->rewrite($partial, $BASE), $BASE),
   'and re-rewriting a mixed string is still idempotent');

done_testing();
