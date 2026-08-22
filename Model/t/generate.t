use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use JSON;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Generate;

my $G = 'ApiCommonModel::Model::ApolloRelease::Generate';
my $BASE = 'https://veupathdb.org';

# --- localNameForInclude ---

is($G->localNameForInclude('/a/jbrowse/tracks/tgonME49/tracks.conf'), 'tracks.conf',
   'per-organism tracks.conf');
is($G->localNameForInclude('/a/jbrowse/functions.conf'), 'functions.conf',
   'functions.conf');
is($G->localNameForInclude('/a/jbrowse/apollo_gene_tracks.conf'), 'apollo_gene_tracks.conf',
   'apollo_gene_tracks.conf');

# rnaseqJunctions must not be swallowed by the plain rnaseq rule: both are
# generated for the same organism, so a rule-order slip writes one file's
# contents under the other's name and nothing downstream notices.
is($G->localNameForInclude('/a/service/jbrowse/rnaseqJunctions/tgonME49'),
   'rnaseqJunctions.json', 'rnaseqJunctions wins over rnaseq');
is($G->localNameForInclude('/a/service/jbrowse/rnaseq/tgonME49'), 'rnaseq.json', 'rnaseq');
is($G->localNameForInclude('/a/service/jbrowse/chipseq/tgonME49'), 'chipseq.json', 'chipseq');
is($G->localNameForInclude('/a/service/jbrowse/dnaseq/tgonME49'), 'dnaseq.json', 'dnaseq');
is($G->localNameForInclude('/a/service/jbrowse/organismSpecific/tgonME49'),
   'organismSpecific.json', 'organismSpecific');
is($G->localNameForInclude('/a/service/jbrowse/somethingNew/tgonME49'), undef,
   'an unrecognised include maps to undef rather than being guessed at');

# --- buildTrackList ---

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

# The caller owns the file set it produced, so buildTrackList must neither
# invent names nor duplicate one already mapped in from the skeleton.
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

$G->buildTrackList({include => ['/a/service/jbrowse/somethingNew/x']}, 'x', $BASE);
ok(scalar(grep { /somethingNew/ } $G->warnings()),
   'an unrecognised include is reported, not silently dropped');

# --- refSeqs.json derived from the .fai ---

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

# --- useAsRefSeqStore stripping ---

# Filter on the FIELD, not the label: the label is cosmetic, so renaming it
# would leave the store-URL track in place fighting Apollo's local copy.
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

# --- every track must be a JSON object ---

# A track builder upstream appended bare integers; this is the last gate before
# a curator sees the output.  The bad entries sit at indexes 2 and 4 of 5 so
# that neither index can be satisfied by the bad-count or the total -- with one
# bad entry at index 1, deleting the whole "at index(es)" clause from the
# message still left this green.
eval { $G->assertTracksAreObjects(
         {tracks => [{a => 1}, {b => 2}, 42, {c => 3}, 'nope']}, 'chipseq.json') };
like($@, qr/chipseq\.json/, 'a bare scalar in a tracks array is a hard failure');
like($@, qr/index\(es\)\s+2,\s*4\b/, 'and every offending index is named');
like($@, qr/\b2 of 5\b/, 'reported against the total, so the scale is visible');
ok($G->assertTracksAreObjects({tracks => [{a => 1}]}, 'ok.json'),
   'a well formed tracks array passes');
is($G->countTracks({tracks => [{a => 1}, {b => 2}]}), 2, 'track count');
is($G->countTracks({tracks => []}), 0,
   'zero tracks is a count, not an error -- cneoJEC21 legitimately has none');

# --- [tracks.refseq] stanza stripping ---

# A no-op across the current roster, so this fixture is the only example of the
# shape; stripRefSeqStanza records why it ships anyway.
my $conf = join "\n",
  '[general]',
  'dataset_id=tgonME49',
  '',
  '[tracks.refseq]',
  'storeClass=JBrowse/Store/SeqFeature/IndexedFasta',
  '#urlTemplate=commented out, and Paul\'s regex stopped here',
  'faiUrlTemplate=/a/service/jbrowse/store?data=x.fai',
  '',
  '[tracks.gcContent]',
  'key=GC Content',
  '';

my ($cleaned, $stanzas) = $G->stripRefSeqStanza($conf);
is($stanzas, 1, 'the refseq stanza is counted');
unlike($cleaned, qr/refseq/i, 'and every line of it is gone');

# The specific failure of the previous implementation: its character class
# stopped at the first "#", leaving the rest of the stanza behind.
unlike($cleaned, qr/faiUrlTemplate/,
       'including the keys after a comment line inside the stanza');
like($cleaned, qr/\[tracks\.gcContent\]\nkey=GC Content/,
     'the following stanza survives intact');
like($cleaned, qr/^\[general\]\ndataset_id=tgonME49\n/,
     'and so does everything before it');

my ($untouched, $none) = $G->stripRefSeqStanza($conf =~ s/\[tracks\.refseq\]/[tracks.other]/r);
is($none, 0, 'a tracks.conf without the stanza reports zero');
like($untouched, qr/faiUrlTemplate/, 'and is returned unchanged');

# --- writeFile: absolutization plus its post-condition ---

my $dir = tempdir(CLEANUP => 1);

$G->writeFile("$dir/t.json", '{"u":"/a/service/x","f":"seq/tgonME49.fa.fai"}', $BASE);
open(my $fh, '<', "$dir/t.json") or die $!;
my $written = do { local $/; <$fh> };
close $fh;
is($written, '{"u":"https://veupathdb.org/a/service/x","f":"seq/tgonME49.fa.fai"}',
   'site-relative URLs absolutized; a bare relative seq/ path is left alone');

# The encoder must return OCTETS: real track configs carry non-ASCII, and
# encoding to characters writes the right bytes but emits a "Wide character"
# warning -- which this module elsewhere treats as untrustworthy output.
my $wide = $G->encodeJson({k => "\x{2013}"});
ok(!utf8::is_utf8($wide), 'encodeJson returns octets, not characters');

my @caught;
{
  local $SIG{__WARN__} = sub { push @caught, @_ };
  $G->writeFile("$dir/wide.json", $wide, $BASE);
}
is_deeply(\@caught, [], 'writing non-ASCII content produces no warnings');
is(-s "$dir/wide.json", length($wide), 'and the bytes on disk are the bytes encoded');

# --- per-organism failure isolation ---

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

# --- assertToolsAvailable ---

# Not called by generateOrganism -- the CLI calls it once before the loop -- so
# without this it ships unverified.  PATH is manipulated rather than trusted, so
# the result does not depend on whose account runs the suite.
{
  my $binDir = tempdir(CLEANUP => 1);
  local $ENV{PATH} = $binDir;

  my $err = do { local $@; eval { $G->assertToolsAvailable() }; $@ };
  like($err, qr/faToTwoBit is not on PATH/, 'a missing faToTwoBit fails immediately');
  like($err, qr{~/bin/faToTwoBit},
       'and the message carries the install location, not just the complaint');
  like($err, qr/libssl\.so\.10/,
       'and warns off the 2016 yew binary, which is the obvious wrong fix');

  open(my $fake, '>', "$binDir/faToTwoBit") or die $!;
  close $fake;
  chmod 0755, "$binDir/faToTwoBit";
  is($G->assertToolsAvailable(), "$binDir/faToTwoBit",
     'and it returns the resolved path when present');
}

# --- generateOrganism: the public/internal abbrev split, end to end ---

# The one function wiring the two abbrev namespaces together, and the mistake it
# guards against is invisible on all but a handful of organisms -- so the fixture
# is a renamed one, where public and internal genuinely differ.
{
  my $out = tempdir(CLEANUP => 1);

  my @scriptCalls;
  my @reads;
  my @copies;
  my @twoBits;

  my $fai = "chr1\t100\t10\t60\t61\nchr2\t250\t200\t60\t61\n";

  my $summary = $G->generateOrganism(
    {abbrev => 'cdenJEC21', internal_abbrev => 'cneoJEC21',
     name_for_filenames => 'CdeneoformansJEC21'},
    {
      outDir  => $out,
      base    => $BASE,
      project => 'UniDB',
      build   => 71,
      wsDir   => '/ws',
      gusHome => '/gus',

      runScript => sub {
        my ($gusHome, $script, @args) = @_;
        push @scriptCalls, {script => $script, args => \@args};

        return encode_json({
          names   => {type => 'REST', url => '/a/service/jbrowse/names/cdenJEC21'},
          tracks  => [],
          refSeqs => '/a/service/jbrowse/store?data=x',
          include => ['/a/jbrowse/tracks/cdenJEC21/tracks.conf'],
        }) if $script eq 'jbrowseTracks';

        # organismSpecific carries the store-URL reference track; the others
        # carry one ordinary track each.
        return encode_json({tracks => [
          {label => 'refseqs', useAsRefSeqStore => JSON::true},
          {label => 'real', urlTemplate => '/a/service/jbrowse/store?data=y'},
        ]}) if $script eq 'jbrowseOrganismSpecificTracks';

        return encode_json({tracks => [{label => 'real'}]});
      },

      readFile => sub {
        my ($path) = @_;
        push @reads, $path;
        return $fai if $path =~ /\.fa\.fai$/;
        return "[tracks.x]\nkey=from $path\n";
      },

      copyFile => sub { push @copies, [@_]; return 1 },
      twoBit   => sub { push @twoBits, [@_]; return 1 },
    },
  );

  # --- the five track producers take the INTERNAL abbrev ------------------
  my @producers = grep { $_->{script} ne 'jbrowseTracks' } @scriptCalls;
  is(scalar(@producers), 5, 'all five track producers ran');
  is_deeply([map { $_->{args}[0] } @producers],
            [('cneoJEC21') x 5],
            'each track producer received the INTERNAL abbrev');
  is_deeply([sort map { $_->{script} } @producers],
            ['jbrowseDNASeqTracks', 'jbrowseOrganismSpecificTracks',
             'jbrowseRNASeqJunctionTracks', 'jbrowseRnaAndChipSeqTracks',
             'jbrowseRnaAndChipSeqTracks'],
            'and they are the five the spec names');

  # --- jbrowseTracks takes the PUBLIC abbrev ------------------------------
  my ($skeleton) = grep { $_->{script} eq 'jbrowseTracks' } @scriptCalls;
  is($skeleton->{args}[0], 'cdenJEC21',
     'jbrowseTracks received the PUBLIC abbrev -- its SQL matches public_abbrev');
  is_deeply($skeleton->{args}, ['cdenJEC21', 'UniDB', 0, 'geneAnnotationTracks'],
            'with the geneAnnotationTracks skeleton arguments');

  # --- tracks.conf is keyed off the INTERNAL abbrev -----------------------
  ok(scalar(grep { $_ eq '/gus/lib/jbrowse/auto_generated/cneoJEC21/tracks.conf' } @reads),
     'tracks.conf read from auto_generated/<INTERNAL>/');
  is(scalar(grep { m{auto_generated/cdenJEC21} } @reads), 0,
     'and never from auto_generated/<public>/, which does not exist');

  # --- every OUTPUT path uses the PUBLIC abbrev ---------------------------
  is_deeply(\@copies,
            [['/ws/UniDB/build-71/CdeneoformansJEC21/genomeAndProteome/fasta/genome.fasta',
              "$out/data/cdenJEC21/seq/cdenJEC21.fa"],
             ['/ws/UniDB/build-71/CdeneoformansJEC21/genomeAndProteome/fasta/genome.fasta.fai',
              "$out/data/cdenJEC21/seq/cdenJEC21.fa.fai"]],
            'the genome is sourced by name_for_filenames and lands under the PUBLIC abbrev');
  is_deeply(\@twoBits,
            [["$out/data/cdenJEC21/seq/cdenJEC21.fa", "$out/twoBit/cdenJEC21.2bit"]],
            'and so does the .2bit');
  ok(-f "$out/data/cdenJEC21/trackList.json", 'the organism dir is the PUBLIC abbrev');
  ok(!-e "$out/data/cneoJEC21", 'nothing is written under the internal abbrev');

  # --- and the package it produced ----------------------------------------
  my $written = decode_json(do {
    open(my $t, '<', "$out/data/cdenJEC21/trackList.json") or die $!;
    local $/; <$t>;
  });
  is($written->{refSeqs}, 'seq/cdenJEC21.fa.fai', 'trackList refSeqs uses the public abbrev');
  is($written->{tracks}[0]{urlTemplate}, 'seq/cdenJEC21.fa', 'as does its reference track');
  is_deeply($written->{include},
            ['tracks.conf', 'rnaseq.json', 'chipseq.json', 'rnaseqJunctions.json',
             'organismSpecific.json', 'dnaseq.json', 'functions.conf',
             'apollo_gene_tracks.conf'],
            'every include names a file this run actually wrote');
  ok(-f "$out/data/cdenJEC21/$_", "$_ was written") for @{$written->{include}};

  is($summary->{stripped}, 1, 'the store-URL reference track was stripped');
  is($summary->{sequences}, 2, 'sequence count comes from the copied index');
  is_deeply($summary->{counts},
            {'rnaseq.json' => 1, 'chipseq.json' => 1, 'rnaseqJunctions.json' => 1,
             'organismSpecific.json' => 1, 'dnaseq.json' => 1},
            'track counts are per file, after stripping');
  is($summary->{refseq_stanzas_stripped}, 0, 'no [tracks.refseq] stanza in this fixture');

  my $specific = decode_json(do {
    open(my $t, '<', "$out/data/cdenJEC21/organismSpecific.json") or die $!;
    local $/; <$t>;
  });
  is(scalar(grep { $_->{useAsRefSeqStore} } @{$specific->{tracks}}), 0,
     'and no useAsRefSeqStore track survives into the file');
  is($specific->{tracks}[0]{urlTemplate}, 'https://veupathdb.org/a/service/jbrowse/store?data=y',
     'the surviving track was absolutized on the way out');

  my $refSeqs = decode_json(do {
    open(my $t, '<', "$out/data/cdenJEC21/seq/refSeqs.json") or die $!;
    local $/; <$t>;
  });
  is_deeply($refSeqs,
            [{name => 'chr1', start => 0, end => 100, length => 100},
             {name => 'chr2', start => 0, end => 250, length => 250}],
            'refSeqs.json derived from the index that was copied, not re-queried');
}

done_testing();
