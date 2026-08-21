# Apollo Release Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Paul Wilkinson's broken `createApolloReleasePackage_ALL.pl` with a maintained tool in `ApiCommonModel` that generates the Apollo release package from the UniDB portal on cedar, seeded from live prod Apollo.

**Architecture:** A thin CLI (`Model/bin/createApolloReleasePackage`) over five focused Perl modules under `Model/lib/perl/ApolloRelease/`. Reconciliation (pure set logic over hashrefs) is separated from generation (filesystem + subprocess) so the former is unit-testable against fixtures with no database, no network, and no `GUS_HOME`. The tool computes five buckets, reports them, and — only for an approved roster — generates per-organism data dirs plus Apollo command files. It never mutates Apollo.

**Tech Stack:** Perl 5 (`Test::More`, `prove`), `JSON`, `LWP::UserAgent`, the existing `ApiCommonModel::Model::JBrowseUtil` and `Model/bin/jbrowse*` scripts, UCSC `faToTwoBit`.

**Spec:** `docs/superpowers/specs/2026-08-21-apollo-release-package-design.md`. Read it first; this plan assumes its facts and does not re-derive them.

---

## Environment and conventions

Everything runs on **cedar**, against the **eupathdb** instance, model **UniDB**.

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && <command>"'
```

Local edits are made in `~/workspaces/eupathdb/ApiCommonModel` and reach cedar via mutagen.
**Do not create a git worktree** — mutagen syncs only the instance directory, so a worktree
elsewhere is invisible to cedar and every build would test stale code.

Install after each change to `Model/`:

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model"'
```

`bld` takes ~13 s. Do **not** run `wb model` — it OOMs on the UniDB portal.

Module naming: `Model/lib/perl/ApolloRelease/Foo.pm` installs to
`$GUS_HOME/lib/perl/ApiCommonModel/Model/ApolloRelease/Foo.pm` and declares
`package ApiCommonModel::Model::ApolloRelease::Foo;`.

Tests live in `Model/t/`, use `Test::More`, and run against the **installed** copy:

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/<name>.t"'
```

So the loop for every task is: edit → `bld` → `prove`.

There are no existing Perl tests in this repo; `Model/t/` is new. Fixtures live in
`Model/t/fixtures/` and are committed — they are small JSON files, and they are what makes
reconciliation testable without a database.

**Branch:** `feat/apollo-configs`, already created, already carrying the
`jbrowseOrganismList` compile fix and the spec.

---

## File structure

| File | Responsibility |
|---|---|
| `Model/bin/jbrowseOrganismList` | *(modify)* fix the history join and the Oracle-cased keys |
| `Model/lib/perl/ApolloRelease/Portal.pm` | Run `jbrowseOrganismList`, normalise to organism hashrefs, expose `latest_annotation_version` |
| `Model/lib/perl/ApolloRelease/Apollo.pm` | Fetch live Apollo organisms, parse `abbrev` from `directory`, flag `commonName` disagreement |
| `Model/lib/perl/ApolloRelease/Overlay.pm` | Parse and validate `roster-overlay.txt` |
| `Model/lib/perl/ApolloRelease/Reconcile.pm` | Pure set logic: five buckets, rename detection, invariant enforcement |
| `Model/lib/perl/ApolloRelease/Report.pm` | Render the buckets as `report.txt` |
| `Model/lib/perl/ApolloRelease/Absolutize.pm` | `/a/` → `https://veupathdb.org/a/` plus the no-bare-`/a/` assertion |
| `Model/lib/perl/ApolloRelease/Generate.pm` | Per-organism file generation; per-organism failure isolation |
| `Model/lib/perl/ApolloRelease/Commands.pm` | Emit `Apollo_curl` / `Apollo_groovy` |
| `Model/bin/createApolloReleasePackage` | CLI: option parsing, preflight, wiring, exit status |
| `Model/data/apollo/roster-overlay.txt` | The seeded overlay |
| `Model/t/*.t` | Tests |

Reconcile, Overlay, Absolutize, and Report have no I/O beyond their arguments. Portal,
Apollo, Generate, and Commands are the only modules that touch the world.

---

## Task 1: Finish fixing `jbrowseOrganismList`

The compile error is already fixed. Two defects remain, and `HISTORY` — which supplies the
annotation version in every Apollo organism name — is silently absent until both are done.

**Files:**
- Modify: `Model/bin/jbrowseOrganismList:30-36` (the `$historySql`), `:60-70` (`addHistoryToOrganism`)

- [ ] **Step 1: Confirm the current failure**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && \
  perl \$GUS_HOME/bin/jbrowseOrganismList UniDB > /tmp/ol.json 2>/tmp/ol.err; \
  echo rc=\$?; head -3 /tmp/ol.err; \
  python3 -c \"import json;d=json.load(open('/tmp/ol.json'))['organisms'];print('organisms',len(d));print('with HISTORY',sum(1 for o in d if 'HISTORY' in o or 'history' in o))\""'
```

Expected: `rc=0`, stderr containing `missing FROM-clause entry for table "nt"`,
`organisms 831`, `with HISTORY 0`. The zero is the bug: the script succeeds while producing
incomplete data.

- [ ] **Step 2: Fix the history query's join**

In `Model/bin/jbrowseOrganismList`, replace the `$historySql` assignment with:

```perl
my $historySql = "select h.build_number, o.public_abbrev, h.genome_source, h.genome_version, h.annotation_source, h.annotation_version
        from apidbtuning.datasethistory h, apidbtuning.datasetdatasource dd, apidb.organism o
        where h.dataset_presenter_id = dd.dataset_presenter_id
        and dd.name like '%primary_genome_RSRC'
        and h.annotation_version is not null
        and dd.taxon_id = o.taxon_id";
```

The only change is the last line: `o.taxon_id = nt.taxon_id` → `dd.taxon_id = o.taxon_id`.
`nt` was never in the FROM clause; `datasetdatasource.taxon_id` is the real link to
`apidb.organism`.

- [ ] **Step 3: Fix the Oracle-cased hash keys**

`DBD::Pg` returns lowercase column names; `DBD::Oracle` returned uppercase. Replace
`addHistoryToOrganism` with:

```perl
sub addHistoryToOrganism {
  my ($h, $orgs) = @_;
  my $publicAbbrev = $h->{public_abbrev};
  foreach(@$orgs) {

    if($_->{organism_abbrev} eq $publicAbbrev) {
      push @{$_->{history}}, $h;
      return;
    }
  }
  die "Could not match organism abbrev $publicAbbrev";
}
```

Note the pushed key is now `history`, matching the lowercase convention of every other key
the script emits. Consumers in this plan read `history`.

- [ ] **Step 4: Install and verify**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && \
  perl \$GUS_HOME/bin/jbrowseOrganismList UniDB > /tmp/ol.json 2>/tmp/ol.err; \
  echo rc=\$?; echo err_bytes=\$(stat -c%s /tmp/ol.err); \
  python3 -c \"import json;d=json.load(open('/tmp/ol.json'))['organisms'];print('organisms',len(d));print('with history',sum(1 for o in d if o.get('history')));import collections;o=[x for x in d if x['organism_abbrev']=='tgonME49'][0];print('tgonME49 history rows',len(o['history']));print(o['history'][0])\""'
```

Expected: `rc=0`, **`err_bytes=0`**, `organisms 831`, `with history` well above 0, and a
sample history row containing `build_number` and `annotation_version`.

`err_bytes=0` is the real assertion. This script is served through
`responseFromCommand`, which merges stderr into the JSON response body — so any warning
here becomes a corrupt API response, not just noise.

- [ ] **Step 5: Save a fixture for later tasks**

```bash
ssh cedar 'python3 -c "
import json
d=json.load(open(\"/tmp/ol.json\"))[\"organisms\"]
keep={\"tgonME49\",\"pfal3D7\",\"cdenJEC21\",\"nglaCBS138\",\"hcapNAm1\",\"hsapREF\",\"tbruLister427_2018\",\"tbruTREU927\"}
out=[o for o in d if o[\"organism_abbrev\"] in keep]
json.dump({\"organisms\":out}, open(\"/tmp/portal_fixture.json\",\"w\"), indent=1)
print(len(out))
"'
scp cedar:/tmp/portal_fixture.json ~/workspaces/eupathdb/ApiCommonModel/Model/t/fixtures/portal.json
```

Expected: `8`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/bin/jbrowseOrganismList Model/t/fixtures/portal.json
git commit -m "fix(jbrowse): repair organismList history query and Postgres key casing

The history query joined to an alias 'nt' absent from its FROM clause,
so it threw while the script still exited 0 and printed JSON with no
history. addHistoryToOrganism then read Oracle-cased keys that DBD::Pg
returns lowercase. Together these meant HISTORY was always missing, and
with it the annotation version every Apollo organism name depends on."
```

---

## Task 2: `ApolloRelease::Portal`

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Portal.pm`
- Create: `Model/t/portal.t`

- [ ] **Step 1: Write the failing test**

Create `Model/t/portal.t`:

```perl
use strict;
use warnings;
use Test::More tests => 9;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Portal;

my $P = 'ApiCommonModel::Model::ApolloRelease::Portal';

my $orgs = $P->loadFromFile("Model/t/fixtures/portal.json");

is(ref($orgs), 'HASH', 'returns a hash keyed by abbrev');
ok(exists $orgs->{tgonME49}, 'tgonME49 present');

my $t = $orgs->{tgonME49};
is($t->{abbrev}, 'tgonME49', 'abbrev normalised');
is($t->{name_for_filenames}, 'TgondiiME49', 'name_for_filenames carried');
is($t->{is_reference}, 1, 'is_reference is a boolean, not a string');
is($t->{is_annotated}, 1, 'is_annotated is a boolean, not a string');

my $b = $orgs->{tbruLister427_2018};
is($b->{is_reference}, 0, 'non-reference strain is 0');

ok(defined $t->{latest_annotation_version}, 'latest annotation version derived');
is($P->qualifies($b), 0, 'non-reference organism does not qualify');
```

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/portal.t"'
```

Expected: FAIL — `Can't locate ApiCommonModel/Model/ApolloRelease/Portal.pm`.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Portal.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Portal;

use strict;
use warnings;

use JSON;

# Reads the organism list produced by Model/bin/jbrowseOrganismList and
# normalises it.  Keys arrive lowercase from DBD::Pg; booleans arrive as the
# strings "1"/"0".  Everything downstream sees plain 0/1 and a single
# `abbrev` key.

sub loadFromCommand {
  my ($class, $projectName) = @_;

  my $gusHome = $ENV{GUS_HOME} or die "GUS_HOME is not set\n";
  my $cmd = "$gusHome/bin/jbrowseOrganismList $projectName";

  my $json = `$cmd 2>/tmp/apolloRelease.organismList.err`;
  die "jbrowseOrganismList failed (exit " . ($? >> 8) . "); see /tmp/apolloRelease.organismList.err\n"
    if $?;

  my $errSize = -s "/tmp/apolloRelease.organismList.err" || 0;
  die "jbrowseOrganismList wrote $errSize bytes to stderr; refusing to trust its output.\n"
    . "See /tmp/apolloRelease.organismList.err\n"
    if $errSize;

  return $class->_normalise(decode_json($json));
}

sub loadFromFile {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or die "Cannot read $path: $!";
  local $/;
  my $json = <$fh>;
  close $fh;

  return $class->_normalise(decode_json($json));
}

sub _normalise {
  my ($class, $decoded) = @_;

  my %byAbbrev;

  foreach my $raw (@{$decoded->{organisms}}) {
    my $abbrev = $raw->{organism_abbrev};

    $byAbbrev{$abbrev} = {
      abbrev                    => $abbrev,
      name                      => $raw->{name},
      name_for_filenames        => $raw->{name_for_filenames},
      strain_abbrev             => $raw->{strain_abbrev},
      species_taxon             => $raw->{species_ncbi_tax_id},
      is_reference              => $raw->{is_reference_strain} ? 1 : 0,
      is_annotated              => $raw->{is_annotated_genome} ? 1 : 0,
      history                   => $raw->{history} || [],
      latest_annotation_version => $class->_latestAnnotationVersion($raw->{history}),
    };
  }

  return \%byAbbrev;
}

# The annotation version belonging to the highest build number.  Apollo names
# an organism "<full name> [<annotation version>]", so this string is part of
# the organism's identity there.
sub _latestAnnotationVersion {
  my ($class, $history) = @_;

  return undef unless $history && @$history;

  my $best;
  foreach my $h (@$history) {
    next unless defined $h->{annotation_version};
    $best = $h if !$best || $h->{build_number} > $best->{build_number};
  }

  return $best ? $best->{annotation_version} : undef;
}

sub qualifies {
  my ($class, $organism) = @_;
  return ($organism->{is_reference} && $organism->{is_annotated}) ? 1 : 0;
}

1;
```

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/portal.t"'
```

Expected: `All tests successful.` — 9 passing.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Portal.pm Model/t/portal.t
git commit -m "feat(apollo): add Portal module for the UniDB organism list"
```

---

## Task 3: `ApolloRelease::Apollo`

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Apollo.pm`
- Create: `Model/t/apollo.t`
- Create: `Model/t/fixtures/apollo.json`

- [ ] **Step 1: Create the fixture**

Create `Model/t/fixtures/apollo.json` — a trimmed, realistic slice of
`POST /organism/findAllOrganisms`:

```json
[
 {"id": 1484940, "commonName": "Toxoplasma gondii ME49 [Jul 01, 2023]",
  "directory": "/data/apollo_data/tgonME49",
  "blatdb": "/data/apollo_data/twoBit/tgonME49.2bit",
  "annotationCount": 10, "publicMode": true},
 {"id": 2452162, "commonName": "Cryptococcus neoformans var. neoformans JEC21 [Jun 16, 2016]",
  "directory": "/data/apollo_data/cneoJEC21",
  "blatdb": "/data/apollo_data/twoBit/cneoJEC21.2bit",
  "annotationCount": 14, "publicMode": true},
 {"id": 5146948, "commonName": "Candida glabrata CBS 138 [s02-m07-r27]",
  "directory": "/data/apollo_data/cglaCBS138",
  "blatdb": "/data/apollo_data/twoBit/cglaCBS138.2bit",
  "annotationCount": 0, "publicMode": false},
 {"id": 9000001, "commonName": "Trypanosoma brucei Lister strain 427 2018 [May 01, 2019]",
  "directory": "/data/apollo_data/tbruLister427_2018",
  "blatdb": "/data/apollo_data/twoBit/tbruLister427_2018.2bit",
  "annotationCount": 3, "publicMode": true},
 {"id": 9000002, "commonName": "Something Renamed In The Gui",
  "directory": "/data/apollo_data/pfal3D7",
  "blatdb": "/data/apollo_data/twoBit/pfal3D7.2bit",
  "annotationCount": 3, "publicMode": true}
]
```

- [ ] **Step 2: Write the failing test**

Create `Model/t/apollo.t`:

```perl
use strict;
use warnings;
use Test::More tests => 8;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Apollo;

my $A = 'ApiCommonModel::Model::ApolloRelease::Apollo';

my $live = $A->loadFromFile("Model/t/fixtures/apollo.json");

is(ref($live), 'HASH', 'returns a hash keyed by abbrev');
is(scalar(keys %$live), 5, 'all five organisms parsed');

my $t = $live->{tgonME49};
is($t->{id}, 1484940, 'numeric id carried');
is($t->{annotation_count}, 10, 'annotation count carried');
is($t->{abbrev}, 'tgonME49', 'abbrev parsed from directory');

my $c = $live->{cneoJEC21};
is($c->{annotation_count}, 14, 'the organism we must not lose is parsed');

# commonName is curator-editable, so it is cross-checked, never matched on.
is($A->commonNameDisagrees($live->{pfal3D7}, 'Plasmodium falciparum 3D7'), 1,
   'GUI-edited common name is flagged');
is($A->commonNameDisagrees($live->{tgonME49}, 'Toxoplasma gondii ME49'), 0,
   'matching common name is not flagged');
```

- [ ] **Step 3: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/apollo.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 4: Implement**

Create `Model/lib/perl/ApolloRelease/Apollo.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Apollo;

use strict;
use warnings;

use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

# Reads the live prod Apollo organism roster.  This is the SEED for the
# release roster -- it is the only record of what curators actually decided.
#
# Organisms are keyed by the abbrev parsed out of `directory`, never by
# commonName: `directory` is machine-written by our own update commands,
# while commonName is editable in the Apollo GUI.

sub loadFromApi {
  my ($class) = @_;

  my $url  = $ENV{APOLLO_API_URL}  || 'https://apollo-api.veupathdb.org';
  my $user = $ENV{APOLLO_API_USER} or die "APOLLO_API_USER is not set\n";
  my $pass = $ENV{APOLLO_API_PASS} or die "APOLLO_API_PASS is not set\n";

  my $agent = LWP::UserAgent->new(timeout => 900);
  my $response = $agent->request(
    POST "$url/organism/findAllOrganisms",
    Content_Type => 'form-data',
    Content      => [username => $user, password => $pass],
  );

  die "Apollo API request failed: " . $response->status_line . "\n"
    unless $response->is_success;

  my $decoded = decode_json($response->content);

  # An empty roster would make every organism look new, and the generated
  # commands would try to re-add the entire set.  Fail instead.
  die "Apollo returned no organisms from $url.\n"
    . "Check APOLLO_API_USER/PASS, and check that you are running this on a\n"
    . "Penn host -- the API is IP-restricted.\n"
    unless @$decoded;

  return $class->_normalise($decoded);
}

sub loadFromFile {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or die "Cannot read $path: $!";
  local $/;
  my $json = <$fh>;
  close $fh;

  return $class->_normalise(decode_json($json));
}

sub _normalise {
  my ($class, $decoded) = @_;

  my %byAbbrev;

  foreach my $raw (@$decoded) {
    my $directory = $raw->{directory} || '';
    $directory =~ s{/+$}{};

    my ($abbrev) = $directory =~ m{([^/]+)$};

    unless ($abbrev) {
      warn "Apollo organism id $raw->{id} has an unparseable directory '$raw->{directory}'; skipping\n";
      next;
    }

    $byAbbrev{$abbrev} = {
      abbrev           => $abbrev,
      id               => $raw->{id},
      common_name      => $raw->{commonName},
      directory        => $raw->{directory},
      blatdb           => $raw->{blatdb},
      annotation_count => $raw->{annotationCount} || 0,
      public_mode      => $raw->{publicMode} ? 1 : 0,
    };
  }

  return \%byAbbrev;
}

# Apollo names an organism "<full name> [<annotation version>]".  Compare only
# the part before the bracket.
sub commonNameDisagrees {
  my ($class, $apolloOrganism, $portalName) = @_;

  my $live = $apolloOrganism->{common_name} || '';
  $live =~ s{\s*\[[^\]]*\]\s*$}{};

  return ($live eq $portalName) ? 0 : 1;
}

1;
```

- [ ] **Step 5: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/apollo.t"'
```

Expected: 8 passing.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Apollo.pm Model/t/apollo.t Model/t/fixtures/apollo.json
git commit -m "feat(apollo): add Apollo module for the live prod roster"
```

---

## Task 4: `ApolloRelease::Overlay` and the seeded roster file

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Overlay.pm`
- Create: `Model/data/apollo/roster-overlay.txt`
- Create: `Model/t/overlay.t`

- [ ] **Step 1: Write the failing test**

Create `Model/t/overlay.t`:

```perl
use strict;
use warnings;
use Test::More tests => 7;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Overlay;

my $O = 'ApiCommonModel::Model::ApolloRelease::Overlay';

my $text = <<'OVERLAY';
# comment line, ignored
remove hsapREF          # host genome; Apollo curates pathogens

add    someNewOrg       # approved by Uli 2026-08-21
OVERLAY

my $overlay = $O->parseString($text);

is_deeply([sort keys %{$overlay->{remove}}], ['hsapREF'], 'remove parsed');
is_deeply([sort keys %{$overlay->{add}}],    ['someNewOrg'], 'add parsed');
like($overlay->{remove}{hsapREF}, qr/host genome/, 'reason retained');
like($overlay->{add}{someNewOrg}, qr/Uli/, 'approver retained');

eval { $O->parseString("bogus hsapREF # what\n") };
like($@, qr/unknown directive 'bogus'/, 'unknown directive rejected');

eval { $O->parseString("add hsapREF # x\nremove hsapREF # y\n") };
like($@, qr/both add and remove/, 'contradictory entry rejected');

eval { $O->parseString("add\n") };
like($@, qr/missing organism/, 'malformed line rejected');
```

A reason is *required*, and contradictions are fatal. The overlay is the only written record
of a curation decision, so a line without provenance defeats the point of having the file.

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/overlay.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Overlay.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Overlay;

use strict;
use warnings;

# The human decisions layered over the live Apollo roster:
#
#   add    <abbrev>   # who approved it, when, why
#   remove <abbrev>   # who approved it, when, why
#
# The reason is mandatory.  This file exists to record provenance; a line
# without it is indistinguishable from the hardcoded __DATA__ block this
# replaces.

sub parseFile {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or die "Cannot read roster overlay $path: $!";
  local $/;
  my $text = <$fh>;
  close $fh;

  return $class->parseString($text);
}

sub parseString {
  my ($class, $text) = @_;

  my %overlay = (add => {}, remove => {});
  my $lineNumber = 0;

  foreach my $line (split /\n/, $text) {
    $lineNumber++;

    next if $line =~ /^\s*$/;
    next if $line =~ /^\s*#/;

    my ($directive, $abbrev, $reason) =
      $line =~ /^\s*(\S+)\s+(\S+)\s*#\s*(.+?)\s*$/;

    unless (defined $directive) {
      my ($lone) = $line =~ /^\s*(\S+)\s*$/;
      die "roster overlay line $lineNumber: missing organism or reason: '$line'\n"
        if $lone;
      die "roster overlay line $lineNumber: every entry needs a '# reason': '$line'\n";
    }

    die "roster overlay line $lineNumber: unknown directive '$directive' (expected add or remove)\n"
      unless $directive eq 'add' || $directive eq 'remove';

    my $other = $directive eq 'add' ? 'remove' : 'add';
    die "roster overlay line $lineNumber: $abbrev is listed as both add and remove\n"
      if exists $overlay{$other}{$abbrev};

    $overlay{$directive}{$abbrev} = $reason;
  }

  return \%overlay;
}

1;
```

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/overlay.t"'
```

Expected: 7 passing.

- [ ] **Step 5: Create the seeded overlay**

Create `Model/data/apollo/roster-overlay.txt`. Per spec §3, the 15 pre-b68 qualifying
organisms absent from Apollo are **not** one group — `hcapNAm1` is deliberately omitted from
this file so it surfaces as an add candidate:

```
# Roster overlay for the Apollo release package.
#
# The roster is seeded from LIVE PROD APOLLO.  This file records the human
# decisions layered on top of it.  Every line needs a reason: this file is the
# only written record of why an organism is or is not in Apollo.
#
#   add    <organismAbbrev>   # who approved, when, why
#   remove <organismAbbrev>   # who approved, when, why

# --- Host genomes -------------------------------------------------------
# Apollo curates pathogens.  Paul's script excluded these implicitly, via an
# @databases array that omitted HostDB and SchistoDB.  On the UniDB portal
# that filter does not exist, so the exclusion has to be stated.

remove hsapREF                  # host genome (seeded 2026-08-21 from b68 behaviour)
remove mmusC57BL6J              # host genome (seeded 2026-08-21 from b68 behaviour)
remove rnorBNNHsdMcwi           # host genome (seeded 2026-08-21 from b68 behaviour)
remove btauHereford             # host genome (seeded 2026-08-21 from b68 behaviour)
remove clupfamiliarisSID07034   # host genome (seeded 2026-08-21 from b68 behaviour)
remove ggalbGalGal1             # host genome (seeded 2026-08-21 from b68 behaviour)
remove cpor2N                   # host genome (seeded 2026-08-21 from b68 behaviour)
remove mfasREF                  # host genome (seeded 2026-08-21 from b68 behaviour)
remove mmulAG07107              # host genome (seeded 2026-08-21 from b68 behaviour)
remove mmyomMyoMyo1             # host genome (seeded 2026-08-21 from b68 behaviour)
remove dmeliso-1                # host genome (seeded 2026-08-21 from b68 behaviour)

# --- Model fungi --------------------------------------------------------
# In FungiDB, qualify on the criteria, never been in Apollo.  Seeded to match
# existing behaviour, but nobody has consciously decided this -- raise with the
# curation team.

remove scerS288C                # model organism, never in Apollo; decision unconfirmed
remove spom972h                 # model organism, never in Apollo; decision unconfirmed

# --- Deliberately NOT listed here ---------------------------------------
# hcapNAm1 (Histoplasma mississippiense NAm1) is a FungiDB pathogen that
# qualifies and is absent from Apollo.  It is left in the add-candidate bucket
# for the curation team rather than suppressed here.
```

- [ ] **Step 6: Verify the seeded file parses**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && \
  perl -Mlib=\$GUS_HOME/lib/perl -MApiCommonModel::Model::ApolloRelease::Overlay -e '
    my \$o = ApiCommonModel::Model::ApolloRelease::Overlay->parseFile(\$ENV{GUS_HOME}.\"/data/ApiCommonModel/Model/apollo/roster-overlay.txt\");
    printf(\"removes=%d adds=%d\n\", scalar(keys %{\$o->{remove}}), scalar(keys %{\$o->{add}}));
    die \"hcapNAm1 must NOT be suppressed\n\" if \$o->{remove}{hcapNAm1};
    print \"hcapNAm1 correctly left as an add candidate\n\";
  '"'
```

Expected: `removes=13 adds=0` and the `hcapNAm1` line.

- [ ] **Step 7: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Overlay.pm Model/t/overlay.t Model/data/apollo/roster-overlay.txt
git commit -m "feat(apollo): add roster overlay parser and seeded overlay file"
```

---

## Task 5: `ApolloRelease::Reconcile` — buckets

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Reconcile.pm`
- Create: `Model/t/reconcile.t`

This module is pure: hashrefs in, hashrefs out. No database, no network, no filesystem —
which is why the whole decision layer can be tested from fixtures.

- [ ] **Step 1: Write the failing test**

Create `Model/t/reconcile.t`:

```perl
use strict;
use warnings;
use Test::More tests => 12;
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
```

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/reconcile.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Reconcile.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Reconcile;

use strict;
use warnings;

use ApiCommonModel::Model::ApolloRelease::Portal;

# Pure set logic over the three inputs.  Produces five buckets:
#
#   update          in Apollo and on the portal          -> regenerate + update
#   add_candidate   qualifies, not in Apollo             -> needs approval
#   prune_candidate in Apollo, gone from the portal      -> needs approval
#   rename          same genome under a new abbrev       -> repoint in place
#   exception       in Apollo, fails the criteria        -> no action, reported
#
# The roster is SEEDED FROM APOLLO.  reference+annotated only ever proposes an
# add; it never removes anything.

sub reconcile {
  my ($class, $portal, $live, $overlay, $renames) = @_;

  $renames ||= {};

  my %result = (
    update          => [],
    add_candidate   => [],
    prune_candidate => [],
    rename          => [],
    exception       => [],
  );

  my %renameTarget = reverse %$renames;

  foreach my $abbrev (sort keys %$live) {
    my $apollo = $live->{$abbrev};

    if (my $newAbbrev = $renames->{$abbrev}) {
      my $target = $portal->{$newAbbrev}
        or die "rename target $newAbbrev is not on the portal\n";

      push @{$result{rename}}, {
        from_abbrev      => $abbrev,
        to_abbrev        => $newAbbrev,
        apollo_id        => $apollo->{id},
        annotation_count => $apollo->{annotation_count},
        organism         => $target,
      };
      next;
    }

    my $organism = $portal->{$abbrev};

    unless ($organism) {
      push @{$result{prune_candidate}}, {
        abbrev           => $abbrev,
        apollo_id        => $apollo->{id},
        common_name      => $apollo->{common_name},
        annotation_count => $apollo->{annotation_count},
      };
      next;
    }

    # In Apollo but failing the criteria: a decision made once, reported so
    # nobody "fixes" it, and so a newly-demoted organism becomes visible.
    unless (ApiCommonModel::Model::ApolloRelease::Portal->qualifies($organism)) {
      push @{$result{exception}}, {
        abbrev           => $abbrev,
        apollo_id        => $apollo->{id},
        organism         => $organism,
        annotation_count => $apollo->{annotation_count},
        is_reference     => $organism->{is_reference},
        is_annotated     => $organism->{is_annotated},
      };
      next;
    }

    push @{$result{update}}, {
      abbrev    => $abbrev,
      apollo_id => $apollo->{id},
      organism  => $organism,
    };
  }

  foreach my $abbrev (sort keys %$portal) {
    next if $live->{$abbrev};
    next if $renameTarget{$abbrev};
    next if $overlay->{remove}{$abbrev};

    my $organism = $portal->{$abbrev};
    next unless ApiCommonModel::Model::ApolloRelease::Portal->qualifies($organism)
             || $overlay->{add}{$abbrev};

    push @{$result{add_candidate}}, {
      abbrev   => $abbrev,
      organism => $organism,
      approved => $overlay->{add}{$abbrev} ? 1 : 0,
      reason   => $overlay->{add}{$abbrev},
    };
  }

  $class->assertInvariants(\%result);

  return \%result;
}

# Invariant 4 from the spec.  An add plus a prune for the same genome creates a
# new Apollo organism with no annotations and orphans the one holding the
# curation work -- from the same inputs and the same API as the correct
# behaviour.  This is the failure mode that must never ship.
sub assertInvariants {
  my ($class, $result) = @_;

  my %renamedFrom = map { $_->{from_abbrev} => 1 } @{$result->{rename}};
  my %renamedTo   = map { $_->{to_abbrev}   => 1 } @{$result->{rename}};

  foreach my $add (@{$result->{add_candidate}}) {
    die "INVARIANT VIOLATED: $add->{abbrev} is both a rename target and an add candidate\n"
      if $renamedTo{$add->{abbrev}};
  }

  foreach my $prune (@{$result->{prune_candidate}}) {
    die "INVARIANT VIOLATED: $prune->{abbrev} is both a rename source and a prune candidate\n"
      if $renamedFrom{$prune->{abbrev}};
  }

  return 1;
}

1;
```

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/reconcile.t"'
```

Expected: 12 passing.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Reconcile.pm Model/t/reconcile.t
git commit -m "feat(apollo): add reconciliation with add/prune/rename invariant"
```

---

## Task 6: `ApolloRelease::Rename` — detection by sequence identity

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Rename.pm`
- Create: `Model/t/rename.t`

Species taxon ID must **not** be used: it changed in both known renames
(`cneoJEC21` 5207 → `cdenJEC21` 40410). Strain abbrev narrows the candidates; identical
sequence names and lengths decide.

- [ ] **Step 1: Write the failing test**

Create `Model/t/rename.t`:

```perl
use strict;
use warnings;
use Test::More tests => 6;
use File::Temp qw(tempdir);
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Rename;

my $R = 'ApiCommonModel::Model::ApolloRelease::Rename';

my $dir = tempdir(CLEANUP => 1);

sub writeFai {
  my ($path, @lines) = @_;
  open(my $fh, '>', $path) or die $!;
  print $fh "$_\n" for @lines;
  close $fh;
}

# Old organism's shipped index, and a new organism with the same assembly.
writeFai("$dir/old.fai",   "AE017341.1\t2300533\t60\t60\t61", "AE017342.1\t1632307\t60\t60\t61");
writeFai("$dir/same.fai",  "AE017341.1\t2300533\t99\t70\t71", "AE017342.1\t1632307\t99\t70\t71");
writeFai("$dir/other.fai", "CP000001.1\t123456\t60\t60\t61");

is_deeply($R->readFai("$dir/old.fai"),
          {'AE017341.1' => 2300533, 'AE017342.1' => 1632307},
          'fai parsed to name => length, ignoring offset columns');

ok($R->sameAssembly("$dir/old.fai", "$dir/same.fai"),
   'identical names and lengths match despite different byte offsets');
ok(!$R->sameAssembly("$dir/old.fai", "$dir/other.fai"),
   'different assembly does not match');

my $portal = {
  cdenJEC21 => {abbrev => 'cdenJEC21', strain_abbrev => 'JEC21', name_for_filenames => 'CdeneoformansJEC21'},
  tgonME49  => {abbrev => 'tgonME49',  strain_abbrev => 'ME49',  name_for_filenames => 'TgondiiME49'},
};

my $renames = $R->detect(
  ['cneoJEC21'],
  $portal,
  sub { my ($abbrev) = @_; return "$dir/old.fai" },                       # previous release
  sub { my ($org) = @_; return $org->{abbrev} eq 'cdenJEC21' ? "$dir/same.fai" : "$dir/other.fai" },
  {cneoJEC21 => 'JEC21'},
);

is_deeply($renames, {cneoJEC21 => 'cdenJEC21'}, 'rename detected by sequence identity');

# A missing previous-release index must not silently mean "no rename".
my $none = $R->detect(['cneoJEC21'], $portal,
                      sub { return "$dir/does-not-exist.fai" },
                      sub { return "$dir/same.fai" },
                      {cneoJEC21 => 'JEC21'});
is_deeply($none, {}, 'unresolvable organism yields no rename');

my @warnings = $R->warnings();
like($warnings[0], qr/cneoJEC21/, 'and says so rather than staying silent');
```

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/rename.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Rename.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Rename;

use strict;
use warnings;

# Detects taxonomic renames: the same assembly appearing under a new organism
# abbrev.  Species taxon ID is deliberately NOT used -- it changed in both
# known cases (cneoJEC21 5207 -> cdenJEC21 40410).
#
# Strain abbrev narrows the candidate set; identical sequence names and
# lengths decide.

my @WARNINGS;

sub warnings { return @WARNINGS }

sub readFai {
  my ($class, $path) = @_;

  open(my $fh, '<', $path) or return undef;

  my %lengths;
  while (my $line = <$fh>) {
    chomp $line;
    next unless length $line;
    my ($name, $length) = split /\t/, $line;
    $lengths{$name} = $length + 0;
  }
  close $fh;

  return \%lengths;
}

sub sameAssembly {
  my ($class, $pathA, $pathB) = @_;

  my $a = $class->readFai($pathA) or return 0;
  my $b = $class->readFai($pathB) or return 0;

  return 0 unless scalar(keys %$a) == scalar(keys %$b);
  return 0 unless scalar(keys %$a);

  foreach my $name (keys %$a) {
    return 0 unless defined $b->{$name};
    return 0 unless $b->{$name} == $a->{$name};
  }

  return 1;
}

# $orphans        - arrayref of Apollo abbrevs absent from the portal
# $portal         - the portal hash from Portal.pm
# $previousFai    - coderef: abbrev            -> path to last release's .fa.fai
# $currentFai     - coderef: portal organism   -> path to this build's .fai
# $strainByAbbrev - hashref: orphan abbrev     -> its strain abbrev
sub detect {
  my ($class, $orphans, $portal, $previousFai, $currentFai, $strainByAbbrev) = @_;

  @WARNINGS = ();
  my %renames;

  foreach my $orphan (@$orphans) {
    my $oldFai = $previousFai->($orphan);

    unless ($oldFai && -e $oldFai) {
      push @WARNINGS,
        "$orphan: no index from the previous release at "
        . ($oldFai || '(no path)')
        . "; cannot test for a rename. Treating as a prune candidate.";
      next;
    }

    my $strain = $strainByAbbrev->{$orphan};

    my @candidates = grep {
      !defined($strain) || (defined($_->{strain_abbrev}) && $_->{strain_abbrev} eq $strain)
    } values %$portal;

    my @matches;
    foreach my $candidate (@candidates) {
      next if $candidate->{abbrev} eq $orphan;
      my $newFai = $currentFai->($candidate);
      next unless $newFai && -e $newFai;
      push @matches, $candidate->{abbrev}
        if $class->sameAssembly($oldFai, $newFai);
    }

    if (@matches == 1) {
      $renames{$orphan} = $matches[0];
    }
    elsif (@matches > 1) {
      push @WARNINGS,
        "$orphan: matches more than one portal organism ("
        . join(', ', sort @matches)
        . "); refusing to guess. Treating as a prune candidate.";
    }
    else {
      push @WARNINGS,
        "$orphan: no portal organism shares its assembly. Treating as a prune candidate.";
    }
  }

  return \%renames;
}

1;
```

An ambiguous match produces **no** rename. Guessing here repoints curated annotations at the
wrong genome.

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/rename.t"'
```

Expected: 6 passing.

- [ ] **Step 5: Verify against the real rename**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && \
  perl -Mlib=\$GUS_HOME/lib/perl -MApiCommonModel::Model::ApolloRelease::Rename -e '\''
    my \$R = q(ApiCommonModel::Model::ApolloRelease::Rename);
    my \$W = q(/var/www/Common/apiSiteFilesMirror/webServices/UniDB/build-71);
    print \"cdenJEC21 matches: \", \$R->sameAssembly(q(/tmp/cneoJEC21.fa.fai), \"\$W/CdeneoformansJEC21/genomeAndProteome/fasta/genome.fasta.fai\") ? \"YES\" : \"no\", \"\n\";
    print \"tgonME49 matches:  \", \$R->sameAssembly(q(/tmp/cneoJEC21.fa.fai), \"\$W/TgondiiME49/genomeAndProteome/fasta/genome.fasta.fai\") ? \"YES\" : \"no\", \"\n\";
  '\''"'
```

First copy the b68 index across: `scp yew:/eupath/data/apolloConfigs/release-68/prod/data/cneoJEC21/seq/cneoJEC21.fa.fai /tmp/` on cedar.

Expected: `cdenJEC21 matches: YES`, `tgonME49 matches: no`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Rename.pm Model/t/rename.t
git commit -m "feat(apollo): detect taxonomic renames by assembly identity

Species taxon ID cannot be used: it changed in both known renames.
Ambiguous matches produce no rename rather than a guess."
```

---

## Task 7: `ApolloRelease::Absolutize`

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Absolutize.pm`
- Create: `Model/t/absolutize.t`

- [ ] **Step 1: Write the failing test**

Create `Model/t/absolutize.t`:

```perl
use strict;
use warnings;
use Test::More tests => 7;
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
```

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/absolutize.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Absolutize.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Absolutize;

use strict;
use warnings;

# Apollo needs absolute URLs; the jbrowse scripts emit site-relative "/a/...".
#
# This is a text pass rather than a typed transformation because roughly 25 of
# these live inside free text -- HTML blobs, onClick and menuTemplate URLs, and
# JavaScript function bodies -- where a typed getApolloObject() cannot reach.
# See spec section 6.
#
# The post-condition check is not optional.  Paul's version did the same
# rewrite with no verification, so a missed URL became a track that silently
# 404s inside Apollo.

# A site-root URL is "/a/" appearing at the start of a quoted string or
# immediately after a quote/paren/equals/whitespace -- not "/a/" occurring in
# the middle of a longer path such as /data/a/thing.
my $RELATIVE = qr{(?<=['"(=\s])/a/};

sub rewrite {
  my ($class, $text, $base) = @_;

  return $text unless defined $text;

  $base =~ s{/+$}{};
  $text =~ s{$RELATIVE}{$base/a/}g;

  return $text;
}

sub assertNoRelative {
  my ($class, $text, $label) = @_;

  return 1 unless defined $text;

  my @found;
  while ($text =~ m{$RELATIVE}g) {
    my $start = $-[0];
    push @found, substr($text, $start, 60);
    last if @found >= 3;
  }

  die "$label still contains site-relative URLs after absolutization:\n"
    . join('', map { "    $_\n" } @found)
    if @found;

  return 1;
}

1;
```

The lookbehind is what makes this safe: it anchors on a delimiter, so a genuine path
component like `/data/a/thing` is untouched, and an already-absolute
`https://veupathdb.org/a/x` is not rewritten twice because the character before `/a/` is `g`.

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/absolutize.t"'
```

Expected: 7 passing.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Absolutize.pm Model/t/absolutize.t
git commit -m "feat(apollo): add URL absolutization with a mandatory post-condition check"
```

---

## Task 8: `ApolloRelease::Generate` — per-organism files

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Generate.pm`
- Create: `Model/t/generate.t`

- [ ] **Step 1: Write the failing test**

Create `Model/t/generate.t`. This tests the parts that do not need a database — the
`trackList.json` assembly and per-organism failure isolation — by injecting a fake runner:

```perl
use strict;
use warnings;
use Test::More tests => 8;
use File::Temp qw(tempdir);
use JSON;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Generate;

my $G = 'ApiCommonModel::Model::ApolloRelease::Generate';

my $trackList = {
  refSeqs => "/a/service/jbrowse/refSeqs/tgonME49",
  names   => {url => "/a/service/jbrowse/names/tgonME49"},
  include => [
    "/a/jbrowse/tracks/tgonME49/tracks.conf",
    "/a/service/jbrowse/rnaseqJunctions/tgonME49",
    "/a/jbrowse/user-datasets-jbrowse/tgonME49",
    "/a/jbrowse/functions.conf",
  ],
  tracks  => [{label => "should be replaced"}],
};

my $built = $G->buildTrackList($trackList, 'tgonME49', 'https://veupathdb.org');

is_deeply([grep { /user-datasets/ } @{$built->{include}}], [],
          'user dataset includes are dropped');
is_deeply($built->{include},
          ['tracks.conf', 'rnaseqJunctions.json', 'functions.conf'],
          'includes rewritten to local filenames');
is($built->{refSeqs}, 'seq/tgonME49.fa.fai', 'refSeqs points at the local index');
is(scalar(@{$built->{tracks}}), 1, 'exactly one track remains');
is($built->{tracks}[0]{storeClass}, 'JBrowse/Store/SeqFeature/IndexedFasta',
   'and it is the local reference sequence track');
is($built->{tracks}[0]{urlTemplate}, 'seq/tgonME49.fa', 'pointing at the local fasta');
like($built->{names}{url}, qr{^https://veupathdb\.org/a/}, 'names url absolutized');

# One organism failing must not abort the run.
my $dir = tempdir(CLEANUP => 1);
my $results = $G->generateAll(
  [{abbrev => 'good1'}, {abbrev => 'explodes'}, {abbrev => 'good2'}],
  $dir,
  sub {
    my ($organism) = @_;
    die "simulated failure\n" if $organism->{abbrev} eq 'explodes';
    return 1;
  },
);
is_deeply([sort @{$results->{failed}}], ['explodes'],
          'a failing organism is recorded and the run continues');
```

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/generate.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Generate.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Generate;

use strict;
use warnings;

use JSON;
use File::Path qw(make_path);
use File::Copy qw(cp);

use ApiCommonModel::Model::ApolloRelease::Absolutize;

my $ABS = 'ApiCommonModel::Model::ApolloRelease::Absolutize';

# Maps an include URL to the local filename Apollo will read it as.
my @INCLUDE_NAMES = (
  [qr{tracks\.conf$}              => 'tracks.conf'],
  [qr{functions\.conf$}           => 'functions.conf'],
  [qr{bindingSites\.conf$}        => 'bindingSites.conf'],
  [qr{apollo_gene_tracks\.conf$}  => 'apollo_gene_tracks.conf'],
  [qr{rnaseqJunctions}            => 'rnaseqJunctions.json'],
  [qr{organismSpecific}           => 'organismSpecific.json'],
  [qr{rnaseq}i                    => 'rnaseq.json'],
  [qr{chipseq}i                   => 'chipseq.json'],
  [qr{dnaseq}i                    => 'dnaseq.json'],
);

sub localNameForInclude {
  my ($class, $url) = @_;

  foreach my $rule (@INCLUDE_NAMES) {
    my ($pattern, $name) = @$rule;
    return $name if $url =~ $pattern;
  }

  return undef;
}

# Rewrites the site's trackList.json into Apollo's.  Three deliberate
# differences, all declared in spec section 10:
#   - user dataset includes dropped
#   - includes rewritten to local filenames
#   - the reference sequence track replaced with a local IndexedFasta track
sub buildTrackList {
  my ($class, $trackList, $abbrev, $base) = @_;

  my %built = %$trackList;

  my @includes;
  foreach my $url (@{$trackList->{include} || []}) {
    next if $url =~ m{user-datasets-jbrowse};
    my $name = $class->localNameForInclude($url);
    unless ($name) {
      warn "$abbrev: unrecognised include '$url'; skipping\n";
      next;
    }
    push @includes, $name;
  }
  $built{include} = \@includes;

  $built{refSeqs} = "seq/$abbrev.fa.fai";

  $built{names} = {%{$trackList->{names} || {}}};
  $built{names}{url} = $ABS->rewrite($built{names}{url}, $base)
    if defined $built{names}{url};

  $built{tracks} = [
    {
      category       => "Sequence Analysis",
      faiUrlTemplate => "seq/$abbrev.fa.fai",
      key            => "Reference sequence",
      label          => "DNA",
      seqType        => "dna",
      storeClass     => "JBrowse/Store/SeqFeature/IndexedFasta",
      type           => "SequenceTrack",
      urlTemplate    => "seq/$abbrev.fa",
      useAsRefSeqStore => JSON::true,
    }
  ];

  return \%built;
}

# Runs $perOrganism for each organism, isolating failures.  Paul's script died
# on the first bad organism, discarding hours of completed work; this run is
# long and the organisms are independent.
sub generateAll {
  my ($class, $organisms, $outDir, $perOrganism) = @_;

  my %results = (succeeded => [], failed => [], errors => {});

  foreach my $organism (@$organisms) {
    my $abbrev = $organism->{abbrev};

    my $ok = eval { $perOrganism->($organism); 1 };

    if ($ok) {
      push @{$results{succeeded}}, $abbrev;
    }
    else {
      my $error = $@ || 'unknown error';
      chomp $error;
      push @{$results{failed}}, $abbrev;
      $results{errors}{$abbrev} = $error;
      warn "FAILED $abbrev: $error\n";
    }
  }

  return \%results;
}

sub writeFile {
  my ($class, $path, $content, $base) = @_;

  my $rewritten = $ABS->rewrite($content, $base);
  $ABS->assertNoRelative($rewritten, $path);

  open(my $fh, '>', $path) or die "Cannot write $path: $!";
  print $fh $rewritten;
  close $fh;

  return 1;
}

1;
```

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/generate.t"'
```

Expected: 8 passing.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Generate.pm Model/t/generate.t
git commit -m "feat(apollo): add per-organism generation with failure isolation"
```

---

## Task 9: Probe one real organism end to end

Before wiring the CLI, confirm the `jbrowse*` scripts actually produce usable Apollo output.
This is the open risk in the spec: the track layer moved REST → flat files and Oracle →
Postgres since the last successful run, so nothing about this is assumed.

**Files:**
- Create: `Model/bin/apolloProbeOrganism` (a temporary harness, deleted in Task 13)

- [ ] **Step 1: Run each producing script by hand for `tgonME49`**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && \
  W=/var/www/Common/apiSiteFilesMirror/webServices && \
  for spec in \
    \"jbrowseRnaAndChipSeqTracks tgonME49 UniDB 71 \$W RNASeq jbrowse\" \
    \"jbrowseRnaAndChipSeqTracks tgonME49 UniDB 71 \$W ChIPSeq jbrowse\" \
    \"jbrowseRNASeqJunctionTracks tgonME49 UniDB 71 \$W 1 jbrowse\" \
    \"jbrowseOrganismSpecificTracks tgonME49 UniDB 1 71 \$W jbrowse\" \
    \"jbrowseDNASeqTracks tgonME49 UniDB 71 \$W jbrowse\" ; do \
    name=\$(echo \$spec | cut -d\" \" -f1); \
    out=/tmp/probe_\$name.json; err=/tmp/probe_\$name.err; \
    perl \$GUS_HOME/bin/\$spec > \$out 2> \$err; \
    echo \"\$name rc=\$? out=\$(stat -c%s \$out) err=\$(stat -c%s \$err) tracks=\$(python3 -c \"import json;print(len(json.load(open(chr(39)+\$out.__str__()+chr(39)))[chr(39)+chr(116)+chr(114)+chr(97)+chr(99)+chr(107)+chr(115)+chr(39)]))\" 2>/dev/null || echo PARSE_FAIL)\"; \
  done"'
```

If the nested quoting fights you, write the loop into a file on cedar and run it — the point
is to record, for each script: exit code, stdout size, **stderr size**, and track count.

- [ ] **Step 2: Record the result in the spec**

Expected per script: `rc=0`, `err=0`, `tracks` > 0.

Anything else is a finding that changes the plan. Specifically:
- **stderr non-empty** — the same class of bug as Task 1. These scripts are also served
  through `responseFromCommand`, so warnings corrupt output.
- **`tracks=0` but valid JSON** — the characteristic flat-file migration failure. Valid,
  empty, and silent.
- **A script dies** — investigate before proceeding; do not work around it in the tool.

Append a short table of the measured results to spec §10 and commit it, so the next person
knows what "working" looked like on 2026-08-21.

- [ ] **Step 3: Compare against what the site serves**

```bash
# From an authenticated browser tab on the eupathdb instance:
#   fetch('/a/service/jbrowse/tracks/tgonME49/trackList.json').then(r=>r.json())
# Record: the include list, and the track count.
```

The Apollo package's include list must be the same set minus `user-datasets-jbrowse`, and
its track count must match after the reference-sequence substitution. A difference outside
the four declared classes in spec §10 is a defect in the tool, not in the site.

- [ ] **Step 4: Commit the findings**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add docs/superpowers/specs/2026-08-21-apollo-release-package-design.md
git commit -m "docs(apollo): record measured per-script output for tgonME49"
```

---

## Task 10: `ApolloRelease::Commands`

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Commands.pm`
- Create: `Model/t/commands.t`

- [ ] **Step 1: Write the failing test**

Create `Model/t/commands.t`:

```perl
use strict;
use warnings;
use Test::More tests => 8;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Commands;

my $C = 'ApiCommonModel::Model::ApolloRelease::Commands';

my $update = $C->updateCommand({
  abbrev => 'tgonME49', apollo_id => 1484940,
});
like($update, qr/"id":"1484940"/,                          'update targets the numeric id');
like($update, qr{/data/apollo_data/tgonME49},              'points at the organism directory');
like($update, qr{/data/apollo_data/twoBit/tgonME49\.2bit}, 'and at its blatdb');
unlike($update, qr/GFERsVNiX5BQ|password":"[^\$]/,         'no literal password in output');

my $rename = $C->renameCommand({
  from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21', apollo_id => 2452162,
  organism => {name => 'Cryptococcus deneoformans JEC21', latest_annotation_version => 'Jun 16, 2016'},
});
like($rename, qr/2452162/,                        'rename targets the EXISTING apollo id');
like($rename, qr{/data/apollo_data/cdenJEC21},    'repointed at the new directory');
like($rename, qr/Cryptococcus deneoformans JEC21 \[Jun 16, 2016\]/, 'renamed with version');

my $prune = $C->pruneCommand({abbrev => 'cglaCBS138', apollo_id => 5146948});
like($prune, qr/"publicMode":"false"/, 'prune unpublishes rather than deleting');
```

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/commands.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Commands.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Commands;

use strict;
use warnings;

# Emits the commands a human runs after the package is synced.  This module
# never executes anything.
#
# Passwords are emitted as the shell variable $APOLLO_ADMIN_PASSWORD, never
# interpolated -- the generated files are read by several people and land in a
# shared directory.

my $API      = 'https://apollo-api.veupathdb.org';
my $DATA     = '/data/apollo_data';
my $ADMIN    = 'admin@local.host';

sub _updateOrganismInfo {
  my ($class, $id, $abbrev, $extra) = @_;

  my %fields = (
    username  => $ADMIN,
    password  => '$APOLLO_ADMIN_PASSWORD',
    id        => "$id",
    directory => "$DATA/$abbrev",
    blatdb    => "$DATA/twoBit/$abbrev.2bit",
    %{$extra || {}},
  );

  my $json = join(',', map { "\"$_\":\"$fields{$_}\"" }
                       qw(username password id directory blatdb),
                       grep { !/^(username|password|id|directory|blatdb)$/ } sort keys %fields);

  return qq{curl -X POST -H "Content-Type: application/json" --data '{$json}' $API/organism/updateOrganismInfo\n};
}

sub updateCommand {
  my ($class, $entry) = @_;
  return $class->_updateOrganismInfo($entry->{apollo_id}, $entry->{abbrev},
                                     {publicMode => 'true'});
}

# A rename repoints the EXISTING organism, preserving its annotations.  The
# alternative -- add the new abbrev, prune the old -- creates an empty organism
# and orphans the curation work.
sub renameCommand {
  my ($class, $entry) = @_;

  my $organism = $entry->{organism};
  my $version  = $organism->{latest_annotation_version};
  my $name     = defined $version
               ? "$organism->{name} [$version]"
               : $organism->{name};

  return $class->_updateOrganismInfo($entry->{apollo_id}, $entry->{to_abbrev},
                                     {publicMode => 'true', commonName => $name});
}

# Prune unpublishes.  It is reversible, and Apollo's API has no delete in use.
sub pruneCommand {
  my ($class, $entry) = @_;
  return $class->_updateOrganismInfo($entry->{apollo_id}, $entry->{abbrev},
                                     {publicMode => 'false'});
}

sub addCommand {
  my ($class, $entry) = @_;

  my $organism = $entry->{organism};
  my $version  = $organism->{latest_annotation_version};
  my $name     = defined $version
               ? "$organism->{name} [$version]"
               : $organism->{name};
  my $abbrev   = $entry->{abbrev};

  return
    qq{groovy add_organism.groovy -name '$name' -url https://apollo.apidb.org }
  . qq{-directory '$DATA/$abbrev' -blatdb '$DATA/twoBit/$abbrev.2bit' }
  . qq{-username '$ADMIN' -password \$APOLLO_ADMIN_PASSWORD\n}
  . qq{groovy alter_group_permissions.groovy -groupname remote_users -organism '$name' }
  . qq{-permission WRITE -destinationurl https://apollo.apidb.org/ }
  . qq{-adminusername '$ADMIN' -adminpassword \$APOLLO_ADMIN_PASSWORD\n};
}

1;
```

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/commands.t"'
```

Expected: 8 passing.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Commands.pm Model/t/commands.t
git commit -m "feat(apollo): emit update/rename/prune/add commands

Prune unpublishes rather than deletes. Rename repoints the existing
organism id so its annotations survive."
```

---

## Task 11: `ApolloRelease::Report`

**Files:**
- Create: `Model/lib/perl/ApolloRelease/Report.pm`
- Create: `Model/t/report.t`

- [ ] **Step 1: Write the failing test**

Create `Model/t/report.t`:

```perl
use strict;
use warnings;
use Test::More tests => 5;
use lib $ENV{GUS_HOME} . "/lib/perl";
use ApiCommonModel::Model::ApolloRelease::Report;

my $R = 'ApiCommonModel::Model::ApolloRelease::Report';

my $result = {
  update          => [ {abbrev => 'tgonME49'} ],
  add_candidate   => [ {abbrev => 'hcapNAm1', organism => {name => 'Histoplasma mississippiense NAm1'}, approved => 0} ],
  prune_candidate => [ {abbrev => 'cglaCBS138', annotation_count => 0, common_name => 'Candida glabrata CBS 138'},
                       {abbrev => 'zzzRisky',   annotation_count => 14, common_name => 'Something Curated'} ],
  rename          => [ {from_abbrev => 'cneoJEC21', to_abbrev => 'cdenJEC21', annotation_count => 14} ],
  exception       => [ {abbrev => 'tbruLister427_2018', is_reference => 0, is_annotated => 1} ],
};

my $text = $R->render($result, {build => 71, environment => 'prod'});

like($text, qr/update\s+1/,        'counts each bucket');
like($text, qr/cneoJEC21.*cdenJEC21/, 'names both sides of a rename');
like($text, qr/zzzRisky.*14/,      'prune candidates show their annotation count');
like($text, qr/ANNOTATIONS WILL BE HIDDEN/, 'an annotated prune is called out loudly');
unlike($text, qr/cglaCBS138.*ANNOTATIONS WILL BE HIDDEN/, 'a zero-annotation prune is not');
```

- [ ] **Step 2: Run it and watch it fail**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME/ApiCommonModel && prove -v Model/t/report.t"'
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

Create `Model/lib/perl/ApolloRelease/Report.pm`:

```perl
package ApiCommonModel::Model::ApolloRelease::Report;

use strict;
use warnings;

# The artifact that goes to the curation team.  Adds and prunes are proposals;
# a human decides.  An annotated prune is called out because that is the
# expensive mistake.

sub render {
  my ($class, $result, $context) = @_;

  my @out;

  push @out, "Apollo release reconciliation\n";
  push @out, sprintf("build %s, environment %s\n\n",
                     $context->{build} // '?', $context->{environment} // '?');

  push @out, "summary\n";
  foreach my $bucket (qw(update add_candidate prune_candidate rename exception)) {
    push @out, sprintf("  %-18s %d\n", $bucket, scalar @{$result->{$bucket} || []});
  }
  push @out, "\n";

  if (@{$result->{rename} || []}) {
    push @out, "renames (repointed in place; annotations preserved)\n";
    foreach my $r (sort { $a->{from_abbrev} cmp $b->{from_abbrev} } @{$result->{rename}}) {
      push @out, sprintf("  %-26s -> %-26s (%d annotations)\n",
                         $r->{from_abbrev}, $r->{to_abbrev}, $r->{annotation_count} || 0);
    }
    push @out, "\n";
  }

  if (@{$result->{prune_candidate} || []}) {
    push @out, "prune candidates -- REQUIRE APPROVAL\n";
    foreach my $p (sort { $a->{abbrev} cmp $b->{abbrev} } @{$result->{prune_candidate}}) {
      my $count = $p->{annotation_count} || 0;
      push @out, sprintf("  %-26s %3d annotations  %s%s\n",
                         $p->{abbrev}, $count, $p->{common_name} || '',
                         $count ? "  <-- ANNOTATIONS WILL BE HIDDEN" : '');
    }
    push @out, "\n";
  }

  if (@{$result->{add_candidate} || []}) {
    push @out, "add candidates -- REQUIRE APPROVAL\n";
    foreach my $a (sort { $a->{abbrev} cmp $b->{abbrev} } @{$result->{add_candidate}}) {
      push @out, sprintf("  %-26s %s%s\n", $a->{abbrev},
                         $a->{organism}{name} || '',
                         $a->{approved} ? '  (approved in overlay)' : '');
    }
    push @out, "\n";
  }

  if (@{$result->{exception} || []}) {
    push @out, "exceptions -- in Apollo but not reference+annotated; no action\n";
    foreach my $e (sort { $a->{abbrev} cmp $b->{abbrev} } @{$result->{exception}}) {
      push @out, sprintf("  %-26s reference=%d annotated=%d\n",
                         $e->{abbrev}, $e->{is_reference}, $e->{is_annotated});
    }
    push @out, "\n";
  }

  return join('', @out);
}

1;
```

- [ ] **Step 4: Install, run, verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/report.t"'
```

Expected: 5 passing.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/lib/perl/ApolloRelease/Report.pm Model/t/report.t
git commit -m "feat(apollo): render the reconciliation report"
```

---

## Task 12: The CLI

**Files:**
- Create: `Model/bin/createApolloReleasePackage`

- [ ] **Step 1: Write the script**

```perl
#!/usr/bin/perl

use strict;
use warnings;

use lib $ENV{GUS_HOME} . "/lib/perl";

use Getopt::Long;
use File::Path qw(make_path);

use ApiCommonModel::Model::ApolloRelease::Portal;
use ApiCommonModel::Model::ApolloRelease::Apollo;
use ApiCommonModel::Model::ApolloRelease::Overlay;
use ApiCommonModel::Model::ApolloRelease::Rename;
use ApiCommonModel::Model::ApolloRelease::Reconcile;
use ApiCommonModel::Model::ApolloRelease::Report;
use ApiCommonModel::Model::ApolloRelease::Commands;

my ($report, $generate, $help);
my $build       = undef;
my $environment = 'prod';
my $project     = 'UniDB';
my $outDir      = "$ENV{HOME}/apolloConfigs";
my $base        = 'https://veupathdb.org';
my $webServices = '/var/www/Common/apiSiteFilesMirror/webServices';
my $previousRelease;
my @onlyOrganisms;

GetOptions(
  'report'            => \$report,
  'generate'          => \$generate,
  'build=i'           => \$build,
  'environment=s'     => \$environment,
  'project=s'         => \$project,
  'out-dir=s'         => \$outDir,
  'base-url=s'        => \$base,
  'webservices-dir=s' => \$webServices,
  'previous-release=s'=> \$previousRelease,
  'organism=s'        => \@onlyOrganisms,
  'help|h'            => \$help,
) or usage(1);

usage(0) if $help;

usage(1, "exactly one of --report or --generate is required")
  unless ($report xor $generate);
usage(1, "--build is required") unless $build;
usage(1, "--environment must be qa or prod")
  unless $environment eq 'qa' || $environment eq 'prod';

preflight();

my $portal  = ApiCommonModel::Model::ApolloRelease::Portal->loadFromCommand($project);
my $live    = ApiCommonModel::Model::ApolloRelease::Apollo->loadFromApi();
my $overlay = ApiCommonModel::Model::ApolloRelease::Overlay->parseFile(
                "$ENV{GUS_HOME}/data/ApiCommonModel/Model/apollo/roster-overlay.txt");

my @orphans = grep { !$portal->{$_} } sort keys %$live;

my $renames = ApiCommonModel::Model::ApolloRelease::Rename->detect(
  \@orphans,
  $portal,
  sub {
    my ($abbrev) = @_;
    return undef unless $previousRelease;
    return "$previousRelease/data/$abbrev/seq/$abbrev.fa.fai";
  },
  sub {
    my ($organism) = @_;
    return "$webServices/$project/build-$build/$organism->{name_for_filenames}"
         . "/genomeAndProteome/fasta/genome.fasta.fai";
  },
  { map { $_ => ($live->{$_}{common_name} =~ /(\S+)\s*\[/ ? $1 : undef) } @orphans },
);

warn "$_\n" for ApiCommonModel::Model::ApolloRelease::Rename->warnings();

my $result = ApiCommonModel::Model::ApolloRelease::Reconcile->reconcile(
               $portal, $live, $overlay, $renames);

my $text = ApiCommonModel::Model::ApolloRelease::Report->render(
             $result, {build => $build, environment => $environment});

print $text;

exit 0 if $report;

my $releaseDir = "$outDir/release-$build/$environment";
make_path("$releaseDir/data", "$releaseDir/twoBit", "$releaseDir/updateCommands");

open(my $rfh, '>', "$releaseDir/report.txt") or die "Cannot write report: $!";
print $rfh $text;
close $rfh;

# Generation is wired in Task 13; the CLI up to here is the reporting path.
die "--generate is not yet implemented; see Task 13 of the plan\n";

sub preflight {
  foreach my $var (qw(GUS_HOME APOLLO_API_USER APOLLO_API_PASS)) {
    die "$var is not set. Source the site's etc/setenv and export the Apollo credentials.\n"
      unless $ENV{$var};
  }

  system("which faToTwoBit > /dev/null 2>&1") == 0
    or die "faToTwoBit is not on PATH.\n"
         . "Install UCSC's linux.x86_64 build into ~/bin:\n"
         . "  curl -fLO https://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/faToTwoBit\n";
}

sub usage {
  my ($status, $message) = @_;
  print STDERR "ERROR: $message\n\n" if $message;
  print STDERR <<'USAGE';
Usage:
  createApolloReleasePackage --report   --build NN [options]
  createApolloReleasePackage --generate --build NN [options]

  --report              reconcile and print the five buckets; changes nothing
  --generate            build the package for the approved roster
  --build NN            release/build number (required)
  --environment qa|prod default prod
  --project NAME        WDK model name, default UniDB
  --out-dir DIR         default $HOME/apolloConfigs
  --base-url URL        default https://veupathdb.org
  --webservices-dir DIR default /var/www/Common/apiSiteFilesMirror/webServices
  --previous-release DIR  previous release/<env> dir, used for rename detection
  --organism ABBREV     restrict generation to this organism; repeatable.
                        Reconciliation still runs over everything, so the
                        report and the invariants are unaffected.

Environment: GUS_HOME, APOLLO_API_USER, APOLLO_API_PASS.
USAGE
  exit $status;
}
```

- [ ] **Step 2: Install and run the report against live data**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && \
  export APOLLO_API_USER=api@local.host APOLLO_API_PASS=\$(read -rsp \"apollo api pass: \" P; echo \$P) && \
  perl \$GUS_HOME/bin/createApolloReleasePackage --report --build 71"'
```

Expected, matching the spec's measured numbers: `update 457`, `add_candidate` 35 (48 minus
the 13 seeded removes), `prune_candidate 2`, `rename 0` (no `--previous-release` given),
`exception 4`.

Then re-run with `--previous-release`, after copying release-68 from yew to cedar:

```bash
rsync -a yew:/eupath/data/apolloConfigs/release-68/prod/data/ ~/apolloConfigs/release-68/prod/data/
```

Expected with it: `rename 1` (`cneoJEC21 -> cdenJEC21`), `prune_candidate 1`
(`cglaCBS138` only), and `cdenJEC21` gone from the add candidates.

- [ ] **Step 3: Commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git add Model/bin/createApolloReleasePackage
git commit -m "feat(apollo): add createApolloReleasePackage CLI with --report"
```

---

## Task 13: Wire generation into the CLI

**Files:**
- Modify: `Model/bin/createApolloReleasePackage` (replace the `die` from Task 12)
- Delete: `Model/bin/apolloProbeOrganism`

- [ ] **Step 1: Replace the placeholder with the generation pass**

Replace the `die "--generate is not yet implemented..."` line with:

```perl
my @roster = (
  @{$result->{update}},
  @{$result->{rename}},
  (grep { $_->{approved} } @{$result->{add_candidate}}),
);

# --organism narrows generation only.  Reconciliation above ran over the full
# set, so the report and the add/prune/rename invariants are unaffected by it.
if (@onlyOrganisms) {
  my %wanted = map { $_ => 1 } @onlyOrganisms;
  @roster = grep {
    my $abbrev = $_->{to_abbrev} || $_->{abbrev};
    $wanted{$abbrev};
  } @roster;
  die "--organism matched nothing in the roster\n" unless @roster;
  warn "restricted to " . scalar(@roster) . " organism(s) by --organism\n";
}

my $results = ApiCommonModel::Model::ApolloRelease::Generate->generateAll(
  [map { $_->{organism} ? {%{$_->{organism}}, apollo_id => $_->{apollo_id}} : $_ } @roster],
  $releaseDir,
  sub {
    my ($organism) = @_;
    generateOrganism($organism, $releaseDir, $build, $project, $webServices, $base);
  },
);

writeCommandFiles($result, "$releaseDir/updateCommands");

printf STDERR "\ngenerated %d organisms, %d failed\n",
  scalar @{$results->{succeeded}}, scalar @{$results->{failed}};

if (@{$results->{failed}}) {
  printf STDERR "  %s: %s\n", $_, $results->{errors}{$_} for @{$results->{failed}};
  exit 1;
}

exit 0;
```

Add these subs, and `use ApiCommonModel::Model::ApolloRelease::Generate;` at the top:

```perl
sub generateOrganism {
  my ($organism, $releaseDir, $build, $project, $webServices, $base) = @_;

  my $abbrev = $organism->{abbrev};
  my $orgDir = "$releaseDir/data/$abbrev";
  my $seqDir = "$orgDir/seq";
  make_path($seqDir);

  my $fastaDir = "$webServices/$project/build-$build/$organism->{name_for_filenames}"
               . "/genomeAndProteome/fasta";

  die "no genome fasta at $fastaDir/genome.fasta\n" unless -e "$fastaDir/genome.fasta";

  File::Copy::cp("$fastaDir/genome.fasta",     "$seqDir/$abbrev.fa")     or die "cp fasta: $!";
  File::Copy::cp("$fastaDir/genome.fasta.fai", "$seqDir/$abbrev.fa.fai") or die "cp fai: $!";

  my $twoBit = "$releaseDir/twoBit/$abbrev.2bit";
  system("faToTwoBit", "$seqDir/$abbrev.fa", $twoBit) == 0
    or die "faToTwoBit failed\n";

  foreach my $spec (trackSpecs($abbrev, $project, $build, $webServices)) {
    my ($fileName, @command) = @$spec;
    my $json = runCapture(@command);
    ApiCommonModel::Model::ApolloRelease::Generate->writeFile(
      "$orgDir/$fileName", $json, $base);
  }

  copyConf("$ENV{GUS_HOME}/lib/jbrowse/auto_generated/$abbrev/tracks.conf",
           "$orgDir/tracks.conf", $base, 1);
  copyConf("$ENV{GUS_HOME}/lib/jbrowse/functions.conf",
           "$orgDir/functions.conf", $base, 0);

  my $refSeqs = runCapture("$ENV{GUS_HOME}/bin/jbrowseRefSeqs",
                           $ENV{GUS_HOME}, $project, $abbrev);
  ApiCommonModel::Model::ApolloRelease::Generate->writeFile(
    "$seqDir/refSeqs.json", $refSeqs, $base);

  my $trackListJson = runCapture("$ENV{GUS_HOME}/bin/jbrowseTracks",
                                 $abbrev, $project, 0, 'geneAnnotationTracks');
  my $built = ApiCommonModel::Model::ApolloRelease::Generate->buildTrackList(
                JSON::decode_json($trackListJson), $abbrev, $base);
  ApiCommonModel::Model::ApolloRelease::Generate->writeFile(
    "$orgDir/trackList.json", JSON::encode_json($built), $base);

  return 1;
}

sub trackSpecs {
  my ($abbrev, $project, $build, $ws) = @_;
  my $bin = "$ENV{GUS_HOME}/bin";
  return (
    ['rnaseq.json',           "$bin/jbrowseRnaAndChipSeqTracks",  $abbrev, $project, $build, $ws, 'RNASeq',  'jbrowse'],
    ['chipseq.json',          "$bin/jbrowseRnaAndChipSeqTracks",  $abbrev, $project, $build, $ws, 'ChIPSeq', 'jbrowse'],
    ['rnaseqJunctions.json',  "$bin/jbrowseRNASeqJunctionTracks", $abbrev, $project, $build, $ws, 1, 'jbrowse'],
    ['organismSpecific.json', "$bin/jbrowseOrganismSpecificTracks", $abbrev, $project, 1, $build, $ws, 'jbrowse'],
    ['dnaseq.json',           "$bin/jbrowseDNASeqTracks",         $abbrev, $project, $build, $ws, 'jbrowse'],
  );
}

# These scripts are also served through responseFromCommand, which merges
# stderr into the response body.  Anything on stderr means the output cannot be
# trusted, so refuse it here too.
sub runCapture {
  my (@command) = @_;

  my $errFile = "/tmp/apolloRelease.$$.err";
  my $quoted = join(' ', map { "'$_'" } @command);
  my $out = `$quoted 2>$errFile`;
  my $status = $?;

  my $errSize = -s $errFile || 0;
  my $errText = '';
  if ($errSize) {
    open(my $fh, '<', $errFile); local $/; $errText = <$fh>; close $fh;
  }
  unlink $errFile;

  die "command failed (exit " . ($status >> 8) . "): $quoted\n$errText" if $status;
  die "command wrote to stderr: $quoted\n$errText" if $errSize;

  return $out;
}

sub copyConf {
  my ($source, $target, $base, $stripRefseq) = @_;

  open(my $fh, '<', $source) or die "Cannot read $source: $!";
  local $/;
  my $text = <$fh>;
  close $fh;

  # The refseq stanza is replaced by the local IndexedFasta track.
  $text =~ s/\[tracks\.refseq\][^#\[]*//s if $stripRefseq;
  $text =~ s{\.\./\.\./common_tracks/}{}g;

  ApiCommonModel::Model::ApolloRelease::Generate->writeFile($target, $text, $base);
}

sub writeCommandFiles {
  my ($result, $dir) = @_;

  my $C = 'ApiCommonModel::Model::ApolloRelease::Commands';

  open(my $curl, '>', "$dir/Apollo_curl") or die "Cannot write Apollo_curl: $!";
  print $curl $C->updateCommand($_) for @{$result->{update}};
  print $curl $C->renameCommand($_) for @{$result->{rename}};
  print $curl $C->pruneCommand($_)  for @{$result->{prune_candidate}};
  close $curl;

  open(my $groovy, '>', "$dir/Apollo_groovy") or die "Cannot write Apollo_groovy: $!";
  print $groovy $C->addCommand($_)
    for grep { $_->{approved} } @{$result->{add_candidate}};
  close $groovy;

  return 1;
}
```

Add `use JSON;` and `use File::Copy;` to the CLI's preamble.

Prune commands are written to `Apollo_curl` **only for approved prunes** — see Step 2.

- [ ] **Step 2: Gate prunes on approval**

Prune candidates are proposals. Change `writeCommandFiles` to emit a prune only when the
overlay approved it:

```perl
  print $curl $C->pruneCommand($_)
    for grep { $_->{approved} } @{$result->{prune_candidate}};
```

and in `Reconcile::reconcile`, mark them:

```perl
      push @{$result{prune_candidate}}, {
        abbrev           => $abbrev,
        apollo_id        => $apollo->{id},
        common_name      => $apollo->{common_name},
        annotation_count => $apollo->{annotation_count},
        approved         => $overlay->{remove}{$abbrev} ? 1 : 0,
        reason           => $overlay->{remove}{$abbrev},
      };
```

Add a test to `Model/t/reconcile.t` (bump the plan to 13 tests):

```perl
my $overlayWithPrune = ApiCommonModel::Model::ApolloRelease::Overlay->parseString(
  "remove cglaCBS138 # renamed to nglaCBS138, zero annotations\n");
my $r3 = $R->reconcile($portal, $live, $overlayWithPrune, {});
my ($cgla) = grep { $_->{abbrev} eq 'cglaCBS138' } @{$r3->{prune_candidate}};
is($cgla->{approved}, 1, 'an overlay remove approves the prune');
```

- [ ] **Step 3: Run the full test suite**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && cd \$PROJECT_HOME && bld ApiCommonModel/Model >/dev/null && cd ApiCommonModel && prove -v Model/t/"'
```

Expected: all files pass; 8 test files, 60+ assertions.

- [ ] **Step 4: Generate three probe organisms**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.eupathdb.org/etc/setenv && \
  export APOLLO_API_USER=api@local.host APOLLO_API_PASS=\$(read -rsp \"apollo api pass: \" P; echo \$P) && \
  perl \$GUS_HOME/bin/createApolloReleasePackage --generate --build 71 \
    --out-dir \$HOME/apolloProbe --previous-release \$HOME/apolloConfigs/release-68/prod"'
```

Use `--organism tgonME49 --organism pfal3D7 --organism cdenJEC21` on the first run rather
than generating 460 organisms.

Verify each organism dir contains all nine files from spec §6 plus `seq/`, that every JSON
parses, that every `include` names a file that exists, and that no file contains a bare
`/a/`:

```bash
ssh cedar 'cd $HOME/apolloProbe/release-71/prod/data && for o in */; do
  echo "== $o"; ls $o; grep -rl "\"/a/\|'"'"'/a/" $o && echo "  BARE /a/ FOUND" || echo "  urls ok"
done'
```

- [ ] **Step 4b: URL liveness on a sample** (spec §10)

The absolutization assertion proves the string changed. Only a request proves it points at
something. For the three probe organisms, HEAD every distinct absolutized URL:

```bash
ssh cedar 'python3 - <<PY
import json,glob,re,subprocess
urls=set()
for f in glob.glob("/home/jbrestel/apolloProbe/release-71/prod/data/*/*.json"):
    urls |= set(re.findall(r"https://veupathdb\.org/a/[^\"'"'"' ]+", open(f).read()))
print(f"{len(urls)} distinct URLs")
bad=[]
for u in sorted(urls)[:40]:
    code=subprocess.run(["curl","-s","-o","/dev/null","-w","%{http_code}","-I","-L",u],
                        capture_output=True,text=True).stdout
    if code not in ("200","302"): bad.append((code,u))
print("non-200:",len(bad))
for c,u in bad[:10]: print(" ",c,u)
PY'
```

Expected: `non-200: 0`. A 404 here means the absolutization produced a well-formed URL that
points nowhere — exactly the silent failure Paul's unverified rewrite could produce.

- [ ] **Step 5: Remove the probe harness and commit**

```bash
cd ~/workspaces/eupathdb/ApiCommonModel
git rm -f Model/bin/apolloProbeOrganism
git add Model/bin/createApolloReleasePackage Model/lib/perl/ApolloRelease/Reconcile.pm Model/t/reconcile.t
git commit -m "feat(apollo): wire generation into the CLI

Prunes and adds are emitted only when approved in the roster overlay."
```

---

## Task 14: Full run and handoff

- [ ] **Step 1: Full report, reviewed with the curation team**

```bash
perl $GUS_HOME/bin/createApolloReleasePackage --report --build 71 \
  --previous-release $HOME/apolloConfigs/release-68/prod | tee ~/apollo-report-71.txt
```

Take the add and prune candidates to Uli and Eve. Record their decisions as overlay entries
with approver and date, then commit the overlay. **`hcapNAm1` is the one to ask about
first** — it is a qualifying FungiDB pathogen absent from Apollo, and no record explains why.

- [ ] **Step 2: Full generation**

```bash
perl $GUS_HOME/bin/createApolloReleasePackage --generate --build 71 \
  --previous-release $HOME/apolloConfigs/release-68/prod
```

Expect hours. Exit status is non-zero if any organism failed; the summary names each one.

- [ ] **Step 3: Verify before handoff**

- every organism dir has the nine files and a `seq/` with three
- `twoBit/` count equals the roster size
- `report.txt` is present in the release dir
- `Apollo_curl` line count equals updates + renames + approved prunes
- `Apollo_groovy` contains only approved adds

- [ ] **Step 4: Sandbox the rename before prod**

Run the `cneoJEC21 → cdenJEC21` line from `Apollo_curl` against the Apollo **sandbox**, then
confirm the organism still reports 14 annotations and that gene tracks and BLAT work. Do not
run it against prod until that passes.

- [ ] **Step 5: Hand off to systems**

```bash
rsync -av ~/apolloConfigs/release-71/prod/ yew:/eupath/data/apolloConfigs/release-71/prod/
```

Then systems' documented procedure (build checklist §7) applies unchanged.

- [ ] **Step 6: Promote what was learned**

Add to `ApiCommonModel`'s docs or the harness `CLAUDE.md`: that the Apollo package is built
with `createApolloReleasePackage` on cedar, that the roster is seeded from live Apollo and
edited through `Model/data/apollo/roster-overlay.txt`, and that `faToTwoBit` must be on PATH.

---

## Notes for the implementer

**Do not create a worktree.** Mutagen syncs `~/workspaces/eupathdb` only. Work in place on
`feat/apollo-configs`.

**`bld ApiCommonModel/Model` after every change to `Model/`**, before running tests — the
tests load the installed copy from `GUS_HOME`, not your working tree.

**Never run `wb model` on this instance.** It OOMs in `wdkXml` on the UniDB portal and leaves
the webapp stopped.

**After any local `git pull` or branch switch**, run `bin/veup-git-sync.sh eupathdb` from the
harness checkout.

**stderr is not noise.** Several of these scripts are served through `responseFromCommand`,
which merges stderr into the JSON response body. That is why `runCapture` refuses output from
any command that wrote to stderr, and why Task 1 asserts `err_bytes=0`.

**The one thing that must never ship** is an add plus a prune for the same genome. It creates
an empty Apollo organism and orphans the curation work — 14 annotations in the case already
in front of us. `Reconcile::assertInvariants` exists for that, and it should stay noisy.
