# Genomic Colocation for the Short Variant record

**Date:** 2026-08-15
**Repos changed:** `ApiCommonModel`, `ApiCommonWebService`
**Branch:** `feat/variant-colocation` (same name in both repos)
**Instance for QA:** plasmodb (`~/workspaces/plasmodb`), appDb `genomicsdb_071n`

**Supersedes** `agentic-veupath-dev/docs/superpowers/local/specs/2026-08-13-variant-genomic-colocation-design.md`.
That draft proposed a model-declared span-source contract; §3 explains why this design
rejects it, and §2 corrects two factual claims it rested on.

## 1. Goal

Make the **Genomic Colocation** combine step work for the Short Variant record, in both
directions (genes → variants, variants → genes), and repair the Oracle→Postgres damage
that currently limits colocation to genes ↔ genes.

There is no separate "record transform" to build. Gene ↔ Variant conversion *is*
colocation: span logic is symmetric, so one working `VariantsBySpanLogic` plus Variant
being an allowed input yields both directions. A direct annotation-based transform
(`ApidbTuning.VariationAttributes.gene_ids`, or `apidb.VariationTranscriptProduct`) is
deliberately **not** built — `VariationTranscriptProduct` is coding-region only, so it
would silently miss intronic and intergenic variants, while positional overlap catches
everything.

## 2. What is actually broken

Every row below was measured against `genomicsdb_071n`, not inferred.

| # | Fact | Evidence |
|---|---|---|
| 1 | Variants have no coordinates in the table the plugin reads | `select count(*) from apidb.featurelocation where feature_source_id like 'Variant_%'` → **0** |
| 2 | Variant is not an allowed colocation **input** | `span_a`/`span_b` list only Transcript + DynSpan (`spanParams.xml:167,253`) |
| 3 | Variant is not an allowed colocation **output** | no `VariantsBySpanLogic` in `spanQuestions.xml` |
| 4 | `rownum` breaks every input routed through the shared builder | `SpanCompositionPlugin.java:494`; PG18: `ERROR: column "rownum" does not exist` |
| 5 | `DECODE` breaks DynSpan specifically | `:436`; PG18: `ERROR: function decode(...) does not exist` |

(1) is the reason a code change is needed at all. (4) and (5) are why colocation is
genes ↔ genes today: genes route through `getTranscriptSpanSql`, which touches neither.

### Two claims from the superseded draft that do not hold

**"The Oracle syntax is a design driver."** It is two lines. Of the four constructs
suspected, only `rownum` and `DECODE` actually fail on PostgreSQL 18.4 — `regexp_substr`
with Oracle's 4-argument signature works, and `AS begin` / `AS end` parse unquoted. The
draft's central argument, that a declared-query contract lets you *avoid inheriting* the
Oracle problem, buys almost nothing.

**"`is_top_level = 1` must be preserved on the default `FeatureLocation` path."** The
`is_top_level` measurement is right (2,503 rows at `0`, all human PAR genes with duplicate
chrX/chrY placements, which would double-count without the filter) but attached to the
wrong path. The bare-`FeatureLocation` fallback is **unreachable**: `span_a`/`span_b`
admit only Transcript and DynSpan, so nothing falls through to it. The PAR risk lives on
the **Transcript** source, which is itself a `FeatureLocation` query.

### No UI change

`ApiBinaryOperations.tsx:45` matches colocation searches by convention
(`searchName.endsWith('BySpanLogic')`). Adding the question is sufficient; `web-monorepo`
is untouched.

## 3. Design

### 3.1 The two dispatches, disentangled

The plugin makes two independent decisions that are easy to conflate:

- **Which plugin class runs** keys off the **output** record type, via the question's
  `queryRef`. `GenesBySpanLogic` → `SpanId.TranscriptsBySpanLogic` →
  `TranscriptSpanCompositionPlugin`; everything else → `SpanId.RecordsBySpanLogic` →
  `SpanCompositionPlugin`. The subclass is 31 lines and overrides only `makeRow` and
  `getColumns`, to carry an extra `gene_source_id` output column. It does not affect
  coordinate lookup.
- **Where coordinates come from** keys off the **input** record type. `getSpanSql` runs
  once per side, each side dispatching on its own record class. This is the `if/else` at
  `:429`.

So genes → variants runs `SpanCompositionPlugin`, with the gene side resolved as a
Transcript input and the variant side as a Variant input. Variants → genes is the same
machinery with `TranscriptSpanCompositionPlugin` producing the output rows.

### 3.2 `SpanSource`

One interface, naming a concept that already exists twice without a name (three times once
Variant is added):

```java
private interface SpanSource {
  String createTableSql(String tableName, String[] region, String cacheSql, WdkModel model);
  default boolean isStrandless() { return false; }
}
```

Registered in a `Map<String, SpanSource>` keyed by record-class full name. `getSpanSql`
becomes a lookup plus a delegate; the `if/else` at `:429` and the
`rcName.equals("TranscriptRecordClasses…")` ternary at `:464` both collapse into it.

**An unregistered record class throws**, naming the class. No silent fallback. If
`OrfsBySpanLogic` or `IsolatesBySpanLogic` are ever uncommented they will fail loudly and
immediately, rather than building a plausible query on a join nobody validated for them.

| Input record class | Coordinate source | `is_top_level` filter | Strandless |
|---|---|---|---|
| `TranscriptRecordClass` | `apidb.FeatureLocation`, joined on `ca.gene_source_id`, `feature_type='GeneFeature'` | **yes — PAR genes** | no |
| `DynSpanRecordClass` | parsed from the step's own cache table | no — one row per record | no |
| `VariantRecordClass` | `ApidbTuning.VariationAttributes` | no — one row per record | **yes** |

The Transcript source joins on `gene_source_id` rather than `source_id`, so a gene result
colocates by the **gene's** extent, and `gene_source_id` survives into the output where
the subclass's extra column needs it. (Transcripts do appear in `apidb.FeatureLocation`
as `feature_type='Transcript'` — `PF3D7_1133400.1` shares coordinates with its gene — so
the generic join would find rows. They would just be the wrong rows for a multi-transcript
gene.)

DynSpan and Variant share one standard-shape builder. Transcript keeps its own.

### 3.3 Why not the model-declared contract

The superseded draft proposed `<propertyList name="spanLocationQuery">` on `<recordClass>`,
making new record types model-only. Rejected because:

- The contract is unvalidated. The declared query *must* return exactly one row per
  record; nothing checks it, and getting it wrong multiplies result rows silently rather
  than failing.
- It does not unify. Transcript cannot use it (it joins on a different cache column) and
  DynSpan cannot (its coordinates derive from the step's own cache table, which no model
  query can name). It would be a third mechanism beside two special cases.
- Its stated payoff — dodging the Oracle constructs — is worth two lines (§2).

`SpanSource` stays typed, unit-testable against the existing JUnit suite in
`WSFPlugin/src/test/java/`, and costs a Java edit plus a WSF redeploy per new record type.
That trade is the right one at three implementations. Revisit if a fifth appears.

## 4. Changes

### 4.1 `ApiCommonWebService` — `SpanCompositionPlugin`

- Introduce `SpanSource` and the registry; convert Transcript and DynSpan to it.
- New `Variant` source over `ApidbTuning.VariationAttributes`: `location AS start_min`,
  `location AS end_max`, `0 AS is_reversed`, `isStrandless() → true`.
  - Use the table's real `project_id` column. The old SNP branch hardcoded
    `wdkModel.getProjectId()`; `VariationAttributes` carries `project_id` per row, which
    is what makes this correct on the UniDB portal.
- `DECODE(x,'r',1,0)` → `CASE WHEN x = 'r' THEN 1 ELSE 0 END` in the DynSpan source.
- **Delete the `rownum` subquery rather than port it.** It filtered all rows to the
  `feature_type` of one arbitrary joined row — a defensive no-op even on Oracle (only
  **95** `feature_source_id`s in 46M `FeatureLocation` rows have more than one distinct
  `feature_type`), and after §3.2 it sits only on paths that are one-row-per-record by
  construction. Porting it to `LIMIT 1` would preserve dead code.
- Drop DynSpan's synthetic `1 AS is_top_level, 'DynamicSpanFeature' AS feature_type`,
  which existed only to satisfy filters that no longer live in the shared builder.
- `Flag.hasSnp` → `Flag.strandless`, set from `isStrandless()`. Same behavior, named after
  the property instead of one record type. It suppresses the strand filter for the whole
  comparison (`:385`), which is required: a point feature has `is_reversed = 0`, so
  "same strand" would otherwise silently return forward-strand genes only.
- **Delete** the `SnpRecordClasses.SnpRecordClass` branch (`:439`). Unreachable — every
  SNP and SNP-chip import is commented out of the assembled model
  (`apiCommonModel.xml:494-501`, `:511-517`), so that record class cannot exist at runtime.

### 4.2 `ApiCommonModel` — inputs

`spanParams.xml`: add `VariantRecordClass` to **both** `span_a` (:167) and `span_b` (:253).
Without this, a variant result cannot be offered as a colocation input and the
variants → genes direction is impossible. The superseded draft omitted this.

### 4.3 `ApiCommonModel` — the question

New `VariantsBySpanLogic` in `spanQuestions.xml`, replacing the commented
`SnpsBySpanLogic` and `SnpsChipsBySpanLogic` blocks:

```xml
<question name="VariantsBySpanLogic"
          displayName="Short Variants By Relative Location"
          shortDisplayName="Variants by Rel Loc"
          queryRef="SpanId.RecordsBySpanLogic"
          recordClassRef="VariantRecordClasses.VariantRecordClass"
          includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">
  <attributesList
      summary="variant_location,gene_ids,variant_type,matched_count,feature_region,matched_regions"
      sorting="chromosome_order_num asc,location asc"/>
  <summary>Get short variants with span logic operation against other results</summary>
  <description><![CDATA[Get short variants with span logic operation against other results]]></description>
  <dynamicAttributes>
    <columnAttribute name="matched_count"   displayName="Match Count" align="center"/>
    <columnAttribute name="feature_region"  displayName="Region"      align="center"/>
    <columnAttribute name="matched_regions" displayName="Matched Regions" truncateTo="4000"/>
  </dynamicAttributes>
</question>
```

- `includeProjects` copied from the `VariantRecordClasses` set, so the search exists
  exactly where the record does.
- Summary columns are the first three of the record's own default (`variantRecords.xml:303`)
  plus the three the plugin produces. `attributesList` must name the dynamic columns
  explicitly or they do not render.
- Sorting mirrors the record's own default (`:304`) rather than `variant_location asc` —
  `variant_location` is a `textAttribute` and is not a safe sort key.
- **No CDS or gene dynamic attributes.** The old SNP question's `linkedGeneId` and
  `position_in_protein` are dropped deliberately.

### 4.4 `ApiCommonModel` — ontology

`Model/lib/wdk/ontology/individuals.txt`: the `SnpsBySpanLogic` entry becomes
`VariantsBySpanLogic` in the same position; the `SnpsChipsBySpanLogic` entry is dropped.
Every `BySpanLogic` entry sits under the `DynSpanRecordClass` parent — a quirk; mirror it
rather than fix it here.

### 4.5 Out of scope

`IsolatesBySpanLogic` and `OrfsBySpanLogic` stay commented out.

## 5. Testing

**Unit** — `WSFPlugin/src/test/java/` already holds live JUnit tests, so each `SpanSource`
gets its generated SQL asserted: Transcript retains `is_top_level = 1` and
`feature_type = 'GeneFeature'`; DynSpan and Variant carry neither; an unregistered record
class throws with the class name in the message. This is the payoff of §3.2 being typed
rather than a model contract.

**SQL** — execute each generated statement read-only against `genomicsdb_071n` before
deploying.

**Build** — `wb full`. Java in `ApiCommonWebService` plus a touched `individuals.txt` means
neither `wb model` nor `wb ontology` alone is sufficient.

**Live QA**, in order:

1. Gene result → colocate → variants.
2. Variant result → colocate → genes.
3. Gene ↔ genomic segment — the DynSpan path, in scope because of the `DECODE` fix, and
   the regression risk of this change.
4. Strand selector on a variant comparison: confirm same-strand and opposite-strand do not
   zero the result (the `strandless` path).
5. Spot-check one hit against `genomicsdb_071n`: the coordinate the plugin used equals the
   variant's `location` in `ApidbTuning.VariationAttributes`.

Branches: `feat/variant-colocation` in both repos, edited **in place** in
`~/workspaces/plasmodb`. A git worktree is not carried by mutagen, so builds would verify
stale code.

## 6. For the reviewer: four Oracle-isms, and one decision that needs a second opinion

§2 claimed the Oracle→Postgres damage was two lines. **That was wrong.** Live QA found two
more, both in code paths shared by *every* colocation regardless of record type. The
corrected picture:

| # | Construct | Where | Scope of breakage | Found by |
|---|---|---|---|---|
| 1 | `rownum` | `getStandardSpanSql` | non-gene inputs | reading the code |
| 2 | `DECODE` | DynSpan branch | genomic segments | reading the code |
| 3 | `regexp_substr` yields **text**, and `getStartStop` does arithmetic on it | DynSpan coordinates | genomic segments | code review |
| 4 | `FROM (table_name) alias` | `composeSql` | **all colocation** | live QA |
| 5 | `getDefaultSchema()` create/drop mismatch | `execute` cleanup | **all colocation** | live QA |

So genomic colocation has been **entirely non-functional since the Postgres migration** —
not "gene ↔ gene only", as this document originally asserted and as the superseded draft
claimed in its §7. Nobody has reported it. Treat any remaining "it worked before" intuition
about this plugin with suspicion.

Note the pattern for reviewers: #1 and #2 were found by reading, #3 by review, and #4 and #5
only by running the thing. Unit tests asserting on generated SQL fragments passed throughout
— they never composed the final join, and never executed anything.

### The decision that needs a second opinion: which schema owns the temp tables

`getSpanSql` issues an **unqualified** `CREATE TABLE spanlogic<n>`. The cleanup previously
dropped via `wdkModel.getAppDb().getDefaultSchema()`. Those two agree on Oracle and diverge
on PostgreSQL:

```java
Oracle.getDefaultSchema(login)     → normalizeSchema(login)     // the login user's schema
PostgreSQL.getDefaultSchema(login) → normalizeSchema("public")  // hardcoded
```

An unqualified `CREATE` follows `search_path`, which on our instances is `"$user"`. So the
tables were created in the login schema and the drop looked in `public`, raising
`table "spanlogic<n>" does not exist` **after** the results had been computed. A working
colocation surfaced to the user as an error, and leaked one table per run — 38 were found
in `genomicsdb_071n`.

**What this change does:** passes `null` as the schema, so `dropTable` emits a bare table
name that resolves exactly the way the `CREATE` did, on either platform.

**The alternatives, and why they were not chosen:**

- *Qualify the `CREATE` with `getDefaultSchema()` instead*, sending the tables to `public`.
  Rejected: since PostgreSQL 15 the `PUBLIC` role no longer holds `CREATE` on `public` by
  default, so this may simply fail with a permission error on some deployments — and it
  puts per-request scratch tables in a shared schema. It was also not testable here without
  writing outside the developer's own schema.
- *Fix `PostgreSQL.getDefaultSchema` in FgpUtil to return the login schema.* Arguably the
  real defect — the two platforms' implementations do not mean the same thing, and callers
  cannot tell. Rejected as out of scope: that method is used across WDK, and `public` may
  well be the intended answer for its other callers. **If the reviewer prefers this, it
  should be its own change with its own audit of call sites.**

**What a reviewer should decide:** whether `null` is the right long-term answer or merely
the safe local one, and whether the FgpUtil asymmetry deserves a follow-up ticket. The
scratch tables are a per-request implementation detail, so "wherever the login can write"
is defensible — but it does mean the plugin no longer states, anywhere, which schema it
writes to. That is the trade being made.

## 7. Risk flagged, not solved

`RecordsBySpanLogic` declares `wsColumn project_id` unconditionally
(`spanQueries.xml:322`), while `VariantRecordClass`'s primary key excludes `project_id` on
UniDB (`variantRecords.xml:34`). `DynSpanRecordClass` has the identical PK shape
(`dynSpanRecord.xml:12`) and shares that query, so this is pre-existing rather than
introduced here — but DynSpan colocation has been broken on Postgres, so nobody has
exercised it. Treat as a QA item on UniDB; do not change the shared query blind.
