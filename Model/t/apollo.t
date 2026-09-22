use strict;
use warnings;
use Test::More tests => 27;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Apollo;

my $A = 'ApiCommonModel::Model::ApolloRelease::Apollo';

my $live = $A->loadFromFile("Model/t/fixtures/apollo.json");

is(ref($live), 'HASH', 'returns a hash keyed by abbrev');
is(scalar(keys %$live), 6, 'all six organisms parsed');

my $t = $live->{tgonME49};
is($t->{id}, 1484940, 'numeric id carried');
is($t->{annotation_count}, 10, 'annotation count carried');
is($t->{abbrev}, 'tgonME49', 'abbrev parsed from directory');

my $c = $live->{cneoJEC21};
# The annotation count is what makes deleting an organism expensive.
is($c->{annotation_count}, 14, 'cneoJEC21 carries its annotation count');

# commonName is curator-editable, so it is cross-checked, never matched on.
is($A->commonNameDisagrees($live->{pfal3D7}, 'Plasmodium falciparum 3D7'), 1,
   'GUI-edited common name is flagged');
is($A->commonNameDisagrees($live->{tgonME49}, 'Toxoplasma gondii ME49'), 0,
   'matching common name is not flagged');

# Not every organism carries an annotation-version bracket, and the strip is
# anchored -- so a bracket-free name must compare whole rather than raise a
# cross-check warning on every such organism, every release.
is($A->commonNameDisagrees({common_name => 'Plasmodium falciparum 3D7'},
                           'Plasmodium falciparum 3D7'), 0,
   'bracket-free common name still matches');

# publicMode arrives as a JSON boolean object, which is an object reference in
# Perl.  Pin the coercion so downstream comparisons see plain 0/1.
is($live->{tgonME49}{public_mode}, 1, 'publicMode true becomes 1');
is($live->{cglaCBS138}{public_mode}, 0, 'publicMode false becomes 0');

# A missing annotationCount must read as 0, not undef: undef warns under numeric
# comparison and compares as "no annotations" by accident anyway.
my $noCount = $A->normalise([
  {id => 1, commonName => 'X', directory => '/data/apollo_data/xxxx'},
]);
is($noCount->{xxxx}{annotation_count}, 0, 'absent annotationCount defaults to 0');

# A trailing slash on directory is the same organism, not a different one.
my $slashed = $A->normalise([
  {id => 2, commonName => 'Y', directory => '/data/apollo_data/tgonME49/'},
]);
is_deeply([keys %$slashed], ['tgonME49'], 'trailing slash on directory is stripped');

# Corruption: silently keeping the last one hides an organism from the diff and
# could generate a delete against the wrong record.
eval {
  $A->normalise([
    {id => 10, commonName => 'A', directory => '/data/apollo_data/dupe', annotationCount => 0},
    {id => 11, commonName => 'B', directory => '/data/apollo_data/dupe', annotationCount => 7},
  ]);
};
like($@, qr/two organisms with directory .*dupe.*\n?.*ids 10 and 11/s,
     'duplicate directory is a fatal error naming both ids');

# Skipped, not keyed under the empty string, which would collide across every
# such record and put a nameless entry into the roster.
my @warnings;
my $bad = do {
  local $SIG{__WARN__} = sub { push @warnings, $_[0] };
  $A->normalise([{id => 9000003, commonName => 'Z', directory => ''}]);
};
is_deeply($bad, {}, 'organism with an unparseable directory is skipped, not keyed as ""');

# The operator needs to know WHICH record is malformed, so assert the id
# appears, not the sentence around it.
is(scalar @warnings, 1, 'an unparseable directory produces exactly one warning');
like($warnings[0], qr/9000003/, 'and the warning names the offending Apollo id');

# A single stray trailing byte is not cosmetic: the tainted abbrev matches no
# portal organism, so reconciliation reports the real genome as an add and the
# tainted one as a prune -- add-plus-prune for one genome.
my $spaced = $A->normalise([
  {id => 3, commonName => 'Y', directory => '/data/apollo_data/tgonME49 '},
]);
is_deeply([keys %$spaced], ['tgonME49'], 'trailing whitespace on directory is stripped');

my $both = $A->normalise([
  {id => 4, commonName => 'Y', directory => "  /data/apollo_data/tgonME49 /\n"},
]);
is_deeply([keys %$both], ['tgonME49'], 'mixed trailing whitespace and slashes are stripped');

# Interior junk cannot be trimmed without inventing an identity.  Skipping is
# the safe failure: an absent organism can only become a gated add, never a
# prune.
my @junkWarnings;
my $junk = do {
  local $SIG{__WARN__} = sub { push @junkWarnings, $_[0] };
  $A->normalise([{id => 9000004, commonName => 'Z', directory => '/data/apollo_data/tgon ME49'}]);
};
is_deeply($junk, {}, 'an abbrev with an interior space is skipped, not admitted');
is(scalar @junkWarnings, 1, 'the malformed abbrev produces exactly one warning');
like($junkWarnings[0], qr/9000004/, 'and the warning names the offending Apollo id');

# A 200 carrying an HTML login page must report as itself, not as a bare
# "malformed JSON string" from inside the JSON module.
eval { $A->_decodeRoster('<html><body>Please log in</body></html>', 'https://apollo.example') };
like($@, qr{non-JSON body from https://apollo\.example}, 'a non-JSON body names its source');

eval { $A->_decodeRoster('{"error":"nope"}', 'https://apollo.example') };
like($@, qr/not a list of organisms/, 'a JSON object that is not a roster is rejected');

# apiUrl is the ONE place the API base is decided.  The CLI labels the report
# from it, and that label was once a second copy of the same expression, so the
# two could disagree silently -- both strings look right in isolation.
{
  local $ENV{APOLLO_API_URL};
  delete $ENV{APOLLO_API_URL};
  is($A->apiUrl(), 'https://apollo-api.veupathdb.org',
     'apiUrl defaults to prod Apollo when the environment says nothing');

  $ENV{APOLLO_API_URL} = 'https://apollo-sandbox.example';
  is($A->apiUrl(), 'https://apollo-sandbox.example',
     'and an explicit APOLLO_API_URL wins -- this is how the sandbox is reached');

  $ENV{APOLLO_API_URL} = '';
  is($A->apiUrl(), 'https://apollo-api.veupathdb.org',
     'an empty value reads as unset, not as a request for an empty base URL');
}

# A still-set $@ at exit becomes the process exit status; clear it so a passing
# run exits 0.
$@ = '';
