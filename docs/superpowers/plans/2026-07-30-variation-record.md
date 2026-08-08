# Variation Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new WDK `variation` record — one record per variant locus — with the attributes, tuning table, and record-page tables specified in `docs/superpowers/specs/2026-07-30-variation-record-design.md`.

**Architecture:** A thin `apidbtuning.VariationAttributes` tuning table supplies derived, aggregated, and join-requiring columns; `apidb.VariationFeature` is queried directly for intrinsic per-locus facts (it is already one row per locus with a unique `source_id`). Two record-page tables read `apidb.VariationTranscriptProduct` and `apidb.VariationEffect`. Work proceeds as a vertical slice: a minimal buildable record first (Task 4), then attributes and tables added incrementally, each verified by a real build against a live instance.

**Tech Stack:** WDK model XML, EuPathDB tuning manager XML, PostgreSQL, `wb` build wrapper via `bin/veup-build.sh`, `wdkQuery` for SQL introspection, WDK REST service for verification.

---

## Context you need before starting

> ### Progress
>
> **All tasks (0-14) are complete.** Reconciled against the commit log on
> `dnaseq-merge-experiments` on 2026-08-05; the block below had been stale since Task 4.
>
> | task | commit(s) |
> |---|---|
> | 0-1 preconditions, psql SELECT check | verification only, no commit |
> | 2 tuning table definition | `9ff6094` |
> | 3 build and verify the tuning table | see the note below — superseded by a tuning run |
> | 4 minimal buildable record | `9bcf147` |
> | 5 classification attributes | `48f13bc` |
> | 6 SNP and Indel allele sections | `d35e557`, `51cb41b` (assemble allele strings in SQL) |
> | 7 strain and call statistics | `af9b2aa`, `e0bb106` (rename to "Called Strain Count") |
> | 8 gene linkage, effect rollups, collapsed columns | `d8ccd76`, `e3571e2` (impact sort, MAF help) |
> | 9 record overview and default summary | `f9264c0`, `d636b44` (label allele rows by class) |
> | 10 TranscriptProducts table | `dd4efa6`, `9cc505b` (strain_count help text) |
> | 11 PredictedEffects table | `b19c82d` |
> | 12 category ontology placement | `cf0dd13`, `19b6527` (ontology parenting) |
> | 13 final end-to-end verification | `19b6527` — the four review findings it fixes are that pass's output; there is no separate report doc |
> | 14 flip the stub to the real tuning table | `2723cda` |
>
> Task 4's original detail, kept because the defects it surfaced are still worth knowing:
> the record built green with 13 attributes registered and
> `/plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_29514` rendering with every
> service call 200 and all error logs silent. Three plan defects came out of it — the
> app/service base URLs both include `/plasmo.jbrestel`, an empty `querySet` is invalid so
> `variationTableQueries.xml` moved to Task 10, and the snp imports sit inside a comment
> block that would have swallowed the new imports.
>
> Tuning table as verified at Task 3: **4,390,908 rows**, exactly matching
> `apidb.VariationFeature`, built in 66s with three indexes and `GRANT SELECT TO gus_r`.
> `gene_ids` populated for 2,879,337 loci, `most_severe_impact_snpeff` for 4,390,895,
> `most_severe_impact_product_call` for 1,690,908, `collapsed_allele` for all 4,390,908,
> 3 projects, **25,545 multi-gene loci** — matching the spec's figure exactly. All three
> spot-check loci correct, including `A>C; A>AC` for the MIXED locus.
>
> ### ✓ The developer-schema stub is gone (was: the model reads a stub)
>
> Resolved. This warning described Tasks 4-13 writing `jbrestel.VariationAttributes` into
> the query XML in six places, because `tuningManager` was not installed on the dev
> instance when the plan was written.
>
> Both halves have since been settled, verified 2026-08-05:
>
> - **Model:** Task 14 (`2723cda`) flipped all six references to
>   `ApidbTuning.VariationAttributes`. No `jbrestel` reference remains anywhere in the
>   variation model XML.
> - **Database:** a tuning run (Jenkins) built the real thing on `unidb_shu_a` —
>   `apidbtuning.variationattributes1121` (1688 MB, 4,390,908 rows) plus the
>   `apidbtuning.variationattributes` view over it, `SELECT` granted to `gus_r`. All 17
>   `va.*` columns the model reads resolve against that view. `jbrestel.VariationAttributes`
>   no longer exists.
>
> So the merge blocker is clear, and the flip does **not** cost buildability on the dev
> instance the way this plan originally assumed it would.
>
> The Task 4-11 bodies below still show `jbrestel.VariationAttributes` in their SQL
> snippets, deliberately: that is what was executed at the time, and rewriting them would
> describe a history that never happened. **Do not copy those snippets forward** — the
> committed XML is the current truth. Read them as a record, not as instructions.

**Two repos are involved:**

| repo | path | role |
|---|---|---|
| `ApiCommonModel` | `~/workspaces/plasmodb/ApiCommonModel` | all edits land here; branch `dnaseq-merge-experiments` |
| `agentic-veupath-dev` | `~/workspaces/agentic-veupath-dev` | control plane — run builds from here |

**Concrete instance values** (resolved from `profiles/plasmodb.yml` + `profiles/identity.yml`):

| value | |
|---|---|
| ssh host | `cedar` |
| docroot | `/var/www/jbrestel.plasmodb.org/project_home` |
| setenv | `/var/www/jbrestel.plasmodb.org/etc/setenv` |
| app URL | `https://jbrestel.plasmodb.org/plasmo.jbrestel/app` |
| service base | `/plasmo.jbrestel/service` (alias `/a/service`) — **not** `/service` |
| GUS project | `PlasmoDB` |
| local appDb (psql) | `unidb_shu_a` on `localhost:5432` |

**Commands you will use repeatedly:**

```bash
# Build the WDK model (questions, queries, records). Run from the harness repo.
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model

# Rebuild the category OWL *and* the model. Required for any individuals.txt change.
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb ontology

# Render a WDK query's assembled SQL without executing it (always safe).
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  wdkQuery -model PlasmoDB -query <QuerySet.queryName> -showQuery"'

# Read remote logs by page-load delta.
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark <label>
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since <label>
```

**Gotcha — trailing commas in the `SELECT`-additions snippets.** Tasks 6-8 each append
columns to an existing `SELECT` list. Pasting a snippet verbatim can leave a trailing comma
immediately before `FROM`, which is invalid SQL and fails the build. Always read the
resulting tail of the `SELECT` and confirm exactly one comma between each pair of columns
and none before `FROM`.

> ### ⚠ Ordering constraint: nothing renders on a record page until Task 12
>
> A WDK record page is laid out from the **category ontology**
> (`Model/lib/wdk/ontology/individuals.txt`). Until Task 12 adds the `variation` entries,
> the record page shows only its title — measured: 1,065 characters of body text, no
> sections, zero attributes, even with a green build. (`variation` had 0 ontology entries
> while `gene` had 195.)
>
> Consequence for Tasks 5-11: **verify through the REST service, not the page.** The
> service reflects the assembled model and works immediately; "load the page and confirm the
> value appears" cannot pass before Task 12 no matter how correct the model is.
>
> Task 9's overview is the one exception that cannot be verified either way early — it is
> purely presentational, so a green build proves only that its `$$tokens$$` resolve. Its real
> acceptance test lives in Task 13, after `wb ontology` has run.

**How "tests" work in this codebase.** There is no unit-test harness for model XML. The
equivalents, used test-first throughout this plan, are:

1. **psql** — assert expected values from a query *before* wiring it into the model.
2. **`wb model`** — the build fails loudly on bad XML, unresolvable refs, or a column in
   the record class that the query does not return. A green build is a real assertion.
3. **`wdkQuery -showQuery`** — proves the query WDK assembled is the SQL you intended.
4. **WDK REST service** — `/service/record-types/variation` and
   `/service/ontologies/Categories` confirm registration and ontology placement.

**Reading the service endpoints.** They are auth-gated; a raw `curl` 307-redirects to
EuPathDB autologin. Fetch them from an already-loaded app page using Claude in Chrome's
`javascript_tool`, where the session cookie is present, e.g.:

```js
await (await fetch('/plasmo.jbrestel/service/record-types/variation')).json()
```

**Gotcha — flags before the name.** `bin/veup-*.sh` option flags must precede the profile
name. `veup-build.sh plasmodb --dry-run wb model` silently drops the flag and runs live.
Use `veup-build.sh --dry-run plasmodb wb model`. A real dry run prints `DRYRUN:`-prefixed
lines.

**Gotcha — `wb ontology` is a superset of `wb model`.** Never run both; run `wb ontology`
alone when categorization changed.

**Gotcha — after any local `git pull` or branch switch**, run
`bin/veup-git-sync.sh plasmodb` or the remote reports phantom modifications.

**Dead code, do not extend:** `Model/lib/wdk/apiCommonModel-sanity.xml` imports an
`apiCommonModel-sanity/` directory that **does not exist**. The whole sanity model is
stale. Do not add a variation sanity file; there is nothing live to add it to.

---

## File Structure

| file | action | responsibility |
|---|---|---|
| `Model/lib/xml/tuningManager/apiTuningManager.xml` | modify | add `VariationAttributes` tuning table |
| `Model/lib/wdk/model/records/variationAttributeQueries.xml` | create | `querySet` `VariationAttributes`: alias query, tuning-backed query, `VariationFeature`-backed query |
| `Model/lib/wdk/model/records/variationTableQueries.xml` | create | `querySet` `VariationTables`: the two record-page table queries |
| `Model/lib/wdk/model/records/variationRecords.xml` | create | `recordClassSet` `VariationRecordClasses`: the record class, attributes, tables |
| `Model/lib/wdk/apiCommonModel.xml` | modify | import the three new files |
| `Model/lib/wdk/ontology/individuals.txt` | modify | category placement for attributes and tables |

Three model files mirror the existing `snp*` split (attribute queries / table queries /
record class), which is the established pattern in this directory. The record class file
is the only one that grows large; keeping queries out of it is what keeps it readable.

---

## Task 0: Confirm preconditions

**Files:** none (verification only)

- [x] **Step 1: Confirm the ApiCommonModel branch and clean tree**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && git branch --show-current && git status --porcelain
```

Expected: `dnaseq-merge-experiments`, and no output from `git status` (clean tree). If the
branch differs, stop and ask — do not switch branches, because a switch requires
`bin/veup-git-sync.sh plasmodb` afterwards and may not be what the user wants.

- [x] **Step 2: Confirm the base tables exist and are populated**

```bash
psql -h localhost -p 5432 -d unidb_shu_a \
  -c "select count(*) from apidb.variationfeature" \
  -c "select count(*) from apidb.variationtranscriptproduct" \
  -c "select count(*) from apidb.variationeffect"
```

Expected: `4390908`, `4595009`, `6789700`. Small drift is fine (data may have been
reloaded); if a count is `0`, stop — nothing downstream will work.

- [x] **Step 3: Confirm the instance's appDb is the database you are querying**

```bash
ssh cedar 'grep -A3 -i "appdb" /var/www/jbrestel.plasmodb.org/gus_home/config/model-config.xml | head -20'
```

Expected: a `connectionUrl` naming `unidb_shu_a`. **If it names a different database,
stop and ask the user** — every psql assertion in this plan would be checking a database
the site does not read, and `wb model` would fail on missing tables.

- [x] **Step 4: Confirm the prerequisite tuning tables exist**

```bash
psql -h localhost -p 5432 -d unidb_shu_a \
  -c "select count(*) from apidbtuning.transcriptattributes" \
  -c "select count(*) from apidbtuning.genomicseqattributes"
```

Expected: both non-zero. These are `internalDependency` targets in Task 2.

---

## Task 1: Verify the tuning table SELECT in psql

Prove the SQL produces the specified values *before* embedding it in XML. The three loci
below were chosen to cover all three `variant_type` values.

**Files:**
- Create: `/tmp/claude-1000/-home-jbrestel-workspaces-agentic-veupath-dev/scratch-va-spot.sql` (scratch, not committed)

- [x] **Step 1: Write the scoped spot-check query**

Create the scratch file with this content. The base-table scans are filtered to one
sequence so it returns in seconds rather than minutes; the unfiltered form is what goes
into the tuning table in Task 2.

```sql
WITH gene_agg AS (
  SELECT sequence_source_id, location,
         string_agg(DISTINCT gene_source_id, ', ' ORDER BY gene_source_id) AS gene_ids,
         count(DISTINCT gene_source_id)                                    AS gene_count
  FROM (
    SELECT e.sequence_source_id, e.location, t.gene_source_id
    FROM apidb.VariationEffect e
    JOIN apidbtuning.TranscriptAttributes t ON t.na_feature_id = e.na_feature_id
    WHERE e.sequence_source_id = 'Pf3D7_01_v3' AND e.location IN (12, 18, 29514)
    UNION
    SELECT p.sequence_source_id, p.location, t.gene_source_id
    FROM apidb.VariationTranscriptProduct p
    JOIN apidbtuning.TranscriptAttributes t ON t.na_feature_id = p.na_feature_id
    WHERE p.sequence_source_id = 'Pf3D7_01_v3' AND p.location IN (12, 18, 29514)
  ) g
  GROUP BY sequence_source_id, location
),
effect_agg AS (
  SELECT sequence_source_id, location,
         max(CASE WHEN source = 'snpeff' THEN
               CASE impact WHEN 'HIGH' THEN 4 WHEN 'MODERATE' THEN 3
                           WHEN 'LOW' THEN 2 WHEN 'MODIFIER' THEN 1 END END) AS rank_snpeff,
         max(CASE WHEN source = 'product_call' THEN
               CASE impact WHEN 'HIGH' THEN 4 WHEN 'MODERATE' THEN 3
                           WHEN 'LOW' THEN 2 WHEN 'MODIFIER' THEN 1 END END) AS rank_pc,
         string_agg(DISTINCT CASE WHEN source = 'snpeff'       THEN effect END, ', ') AS effect_summary_snpeff,
         string_agg(DISTINCT CASE WHEN source = 'product_call' THEN effect END, ', ') AS effect_summary_product_call
  FROM apidb.VariationEffect
  WHERE sequence_source_id = 'Pf3D7_01_v3' AND location IN (12, 18, 29514)
  GROUP BY sequence_source_id, location
)
SELECT v.source_id,
       g.project_id,
       v.sequence_source_id,
       v.location,
       trim(to_char(v.location, '99,999,999')) AS location_text,
       g.organism,
       g.ncbi_tax_id,
       g.chromosome_order_num,
       coalesce(dp.display_name, d.name)       AS dataset,
       ga.gene_ids,
       coalesce(ga.gene_count, 0)              AS gene_count,
       CASE ea.rank_snpeff WHEN 4 THEN 'HIGH' WHEN 3 THEN 'MODERATE'
                           WHEN 2 THEN 'LOW'  WHEN 1 THEN 'MODIFIER' END AS most_severe_impact_snpeff,
       CASE ea.rank_pc     WHEN 4 THEN 'HIGH' WHEN 3 THEN 'MODERATE'
                           WHEN 2 THEN 'LOW'  WHEN 1 THEN 'MODIFIER' END AS most_severe_impact_product_call,
       ea.effect_summary_snpeff,
       ea.effect_summary_product_call,
       concat_ws('; ',
         CASE WHEN v.snp_minor_allele   IS NOT NULL THEN concat(v.snp_ref_allele,   '>', v.snp_minor_allele)   END,
         CASE WHEN v.indel_minor_allele IS NOT NULL THEN concat(v.indel_ref_allele, '>', v.indel_minor_allele) END
       )                                       AS collapsed_allele,
       CASE WHEN v.snp_minor_allele_frequency IS NULL
             AND v.indel_minor_allele_frequency IS NULL THEN NULL
            ELSE greatest(coalesce(v.snp_minor_allele_frequency,   0),
                          coalesce(v.indel_minor_allele_frequency, 0)) END AS collapsed_minor_allele_frequency
FROM apidb.VariationFeature v
JOIN apidbtuning.GenomicSeqAttributes g ON g.source_id = v.sequence_source_id
JOIN sres.ExternalDatabaseRelease r     ON r.external_database_release_id = v.external_database_release_id
JOIN sres.ExternalDatabase d            ON d.external_database_id = r.external_database_id
LEFT JOIN apidbtuning.DatasetPresenter dp ON dp.name = d.name
LEFT JOIN gene_agg   ga ON ga.sequence_source_id = v.sequence_source_id AND ga.location = v.location
LEFT JOIN effect_agg ea ON ea.sequence_source_id = v.sequence_source_id AND ea.location = v.location
WHERE v.sequence_source_id = 'Pf3D7_01_v3' AND v.location IN (12, 18, 29514)
ORDER BY v.location
```

- [x] **Step 2: Run it and assert the expected values**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -x \
  -f /tmp/claude-1000/-home-jbrestel-workspaces-agentic-veupath-dev/scratch-va-spot.sql
```

Expected — three records, with these exact values:

| | loc 12 (MIXED) | loc 18 (INDEL) | loc 29514 (SNV) |
|---|---|---|---|
| `collapsed_allele` | `A>C; A>AC` | `AC>A` | `T>C` |
| `collapsed_minor_allele_frequency` | `0.0598` | `0.008` | `0.0063` |
| `gene_ids` | *(null)* | *(null)* | `PF3D7_0100100` |
| `gene_count` | `0` | `0` | `1` |
| `most_severe_impact_snpeff` | `MODIFIER` | `MODIFIER` | `MODERATE` |
| `most_severe_impact_product_call` | *(null)* | *(null)* | `MODERATE` |
| `location_text` | `12` | `18` | `29,514` |
| `project_id` | `PlasmoDB` | `PlasmoDB` | `PlasmoDB` |
| `dataset` | `pfal3D7_dnaSeqVariations` | same | same |

The `MIXED` locus rendering as `A>C; A>AC` is the single most important assertion here —
it is the case a collapsed single-allele column would have silently destroyed.

`dataset` showing the raw external-database name (not a friendlier display name) is
**correct and expected**: no `DatasetPresenter` row matches these external databases,
because presenters exist per dnaseq *experiment* while `*_dnaSeqVariations` is the merged
call set across many experiments. Do not "fix" this.

- [x] **Step 3: Verify the GenomicSeqAttributes join loses no loci**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select count(*) total, count(g.source_id) matched
from apidb.variationfeature v
left join apidbtuning.genomicseqattributes g on g.source_id = v.sequence_source_id"
```

Expected: `total` = `matched` = `4390908`. An inner join is used in the tuning SQL, so a
mismatch would silently drop loci.

- [x] **Step 4: No commit**

Scratch SQL is not committed. Proceed to Task 2.

---

## Task 2: Add the VariationAttributes tuning table definition

**Files:**
- Modify: `~/workspaces/plasmodb/ApiCommonModel/Model/lib/xml/tuningManager/apiTuningManager.xml`

**Convention note.** Inside a `<tuningTable>`, the table being created takes an `&1`
suffix (`VariationAttributes&1`); *other* tuning tables are referenced **unqualified and
without `&1`** (`TranscriptAttributes`, `GenomicSeqAttributes`, `DatasetPresenter`), while
non-tuning base tables stay schema-qualified (`apidb.`, `sres.`). Compare the existing
`GeneOrgAbbrev` and `GoSubsetLeaf` definitions in the same file.

- [x] **Step 1: Insert the tuning table definition**

Add this immediately after the closing `</tuningTable>` of `TranscriptOrgAbbrev`
(around line 1088). Note both `internalDependency` elements — omitting either causes a
silently empty column rather than an error, per spec §3.3a.

```xml
 <tuningTable name="VariationAttributes">
    <comment>
      One row per variant locus. Holds ONLY columns that are derived, aggregated, or
      require a join; intrinsic per-locus facts are read directly from
      apidb.VariationFeature by the WDK attribute query, since that table is already
      one row per locus with a unique source_id.
      See docs/superpowers/specs/2026-07-30-variation-record-design.md
    </comment>
    <internalDependency name="TranscriptAttributes"/>
    <internalDependency name="GenomicSeqAttributes"/>
    <externalDependency name="apidb.VariationFeature"/>
    <externalDependency name="apidb.VariationTranscriptProduct"/>
    <externalDependency name="apidb.VariationEffect"/>
    <externalDependency name="sres.ExternalDatabaseRelease"/>
    <externalDependency name="sres.ExternalDatabase"/>
    <sql>
      <![CDATA[
        CREATE TABLE VariationAttributes&1 AS
        WITH gene_agg AS (
          SELECT sequence_source_id, location,
                 string_agg(DISTINCT gene_source_id, ', ' ORDER BY gene_source_id) AS gene_ids,
                 count(DISTINCT gene_source_id)                                    AS gene_count
          FROM (
            SELECT e.sequence_source_id, e.location, t.gene_source_id
            FROM apidb.VariationEffect e
            JOIN TranscriptAttributes t ON t.na_feature_id = e.na_feature_id
            UNION
            SELECT p.sequence_source_id, p.location, t.gene_source_id
            FROM apidb.VariationTranscriptProduct p
            JOIN TranscriptAttributes t ON t.na_feature_id = p.na_feature_id
          ) g
          GROUP BY sequence_source_id, location
        ),
        effect_agg AS (
          SELECT sequence_source_id, location,
                 max(CASE WHEN source = 'snpeff' THEN
                       CASE impact WHEN 'HIGH' THEN 4 WHEN 'MODERATE' THEN 3
                                   WHEN 'LOW' THEN 2 WHEN 'MODIFIER' THEN 1 END END) AS rank_snpeff,
                 max(CASE WHEN source = 'product_call' THEN
                       CASE impact WHEN 'HIGH' THEN 4 WHEN 'MODERATE' THEN 3
                                   WHEN 'LOW' THEN 2 WHEN 'MODIFIER' THEN 1 END END) AS rank_pc,
                 string_agg(DISTINCT CASE WHEN source = 'snpeff'       THEN effect END, ', ') AS effect_summary_snpeff,
                 string_agg(DISTINCT CASE WHEN source = 'product_call' THEN effect END, ', ') AS effect_summary_product_call
          FROM apidb.VariationEffect
          GROUP BY sequence_source_id, location
        )
        SELECT v.source_id,
               g.project_id,
               v.sequence_source_id,
               v.location,
               trim(to_char(v.location, '99,999,999')) AS location_text,
               g.organism,
               g.ncbi_tax_id,
               g.chromosome_order_num,
               coalesce(dp.display_name, d.name)       AS dataset,
               ga.gene_ids,
               coalesce(ga.gene_count, 0)              AS gene_count,
               CASE ea.rank_snpeff WHEN 4 THEN 'HIGH' WHEN 3 THEN 'MODERATE'
                                   WHEN 2 THEN 'LOW'  WHEN 1 THEN 'MODIFIER' END AS most_severe_impact_snpeff,
               CASE ea.rank_pc     WHEN 4 THEN 'HIGH' WHEN 3 THEN 'MODERATE'
                                   WHEN 2 THEN 'LOW'  WHEN 1 THEN 'MODIFIER' END AS most_severe_impact_product_call,
               ea.effect_summary_snpeff,
               ea.effect_summary_product_call,
               concat_ws('; ',
                 CASE WHEN v.snp_minor_allele   IS NOT NULL THEN concat(v.snp_ref_allele,   '>', v.snp_minor_allele)   END,
                 CASE WHEN v.indel_minor_allele IS NOT NULL THEN concat(v.indel_ref_allele, '>', v.indel_minor_allele) END
               )                                       AS collapsed_allele,
               CASE WHEN v.snp_minor_allele_frequency IS NULL
                     AND v.indel_minor_allele_frequency IS NULL THEN NULL
                    ELSE greatest(coalesce(v.snp_minor_allele_frequency,   0),
                                  coalesce(v.indel_minor_allele_frequency, 0)) END AS collapsed_minor_allele_frequency
        FROM apidb.VariationFeature v
        JOIN GenomicSeqAttributes g           ON g.source_id = v.sequence_source_id
        JOIN sres.ExternalDatabaseRelease r   ON r.external_database_release_id = v.external_database_release_id
        JOIN sres.ExternalDatabase d          ON d.external_database_id = r.external_database_id
        LEFT JOIN DatasetPresenter dp         ON dp.name = d.name
        LEFT JOIN gene_agg   ga ON ga.sequence_source_id = v.sequence_source_id AND ga.location = v.location
        LEFT JOIN effect_agg ea ON ea.sequence_source_id = v.sequence_source_id AND ea.location = v.location
      ]]>
    </sql>
    <sql>
      <![CDATA[
        CREATE UNIQUE INDEX VariationAttr_pk&1 ON VariationAttributes&1 (source_id, project_id)
      ]]>
    </sql>
    <sql>
      <![CDATA[
        CREATE INDEX VariationAttr_loc&1 ON VariationAttributes&1 (sequence_source_id, location)
      ]]>
    </sql>
    <sql>
      <![CDATA[
        CREATE INDEX VariationAttr_sort&1 ON VariationAttributes&1 (chromosome_order_num, location)
      ]]>
    </sql>
  </tuningTable>
```

- [x] **Step 2: Verify the file is still well-formed XML**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && python3 -c "
import xml.dom.minidom
xml.dom.minidom.parse('Model/lib/xml/tuningManager/apiTuningManager.xml')
print('XML OK')"
```

Expected: `XML OK`. A malformed edit here breaks every tuning table, not just this one.

- [x] **Step 3: Confirm the definition is registered exactly once**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && \
  grep -c 'tuningTable name="VariationAttributes"' Model/lib/xml/tuningManager/apiTuningManager.xml
```

Expected: `1`.

- [x] **Step 4: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/xml/tuningManager/apiTuningManager.xml
git commit -m "Add VariationAttributes tuning table

One row per variant locus, holding only derived/aggregated/join-requiring
columns. Intrinsic per-locus facts are read directly from
apidb.VariationFeature, which is already record-shaped.

Declares internalDependency on both TranscriptAttributes (gene aggregate)
and GenomicSeqAttributes (project_id, organism, chromosome_order_num);
built out of order these yield silently empty columns rather than errors."
```

---

## Task 3: Build and verify the tuning table

**Files:** none (build + verification)

- [x] **Step 1: Build the table as a `jbrestel`-schema stub**

`tuningManager` is not installed on this dev instance
(`ls /var/www/jbrestel.plasmodb.org/gus_home/bin | grep -i tuning` returns only
`joeUser*DatabaseTuning` wrappers), and no `veup-build.sh` command wraps a tuning build.
Rather than block on the central tuning job, build the same table in the developer's own
`jbrestel` schema. This does double duty: it executes the committed SQL for real, and it
unblocks Tasks 4-13 immediately.

Run `scratchpad/create-jbrestel-va.sql` — the committed tuning SQL with every `&1`
dropped and tuning-table references schema-qualified (`apidbtuning.TranscriptAttributes`
etc.), since the tuning manager's `search_path` is not in effect outside it:

```bash
psql -h localhost -p 5432 -d unidb_shu_a -v ON_ERROR_STOP=1 -f create-jbrestel-va.sql
```

It ends with `GRANT SELECT ON jbrestel.VariationAttributes TO gus_r` so the webapp can
read it. Budget minutes: the aggregates cover 6.79M `VariationEffect` and 4.6M
`VariationTranscriptProduct` rows.

**Writes are confined to the `jbrestel` schema.** Never create or alter anything in
`apidbtuning`, and never invent a `tuningManager` command line against a shared schema.

- [x] **Step 1a: Point the model at the stub, in exactly six places**

While stubbed, every query in Tasks 4-11 reads `jbrestel.VariationAttributes` instead of
`ApidbTuning.VariationAttributes`. There are **six** occurrences across the two query
files:

| file | query |
|---|---|
| `variationAttributeQueries.xml` | `testRowCountSql` |
| `variationAttributeQueries.xml` | `VariationAlias` |
| `variationAttributeQueries.xml` | `VariationTuning` |
| `variationAttributeQueries.xml` | `VariationFeatureBase` |
| `variationTableQueries.xml` | `TranscriptProducts` |
| `variationTableQueries.xml` | `PredictedEffects` |

Write the XML in Tasks 4-11 with `jbrestel.VariationAttributes`, and put this comment at
the top of **both** query files so the stub cannot be forgotten:

```xml
  <!-- TEMPORARY STUB: reads jbrestel.VariationAttributes instead of
       ApidbTuning.VariationAttributes until the central tuning job builds the real
       table. Flip back per Task 14 before merging. -->
```

- [x] **Step 1b: Verify the stub is complete and consistent**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/records && \
  grep -c 'jbrestel\.VariationAttributes'   variationAttributeQueries.xml variationTableQueries.xml && \
  grep -c 'ApidbTuning\.VariationAttributes' variationAttributeQueries.xml variationTableQueries.xml
```

Actual once Tasks 4-11 are done: **`5` and `3`** for the `jbrestel` form, `0` and `0` for
the `ApidbTuning` form.

Those totals include the `TEMPORARY STUB` comment line in each file, so the SQL references
alone are `4` and `2` — which is what Task 14 expects *after* the flip, since Task 14 also
deletes the comments. Verified breakdown: `variationAttributeQueries.xml` has 4 SQL
references (`testRowCountSql`, `VariationAlias`, `VariationTuning`, `VariationFeatureBase`)
plus 1 comment; `variationTableQueries.xml` has 2 (`TranscriptProducts`,
`PredictedEffects`) plus 1 comment.

A non-zero `ApidbTuning` count while stubbed means a query will fail at build time; a
non-zero `jbrestel` count after Task 14 means the stub leaked into a merge.

- [x] **Step 2: Verify row count matches the base table exactly**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select (select count(*) from jbrestel.variationattributes) as tuning,
       (select count(*) from apidb.variationfeature)          as base"
```

Expected: both `4390908`. A shortfall means the inner join to `GenomicSeqAttributes`
dropped loci — investigate before continuing.

- [x] **Step 3: Verify the aggregate columns are actually populated**

This is the assertion that catches a dependency-ordering failure, which produces empty
columns rather than an error.

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select count(*) filter (where gene_ids is not null)                   as with_genes,
       count(*) filter (where most_severe_impact_snpeff is not null)  as with_snpeff,
       count(*) filter (where most_severe_impact_product_call is not null) as with_pc,
       count(*) filter (where collapsed_allele is not null)           as with_allele,
       count(distinct project_id)                                     as projects
from jbrestel.variationattributes"
```

Expected, approximately: `with_genes` ≈ 2,878,000 (not 0 — zero means the
`TranscriptAttributes` dependency did not resolve), `with_snpeff` > `with_pc` (snpeff
covers ~2.9M more loci), `with_allele` = 4,390,908, `projects` = 3.

- [x] **Step 4: Verify the three spot-check loci survived the build**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -x -c "
select source_id, collapsed_allele, collapsed_minor_allele_frequency,
       gene_ids, most_severe_impact_snpeff, most_severe_impact_product_call, location_text
from jbrestel.variationattributes
where source_id in ('Variant_Pf3D7_01_v3_12','Variant_Pf3D7_01_v3_18','Variant_Pf3D7_01_v3_29514')
order by location"
```

Expected: identical to the Task 1 Step 2 table.

- [x] **Step 5: No commit** (no files changed)

---

## Task 4: Minimal buildable record — vertical slice

Get a `variation` record that builds and loads by ID, with only the identity attributes.
Everything after this task is additive and independently verifiable.

**Files:**
- Create: `Model/lib/wdk/model/records/variationAttributeQueries.xml`
- Create: `Model/lib/wdk/model/records/variationTableQueries.xml`
- Create: `Model/lib/wdk/model/records/variationRecords.xml`
- Modify: `Model/lib/wdk/apiCommonModel.xml:406-408` (add three imports near the snp ones)

- [x] **Step 1: Create `variationAttributeQueries.xml`**

```xml
<wdkModel>
  <querySet name="VariationAttributes" queryType="attribute" isCacheable="false"
            includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

    <defaultTestParamValues includeProjects="PlasmoDB,UniDB">
      <paramValue name="source_id">Variant_Pf3D7_01_v3_100057</paramValue>
      <paramValue name="project_id">PlasmoDB</paramValue>
    </defaultTestParamValues>

    <defaultTestParamValues includeProjects="TriTrypDB">
      <paramValue name="source_id">Variant_11L3_v3_26886</paramValue>
      <paramValue name="project_id">TriTrypDB</paramValue>
    </defaultTestParamValues>

    <defaultTestParamValues includeProjects="FungiDB">
      <paramValue name="source_id">Variant_Chr1_A_fumigatus_Af293_1000005</paramValue>
      <paramValue name="project_id">FungiDB</paramValue>
    </defaultTestParamValues>

    <testRowCountSql>
      SELECT count(*) FROM jbrestel.VariationAttributes
    </testRowCountSql>

    <!-- Alias query: no historical ID remapping exists for this new record, so old
         IDs are simply the current IDs. Mirrors SnpAttributes.SnpAlias. -->
    <sqlQuery name="VariationAlias" doNotTest="true">
      <column name="source_id"/>
      <column name="project_id"/>
      <column name="old_source_id"/>
      <column name="old_project_id"/>
      <sql>
        <![CDATA[
          SELECT source_id,
                 project_id,
                 source_id  AS old_source_id,
                 project_id AS old_project_id
          FROM jbrestel.VariationAttributes
        ]]>
      </sql>
    </sqlQuery>

    <!-- Derived / aggregated / join-requiring columns. -->
    <sqlQuery name="VariationTuning">
      <column name="source_id"/>
      <column name="project_id"/>
      <column name="sequence_source_id" sortingColumn="chromosome_order_num"/>
      <column name="location" sortingColumn="location"/>
      <column name="location_text" sortingColumn="location"/>
      <column name="chromosome_order_num"/>
      <column name="organism_text" ignoreCase="true"/>
      <column name="formatted_organism" sortingColumn="organism_text"/>
      <column name="ncbi_tax_id"/>
      <column name="dataset" ignoreCase="true"/>
      <sql>
        <![CDATA[
          SELECT va.source_id, va.project_id,
                 va.sequence_source_id, va.location, va.location_text,
                 va.chromosome_order_num,
                 va.organism AS organism_text,
                 CONCAT('<i>', SUBSTR(va.organism, 1, 1), '.',
                        REGEXP_REPLACE(SUBSTR(va.organism, strpos(va.organism, ' ')),
                                       '[[:space:]]+', CONCAT(chr(38), 'nbsp;')),
                        '</i>') AS formatted_organism,
                 va.ncbi_tax_id,
                 va.dataset
          FROM jbrestel.VariationAttributes va
        ]]>
      </sql>
    </sqlQuery>

  </querySet>
</wdkModel>
```

- [x] **Step 2: Do NOT create `variationTableQueries.xml` yet**

WDK's RELAX NG schema requires a `querySet` to contain at least one `sqlQuery`,
`processQuery`, or `testRowCountSql`. A `querySet` holding only `defaultTestParamValues`
fails validation with:

```
element "querySet" incomplete; expected element "defaultTestParamValues",
"processQuery", "sqlQuery" or "testRowCountSql"
```

There is therefore no valid empty placeholder. `variationTableQueries.xml` is created in
**Task 10**, together with its first query and its import line.

- [x] **Step 3: Create `variationRecords.xml` with identity attributes only**

```xml
<wdkModel>

  <recordClassSet name="VariationRecordClasses"
                  includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

    <recordClass name="VariationRecordClass" urlName="variation"
                 displayName="Variation" displayNamePlural="Variations">

      <testParamValues includeProjects="PlasmoDB">
        <paramValue name="source_id">Variant_Pf3D7_01_v3_100057</paramValue>
        <paramValue name="project_id">PlasmoDB</paramValue>
      </testParamValues>

      <testParamValues includeProjects="UniDB">
        <paramValue name="source_id">Variant_Pf3D7_01_v3_100057</paramValue>
      </testParamValues>

      <testParamValues includeProjects="TriTrypDB">
        <paramValue name="source_id">Variant_11L3_v3_26886</paramValue>
        <paramValue name="project_id">TriTrypDB</paramValue>
      </testParamValues>

      <testParamValues includeProjects="FungiDB">
        <paramValue name="source_id">Variant_Chr1_A_fumigatus_Af293_1000005</paramValue>
        <paramValue name="project_id">FungiDB</paramValue>
      </testParamValues>

      <primaryKey aliasQueryRef="VariationAttributes.VariationAlias">
        <columnRef>source_id</columnRef>
        <columnRef excludeProjects="UniDB">project_id</columnRef>
      </primaryKey>

      <idAttribute name="primary_key" displayName="Variation ID">
        <text><![CDATA[ $$source_id$$ ]]></text>
      </idAttribute>

      <reporter name="attributesTabular" displayName="%%attributesReporterDisplayName%%" scopes="results"
                implementation="org.gusdb.wdk.model.report.reporter.AttributesTabularReporter">
        <property name="page_size">500</property>
      </reporter>

      <reporter name="tableTabular" displayName="%%tableReporterDisplayName%%" scopes="results"
                implementation="org.gusdb.wdk.model.report.reporter.TableTabularReporter">
        <property name="page_size">1000000</property>
      </reporter>

      <reporter name="fullRecord" displayName="%%fullReporterDisplayName%%" scopes="record"
                implementation="org.gusdb.wdk.model.report.reporter.FullRecordReporter"/>

      <reporter name="xml" displayName="XML: choose from columns and/or tables" scopes=""
                implementation="org.gusdb.wdk.model.report.reporter.XMLReporter"/>

      <reporter name="json" displayName="json: choose from columns and/or tables" scopes=""
                implementation="org.gusdb.wdk.model.report.reporter.JSONReporter"/>

      <!-- Identity & location. sequence_source_id and location are deliberately
           non-internal and independently addressable: they are the coordinate a future
           VCF/tabix lookup and an EDA sample join both key on. See spec section 4. -->
      <attributeQueryRef ref="VariationAttributes.VariationTuning">
        <columnAttribute name="sequence_source_id" displayName="Sequence"/>
        <columnAttribute name="location"           displayName="Position"/>
        <columnAttribute name="location_text"      displayName="Position" inReportMaker="false"/>
        <columnAttribute name="chromosome_order_num" displayName="Chromosome" inReportMaker="false"/>
        <columnAttribute name="organism_text"      displayName="Organism" inReportMaker="true"/>
        <columnAttribute name="formatted_organism" displayName="Organism" inReportMaker="false"
                         help="Abbreviated italic form, e.g. P.&#160;falciparum&#160;3D7."/>
        <columnAttribute name="ncbi_tax_id"        displayName="NCBI Taxon ID" inReportMaker="false"/>
        <columnAttribute name="dataset"            displayName="Variant Call Set"
                         help="The merged variant call set this locus came from. Contributing
                               dnaseq experiments are per-strain and are not listed here."/>
        <textAttribute name="variation_location" displayName="Location">
          <text><![CDATA[ $$sequence_source_id$$: $$location_text$$ ]]></text>
        </textAttribute>
      </attributeQueryRef>

      <textAttribute name="organism" displayName="Organism" inReportMaker="true"
                     help="The biological sample used to sequence this genome">
        <display><![CDATA[ <i>$$organism_text$$</i> ]]></display>
        <text><![CDATA[ $$organism_text$$ ]]></text>
      </textAttribute>

      <attributesList summary="variation_location,organism" sorting="chromosome_order_num asc,location asc"/>

    </recordClass>

  </recordClassSet>
</wdkModel>
```

- [x] **Step 4: Add the imports — mind the comment block**

**The snp imports at lines 405-411 sit inside a `<!-- UNCOMMENT WHEN SNPS are AVAILABLE`
block that closes at line 412**, and the snpChip block right after it is commented out
too. Inserting "after the snp imports" would place the new imports *inside* a comment and
silently disable the record — the build passes and the record simply does not exist.

Insert **after** the closing `-->` of the snp block, immediately before
`<!-- SNP from Array -->`:

```xml
  <!-- Variations (replaces the deprecated SNP record above) -->
  <import file="model/records/variationAttributeQueries.xml"/>
  <import file="model/records/variationRecords.xml"/>
```

Two imports only: `variationTableQueries.xml` does not exist until Task 10.

Verify the imports are live rather than swallowed by a comment:

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && python3 -c "
import re
s = open('Model/lib/wdk/apiCommonModel.xml').read()
stripped = re.sub(r'<!--.*?-->', '', s, flags=re.S)
for n in ['variationAttributeQueries', 'variationRecords']:
    print(n, 'ACTIVE' if n in stripped else 'COMMENTED OUT -- FIX THIS')"
```

Expected: both `ACTIVE`.

- [x] **Step 5: Build the model — this is the test**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: build completes and reloads the webapp. A failure naming
`VariationAttributes.VariationTuning` means a column in the record class is not returned
by the query; a failure naming `jbrestel.VariationAttributes` means Task 3 did not
actually create the table.

- [x] **Step 6: Verify the assembled SQL is what you intended**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  wdkQuery -model PlasmoDB -query VariationAttributes.VariationTuning -showQuery"'
```

Expected: the `SELECT ... FROM jbrestel.VariationAttributes va` body, wrapped by WDK's
PK join. This does not execute the query, so it is always safe.

- [x] **Step 7: Verify the record type is registered**

Using Claude in Chrome, load `https://jbrestel.plasmodb.org` and run:

```js
await (await fetch('/plasmo.jbrestel/service/record-types/variation')).json()
```

Expected: JSON with `urlSegment: "variation"`, `displayName: "Variation"`, and an
`attributes` array containing `sequence_source_id`, `location`, `variation_location`,
`organism`. `tables` will be empty — correct at this stage.

- [x] **Step 8: Verify a record page loads**

Navigate to
`https://jbrestel.plasmodb.org/plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_100057`

Expected: the page renders with the ID as its title and shows Location and Organism.
If it 404s, the alias query is not resolving the ID.

- [x] **Step 9: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationAttributeQueries.xml \
        Model/lib/wdk/model/records/variationTableQueries.xml \
        Model/lib/wdk/model/records/variationRecords.xml \
        Model/lib/wdk/apiCommonModel.xml
git commit -m "Add a minimal buildable variation record

Record class, alias query, and the tuning-backed identity/location
attributes. sequence_source_id and location are exposed as first-class
non-internal attributes because they are the coordinate a future VCF
lookup and EDA join both key on.

Builds and loads by ID; attributes and tables follow."
```

---

## Task 5: Classification attributes from VariationFeature

Add the first attribute query that reads `apidb.VariationFeature` directly — the other
half of the sourcing rule.

**Files:**
- Modify: `Model/lib/wdk/model/records/variationAttributeQueries.xml`
- Modify: `Model/lib/wdk/model/records/variationRecords.xml`

- [x] **Step 1: Assert the expected values in psql first**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select source_id, variant_type, is_coding, reference_strain
from apidb.variationfeature
where source_id in ('Variant_Pf3D7_01_v3_12','Variant_Pf3D7_01_v3_18','Variant_Pf3D7_01_v3_29514')
order by location"
```

Expected: `MIXED`/`0`/`3D7`, `INDEL`/`0`/`3D7`, `SNV`/`1`/`3D7`.

- [x] **Step 2: Add the query to `variationAttributeQueries.xml`**

Insert before the closing `</querySet>`:

```xml
    <!-- Intrinsic per-locus facts, read straight from the base table. It is already
         one row per locus with a unique source_id, which is what makes the hybrid
         sourcing rule work. Joined to the tuning table only for project_id. -->
    <sqlQuery name="VariationFeatureBase">
      <column name="source_id"/>
      <column name="project_id"/>
      <column name="variant_type"/>
      <column name="is_coding"/>
      <column name="reference_strain"/>
      <sql>
        <![CDATA[
          SELECT vf.source_id, va.project_id,
                 vf.variant_type,
                 CASE vf.is_coding WHEN 1 THEN 'coding' ELSE 'non-coding' END AS is_coding,
                 vf.reference_strain
          FROM apidb.VariationFeature vf,
               jbrestel.VariationAttributes va
          WHERE va.source_id = vf.source_id
        ]]>
      </sql>
    </sqlQuery>
```

- [x] **Step 3: Add the attributes to `variationRecords.xml`**

Insert after the closing `</attributeQueryRef>` of the `VariationTuning` block:

```xml
      <attributeQueryRef ref="VariationAttributes.VariationFeatureBase">
        <columnAttribute name="variant_type" displayName="Variant Type"
                         help="SNV (single-nucleotide), INDEL (insertion/deletion), or
                               MIXED (both classes observed at this locus)."/>
        <columnAttribute name="is_coding" displayName="Coding" align="center"/>
        <columnAttribute name="reference_strain" displayName="Reference Strain"/>
      </attributeQueryRef>
```

- [x] **Step 4: Build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: green build.

- [x] **Step 5: Verify on the record page**

Reload `https://jbrestel.plasmodb.org/plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_29514`

Expected: Variant Type `SNV`, Coding `coding`, Reference Strain `3D7`.

- [x] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationAttributeQueries.xml \
        Model/lib/wdk/model/records/variationRecords.xml
git commit -m "Add variation classification attributes from VariationFeature

First attribute query reading apidb.VariationFeature directly, per the
sourcing rule: intrinsic per-locus facts come from the base table, only
derived/joined columns come from the tuning table."
```

---

## Task 6: SNP and Indel allele sections

The core of the design: two named sections, never collapsed.

**Files:**
- Modify: `Model/lib/wdk/model/records/variationAttributeQueries.xml`
- Modify: `Model/lib/wdk/model/records/variationRecords.xml`

- [x] **Step 1: Assert the MIXED locus carries both classes**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -x -c "
select snp_ref_allele, snp_major_allele, snp_minor_allele, snp_minor_allele_frequency,
       indel_ref_allele, indel_major_allele, indel_minor_allele, indel_minor_allele_frequency,
       snp_minor_genomic_hgvs, indel_minor_genomic_hgvs, indel_frame_effect
from apidb.variationfeature where source_id = 'Variant_Pf3D7_01_v3_12'"
```

Expected: SNP side `A`/`A`/`C`/`0.0598`, indel side `A`/`A`/`AC`/`0.0085`,
`snp_minor_genomic_hgvs` = `Pf3D7_01_v3:g.12A>C`, `indel_minor_genomic_hgvs` =
`Pf3D7_01_v3:g.12_13insC`. Both sides populated on one row is exactly the case that
motivates two sections.

- [x] **Step 2: Extend `VariationFeatureBase` with all 19 allele columns**

19, not 22: 9 `snp_*` + 10 `indel_*`. `indel_frame_effect` is indel-only, so the two
sections are deliberately asymmetric.

Add these `<column>` declarations to the existing `VariationFeatureBase` query, after
`<column name="reference_strain"/>`:

```xml
      <column name="snp_ref_allele"/>
      <column name="snp_major_allele"/>
      <column name="snp_major_allele_frequency"/>
      <column name="snp_major_allele_strain_count"/>
      <column name="snp_minor_allele"/>
      <column name="snp_minor_allele_frequency"/>
      <column name="snp_minor_allele_strain_count"/>
      <column name="snp_major_genomic_hgvs"/>
      <column name="snp_minor_genomic_hgvs"/>
      <column name="indel_ref_allele"/>
      <column name="indel_major_allele"/>
      <column name="indel_major_allele_frequency"/>
      <column name="indel_major_allele_strain_count"/>
      <column name="indel_minor_allele"/>
      <column name="indel_minor_allele_frequency"/>
      <column name="indel_minor_allele_strain_count"/>
      <column name="indel_major_genomic_hgvs"/>
      <column name="indel_minor_genomic_hgvs"/>
      <column name="indel_frame_effect"/>
```

And add the matching columns to the `SELECT` list, immediately after
`vf.reference_strain,`:

```sql
                 vf.snp_ref_allele, vf.snp_major_allele,
                 vf.snp_major_allele_frequency, vf.snp_major_allele_strain_count,
                 vf.snp_minor_allele,
                 vf.snp_minor_allele_frequency, vf.snp_minor_allele_strain_count,
                 vf.snp_major_genomic_hgvs, vf.snp_minor_genomic_hgvs,
                 vf.indel_ref_allele, vf.indel_major_allele,
                 vf.indel_major_allele_frequency, vf.indel_major_allele_strain_count,
                 vf.indel_minor_allele,
                 vf.indel_minor_allele_frequency, vf.indel_minor_allele_strain_count,
                 vf.indel_major_genomic_hgvs, vf.indel_minor_genomic_hgvs,
                 vf.indel_frame_effect,
```

- [x] **Step 3: Add the allele attributes to `variationRecords.xml`**

Add inside the existing `VariationFeatureBase` `<attributeQueryRef>` block, after
`reference_strain`. Note the shared `help` text on the HGVS attributes — the
major-allele HGVS is null whenever the major allele equals the reference, and without
this it reads as missing data.

```xml
        <!-- ===== SNP Alleles ===== -->
        <columnAttribute name="snp_ref_allele"   displayName="SNP Reference Allele" align="center"/>
        <columnAttribute name="snp_major_allele" displayName="SNP Major Allele" align="center"/>
        <columnAttribute name="snp_major_allele_frequency"    displayName="SNP Major Allele Frequency" align="center"/>
        <columnAttribute name="snp_major_allele_strain_count" displayName="SNP Major Allele Strain Count" align="center"/>
        <columnAttribute name="snp_minor_allele" displayName="SNP Minor Allele" align="center"/>
        <columnAttribute name="snp_minor_allele_frequency"    displayName="SNP Minor Allele Frequency" align="center"/>
        <columnAttribute name="snp_minor_allele_strain_count" displayName="SNP Minor Allele Strain Count" align="center"/>
        <columnAttribute name="snp_major_genomic_hgvs" displayName="SNP Major Allele HGVS"
                         help="Genomic HGVS for the major allele. Empty when the major allele
                               is identical to the reference allele, which is the usual case."/>
        <columnAttribute name="snp_minor_genomic_hgvs" displayName="SNP Minor Allele HGVS"/>
        <textAttribute name="snp_major_allele_and_freq" displayName="SNP Major Allele" align="center">
          <text><![CDATA[ $$snp_major_allele$$ ($$snp_major_allele_frequency$$) ]]></text>
        </textAttribute>
        <textAttribute name="snp_minor_allele_and_freq" displayName="SNP Minor Allele" align="center">
          <text><![CDATA[ $$snp_minor_allele$$ ($$snp_minor_allele_frequency$$) ]]></text>
        </textAttribute>

        <!-- ===== Indel Alleles ===== -->
        <columnAttribute name="indel_ref_allele"   displayName="Indel Reference Allele" align="center"/>
        <columnAttribute name="indel_major_allele" displayName="Indel Major Allele" align="center"/>
        <columnAttribute name="indel_major_allele_frequency"    displayName="Indel Major Allele Frequency" align="center"/>
        <columnAttribute name="indel_major_allele_strain_count" displayName="Indel Major Allele Strain Count" align="center"/>
        <columnAttribute name="indel_minor_allele" displayName="Indel Minor Allele" align="center"/>
        <columnAttribute name="indel_minor_allele_frequency"    displayName="Indel Minor Allele Frequency" align="center"/>
        <columnAttribute name="indel_minor_allele_strain_count" displayName="Indel Minor Allele Strain Count" align="center"/>
        <columnAttribute name="indel_major_genomic_hgvs" displayName="Indel Major Allele HGVS"
                         help="Genomic HGVS for the major allele. Empty when the major allele
                               is identical to the reference allele, which is the usual case."/>
        <columnAttribute name="indel_minor_genomic_hgvs" displayName="Indel Minor Allele HGVS"/>
        <columnAttribute name="indel_frame_effect" displayName="Indel Frame Effect"/>
        <textAttribute name="indel_major_allele_and_freq" displayName="Indel Major Allele" align="center">
          <text><![CDATA[ $$indel_major_allele$$ ($$indel_major_allele_frequency$$) ]]></text>
        </textAttribute>
        <textAttribute name="indel_minor_allele_and_freq" displayName="Indel Minor Allele" align="center">
          <text><![CDATA[ $$indel_minor_allele$$ ($$indel_minor_allele_frequency$$) ]]></text>
        </textAttribute>
```

- [x] **Step 4: Build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: green build.

- [x] **Step 5: Verify all three variant types render correctly**

Load each and confirm:

| record | expect |
|---|---|
| `Variant_Pf3D7_01_v3_29514` (SNV) | SNP attributes populated; indel attributes empty |
| `Variant_Pf3D7_01_v3_18` (INDEL) | indel populated (`AC` / `A`); SNP empty |
| `Variant_Pf3D7_01_v3_12` (MIXED) | **both** populated — SNP `A`/`C`, indel `A`/`AC` |

The MIXED case is the acceptance test for this task.

- [x] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationAttributeQueries.xml \
        Model/lib/wdk/model/records/variationRecords.xml
git commit -m "Add SNP and Indel allele attributes as separate sections

Both allele classes are preserved rather than collapsed: 129,850 MIXED
loci populate snp_* and indel_* simultaneously and describe the same
strains two ways, so a single major/minor pair would silently lose half
the data.

HGVS attributes carry help text explaining that the major-allele HGVS is
empty whenever the major allele equals the reference."
```

---

## Task 7: Strain and call statistics

**Files:**
- Modify: `Model/lib/wdk/model/records/variationAttributeQueries.xml`
- Modify: `Model/lib/wdk/model/records/variationRecords.xml`

- [x] **Step 1: Assert the values in psql**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -x -c "
select distinct_strain_count, called_strain_count, no_call_strain_count, call_rate,
       total_ploidy_count, het_strain_count, ref_allele_frequency
from apidb.variationfeature where source_id = 'Variant_Pf3D7_01_v3_29514'"
```

Expected: `160`, `159`, `57`, `0.7361`, `160`, `0`, `0.9938`.

- [x] **Step 2: Add columns to `VariationFeatureBase`**

Add the `<column>` declarations:

```xml
      <column name="distinct_strain_count"/>
      <column name="called_strain_count"/>
      <column name="no_call_strain_count"/>
      <column name="call_rate"/>
      <column name="total_ploidy_count"/>
      <column name="het_strain_count"/>
      <column name="ref_allele_frequency"/>
```

And to the `SELECT` list.

**Mind the comma.** After Task 6 the `SELECT` ends with `vf.indel_frame_effect` and **no**
trailing comma, immediately followed by `FROM apidb.VariationFeature vf,`. So you must add
a comma to the current last line, and your own last line must NOT have one. The tail
should read exactly:

```sql
                 vf.indel_frame_effect,
                 vf.distinct_strain_count, vf.called_strain_count,
                 vf.no_call_strain_count, vf.call_rate,
                 vf.total_ploidy_count, vf.het_strain_count,
                 vf.ref_allele_frequency
          FROM apidb.VariationFeature vf,
               jbrestel.VariationAttributes va
          WHERE va.source_id = vf.source_id
```

- [x] **Step 3: Add the attributes to `variationRecords.xml`**

Inside the same `VariationFeatureBase` `<attributeQueryRef>` block:

```xml
        <!-- ===== Strain / call statistics =====
             This group is the anchor for the future per-strain table (spec section 9):
             these are the aggregates that table will detail. -->
        <columnAttribute name="distinct_strain_count" displayName="Strain Count" align="center"/>
        <columnAttribute name="called_strain_count"   displayName="Called Strain Count" align="center"
                         help="Strains with a confident genotype call at this locus."/>
        <columnAttribute name="no_call_strain_count"  displayName="No-Call Strain Count" align="center"
                         help="Strains with insufficient evidence for a genotype call."/>
        <columnAttribute name="call_rate"             displayName="Call Rate" align="center"/>
        <columnAttribute name="total_ploidy_count"    displayName="Total Ploidy Count" align="center"/>
        <columnAttribute name="het_strain_count"      displayName="Heterozygous Strain Count" align="center"/>
        <columnAttribute name="ref_allele_frequency"  displayName="Reference Allele Frequency" align="center"/>
```

- [x] **Step 4: Build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: green build.

- [x] **Step 5: Verify**

Load `https://jbrestel.plasmodb.org/plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_29514` and
confirm Strain Count `160`, Call Rate `0.7361`, Reference Allele Frequency `0.9938`.

- [x] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationAttributeQueries.xml \
        Model/lib/wdk/model/records/variationRecords.xml
git commit -m "Add variation strain and call statistic attributes

Grouped together deliberately: these aggregates are what the future
per-strain VCF-backed table will detail, so it lands beside them."
```

---

## Task 8: Gene linkage, effect rollups, and collapsed columns

**Files:**
- Modify: `Model/lib/wdk/model/records/variationAttributeQueries.xml`
- Modify: `Model/lib/wdk/model/records/variationRecords.xml`

- [x] **Step 1: Assert a multi-gene locus exists and find one**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select source_id, gene_ids, gene_count, most_severe_impact_snpeff,
       most_severe_impact_product_call, collapsed_allele
from jbrestel.variationattributes
where gene_count > 1 and project_id = 'PlasmoDB' order by source_id limit 3"
```

**Filter to `project_id = 'PlasmoDB'`** — you are verifying against a PlasmoDB instance,
and a TriTrypDB or FungiDB record will not resolve there. Multi-gene loci are distributed
TriTrypDB 16,189 / PlasmoDB 4,698 / FungiDB 4,658, so an unfiltered `order by source_id
limit 3` returns TriTrypDB records that 404 on this site.

Verified PlasmoDB multi-gene loci, usable directly:

| `source_id` | `gene_ids` | `gene_count` | `collapsed_allele` |
|---|---|---|---|
| `Variant_Pf3D7_01_v3_125983` | `PF3D7_0102700, PF3D7_0102800` | 2 | `AAT>AATATAT` |
| `Variant_Pf3D7_01_v3_126183` | `PF3D7_0102700, PF3D7_0102800` | 2 | `TA>T` |
| `Variant_Pf3D7_01_v3_126195` | `PF3D7_0102700, PF3D7_0102800` | 2 | `A>C` |

If the query returns nothing, the gene aggregate is broken; go back to Task 3.

- [x] **Step 2: Extend `VariationTuning` with the aggregate columns**

Add the `<column>` declarations to the existing `VariationTuning` query:

```xml
      <column name="gene_ids" ignoreCase="true"/>
      <column name="gene_count"/>
      <column name="most_severe_impact_snpeff" sortingColumn="most_severe_impact_snpeff_rank"/>
      <column name="most_severe_impact_product_call" sortingColumn="most_severe_impact_product_call_rank"/>
      <column name="most_severe_impact_snpeff_rank"/>
      <column name="most_severe_impact_product_call_rank"/>
      <column name="effect_summary_snpeff"/>
      <column name="effect_summary_product_call"/>
      <column name="collapsed_allele"/>
      <column name="collapsed_minor_allele_frequency"/>
```

And to its `SELECT`, after `va.dataset`. This snippet uses **leading** commas, so it
appends cleanly with no trailing-comma hazard — the tail should read:

```sql
                 va.ncbi_tax_id,
                 va.dataset
                 , va.gene_ids, va.gene_count
                 , va.most_severe_impact_snpeff, va.most_severe_impact_product_call
                 , va.effect_summary_snpeff, va.effect_summary_product_call
                 , va.collapsed_allele, va.collapsed_minor_allele_frequency
                 , CASE va.most_severe_impact_snpeff
                     WHEN 'HIGH' THEN 4 WHEN 'MODERATE' THEN 3
                     WHEN 'LOW' THEN 2 WHEN 'MODIFIER' THEN 1 END AS most_severe_impact_snpeff_rank
                 , CASE va.most_severe_impact_product_call
                     WHEN 'HIGH' THEN 4 WHEN 'MODERATE' THEN 3
                     WHEN 'LOW' THEN 2 WHEN 'MODIFIER' THEN 1 END AS most_severe_impact_product_call_rank
          FROM jbrestel.VariationAttributes va
```

**Why the rank columns.** The impact columns hold the *text* `HIGH`/`MODERATE`/`LOW`/`MODIFIER`,
so without a `sortingColumn` WDK sorts them alphabetically — `HIGH, LOW, MODERATE, MODIFIER` —
directly contradicting the severity ranking the columns' own `help` text advertises. A user
sorting a results page by impact would silently get a wrong order. `sortingColumn` only needs
a column returned by the *same query*, so a `CASE` here fixes it with no tuning-table change
and no rebuild.

- [x] **Step 3: Add the attributes to `variationRecords.xml`**

Inside the existing `VariationTuning` `<attributeQueryRef>` block:

```xml
        <!-- ===== Gene linkage =====
             gene_ids is an AGGREGATE, not a lookup: a locus can overlap more than one
             gene (25,545 loci do). There is deliberately no record-level gene_strand,
             because strand is not singular once a locus hits two genes; strand lives in
             the TranscriptProducts table instead. -->
        <columnAttribute name="gene_ids"   displayName="Gene ID(s)" inReportMaker="true"
                         help="All genes overlapping this locus, comma-separated. Usually one."/>
        <columnAttribute name="gene_count" displayName="Gene Count" align="center" inReportMaker="false"/>
        <textAttribute name="linkedGeneIds" displayName="Gene ID(s)" inReportMaker="false">
          <text><![CDATA[ $$gene_ids$$ ]]></text>
          <display><![CDATA[ $$gene_ids$$ ]]></display>
        </textAttribute>

        <!-- ===== Effect rollups, per caller =====
             Kept separate because snpeff and product_call disagree on 19% of paired
             calls, and that disagreement is the scientific content of the pipeline
             rather than noise to be resolved. -->
        <columnAttribute name="most_severe_impact_snpeff" displayName="Most Severe Impact (SnpEff)"
                         align="center"
                         help="Highest impact across all SnpEff calls at this locus,
                               ranked HIGH > MODERATE > LOW > MODIFIER."/>
        <columnAttribute name="most_severe_impact_product_call" displayName="Most Severe Impact (Product Call)"
                         align="center"
                         help="Highest impact across all EuPathDB strain-aware product calls.
                               Empty when there is no product call at this locus."/>
        <columnAttribute name="effect_summary_snpeff"       displayName="Effects (SnpEff)"/>
        <columnAttribute name="effect_summary_product_call" displayName="Effects (Product Call)"/>

        <!-- Sort keys for the two impact columns above. Internal: they exist so that
             sorting by impact follows severity rather than the alphabet. -->
        <columnAttribute name="most_severe_impact_snpeff_rank" displayName="Impact Rank (SnpEff)"
                         internal="true" inReportMaker="false"/>
        <columnAttribute name="most_severe_impact_product_call_rank" displayName="Impact Rank (Product Call)"
                         internal="true" inReportMaker="false"/>

        <!-- ===== Collapsed summary columns =====
             Derived conveniences for results pages only, because WDK tables render only
             on individual record pages. The two allele sections remain canonical. -->
        <columnAttribute name="collapsed_allele" displayName="Allele" align="center"
                         help="Reference&gt;minor allele. A MIXED locus shows both classes,
                               e.g. 'A&gt;C; A&gt;AC'. Derived; see the SNP Alleles and
                               Indel Alleles sections for full detail."/>
        <columnAttribute name="collapsed_minor_allele_frequency" displayName="Minor Allele Frequency"
                         align="center"
                         help="Highest minor-allele frequency across both allele classes. Derived,
                               so a MIXED locus has a single sortable value; see the SNP Alleles and
                               Indel Alleles sections for the per-class frequencies."/>
```

**Note on `linkedGeneIds`:** WDK's `linkAttribute` builds exactly one URL, so it cannot
render one link per ID in an aggregated string. A `textAttribute` is used instead, and it
renders IDs as plain text. If per-ID hyperlinks are wanted, that needs a client-side
component and should be raised with the user as a follow-up rather than faked here.

- [x] **Step 4: Build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: green build.

- [x] **Step 5: Verify single-gene and multi-gene loci both render**

- `Variant_Pf3D7_01_v3_29514` → Gene ID(s) `PF3D7_0100100`, Gene Count `1`, Allele `T>C`,
  both Most Severe Impact columns `MODERATE`.
- `Variant_Pf3D7_01_v3_12` → Allele `A>C; A>AC`, Minor Allele Frequency `0.0598`,
  SnpEff impact `MODIFIER`, Product Call impact **empty**.
- `Variant_Pf3D7_01_v3_126195` → Gene ID(s) shows **two** comma-separated IDs
  (`PF3D7_0102700, PF3D7_0102800`) and Gene Count `2`. This is the acceptance test: it is
  the case a single-gene lookup would have silently misreported.

- [x] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationAttributeQueries.xml \
        Model/lib/wdk/model/records/variationRecords.xml
git commit -m "Add variation gene aggregate, per-caller effect rollups, collapsed columns

Gene linkage is an aggregate rather than a lookup, so the 25,545
multi-gene loci are correct by construction instead of by a later fix.

Effect rollups stay split by caller: snpeff and product_call disagree on
19% of paired calls, 62% of which are product_call's strain-aware
downstream_frameshift.

Collapsed allele and MAF columns exist only because WDK tables render on
record pages, so results pages need pre-aggregated values."
```

---

## Task 9: Record overview and default summary

**Files:**
- Modify: `Model/lib/wdk/model/records/variationRecords.xml`

- [x] **Step 1: Add the overview text attribute**

Insert immediately before the closing `</recordClass>`. Both allele sections appear, each
rendered unconditionally — WDK text attributes have no conditionals, so an absent class
shows empty values, which is honest and matches how the `snp` record behaved.

```xml
      <textAttribute name="record_overview" displayName="Overview" inReportMaker="false"
                     sortable="false" truncateTo="4000">
        <text>
          <![CDATA[
          <div class="eupathdb-RecordOverview">
            <div class="eupathdb-RecordOverviewPanels">
              <div class="eupathdb-RecordOverviewLeft">
                <dl>
                  <dt>Organism</dt><dd>$$organism$$</dd>
                  <dt>Location</dt><dd>$$variation_location$$</dd>
                  <dt>Variant Type</dt><dd>$$variant_type$$</dd>
                  <dt>Coding</dt><dd>$$is_coding$$</dd>
                  <dt>Reference Strain</dt><dd>$$reference_strain$$</dd>
                  <dt>Gene(s)</dt><dd>$$linkedGeneIds$$</dd>
                  <dt>Most Severe Impact (SnpEff)</dt><dd>$$most_severe_impact_snpeff$$</dd>
                  <dt>Most Severe Impact (Product Call)</dt><dd>$$most_severe_impact_product_call$$</dd>
                </dl>
              </div>
              <div class="eupathdb-RecordOverviewRight">
                <dl>
                  <dt><b>SNP Alleles</b></dt><dd></dd>
                  <dt>Reference</dt><dd>$$snp_ref_allele$$</dd>
                  <dt>Major</dt><dd>$$snp_major_allele_and_freq$$</dd>
                  <dt>Minor</dt><dd>$$snp_minor_allele_and_freq$$</dd>
                  <dt><b>Indel Alleles</b></dt><dd></dd>
                  <dt>Reference</dt><dd>$$indel_ref_allele$$</dd>
                  <dt>Major</dt><dd>$$indel_major_allele_and_freq$$</dd>
                  <dt>Minor</dt><dd>$$indel_minor_allele_and_freq$$</dd>
                  <dt><b>Calls</b></dt><dd></dd>
                  <dt>Strain Count</dt><dd>$$distinct_strain_count$$</dd>
                  <dt>Called / No-Call</dt><dd>$$called_strain_count$$ / $$no_call_strain_count$$</dd>
                  <dt>Call Rate</dt><dd>$$call_rate$$</dd>
                  <dt>Heterozygous Strains</dt><dd>$$het_strain_count$$</dd>
                </dl>
              </div>
            </div>
          </div>
          ]]>
        </text>
      </textAttribute>
```

- [x] **Step 2: Replace the placeholder `attributesList`**

Replace the `<attributesList .../>` line added in Task 4 with:

```xml
      <attributesList
             summary="variation_location,linkedGeneIds,variant_type,collapsed_allele,collapsed_minor_allele_frequency,most_severe_impact_snpeff,most_severe_impact_product_call,distinct_strain_count"
             sorting="chromosome_order_num asc,location asc"/>

      <attributesList includeProjects="UniDB,EuPathDB"
             summary="organism,variation_location,linkedGeneIds,variant_type,collapsed_allele,collapsed_minor_allele_frequency,most_severe_impact_snpeff,most_severe_impact_product_call,distinct_strain_count"
             sorting="organism asc,chromosome_order_num asc,location asc"/>
```

- [x] **Step 3: Build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: green build. A failure naming an attribute in `summary` means it is misspelled
or not defined — every name in `attributesList` must exist.

- [x] **Step 4: Verify the overview renders on the MIXED locus**

Load `https://jbrestel.plasmodb.org/plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_12`

Expected: a two-panel overview; the right panel shows **both** a SNP Alleles block
(`A`, minor `C (0.0598)`) and an Indel Alleles block (`A`, minor `AC (0.0085)`).

- [x] **Step 5: Check the logs are clean**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark overview
# reload the record page in the browser, let it settle
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since overview --quiet
```

Expected: error logs reported as `silent:`. An unresolved `$$attribute$$` shows up here
rather than on the page.

- [x] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationRecords.xml
git commit -m "Add variation record overview and default summary columns

Overview shows both allele sections so a MIXED locus reads honestly.
Summary columns use the collapsed allele and MAF, since results pages
cannot render tables."
```

---

## Task 10: TranscriptProducts table

**Files:**
- **Create:** `Model/lib/wdk/model/records/variationTableQueries.xml` (does not exist yet — an
  empty `querySet` is invalid, so the file arrives with this first query)
- Modify: `Model/lib/wdk/apiCommonModel.xml` (add its import)
- Modify: `Model/lib/wdk/model/records/variationRecords.xml`

- [x] **Step 1: Assert the expected rows in psql**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select t.gene_source_id, t.transcript_source_id, t.strand,
       p.pos_in_cds, p.pos_in_protein, p.codon, p.pos_in_codon, p.product,
       p.matches_ref_codon, p.matches_ref_product, p.strain_count, p.hgvs_p
from apidb.variationtranscriptproduct p
join apidbtuning.transcriptattributes t on t.na_feature_id = p.na_feature_id
where p.sequence_source_id = 'Pf3D7_01_v3' and p.location = 29514
order by p.codon"
```

Expected: **5 rows**, all gene `PF3D7_0100100`, codons `GCG`, `GTA`, `GTC`, `GTG`, `GTT`;
the `GCG` row has product `A` with `matches_ref_product` `0`, the rest product `V` with
`1`.

- [x] **Step 2: Create `variationTableQueries.xml` with this query**

Full file. The stub comment matters — this file also reads the developer-schema table.

```xml
<wdkModel>

  <!-- TEMPORARY STUB: reads jbrestel.VariationAttributes instead of
       ApidbTuning.VariationAttributes until the central tuning job builds the real
       table. Flip back per Task 14 before merging. -->

  <querySet name="VariationTables" queryType="table" isCacheable="false"
            includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

    <defaultTestParamValues includeProjects="PlasmoDB,UniDB">
      <paramValue name="source_id">Variant_Pf3D7_01_v3_100057</paramValue>
      <paramValue name="project_id">PlasmoDB</paramValue>
    </defaultTestParamValues>

    <defaultTestParamValues includeProjects="TriTrypDB">
      <paramValue name="source_id">Variant_11L3_v3_26886</paramValue>
      <paramValue name="project_id">TriTrypDB</paramValue>
    </defaultTestParamValues>

    <defaultTestParamValues includeProjects="FungiDB">
      <paramValue name="source_id">Variant_Chr1_A_fumigatus_Af293_1000005</paramValue>
      <paramValue name="project_id">FungiDB</paramValue>
    </defaultTestParamValues>

    <sqlQuery name="TranscriptProducts">
      <column name="source_id"/>
      <column name="project_id"/>
      <column name="gene_source_id"/>
      <column name="transcript_source_id"/>
      <column name="gene_product"/>
      <column name="strand"/>
      <column name="pos_in_cds"/>
      <column name="pos_in_protein"/>
      <column name="codon"/>
      <column name="pos_in_codon"/>
      <column name="product"/>
      <column name="matches_ref_codon"/>
      <column name="matches_ref_product"/>
      <column name="strain_count"/>
      <column name="hgvs_p"/>
      <sql>
        <![CDATA[
          SELECT va.source_id, va.project_id,
                 t.gene_source_id, t.transcript_source_id, t.gene_product, t.strand,
                 p.pos_in_cds, p.pos_in_protein, p.codon, p.pos_in_codon, p.product,
                 CASE p.matches_ref_codon   WHEN 1 THEN 'yes' ELSE 'no' END AS matches_ref_codon,
                 CASE p.matches_ref_product WHEN 1 THEN 'yes' ELSE 'no' END AS matches_ref_product,
                 p.strain_count, p.hgvs_p
          FROM apidb.VariationTranscriptProduct p,
               jbrestel.VariationAttributes va,
               ApidbTuning.TranscriptAttributes t
          WHERE va.sequence_source_id = p.sequence_source_id
            AND va.location          = p.location
            AND t.na_feature_id      = p.na_feature_id
        ]]>
      </sql>
    </sqlQuery>

  </querySet>
</wdkModel>
```

- [x] **Step 2a: Add its import to `apiCommonModel.xml`**

Between the two existing variation imports, so query sets precede the record class:

```xml
  <import file="model/records/variationAttributeQueries.xml"/>
  <import file="model/records/variationTableQueries.xml"/>
  <import file="model/records/variationRecords.xml"/>
```

Then re-run the ACTIVE check from Task 4 Step 4, now expecting all three `ACTIVE`.

- [x] **Step 3: Add the table to `variationRecords.xml`**

Insert immediately before the closing `</recordClass>`:

```xml
      <!-- Strand lives here rather than as a record attribute: a locus can overlap more
           than one gene, so strand is only unambiguous per transcript. -->
      <table name="TranscriptProducts" displayName="Variant Products by Transcript"
             queryRef="VariationTables.TranscriptProducts">
        <columnAttribute name="gene_source_id" displayName="Gene ID" internal="true" inReportMaker="true"/>
        <linkAttribute name="linkedGeneId" displayName="Gene ID" inReportMaker="false">
          <displayText><![CDATA[ $$gene_source_id$$ ]]></displayText>
          <url><![CDATA[ @WEBAPP_BASE_URL@/record/gene/$$gene_source_id$$ ]]></url>
        </linkAttribute>
        <columnAttribute name="transcript_source_id" displayName="Transcript ID" internal="true" inReportMaker="true"/>
        <linkAttribute name="linkedTranscriptId" displayName="Transcript ID" inReportMaker="false">
          <displayText><![CDATA[ $$transcript_source_id$$ ]]></displayText>
          <url><![CDATA[ @WEBAPP_BASE_URL@/record/gene/$$gene_source_id$$#category:transcripts ]]></url>
        </linkAttribute>
        <columnAttribute name="gene_product"        displayName="Gene Product"/>
        <columnAttribute name="strand"              displayName="Gene Strand" align="center"/>
        <columnAttribute name="pos_in_cds"          displayName="Position in CDS" align="center"/>
        <columnAttribute name="pos_in_protein"      displayName="Position in Protein" align="center"/>
        <columnAttribute name="codon"               displayName="Codon" align="center"/>
        <columnAttribute name="pos_in_codon"        displayName="Position in Codon" align="center"/>
        <columnAttribute name="product"             displayName="Amino Acid" align="center"/>
        <columnAttribute name="matches_ref_codon"   displayName="Matches Reference Codon" align="center"/>
        <columnAttribute name="matches_ref_product" displayName="Matches Reference Product" align="center"/>
        <columnAttribute name="strain_count"        displayName="Strain Count" align="center"
                         help="Number of strains observed with this codon."/>
        <columnAttribute name="hgvs_p"              displayName="HGVS (protein)"/>
      </table>
```

- [x] **Step 4: Build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: green build.

- [x] **Step 5: Verify the assembled SQL, then the page**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  wdkQuery -model PlasmoDB -query VariationTables.TranscriptProducts -showQuery"'
```

Expected: the three-way join, unchanged.

Then load
`https://jbrestel.plasmodb.org/plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_29514` and
confirm the table shows the **5 codon rows** from Step 1, with the `GCG`/`A` row marked
`no` for Matches Reference Product.

- [x] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationTableQueries.xml \
        Model/lib/wdk/model/records/variationRecords.xml \
        Model/lib/wdk/apiCommonModel.xml
git commit -m "Add variation TranscriptProducts record table

One row per transcript and observed codon. This is where gene strand
lives, since strand is only unambiguous per transcript once a locus can
overlap two genes."
```

---

## Task 11: PredictedEffects table

**Files:**
- Modify: `Model/lib/wdk/model/records/variationTableQueries.xml`
- Modify: `Model/lib/wdk/model/records/variationRecords.xml`

- [x] **Step 1: Assert both callers appear, including an intergenic locus**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select allele, na_feature_id, impact, effect, hgvs_c, source
from apidb.variationeffect
where sequence_source_id='Pf3D7_01_v3' and location in (12, 29514)
order by location, source, allele"
```

Expected: for 12, two `snpeff` rows with **null** `na_feature_id` and effect
`intergenic_region`; for 29514, one `snpeff` and one `product_call` row, both
`MODERATE`/`missense_variant`/`c.5T>C`. The null `na_feature_id` is why the join must be
a LEFT join.

- [x] **Step 2: Add the query to `variationTableQueries.xml`**

```xml
    <sqlQuery name="PredictedEffects">
      <column name="source_id"/>
      <column name="project_id"/>
      <column name="allele"/>
      <column name="gene_source_id"/>
      <column name="transcript_source_id"/>
      <column name="impact"/>
      <column name="effect"/>
      <column name="hgvs_c"/>
      <column name="source"/>
      <sql>
        <![CDATA[
          SELECT va.source_id, va.project_id,
                 e.allele,
                 t.gene_source_id, t.transcript_source_id,
                 e.impact, e.effect, e.hgvs_c, e.source
          FROM apidb.VariationEffect e
          JOIN jbrestel.VariationAttributes va
            ON va.sequence_source_id = e.sequence_source_id
           AND va.location          = e.location
          LEFT JOIN ApidbTuning.TranscriptAttributes t
            ON t.na_feature_id = e.na_feature_id
        ]]>
      </sql>
    </sqlQuery>
```

The LEFT join is required: `na_feature_id` is null for intergenic calls, and an inner
join would silently drop every intergenic effect row.

- [x] **Step 3: Add the table to `variationRecords.xml`**

Insert before the closing `</recordClass>`:

```xml
      <!-- One table with a visible Source column rather than two tables: provenance
           travels with every row, and the 19% disagreement between callers stays
           legible instead of requiring the user to read two tables and diff them. -->
      <table name="PredictedEffects" displayName="Predicted Effects"
             queryRef="VariationTables.PredictedEffects">
        <columnAttribute name="allele" displayName="Allele" align="center"/>
        <columnAttribute name="gene_source_id" displayName="Gene ID" internal="true" inReportMaker="true"/>
        <linkAttribute name="linkedGeneId" displayName="Gene ID" inReportMaker="false">
          <displayText><![CDATA[ $$gene_source_id$$ ]]></displayText>
          <url><![CDATA[ @WEBAPP_BASE_URL@/record/gene/$$gene_source_id$$ ]]></url>
        </linkAttribute>
        <columnAttribute name="transcript_source_id" displayName="Transcript ID" inReportMaker="true"/>
        <columnAttribute name="impact" displayName="Impact" align="center"
                         help="SnpEff impact class: HIGH, MODERATE, LOW, or MODIFIER."/>
        <columnAttribute name="effect" displayName="Effect"/>
        <columnAttribute name="hgvs_c" displayName="HGVS (coding)"/>
        <columnAttribute name="source" displayName="Source" align="center"
                         help="Which caller produced this row. 'snpeff' annotates each variant
                               in isolation. 'product_call' is the EuPathDB strain-aware call,
                               which additionally knows when a variant sits downstream of a
                               frameshift and reports 'downstream_frameshift'. The two callers
                               disagree at some loci; both are shown rather than one being
                               chosen, because the disagreement is informative."/>
      </table>
```

- [x] **Step 4: Build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: green build.

- [x] **Step 5: Verify both callers and the intergenic case render**

- `Variant_Pf3D7_01_v3_29514` → 2 rows, Source `snpeff` and `product_call`, both
  `MODERATE` / `missense_variant`.
- `Variant_Pf3D7_01_v3_12` → 2 `snpeff` rows, effect `intergenic_region`, Gene ID
  **empty**. If this table is empty, the LEFT join was written as an inner join.

- [x] **Step 6: Find and verify a disagreement locus — the real acceptance test**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
with p as (select * from apidb.variationeffect where source='product_call'),
     s as (select * from apidb.variationeffect where source='snpeff')
select va.source_id, p.effect as product_call_effect, s.effect as snpeff_effect
from p join s using (sequence_source_id, location, allele, na_feature_id)
join jbrestel.variationattributes va
  on va.sequence_source_id = p.sequence_source_id and va.location = p.location
where p.effect <> s.effect and p.effect = 'downstream_frameshift'
limit 3"
```

Load one of those records and confirm the table shows **both** rows with different
`Effect` values side by side. This is the behaviour the whole two-caller design exists to
produce.

- [x] **Step 7: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationTableQueries.xml \
        Model/lib/wdk/model/records/variationRecords.xml
git commit -m "Add variation PredictedEffects record table

One table with a visible Source column, not two tables, so caller
provenance travels with every row and disagreements stay legible.

LEFT joins TranscriptAttributes because na_feature_id is null for
intergenic calls; an inner join would drop them silently."
```

---

## Task 12: Category ontology placement

**Files:**
- Modify: `Model/lib/wdk/ontology/individuals.txt`

**Critical:** this is a categorization change, so it needs `wb ontology`, **not**
`wb model`. `wb model` does not regenerate the category OWL, and skipping `wb ontology`
leaves every new attribute uncategorized with **no error anywhere**.

- [x] **Step 1: Understand the file format**

Tab-separated, no quoting. Columns, in order:

```
individualIri  parentIri  parentLabel  recordClassName  targetType  name
displayName  shortDisplayName  description  geneOrTranscript  displayOrder
scope  scope  scope
```

Trailing empty columns are still tab-delimited. Study lines 684-692 (the existing
`SnpRecordClasses.SnpRecordClass` attribute entries) before editing — match their exact
tab count.

- [x] **Step 2: Add three new category nodes**

Add near the other category-node definitions at the top of the file (compare
`GenomicSequencePropertiesCategory` on line 3). These are the parents for the allele and
statistics groups:

```
VariationSnpAlleleCategory			http://edamontology.org/topic_2885	category	VariationSnpAlleleCategory	SNP Alleles					1			
VariationIndelAlleleCategory			http://edamontology.org/topic_2885	category	VariationIndelAlleleCategory	Indel Alleles					2			
VariationStrainStatsCategory			http://edamontology.org/topic_2885	category	VariationStrainStatsCategory	Strain Statistics					3			
```

- [x] **Step 3: Add attribute and table entries**

Add one line per attribute and table. The parent assignments follow spec §8:

| group | parent |
|---|---|
| identity & location | `GenomicSequenceLocationCategory` |
| classification | `http://edamontology.org/topic_2885` |
| SNP alleles | `VariationSnpAlleleCategory` |
| Indel alleles | `VariationIndelAlleleCategory` |
| strain / call stats | `VariationStrainStatsCategory` |
| gene linkage, effect rollups, collapsed, both tables | `http://edamontology.org/topic_0199` |

Hand-typing ~50 tab-delimited lines with 14 columns each is how tab-count bugs get made.
Generate them instead. Write this script to
`/tmp/claude-1000/-home-jbrestel-workspaces-agentic-veupath-dev/gen-variation-ontology.py`
— it names every attribute explicitly, so nothing is left to inference:

```python
#!/usr/bin/env python3
"""Emit individuals.txt lines for the variation record. 14 tab-separated columns."""

RC = "VariationRecordClasses.VariationRecordClass"

LOC   = ("GenomicSequenceLocationCategory", "GenomicSequenceLocationCategory")
POLY  = ("http://edamontology.org/topic_2885", "DNA Polymorphism")
GENV  = ("http://edamontology.org/topic_0199", "Genetic Variation")
SNPA  = ("VariationSnpAlleleCategory", "SNP Alleles")
INDA  = ("VariationIndelAlleleCategory", "Indel Alleles")
STATS = ("VariationStrainStatsCategory", "Strain Statistics")

FULL = ["results", "record", "download"]
REC  = ["", "record", "download"]
INT  = ["", "record-internal", ""]

# (parent, targetType, name, scopes)
ROWS = [
    # identity & location
    (LOC, "attribute", "variation_location",   FULL),
    (LOC, "attribute", "sequence_source_id",   FULL),
    (LOC, "attribute", "location",             FULL),
    (LOC, "attribute", "location_text",        INT),
    (LOC, "attribute", "chromosome_order_num", INT),
    (LOC, "attribute", "organism",             FULL),
    (LOC, "attribute", "organism_text",        INT),
    (LOC, "attribute", "formatted_organism",   INT),
    (LOC, "attribute", "ncbi_tax_id",          REC),
    (LOC, "attribute", "dataset",              FULL),
    # classification
    (POLY, "attribute", "variant_type",     FULL),
    (POLY, "attribute", "is_coding",        FULL),
    (POLY, "attribute", "reference_strain", FULL),
    # record overview
    (POLY, "attribute", "record_overview", REC),
]

for prefix, parent in (("snp", SNPA), ("indel", INDA)):
    for suffix in ["ref_allele", "major_allele", "major_allele_frequency",
                   "major_allele_strain_count", "minor_allele",
                   "minor_allele_frequency", "minor_allele_strain_count",
                   "major_genomic_hgvs", "minor_genomic_hgvs"]:
        ROWS.append((parent, "attribute", f"{prefix}_{suffix}", FULL))
    for suffix in ["major_allele_and_freq", "minor_allele_and_freq"]:
        ROWS.append((parent, "attribute", f"{prefix}_{suffix}", REC))
ROWS.append((INDA, "attribute", "indel_frame_effect", FULL))

for name in ["distinct_strain_count", "called_strain_count", "no_call_strain_count",
             "call_rate", "total_ploidy_count", "het_strain_count",
             "ref_allele_frequency"]:
    ROWS.append((STATS, "attribute", name, FULL))

for name in ["gene_ids", "linkedGeneIds", "most_severe_impact_snpeff",
             "most_severe_impact_product_call", "effect_summary_snpeff",
             "effect_summary_product_call", "collapsed_allele",
             "collapsed_minor_allele_frequency"]:
    ROWS.append((GENV, "attribute", name, FULL))
ROWS.append((GENV, "attribute", "gene_count", INT))

for name in ["TranscriptProducts", "PredictedEffects"]:
    ROWS.append((GENV, "table", name, REC))

for (parent_iri, parent_label), target, name, scopes in ROWS:
    cols = [f"{RC}.{name}", parent_iri, parent_label, RC, target, name,
            "", "", "", "", ""] + scopes
    assert len(cols) == 14, (name, len(cols))
    print("\t".join(cols))
```

Run it and append the output:

```bash
python3 /tmp/claude-1000/-home-jbrestel-workspaces-agentic-veupath-dev/gen-variation-ontology.py \
  >> ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/ontology/individuals.txt
```

Then confirm the count:

```bash
grep -c '^VariationRecordClasses' ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/ontology/individuals.txt
```

Expected: `55`. (Verified by running the script — it emits 55 lines, every one with
exactly 14 tab-separated columns, enforced by the `assert` in the loop.)

The three category-node lines from Step 2 are added by hand, not by this script — they
have a different shape (no record class, `category` target type).

- [x] **Step 4: Verify tab structure is consistent**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && \
  awk -F'\t' '/^VariationRecordClasses/ {print NF}' Model/lib/wdk/ontology/individuals.txt | sort -u
```

Expected: a single value, matching what existing `SnpRecordClasses` lines produce:

```bash
awk -F'\t' '/^SnpRecordClasses/ {print NF}' Model/lib/wdk/ontology/individuals.txt | sort -u
```

If the two differ, the tab count is wrong and the OWL build will fail or misplace nodes.

- [x] **Step 5: Build the ontology — do NOT also run `wb model`**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb ontology
```

Expected: `individuals.owl` → `categories_merged.owl` regenerated, model rebuilt, webapp
reloaded. A failure mentioning an unresolvable IRI means a parent category name is
misspelled.

- [x] **Step 6: Verify placement in the assembled tree**

From an authenticated app page:

```js
const o = await (await fetch('/plasmo.jbrestel/service/ontologies/Categories')).json();
const hits = [];
(function walk(n, parent) {
  const p = n.properties || {};
  if ((p.name || [])[0]?.startsWith?.('snp_minor_allele') ||
      (p.name || [])[0] === 'PredictedEffects' ||
      (p.name || [])[0] === 'distinct_strain_count')
    hits.push({ name: p.name, parent: parent?.properties?.['EuPathDB alternative term'] });
  (n.children || []).forEach(c => walk(c, n));
})(o.tree, null);
hits
```

Expected: `snp_minor_allele` under a parent displaying "SNP Alleles",
`distinct_strain_count` under "Strain Statistics", `PredictedEffects` under the Genetic
Variation node.

**Caveat:** `/plasmo.jbrestel/service/ontologies/Categories` is **not** project-filtered. For
"does this site actually have the item", trust
`/plasmo.jbrestel/service/record-types/variation` instead.

- [x] **Step 7: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "Categorize variation record attributes and tables

Adds SNP Alleles, Indel Alleles, and Strain Statistics category nodes so
the two allele classes read as distinct sections on the record page.

Requires wb ontology; wb model alone does not regenerate the OWL and
would leave every attribute uncategorized with no error."
```

---

## Task 13: Final end-to-end verification

**Files:** none

- [x] **Step 1: Confirm registration is complete**

From an authenticated app page:

```js
const rt = await (await fetch('/plasmo.jbrestel/service/record-types/variation')).json();
({ attributes: rt.attributes.length, tables: rt.tables.map(t => t.name) })
```

Expected: `tables` = `["TranscriptProducts", "PredictedEffects"]`, and `attributes`
covering everything from Tasks 4-9.

- [x] **Step 1a: Perform the visual checks deferred from Tasks 5-11**

These could not run earlier: record pages render from the category ontology, which only
exists once Task 12 has run. Do them now, for real, rather than assuming earlier tasks
covered them.

For each of the three variant-type records below, load the page and confirm with the DOM:

```js
const ov = document.querySelector('.eupathdb-RecordOverview');
({ overviewPresent: !!ov,
   overviewText: ov ? ov.innerText.replace(/\n{2,}/g,'\n') : null,
   sections: [...document.querySelectorAll('h2,h3,h4')].map(e => e.innerText.trim()).filter(Boolean),
   bodyLen: document.body.innerText.length })
```

Required:
- `overviewPresent` must be `true`. If it is `false`, the `record_overview` attribute has no
  ontology entry with a `record` scope — check Task 12's generator emitted it.
- `Variant_Pf3D7_01_v3_29514` (SNV): SNP allele values shown, Indel blocks empty
- `Variant_Pf3D7_01_v3_18` (INDEL): Indel values shown, SNP blocks empty
- `Variant_Pf3D7_01_v3_12` (MIXED): **BOTH** blocks populated — the acceptance test for the
  whole two-section design
- No literal unsubstituted `$$name$$` text on any page. Detect it without tripping tool
  content filters by testing for the delimiter indirectly:
  `document.body.innerText.split(String.fromCharCode(36,36)).length - 1` — expect `0`.
- Both record tables present and populated (5 codon rows and 2 effect rows for
  `Variant_Pf3D7_01_v3_29514`).

- [x] **Step 2: Walk all three variant types with clean logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark final
```

Load each in the browser, letting each settle:
- `.../plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_29514` — SNV, coding, 5 codon rows, 2 effect rows
- `.../plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_18` — INDEL, indel section only
- `.../plasmo.jbrestel/app/record/variation/Variant_Pf3D7_01_v3_12` — MIXED, **both** allele sections, intergenic effects

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since final --quiet
```

Expected: error logs `silent:`.

- [x] **Step 3: Confirm the cross-project record classes still build**

The record class is declared for 9 projects but only 3 have data. Confirm the other
projects' models still load — a project with no variation data must build cleanly and
simply return no records.

Ask the user which other project instance to build against, if any is available. If none
is, note it explicitly as unverified rather than claiming cross-project correctness.

- [x] **Step 4: Report**

Summarize: what was built, what was verified with what evidence, and anything left
unverified (notably Step 3, and the `linkedGeneIds` plain-text limitation from Task 8).

---

## Task 14: Flip the stub back to the real tuning table

**Do this once the central tuning job has built `apidbtuning.VariationAttributes`.** This
task is what stops a developer-schema reference from reaching a merge.

**Files:**
- Modify: `Model/lib/wdk/model/records/variationAttributeQueries.xml`
- Modify: `Model/lib/wdk/model/records/variationTableQueries.xml`

- [x] **Step 1: Confirm the real table exists and matches the stub**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select (select count(*) from apidbtuning.variationattributes) as real_table,
       (select count(*) from jbrestel.variationattributes)    as stub"
```

Expected: equal counts. If `real_table` errors, the tuning job has not run — stop.

If the counts differ, do not proceed on the assumption that the stub was right: compare a
sample before flipping, since a difference means the tuning-manager path produced
something the verified SQL did not.

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
select * from apidbtuning.variationattributes
except select * from jbrestel.variationattributes limit 5"
```

Expected: no rows.

- [x] **Step 2: Rewrite all six references**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/records
sed -i 's/jbrestel\.VariationAttributes/ApidbTuning.VariationAttributes/g' \
  variationAttributeQueries.xml variationTableQueries.xml
```

- [x] **Step 3: Remove the TEMPORARY STUB comment from both files**

Delete the three-line `<!-- TEMPORARY STUB: ... -->` block added in Task 3 Step 1a from
the top of `variationAttributeQueries.xml` and `variationTableQueries.xml`.

- [x] **Step 4: Verify no stub reference survives**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && \
  grep -rn 'jbrestel' Model/lib/wdk/ Model/lib/xml/ ; echo "exit: $?"
```

Expected: no matches (`exit: 1` from grep). **Any match here is a blocker for merge.**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/records && \
  grep -c 'ApidbTuning\.VariationAttributes' variationAttributeQueries.xml variationTableQueries.xml
```

Expected: `4` and `2`.

- [x] **Step 5: Rebuild and re-verify**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Then re-run the Task 13 Step 2 walk of all three variant-type records, confirming the
pages are unchanged from the stubbed state.

- [x] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variationAttributeQueries.xml \
        Model/lib/wdk/model/records/variationTableQueries.xml
git commit -m "Point the variation record at the real tuning table

Replaces the temporary jbrestel.VariationAttributes stub with
ApidbTuning.VariationAttributes now that the tuning job has built it.
Record pages verified unchanged across SNV, INDEL, and MIXED loci."
```

- [x] **Step 7: Drop the stub table** (optional, and only after Step 5 passes)

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "DROP TABLE jbrestel.VariationAttributes"
```

---

## Deliberately not in this plan

- **Searches / questions** for the variation record — separate spec and plan.
- **Removing the dead `snp` model XML.** `snpRecords.xml` and friends still reference the
  non-existent `apidbtuning.SnpAttributes`; removal has its own blast radius
  (`recordParams.xml`, `spanQuestions.xml`, `SnpsBySpanLogic`).
- **A sanity-test file.** `apiCommonModel-sanity.xml` imports a directory that does not
  exist; the whole sanity model is dead. Do not extend it.
- **Reconciling `downstream_of_frameshift_strain_ids`**, which is in the live table but
  not the checked-in DDL and is 100% null.
- **Per-strain / VCF data** — spec §9.
- **A `webready.variationattributes_p` variant.** 38 of 54 tuning tables are now thin
  copies of `webready.*_p` tables built by a separate pipeline, which appears to be the
  direction of travel. This plan uses in-tuning-manager SQL (the pattern the other 16
  still follow) because it is self-contained and executable now. If the data team wants
  the webready route, only Task 2 changes.
