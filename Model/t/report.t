use strict;
use warnings;
use Test::More;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Report;

my $R = 'ApiCommonModel::Model::ApolloRelease::Report';

# A mixed result shaped like a real build: a large routine `update` bucket, two
# renames, an annotated prune next to a harmless one, an approved add next to an
# unapproved one, two exceptions failing on different criteria, and one dead
# overlay line.
sub mixedResult {
  return {
    update => [
      map { { abbrev            => sprintf('org%03d', $_),
              apollo_id         => 1000 + $_,
              public_mode       => 1,
              organism          => {name => "Organism $_"} } } (1 .. 457)
    ],
    add_candidate => [
      { abbrev   => 'hcapNAm1',
        organism => {name => 'Histoplasma mississippiense NAm1'},
        approved => 0, reason => undef },
      { abbrev   => 'pbraCM01',
        organism => {name => 'Paracoccidioides brasiliensis CM01'},
        approved => 1, reason => 'approved by curation 2026-07' },
    ],
    prune_candidate => [
      { abbrev => 'cglaCBS138', apollo_id => 21, common_name => 'Candida glabrata CBS 138',
        annotation_count => 0,  approved => 1, reason => 'renamed away, zero annotations' },
      { abbrev => 'zzzRisky',   apollo_id => 22, common_name => 'Something Curated',
        annotation_count => 14, approved => 0, reason => undef },
    ],
    rename => [
      { from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21', apollo_id => 2452162,
        annotation_count => 14, public_mode => 1,
        organism => {name => 'Cryptococcus deneoformans JEC21'} },
      { from_abbrev => 'oldAbbrev', to_abbrev => 'newAbbrev', apollo_id => 31,
        annotation_count => 0, public_mode => 0,
        organism => {name => 'Renamed Thing'} },
    ],
    exception => [
      { abbrev => 'tbruLister427_2018', apollo_id => 41, annotation_count => 3,
        is_reference => 0, is_annotated => 1, public_mode => 1,
        organism => {name => 'Trypanosoma brucei Lister427 2018'} },
      { abbrev => 'unannotatedRef', apollo_id => 42, annotation_count => 0,
        is_reference => 1, is_annotated => 0, public_mode => 0,
        organism => {name => 'Unannotated Reference'} },
    ],
    redundant_overlay => [
      { abbrev => 'staleEntry', directive => 'add',
        reason => 'approved 2025', note => 'already in Apollo' },
    ],
  };
}

my $result = mixedResult();
my $text   = $R->render($result, {build => 71, environment => 'prod'});

# ------------------------------------------------------------------ counts

like($text, qr/^\s*update\s+457\s*$/m,            'summary counts the update bucket');
like($text, qr/^\s*add_candidate\s+2\s*$/m,       'summary counts the add bucket');
like($text, qr/^\s*prune_candidate\s+2\s*$/m,     'summary counts the prune bucket');
like($text, qr/^\s*rename\s+2\s*$/m,              'summary counts the rename bucket');
like($text, qr/^\s*exception\s+2\s*$/m,           'summary counts the exception bucket');
like($text, qr/^\s*redundant_overlay\s+1\s*$/m,   'summary counts the redundant overlay bucket');

like($text, qr/build 71/,   'the report says which build it describes');
like($text, qr/\bprod\b/,   'and which environment');

# ----------------------------------------------------------------- renames
# Two rows out of 461 that must not be missed.

like($text, qr/cneoJEC21.*cdenJEC21/,      'a rename names both abbrevs');
like($text, qr/cneoJEC21.*cdenJEC21.*14/,  'and the annotation count it is preserving');

# ---------------------------------------------------- prunes: the loud one
# The expensive mistake this whole tool exists to prevent.

like($text, qr/zzzRisky.*\b14\b/,                      'a prune candidate shows its annotation count');
like($text, qr/zzzRisky.*ANNOTATIONS WILL BE HIDDEN/,  'an annotated prune is flagged loudly');
unlike($text, qr/cglaCBS138.*ANNOTATIONS WILL BE HIDDEN/,
       'a zero-annotation prune is NOT flagged');

# A prune with no annotation_count key at all must read as zero, not as a
# warning and not as an undef-warning in the middle of the report.
my $noCount = { %{mixedResult()},
                prune_candidate => [{abbrev => 'noCountAtAll', apollo_id => 9,
                                     common_name => 'No Count', approved => 0}] };
my $noCountText = $R->render($noCount, {build => 71, environment => 'prod'});
like($noCountText,   qr/noCountAtAll\s+0\b/,                    'a missing annotation count reads as 0');
unlike($noCountText, qr/noCountAtAll.*ANNOTATIONS WILL BE HIDDEN/,
       'and is not flagged');

# --------------------------------------------------------- approval status

like($text, qr/hcapNAm1.*Histoplasma mississippiense NAm1/, 'an add candidate shows its organism name');

my ($unapprovedAdd) = $text =~ /^(.*hcapNAm1.*)$/m;
my ($approvedAdd)   = $text =~ /^(.*pbraCM01.*)$/m;
like($approvedAdd,   qr/approved/i, 'an add already approved in the overlay says so');
unlike($unapprovedAdd, qr/approved/i, 'an unapproved add does not');

my ($approvedPrune)   = $text =~ /^(.*cglaCBS138.*)$/m;
my ($unapprovedPrune) = $text =~ /^(.*zzzRisky.*)$/m;
like($approvedPrune,     qr/approved/i, 'an approved prune says so');
unlike($unapprovedPrune, qr/approved/i, 'an unapproved prune does not');

# -------------------------------------------------------------- exceptions

my ($refException) = $text =~ /^(.*tbruLister427_2018.*)$/m;
my ($annException) = $text =~ /^(.*unannotatedRef.*)$/m;
like($refException, qr/not reference/i,  'an exception shows the criterion it fails');
unlike($refException, qr/not annotated/i, 'and not the one it passes');
like($annException, qr/not annotated/i,  'the other criterion is reported when it is the failing one');
like($text, qr/exceptions.*no action/is, 'exceptions are marked as needing no action');

# ------------------------------------------------------- redundant overlay

like($text, qr/staleEntry.*already in Apollo/, 'a redundant overlay entry is shown with its note');
like($text, qr/staleEntry.*add\b/,             'and with the directive that is dead');

# -------------------------------------------------- pending human decisions

# One unapproved add + one unapproved prune.
my $pending = $R->pendingDecisions($result);
is($pending->{add},             1, 'pendingDecisions counts unapproved adds');
is($pending->{prune},           1, 'pendingDecisions counts unapproved prunes');
is($pending->{total},           2, 'and their total');
is($pending->{annotated_prune}, 1, 'and how many pending prunes would hide annotations');

like($text, qr/DECISIONS REQUIRED:\s*2\b/, 'the report states the pending decision count plainly');

# An empty decision set must SAY so.  Silence is indistinguishable from a
# report that forgot to render the section.
my $settled = { %{mixedResult()}, add_candidate => [], prune_candidate => [] };
my $settledText = $R->render($settled, {build => 71, environment => 'prod'});
like($settledText, qr/DECISIONS REQUIRED:\s*none/i,
     'a report with nothing pending says so explicitly rather than omitting the line');

my $settledPending = $R->pendingDecisions($settled);
is($settledPending->{total}, 0, 'and pendingDecisions agrees');

# Approved-but-annotated is still counted as annotated work at risk, but is not
# a pending decision -- the human already made it.
my $approvedRisky = { %{mixedResult()},
  add_candidate   => [],
  prune_candidate => [{abbrev => 'zzzRisky', apollo_id => 22, common_name => 'Something Curated',
                       annotation_count => 14, approved => 1, reason => 'signed off'}] };
is($R->pendingDecisions($approvedRisky)->{total}, 0, 'an approved prune is not a pending decision');
like($R->render($approvedRisky, {}), qr/zzzRisky.*ANNOTATIONS WILL BE HIDDEN/,
     'but it is still flagged: approval does not make the annotations less hidden');

# ------------------------------------------------ the 457-row update bucket
# Routine updates are real output -- "which 457" matters when the count moves --
# but they must never sit between a reader and the rows that need a decision.

my $pruneAt  = index($text, 'zzzRisky');
my $renameAt = index($text, 'cneoJEC21');
my $addAt    = index($text, 'hcapNAm1');
my $updateAt = index($text, 'org001');
cmp_ok($updateAt, '>', $pruneAt,  'routine updates are printed after the prune candidates');
cmp_ok($updateAt, '>', $renameAt, 'and after the renames');
cmp_ok($updateAt, '>', $addAt,    'and after the add candidates');

my @updateLines = grep { /\borg\d\d\d\b/ } split(/\n/, $text);
cmp_ok(scalar(@updateLines), '<', 100,
       '457 updates do not become 457 lines that bury everything else');
like($text, qr/org457/, 'but every updated organism is still named somewhere');

# ------------------------------------------------------------- determinism

is($R->render(mixedResult(), {build => 71, environment => 'prod'}),
   $R->render(mixedResult(), {build => 71, environment => 'prod'}),
   'the same input renders byte-identical output');

# Bucket contents arriving in a different order must not change the output;
# a diff between two releases has to be a diff of decisions.
my $shuffled = mixedResult();
$shuffled->{prune_candidate} = [reverse @{$shuffled->{prune_candidate}}];
$shuffled->{rename}          = [reverse @{$shuffled->{rename}}];
$shuffled->{add_candidate}   = [reverse @{$shuffled->{add_candidate}}];
$shuffled->{update}          = [reverse @{$shuffled->{update}}];
is($R->render($shuffled, {build => 71, environment => 'prod'}), $text,
   'input order does not change the rendered output');

# --------------------------------------------------------- missing buckets

my $empty;
eval { $empty = $R->render({}, {}) };
is($@, '', 'a result with no buckets at all renders instead of dying');
like($empty, qr/^\s*update\s+0\s*$/m, 'and still shows a zero for every bucket');

# ------------------------------------------------------- machine-readable

my $tsv = $R->renderTsv($result);
my @rows = split(/\n/, $tsv);
like($rows[0], qr/^#/, 'the TSV starts with a comment header naming the columns');

my @body = grep { !/^#/ } @rows;
is(scalar(@body), 457 + 2 + 2 + 2 + 2 + 1, 'the TSV has exactly one row per bucket entry');

my ($tsvRename) = grep { /\bcneoJEC21\b/ } @body;
my @f = split(/\t/, $tsvRename, -1);
is($f[0], 'rename',    'the first TSV column is the bucket');
is($f[1], 'cneoJEC21', 'the second is the abbrev the entry is keyed by');
like($tsvRename, qr/\bcdenJEC21\b/, 'a rename row carries the destination abbrev too');
like($tsvRename, qr/\b14\b/,        'and the annotation count');

is($R->renderTsv(mixedResult()), $tsv, 'the TSV is byte-stable for the same input');

# A tab or newline in a portal-supplied name would silently shift every later
# column, or split one record into two, in whatever diffs this file.
my $nasty = { %{mixedResult()},
  prune_candidate => [{abbrev => 'nasty', apollo_id => 1, annotation_count => 0, approved => 0,
                       common_name => "Tab\there and\nnewline"}] };
my ($nastyRow) = grep { /\bnasty\b/ } split(/\n/, $R->renderTsv($nasty));
unlike($nastyRow, qr/\tTab\t/, 'an embedded tab is neutralised rather than shifting the columns');

my @nastyBody = grep { !/^#/ } split(/\n/, $R->renderTsv($nasty));
is(scalar(@nastyBody), 457 + 2 + 1 + 2 + 2 + 1,
   'an embedded newline does not split one record into two rows');
is(scalar(grep { !/^(update|add_candidate|prune_candidate|rename|exception|redundant_overlay)\t/ } @nastyBody),
   0, 'and every row still begins with its bucket');

done_testing();
