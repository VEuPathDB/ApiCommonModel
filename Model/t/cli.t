use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Cli;

my $C = 'ApiCommonModel::Model::ApolloRelease::Cli';

# --- option parsing and the two phases ---

{
  my $opts = $C->parseOptions('--report', '--build', '71');
  is($opts->{phase}, 'report', 'a bare --report run parses');
  is($opts->{build}, 71, 'build carried');
  is($opts->{environment}, 'prod', 'environment defaults to prod');
  is($opts->{project}, 'UniDB', 'project defaults to UniDB');
  is($opts->{base_url}, 'https://veupathdb.org', 'base url defaults to the portal');
  is($opts->{ws_dir}, '/var/www/Common/apiSiteFilesMirror/webServices', 'webServices default');
  is($opts->{out_dir}, "$ENV{HOME}/apolloConfigs", 'out dir defaults under HOME');
  is_deeply($opts->{organisms}, [], 'no organism narrowing by default');
  ok(!$opts->{force}, 'force off by default');
}

{
  my $opts = $C->parseOptions('--help');
  is($opts->{phase}, 'help', '--help is its own phase');
  ok(!defined $opts->{build}, 'and --help does not require --build');
}

{
  # The point of this case: --help must be answerable with no credentials, no
  # GUS_HOME and no database, so it cannot be validated like a real run.
  local %ENV = (HOME => $ENV{HOME});
  my $opts = eval { $C->parseOptions('--help') };
  is($opts->{phase}, 'help', '--help parses with a stripped environment');
}

{
  local %ENV = (HOME => $ENV{HOME});
  eval { $C->parseOptions('--report') };
  like($@, qr/--build/, 'a missing --build is reported with no environment at all');
}

{
  eval { $C->parseOptions('--build', '71') };
  like($@, qr/--report.*--generate|exactly one/i, 'neither phase is refused');
}

{
  eval { $C->parseOptions('--report', '--generate', '--build', '71') };
  like($@, qr/exactly one|mutually exclusive/i, 'both phases at once is refused');
}

{
  eval { $C->parseOptions('--report', '--build', 'seventy-one') };
  like($@, qr/--build/, 'a non-numeric build is refused');
}

{
  eval { $C->parseOptions('--report', '--build', '0') };
  like($@, qr/--build/, 'build 0 is refused');
}

{
  eval { $C->parseOptions('--report', '--build', '71', '--environment', 'staging') };
  like($@, qr/environment/, 'an unknown environment is refused');
}

{
  my $opts = $C->parseOptions('--generate', '--build', '71',
                              '--organism', 'tgonME49', '--organism', 'pfal3D7');
  is_deeply($opts->{organisms}, ['tgonME49', 'pfal3D7'], '--organism is repeatable');
}

{
  # --organism narrows generation only; accepting it silently on --report
  # would suggest the report had been filtered too.
  eval { $C->parseOptions('--report', '--build', '71', '--organism', 'tgonME49') };
  like($@, qr/--organism/, '--organism with --report is refused rather than ignored');
}

{
  my $opts = $C->parseOptions('--generate', '--build', '71', '--environment', 'qa',
                              '--out-dir', '/tmp/x', '--force');
  is($C->outputDir($opts), '/tmp/x/release-71/qa', 'output dir is <out>/release-N/<env>');
  ok($opts->{force}, '--force carried');
}

# --- preflight ---

{
  eval { $C->assertEnvironment({GUS_HOME => '/x', APOLLO_API_PASS => 'p'}, 1) };
  like($@, qr/APOLLO_API_USER/, 'a missing credential is named');

  eval { $C->assertEnvironment({APOLLO_API_USER => 'u', APOLLO_API_PASS => 'p'}, 1) };
  like($@, qr/GUS_HOME/, 'a missing GUS_HOME is named');

  ok($C->assertEnvironment({GUS_HOME => '/x', APOLLO_API_USER => 'u', APOLLO_API_PASS => 'p'}, 1),
     'a complete environment passes');

  ok($C->assertEnvironment({GUS_HOME => '/x'}, 0),
     'the Apollo credentials are not required when the roster comes from a file');
}

{
  my $dir = tempdir(CLEANUP => 1);
  ok($C->assertPreviousRelease($dir), 'a readable previous release passes');
  eval { $C->assertPreviousRelease("$dir/nope") };
  like($@, qr/\Q$dir\E\/nope/, 'a missing previous release names the path');
  ok($C->assertPreviousRelease(undef), 'no previous release is not an error');
}

# --- roster overlay: the installed copy, and the per-release override ---

{
  my $opts = $C->parseOptions('--report', '--build', '71');
  ok(!defined $opts->{roster_overlay}, 'no roster overlay override by default');
  is($C->overlayPath($opts, {GUS_HOME => '/g'}),
     '/g/data/ApiCommonModel/Model/apollo/roster-overlay.txt',
     'the default overlay is the copy installed under GUS_HOME');
}

{
  my $opts = $C->parseOptions('--report', '--build', '71',
                              '--roster-overlay', '/tmp/b71-overlay.txt');
  is($opts->{roster_overlay}, '/tmp/b71-overlay.txt', '--roster-overlay carried');
  is($C->overlayPath($opts, {GUS_HOME => '/g'}), '/tmp/b71-overlay.txt',
     'an override wins over the installed copy');
}

{
  eval { $C->parseOptions('--report', '--build', '71', '--roster-overlay', '') };
  like($@, qr/--roster-overlay cannot be empty/,
       'an empty --roster-overlay is refused, not read as "use the default"');
}

{
  eval { $C->overlayPath({}, {}) };
  like($@, qr/GUS_HOME/,
       'no override and no GUS_HOME refuses rather than building /data/...');
}

{
  my $dir = tempdir(CLEANUP => 1);
  my $file = "$dir/overlay.txt";
  open(my $fh, '>', $file) or die $!;
  print $fh "# empty overlay\n";
  close $fh;

  ok($C->assertRosterOverlay($file), 'a readable override passes preflight');
  ok($C->assertRosterOverlay(undef), 'no override is not an error');

  eval { $C->assertRosterOverlay("$dir/nope.txt") };
  like($@, qr/\Q$dir\E\/nope\.txt/, 'a missing override names the path');

  eval { $C->assertRosterOverlay($dir) };
  like($@, qr/is not a file/, 'a directory is refused before parseFile slurps it');
}

{
  my %good = (outDir => '/o', base => 'https://veupathdb.org', project => 'UniDB',
              build => 71, wsDir => '/ws', gusHome => '/g');

  ok($C->assertGenerateConfig(\%good), 'a complete Generate config passes');

  # The two failures a quality review flagged: a key typo, and a key that is
  # merely absent and degrades to a wrong path rather than an error.
  my %typo = %good;
  $typo{wsdir} = delete $typo{wsDir};
  eval { $C->assertGenerateConfig(\%typo) };
  like($@, qr/wsDir/, 'a wsDir typo is caught before the run, not deep inside it');

  my %missing = %good;
  delete $missing{gusHome};
  eval { $C->assertGenerateConfig(\%missing) };
  like($@, qr/gusHome/, 'a missing gusHome is caught rather than degrading to /bin/<script>');

  my %empty = (%good, wsDir => '/ws', gusHome => '');
  eval { $C->assertGenerateConfig(\%empty) };
  like($@, qr/gusHome/, 'an empty value is as bad as a missing one');
}

# --- sanity checks -- the tool this replaces produced an empty release and reported success ---

sub _portalOf {
  my ($n) = @_;
  return {map { ("o$_" => {abbrev => "o$_", is_reference => 1, is_annotated => 1}) } (1 .. $n)};
}

{
  eval { $C->assertPortalSane({}) };
  like($@, qr/\b0\b/, 'an empty portal dies');

  eval { $C->assertPortalSane(_portalOf(12)) };
  like($@, qr/implausibl|floor|too few/i, 'an implausibly small portal dies');

  ok($C->assertPortalSane(_portalOf($C->PORTAL_FLOOR)), 'exactly the floor passes');
  ok($C->assertPortalSane(_portalOf(831)), 'the real build-71 figure passes');
}

{
  eval { $C->assertApolloSane({}, 'fixture.json') };
  like($@, qr/fixture\.json/, 'an empty Apollo roster dies naming its source');
  like($@, qr/no organisms|empty/i, 'and says the roster was empty');

  ok($C->assertApolloSane({a => {}}, 'fixture.json'), 'a non-empty roster passes');
}

{
  my $none = {update => [], rename => [], add_candidate => [], prune_candidate => []};
  eval { $C->assertUpdateBucketSane($none, 0) };
  like($@, qr/--force/, 'an empty update bucket dies and names the override');
  like($@, qr/portal/i, 'and explains what an empty update bucket means');

  ok($C->assertUpdateBucketSane($none, 1), '--force overrides it');
  ok($C->assertUpdateBucketSane({update => [{abbrev => 'a'}]}, 0), 'a non-empty bucket passes');
}

# --- the --generate gate: writeCommandFiles silently drops unapproved candidates ---

{
  my $pending = {
    update          => [{abbrev => 'a'}],
    add_candidate   => [{abbrev => 'hcapNAm1', approved => 0}],
    prune_candidate => [{abbrev => 'zzz', approved => 0, annotation_count => 3}],
    rename          => [],
  };

  eval { $C->assertGenerationAllowed($pending, 0) };
  like($@, qr/2\b/,             'the gate names the number pending');
  like($@, qr/roster.overlay/i, 'and names the roster overlay as the fix');
  like($@, qr/hcapNAm1/,        'and names the pending add');
  like($@, qr/zzz/,             'and names the pending prune');

  ok($C->assertGenerationAllowed($pending, 1), '--force overrides the gate');

  my $clear = {update => [{abbrev => 'a'}], add_candidate => [{abbrev => 'b', approved => 1}],
               prune_candidate => [], rename => []};
  ok($C->assertGenerationAllowed($clear, 0), 'an approved candidate is not pending');
}

{
  # The gate's advice must name the overlay the run actually read; with an
  # override it otherwise sends the reader to edit a file that had no effect.
  my $pending = {
    update          => [{abbrev => 'a'}],
    add_candidate   => [{abbrev => 'hcapNAm1', approved => 0}],
    prune_candidate => [],
    rename          => [],
  };

  eval { $C->assertGenerationAllowed($pending, 0, '/tmp/b71-overlay.txt') };
  like($@, qr{/tmp/b71-overlay\.txt}, 'the gate names the overlay actually in use');

  eval { $C->assertGenerationAllowed($pending, 0) };
  like($@, qr/\$GUS_HOME/, 'and falls back to the installed copy when none is named');
}

{
  # Approval gates the ACTION, not the CONSEQUENCE: an approved annotated prune
  # raises no pending decision, so it must not block and must still be shouted
  # -- that is the run most likely to be executed unread.
  my $approvedButCostly = {
    update          => [{abbrev => 'a'}],
    add_candidate   => [],
    rename          => [],
    prune_candidate => [{abbrev => 'cneoJEC21', approved => 1, annotation_count => 14}],
  };

  ok($C->assertGenerationAllowed($approvedButCostly, 0),
     'an approved annotated prune does not block generation');

  my $warning = $C->annotatedPruneWarning($approvedButCostly);
  like($warning, qr/cneoJEC21 \(14\)/,
       'but it is still reported, with its abbrev and annotation count');
  like($warning, qr/reversible/, 'and says unpublishing is reversible');

  ok(!defined $C->annotatedPruneWarning({prune_candidate => []}),
     'nothing is said when nothing is at stake');

  ok(defined $C->annotatedPruneWarning(
       {prune_candidate => [{abbrev => 'z', approved => 0, annotation_count => 2}]}),
     'an UNAPPROVED annotated prune is reported by the same path');
}

# --- the generation roster ---

my $RESULT = {
  update          => [{abbrev => 'tgonME49', organism => {abbrev => 'tgonME49'}},
                      {abbrev => 'pfal3D7',  organism => {abbrev => 'pfal3D7'}}],
  rename          => [{from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21',
                       organism => {abbrev => 'cdenJEC21'}}],
  add_candidate   => [{abbrev => 'hcapNAm1', approved => 1, organism => {abbrev => 'hcapNAm1'}},
                      {abbrev => 'nope',     approved => 0, organism => {abbrev => 'nope'}}],
  prune_candidate => [{abbrev => 'gone', approved => 1}],
  exception       => [{abbrev => 'tcruYC6', organism => {abbrev => 'tcruYC6'}}],
};

{
  my $roster = $C->generationRoster($RESULT, []);
  is_deeply([map { $_->{abbrev} } @$roster],
            [qw(cdenJEC21 hcapNAm1 pfal3D7 tgonME49)],
            'the roster is update + rename + APPROVED add, by public abbrev');
}

{
  my $roster = $C->generationRoster($RESULT, ['tgonME49', 'cdenJEC21']);
  is_deeply([map { $_->{abbrev} } @$roster], [qw(cdenJEC21 tgonME49)],
            '--organism narrows the roster, naming a rename by its NEW abbrev');
}

{
  # An unmatched --organism would otherwise generate an empty package and
  # report success -- the exact failure this tool exists to stop repeating.
  eval { $C->generationRoster($RESULT, ['tgonME49', 'wrongName']) };
  like($@, qr/wrongName/, 'an --organism that is in no bucket dies naming itself');

  eval { $C->generationRoster($RESULT, ['nope']) };
  like($@, qr/nope/, 'an UNAPPROVED add named by --organism is not silently generated');
}

{
  # --force used to carry its permission all the way through: an empty roster
  # wrote empty command files and exited 0, the silent empty release this tool
  # replaced.  The refusal is NOT force-able, so the signature is pinned too --
  # a later "consistency" fix adding a force argument turns this red.
  eval { $C->assertRosterNonEmpty([]) };
  like($@, qr/empty package/, 'an empty generation roster is refused, not generated');
  like($@, qr/--force/,       'and names the override that reached it');

  ok($C->assertRosterNonEmpty([{abbrev => 'a'}]), 'a non-empty roster passes');

  # The signature carries the guarantee: an extra argument cannot switch it off.
  eval { $C->assertRosterNonEmpty([], 1) };
  like($@, qr/empty package/, 'and no second argument can override it');
}

{
  my $narrowed = $C->narrowResult($RESULT, ['tgonME49', 'cdenJEC21']);
  is_deeply([map { $_->{abbrev} }      @{$narrowed->{update}}], ['tgonME49'], 'updates narrowed');
  is_deeply([map { $_->{to_abbrev} }   @{$narrowed->{rename}}], ['cdenJEC21'], 'renames narrowed');
  is(scalar @{$narrowed->{add_candidate}},   0, 'unselected adds dropped from the commands');
  is(scalar @{$narrowed->{prune_candidate}}, 0, 'unselected prunes dropped from the commands');
}

{
  # The POSITIVE half: the case above is satisfied just as well by a filter
  # hardcoded to return nothing, which would silently drop a curator-approved
  # addition while the package still builds and reports success.  So require
  # that a named add and prune both SURVIVE, with the unselected add gone.
  my $narrowed = $C->narrowResult($RESULT, ['hcapNAm1', 'gone']);

  is_deeply([map { $_->{abbrev} } @{$narrowed->{add_candidate}}], ['hcapNAm1'],
            'a selected add candidate survives narrowing, and only it');
  is_deeply([map { $_->{abbrev} } @{$narrowed->{prune_candidate}}], ['gone'],
            'a selected prune candidate survives narrowing');
  ok($narrowed->{add_candidate}[0]{approved},
     'carried whole, approval flag included -- writeCommandFiles reads it');
  is_deeply([map { $_->{abbrev} }    @{$narrowed->{update}}], [],
            'and the buckets nobody named are emptied');
  is_deeply([map { $_->{to_abbrev} } @{$narrowed->{rename}}], [],
            'renames too');
}

# --- rename resolution: the database first, assembly identity as a fallback ---

sub _p {
  my ($abbrev, $internal, %extra) = @_;
  return {abbrev => $abbrev, internal_abbrev => $internal, name => $abbrev,
          name_for_filenames => $abbrev, strain_abbrev => 'S', %extra};
}

{
  # The two cases seen in the live data.
  my $portal = {
    cdenJEC21  => _p('cdenJEC21',  'cneoJEC21'),
    nglaCBS138 => _p('nglaCBS138', 'cglaCBS138'),
    tgonME49   => _p('tgonME49',   'tgonME49'),
  };
  my $live = {tgonME49 => {}, cneoJEC21 => {}, cglaCBS138 => {}};

  my $r = $C->resolveRenames($portal, $live, {});

  is_deeply($r->{renames}, {cneoJEC21 => 'cdenJEC21', cglaCBS138 => 'nglaCBS138'},
            'both live renames resolve from the database alone');
  is($r->{mechanism}{cneoJEC21}, 'database', 'and are recorded as database-resolved');
  is_deeply($r->{unresolved}, [], 'nothing is left for the assembly fallback');
}

{
  # Abbrevs differing only in case are DIFFERENT organisms, and such collisions
  # exist in the namespace, so a lc() anywhere in this path merges two genomes.
  my $portal = {scerS288c => _p('scerS288c', 'scerS288C')};
  my $live   = {scerS288C => {}};

  my $r = $C->resolveRenames($portal, $live, {});
  is_deeply($r->{renames}, {scerS288C => 'scerS288c'},
            'a case-only rename is detected -- the comparison is exact, not folded');
}

{
  # The other half of case sensitivity: an abbrev that differs only by case
  # from a portal organism, with NO internal-abbrev link, is not a rename.
  my $portal = {bnonp57 => _p('bnonp57', 'bnonp57')};
  my $live   = {bnonP57 => {}};

  # ONE assertion over both halves on purpose: split, the renames check passes
  # under an lc() mutation for the WRONG reason, since folding case stops it
  # being an orphan at all.  Only the pair discriminates.
  my $r = $C->resolveRenames($portal, $live, {});
  is_deeply({renames => $r->{renames}, unresolved => $r->{unresolved}},
            {renames => {},            unresolved => ['bnonP57']},
            'a case-insensitive near-match is neither renamed nor absorbed: it stays an orphan');
}

{
  # An organism whose internal abbrev equals its public one cannot explain an
  # orphan.  This holds STRUCTURALLY, not by a filter -- such an entry's key is
  # itself a public abbrev -- so assert the whole outcome, not a branch.
  my $portal = {aaa => _p('aaa', 'aaa')};
  my $live   = {bbb => {}};
  my $r = $C->resolveRenames($portal, $live, {});
  is_deeply({renames => $r->{renames}, unresolved => $r->{unresolved}},
            {renames => {},            unresolved => ['bbb']},
            'a self-referential portal organism is never a rename source');
}

{
  # Two portal organisms sharing one internal abbrev does NOT occur in the live
  # data, which is why a test is the only thing keeping the guard honest.
  my $portal = {aa => _p('aa', 'shared'), bb => _p('bb', 'shared')};
  my $live   = {shared => {}};

  my $r = $C->resolveRenames($portal, $live, {});

  is_deeply({renames => $r->{renames}, unresolved => $r->{unresolved}},
            {renames => {},            unresolved => ['shared']},
            'a duplicated internal abbrev resolves to NEITHER organism');
  like(join('', @{$r->{warnings}}), qr/belongs to more than one portal organism/,
       'and the ambiguity is reported rather than silently decided');
  like(join('', @{$r->{warnings}}), qr/\baa\b.*\bbb\b|\bbb\b.*\baa\b/,
       'naming both claimants');
}

{
  # Repointing onto an abbrev Apollo already holds is a merge; Reconcile would
  # die on it.  Decline here, with a warning, so the release still reports.
  my $portal = {cdenJEC21 => _p('cdenJEC21', 'cneoJEC21')};
  my $live   = {cneoJEC21 => {}, cdenJEC21 => {}};

  my $r = $C->resolveRenames($portal, $live, {});
  is_deeply($r->{renames}, {}, 'a rename onto an abbrev already in Apollo is declined');
  like(join('', @{$r->{warnings}}), qr/already in Apollo/, 'and is reported, not swallowed');
}

{
  # Silence when the fallback cannot run would read as "the database says it is
  # not a rename", a different and much stronger claim.
  my $portal = {aaa => _p('aaa', 'aaa')};
  my $live   = {orphan1 => {}};

  my $r = $C->resolveRenames($portal, $live, {});
  is_deeply($r->{unresolved}, ['orphan1'], 'the orphan is unresolved');
  like(join('', @{$r->{warnings}}), qr/--previous-release/,
       'and the report says why the fallback did not run');
}

{
  # The assembly fallback, exercised through Rename.pm's own coderef seams.
  my $dir = tempdir(CLEANUP => 1);

  my $prev = "$dir/prev";  mkdir $prev;
  my $cur  = "$dir/cur";   mkdir $cur;

  _write("$prev/orphan1.fai", "chr1\t100\t0\t60\t61\nchr2\t200\t0\t60\t61\n");
  _write("$cur/newname.fai",  "chr1\t100\t9\t70\t71\nchr2\t200\t9\t70\t71\n");
  _write("$cur/other.fai",    "chrX\t999\t0\t60\t61\n");

  my $portal = {newname => _p('newname', 'newname'), other => _p('other', 'other')};
  my $live   = {orphan1 => {}};

  my $r = $C->resolveRenames($portal, $live, {
    previous_release => $prev,
    previousFai      => sub { "$prev/$_[0].fai" },
    currentFai       => sub { "$cur/$_[0]{abbrev}.fai" },
  });

  is_deeply($r->{renames}, {orphan1 => 'newname'},
            'an orphan the database cannot explain is resolved by assembly identity');
  is($r->{mechanism}{orphan1}, 'assembly', 'and is recorded as assembly-resolved');
  is_deeply($r->{unresolved}, [], 'nothing left over');
}

{
  # Rename.pm collects warnings rather than printing them; the CLI must
  # surface them or an unreadable index looks like a genome that changed.
  my $dir = tempdir(CLEANUP => 1);
  my $prev = "$dir/prev"; mkdir $prev;
  _write("$prev/orphan1.fai", "chr1\t100\n");

  my $portal = {newname => _p('newname', 'newname')};
  my $live   = {orphan1 => {}};

  my $r = $C->resolveRenames($portal, $live, {
    previous_release => $prev,
    previousFai      => sub { "$prev/$_[0].fai" },
    currentFai       => sub { "$dir/missing/$_[0]{abbrev}.fai" },
  });

  is_deeply($r->{renames}, {}, 'no rename when nothing could be compared');
  like(join('', @{$r->{warnings}}), qr/NOT evidence/,
       "and Rename's own warning is surfaced verbatim");
}

{
  # One target, one source, on both paths: two orphans landing on one portal
  # organism would make Reconcile die, so catch it where it can be explained.
  my $dir = tempdir(CLEANUP => 1);
  my $prev = "$dir/prev"; mkdir $prev;
  my $cur  = "$dir/cur";  mkdir $cur;
  _write("$prev/orphanA.fai", "chr1\t100\n");
  _write("$prev/orphanB.fai", "chr1\t100\n");
  _write("$cur/newname.fai",  "chr1\t100\n");

  my $portal = {newname => _p('newname', 'newname')};
  my $live   = {orphanA => {}, orphanB => {}};

  my $r = $C->resolveRenames($portal, $live, {
    previous_release => $prev,
    previousFai      => sub { "$prev/$_[0].fai" },
    currentFai       => sub { "$cur/$_[0]{abbrev}.fai" },
  });

  is(scalar(keys %{$r->{renames}}), 1, 'only one of two claimants is accepted');
  like(join('', @{$r->{warnings}}), qr/already the rename target|two organisms/i,
       'and the loser is reported rather than dropped');
}

{
  # The merge refusal on the ASSEMBLY route, which must reach the same answer as
  # the database route above: two Apollo organisms sharing one directory is what
  # Apollo.pm refuses to load on the NEXT release, so the damage surfaces a
  # release late on a run that did nothing wrong.
  #
  # The database route cannot stand in -- it declines before the fallback runs.
  # Reaching this branch needs an orphan with no internal-abbrev link (hence the
  # self-referential portal entries) whose assembly matches a live organism.
  my $dir = tempdir(CLEANUP => 1);
  my $prev = "$dir/prev"; mkdir $prev;
  my $cur  = "$dir/cur";  mkdir $cur;
  _write("$prev/orphan1.fai", "chr1\t100\t0\t60\t61\nchr2\t200\t0\t60\t61\n");
  _write("$cur/newname.fai",  "chr1\t100\t9\t70\t71\nchr2\t200\t9\t70\t71\n");

  my $portal = {newname => _p('newname', 'newname')};
  my $live   = {orphan1 => {}, newname => {}};

  my $r = $C->resolveRenames($portal, $live, {
    previous_release => $prev,
    previousFai      => sub { "$prev/$_[0].fai" },
    currentFai       => sub { "$cur/$_[0]{abbrev}.fai" },
  });

  # One outcome, because performing the rename would both add it and consume the
  # orphan -- either half alone leaves the other free to be wrong.
  is_deeply({renames => $r->{renames}, mechanism => $r->{mechanism},
             unresolved => $r->{unresolved}},
            {renames => {}, mechanism => {}, unresolved => ['orphan1']},
            'an assembly-matched rename onto an abbrev already in Apollo is declined, '
            . 'and the orphan stays a prune candidate');
  like(join('', @{$r->{warnings}}), qr/assembly matches 'newname'/,
       'the warning names the match the assembly comparison actually found');
  like(join('', @{$r->{warnings}}), qr/already in Apollo/,
       'and says why it was refused rather than swallowing it');
}

# --- the installed script answers --help with nothing set ---

{
  my $script = "$ENV{GUS_HOME}/bin/createApolloReleasePackage";
  ok(-x $script, 'the CLI is installed and executable');

  my $help = `env -u APOLLO_API_USER -u APOLLO_API_PASS -u GUS_HOME PERL5LIB=$ENV{GUS_HOME}/lib/perl $script --help 2>&1`;
  is($? >> 8, 0, '--help exits 0 with no GUS_HOME and no credentials');
  like($help, qr/--generate/, 'and describes the phases');

  my $bad = `env -u APOLLO_API_USER -u APOLLO_API_PASS -u GUS_HOME PERL5LIB=$ENV{GUS_HOME}/lib/perl $script --report 2>&1`;
  isnt($? >> 8, 0, 'a missing --build exits non-zero');
  like($bad, qr/--build/, 'and says which option is missing, without asking for credentials');
  unlike($bad, qr/APOLLO_API/, 'the credential check never ran');
}

sub _write {
  my ($path, $text) = @_;
  open(my $fh, '>', $path) or die "$path: $!";
  print $fh $text;
  close $fh;
}

done_testing();
