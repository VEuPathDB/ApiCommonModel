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

# ---------------------------------------------------------------------------
# Every character MEASURED to precede "/a/" in the real generated config and in
# Model/lib/perl.  Measured frequencies:
#   generated config:  = 91,  ' 14,  " 13
#   Model/lib/perl:    " 27,  ' 7,   = 1,  l 1
# The lookbehind was validated against this set rather than assumed.
# ---------------------------------------------------------------------------

is($A->rewrite('"url":"?data=/a/service/jbrowse/tracks/tgonME49"', $BASE),
   '"url":"?data=https://veupathdb.org/a/service/jbrowse/tracks/tgonME49"',
   'preceded by "=" -- the single most common case (91 of 118) in real config');

is($A->rewrite(q{href='/a/app/record/gene/X'}, $BASE),
   q{href='https://veupathdb.org/a/app/record/gene/X'},
   'preceded by a single quote');

is($A->rewrite('baseUrl => "/a/service/jbrowse"', $BASE),
   'baseUrl => "https://veupathdb.org/a/service/jbrowse"',
   'preceded by a double quote');

# The one `l` measured in Model/lib/perl is "$projectUrl/a/service/..." -- a
# string that already carries an absolute base.  Rewriting it would produce
# "$projectUrlhttps://...".  This is the case the lookbehind exists to reject.
is($A->rewrite('my $u = "$projectUrl/a/service/jbrowse/store?data=x";', $BASE),
   'my $u = "$projectUrl/a/service/jbrowse/store?data=x";',
   'an interpolated absolute base already precedes it -- left alone');

# Not measured in the config, but in the character class, so pin the intent.
is($A->rewrite("/a/service/x", $BASE),
   'https://veupathdb.org/a/service/x',
   'at the very start of the string -- a positive lookbehind would miss this');

is($A->rewrite("line one\n/a/service/x", $BASE),
   "line one\nhttps://veupathdb.org/a/service/x",
   'at the start of a line inside a multi-line blob');

is($A->rewrite('(/a/images/x.png)', $BASE),
   '(https://veupathdb.org/a/images/x.png)',
   'preceded by an open paren');

# ---------------------------------------------------------------------------
# Step 6 questions
# ---------------------------------------------------------------------------

# rewrite() trims a trailing slash from $base.  @_ is aliased in Perl, so the
# worry is real -- but `my (...) = @_` copies, so the caller's variable is not
# touched.  Cheap to pin; expensive to discover later.
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

# A URL absolute to a DIFFERENT host is left alone.  This is right, not an
# oversight: the real config contains "https://apollo.veupathdb.org/annotator/..."
# and "https://www.ncbi.nlm.nih.gov/...", which are deliberate off-site links.
# assertNoRelative is about RELATIVE URLs, so it must not flag them either.
is($A->rewrite('"u":"https://other.org/a/x"', $BASE), '"u":"https://other.org/a/x"',
   'a URL absolute to a different host is left alone');
ok($A->assertNoRelative('"u":"https://other.org/a/x"', 'tracks.conf'),
   'assertNoRelative does not flag a foreign absolute host');

# Protocol-relative "//a/" already occupies the host position; prefixing it
# would yield "//https://...".  Zero occur in the real config -- the behaviour
# is pinned by test so it stays a decision rather than an accident.
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

done_testing();
