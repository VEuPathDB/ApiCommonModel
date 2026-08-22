# Apollo release package generation from the UniDB portal

**Date:** 2026-08-21
**Repos changed:** `ApiCommonModel`
**Branch:** `feat/apollo-configs`
**Instance for QA:** eupathdb (`~/workspaces/eupathdb`), model `UniDB`, appDb `genomicsdb_071n`
**Replaces:** `~/apollo_config/bld-71-createApolloReleasePackage_ALL.pl` (Paul Wilkinson's
script) and its `Paul_Wilkinson_Handover_notes.docx`.

## 1. Goal

Each release, VEuPathDB must publish JBrowse configuration and sequence data for the
organisms hosted in Apollo, the genome curation platform. The existing script has not
produced a usable package since build 68, and its author has left the project.

Rebuild it as a maintained tool in `ApiCommonModel` that:

- runs on **cedar** against the **UniDB portal**, calling the `jbrowse*` scripts directly
  rather than scraping eleven component websites over HTTP;
- treats **live prod Apollo** as the roster's starting point, so curators' decisions are
  not silently reverted each build;
- reports what will be **added, pruned, and renamed** before anything is generated,
  because today nothing computes prunes at all;
- never mutates Apollo. It writes command files for a human to run, as today.

## 2. What is actually broken

Every row measured on 2026-08-21, not inferred.

| # | Fact | Evidence |
|---|---|---|
| 1 | `jbrowseOrganismList` does not compile | Line 11 passes `$organismAbbrev` to the `JBrowseUtil` constructor; the variable is never declared and the file is `use strict`. Fails identically over HTTP and on the command line. |
| 2 | Its history query is malformed | `$historySql` ends `and o.taxon_id = nt.taxon_id`; there is no `nt` in its FROM clause. `DBD::Pg` throws, the script exits **0**, and prints JSON with no `HISTORY` key. |
| 3 | The script reads Oracle-cased keys on Postgres | `addHistoryToOrganism` reads `$h->{PUBLIC_ABBREV}` / `$_->{ORGANISM_ABBREV}`; `DBD::Pg` returns lowercase. |
| 4 | Consequently Paul's script processes **zero** organisms | It reads `$organism->{IS_REFERENCE_STRAIN}` etc., all now `undef`, so every organism falls out at `next unless`. `/eupath/data/apolloConfigs/release-71/` on yew contains one empty `AmoebaDB/` dir, 0 data dirs, 0 twoBit, 0 update commands. |
| 5 | Releases 69 and 70 were never produced | `/eupath/data/apolloConfigs/` holds release-64…68, then 71 (empty). |
| 6 | `__DATA__` is a frozen build-68 snapshot | Its newest entries have `first_build = 68`; nothing from 69, 70, 71. 33 of the 48 organisms it "excludes" did not exist when it was last edited. |
| 7 | Its remaining exclusions are the `@databases` array, not the list | The other 15 are host genomes (`hsapREF`, `mmusC57BL6J`, `btauHereford`, `scerS288C`, …). Paul's array names 11 component DBs and omits HostDB and SchistoDB. On the portal that filter does not exist and must be stated explicitly. |
| 8 | The update-commands pass ignores the data filters | It walks the whole organism list, so release-68/prod emitted 461 curl + 28 groovy commands against 472 data dirs. |
| 9 | Nothing computes prunes | Confirmed by inspection; the handover notes list no prune step. |
| 10 | Two organisms have been renamed and are orphaned | `cneoJEC21` → `cdenJEC21`, `cglaCBS138` → `nglaCBS138`. Both old abbrevs are still in prod Apollo and absent from the portal. |
| 11 | One of them holds curation work | Apollo id 2452162, `cneoJEC21`, **14 annotations**, `publicMode=true`. Prod Apollo holds 14,600 annotations across 102 organisms. |
| 12 | Species taxon ID cannot detect a rename | `cneoJEC21` was species 5207; `cdenJEC21` is 40410. `cglaCBS138` (5478 → *Nakaseomyces*) likewise. |
| 13 | The renamed genome is byte-identical | b68 `cneoJEC21.fa.fai` vs b71 `CdeneoformansJEC21/genome.fasta.fai`: 14 sequences, identical names and lengths. |
| 14 | `applicationType=apollo` is unimplemented | `Store::makeUrlTemplate` is `die "TODO: make apollo work"`. `getConfigurationObject` dispatches `apollo` to the abstract `getApolloObject`; **39** classes implement `getJBrowseObject`, **1** implements `getApolloObject`. |
| 15 | 17 live organisms are deliberately hidden, and the update command would un-hide them | `publicMode=false` on 17 organisms; 16 are on the portal and 15 qualify as reference+annotated, so they are curator-hidden, not retired. 3 carry annotations (`iscaPalLabHiFi` 20, `treeQM6a` 11, `etenHoughton2021` 2). Paul's `updateOrganismInfo` curl hardcodes `"publicMode":"true"`, so running the generated commands re-publishes all 17. |

### Set sizes as of build 71

| set | count |
|---|---|
| portal organisms (`jbrowseOrganismList UniDB`) | 831 |
| reference **and** annotated | 501 |
| `__DATA__` | 471 |
| release-68/prod data dirs | 472 (471 + the `twoBit` symlink) |
| live prod Apollo | 459 |

`__DATA__` and release-68/prod match exactly, so the list did govern generation. It
diverges from Apollo in both directions: 13 organisms it contains are absent from Apollo
(overwhelmingly VectorBase — consistent with the notes' rule that genomes curated
elsewhere are excluded), and it lacks 48 that now qualify.

## 3. Roster model

```
roster(N) = apollo_live
            + adds     (approved, from the add-candidate bucket)
            − removes  (approved)
            ± renames  (repointed in place, never add+prune)
```

**Live prod Apollo is the seed**, not `__DATA__`. It is the only record of what curators
actually decided: it reflects the 13 removals `__DATA__` never captured, and it carries the
annotations that make a mistake expensive.

`reference AND annotated` is demoted from a gate to a *proposal* input. It never adds or
removes anything on its own.

`__DATA__` is retired. Its only irreducible content — organisms in Apollo that fail the
criteria — is recoverable from Apollo itself, and is 4 organisms, not 17:
`cposSilveira2022`, `lbraMHOMBR75M2904_2019`, `tbruLister427_2018`, `tcruYC6`.

### Seeding the overlay

Fifteen organisms qualify as reference+annotated, predate build 68, and have never been in
Apollo. Paul excluded them for free via an `@databases` array that omitted HostDB and
SchistoDB (fact 7); on the portal that filter does not exist, so without seeding they appear
as add candidates at every build forever and the bucket becomes noise nobody reads. They are
not one group, and must not be seeded as one:

| organisms | disposition |
|---|---|
| `hsapREF`, `mmusC57BL6J`, `rnorBNNHsdMcwi`, `btauHereford`, `clupfamiliarisSID07034`, `ggalbGalGal1`, `cpor2N`, `mfasREF`, `mmulAG07107`, `mmyomMyoMyo1`, `dmeliso-1` | host genomes — seed as `remove`; Apollo curates pathogens |
| `scerS288C`, `spom972h` | model fungi, in FungiDB, never in Apollo — seed as `remove`, but flag to the curation team as a decision nobody has consciously made |
| `hcapNAm1` (*Histoplasma mississippiense* NAm1) | **not** a host genome. A FungiDB pathogen that qualifies and is absent from Apollo. Leave it in the add-candidate bucket for the curation team. |
| `cdenJEC21` | rename target; resolved by rename detection before the add bucket is computed. No overlay entry. |

Recording these as `remove` with a stated reason is the point of the overlay: a decision made
once, with provenance, rather than an array that silently encoded it. The distinction above is
exactly what a project-name filter would have flattened — `hcapNAm1` would have been suppressed
along with the vertebrates, and nobody would ever have seen it.

## 4. Inputs

All read-only.

| input | source | provides |
|---|---|---|
| portal organisms | `jbrowseOrganismList UniDB` on cedar | abbrev, name, `name_for_filenames`, `strain_abbrev`, ref/annotated flags, species taxon, `HISTORY` (after the §8 fixes) |
| live Apollo | `POST /organism/findAllOrganisms` from a Penn host | `id`, `commonName`, `directory`, `blatdb`, `annotationCount`, `publicMode` |
| roster overlay | `$GUS_HOME/data/ApiCommonModel/Model/apollo/roster-overlay.txt` | `add`/`remove` lines with approver and reason |
| genome files | `webServices/UniDB/build-NN/<NameForFilenames>/genomeAndProteome/fasta/` | `genome.fasta` + `genome.fasta.fai` |

Verified: all 831 portal organisms have a directory and a `genome.fasta` under
`UniDB/build-71` (0 missing dirs, 0 missing fastas). `samtools faidx` is unnecessary — the `.fai` ships alongside and contains
no self-reference, so renaming to `<abbrev>.fa` / `<abbrev>.fa.fai` is safe.

The Apollo API is IP-restricted to Penn hosts. Credentials come from the environment
(`APOLLO_API_URL`, `APOLLO_API_USER`, `APOLLO_API_PASS`), never from a literal in the
source — Paul's script hardcodes a live password.

## 5. Reconciliation

Matching is on `organism_abbrev`, obtained from Apollo by parsing the trailing path
component of `directory` (`/data/apollo_data/tgonME49` → `tgonME49`). All 459 parse cleanly
with no duplicates. `directory` is machine-written by our own update commands; `commonName`
is editable in the Apollo GUI, so it is cross-checked and reported on mismatch, never used
for matching.

Five buckets, with build-71 counts:

| bucket | rule | count | action |
|---|---|---|---|
| update | in Apollo ∧ on portal | 457 | regenerate data, emit update command |
| add candidate | qualifies ∧ not in Apollo ∧ not `remove`d | 48 (33 new since b68) | **requires approval** |
| prune candidate | in Apollo ∧ not on portal ∧ not a rename | 2 → 0 after rename detection | **requires approval** |
| rename | see below | 2 | repoint in place |
| exception | in Apollo ∧ fails criteria | 4 | none; reported so it is not "fixed" |

The exception bucket exists to prevent work, and to surface an organism *becoming*
non-qualifying rather than letting it persist unnoticed.

### Rename detection

For each Apollo organism whose abbrev is absent from the portal, compare the `.fa.fai`
shipped in the previous release against the `.fai` of each portal organism sharing its
`strain_abbrev`. An identical set of sequence names and lengths means the same assembly
under a new name.

Species taxon ID is deliberately **not** used (fact 12). Strain abbrev narrows the
candidates; sequence identity decides.

A rename emits **one** update against the existing Apollo `id`, setting `directory`,
`blatdb`, and `commonName`. Emitting an add for the new abbrev in the same run is a hard
error, not a convention: `add cdenJEC21` + `prune cneoJEC21` creates an empty organism and
destroys 14 annotations — same inputs, same API, opposite outcome.

Renames whose sequence sets do **not** match fall through to prune-candidate and are
reported with their `annotationCount`, for a human.

## 6. Generation

Per organism in the approved roster:

| output | produced by |
|---|---|
| `trackList.json` | assembled by the tool; `jbrowseTracks <abbrev> UniDB 0 geneAnnotationTracks` supplies the include list, rewritten to local filenames, with `tracks` replaced by the reference-sequence track |
| `tracks.conf` | `$GUS_HOME/lib/jbrowse/auto_generated/<abbrev>/tracks.conf`, refseq stanza removed |
| `functions.conf` | `$GUS_HOME/lib/jbrowse/functions.conf` |
| `rnaseq.json`, `chipseq.json` | `jbrowseRnaAndChipSeqTracks <abbrev> UniDB <build> <wsDir> {RNASeq,ChIPSeq} jbrowse` |
| `rnaseqJunctions.json` | `jbrowseRNASeqJunctionTracks <abbrev> UniDB <build> <wsDir> 1 jbrowse` |
| `organismSpecific.json` | `jbrowseOrganismSpecificTracks <abbrev> UniDB 1 <build> <wsDir> jbrowse` |
| `dnaseq.json` | `jbrowseDNASeqTracks <abbrev> UniDB <build> <wsDir> jbrowse` |
| `seq/<abbrev>.fa`, `seq/<abbrev>.fa.fai` | copied and renamed from webServices |
| `seq/refSeqs.json` | `jbrowseRefSeqs $GUS_HOME UniDB <abbrev>` |
| `twoBit/<abbrev>.2bit` | `faToTwoBit` — the only new computation |

### faToTwoBit on cedar

`faToTwoBit` existed only on yew, at `/eupath/workflow-software/bin/faToTwoBit` — a 2016
build linked against `libssl.so.10`, `libcrypto.so.10`, and `libpng15.so.15`, none of which
exist on cedar (Rocky 9, glibc 2.34). Copying it across does not work.

Resolved by installing UCSC's current `linux.x86_64` build to `~/bin/faToTwoBit` on cedar
(2026-08-21), which is already on PATH. Verified byte-for-byte against the old one:

```
release-68 twoBit/cneoJEC21.2bit  (yew, 2016 binary)    4764116  a8b9cb95a7794c1ed7dcc3568edeaff9
build-71   cdenJEC21.2bit         (cedar, 2026 binary)  4764116  a8b9cb95a7794c1ed7dcc3568edeaff9
```

Identical output from two binaries a decade apart, over the renamed organism's genome. This
also independently confirms fact 13 at the byte level.

**Always regenerate; never copy forward.** Measured 0.17–0.74 s per genome, so the full
roster costs a couple of minutes. An incremental scheme keyed on genome version was
considered and rejected: it adds state to save nothing.

The tool must check for `faToTwoBit` on PATH at startup and fail immediately with the
install instruction, rather than 400 organisms into a run.

### URL absolutization

Apollo needs absolute URLs; the scripts emit site-relative `/a/…`. We generate with
`applicationType=jbrowse` and run a **single text pass per generated file**, rewriting
`/a/` to `https://veupathdb.org/a/`, followed by an assertion that no bare `/a/` survives.

`applicationType=apollo` is **not** used, and stays unimplemented (fact 14). It would need
`getApolloObject` in 39 classes, and even then would not cover the ~25 `/a/` literals that
live inside free text rather than in typed fields — HTML blobs (`<img src='/a/images/…'>`),
`onClick` and `menuTemplate` URLs, `baseUrl` values, and JavaScript function bodies
(`"function(track,f) { … '/a/app/record/gene/' + f.get('name') }"`). A typed approach
cannot reach inside a JS string; a text pass covers all of it uniformly.

This is deliberate, acknowledged debt. Paul did the same rewrite inline
(`s/\/a\//$website\/a\//g`) with no verification, so a missed URL became a track that
silently 404s inside Apollo. **The post-condition check is the part that makes this
approach safe, and is not optional.**

The base is the portal, `https://veupathdb.org`, not a per-component site — one host now
serves every organism.

No HTTP fetches, no `samtools`, and no dependency on the release being deployed to a public
site, so the package can be built as soon as webServices and the model exist — days earlier
than the current process permits.

**Failures are per-organism.** Paul's script `die`s on the first missing input, discarding
hours of completed work. This tool records the failure, continues, prints a summary, and
exits non-zero.

## 7. Output

`~/apolloConfigs/release-NN/<env>/` on cedar (`--out-dir` overridable). `/eupath` is not
mounted on cedar; the rsync to yew is performed manually after inspection, and the tool does
not do it.

Layout is unchanged from release-68, so systems' documented procedure still applies:

```
release-NN/<env>/
  data/<abbrev>/            (symlinked into data/ as today)
  twoBit/<abbrev>.2bit
  updateCommands/{Apollo_curl,Apollo_groovy}
  report.txt                (new: the five buckets, as generated)
```

## 8. Packaging

`ApiCommonModel/Model/bin/createApolloReleasePackage`, logic in
`Model/lib/perl/ApolloRelease/*.pm`, roster overlay in `Model/data/apollo/`. Installed to
`gus_home` by `bld ApiCommonModel/Model` (verified: `Model/data/` installs to
`$GUS_HOME/data/ApiCommonModel/Model/`).

It lives here, not in `agentic-veupath-dev`, because it calls the `jbrowse*` scripts and must
version with them — an `applicationType` change has to move in one commit. The harness
invokes it as a `build.commands` entry.

Two phases, because they cost differently:

- `--report` — minutes. Portal + Apollo + overlay; prints the buckets. Safe at any time,
  including before the release completes. This is what goes to the curation team.
- `--generate` — hours. Builds data and command files for the approved roster.

Prerequisite fixes to `jbrowseOrganismList`, all three (nothing works without `HISTORY`):
the undeclared `$organismAbbrev` (done), the `nt.taxon_id` join corrected to
`dd.taxon_id = o.taxon_id` (verified: returns first/last build for all 831 organisms), and
the Oracle-cased keys in `addHistoryToOrganism`.

## 9. Safety invariants

1. The tool never calls a mutating Apollo endpoint.
2. Prune emits `publicMode=false`, not a delete — reversible, and Apollo's API has no delete
   in use anyway.
3. Add and prune require an overlay entry; neither is inferred from the criteria alone.
4. A rename and an add for the same genome cannot both be emitted.
5. Every generated file passes the no-bare-`/a/` check before the run is declared successful.
6. **An update never changes an organism's `publicMode`.** It is echoed back from the value
   Apollo currently holds. 17 organisms are deliberately hidden by curators (fact 15); a
   hardcoded `"publicMode":"true"` — which is what the previous script emitted — silently
   re-publishes all of them, three with annotations. Publishing and unpublishing are curation
   decisions, and the only bucket permitted to change that state is an approved prune.
7. Credentials come from the environment. The repo contains no password.

## 10. Verification

**Release-68 is not a baseline.** Between b68 and b71 the track layer moved from REST to
flat files, the database moved Oracle → Postgres, and a large number of track definitions
changed. Output that matched release-68 would be evidence of a *bug*, not of correctness.
Release-68 is useful for exactly two things: the file-name inventory a working organism dir
must contain (§6), and the `faToTwoBit` reproducibility check already done.

The real baseline is **what the portal serves today**. Apollo's config and the site's JBrowse
config are generated from the same scripts against the same model; the Apollo variant should
differ only by known, enumerable transformations. So:

- **Equivalence with the live site, per organism.** For a probe organism, generate the Apollo
  package and diff each file against what the portal's own JBrowse serves for that organism.
  Every difference must fall into one of four declared classes:
  1. URL absolutization (`/a/` → `https://veupathdb.org/a/`),
  2. the reference-sequence track replaced by the local `IndexedFasta` track,
  3. `include` URLs rewritten to local filenames,
  4. removals: the `[tracks.refseq]` stanza and `user-datasets-jbrowse` includes.

  A difference outside those four classes is a defect. This is the test that would have
  caught Paul's silent skips, and it is meaningful *because* the tracks changed.
- **Track-count floor per organism.** Non-zero track count, and every `include` named in
  `trackList.json` resolves to a file that exists and parses. Empty-but-valid JSON is the
  characteristic failure of the flat-file migration and is invisible to a schema check.
- **URL liveness on a sample.** For a handful of organisms, HEAD every absolutized store URL
  and require 200. The absolutization assertion proves the string changed; only a request
  proves it points at something.
- **Unit tests** for reconciliation over fixture JSON: the two known renames, an annotated
  prune candidate, an overlay add, and the mutual-exclusion rule of §5.
- **Sandbox before prod**, per the post-release checklist: gene track drags into the
  annotation track, BLAT works against the new `.2bit`. Specifically exercise the
  `cneoJEC21` → `cdenJEC21` repoint on the sandbox and confirm all 14 annotations survive
  before it is ever run against prod.

Probe organisms: `tgonME49` (rich track set, 10 annotations in Apollo), `pfal3D7` (different
component DB, partitioned queries), and `cdenJEC21` (the rename).

## 11. Deferred

- **A real `apollo` application type.** When JBrowse2/Apollo3 arrives, `applicationType`
  becomes the correct seam and §6's text pass retires. Not worth 39 classes now for output
  that differs from `jbrowse` only in URL base.
- **JBrowse2 output.** The scripts accept `applicationType=jbrowse2`; nothing here uses it.
- **`datasetAndPresenterProps.conf` migration.** Paul's notes describe removing the DB handle
  from the track scripts in favour of a per-organism props file. Partially landed upstream,
  and independent of this work, which consumes those scripts' output either way.
- **Apollo `genus`/`species` fields.** Neither the curl nor the arrow command touches them,
  so after a rename `commonName` will say *deneoformans* while those fields may not.
  Determine whether the Apollo GUI keys off them; if so, this becomes part of the rename
  command.
- **`--environment qa`.** Retained from the old script and still generated, but the qa and
  prod rosters have never differed by anything but staleness. Revisit whether qa is worth
  producing at all.
