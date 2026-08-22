use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use JSON;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Generate;

my $G = 'ApiCommonModel::Model::ApolloRelease::Generate';
my $BASE = 'https://veupathdb.org';

# ---------------------------------------------------------------------------
# localNameForInclude
# ---------------------------------------------------------------------------

is($G->localNameForInclude('/a/jbrowse/tracks/tgonME49/tracks.conf'), 'tracks.conf',
   'per-organism tracks.conf');
is($G->localNameForInclude('/a/jbrowse/functions.conf'), 'functions.conf',
   'functions.conf');
is($G->localNameForInclude('/a/jbrowse/apollo_gene_tracks.conf'), 'apollo_gene_tracks.conf',
   'apollo_gene_tracks.conf');

# rnaseqJunctions must not be swallowed by the plain rnaseq rule.  Both endpoints
# are generated for the same organism, so a rule-order slip silently writes one
# file's contents under the other's name and nothing downstream notices.
is($G->localNameForInclude('/a/service/jbrowse/rnaseqJunctions/tgonME49'),
   'rnaseqJunctions.json', 'rnaseqJunctions wins over rnaseq');
is($G->localNameForInclude('/a/service/jbrowse/rnaseq/tgonME49'), 'rnaseq.json', 'rnaseq');
is($G->localNameForInclude('/a/service/jbrowse/chipseq/tgonME49'), 'chipseq.json', 'chipseq');
is($G->localNameForInclude('/a/service/jbrowse/dnaseq/tgonME49'), 'dnaseq.json', 'dnaseq');
is($G->localNameForInclude('/a/service/jbrowse/organismSpecific/tgonME49'),
   'organismSpecific.json', 'organismSpecific');
is($G->localNameForInclude('/a/service/jbrowse/somethingNew/tgonME49'), undef,
   'an unrecognised include maps to undef rather than being guessed at');

# ---------------------------------------------------------------------------
# buildTrackList
# ---------------------------------------------------------------------------

my $trackList = {
  refSeqs => "/a/service/jbrowse/store?data=TgondiiME49/genomeAndProteome/fasta/genome.fasta.fai",
  names   => {type => "REST", url => "/a/service/jbrowse/names/tgonME49"},
  include => [
    "/a/jbrowse/tracks/tgonME49/tracks.conf",
    "/a/service/jbrowse/rnaseqJunctions/tgonME49",
    "/a/service/users/current/user-datasets-jbrowse/TgondiiME49",
    "/a/jbrowse/jbrowse_embed.conf",
    "/a/service/jbrowse/organismSpecific/tgonME49",
  ],
  tracks  => [{label => "should be replaced"}],
};

my $built = $G->buildTrackList($trackList, 'tgonME49', $BASE);

is_deeply([grep { /user-datasets/ } @{$built->{include}}], [],
          'user dataset includes are dropped');
is_deeply([grep { /jbrowse_embed/ } @{$built->{include}}], [],
          'the site embed config is dropped');
is_deeply($built->{include},
          ['tracks.conf', 'rnaseqJunctions.json', 'organismSpecific.json'],
          'includes rewritten to local filenames, in the order given');
is($built->{refSeqs}, 'seq/tgonME49.fa.fai', 'refSeqs points at the local index');
is(scalar(@{$built->{tracks}}), 1, 'exactly one track remains');
is($built->{tracks}[0]{storeClass}, 'JBrowse/Store/SeqFeature/IndexedFasta',
   'and it is the local reference sequence track');
is($built->{tracks}[0]{urlTemplate}, 'seq/tgonME49.fa', 'pointing at the local fasta');
is($built->{tracks}[0]{faiUrlTemplate}, 'seq/tgonME49.fa.fai', 'and at the local index');
like($built->{names}{url}, qr{^https://veupathdb\.org/a/}, 'names url absolutized');

# The caller owns the file set it actually produced, so it appends those names;
# buildTrackList must not invent them and must not duplicate one already mapped
# in from the skeleton.
my $withExtras = $G->buildTrackList($trackList, 'tgonME49', $BASE,
                                    ['functions.conf', 'apollo_gene_tracks.conf',
                                     'rnaseq.json', 'organismSpecific.json']);
is_deeply($withExtras->{include},
          ['tracks.conf', 'rnaseqJunctions.json', 'organismSpecific.json',
           'functions.conf', 'apollo_gene_tracks.conf', 'rnaseq.json'],
          'extra local files are appended once, never duplicated');

# The input must not be mutated -- generateAll reuses one skeleton per organism
# and a shared nested arrayref would accumulate every previous organism's state.
is_deeply($trackList->{include}[0], "/a/jbrowse/tracks/tgonME49/tracks.conf",
          'the caller\'s skeleton is left untouched');
is(scalar(@{$trackList->{tracks}}), 1, 'and so is its tracks array');

my @warnings = $G->warnings();
$G->buildTrackList({include => ['/a/service/jbrowse/somethingNew/x']}, 'x', $BASE);
ok(scalar(grep { /somethingNew/ } $G->warnings()),
   'an unrecognised include is reported, not silently dropped');

# ---------------------------------------------------------------------------
# refSeqs.json derived from the .fai
# ---------------------------------------------------------------------------

my $fai = "TGME49_chrIa\t1876705\t14\t60\t61\nTGME49_chrIb\t2199384\t1907792\t60\t60\n";
is_deeply($G->refSeqsFromFai($fai),
          [{name => 'TGME49_chrIa', start => 0, end => 1876705, length => 1876705},
           {name => 'TGME49_chrIb', start => 0, end => 2199384, length => 2199384}],
          'refSeqs derived from the fasta index, in index order');

# Numbers, not strings: JBrowse compares these arithmetically.
like(JSON->new->canonical->encode($G->refSeqsFromFai($fai)), qr/"end":1876705/,
     'lengths encode as JSON numbers');

is_deeply($G->refSeqsFromFai(""), [], 'an empty index yields an empty list');

eval { $G->refSeqsFromFai("TGME49_chrIa\n") };
like($@, qr/malformed/i, 'a truncated index line is refused rather than read as length 0');

# ---------------------------------------------------------------------------
# useAsRefSeqStore stripping
# ---------------------------------------------------------------------------

# Filter on the FIELD, not the label: the label is cosmetic and one organism
# renaming it would silently leave the store-URL reference track in place,
# fighting Apollo's own local copy.
my $withRefSeq = {tracks => [
  {label => 'refseqs',  useAsRefSeqStore => JSON::true,  storeClass => 'X'},
  {label => 'refseqs',  storeClass => 'Y'},
  {label => 'notRefSeq', useAsRefSeqStore => JSON::true, storeClass => 'Z'},
  {label => 'genes',    storeClass => 'W'},
]};
my ($stripped, $removed) = $G->stripRefSeqStoreTracks($withRefSeq);
is($removed, 2, 'both useAsRefSeqStore tracks are stripped regardless of label');
is_deeply([map { $_->{label} } @{$stripped->{tracks}}], ['refseqs', 'genes'],
          'and nothing else is');
is(scalar(@{$withRefSeq->{tracks}}), 4, 'the input document is not mutated');

# ---------------------------------------------------------------------------
# every track must be a JSON object
# ---------------------------------------------------------------------------

# addChipChipTracks appended bare integers (56 of 158 entries for tgonME49).
# Fixed upstream; this is the last gate before a curator sees the output.
eval { $G->assertTracksAreObjects({tracks => [{a => 1}, 42, {b => 2}]}, 'chipseq.json') };
like($@, qr/chipseq\.json/, 'a bare scalar in a tracks array is a hard failure');
like($@, qr/\b1\b/, 'and the offending index is named');
ok($G->assertTracksAreObjects({tracks => [{a => 1}]}, 'ok.json'),
   'a well formed tracks array passes');
is($G->countTracks({tracks => [{a => 1}, {b => 2}]}), 2, 'track count');
is($G->countTracks({tracks => []}), 0,
   'zero tracks is a count, not an error -- cneoJEC21 legitimately has none');

# ---------------------------------------------------------------------------
# writeFile: absolutization plus its post-condition
# ---------------------------------------------------------------------------

my $dir = tempdir(CLEANUP => 1);

$G->writeFile("$dir/t.json", '{"u":"/a/service/x","f":"seq/tgonME49.fa.fai"}', $BASE);
open(my $fh, '<', "$dir/t.json") or die $!;
my $written = do { local $/; <$fh> };
close $fh;
is($written, '{"u":"https://veupathdb.org/a/service/x","f":"seq/tgonME49.fa.fai"}',
   'site-relative URLs absolutized; a bare relative seq/ path is left alone');

# The encoder must return OCTETS.  Real track configs carry non-ASCII (tgonME49
# does), and encoding to characters writes the right bytes but emits a "Wide
# character" warning on the way -- which this module elsewhere treats as proof
# that a config producer's output cannot be trusted.
my $wide = $G->encodeJson({k => "\x{2013}"});
ok(!utf8::is_utf8($wide), 'encodeJson returns octets, not characters');

my @caught;
{
  local $SIG{__WARN__} = sub { push @caught, @_ };
  $G->writeFile("$dir/wide.json", $wide, $BASE);
}
is_deeply(\@caught, [], 'writing non-ASCII content produces no warnings');
is(-s "$dir/wide.json", length($wide), 'and the bytes on disk are the bytes encoded');

# ---------------------------------------------------------------------------
# per-organism failure isolation
# ---------------------------------------------------------------------------

my $results = $G->generateAll(
  [{abbrev => 'good1'}, {abbrev => 'explodes'}, {abbrev => 'good2'}],
  sub {
    my ($organism) = @_;
    die "simulated failure\n" if $organism->{abbrev} eq 'explodes';
    return {tracks => {rnaseq => 3}};
  },
);
is_deeply([sort @{$results->{failed}}], ['explodes'],
          'a failing organism is recorded and the run continues');
is_deeply([sort @{$results->{succeeded}}], ['good1', 'good2'],
          'the organisms either side of it still complete');
like($results->{errors}{explodes}, qr/simulated failure/, 'the error text is kept');

done_testing();
