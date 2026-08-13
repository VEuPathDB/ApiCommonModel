# `VariationsByIsolateGroup` — design

**Date:** 2026-08-05
**Status:** approved
**Scope:** One search on the `variation` record — `VariationsByIsolateGroup`, an HSSS
`processQuery` over a user-chosen group of samples. Includes the reusable param machinery
every later HSSS variation search needs: the organism vocabulary, the hidden EDA
table-suffix param, and the EDA-driven samples `filterParam`.
**Implementation target:** `ApiCommonModel` (branch `dnaseq-merge-experiments`)
**Prerequisite, already implemented:** `ApiCommonWebService`'s
`2026-08-05-hsss-variation-plumbing-design.md`. This search is its first consumer and the
first thing to exercise it. Section references prefixed `plumbing §` point there;
`record §` points to `2026-07-30-variation-record-design.md`; `searches §` to
`2026-08-05-variation-searches-design.md`.

## 1. Purpose

The `variation` record has one search, `VariationBySourceId` — a plain `sqlQuery` for
people who already have IDs. This adds the first *analytical* search: choose an organism,
choose a group of samples, and get the variant loci that are polymorphic within that group
above chosen frequency thresholds.

It is the simplest of the four HSSS searches being ported from the deprecated `snp` record
(`NgsSnpsByIsolateGroup`), and the other three are variations on it — `ByLocation` adds
sequence/start/end params, `ByGeneIds` adds a gene list, `ByTwoIsolateGroups` compares two
groups. Doing this one first stands up the shared machinery they all need.

The port is not a copy. Three of its four params have to be rebuilt because the tables the
snp originals read no longer exist, and the samples filter moves to a completely different
data source (EDA rather than `apidbTuning.Metadata`).

## 2. The two identities problem (governing constraint)

The single most load-bearing fact in this design:

> **The organism param's internal value must be the taxon name. The EDA study abbreviation
> must travel in a separate param.**

Why. `HighSpeedSnpSearchAbstractPlugin:314-329` resolves the organism param's internal
value by looking it up in `sres.TaxonName.name`, to derive
`apidb.organism.name_for_filenames` — `Pfalciparum3D7`, `TbruceiTREU927`,
`AfumigatusAf293` — which is the directory segment in the HSSS path
(`:209`, and `:212` throws if the directory is absent). Feed it anything else and it fails
with `Unable to find file organism name for param '<x>'`.

Meanwhile the samples `filterParam` reads EDA's per-study tables, whose **names embed the
study and entity abbreviations**: `eda.attributevalue_s3be28bbe14_sample`. SQL cannot
parameterize a table name from a subquery result, so the abbreviation has to arrive as a
param value that gets textually interpolated.

Two consumers, two different identities for the same organism, one dropdown. Resolved with
a **hidden dependent param** (§4.2) — standard WDK machinery, and it keeps each consumer
reading the identity it actually needs. Two alternatives were rejected:

- **Derive the abbreviation inside each EDA query** from `$$organismSinglePick$$`. This
  cannot work: the table name would have to come from a value the query itself computes.
  Recorded because it is the obvious first idea.
- **Change the plugin's Java to accept an abbreviation.** Rejected — it is shared by six
  plugins, and bending shared code to avoid one param is the tail wagging the dog.

## 3. How the study abbreviation is obtained (settled)

`eda.study.internal_abbrev` is a 10-hex-character SHA-1 digest with an `s` prefix, and it
**is reproducible in SQL**: `sha1(<orgAbbrev> || '_dnaSeqVariations')[1:10]` matches
`internal_abbrev` for 3 of 3 organisms (verified 2026-08-05; Oracle's
`dbms_crypto.hash(...,3)` is SHA-1, and the Postgres equivalent needs
`public.digest(x,'sha1')`, schema-qualified because pgcrypto lives in `public` which is not
on the default search path).

**We do not use it.** The abbreviation is *looked up*, not recomputed:

> Recomputing hardcodes the hashing convention — algorithm, truncation length, the `s`
> prefix, the `_dnaSeqVariations` suffix — into model XML forever, and fails **invisibly**:
> a changed convention yields a well-formed abbreviation for a study that does not exist,
> surfacing much later as `relation "eda.attributevalue_s<hash>_sample" does not exist`
> from inside a filterParam's metadata query. A lookup yields **zero rows**, so the
> organism dropdown is visibly empty instead.

This also matches existing practice: `apiTuningManager.xml:3846-3863` builds these same
table names and obtains both abbreviations by querying `eda.study` and
`eda.entitytypegraph` through `studyexternaldatabaserelease`, guarding with
`to_regclass(...) IS NULL → CONTINUE`. No hash anywhere.

Note `eda.entitytypegraph` supplies the **entity** abbreviation too (`sample` for all three
studies), so even that is a lookup rather than an assumption. `eda.entitytype` is empty in
this database, which is probably why assuming `sample` looks necessary.

## 4. Params

### 4.1 Organism — `organismParams.organismSinglePick`, new vocabulary

The param is reused unchanged; only its `queryRef` is new, because the snp original's
vocabulary reads `apidbtuning.snpstrains`, **which does not exist in this build** (like
`SnpAttributes`). So this is a rewrite.

New `organismVQ.withVariationsTree`, returning `internal` / `term` / `parentTerm`:

```sql
WITH FilterQuery AS (
  SELECT DISTINCT tn.name AS organism
  FROM apidb.datasource ds
  JOIN apidb.organism o    ON o.taxon_id = ds.taxon_id
  JOIN sres.taxonname tn   ON tn.taxon_id = o.taxon_id AND tn.name_class = 'scientific name'
  WHERE ds.type = 'isolates' AND ds.subtype = 'Dna_Seq'
)
SELECT DISTINCT ot.term, ot.parentterm,
       CASE WHEN ot.term = ot.organism THEN ot.term ELSE '-1' END AS internal
FROM apidbtuning.organismtree ot
JOIN FilterQuery fq ON fq.organism = ot.organism
WHERE (ot.project_id = '@PROJECT_ID@' OR 'UniDB' = '@PROJECT_ID@')
ORDER BY ot.parentterm, ot.term
```

`internal` is the taxon name for selectable leaves and `-1` for branch nodes — the
`OrganismTree` convention, and it satisfies §2. Rendered `displayType="treeBox"`,
`maxSelectedCount="1"`, as the snp original.

**Filter on `type`/`subtype`, not on `lower(name) LIKE '%dnaseq%'`.** `apidb.datasource`
declares `type='isolates'`, `subtype='Dna_Seq'` for exactly the 10 dnaseq experiment
datasets. A declared category beats a string convention. Note
`apidbtuning.datasetdatasource.category` is **NULL** for all 10, so the `category='Phenotype'`
idiom the tuning manager uses is not available here.

Verified 2026-08-05: PlasmoDB yields 7 rows — one selectable leaf
(`Plasmodium falciparum 3D7`) and 6 branch nodes. Unfiltered across projects it yields the
three organisms with dnaseq isolate data: `pfal3D7`, `tbruTREU927`, `afumAf293`.

### 4.2 EDA table suffix — `variationParams.eda_sample_table_suffix` (new, hidden)

```xml
<flatVocabParam name="eda_sample_table_suffix"
                queryRef="VariationVQ.EdaSampleTableSuffix"
                prompt="EDA sample table suffix"
                quote="false"
                visible="false"
                dependedParamRef="organismParams.organismSinglePick">
```

`quote="false"` because the value is interpolated into a table name, not compared as a
string. `visible="false"` because it is derived, not chosen.

Its vocabulary returns **one row**, the full suffix — study and entity abbreviations joined
— so a single interpolation names any of the three per-study tables
(`attributevalue_`, `attributegraph_`, `ancestors_`):

```sql
SELECT DISTINCT
  s.internal_abbrev || '_' || lower(e.internal_abbrev) AS internal,
  s.internal_abbrev || '_' || lower(e.internal_abbrev) AS term
FROM apidb.datasource ds
JOIN apidb.organism o    ON o.taxon_id = ds.taxon_id
JOIN sres.taxonname tn   ON tn.taxon_id = o.taxon_id AND tn.name_class = 'scientific name'
JOIN sres.externaldatabase ed  ON ed.name = ds.name
JOIN sres.externaldatabaserelease edr
     ON edr.external_database_id = ed.external_database_id
JOIN eda.studyexternaldatabaserelease sedr
     ON sedr.external_database_release_id = edr.external_database_release_id
JOIN eda.study s          ON s.study_id = sedr.study_id
JOIN eda.entitytypegraph e ON e.study_id = s.study_id
WHERE ds.type = 'isolates' AND ds.subtype = 'Dna_Seq'
  AND tn.name = '$$organismSinglePick$$'
  AND s.internal_abbrev IS NOT NULL
```

Verified: for `Plasmodium falciparum 3D7` this returns exactly one row,
`s3be28bbe14_sample`.

One hidden param rather than two (study and entity separately) because the two are only
ever used concatenated, and one interpolation point is one thing to get wrong instead of
two.

### 4.3 Samples — `variationParams.variation_sample_meta` (new `filterParam`)

```xml
<filterParam name="variation_sample_meta"
             metadataQueryRef="VariationVQ.SamplesMetadataByStudy"
             backgroundQueryRef="VariationVQ.SamplesMetadataByStudy"
             ontologyQueryRef="VariationVQ.SampleOntologyByStudy"
             prompt="Samples"
             minSelectedCount="2"
             dependedParamRef="organismParams.organismSinglePick,variationParams.eda_sample_table_suffix">
```

> **The name `variation_sample_meta` is not a style choice — it is a contract.**
> `FindPolymorphismsPlugin.getStrainFilterParamName()` returns exactly this string
> (plumbing §3.5), and `FindPolymorphismsAbstractPlugin:41` lists it among the plugin's
> **required** parameters, reading it at `:100`. Any other name is rejected as a missing
> required parameter.

`minSelectedCount="2"` as the snp original — comparing polymorphism within a group is
meaningless for one sample.

**The filter's internal values are EDA sample stable IDs, and they are directly usable by
HSSS.** Verified 2026-08-05: all **216** distinct `sample_stable_id`s in
`eda.attributevalue_s3be28bbe14_sample` are a strict subset of the **538** strain names in
`strainIdToName.dat`. No mapping layer is needed. (EDA covers 216 of 538 because metadata is
loaded for a subset; the filter simply cannot offer a strain HSSS does not know, which is the
safe direction for the discrepancy to run.)

`FindPolymorphismsAbstractPlugin:104` resolves this param's value by running it as SQL and
joining the results, then writes them to a strains file; the generated command passes
`strains_are_names = 1`, so names rather than numeric IDs are correct.

### 4.4 The four HSSS path and threshold params — defined here, not reused

`WebServicesPath`, `ReadFrequencyPercent`, `MinPercentMinorAlleles`, and
`MinPercentIsolateCalls` are **defined in `variationParams`**, copied from their
`snpParams` originals.

**An earlier draft of this design reused them as `snpParams.<name>`, arguing that copying
would create constants that drift. That would not have loaded.** `snpParams.xml` is
imported *inside the commented-out snp block* in `apiCommonModel.xml:405-412`, so the
`snpParams` paramSet is absent from the assembled model — verified: `wdkXml -model PlasmoDB`
lists 20 paramSets and `snpParams` is not among them. Every `paramRef` to it would fail
model load with an unresolved reference.

Nor can the fix be "uncomment the `snpParams` import". That file's `ngs_snp_id`
`datasetParam` and `snp_result` `answerParam` both reference
`SnpRecordClasses.SnpRecordClass`, which is also commented out, so importing it alone fails
on an unresolved `recordClassRef`. Reviving dead snp XML to serve a new search is the wrong
direction regardless.

So copying is right, and the drift objection dissolves on inspection: the originals are
**unimported dead code that nobody maintains**. This is a migration out of a dead file, not
duplication between two live ones.

What to carry over, faithfully:

| param | shape | notes |
|---|---|---|
| `WebServicesPath` | `enumParam`, `visible="false"`, `quote="false"`, single default `enumValue` | internal is `@WEBSERVICEMIRROR@/PROJECT_GOES_HERE/build-%%buildNumber%%`; the plugin substitutes `PROJECT_GOES_HERE` itself (`:209`) |
| `ReadFrequencyPercent` | `enumParam`, `quote="false"`, terms `80%`/`60%`/`40%`/`20%` → internals `80`/`60`/`40`/`20` | the four internals must match the four `readFreq*` directories exactly |
| `MinPercentMinorAlleles` | `stringParam`, `number="true"`, `<suggest default="0"/>`, `<regex>\d\d?</regex>` | prompt "Minor allele frequency >= " |
| `MinPercentIsolateCalls` | `stringParam`, `number="true"`, `<suggest default="20"/>`, `<regex>\d\d?|100</regex>` | prompt "Percent isolates with a base call >= " |

Two deliberate departures from the originals:

- **One `ReadFrequencyPercent`, not two.** `snpParams` declares it twice —
  `excludeProjects="ToxoDB"` and `includeProjects="ToxoDB"` — and the two differ only in
  help text, the ToxoDB copy being phrased for the two-group search ("isolates in Set A").
  That distinction does not apply to this single-group search, so one definition with the
  general help text. If a ToxoDB-specific wording is wanted later it can be added then.
- **Help text says "samples", not "isolates"**, matching the EDA vocabulary the filter is
  built from and `displayName` in §7.2. The scientific content of the help — what the read
  frequency threshold means, why 80% suits haploids and 40% heterozygous diploids — is
  carried over intact, because it is genuinely useful and hard-won.

## 5. The two EDA vocabulary queries — new `querySet VariationVQ`

Both interpolate `$$eda_sample_table_suffix$$` into the table name.

### 5.1 `SamplesMetadataByStudy` — metadata and background

WDK's contract is `internal`, `ontology_term_name`, `string_value`, `number_value`,
`date_value`. EDA's `attributevalue` table supplies all five almost verbatim:

```sql
SELECT av.sample_stable_id    AS internal,
       av.attribute_stable_id AS ontology_term_name,
       av.string_value,
       av.number_value,
       av.date_value
FROM eda.attributevalue_$$eda_sample_table_suffix$$ av
```

Verified: 3,771 rows, 216 samples, 20 attributes; `string_value` populated on 2,013 rows,
`number_value` on 1,758, `date_value` on **0** (so no date-typed filters appear — not a
defect, just this dataset).

The same query serves `metadataQueryRef` and `backgroundQueryRef`, as the snp original did:
the background distribution is over all samples in the study, which is what this returns.

### 5.2 `SampleOntologyByStudy` — the filter tree

Contract: `ontology_term_name`, `parent_ontology_term_name`, `display_name`, `description`,
`type`, `units`, `precision`, `is_range`.

```sql
SELECT ag.stable_id AS ontology_term_name,
       CASE WHEN ag.parent_stable_id IN
                 (SELECT stable_id FROM eda.attributegraph_$$eda_sample_table_suffix$$)
            THEN ag.parent_stable_id
       END AS parent_ontology_term_name,
       ag.display_name,
       ag.definition AS description,
       CASE ag.data_type
         WHEN 'string'  THEN 'string'
         WHEN 'number'  THEN 'number'
         WHEN 'integer' THEN 'number'
       END AS type,
       ag.unit AS units,
       ag.precision,
       CASE WHEN ag.data_shape = 'continuous' THEN 1 ELSE 0 END AS is_range
FROM eda.attributegraph_$$eda_sample_table_suffix$$ ag
```

**The `type` mapping is pinned to WDK's `OntologyItemType` enum**, which accepts exactly
`string`, `number`, `date`, `multiFilter` — and treats **NULL as a branch node**. EDA's
`category` rows (`has_values = 0`, no `data_shape`) map to NULL, which is exactly right:
they are the tree's internal nodes. `integer` folds into `number` because WDK has no integer
type.

#### 5.2.1 The root problem, and why the `CASE` on the parent is load-bearing

EDA's attribute graph has **no row for the entity itself**. Seven category nodes declare
`parent_stable_id = 'sample'`, and no row has `stable_id = 'sample'`.

`OntologyItemNewFetcher.validateOntologyItems` (WDK) throws on exactly that:

```java
if (parent == null) throw new WdkModelException(
    "Parent ontology ID '" + parentId + "' for ontology item '" + ... + "' cannot be found.");
```

so the naive query would fail the filterParam at runtime. The same method throws a second
way — any BRANCH node that ends up a leaf:

```java
"The following ontology items have no children ... but have a null item type: ..."
```

The fix maps *unresolvable* parents to NULL, which WDK treats as "child of the synthetic
master root" (`root.addChildNode(node)`). It is written as a membership test rather than
`= 'sample'` so it stays correct if the entity abbreviation ever differs — and the
abbreviation is already dynamic in the table name.

Verified against both throw conditions for the Pf study: 27 nodes → 7 roots, **0** dangling
parents, **0** childless branch nodes, 20 typed leaves.

The resulting tree is genuinely useful: 20 leaf variables (continent, country, Collection
Year, Mean coverage, Reads mapped, parasite strain, specimen, …) under 7 categories
(Provenance and identity, Organism under investigation, Specimen and culture, Collection
event, Host, Collection location, Alignment statistics).

## 6. `buildNumber` 70 → 71 — a shared constant, in its own commit

The HSSS files for variations exist **only** under build-71:

| | `Pfalciparum3D7/dnaseq`? |
|---|---|
| `.../PlasmoDB/build-70/` | **absent** |
| `.../PlasmoDB/build-71/` | present — `readFreq20/40/60/80`, plus `bigwig` and `vcf` |

`WebServicesPath` (§4.4) resolves to `@WEBSERVICEMIRROR@/PROJECT_GOES_HERE/build-%%buildNumber%%`,
and `%%buildNumber%%` is a **model-wide constant** — `apiCommonModel.xml:28`, currently
`70`, declared for all 14 ApiCommon projects and referenced 43 times across 6 files
(webservices paths for similarity/BLAST, organism records, snp and chip params, plus
displayed version strings).

Bumping it is nonetheless the right move, and it is established practice here: commit
`8ff801f03` reads *"change buildNumber to 69, so as to point to webservices files built from
rebuild01 workflow"* — the identical motivation. Safety was checked rather than assumed:
build-71 is a fully populated **superset** (1,545 organism directories vs 1,527) and exists
for every project examined (PlasmoDB, ToxoDB, TriTrypDB, FungiDB, CryptoDB, AmoebaDB,
MicrosporidiaDB, PiroplasmaDB), so the searches that already read webservices files do not
lose their inputs.

`releaseDate` stays at `18 March 2026 12:09`. It is a separate set of per-project constants
(`apiCommonModel.xml:11-20`) and past `buildNumber` bumps left it alone.

> **This change gets its own commit**, not one titled after the search. It touches a
> constant shared by 14 projects; anyone later bisecting a webservices-path problem must be
> able to see it.

No `webServiceMirror` override and no test-only `enumValue` are needed — an earlier draft of
this design assumed both. Nothing in committed model XML references a developer's home
directory.

## 7. The search

### 7.1 `VariationsBy.VariationsByIsolateGroup` (processQuery)

```xml
<processQuery name="VariationsByIsolateGroup"
              processName="org.apidb.apicomplexa.wsfplugin.highspeedsnpsearch.FindPolymorphismsPlugin">
  <paramRef ref="organismParams.organismSinglePick" prompt="Organism"
            displayType="treeBox" quote="false"
            queryRef="organismVQ.withVariationsTree"/>
  <paramRef ref="variationParams.eda_sample_table_suffix"/>
  <paramRef ref="variationParams.variation_sample_meta" prompt="Samples"/>
  <paramRef ref="variationParams.WebServicesPath"/>
  <paramRef ref="variationParams.ReadFrequencyPercent"/>
  <paramRef ref="variationParams.MinPercentMinorAlleles"/>
  <paramRef ref="variationParams.MinPercentIsolateCalls"/>
  <wsColumn name="source_id" width="60" wsName="SourceId"/>
  <wsColumn name="project_id" width="20" wsName="ProjectId"/>
  <wsColumn name="PercentMinorAlleles" width="8" columnType="float"/>
  <wsColumn name="PercentIsolateCalls" width="8" columnType="float"/>
  <wsColumn name="Phenotype" width="15"/>
</processQuery>
```

`quote="false"` on the organism param is required for the dependent-param query to work —
the plugin strips quotes for its own use (`removeSingleQuotes`, `:178`, `:203`).

**The `wsColumn` set is fixed by the plugin, not chosen.**
`FindPolymorphismsAbstractPlugin:141` throws if the results file does not have **exactly 4**
tab-separated columns, and `:146-151` maps them to `SourceId`, `PercentOfKnowns`
(→ `PercentIsolateCalls`), `PercentOfPolymorphisms` (→ `PercentMinorAlleles`), `Phenotype`,
with `project_id` supplied by the plugin rather than the file.

**All four threshold/path params come from `variationParams`, not `snpParams`** — see §4.4
for why reuse is impossible (`snpParams` is not in the assembled model) and what to copy.

### 7.2 The question

```xml
<question name="VariationsByIsolateGroup"
          displayName="Differences Within a Group of Samples"
          shortDisplayName="One Group"
          queryRef="VariationsBy.VariationsByIsolateGroup"
          recordClassRef="VariationRecordClasses.VariationRecordClass">
  <attributesList summary="variation_location,gene_ids,variant_type,PercentMinorAlleles,PercentIsolateCalls,Phenotype"/>
  ...
</question>
```

**This question *does* override `attributesList`**, unlike `VariationBySourceId` which
deliberately inherits the record default (searches §6). The plugin's dynamic columns —
minor-allele frequency and percent-of-samples-with-calls *for the chosen group* — are the
entire point of the search and do not exist in the record's default summary. The override
leads with them alongside enough locus identity to be readable.

No `searchCategory`: it groups searches *within* a set, and with two variation searches
there is little to group. It arrives with `ByLocation`/`ByGeneIds`, when the grouping is
informative. Same call as `VariationBySourceId`.

`displayName` says **Samples**, not the original's "Isolates" — EDA calls them samples
throughout, and the filter is built from EDA. The internal search name stays
`VariationsByIsolateGroup`.

`noSummaryOnSingleRecord` is **not** set: unlike an ID lookup, a one-hit analytical result
is a finding the user wants to see in context.

## 8. Ontology and verification

### 8.1 Category ontology

One row in `Model/lib/wdk/ontology/individuals.txt`:
`VariationRecordClasses.VariationRecordClass.VariationQuestions.VariationsByIsolateGroup`,
parent `http://edamontology.org/topic_0199` ("Genetic Variation"), `targetType` `search`,
scopes `menu` + `webservice` — the same placement `VariationBySourceId` uses.

**Build with `wb ontology`, not `wb model`** — a categorization change leaves the OWL stale
otherwise, with no error anywhere. `wb ontology` is a superset; run it alone.

The file is tab-delimited with 14 columns and load-bearing empty fields; append the row with
`printf` rather than by hand.

### 8.2 Verification

Everything in §4 and §5 is already verified by execution against `unidb_shu_a`. What only a
live run can establish:

1. `wb ontology` completes; the model loads with the new params and query.
2. `/service/record-types/variation` lists `VariationQuestions.VariationsByIsolateGroup`
   (project-filtered, so this is the source of truth for presence).
3. The search page renders: organism treeBox offers `Plasmodium falciparum 3D7`; choosing it
   populates the Samples filter with 216 samples under the 7-category tree. **This is the
   first proof the hidden param and both EDA queries work end to end.**
4. Selecting ≥2 samples and submitting returns rows. **This is the first exercise of
   plumbing §3.1 (`/dnaseq`) and §3.5 (the param name), which that spec could not verify.**
   A `"Organism dir does not exist"` failure means the path or `buildNumber`; a missing-
   required-parameter failure means the filterParam name.
5. Returned IDs are `Variant_<sequence>_<location>` and resolve to real record pages — the
   proof that the plumbing spec's ID work holds through a real search.
6. `veup-logs.sh plasmodb mark/since` around all of it: error logs silent.

Fetches in step 2 must come from an authenticated app page (Claude Chrome
`javascript_tool`); a raw `curl` redirects to autologin, and — recorded because it already
cost a session — **a tab bounced to that gate makes relative `fetch` calls answer for
veupathdb.org production**, returning confident wrong answers. Check
`window.location.origin` first. The app is under `/a/`.

## 9. Out of scope

- **The other three HSSS searches.** `ByLocation` (adds `sequenceId`/`start`/`end`,
  `FindPolymorphismsWithSeqFilterPlugin`), `ByGeneIds`
  (`FindSnpsByGeneIdsPlugin`), `ByTwoIsolateGroups` (`FindMajorAllelesPlugin`). Each reuses
  everything in §4 and §5.
- **`FindMajorAllelesPlugin`'s param rename.** It hardcodes `ngsSnp_strain_meta_a` / `_m`
  (plus `_wiz` variants in `sharedParams.xml`) as its own required-param contract. Deferred
  to the `ByTwoIsolateGroups` spec, which **must not forget it** — and should decide
  deliberately what the odd `_m` becomes, since the prompts read "Set B".
- **Deleting the dead `snpParams.xml`** (and the rest of the commented-out snp block). Once
  §4.4 copies the four params out, `snpParams.xml` has no remaining reason to exist — but
  removal has its own blast radius (record §10: `recordParams.xml`, `spanQuestions.xml`,
  `SnpsBySpanLogic`) and is a separate change.
- **`snpParams.MinPercentMajorAlleles`, `*Two` variants, and the wizard params** — used only
  by the two-group searches, so they migrate with `ByTwoIsolateGroups`.
- **Per-strain / VCF data.** `build-71/.../dnaseq/` also contains `vcf` and `bigwig`
  directories — the inputs for record §9's deferred strain tables. Noted because it is the
  first sighting of that data in a served location; still out of scope here.
- **Reviving the HSSS test harnesses** (plumbing §4). Both are broken; this search's
  verification is the browser.
