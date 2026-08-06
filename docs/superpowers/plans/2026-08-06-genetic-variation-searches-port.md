# Genetic Variation Searches Port — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the four remaining Genetic Variation searches — `GenesByNgsSnps`,
`SequencesByPloidy`, `GenesByCopyNumber`, `GenesByCopyNumberComparison` — onto the merged
dnaseq/EDA world, so all eight dnaseq searches work and are categorized together.

**Architecture:** `GenesByNgsSnps` is uncommented and repointed from the absent `snpParams`
paramSet to its live `variationParams` twins; its HSSS plugin was already fixed by the
2026-08-05 plumbing work. The three CNV searches are rebuilt on corrected copy-number tables
that drop the dead `PANIO_p`/`study.Input` join and key on an EDA sample stable ID. Those
tables land transitionally in `apidbtuning` (buildable now via Jenkins) and permanently in
`webready/*.psql` (next workflow run).

**Tech Stack:** WDK model XML (questions, queries, params, ontology), EuPathDB tuningManager
XML, PostgreSQL, the `wb` build wrapper, Claude in Chrome for live QA.

**Spec:** `ApiCommonModel/docs/superpowers/specs/2026-08-06-genetic-variation-searches-port-design.md`

---

## How "TDD" works here

There is no unit-test harness for WDK model XML. The test-first discipline still applies,
in this form — **every task establishes a failing observation before changing anything**:

| Instead of | Do this |
|---|---|
| write a failing test | run the build / query / service endpoint and **capture the current failure or absence** |
| watch it fail | confirm the exact error text or the missing item |
| implement | make the edit |
| watch it pass | re-run the *same* command and confirm the failure is gone |

Never skip the "before" observation. Three of these four searches currently **build fine and
silently return nothing**, which is exactly the failure mode a "did it build?" check misses.

### The app lives under a context path — `/service` alone is a 404

Verified 2026-08-06 from an authenticated tab. The app is served at
`https://jbrestel.plasmodb.org/plasmo.jbrestel/app`, so:

| fetch | result |
|---|---|
| `/service/record-types/transcript` | **404**, `text/html` |
| `/plasmo.jbrestel/service/record-types/transcript` | **200**, `application/json` |

Every `javascript_tool` snippet in this plan therefore derives the base from the current
location rather than hardcoding it:

```javascript
const BASE = window.location.pathname.replace(/\/app.*$/, '');   // -> "/plasmo.jbrestel"
```

Keep the origin guard as well. The two catch different failures: the origin guard catches
an unauthenticated tab that has been redirected to **production** (where the fetch would
succeed and answer for the wrong site), and the BASE derivation catches the 404. A bare
`/service` fetch throws at `.json()` rather than returning empty, so it fails loudly — but
only if you do not wrap it in a try/catch that swallows it.

### `wdkQuery -showQuery` does not work on these queries — use `-showParams`

Discovered during Task 1 and verified against a **known-good** search. Any query with a
dependent `filterParam` makes the `wdkQuery` CLI fail before it renders SQL:

```
ERROR - org.gusdb.wdk.model.test.ParamValuesFactory:84 - Unable to populate param values set with defaults
```

`VariationsBy.VariationsByIsolateGroup` — one of the five searches that work in production
today — fails identically. It is a CLI auto-default limitation, **not** a defect in the
query, so do not treat it as one and do not try to fix it.

This affects every query in this plan that uses `variation_sample_meta` or
`cnv_sample_meta`: Tasks 1, 9, 10 and 12.

**Use instead:**

- **`-showParams`** to prove the query resolves and its params are correctly typed. This
  works, and is the "did my XML wire up" check.
- **The model XML itself** as the SQL to run in psql. This is normally *not* safe advice —
  the CLAUDE.md rule is that raw model XML is not what executes, because
  `presenterInjectTemplates` expands `-- TEMPLATE_ANCHOR` into per-dataset `UNION` branches.
  It is safe **here specifically**: all three CNV queries were checked and contain **zero**
  `TEMPLATE_ANCHOR` occurrences, so the XML SQL and the assembled SQL are identical. If you
  add a template anchor to any of them, this shortcut stops being valid.

## Environment

All commands run from `/home/jbrestel/workspaces/agentic-veupath-dev` unless stated.
Source edits are in `/home/jbrestel/workspaces/plasmodb/<repo>/`, already on branch
`dnaseq-merge-experiments`. Mutagen carries edits to the remote; **do not** run builds
locally.

| Thing | Value |
|---|---|
| build | `bin/veup-build.sh plasmodb wb model` / `... wb ontology` |
| logs | `bin/veup-logs.sh plasmodb mark <label>` then `bin/veup-logs.sh plasmodb since <label>` |
| appDb | `psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a` |
| app | `https://jbrestel.plasmodb.org` |
| ssh host | `cedar` |
| setenv | `/var/www/jbrestel.plasmodb.org/project_home/../etc/setenv` |
| WDK model name | `PlasmoDB` |

**`wb ontology` is a superset of `wb model`** — when a task needs the ontology rebuilt, run
only `wb ontology`. Each target reloads the webapp when it finishes.

**Database rule:** read-only everywhere except the `jbrestel` schema. Tasks 4 and 5 create
tables in `jbrestel` — that is explicitly authorised for this work and nowhere else.

## File structure

| File | Responsibility | Tasks |
|---|---|---|
| `ApiCommonModel/Model/lib/wdk/model/questions/queries/geneQueries.xml` | `GenesByNgsSnps` processQuery; both gene CNV sqlQueries | 1, 9, 10 |
| `.../questions/geneQuestions.xml` | `GenesByNgsSnps`, `GenesByCopyNumber`, `GenesByCopyNumberComparison` questions | 2, 11 |
| `.../questions/queries/genomicQueries.xml` | `SequenceIds.ByCopyNumber` sqlQuery | 12 |
| `.../questions/genomicQuestions.xml` | `SequencesByPloidy` question | 12 |
| `.../questions/params/organismParams.xml` | CNV organism vocabularies; retire `organismSinglePickCnv` | 8, 14 |
| `.../questions/params/variationParams.xml` | `cnv_sample_meta` filterParam | 8 |
| `.../questions/params/sharedParams.xml` | retire `CNV_strain` and its two vocab queries | 14 |
| `.../wdk/ontology/individuals.txt` | category rows for all four searches | 13 |
| `ApiCommonModel/Model/lib/xml/tuningManager/apiTuningManager.xml` | transitional `apidbtuning` CNV tables | 6 |
| `ApiCommonModel/Model/lib/psql/webready/orgSpecific/{Gene,Chr}CopyNumbers_p{,_ix}.psql` | permanent webready CNV tables (4 files) | 7 |

---

# PHASE 1 — `GenesByNgsSnps`

No dependency on any CNV work. Ships on its own.

## Task 1: Uncomment and repoint the `GenesByNgsSnps` processQuery

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/geneQueries.xml:2723-2856`

The `processQuery` sits inside a comment block opening at line 2723
(`<!-- UNCOMMENT WHEN SNPS are AVAILABLE`) and closing at line 2856 (`-->`).

- [ ] **Step 1: Establish the failing observation — the query is absent from the model**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/project_home/../etc/setenv && \
  wdkQuery -model PlasmoDB -query GeneId.GenesByNgsSnps -showParams"'
```

Expected: `WdkModelException: Query Set GeneId does not include query GenesByNgsSnps`.
Record the exact message — Step 5 asserts it is gone.

- [ ] **Step 2: Remove the two comment-delimiter lines**

Delete line 2723 (`<!-- UNCOMMENT WHEN SNPS are AVAILABLE`) and line 2856 (`-->`).
Change nothing between them yet — this step is only the un-commenting, so that if the
build breaks, the cause is unambiguous.

- [ ] **Step 3: Repoint the five `snpParams` refs and drop the dead organism override**

`snpParams` is absent from the assembled model, so every one of these fails model load.
Within the now-uncommented `processQuery`, replace:

```xml
        <paramRef ref="organismParams.organismSinglePick" displayType="treeBox" queryRef="organismVQ.withNgsSNPsTree" quote="false" noTranslation="true">
        <help>The organism you choose will determine the strains/isolates from which you can identify SNPs.</help>
      </paramRef>

      <paramRef ref="snpParams.ngsSnp_strain_meta" prompt="Set of Samples">
        <help>SNPs are defined here as sequence differences between the selected strains. If you want to include
          sequence differences between the selected strains and the reference genome, then also include the reference
          strain in your search.
        </help>
      </paramRef>
      <paramRef ref="snpParams.WebServicesPath"/>
      <paramRef ref="snpParams.ReadFrequencyPercent"/>

      <paramRef ref="snpParams.MinPercentMinorAlleles"/>
      <paramRef ref="snpParams.MinPercentIsolateCalls"/>
```

with:

```xml
      <!-- Plain organismSinglePick, as the five working variation searches use. The
           original overrode queryRef to organismVQ.withNgsSNPsTree, which reads
           apidbtuning.snpstrains - a table that does not exist in this build. -->
      <paramRef ref="organismParams.organismSinglePick" quote="false" noTranslation="true">
        <help>The organism you choose will determine the samples from which you can identify SNPs.</help>
      </paramRef>

      <!-- variation_sample_meta is a CONTRACT with the Java plugin, not a preference:
           FindGenesWithSnpCharsPlugin extends FindPolymorphismsPlugin and therefore
           inherits getStrainFilterParamName() returning exactly this string. A mismatch
           fails at run time, not at build time. -->
      <paramRef ref="variationParams.variation_sample_meta" prompt="Set of Samples">
        <help>SNPs are defined here as sequence differences between the selected samples. If you want to include
          sequence differences between the selected samples and the reference genome, then also include the reference
          sample in your search.
        </help>
      </paramRef>
      <paramRef ref="variationParams.WebServicesPath"/>
      <paramRef ref="variationParams.ReadFrequencyPercent"/>

      <paramRef ref="variationParams.MinPercentMinorAlleles"/>
      <paramRef ref="variationParams.MinPercentIsolateCalls"/>
```

- [ ] **Step 4: Delete the three stale `testParamValues` blocks**

They name a param that no longer exists, with old strain names rather than EDA sample
stable IDs. Delete exactly:

```xml
      <testParamValues includeProjects="CryptoDB">
        <paramValue name="ngsSnp_strain_meta">IowaII</paramValue>
      </testParamValues>
      <testParamValues includeProjects="ToxoDB">
        <paramValue name="ngsSnp_strain_meta">GT1</paramValue>
      </testParamValues>
      <testParamValues includeProjects="TriTrypDB">
        <paramValue name="ngsSnp_strain_meta">Tb-927</paramValue>
      </testParamValues>
```

Leave the three `postCacheUpdateSql` blocks and all eleven `wsColumn` declarations exactly
as they are — they are the plugin's output contract and read healthy tables.

- [ ] **Step 5: Build and confirm the failing observation is resolved**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: build succeeds. Then re-run Step 1's command.
Expected: it now lists the query's params (including `variation_sample_meta` as a
`FilterParamNew`) instead of "does not include query".

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/geneQueries.xml
git commit -m "Restore the GenesByNgsSnps process query on variationParams

The query was commented out because it referenced snpParams, which is
absent from the assembled model. Repoint the five refs to their
variationParams twins and drop the organismVQ.withNgsSNPsTree override,
which reads a table this build does not have.

variation_sample_meta is required rather than chosen:
FindGenesWithSnpCharsPlugin inherits getStrainFilterParamName() from
FindPolymorphismsPlugin, which returns that exact string."
```

## Task 2: Uncomment the `GenesByNgsSnps` question

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/geneQuestions.xml:1418-1534`

- [ ] **Step 1: Establish the failing observation — the search is absent from the service**

From an **already-loaded, logged-in** `https://jbrestel.plasmodb.org` tab, using Claude
Chrome's `javascript_tool`:

```javascript
if (!window.location.origin.includes('jbrestel')) throw new Error('WRONG ORIGIN: ' + window.location.origin);
const BASE = window.location.pathname.replace(/\/app.*$/, '');   // -> "/plasmo.jbrestel"
if (!BASE) throw new Error('NO CONTEXT PATH: ' + window.location.pathname);
const r = await fetch(BASE + '/service/record-types/transcript');
const j = await r.json();
JSON.stringify(j.searches.map(s => s.urlSegment).filter(n => /NgsSnp/i.test(n)))
```

Expected: `[]`. The origin guard is mandatory — an unauthenticated dev tab redirects to
`veupathdb.org` and the fetch answers for **production**, which would make this check lie.

- [ ] **Step 2: Remove the two comment-delimiter lines**

Delete line 1418 (`<!-- UNCOMMENT WHEN SNPS are AVAILABLE`) and line 1534 (`-->`).

- [ ] **Step 3: Delete the deprecated `propertyList` blocks**

The file's own comment marks them deprecated (`## propertyList organism is deprecated`).
Delete that comment line and every `<propertyList name="organism" …>…</propertyList>` block
inside this question — they hardcode an organism list the search no longer needs.

Keep everything else: `searchCategory="Population Biology"`, `displayName`,
`shortDisplayName`, `attributesList`, both project-scoped `<description>` blocks, and all
eight `dynamicAttributes` columns.

- [ ] **Step 4: Build**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: succeeds. A failure naming `snpParams` means Task 1 missed a ref.

- [ ] **Step 5: Confirm the failing observation is resolved**

Re-run Step 1's `javascript_tool` snippet (reload the tab first — the webapp restarted).
Expected: `["GenesByNgsSnps"]`.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/geneQuestions.xml
git commit -m "Restore the GenesByNgsSnps question

Drops the deprecated per-project propertyList organism blocks, which the
file itself marks deprecated and which pin an organism list the search
no longer needs."
```

## Task 3: Categorize and live-QA `GenesByNgsSnps`

**Files:** none — `individuals.txt:99` is already live and un-commented. It was an orphan
row naming a question the model did not define; Task 2 gave it a target.

- [ ] **Step 1: Establish the failing observation — the tree has no usable node yet**

The OWL still predates Task 2. From the app tab:

```javascript
if (!window.location.origin.includes('jbrestel')) throw new Error('WRONG ORIGIN: ' + window.location.origin);
const BASE = window.location.pathname.replace(/\/app.*$/, '');   // -> "/plasmo.jbrestel"
if (!BASE) throw new Error('NO CONTEXT PATH: ' + window.location.pathname);
const j = await (await fetch(BASE + '/service/ontologies/Categories')).json();
const hits = [];
(function walk(n, parent) {
  const p = n.properties || {};
  if ((p.name || []).some(x => /GenesByNgsSnps/.test(x))) hits.push(parent);
  (n.children || []).forEach(c => walk(c, (n.properties || {})['EuPathDB alternative term'] || (n.properties||{}).label));
})(j.tree, null);
JSON.stringify(hits)
```

Record the result.

- [ ] **Step 2: Rebuild the ontology**

```bash
bin/veup-logs.sh plasmodb mark ngssnps
bin/veup-build.sh plasmodb wb ontology
```

`wb ontology`, not `wb model` — it regenerates `individuals.owl` → `categories_merged.owl`,
which is what the app reads. `wb model` alone leaves the tree stale.

- [ ] **Step 3: Confirm placement**

Reload the tab and re-run Step 1's snippet.
Expected: `["Genetic Variation"]`.

- [ ] **Step 4: Run the search live**

Navigate to the search from the menu under Genetic Variation. Choose organism
*Plasmodium falciparum 3D7*, accept the default sample set (or narrow to a handful),
leave the SNP-characteristic params at their defaults, and Get Answer.

Expected: a non-zero gene result with the SNP columns (`Total SNPs`, `SNPs per Kb (CDS)`,
`Nonsyn/syn SNP ratio`, `Synonymous SNPs`, `Nonsynonymous SNPs`, `Nonsense SNPs`,
`Non-coding SNPs`) populated — **not** blank or all-zero.

This is the end-to-end proof of the 2026-08-05 plumbing: the `/dnaseq` search directory and
the `Variant_` ID prefix are both exercised here for the first time by a gene search.

- [ ] **Step 5: Check the logs for silent breakage**

```bash
bin/veup-logs.sh plasmodb since ngssnps --quiet
```

Expected: the error logs report `silent:`. Any HSSS stack trace here means the plugin
found no organism directory — check that `cedar:/home/jbrestel/webserviceTest/Pfalciparum3D7/dnaseq/`
exists and holds `readFreq20/40/60/80`.

- [ ] **Step 6: Commit (documentation only, if anything changed)**

If Steps 1–5 required no file change, there is nothing to commit — say so explicitly rather
than inventing a commit. Phase 1 is complete.

---

# PHASE 2 — Corrected CNV tables

Nothing in this phase touches a search. It produces verified SQL and lands it in two
definition sites.

## Task 4: Prove `GeneCopyNumbers` in the `jbrestel` schema

**Files:** none — this is throwaway proof-of-concept SQL. It must never be committed.

- [ ] **Step 1: Establish the failing observation — the real table is empty**

```bash
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "select count(*) from webready.genecopynumbers_p"
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "select count(*) from webready.panio_p"
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "select count(*) from study.input"
```

Expected: `0`, `0`, `0`. That chain — no `study.Input` → no `PANIO_p` → no CNV table — is
the entire reason for this phase.

- [ ] **Step 2: Build the corrected table**

```sql
DROP TABLE IF EXISTS jbrestel.GeneCopyNumbers;

CREATE TABLE jbrestel.GeneCopyNumbers AS
SELECT DISTINCT
    ta.project_id
  , ta.org_abbrev
  , ta.organism
  , ta.taxon_id
  , ta.source_id
  , ta.gene_source_id
  , regexp_replace(pan.name, '_GeneCNV$', '') AS eda_sample_stable_id
  , gcn.haploid_number  AS raw_estimate
  , gcn.ref_copy_number AS ref_cn
  , CASE WHEN (gcn.haploid_number < 0.01) THEN 0
         WHEN (0.01 < gcn.haploid_number AND gcn.haploid_number < 1.85) THEN 1
         ELSE round(gcn.haploid_number) END AS haploid_number
  , ta.chromosome
  , ta.na_sequence_id
FROM apidb.genecopynumber gcn
JOIN study.protocolappnode pan
     ON pan.protocol_app_node_id = gcn.protocol_app_node_id
JOIN webready.transcriptattributes_p ta
     ON ta.gene_na_feature_id = gcn.na_feature_id
WHERE ta.gene_type IN ('protein coding', 'protein coding gene');

CREATE INDEX gcn_tt_ix ON jbrestel.GeneCopyNumbers (organism, eda_sample_stable_id);
ANALYZE jbrestel.GeneCopyNumbers;
```

The rounding `CASE` is copied **verbatim** from `GeneCopyNumbers_p.psql`, gap at exactly
`0.01` included. Do not "tidy" it — a port must not change data semantics.

- [ ] **Step 3: Parity checks**

```sql
-- (a) no base row is lost
SELECT (SELECT count(*) FROM apidb.genecopynumber)                 AS base_rows,
       (SELECT count(DISTINCT g.gene_copy_number_id)
          FROM apidb.genecopynumber g
          JOIN webready.transcriptattributes_p ta
            ON ta.gene_na_feature_id = g.na_feature_id)            AS matched_base_rows;

-- (b) result size sits at or below the pre-DISTINCT fan-out
SELECT count(*) FROM jbrestel.GeneCopyNumbers;

-- (c) sample identity
SELECT count(DISTINCT eda_sample_stable_id) FROM jbrestel.GeneCopyNumbers;

-- (d) organisms
SELECT organism, count(DISTINCT eda_sample_stable_id)
FROM jbrestel.GeneCopyNumbers GROUP BY 1 ORDER BY 1;

-- (e) the rounding CASE covers all three branches
SELECT CASE WHEN raw_estimate < 0.01 THEN 'zero'
            WHEN raw_estimate < 1.85 THEN 'one'
            ELSE 'rounded' END AS branch,
       count(*), min(raw_estimate), max(raw_estimate), min(haploid_number), max(haploid_number)
FROM jbrestel.GeneCopyNumbers GROUP BY 1 ORDER BY 1;
```

Expected: (a) `base_rows` = `matched_base_rows` = `3389444` — **no base row is dropped**.
(b) at or below `3404180` (the join fans out over multi-transcript genes, then `DISTINCT`
collapses). (c) `441`. (d) three organisms — `Aspergillus fumigatus Af293`,
`Plasmodium falciparum 3D7`, `Trypanosoma brucei brucei TREU927`. (e) all three branches
present, with `haploid_number` equal to `0` on the `zero` branch and `1` on the `one` branch.

Note: `gene_type IN ('protein coding', 'protein coding gene')` currently removes **nothing**
(3,404,180 rows with and without it). It is kept because it is the original semantics — but
do not build a parity assertion on it.

- [ ] **Step 4: Confirm every sample name really is an EDA sample stable ID**

```sql
SELECT count(*) AS unmatched
FROM (SELECT DISTINCT eda_sample_stable_id s, organism FROM jbrestel.GeneCopyNumbers) g
WHERE NOT EXISTS (
  SELECT 1 FROM eda.attributevalue_s3be28bbe14_sample WHERE sample_stable_id = g.s
  UNION ALL
  SELECT 1 FROM eda.attributevalue_s82c3cb5b8b_sample WHERE sample_stable_id = g.s
  UNION ALL
  SELECT 1 FROM eda.attributevalue_s59941a54bb_sample WHERE sample_stable_id = g.s
);
```

Expected: `0`. This is the load-bearing claim of the whole redesign — if it is not zero,
**stop** and re-derive the suffix rule rather than proceeding.

- [ ] **Step 5: Timing baseline**

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM jbrestel.GeneCopyNumbers
WHERE organism = 'Plasmodium falciparum 3D7'
  AND eda_sample_stable_id IN (
    SELECT DISTINCT eda_sample_stable_id FROM jbrestel.GeneCopyNumbers
    WHERE organism = 'Plasmodium falciparum 3D7' LIMIT 10);
```

Expected: uses `gcn_tt_ix`; well under the 218 ms base-table baseline for 10 samples.
Record the number — Task 15 compares against it.

- [ ] **Step 6: No commit**

Nothing to commit; `jbrestel.*` is scratch. Record the five results in the task notes so
Task 6 can be written against measured numbers.

## Task 5: Prove `ChrCopyNumbers` in the `jbrestel` schema

**Files:** none — throwaway, as Task 4.

- [ ] **Step 1: Establish the failing observation**

```bash
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "select count(*) from webready.chrcopynumbers_p"
```

Expected: `0`.

- [ ] **Step 2: Build the corrected table**

```sql
DROP TABLE IF EXISTS jbrestel.ChrCopyNumbers;

CREATE TABLE jbrestel.ChrCopyNumbers AS
SELECT DISTINCT
    sa.project_id
  , sa.org_abbrev
  , sa.organism
  , sa.taxon_id
  , sa.source_id
  , sa.na_sequence_id
  , sa.chromosome
  , ccn.chr_copy_number AS ploidy
  , regexp_replace(pan.name, '_Ploidy$', '') AS eda_sample_stable_id
FROM apidb.chrcopynumber ccn
JOIN study.protocolappnode pan
     ON pan.protocol_app_node_id = ccn.protocol_app_node_id
JOIN webready.genomicseqattributes_p sa
     ON sa.na_sequence_id = ccn.na_sequence_id
WHERE sa.chromosome IS NOT NULL;

CREATE INDEX ccn_tt_ix ON jbrestel.ChrCopyNumbers (organism, eda_sample_stable_id);
ANALYZE jbrestel.ChrCopyNumbers;
```

This sources from `GenomicSeqAttributes_p`, **not** `TranscriptAttributes_p` as the current
`ChrCopyNumbers_p.psql` does. Chromosome ploidy is sequence-level; reaching through the
transcript table for it was incidental, and `SequencesByPloidy` already reads the sequence
table.

- [ ] **Step 3: Parity checks**

```sql
SELECT count(*) FROM jbrestel.ChrCopyNumbers;
SELECT count(DISTINCT eda_sample_stable_id) FROM jbrestel.ChrCopyNumbers;
SELECT organism, count(DISTINCT eda_sample_stable_id), count(DISTINCT na_sequence_id)
FROM jbrestel.ChrCopyNumbers GROUP BY 1 ORDER BY 1;
```

Expected: `4936` rows exactly (the join is on `na_sequence_id`, so no fan-out); `452`
distinct samples; the same three organisms as Task 4.

- [ ] **Step 4: Confirm the gene↔chr join key survives**

This is what replaces the dead `g.input_pan_id = c.input_pan_id`.

```sql
SELECT (SELECT count(DISTINCT eda_sample_stable_id) FROM jbrestel.GeneCopyNumbers) AS gene_samples,
       (SELECT count(DISTINCT eda_sample_stable_id) FROM jbrestel.ChrCopyNumbers)  AS chr_samples,
       (SELECT count(*) FROM (SELECT DISTINCT eda_sample_stable_id FROM jbrestel.GeneCopyNumbers
                              INTERSECT
                              SELECT DISTINCT eda_sample_stable_id FROM jbrestel.ChrCopyNumbers) x) AS both;
```

Expected: `441 | 452 | 441` — every gene-CNV sample has chromosome ploidy. If `both` is less
than `gene_samples`, the gene searches will silently drop rows; **stop** and investigate.

- [ ] **Step 5: Confirm sample names are EDA sample stable IDs**

Repeat Task 4 Step 4's query against `jbrestel.ChrCopyNumbers`.
Expected: `0` unmatched.

- [ ] **Step 6: No commit** — scratch schema. Record results in the task notes.

## Task 6: Add the transitional tuning tables

**Files:**
- Modify: `ApiCommonModel/Model/lib/xml/tuningManager/apiTuningManager.xml`

Add two `<tuningTable>` elements alongside the existing 55. Follow the file's established
shape (see `<tuningTable name="GeneId">`): `&1` is the version suffix the tuningManager
substitutes.

- [ ] **Step 1: Establish the failing observation**

```bash
grep -c "tuningTable name=\"GeneCopyNumbers\"\|tuningTable name=\"ChrCopyNumbers\"" \
  /home/jbrestel/workspaces/plasmodb/ApiCommonModel/Model/lib/xml/tuningManager/apiTuningManager.xml
```

Expected: `0`.

- [ ] **Step 2: Add the two tuning tables**

Insert before the closing element of the `<tuningTables>` block:

```xml
  <!-- TRANSITIONAL. Mirrors webready/orgSpecific/GeneCopyNumbers_p.psql, which is
       corrected in the same change but does not take effect until the next workflow
       run. Scheduled for deletion one release later: see the port design doc, section 7.
       Any edit here MUST be mirrored in that .psql file, and vice versa. -->
  <tuningTable name="GeneCopyNumbers">
    <externalDependency name="apidb.GeneCopyNumber"/>
    <externalDependency name="study.ProtocolAppNode"/>
    <externalDependency name="webready.TranscriptAttributes_p"/>
    <sql>
      <![CDATA[
        create table GeneCopyNumbers&1 as
        SELECT DISTINCT
            ta.project_id
          , ta.org_abbrev
          , ta.organism
          , ta.taxon_id
          , ta.source_id
          , ta.gene_source_id
          , regexp_replace(pan.name, '_GeneCNV$', '') AS eda_sample_stable_id
          , gcn.haploid_number  AS raw_estimate
          , gcn.ref_copy_number AS ref_cn
          , CASE WHEN (gcn.haploid_number < 0.01) THEN 0
                 WHEN (0.01 < gcn.haploid_number AND gcn.haploid_number < 1.85) THEN 1
                 ELSE round(gcn.haploid_number) END AS haploid_number
          , ta.chromosome
          , ta.na_sequence_id
        FROM apidb.genecopynumber gcn
        JOIN study.protocolappnode pan
             ON pan.protocol_app_node_id = gcn.protocol_app_node_id
        JOIN webready.transcriptattributes_p ta
             ON ta.gene_na_feature_id = gcn.na_feature_id
        WHERE ta.gene_type IN ('protein coding', 'protein coding gene')
      ]]>
    </sql>
    <sql>
      <![CDATA[
        create index GeneCopyNumbersTT_i1_idx&1 ON GeneCopyNumbers&1 (organism, eda_sample_stable_id)
      ]]>
    </sql>
  </tuningTable>

  <!-- TRANSITIONAL. Mirrors webready/orgSpecific/ChrCopyNumbers_p.psql. Same sunset and
       same mirroring obligation as GeneCopyNumbers above. -->
  <tuningTable name="ChrCopyNumbers">
    <externalDependency name="apidb.ChrCopyNumber"/>
    <externalDependency name="study.ProtocolAppNode"/>
    <externalDependency name="webready.GenomicSeqAttributes_p"/>
    <sql>
      <![CDATA[
        create table ChrCopyNumbers&1 as
        SELECT DISTINCT
            sa.project_id
          , sa.org_abbrev
          , sa.organism
          , sa.taxon_id
          , sa.source_id
          , sa.na_sequence_id
          , sa.chromosome
          , ccn.chr_copy_number AS ploidy
          , regexp_replace(pan.name, '_Ploidy$', '') AS eda_sample_stable_id
        FROM apidb.chrcopynumber ccn
        JOIN study.protocolappnode pan
             ON pan.protocol_app_node_id = ccn.protocol_app_node_id
        JOIN webready.genomicseqattributes_p sa
             ON sa.na_sequence_id = ccn.na_sequence_id
        WHERE sa.chromosome IS NOT NULL
      ]]>
    </sql>
    <sql>
      <![CDATA[
        create index ChrCopyNumbersTT_i1_idx&1 ON ChrCopyNumbers&1 (organism, eda_sample_stable_id)
      ]]>
    </sql>
  </tuningTable>
```

- [ ] **Step 3: Confirm the SQL matches what Tasks 4–5 proved**

Diff the two `create table` bodies against the `CREATE TABLE AS` statements from Tasks 4
and 5. They must be character-identical below the `SELECT DISTINCT`. Any drift here is a
bug that will not surface until Jenkins runs.

- [ ] **Step 4: Confirm the file still parses**

```bash
python3 -c "import xml.etree.ElementTree as E; E.parse('/home/jbrestel/workspaces/plasmodb/ApiCommonModel/Model/lib/xml/tuningManager/apiTuningManager.xml'); print('OK')"
```

Expected: `OK`.

- [ ] **Step 5: Re-run the Step 1 observation**

Expected: `2`.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/xml/tuningManager/apiTuningManager.xml
git commit -m "Add transitional apidbtuning CNV tables

webready.GeneCopyNumbers_p and ChrCopyNumbers_p are empty because they
inner-join PANIO_p, which is empty because study.Input has no rows. The
webready definitions are corrected in the same change but only take
effect at the next workflow run, so these tuningManager copies carry the
searches until then.

Scheduled for deletion one release later; see the port design doc s7."
```

## Task 7: Correct the four `webready` psql files

**Files:**
- Modify: `ApiCommonModel/Model/lib/psql/webready/orgSpecific/GeneCopyNumbers_p.psql`
- Modify: `ApiCommonModel/Model/lib/psql/webready/orgSpecific/ChrCopyNumbers_p.psql`
- Modify: `ApiCommonModel/Model/lib/psql/webready/orgSpecific/GeneCopyNumbers_p_ix.psql`
- Modify: `ApiCommonModel/Model/lib/psql/webready/orgSpecific/ChrCopyNumbers_p_ix.psql`

These keep their `org_abbrev` partitioning (`:DECLARE_PARTITION`) — unlike the transitional
tables, this is their permanent home.

- [ ] **Step 1: Establish the failing observation**

```bash
grep -n "PANIO_p\|input_pan_id\|output_pan_id" \
  /home/jbrestel/workspaces/plasmodb/ApiCommonModel/Model/lib/psql/webready/orgSpecific/{Gene,Chr}CopyNumbers_p*.psql
```

Expected: several hits across all four files. Those are the dead references.

- [ ] **Step 2: Replace `GeneCopyNumbers_p.psql` entirely**

```sql
:CREATE_AND_POPULATE
            -- Mirrors the GeneCopyNumbers tuningTable in apiTuningManager.xml, which
            -- carries the searches until this file's next workflow run. Any edit here
            -- MUST be mirrored there. See the port design doc, section 7.
            --
            -- The PANIO_p join was removed: study.Input has no rows, so PANIO_p is empty
            -- and this table came out empty. Organism identity now comes from
            -- TranscriptAttributes_p and sample identity from the protocolappnode name.
            SELECT DISTINCT ':PROJECT_ID' as project_id
            , ':ORG_ABBREV' as org_abbrev
            , ta.organism
            , ta.taxon_id
            , current_timestamp as modification_date
            , ta.source_id
            , ta.gene_source_id
            , regexp_replace(pan.name, '_GeneCNV$', '') AS eda_sample_stable_id
            , gcn.haploid_number AS raw_estimate
            , gcn.ref_copy_number AS ref_cn
            , CASE WHEN (gcn.haploid_number < 0.01) THEN 0
                WHEN (0.01 < gcn.haploid_number AND gcn.haploid_number < 1.85) THEN 1
                ELSE round(gcn.haploid_number) END AS haploid_number
            , ta.chromosome
            , ta.na_sequence_id
            FROM apidb.genecopynumber gcn
            , study.protocolappnode pan
            , :SCHEMA.TranscriptAttributes_p ta
            WHERE gcn.protocol_app_node_id = pan.protocol_app_node_id
            AND gcn.na_feature_id = ta.gene_na_feature_id
            AND (ta.gene_type = 'protein coding' or ta.gene_type = 'protein coding gene')
            AND ta.org_abbrev = ':ORG_ABBREV';


:DECLARE_PARTITION;
```

- [ ] **Step 3: Replace `ChrCopyNumbers_p.psql` entirely**

```sql
:CREATE_AND_POPULATE
          -- Mirrors the ChrCopyNumbers tuningTable in apiTuningManager.xml; any edit here
          -- MUST be mirrored there. See the port design doc, section 7.
          --
          -- Two changes: the dead PANIO_p join is gone, and the source is
          -- GenomicSeqAttributes_p rather than TranscriptAttributes_p. Chromosome ploidy
          -- is sequence-level, and SequencesByPloidy already reads the sequence table.
          SELECT DISTINCT
              sa.project_id
            , sa.org_abbrev
            , sa.organism
            , sa.taxon_id
            , current_timestamp as modification_date
            , sa.source_id
            , sa.na_sequence_id
            , sa.chromosome
            , ccn.chr_copy_number AS ploidy
            , regexp_replace(pan.name, '_Ploidy$', '') AS eda_sample_stable_id
          FROM apidb.ChrCopyNumber ccn
            , study.protocolappnode pan
            , :SCHEMA.GenomicSeqAttributes_p sa
          WHERE ccn.protocol_app_node_id = pan.protocol_app_node_id
            AND sa.na_sequence_id = ccn.na_sequence_id
            AND sa.chromosome IS NOT NULL
            AND sa.org_abbrev = ':ORG_ABBREV';


:DECLARE_PARTITION;
```

- [ ] **Step 4: Replace both index files**

`GeneCopyNumbers_p_ix.psql` — the old index named `input_pan_id`, which no longer exists:

```sql
            CREATE INDEX GeneCN_ix
            ON :SCHEMA.GeneCopyNumbers_p (org_abbrev, eda_sample_stable_id, na_sequence_id)
    ;
```

`ChrCopyNumbers_p_ix.psql` — this file currently declares **two** indexes:

```sql
          CREATE index ChrCN_ix 
          ON :SCHEMA.ChrCopyNumbers_p (org_abbrev, input_pan_id, na_sequence_id)
    ;


          CREATE index ChrCN_output 
          ON :SCHEMA.ChrCopyNumbers_p (org_abbrev, output_pan_id)
    ;
```

Both pan columns collapse to `eda_sample_stable_id`, which would make `ChrCN_output` a
redundant prefix of `ChrCN_ix`. Drop it and keep one:

```sql
          -- Was two indexes, on (org_abbrev, input_pan_id, na_sequence_id) and
          -- (org_abbrev, output_pan_id). Both pan columns are now eda_sample_stable_id,
          -- which would make the second a redundant prefix of the first.
          CREATE index ChrCN_ix
          ON :SCHEMA.ChrCopyNumbers_p (org_abbrev, eda_sample_stable_id, na_sequence_id)
    ;
```

- [ ] **Step 5: Confirm the failing observation is resolved**

```bash
grep -n "PANIO_p\|input_pan_id\|output_pan_id" \
  /home/jbrestel/workspaces/plasmodb/ApiCommonModel/Model/lib/psql/webready/orgSpecific/{Gene,Chr}CopyNumbers_p*.psql
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/psql/webready/orgSpecific/GeneCopyNumbers_p.psql \
        Model/lib/psql/webready/orgSpecific/ChrCopyNumbers_p.psql \
        Model/lib/psql/webready/orgSpecific/GeneCopyNumbers_p_ix.psql \
        Model/lib/psql/webready/orgSpecific/ChrCopyNumbers_p_ix.psql
git commit -m "Correct the webready CNV tables for the next workflow run

Drops the PANIO_p join that made both tables empty, keys samples on an
EDA sample stable id derived from the protocolappnode name, and sources
chromosome ploidy from GenomicSeqAttributes_p rather than reaching
through TranscriptAttributes_p.

Also retires the strain column, whose regex required a space these names
never contain and so never stripped anything."
```

---

# ⛔ HALT — Jenkins tuning build

**Stop here and hand back to John.**

Nothing in Phase 3 can be built or verified until `apidbtuning.GeneCopyNumbers` and
`apidbtuning.ChrCopyNumbers` exist. The model XML in Phase 3 names those tables, and WDK
tests `sqlQuery` definitions during the model build, so `wb model` will **fail** — not
silently degrade — if they are absent.

Report to John: Phases 1 and 2 complete, Task 6's tuningManager entries ready to build,
and the parity numbers from Tasks 4 and 5. Wait for confirmation that the Jenkins build has
run before starting Task 8.

Confirm the tables exist before proceeding:

```bash
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "select count(*) from apidbtuning.GeneCopyNumbers"
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "select count(*) from apidbtuning.ChrCopyNumbers"
```

Expected: non-zero, and matching the counts recorded in Tasks 4 and 5.

---

# PHASE 3 — The three CNV searches

## Task 8: Add the CNV params

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/organismParams.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/variationParams.xml`

Two organism vocabularies, not one: the gene searches join both CNV tables and so need an
organism present in both, while `SequencesByPloidy` needs only chromosome data. A single
shared vocabulary would either hide an organism from the ploidy search or offer the gene
searches one that returns nothing. (This refines the design doc's §4.1, which named a single
`organismVQ.CNVDnaSeq`.)

- [ ] **Step 1: Establish the failing observation — the old vocab returns nothing**

```bash
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc "
SELECT DISTINCT tn.NAME FROM APIDB.DATASOURCE d, SRES.TAXONNAME tn
WHERE lower(d.NAME) like '%copynumbervariations_%' AND tn.TAXON_ID = d.TAXON_ID
  AND tn.NAME_CLASS = 'scientific name'"
```

Expected: no rows. That is `organismVQ.CNV`'s core predicate, and why the organism dropdown
on all three searches is empty today.

- [ ] **Step 2: Add both vocabularies to `organismParams.xml`**

Inside the `organismVQ` `querySet`, next to the existing `<!-- CNV -->` block:

```xml
    <!-- Organisms with GENE copy-number data. Used by GenesByCopyNumber and
         GenesByCopyNumberComparison, which join both CNV tables, so an organism must
         appear in the gene table to be useful to them.

         internal is the SCIENTIFIC NAME, matching organismSinglePick's convention. The
         retired organismVQ.CNV returned string_agg(o.abbrev) - a comma-joined list of
         abbreviations - which is a second reason nothing downstream lined up. -->
    <sqlQuery name="CNVGene" doNotTest="1"
              includeProjects="AmoebaDB,CryptoDB,PlasmoDB,ToxoDB,TriTrypDB,FungiDB,UniDB">
      <column name="internal"/>
      <column name="term"/>
      <sql>
        <![CDATA[
          SELECT DISTINCT organism AS term, organism AS internal
          FROM apidbtuning.GeneCopyNumbers
          ORDER BY term
        ]]>
      </sql>
    </sqlQuery>

    <!-- Organisms with CHROMOSOME ploidy data. Used by SequencesByPloidy, which reads only
         the chromosome table. Kept separate from CNVGene deliberately: the two sets are
         identical today, but an organism whose pipeline produced ploidy without gene CNV
         would otherwise vanish from this search. -->
    <sqlQuery name="CNVChr" doNotTest="1"
              includeProjects="AmoebaDB,TriTrypDB,PlasmoDB,ToxoDB,CryptoDB,FungiDB,UniDB">
      <column name="internal"/>
      <column name="term"/>
      <sql>
        <![CDATA[
          SELECT DISTINCT organism AS term, organism AS internal
          FROM apidbtuning.ChrCopyNumbers
          ORDER BY term
        ]]>
      </sql>
    </sqlQuery>
```

- [ ] **Step 3: Add `cnv_sample_meta` to `variationParams.xml`**

Place it after `variation_sample_meta` (currently at line 65), inside the `variationParams`
paramSet:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Samples for the copy-number searches -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Reuses the same three EDA queries as variation_sample_meta. WDK clones a dependent
         param's queries per param, so sharing the definitions costs nothing - the same
         arrangement variation_sample_meta_a and _b already use.

         Deliberately NO minSelectedCount, unlike variation_sample_meta which requires 2.
         Polymorphism within a group of one is undefined, which is why that search needs a
         minimum; a copy-number query on a single sample is perfectly meaningful.

         Unlike variation_sample_meta, this name is NOT a plugin contract - the CNV searches
         are plain sqlQueries with no plugin behind them. It is a separate param anyway,
         because the minSelectedCount differs and because a param named for variation should
         not be what a genomic-sequence ploidy search depends on.

         This lives in variationParams.xml rather than a neutral file by decision, not
         oversight: see the port design doc, section 9.1. -->
    <filterParam name="cnv_sample_meta"
                 metadataQueryRef="VariationVQ.SamplesMetadataByStudy"
                 backgroundQueryRef="VariationVQ.SamplesMetadataByStudy"
                 ontologyQueryRef="VariationVQ.SampleOntologyByStudy"
                 prompt="Strain/Sample"
                 dependedParamRef="organismParams.organismSinglePick,variationParams.eda_sample_table_suffix">
      <help>
        Choose the resequenced strains or samples to examine. Use the sample characteristics
        to narrow the group, or accept all samples for the organism you chose.
      </help>
    </filterParam>
```

- [ ] **Step 4: Build**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: succeeds. New params with no referencing query are legal.

- [ ] **Step 5: Confirm the new vocabularies return rows**

```bash
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "SELECT DISTINCT organism FROM apidbtuning.GeneCopyNumbers ORDER BY 1"
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a -Atc \
  "SELECT DISTINCT organism FROM apidbtuning.ChrCopyNumbers ORDER BY 1"
```

Expected: three organisms each — `Aspergillus fumigatus Af293`,
`Plasmodium falciparum 3D7`, `Trypanosoma brucei brucei TREU927`. Contrast with Step 1's
empty result.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/organismParams.xml \
        Model/lib/wdk/model/questions/params/variationParams.xml
git commit -m "Add CNV organism vocabularies and the cnv_sample_meta filter

organismVQ.CNV returns zero rows - no datasource matches
%copynumbervariations_%, because CNV now rides the merged isolates/
Dna_Seq datasources. Its replacements key on the corrected tuning tables
and return the scientific name, matching organismSinglePick.

Two vocabularies rather than one: the gene searches join both CNV tables
and the ploidy search only the chromosome one, so a shared vocabulary
would either hide or over-offer an organism."
```

## Task 9: Port `GeneId.GenesByCopyNumber`

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/geneQueries.xml:5468-5566`

- [ ] **Step 1: Establish the failing observation — the search returns nothing**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/project_home/../etc/setenv && \
  wdkQuery -model PlasmoDB -query GeneId.GenesByCopyNumber -showParams"'
```

Record the rendered SQL. It names `webready.GeneCopyNumbers_p` and `ChrCopyNumbers_p`.
Confirm both are empty (Task 4 Step 1) — so this search *builds and returns zero rows*,
which is the failure mode to fix.

- [ ] **Step 2: Repoint the six param refs**

Replace:

```xml
      <paramRef ref="organismParams.organismSinglePickCnv"/> <!-- queryRef="organismVQ.CNV"/ -->
      <paramRef ref="sharedParams.CNV_strain"/>
```

with:

```xml
      <!-- organismSinglePick with a vocabulary override, NOT a new param:
           variationParams.eda_sample_table_suffix and cnv_sample_meta both declare
           dependedParamRef on organismSinglePick and interpolate $$organismSinglePick$$.
           A different organism param would leave that chain dangling, and the samples
           filter would silently stop being scoped by organism. -->
      <paramRef ref="organismParams.organismSinglePick" queryRef="organismVQ.CNVGene"
                quote="true" noTranslation="true"/>
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <paramRef ref="variationParams.cnv_sample_meta"/>
```

The explicit `eda_sample_table_suffix` ref is required and is **not** redundant even though
this query's SQL never interpolates it: WDK validates that every param a query uses is
declared, and `cnv_sample_meta`'s metadata/ontology queries need it. All four working
variation queries declare it the same way (`variationQueries.xml:56, 93, 133, 176`).

Leave the four remaining `paramRef`s (`medianOrIndividual`, `CNV_type`, `operator`,
`copyNumber`) exactly as they are.

- [ ] **Step 3: Rewrite the `bySample` CTE**

Replace:

```sql
          WITH bySample AS (
            SELECT DISTINCT g.project_id
              , g.source_id
              , g.gene_source_id
              , g.strain
              , g.raw_estimate
              , g.ref_cn
              , g.haploid_number
              , c.ploidy
              , g.chromosome
            FROM webready.GeneCopyNumbers_p g
             , webready.ChrCopyNumbers_p c
            WHERE c.output_pan_id IN ($$CNV_strain$$)
              AND g.input_pan_id = c.input_pan_id
              AND g.na_sequence_id = c.na_sequence_id
              AND g.org_abbrev = $$organismSinglePickCnv$$ 
              AND c.org_abbrev = $$organismSinglePickCnv$$ 
          )
```

with:

```sql
          WITH bySample AS (
            SELECT DISTINCT g.project_id
              , g.source_id
              , g.gene_source_id
              , g.eda_sample_stable_id AS strain
              , g.raw_estimate
              , g.ref_cn
              , g.haploid_number
              , c.ploidy
              , g.chromosome
            FROM apidbtuning.GeneCopyNumbers g
             , apidbtuning.ChrCopyNumbers c
            WHERE c.eda_sample_stable_id IN ($$cnv_sample_meta$$)
              AND g.eda_sample_stable_id = c.eda_sample_stable_id
              AND g.na_sequence_id = c.na_sequence_id
              AND g.organism = $$organismSinglePick$$
              AND c.organism = $$organismSinglePick$$
          )
```

`g.eda_sample_stable_id = c.eda_sample_stable_id AND g.na_sequence_id = c.na_sequence_id`
together reproduce exactly what `g.input_pan_id = c.input_pan_id` meant: *the same sample's
ploidy for the chromosome this gene sits on*. Aliasing to `strain` keeps the rest of the
query — including `string_agg(s.strain, …)` — unchanged.

- [ ] **Step 4: Build**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: succeeds. `relation "apidbtuning.genecopynumbers" does not exist` means the
Jenkins build at the HALT gate did not actually run.

- [ ] **Step 5: Confirm the failing observation is resolved**

Re-run Step 1's `-showParams`; the query must now resolve and list `cnv_sample_meta` as a
`FilterParamNew`. Then take the SQL **from the model XML you just edited** (valid here — no
template injection; see the note at the top of this plan), confirm it names `apidbtuning.*`,
substitute a real organism and sample list, and run it read-only:

```bash
psql -h localhost -p 5432 -U jbrestel -d unidb_shu_a
```

Substitute `$$organismSinglePick$$` → `'Plasmodium falciparum 3D7'`, `$$cnv_sample_meta$$`
→ a 10-element list from
`SELECT DISTINCT eda_sample_stable_id FROM apidbtuning.GeneCopyNumbers WHERE organism = 'Plasmodium falciparum 3D7' LIMIT 10`,
`$$CNV_type$$` → `'haploid_number'`, `$$operator$$` → `>=`, `$$copyNumber$$` → `2`,
`$$medianOrIndividual$$` → `'sample'`.

Expected: a non-empty result with populated `strains`, `ref_cn`, and the eight median
columns — the first time this search has returned rows.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/geneQueries.xml
git commit -m "Port GenesByCopyNumber onto the corrected CNV tables

Replaces the input_pan_id/output_pan_id joins, which had no data behind
them, with the EDA sample stable id, and scopes on organism rather than
the retired organismSinglePickCnv.

The organism vocabulary is a queryRef override on organismSinglePick
rather than a new param, so eda_sample_table_suffix and cnv_sample_meta
stay attached to the organism they are scoped by."
```

## Task 10: Port `GeneId.GenesByCopyNumberComparison`

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/geneQueries.xml` — the
  `GenesByCopyNumberComparison` sqlQuery (was line 5566; shifted by Task 9)

The edits mirror Task 9. They are repeated in full rather than cross-referenced, because
this query has a different param list and you may be reading tasks out of order.

- [ ] **Step 1: Establish the failing observation**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/project_home/../etc/setenv && \
  wdkQuery -model PlasmoDB -query GeneId.GenesByCopyNumberComparison -showParams"'
```

Record the rendered SQL; it names the two empty `webready` tables.

- [ ] **Step 2: Repoint the param refs**

Replace:

```xml
      <paramRef ref="organismParams.organismSinglePickCnv"/> <!-- queryRef="organismVQ.CNV"/ -->
      <paramRef ref="sharedParams.CNV_strain"/>
```

with:

```xml
      <!-- See GenesByCopyNumber: a vocabulary override, not a new organism param, so the
           eda_sample_table_suffix / cnv_sample_meta dependency chain stays intact. -->
      <paramRef ref="organismParams.organismSinglePick" queryRef="organismVQ.CNVGene"
                quote="true" noTranslation="true"/>
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <paramRef ref="variationParams.cnv_sample_meta"/>
```

Leave `geneParams.medianOrIndividual` and `geneParams.comparisonOperator` untouched. Note
this query has **no** `CNV_type`, `operator`, or `copyNumber` param — it compares against
`ref_cn` instead.

- [ ] **Step 3: Rewrite the `bySample` CTE**

Replace:

```sql
          WITH bySample AS (
            SELECT DISTINCT g.project_id
              , g.source_id
              , g.gene_source_id
              , g.strain
              , g.raw_estimate
              , g.ref_cn
              , g.haploid_number
              , c.ploidy
              , g.chromosome
            FROM webready.GeneCopyNumbers_p g
              , webready.ChrCopyNumbers_p c
            WHERE c.output_pan_id IN ($$CNV_strain$$)
              AND g.input_pan_id = c.input_pan_id
              AND g.na_sequence_id = c.na_sequence_id
              AND g.org_abbrev = $$organismSinglePickCnv$$ 
              AND c.org_abbrev = $$organismSinglePickCnv$$ 
          )
```

with:

```sql
          WITH bySample AS (
            SELECT DISTINCT g.project_id
              , g.source_id
              , g.gene_source_id
              , g.eda_sample_stable_id AS strain
              , g.raw_estimate
              , g.ref_cn
              , g.haploid_number
              , c.ploidy
              , g.chromosome
            FROM apidbtuning.GeneCopyNumbers g
              , apidbtuning.ChrCopyNumbers c
            WHERE c.eda_sample_stable_id IN ($$cnv_sample_meta$$)
              AND g.eda_sample_stable_id = c.eda_sample_stable_id
              AND g.na_sequence_id = c.na_sequence_id
              AND g.organism = $$organismSinglePick$$
              AND c.organism = $$organismSinglePick$$
          )
```

Leave the `medians`, `hit_medians`, and final `SELECT` untouched — including
`AND s.haploid_number $$comparisonOperator$$ s.ref_cn`, which is this query's whole point.

- [ ] **Step 4: Build**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: succeeds.

- [ ] **Step 5: Confirm resolution**

Re-run Step 1's `-showParams`; confirm the query resolves. Then take the SQL from the model
XML you just edited, confirm it names `apidbtuning.*`, and run it in psql with `$$organismSinglePick$$` → `'Plasmodium falciparum 3D7'`, `$$cnv_sample_meta$$` → the
same 10-sample list as Task 9, `$$comparisonOperator$$` → `>`, `$$medianOrIndividual$$` →
`'sample'`.

Expected: a non-empty result — genes amplified relative to the reference.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/geneQueries.xml
git commit -m "Port GenesByCopyNumberComparison onto the corrected CNV tables"
```

## Task 11: Restore the gene CNV questions' summary columns

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/geneQuestions.xml` — the
  `GenesByCopyNumber` (was :4254) and `GenesByCopyNumberComparison` (was :4360) questions

Both have their `attributesList` commented out, so ten CNV columns are declared in
`dynamicAttributes` and never shown — the searches return bare gene rows.

- [ ] **Step 1: Establish the failing observation**

```bash
grep -n -A4 '<question name="GenesByCopyNumber"' \
  /home/jbrestel/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/geneQuestions.xml
```

Expected: an `<!--` immediately preceding `<attributesList`, confirming it is inert.

- [ ] **Step 2: Replace the commented block in `GenesByCopyNumber`**

Replace:

```xml
<!--
        <attributesList
            summary="strains, ref_cn, median_raw_hits, median_haploid_hits, median_ploidy_hits, median_gene_dose_hits, gene_product, chromosome, orthomcl_link"
        /> 
-->
```

with:

```xml
        <!-- CNV columns only. The commented original also named gene_product, chromosome
             and orthomcl_link; all three were verified to exist on TranscriptRecordClass
             (transcriptRecord.xml:339, :327, :869), so leaving them out is a choice to
             keep the summary to what the search is about, not a workaround for missing
             attributes.

             The _all variants stay declared in dynamicAttributes but out of the default
             summary, as in the original.

             sorting is NEW - the original carried none, and an unsorted copy-number
             result is not useful. Highest amplification first is the usual ask. -->
        <attributesList
            summary="strains,ref_cn,median_raw_hits,median_haploid_hits,median_ploidy_hits,median_gene_dose_hits"
            sorting="median_haploid_hits desc"/>
```

- [ ] **Step 3: Replace the identical commented block in `GenesByCopyNumberComparison`**

Same replacement, with a shorter comment:

```xml
        <!-- CNV columns only; see GenesByCopyNumber above for why gene_product,
             chromosome and orthomcl_link are deliberately omitted. -->
        <attributesList
            summary="strains,ref_cn,median_raw_hits,median_haploid_hits,median_ploidy_hits,median_gene_dose_hits"
            sorting="median_haploid_hits desc"/>
```

- [ ] **Step 4: Build**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: succeeds. `Summary attribute field [...] is invalid` means a named column is not
declared in `dynamicAttributes` — check spelling against the ten `columnAttribute` names.

- [ ] **Step 5: Confirm the columns are registered**

From the app tab:

```javascript
if (!window.location.origin.includes('jbrestel')) throw new Error('WRONG ORIGIN: ' + window.location.origin);
const BASE = window.location.pathname.replace(/\/app.*$/, '');   // -> "/plasmo.jbrestel"
if (!BASE) throw new Error('NO CONTEXT PATH: ' + window.location.pathname);
const j = await (await fetch(BASE + '/service/record-types/transcript/searches/GenesByCopyNumber')).json();
JSON.stringify(j.defaultAttributes)
```

Expected: the six summary columns, `median_haploid_hits` among them.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/geneQuestions.xml
git commit -m "Restore the CNV summary columns on both gene CNV searches

Both attributesList blocks were commented out, so ten declared CNV
columns never reached the results table and the searches returned bare
gene rows. Restored with the CNV columns only."
```

## Task 12: Port `SequencesByPloidy`

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/genomicQueries.xml:310`
  (`SequenceIds.ByCopyNumber`)

The question itself (`genomicQuestions.xml:252`) needs **no** change — its `attributesList`,
`dynamicAttributes`, `summary`, and `description` all stand.

- [ ] **Step 1: Establish the failing observation**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/project_home/../etc/setenv && \
  wdkQuery -model PlasmoDB -query SequenceIds.ByCopyNumber -showParams"'
```

Record the SQL. Note it reads base tables directly and has **no organism predicate** — it
relied on `CNV_strain`'s organism-scoped vocabulary for that.

- [ ] **Step 2: Repoint the param refs**

Replace:

```xml
      <paramRef ref="organismParams.organismSinglePickCnv"/> <!-- queryRef="organismVQ.CNV"/ -->
      <paramRef ref="sharedParams.CNV_strain"/>
```

with:

```xml
      <!-- CNVChr, not CNVGene: this search reads only chromosome ploidy. -->
      <paramRef ref="organismParams.organismSinglePick" queryRef="organismVQ.CNVChr"
                quote="true" noTranslation="true"/>
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <paramRef ref="variationParams.cnv_sample_meta"/>
```

Leave `genomicParams.chrCopyNumber` and `genomicParams.medianOrIndividual` untouched.

- [ ] **Step 3: Rewrite the SQL onto the corrected chromosome table**

Replace the whole `<sql>` body with:

```sql
          WITH bySample AS (
            SELECT c.source_id
              , c.project_id
              , c.ploidy AS chr_copy_number
              , c.eda_sample_stable_id
            FROM apidbtuning.ChrCopyNumbers c
            WHERE c.eda_sample_stable_id IN ($$cnv_sample_meta$$)
              AND c.organism = $$organismSinglePick$$
          )
          , median AS (
            SELECT DISTINCT s.source_id
              , percentile_cont(0.5) WITHIN GROUP (ORDER BY s.chr_copy_number) AS median
            FROM bySample s
            GROUP BY s.source_id
          )
          SELECT DISTINCT s.source_id
            , s.project_id
            , percentile_cont(0.5) WITHIN GROUP (ORDER BY s.chr_copy_number) AS median_hits
            , string_agg(s.eda_sample_stable_id, ', ' ORDER BY s.eda_sample_stable_id) AS strains
            , m.median AS median_all
          FROM bySample s
            , median m
          WHERE m.source_id = s.source_id
            AND s.chr_copy_number >= $$chrCopyNumber$$
            AND CASE WHEN $$medianOrIndividual$$ = 'median' AND m.median >= $$chrCopyNumber$$ THEN 1
                     WHEN $$medianOrIndividual$$ = 'sample' THEN 1
                     ELSE 0
                     END = 1
          GROUP BY s.source_id, s.project_id, m.median
```

Three things changed and each is deliberate:
1. the three-table base join collapses to the one corrected tuning table (which already
   applies `chromosome IS NOT NULL`);
2. `string_agg(REGEXP_REPLACE(s.name, '_[A-Za-z0-9]+ (.+)$', ''), …)` becomes a plain
   `string_agg` of `eda_sample_stable_id` — the regex required a **space** these names never
   contain, so it stripped nothing and `strains` showed `427_Ploidy`;
3. **an organism predicate is added.** This is a behaviour fix, not a regression: organism
   was previously constrained only implicitly through `CNV_strain`'s vocabulary, and with
   the sample list now coming from an EDA study, a sample name colliding across organisms
   would leak rows.

- [ ] **Step 4: Build**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: succeeds.

- [ ] **Step 5: Confirm resolution**

Re-run Step 1's `-showParams`, then run the SQL from the model XML you just edited in psql
with
`$$organismSinglePick$$` → `'Plasmodium falciparum 3D7'`, `$$cnv_sample_meta$$` → 10 samples
from `apidbtuning.ChrCopyNumbers`, `$$chrCopyNumber$$` → `2`, `$$medianOrIndividual$$` →
`'sample'`.

Expected: non-empty, with `strains` showing bare sample names (`427`), **not** `427_Ploidy`.
That string is the proof the regex bug is fixed.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/genomicQueries.xml
git commit -m "Port SequencesByPloidy onto the corrected chromosome CNV table

Also adds an explicit organism predicate. The query previously had none,
relying on CNV_strain's organism-scoped vocabulary; with samples now
coming from an EDA study, a name colliding across organisms would leak
rows."
```

## Task 13: Categorize the three CNV searches

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt` lines 100, 101, 138

- [ ] **Step 1: Establish the failing observation**

```bash
sed -n '100p;101p;138p' \
  /home/jbrestel/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/ontology/individuals.txt
```

Expected: all three begin with `##`, and line 138 carries `topic_0219` /
`Curation and Annotation`.

- [ ] **Step 2: Uncomment lines 100 and 101**

Remove the leading `##` from each. Change nothing else — both already carry
`topic_0199` / `Genetic Variation`.

- [ ] **Step 3: Uncomment line 138 and move it to Genetic Variation**

Remove the leading `##`, and change `http://edamontology.org/topic_0219` →
`http://edamontology.org/topic_0199` and `Curation and Annotation` → `Genetic Variation`.
This is a tab-separated file — preserve the tab structure exactly; do not let an editor
convert tabs to spaces.

- [ ] **Step 4: Rebuild the ontology**

```bash
bin/veup-logs.sh plasmodb mark cnvcat
bin/veup-build.sh plasmodb wb ontology
```

`wb ontology`, not `wb model` — the category tree comes from the OWL, and `wb model` alone
leaves it stale.

- [ ] **Step 5: Confirm all three are placed**

From the app tab:

```javascript
if (!window.location.origin.includes('jbrestel')) throw new Error('WRONG ORIGIN: ' + window.location.origin);
const BASE = window.location.pathname.replace(/\/app.*$/, '');   // -> "/plasmo.jbrestel"
if (!BASE) throw new Error('NO CONTEXT PATH: ' + window.location.pathname);
const j = await (await fetch(BASE + '/service/ontologies/Categories')).json();
const want = /GenesByCopyNumber|GenesByCopyNumberComparison|SequencesByPloidy|GenesByNgsSnps/;
const hits = [];
(function walk(n, parent) {
  const p = n.properties || {};
  (p.name || []).forEach(x => { if (want.test(x)) hits.push([x, parent]); });
  const term = (p['EuPathDB alternative term'] || p.label || [])[0];
  (n.children || []).forEach(c => walk(c, term));
})(j.tree, null);
JSON.stringify(hits, null, 1)
```

Expected: all four searches, each with parent `Genetic Variation`.

Then confirm registration, which the tree does **not** prove — `/service/ontologies/Categories`
is not project-filtered, so a node can appear for a site whose model excludes the question:

```javascript
if (!window.location.origin.includes('jbrestel')) throw new Error('WRONG ORIGIN: ' + window.location.origin);
const BASE = window.location.pathname.replace(/\/app.*$/, '');   // -> "/plasmo.jbrestel"
if (!BASE) throw new Error('NO CONTEXT PATH: ' + window.location.pathname);
const t = await (await fetch(BASE + '/service/record-types/transcript')).json();
const g = await (await fetch(BASE + '/service/record-types/genomic-sequence')).json();
JSON.stringify({
  transcript: t.searches.map(s=>s.urlSegment).filter(n=>/CopyNumber|NgsSnps/.test(n)),
  genomicSequence: g.searches.map(s=>s.urlSegment).filter(n=>/Ploidy/.test(n))
})
```

Expected: `GenesByCopyNumber`, `GenesByCopyNumberComparison`, `GenesByNgsSnps` under
transcript; `SequencesByPloidy` under genomic-sequence.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "Categorize the three CNV searches under Genetic Variation

SequencesByPloidy moves from Curation and Annotation, so all eight
dnaseq searches sit in one menu section."
```

## Task 14: Retire the dead CNV params

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/organismParams.xml:230`
  (`organismSinglePickCnv`) and `:522` (`organismVQ.CNV`)
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/sharedParams.xml:1530`
  (`CNV_strain`), `:2913` (`CnvSamplesMetadataByOrganism`), `:2936` (`CnvMetadataSpecByOrganism`)

Only safe now that Tasks 9, 10, and 12 have removed the last references.

- [ ] **Step 1: Establish the failing observation — prove there are no consumers left**

Ask the **assembled** model, not the source. A `grep` of the source matches inside comment
blocks just as happily as outside them, which is how the snp import was previously misread.

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/project_home/../etc/setenv && \
  wdkXml -model PlasmoDB"' > /tmp/claude-1000/-home-jbrestel-workspaces-agentic-veupath-dev/0c03b31d-4bcd-456b-b2ac-4cbb0a3afb4f/scratchpad/assembled.xml
grep -c "organismSinglePickCnv\|CNV_strain\|CnvSamplesMetadataByOrganism\|CnvMetadataSpecByOrganism" \
  /tmp/claude-1000/-home-jbrestel-workspaces-agentic-veupath-dev/0c03b31d-4bcd-456b-b2ac-4cbb0a3afb4f/scratchpad/assembled.xml
```

Expected: **4, not 0** — and that is correct, not a problem.

`wdkXml -model` dumps a full *registry* of every declared param and query, so the items being
deleted necessarily appear in their own inventory entries. A grep-for-zero gate here **cannot
pass by construction**. (This was a defect in an earlier draft of this plan. An agent hit it,
correctly refused to reinterpret the premise on its own authority, and stopped — the right
call, and why the gate is now written properly.)

**The real gate:** every reference must come from *within the deletion set itself*. Verified
on this instance:

| line | reference |
|---|---|
| 400 | `organismSinglePickCnv`'s own declaration |
| 1405 | `CNV_strain`'s own declaration |
| 8961 | `organismVQ.CNV`'s own declaration |
| 9121, 9124 | the two doomed `SharedVQ` queries, each naming the doomed param |

**Stop only if a *Question* references one of them.** Check that specifically:

```bash
grep -nE "GenesByCopyNumber|GenesByCopyNumberComparison|ByCopyNumber" \
  <scratchpad>/assembled.xml | grep -E "organismSinglePickCnv|CNV_strain"
```

Expected: no output — by this point `GeneId.GenesByCopyNumber` lists `organismSinglePick`
and `cnv_sample_meta` instead.

The grep-for-zero check *is* meaningful **after** deletion; that is Step 5's job.

- [ ] **Step 2: Delete from `organismParams.xml`**

Delete the whole `<flatVocabParam name="organismSinglePickCnv" …>…</flatVocabParam>` element
(with its `suggest`, `propertyList`, and `help` children) and the whole
`<sqlQuery name="CNV" …>…</sqlQuery>` plus its `<!-- CNV -->` header comment.

- [ ] **Step 3: Delete from `sharedParams.xml`**

Delete the whole `<filterParam name="CNV_strain" …>…</filterParam>` with its preceding
`<!--+++ Strain selection for genes by CNV and genomic segment by ploidy +++-->` comment
block, and both `<sqlQuery name="CnvSamplesMetadataByOrganism" …>` and
`<sqlQuery name="CnvMetadataSpecByOrganism" …>` elements in full.

- [ ] **Step 4: Build**

```bash
bin/veup-build.sh plasmodb wb model
```

Expected: succeeds. Any "cannot be found" error names a consumer Step 1 missed — restore
that element and investigate rather than chasing the error.

- [ ] **Step 5: Confirm the retired names are gone from the assembled model**

Re-run Step 1's `wdkXml` + `grep`. Expected: still `0`, and the build succeeded — which
together mean the elements are gone and nothing wanted them.

- [ ] **Step 6: Commit**

```bash
cd /home/jbrestel/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/organismParams.xml \
        Model/lib/wdk/model/questions/params/sharedParams.xml
git commit -m "Retire the dead CNV organism and strain params

organismVQ.CNV returns zero rows; CnvSamplesMetadataByOrganism and
CnvMetadataSpecByOrganism read apidbTuning.Metadata and .Ontology, which
do not exist in this build. Their last consumers were ported off in the
preceding commits."
```

## Task 15: End-to-end live QA

**Files:** none.

- [ ] **Step 1: Mark the logs**

```bash
bin/veup-logs.sh plasmodb mark cnvqa
```

- [ ] **Step 2: Run `SequencesByPloidy` in the app**

Genetic Variation → Copy Number/Ploidy. Organism *Plasmodium falciparum 3D7*, narrow the
sample filter to a handful, Copy Number `2`, By Sample.

Expected: non-zero sequences; `Strains/Samples Meeting Criteria` shows bare names (`427`),
not `427_Ploidy`; `Median Copy No` columns populated.

- [ ] **Step 3: Run `GenesByCopyNumber`**

Genetic Variation → Copy Number (CNV). Same organism, a handful of samples, metric
*haploid number*, operator `>=`, Copy Number `2`.

Expected: non-zero genes, with all six restored summary columns populated and sorted by
`Median Haploid No (Hits)` descending.

- [ ] **Step 4: Run `GenesByCopyNumberComparison`**

Genetic Variation → Copy Number Comparison (CNV). Same organism and samples, comparison
operator *greater than*.

Expected: non-zero genes; `Copies in Reference` populated and the median haploid number
exceeding it, consistent with the operator.

- [ ] **Step 5: Confirm the organism dropdown and sample tree**

On each of the three searches, confirm the Organism dropdown lists the three CNV organisms
(it was empty before this work) and that the Strain/Sample filter renders an EDA
characteristics tree rather than a flat list or an error.

Then check the logs:

```bash
bin/veup-logs.sh plasmodb since cnvqa --quiet
```

Expected: error logs `silent:`.

- [ ] **Step 6: Record the outcome**

No commit. Report to John: all four searches live, with the sample sizes used and any
timing observations against Task 4 Step 5's baseline. Flag anything that returned zero rows
— a zero result here is a failure, not a pass, since every search was chosen to have data.

---

## Deferred

Named so they are visible decisions rather than omissions:

- **The one-release sunset** (design §7): delete the two `<tuningTable>` entries, repoint
  the three queries from `apidbtuning.X` to `webready.X_p`, and reconsider `organism` vs
  `org_abbrev` in the predicate. Not part of this plan — it cannot happen until a workflow
  run populates the corrected webready tables.
- **`GeneQuestions.GenesBySnps`** (`individuals.txt:116`): a second orphaned ontology row
  for a question the model does not define. Belongs to the older non-HTS snp search, has no
  port target, harmless.
- **The chip searches** (`FindChipPolymorphismsPlugin`, `FindChipSnpMajorAllelesPlugin`),
  still pointing at `/highSpeedChipSnpSearch`. Equally dead, deliberately untouched.
- **Select-all timing**: ~4.1 s at 216 samples, extrapolating to ~10 s at production's ~538
  pfal strains. Accepted tail case (design §9.3). If it becomes a complaint, the fix is a
  materialized per-organism median, not a different table layout.
