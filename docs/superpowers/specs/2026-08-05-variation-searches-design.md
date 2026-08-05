# Variation searches — design (scaffolding + `VariationBySourceId`)

**Date:** 2026-08-05
**Status:** approved
**Scope:** The question-side scaffolding for the `variation` record — a `paramSet`, a
`querySet`, a `questionSet`, and their model imports — plus the first and simplest
search, `VariationBySourceId`. The four remaining ported searches are **out of scope**;
see §8.
**Companion spec:** `2026-07-30-variation-record-design.md` (record class, attributes,
tuning table, record-page tables). Section references below prefixed `record §` point
there.
**Implementation target:** `ApiCommonModel` (branch `dnaseq-merge-experiments`)

## 1. Purpose

The `variation` record shipped with attributes and record-page tables but **no way to
search for one**. Today a variation is reachable only by URL or by a record-page link
from elsewhere. This adds the first search, and — more importantly — the three model
files and the import block that every later variation search will extend.

The reference implementation is the deprecated `snp` record's `NgsSnpBySourceId`
(`Model/lib/wdk/model/questions/snpQuestions.xml`,
`questions/queries/snpQueries.xml`, `questions/params/snpParams.xml`).

### 1.1 The reference is dead code

`apiCommonModel.xml` has the entire snp block commented out (`<!-- UNCOMMENT WHEN SNPS
are AVAILABLE`, around lines 405–412). None of the five snp searches is loaded on any
site. Consequences for this work:

- The port is from XML that has not been exercised in this build. "Behaves like the old
  search" is **not verifiable** — there is no running snp search to compare against.
- Verification is therefore against the new search's own assembled SQL and the WDK
  service, never against snp behavior. See §7.
- Do not uncomment the snp block to compare. `snpRecords.xml` and friends reference
  `apidbtuning.SnpAttributes`, which does not exist in this build; the model would fail
  to load.

## 2. Project reach (settled — read this before "fixing" it)

The `paramSet` and `questionSet` both carry the `VariationRecordClasses` list verbatim:

```
AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB
```

Nine projects — **not** all of them. GiardiaDB, TrichDB, HostDB, SchistoDB, and
VectorBase are deliberately absent, inherited from `SnpRecordClasses`.

> **Variation data is expected for all nine in the full database.** On a dev instance
> with a subset appDb only PlasmoDB, TriTrypDB, FungiDB, and UniDB (which spans them)
> have loaded variations, so the search returns nothing on the other five. That is a
> property of the test data, not of the model. Do **not** narrow `includeProjects` to the
> loaded set.

This decision is made once here for the whole search family: each of the four deferred
searches (§8) carries the same nine-project list.

## 3. File layout

Three new files, mirroring the convention every other record in the model follows:

| file | contains |
|---|---|
| `Model/lib/wdk/model/questions/params/variationParams.xml` | `paramSet variationParams` |
| `Model/lib/wdk/model/questions/queries/variationQueries.xml` | `querySet VariationsBy` |
| `Model/lib/wdk/model/questions/variationQuestions.xml` | `questionSet VariationQuestions` |

Two alternatives were considered and rejected. Folding the `paramSet`/`querySet` into
the existing `records/variation*.xml` files puts question machinery in files named for
records, and the deferred searches would force the split later anyway. A single combined
`variationQuestions.xml` holding all three sets is compact but breaks the model-wide
convention and the `apiCommonModel.xml` import grouping.

The querySet is named `VariationsBy` — for the family, not for this one search — so
`VariationsBy.VariationsByLocation` and friends land without a rename.

## 4. `paramSet variationParams`

```xml
<paramSet name="variationParams"
          includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

  <datasetParam name="variation_id"
                recordClassRef="VariationRecordClasses.VariationRecordClass"
                prompt="Variation ID input set">
    <help>Input a comma delimited set of Variation IDs, or upload a file</help>
    <suggest includeProjects="PlasmoDB"  default="Variant_Pf3D7_01_v3_100057"/>
    <suggest includeProjects="TriTrypDB" default="Variant_11L3_v3_26886"/>
    <suggest includeProjects="FungiDB"   default="Variant_Chr1_A_fumigatus_Af293_1000005"/>
    <suggest includeProjects="UniDB"     default="Variant_Pf3D7_01_v3_100057"/>
  </datasetParam>

</paramSet>
```

A `datasetParam` (not a `stringParam`) because it gives the manual-entry box, file
upload, and basket/strategy input sources for free — the same choice
`snpParams.ngs_snp_id` and `popsetParams.popset_id` make.

### 4.1 Missing `<suggest>` defaults are a data gap, not a design gap

The four defaults above are IDs verified present in the current subset appDb; they are
the same values the record's `testParamValues` uses (record §4).

**AmoebaDB, CryptoDB, MicrosporidiaDB, PiroplasmaDB, and ToxoDB owe a `<suggest>`
default once their variation data loads.** They are omitted rather than filled with
invented IDs — the same rule record §4 applied to `testParamValues`. A missing `suggest`
degrades to an empty input box, which is mildly annoying and never wrong.

## 5. `querySet VariationsBy`

```xml
<sqlQuery name="VariationBySourceId" doNotTest="true">
  <paramRef ref="variationParams.variation_id"/>
  <column name="source_id"/>
  <column name="project_id"/>
  <sql>
    <![CDATA[
      SELECT DISTINCT va.source_id, va.project_id
      FROM ApidbTuning.VariationAttributes va, ($$variation_id$$) ds
      WHERE va.source_id = ds.source_id
    ]]>
  </sql>
</sqlQuery>
```

`doNotTest="true"` matches the snp original: a `datasetParam`-backed query has no
sanity-testable parameter value.

**Why `ApidbTuning.VariationAttributes` and not `apidb.VariationFeature`.** The query
must return both primary-key columns, and `project_id` is a derived taxon→project
mapping that by record §3.1's sourcing invariant lives only in the tuning table.
`VariationFeature` has no `project_id`. The invariant decides this — no judgment call,
and the same reasoning will fix the target for every later search that returns a
primary key.

`DISTINCT` is retained from the original. It is strictly redundant here —
`VariationAttributes` is one row per locus with a unique `source_id` (record §5) — but
it costs nothing and survives a future join.

### 5.1 ID tolerance: exact `source_id` only

`source_id` has the form `Variant_<sequence_source_id>_<location>`. The search matches
it exactly. Two richer options were rejected:

- **Accept `<sequence>:<location>` in this search's SQL** — the tolerance would be
  invisible to every other entry point (record URL, strategy import, webservice), i.e. a
  local fix that becomes an inconsistency.
- **Accept it via the alias query** — architecturally the right home (WDK's designed
  mechanism for alternate IDs; every entry point benefits), but there is no evidence
  users hold IDs in any form other than what a prior result page or download gave them.
  YAGNI.

`VariationAttributes.VariationAlias` is currently identity-only
(`source_id → source_id`). **If ID tolerance is ever wanted, extend that alias query —
not this search's SQL.** Recording the decision here so the cheap-and-wrong option
isn't rediscovered.

## 6. `questionSet VariationQuestions`

```xml
<questionSet name="VariationQuestions" displayName="Search for Variations"
             includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

  <question name="VariationBySourceId"
            displayName="Variation ID(s)"
            shortDisplayName="Variation ID(s)"
            queryRef="VariationsBy.VariationBySourceId"
            recordClassRef="VariationRecordClasses.VariationRecordClass"
            noSummaryOnSingleRecord="true">

    <summary>Find variations by ID.</summary>

    <description>
      <![CDATA[
        Find variations by Variation ID. <br><br>
        Either enter the ID list manually, or upload a file that contains the list.
        IDs can be delimited by a comma, a semi colon, or any white spaces.
      ]]>
    </description>

  </question>

</questionSet>
```

**No `attributesList`.** The question inherits the record's default summary columns
(record §6.9: location, gene IDs, variant type, collapsed allele, collapsed MAF, both
impact rollups, strain count). The snp original overrode to a narrow three-column list;
inheriting instead means one place defines what a variation result looks like and every
later search matches it for free. A search that genuinely needs different columns can
still override.

**No `searchCategory`.** That attribute groups searches *within* a set; with one search
there is nothing to group. It arrives with the deferred searches (§8).

`noSummaryOnSingleRecord="true"` sends a one-hit result straight to the record page,
matching both `NgsSnpBySourceId` and `PopsetByPopsetId`.

## 7. Wiring and verification

### 7.1 Model imports

Three lines appended to the existing "Variations" block in
`Model/lib/wdk/apiCommonModel.xml` (currently ending at
`model/records/variationRecords.xml`), in the model's conventional order:

```xml
<import file="model/questions/params/variationParams.xml"/>
<import file="model/questions/queries/variationQueries.xml"/>
<import file="model/questions/variationQuestions.xml"/>
```

### 7.2 Category ontology

One row in `Model/lib/wdk/ontology/individuals.txt`:

| field | value |
|---|---|
| id | `VariationRecordClasses.VariationRecordClass.VariationQuestions.VariationBySourceId` |
| parent IRI | `http://edamontology.org/topic_0199` |
| parent label | `Genetic Variation` |
| record class | `VariationRecordClasses.VariationRecordClass` |
| targetType | `search` |
| name | `VariationQuestions.VariationBySourceId` |
| scopes | `menu`, `webservice` |

Same parent node and same scope pair the Popset ID search uses, and the node the record's
gene-linkage and effect-rollup attributes already sit under (record §8).

> **This is a categorization change, so the build target is `wb ontology`, not
> `wb model`.** `wb model` alone leaves the OWL stale and the search uncategorized with
> no error anywhere. `wb ontology` is a superset of `wb model`; run it alone.

### 7.3 Verification

There are no unit tests for model XML, and the sanity model is dead
(`apiCommonModel-sanity.xml` imports a directory that does not exist — do not extend
it). Verification is build, service, and browser:

1. `bin/veup-build.sh plasmodb wb ontology` completes without error.
2. `wdkQuery -model PlasmoDB -query VariationsBy.VariationBySourceId -showQuery
   -showParams` renders the SQL and reports the single `variation_id` param.
3. `/service/record-types/variation` → `.searches` contains `VariationBySourceId`. This
   is the project-filtered source of truth for "does this site have the search."
4. `/service/ontologies/Categories` → the node sits under the "Genetic Variation"
   display term. (Not project-filtered — use it for placement only, never for presence.)
5. Browser, single ID (the PlasmoDB suggest default): lands directly on the record page,
   no intervening result page.
6. Browser, three real IDs plus one bogus ID: three rows, the record's default summary
   columns, no error — an unmatched ID is silently absent, which is the `datasetParam`
   norm.
7. Browser, a project with no loaded variation data (any of the five named in §4.1): the
   form renders and the search returns 0 rows cleanly. Per §2 this is a passing case, not
   a defect. Note this one cannot be checked from the plasmodb instance — it needs a
   site whose project lacks the data, so treat it as a check to run when one of those
   sites is next stood up rather than a blocker here.
8. `bin/veup-logs.sh plasmodb mark <label>` / `since <label>` around steps 5–7: error
   logs stay silent.

Both fetches in 3 and 4 must come from an already-authenticated app page (Claude Chrome
`javascript_tool`); a raw `curl` redirects to autologin.

## 8. Out of scope

### 8.1 The four remaining snp searches

`NgsSnpsByIsolateGroup`, `NgsSnpsByLocation`, `NgsSnpsByGeneIds`,
`NgsSnpsByTwoIsolateGroups` (plus the PlasmoDB-only `NgsSnpsByTwoIsolateGroupsWiz`).

These are not four more of the same thing. `NgsSnpBySourceId` is the only `sqlQuery`
among the five; every other one is a `processQuery` against
`org.apidb.apicomplexa.wsfplugin.highspeedsnpsearch.FindPolymorphismsPlugin`, driven by
per-isolate strain metadata (`snpParams.ngsSnp_strain_meta`) and HSSS index files. That
per-strain layer is exactly what record §9 defers to the VCF + EDA seam — it does not
exist for the variation pipeline today.

Porting them needs its own spec, and that spec's first question is what replaces HSSS,
not what the XML looks like. Three of them (`ByLocation`, `ByGeneIds`, and the
isolate-group pair) may split further: location and gene-ID searches are answerable from
`apidb.VariationFeature` / `apidb.VariationEffect` / `VariationAttributes` without any
per-strain data, whereas the isolate-group comparisons are inherently per-strain.

### 8.2 Also out of scope

- **ID tolerance / alias-query changes** — §5.1.
- **Deleting the dead `snp` model XML.** Unchanged from record §10: removal has its own
  blast radius (`recordParams.xml`, `spanQuestions.xml`, `SnpsBySpanLogic`).
- **`<suggest>` defaults for the five projects awaiting data** — §4.1.
- **A sanity-test file** — §7.3.
