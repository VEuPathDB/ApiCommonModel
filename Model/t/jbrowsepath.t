use strict;
use warnings;
use Test::More;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::JbrowsePath;
use ApiCommonModel::Model::ApolloRelease::Absolutize;

my $J = 'ApiCommonModel::Model::ApolloRelease::JbrowsePath';
my $A = 'ApiCommonModel::Model::ApolloRelease::Absolutize';
my $BASE = 'https://veupathdb.org';

# --- the bulk: a "jbrowse" path segment moves ---

is($J->rewrite('"urlTemplate":"/a/service/jbrowse/store?data=x"'),
   '"urlTemplate":"/a/service/jbrowse-apollo/store?data=x"',
   'service store URL');

is($J->rewrite('"include":["/a/jbrowse/tracks/tgonME49/tracks.conf"]'),
   '"include":["/a/jbrowse-apollo/tracks/tgonME49/tracks.conf"]',
   'static conf path');

is($J->rewrite('urlTemplates+=json:{"url":"/a/service/jbrowse/auxiliary?data=x.bw"}'),
   'urlTemplates+=json:{"url":"/a/service/jbrowse-apollo/auxiliary?data=x.bw"}',
   'URL nested in a JSON blob inside a .conf value');

is($J->rewrite(q{href='/a/service/jbrowse/names/tgonME49'}),
   q{href='/a/service/jbrowse-apollo/names/tgonME49'},
   'URL inside an HTML blob');

# The bare service root carries no trailing slash, so the segment boundary has
# to be end-of-token, not just "/".  Real shape, apollo_gene_tracks.conf.
is($J->rewrite("baseUrl=/a/service/jbrowse\nfoo=1"),
   "baseUrl=/a/service/jbrowse-apollo\nfoo=1",
   'bare service root at end of line');

is($J->rewrite('"baseUrl":"/a/service/jbrowse"'),
   '"baseUrl":"/a/service/jbrowse-apollo"',
   'bare service root before a closing quote');

is($J->rewrite('/a/service/jbrowse'), '/a/service/jbrowse-apollo',
   'bare service root at end of string');

# --- what must NOT move ---

# The filename keeps its name; only the directory segment above it moves.
is($J->rewrite('"include":["/a/jbrowse/jbrowse_embed.conf"]'),
   '"include":["/a/jbrowse-apollo/jbrowse_embed.conf"]',
   'jbrowse_embed.conf keeps its filename while its directory moves');

is($J->rewrite('/a/jbrowse/jbrowse_embed/x'), '/a/jbrowse-apollo/jbrowse_embed/x',
   'a jbrowse_embed directory segment is left alone too');

# /a/app/jbrowse is the public site's application, which is not moving.
is($J->rewrite('var baseUrl = "/a/app/jbrowse";'),
   'var baseUrl = "/a/app/jbrowse";',
   'the public site JBrowse app link is exempt');

is($J->rewrite('"/a/app/jbrowse/index.html"'), '"/a/app/jbrowse/index.html"',
   'the exemption covers the whole app route, not just the bare form');

# The exemption is on /a/app specifically -- a different app path is not exempt.
is($J->rewrite('"/a/other/jbrowse/x"'), '"/a/other/jbrowse-apollo/x"',
   'only /a/app is exempt, not any three-segment prefix');

# --- the JavaScript regex pair, functions.conf ---

# The escaped literal needs no special case: a backslash is neither a word
# character nor a hyphen, so the segment boundary matches it.  The pair moving
# together is the point -- half-renamed, the replace() stops round-tripping.
my $js = 'var dataRootRegex = /\/jbrowse\/.+Tracks\//;' . "\n"
       . 'dataRoot = dataRoot.replace(dataRootRegex, "/jbrowse/tracks/");';
is($J->rewrite($js),
   'var dataRootRegex = /\/jbrowse-apollo\/.+Tracks\//;' . "\n"
   . 'dataRoot = dataRoot.replace(dataRootRegex, "/jbrowse-apollo/tracks/");',
   'a JS regex literal and its replacement string move together');

# --- idempotence and the post-condition ---

# "-" after the segment is what makes a second pass a no-op; assert it rather
# than reason it, since the whole rule rests on that one character class.
my $mixed = '"a":"/a/service/jbrowse/store?data=x","b":"/a/app/jbrowse",'
          . '"c":"/a/jbrowse/jbrowse_embed.conf","d":"/a/service/jbrowse"';
my $once  = $J->rewrite($mixed);
is($J->rewrite($once), $once, 'rewrite is idempotent');
ok($J->assertRenamed($once, 'trackList.json'),
   'one pass satisfies the post-condition');

eval { $J->assertRenamed('"url":"/a/service/jbrowse/store?data=x"', 'trackList.json') };
like($@, qr/trackList\.json/, 'the assertion names the offending file');
like($@, qr/1 un-renamed/,    'and counts what it found');

ok($J->assertRenamed('var baseUrl = "/a/app/jbrowse";', 'functions.conf'),
   'the assertion does not flag the exempt app link');

# The cap on shown findings is a summary, not a truncation: the COUNT is what
# separates one missed edge case from a file the rewrite never touched.
my $many = join(' ', map { qq{"/a/service/jbrowse/$_"} } 1 .. 10);
eval { $J->assertRenamed($many, 'tracks.conf') };
like($@, qr/10 un-renamed/, 'the assertion reports the total count');
like($@, qr/first 3 shown/, 'and says the listing is a sample');
my @lines = grep { /^    / } split /\n/, $@;
is(scalar @lines, 3, 'exactly three findings are listed');

ok($J->assertRenamed(undef, 'tracks.conf'), 'undef text is vacuously clean');
is($J->rewrite(undef), undef, 'undef text rewrites to undef');

# --- composition with Absolutize, as writeFile runs them ---

# Rename first: the /a/app exemption is a fixed-width lookbehind, and the two
# passes must not interfere in either direction.
my $both = $A->rewrite($J->rewrite($mixed), $BASE);
is($both,
   qq{"a":"$BASE/a/service/jbrowse-apollo/store?data=x","b":"$BASE/a/app/jbrowse",}
   . qq{"c":"$BASE/a/jbrowse-apollo/jbrowse_embed.conf","d":"$BASE/a/service/jbrowse-apollo"},
   'rename then absolutize produces both rewrites');
ok($A->assertNoRelative($both, 'trackList.json'), 'and no URL is left relative');
ok($J->assertRenamed($both, 'trackList.json'),    'and no path is left un-renamed');

# A base that itself contains the old segment must survive the rename, which is
# the reason the order is rename-then-absolutize and not the other way round.
my $odd = $A->rewrite($J->rewrite('"u":"/a/service/jbrowse/x"'), 'https://veupathdb.org/jbrowse');
is($odd, '"u":"https://veupathdb.org/jbrowse/a/service/jbrowse-apollo/x"',
   'the injected base is not itself renamed');

done_testing();
