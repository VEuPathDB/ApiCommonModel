use strict;
use warnings;
use Test::More tests => 36;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Portal;
use ApiCommonModel::Model::ApolloRelease::Apollo;
use ApiCommonModel::Model::ApolloRelease::Overlay;
use ApiCommonModel::Model::ApolloRelease::Reconcile;

my $R = 'ApiCommonModel::Model::ApolloRelease::Reconcile';

my $portal  = ApiCommonModel::Model::ApolloRelease::Portal->loadFromFile("Model/t/fixtures/portal.json");
my $live    = ApiCommonModel::Model::ApolloRelease::Apollo->loadFromFile("Model/t/fixtures/apollo.json");
my $overlay = ApiCommonModel::Model::ApolloRelease::Overlay->parseString("remove hsapREF # host genome\n");

# No renames supplied: cneoJEC21 and cglaCBS138 are unmatched, so both are prunes.
my $r = $R->reconcile($portal, $live, $overlay, {});

my %update = map { $_->{abbrev} => 1 } @{$r->{update}};
ok($update{tgonME49}, 'in Apollo and on portal -> update');
ok($update{pfal3D7},  'GUI-renamed organism still updates (matched on directory)');

my %prune = map { $_->{abbrev} => 1 } @{$r->{prune_candidate}};
ok($prune{cneoJEC21},  'in Apollo, absent from portal -> prune candidate');
ok($prune{cglaCBS138}, 'second orphan is a prune candidate');

my ($cneo) = grep { $_->{abbrev} eq 'cneoJEC21' } @{$r->{prune_candidate}};
is($cneo->{annotation_count}, 14, 'prune candidates carry their annotation count');

my %add = map { $_->{abbrev} => 1 } @{$r->{add_candidate}};
ok($add{hcapNAm1},  'qualifying organism absent from Apollo -> add candidate');
ok($add{cdenJEC21}, 'rename target is an add candidate when no rename is detected');
ok(!$add{hsapREF},  'overlay remove suppresses an add candidate');

my %exception = map { $_->{abbrev} => 1 } @{$r->{exception}};
ok($exception{tbruLister427_2018}, 'in Apollo but not reference+annotated -> exception');
ok(!$update{tbruLister427_2018},   'an exception is not also an update');

# Now supply the rename, and the pair must collapse.
my $renames = { cneoJEC21 => 'cdenJEC21' };
my $r2 = $R->reconcile($portal, $live, $overlay, $renames);

my %prune2 = map { $_->{abbrev} => 1 } @{$r2->{prune_candidate}};
my %add2   = map { $_->{abbrev} => 1 } @{$r2->{add_candidate}};
ok(!$prune2{cneoJEC21} && !$add2{cdenJEC21},
   'a detected rename removes both the prune and the add');

is(scalar(@{$r2->{rename}}), 1, 'and produces exactly one rename entry');

my $overlayWithPrune = ApiCommonModel::Model::ApolloRelease::Overlay->parseString(
  "remove cglaCBS138 # renamed to nglaCBS138, zero annotations\n");
my $r3 = $R->reconcile($portal, $live, $overlayWithPrune, {});
my ($cgla) = grep { $_->{abbrev} eq 'cglaCBS138' } @{$r3->{prune_candidate}};
is($cgla->{approved}, 1, 'an overlay remove approves the prune');

# ---------------------------------------------------------------------------
# publicMode passthrough.  17 live organisms are deliberately hidden; an update
# or a rename that forces publicMode=true silently re-publishes them.
# ---------------------------------------------------------------------------

my ($tgon) = grep { $_->{abbrev} eq 'tgonME49' } @{$r->{update}};
is($tgon->{public_mode}, 1, 'update carries the live publicMode through');

# treeQM6a is the case that actually matters: hidden by curators
# (publicMode false), on the portal, reference+annotated, 11 annotations.  It
# is a plain update, so a hardcoded publicMode=true would re-publish it --
# exactly the 17-organism bug this module exists to prevent.
my ($tree) = grep { $_->{abbrev} eq 'treeQM6a' } @{$r->{update}};
ok($tree, 'a hidden organism still qualifies for a routine update');
is($tree->{public_mode}, 0, 'update on a HIDDEN organism carries publicMode 0, not 1');

my ($ren) = @{$r2->{rename}};
is($ren->{public_mode}, 1, 'rename carries the live publicMode through');
is($ren->{annotation_count}, 14, 'rename carries the curation work it is protecting');

# Same rule on the rename path.  No live pair exercises it, so the rename map
# is synthetic -- but the passthrough it checks is not: a hidden organism that
# gets reclassified must not be published by the act of being renamed.
my $r5 = $R->reconcile($portal, $live, $overlay, { treeQM6a => 'tbruTREU927' });
my ($hiddenRename) = @{$r5->{rename}};
is($hiddenRename->{from_abbrev}, 'treeQM6a', 'the hidden organism is the one renamed');
is($hiddenRename->{public_mode}, 0, 'rename of a HIDDEN organism carries publicMode 0, not 1');

# ---------------------------------------------------------------------------
# Attacking the invariant directly.  reconcile() cannot construct a violating
# result (see Reconcile.pm), so the guard is exercised at its own seam: it is a
# public class method precisely so that it is not dead, untested code.
# ---------------------------------------------------------------------------

eval {
  $R->assertInvariants({
    update          => [],
    add_candidate   => [{ abbrev => 'cdenJEC21' }],
    prune_candidate => [],
    rename          => [{ from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21' }],
    exception       => [],
  });
};
like($@, qr/INVARIANT VIOLATED: cdenJEC21 is both a rename target and an add candidate/,
     'guard fires when a rename target is also an add candidate');

eval {
  $R->assertInvariants({
    update          => [],
    add_candidate   => [],
    prune_candidate => [{ abbrev => 'cneoJEC21' }],
    rename          => [{ from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21' }],
    exception       => [],
  });
};
like($@, qr/INVARIANT VIOLATED: cneoJEC21 is both a rename source and a prune candidate/,
     'guard fires when a rename source is also a prune candidate');

ok($R->assertInvariants($r2), 'a real reconcile result passes the guard');

# ---------------------------------------------------------------------------
# Incoherent rename input.  A rename map is a human statement of intent; every
# way of ignoring one silently loses curation work or an organism.
# ---------------------------------------------------------------------------

eval { $R->reconcile($portal, $live, $overlay, { zzzNotLive => 'hcapNAm1' }) };
like($@, qr/rename source zzzNotLive is not in Apollo/,
     'a rename whose source is not live dies instead of vanishing');

eval { $R->reconcile($portal, $live, $overlay, { cneoJEC21 => 'cdenJEC21',
                                                 cglaCBS138 => 'cdenJEC21' }) };
like($@, qr/two organisms renamed to cdenJEC21/,
     'two sources claiming one target is refused');

eval { $R->reconcile($portal, $live, $overlay, { cneoJEC21 => 'notOnPortal' }) };
like($@, qr/rename target notOnPortal is not on the portal/,
     'a rename target absent from the portal dies');

eval { $R->reconcile($portal, $live, $overlay, { cneoJEC21 => '' }) };
like($@, qr/rename target for cneoJEC21 is empty/,
     'an empty rename target dies instead of falling through as "no rename"');

# treeQM6a is both a target (of cneoJEC21) and a source (of tbruTREU927).
eval { $R->reconcile($portal, $live, $overlay, { cneoJEC21 => 'treeQM6a',
                                                 treeQM6a  => 'tbruTREU927' }) };
like($@, qr/treeQM6a is both a rename source and a rename target/,
     'a chained rename is refused rather than applied in an arbitrary order');

eval { $R->reconcile($portal, $live, $overlay, { cneoJEC21 => 'tgonME49' }) };
like($@, qr/rename target tgonME49 is already in Apollo; that is a merge, not a rename/,
     'repointing onto a live organism is refused');

# ---------------------------------------------------------------------------
# Overlay hygiene.  A no-op overlay line is not an error, but it must be
# reported: it is a human decision the tool did nothing with.
# ---------------------------------------------------------------------------

is(scalar(@{$r->{redundant_overlay}}), 0, 'a fully-effective overlay reports nothing redundant');

my $noisyOverlay = ApiCommonModel::Model::ApolloRelease::Overlay->parseString(
    "add tgonME49 # already live, left over from last release\n"
  . "remove zzzGhost # organism nobody has heard of\n");
my $r4 = $R->reconcile($portal, $live, $noisyOverlay, {});
my %redundant = map { $_->{abbrev} => $_ } @{$r4->{redundant_overlay}};
is($redundant{tgonME49}{directive}, 'add', 'an overlay add for a live organism is reported as redundant');
is($redundant{zzzGhost}{directive}, 'remove', 'an overlay entry naming nothing at all is reported');
is($redundant{tgonME49}{reason}, 'already live, left over from last release',
   'the redundant entry carries its reason so the file can be cleaned up');

# A rename consumes BOTH abbrevs, disarming an overlay line naming either end.
# Neither shows up in any other bucket, so this is the only place they surface.
my $renameShadowedOverlay = ApiCommonModel::Model::ApolloRelease::Overlay->parseString(
    "add cdenJEC21 # approved before we knew it was a rename\n"
  . "remove cneoJEC21 # thought it was gone; it was reclassified\n");
my $r6 = $R->reconcile($portal, $live, $renameShadowedOverlay, { cneoJEC21 => 'cdenJEC21' });
my %shadowed = map { $_->{abbrev} => $_ } @{$r6->{redundant_overlay}};
is($shadowed{cdenJEC21}{note}, 'already arriving as a rename from cneoJEC21',
   'an overlay add naming a rename target is reported, not swallowed');
is($shadowed{cneoJEC21}{note}, 'being renamed to cdenJEC21, not pruned',
   'an overlay remove naming a rename source is reported, not swallowed');

# The exclusion that must survive all of the above.
my %stillEffective = map { $_->{abbrev} => 1 } @{$r->{redundant_overlay}};
ok(!$stillEffective{hsapREF},
   'a remove that really does suppress an add is NOT reported as redundant');
