# `VariationsByTwoIsolateGroups` — design

**Date:** 2026-08-05
**Status:** approved
**Scope:** The last of the five `snp` searches to port — `NgsSnpsByTwoIsolateGroups` becomes
`VariationsByTwoIsolateGroups`. Finds loci whose *major allele* differs between two
user-chosen groups of samples.
**Implementation target:** `ApiCommonModel`, plus two constants in `ApiCommonWebService`.
Branch `dnaseq-merge-experiments`.
**Prerequisites, all implemented and verified live:**
- `2026-08-05-hsss-variation-plumbing-design.md` (`ApiCommonWebService`)
- `2026-08-05-variations-by-isolate-group-design.md` — supplies the filter this one doubles
- `2026-08-05-variations-by-location-and-gene-ids-design.md`

Section references: `group §` → the by-isolate-group spec, `locgene §` → the location/genes spec.

## 1. Purpose, and why this one is not like the other three

The three ported HSSS searches so far all answer "what varies *within* one group of samples,"
optionally restricted to a region. This one asks a different question: **take two groups, find
the major allele in each, and return the loci where those major alleles disagree.** It is the
search you use to find markers that distinguish two populations.

That difference in question produces a difference in shape, and this is the one port where
"same as the last one plus a param" does not hold:

| | one group | two groups |
|---|---|---|
| plugin | `FindPolymorphismsPlugin` | `FindMajorAllelesPlugin` |
| plugin's parent | `FindPolymorphismsPlugin` chain | **`HighSpeedSnpSearchAbstractPlugin` directly** |
| threshold of interest | *minor* allele frequency | *major* allele frequency, per group |
| result columns | 5 | **12** |
| results-file columns | 4 | **11** |
| sample filters | 1 | **2, which must differ** |

The middle row matters: because `FindMajorAllelesPlugin` extends the abstract plugin rather
than `FindPolymorphismsPlugin`, it inherits **no** `getStrainFilterParamName()`. Its filter
param names are its own constants, which is why §4 renames two of them rather than one.

## 2. Reused unchanged

Three of the ten required params are already ours, under exactly the names the plugin wants:

| Component | Where |
|---|---|
| `organismVQ.withVariationsTree` | `organismParams.xml`, group §4.1 |
| `variationParams.eda_sample_table_suffix` + `VariationVQ.EdaSampleTableSuffix` | group §4.2 |
| `VariationVQ.SamplesMetadataByStudy` / `SampleOntologyByStudy` | group §5 — **shared by all three filter params**, see §4.2 |
| `variationParams.WebServicesPath` | group §4.4 |
| `variationParams.ReadFrequencyPercent` | group §4.4 — serves **Set A** |
| `variationParams.MinPercentIsolateCalls` | group §4.4 — serves **Set A** |

Note the asymmetry in the last two: the plugin's Set A constants are the *unsuffixed* names the
one-group search already defines, and only Set B gets `...Two` variants. That is the plugin's
choice, not ours, and it means Set A's read-frequency and percent-called params are literally
the same param objects as the one-group search's, distinguished only by a `prompt` override on
the `paramRef` (as the snp original did).

## 3. The plugin contract (read this before writing any XML)

`FindMajorAllelesPlugin.getRequiredParameterNames()` returns exactly ten names. Miss one and
the search fails at run time as a missing required parameter, not at build time.

| Plugin constant | Required param name | Status |
|---|---|---|
| `PARAM_ORGANISM` | `organismSinglePick` | exists |
| `PARAM_WEBSVCPATH` | `WebServicesPath` | exists |
| `PARAM_STRAIN_FILTER_A` | `ngsSnp_strain_meta_a` → **`variation_sample_meta_a`** | §4, rename + new |
| `PARAM_READ_FREQ_PERCENT_A` | `ReadFrequencyPercent` | exists |
| `PARAM_MIN_PERCENT_KNOWNS_A` | `MinPercentIsolateCalls` | exists |
| `PARAM_MIN_PERCENT_MAJOR_ALLELES_A` | `MinPercentMajorAlleles` | **new** (§5) |
| `PARAM_STRAIN_FILTER_B` | `ngsSnp_strain_meta_m` → **`variation_sample_meta_b`** | §4, rename + new |
| `PARAM_READ_FREQ_PERCENT_B` | `ReadFrequencyPercentTwo` | **new** (§5) |
| `PARAM_MIN_PERCENT_KNOWNS_B` | `MinPercentIsolateCallsTwo` | **new** (§5) |
| `PARAM_MIN_PERCENT_MAJOR_ALLELES_B` | `MinPercentMajorAllelesTwo` | **new** (§5) |

`getColumns()` returns twelve, and `makeResultRow` throws unless the results file has **exactly
11** tab-separated columns (`project_id` is supplied by the plugin, not the file):

```
SourceId, ProjectId,
MajorAlleleA, MajorAllelePctA, IsTriallelicA, MajorProductA, MajorProductIsVariableA,
MajorAlleleB, MajorAllelePctB, IsTriallelicB, MajorProductB, MajorProductIsVariableB
```

Two more inherited facts worth knowing: `getReconstructCmdName()` returns
`hsssReconstructSnpId` — the script whose ID separator was fixed in the plumbing work, so IDs
arrive as `Variant_<sequence>_<location>` — and the plugin passes `suffix = "NULL"` plus
`strains_are_names = 1`, so the filter's EDA sample stable IDs are used directly as strain
names, exactly as in the one-group search (group §4.3).

Observation, recorded and **not** acted on: the Set A path null-checks its strains twice
(redundantly) while the Set B path never null-checks `strainsB` after resolving it. An empty
Set B would therefore reach `writeStrainsFile` unguarded. Since `uniq-value-params` (§6.3) and
the filter's own defaults make an empty Set B hard to produce through the UI, this is left
alone rather than fixed under cover of a port.

## 4. The two sample filters

### 4.1 Naming: symmetric `_a` / `_b`

```java
-  public static final String PARAM_STRAIN_FILTER_A = "ngsSnp_strain_meta_a";
-  public static final String PARAM_STRAIN_FILTER_B = "ngsSnp_strain_meta_m";
+  public static final String PARAM_STRAIN_FILTER_A = "variation_sample_meta_a";
+  public static final String PARAM_STRAIN_FILTER_B = "variation_sample_meta_b";
```

Two decisions here. **The `_m` becomes `_b`** — it is the odd one out in the original, whose
prompts already read "Set B Isolates"; nothing in the plugin distinguishes it beyond being the
second group. And **Set A gets its own `_a` param** rather than reusing the unsuffixed
`variation_sample_meta`. Reuse was the cheaper option (one fewer definition, and Set A would
literally be the one-group search's filter) and was rejected: a search declaring an unsuffixed
A beside a suffixed B reads as though the two were different in kind. Symmetry is worth one
duplicated definition, and it makes `uniq-value-params` (§6.3) obvious at a glance.

This continues the rename already applied twice — `variation_sample_meta` (plumbing §3.5) and
`chromosomeOptionalForVariations` (locgene §5). After this, no snp-era param name survives in
any variation search.

### 4.2 Definitions: two new params, zero new queries

```xml
<filterParam name="variation_sample_meta_a"
             metadataQueryRef="VariationVQ.SamplesMetadataByStudy"
             backgroundQueryRef="VariationVQ.SamplesMetadataByStudy"
             ontologyQueryRef="VariationVQ.SampleOntologyByStudy"
             prompt="Set A Samples"
             dependedParamRef="organismParams.organismSinglePick,variationParams.eda_sample_table_suffix">
```

and the same again for `_b` with `prompt="Set B Samples"`. **Both reuse the existing EDA
queries** — no new SQL anywhere in this spec. WDK resolves a dependent param's queries by
`query.clone()` followed by `setContextParam(this)` (`AbstractDependentParam:230-231`, inside
`resolveDependentQuery`), so
three filter params sharing two query definitions get three independent instances. The snp
original did exactly this: `ngsSnp_strain_meta_a` and `_m` both pointed at
`SnpVQ.SamplesMetadataByOrganism`.

This is what "constructed the same way as in the one group question" cashes out to: same
metadata query, same ontology query, same 27-node/7-category tree over 216 samples, same
`sample_stable_id` internals that HSSS accepts as strain names.

**No `minSelectedCount`, deliberately** — and this is a real difference from
`variation_sample_meta`, which sets `minSelectedCount="2"`. Polymorphism *within* a group of
one is undefined, which is why the one-group search requires two. Comparing the major allele
*between* two groups of one is perfectly meaningful: it is a strain-versus-strain comparison.
The snp original set no minimum on either group. Do not add one.

## 5. The four new threshold params

Copied from `snpParams.xml` into `variationParams`, for the same reason as the previous four:
`snpParams` is imported inside a commented-out block and is absent from the assembled model, so
a `paramRef` to it fails model load (group §4.4).

| param | shape | notes |
|---|---|---|
| `MinPercentMajorAlleles` | `stringParam`, `number="true"`, `<suggest default="80"/>`, `<regex>\d\d?|100</regex>` | prompt "Major allele frequency >= "; serves **Set A** |
| `MinPercentMajorAllelesTwo` | identical shape and default | serves **Set B** |
| `MinPercentIsolateCallsTwo` | `stringParam`, `number="true"`, `<suggest default="20"/>`, `<regex>\d\d?|100</regex>` | prompt "Min percent isolates with calls >= " |
| `ReadFrequencyPercentTwo` | `enumParam`, `quote="false"`, terms `80%`/`60%`/`40%`/`20%` → internals `80`/`60`/`40`/`20` | the four internals must match the `readFreq*` directories exactly |

Three deliberate departures, consistent with the earlier ports:

- **One `ReadFrequencyPercentTwo`, not two.** The original declares it twice
  (`excludeProjects="ToxoDB"` / `includeProjects="ToxoDB"`), differing only in help text.
- **Help text says "samples", not "isolates"**, matching EDA vocabulary and the display names.
  The scientific content is carried over intact, including the genuinely useful note that 100%
  is permissible and is the *most stringent* setting for a major-allele threshold — a point
  that reads as counterintuitive until you notice the search first identifies an allele in one
  set and then compares it against the other.
- **`MinPercentIsolateCallsTwo` keeps its original prompt wording** ("Min percent isolates with
  calls >= ") rather than being harmonised with `MinPercentIsolateCalls`' longer phrasing
  ("Percent samples with a base call >= "). Flagged because it is an inconsistency a reader
  will notice: the two prompts sit side by side in one form. Harmonising is a one-line change
  and is left to the implementer's judgement at review time; the param **name** must not change.

## 6. The search

### 6.1 `VariationsBy.VariationsByTwoIsolateGroups`

`processName="org.apidb.apicomplexa.wsfplugin.highspeedsnpsearch.FindMajorAllelesPlugin"`,
with params in the original's order — organism, then all of Set A, then all of Set B — so the
form reads as two parallel blocks:

```xml
<paramRef ref="organismParams.organismSinglePick" prompt="Organism"
          displayType="treeBox" quote="false" queryRef="organismVQ.withVariationsTree"/>
<paramRef ref="variationParams.eda_sample_table_suffix"/>
<paramRef ref="variationParams.WebServicesPath"/>

<paramRef ref="variationParams.variation_sample_meta_a"     prompt="Set A Samples"/>
<paramRef ref="variationParams.ReadFrequencyPercent"        prompt="Set A read frequency threshold &gt;= "/>
<paramRef ref="variationParams.MinPercentMajorAlleles"      prompt="Set A major allele frequency &gt;= "/>
<paramRef ref="variationParams.MinPercentIsolateCalls"      prompt="Set A percent samples with base call &gt;= "/>

<paramRef ref="variationParams.variation_sample_meta_b"     prompt="Set B Samples"/>
<paramRef ref="variationParams.ReadFrequencyPercentTwo"     prompt="Set B read frequency threshold &gt;= "/>
<paramRef ref="variationParams.MinPercentMajorAllelesTwo"   prompt="Set B major allele frequency &gt;= "/>
<paramRef ref="variationParams.MinPercentIsolateCallsTwo"   prompt="Set B percent samples with base call &gt;= "/>
```

The `prompt` overrides are load-bearing for usability, not decoration: without them Set A's
three thresholds carry the one-group search's generic labels and the form shows two
indistinguishable "Read frequency threshold" fields.

Twelve `wsColumn`s per §3, `source_id` at width 60, `project_id` at 20, the two `*Pct*`
columns `columnType="float"` at width 8, the rest narrow.

### 6.2 The question

```xml
<question name="VariationsByTwoIsolateGroups"
          displayName="Differences Between Two Groups of Samples"
          shortDisplayName="Two Groups"
          queryRef="VariationsBy.VariationsByTwoIsolateGroups"
          recordClassRef="VariationRecordClasses.VariationRecordClass">
  <attributesList summary="variation_location,gene_ids,variant_type,MajorAlleleA,MajorAllelePctA,IsTriallelicA,MajorProductA,MajorProductIsVariableA,MajorAlleleB,MajorAllelePctB,IsTriallelicB,MajorProductB,MajorProductIsVariableB"/>
```

Thirteen summary columns is a lot, and it is the original's choice reproduced: the whole point
of the search is the side-by-side comparison, and dropping either set's columns would hide half
the answer. `displayName` says **Samples** rather than the original's "Isolates".

Ten `dynamicAttributes`, all `sortable="false"` as in the original (the plugin emits them as
strings, so a lexical sort on `MajorAllelePctA` would mis-order), with `Set A ` / `Set B `
display-name prefixes carried over verbatim.

### 6.3 `uniq-value-params` — the piece most likely to be dropped

```xml
<propertyList name="uniq-value-params">
  <value>variation_sample_meta_a</value>
  <value>variation_sample_meta_b</value>
</propertyList>
```

This declares that the two params must not hold the same value; comparing a group against
itself returns nothing useful. It is **not** snp cruft — `geneQuestions.xml` uses the same
property four times for fold-change reference-versus-comparison sample pairs.

Enforcement is client-side, in `web-monorepo`, which is not checked out in this workspace — so
the convention is verifiable but the implementation is not readable from here. Consequence for
verification: **its absence cannot be detected by any build or service check**, only by
noticing in the browser that the form lets you submit A = B. Port it, and confirm it in the
rendered form.

## 7. Ontology

One row in `Model/lib/wdk/ontology/individuals.txt`, parent
`http://edamontology.org/topic_0199`, `targetType` `search`, scopes `menu` + `webservice` —
identical placement to the four existing variation searches, derived by substitution from the
`VariationBySourceId` row. Build with **`wb ontology`**, not `wb model`.

No `searchCategory`: it appears zero times in the assembled model (locgene §7).

## 8. Verification

The Java rename must be built and installed (`bld ApiCommonWebService`) and the webapp reloaded
before any run, or the search fails as a missing required parameter while the model looks wrong.
Confirm the installed jar carries both new strings and neither old one.

Then, in the browser (screenshots are unavailable on this instance; use `javascript_tool` and
the service, and check `window.location.origin` first):

1. `/service/record-types/variation` lists all **five** variation searches.
2. The form renders two parallel Set A / Set B blocks with distinct prompts, and both sample
   filters populate with 216 samples under the 7-category tree.
3. **The disjoint-groups run.** `country` splits the Pf samples cleanly — 147 French Guiana, 69
   Senegal (verified during the one-group work). Set A = Senegal, Set B = French Guiana, major
   allele thresholds at the 80 default. Expect a non-empty result set, and for each row
   `MajorAlleleA != MajorAlleleB` — that inequality *is* the search's definition, so a row
   violating it means the comparison is broken.
4. **The symmetry check.** Swap the two groups. The total count must be identical, because
   "major alleles disagree" is symmetric. A differing count means Set B's thresholds are not
   being applied the way Set A's are, which is exactly the sort of copy-paste asymmetry the
   doubled params invite.
5. **The `uniq-value-params` check.** Set A = Set B = Senegal. The form should refuse it. If it
   submits, the property did not take effect (§6.3).
6. Returned IDs are `Variant_<sequence>_<location>` and resolve to record pages.
7. `veup-logs.sh plasmodb mark/since` around all of it: error logs silent, and any errors caused
   by hand-rolled service requests reported as self-inflicted rather than counted as clean.

Note for step 3: a `datasetParam`-free search, so no dataset creation is needed — but the two
filter values are `filterParam` JSON, and the two must differ or step 5's guard is what you are
testing instead.

## 9. Out of scope

- **`NgsSnpsByTwoIsolateGroupsWiz`** — a sixth search (PlasmoDB/UniDB only) driven by the
  `*_wiz` params, which live in the same commented-out region of `sharedParams.xml` as
  `ngsSnp_strain_meta_a`/`_m`. Whether the wizard flow is still wanted is a product question,
  not a porting one. **After this spec ships, the five-search port is complete** and this is
  the only snp-era search left unported.
- **Deleting the dead snp XML.** With this spec, every param the five searches need lives in
  `variationParams`. `snpParams.xml` and the commented-out snp regions of `sharedParams.xml`
  then have no remaining consumer — but removal has its own blast radius (`recordParams.xml`,
  `spanQuestions.xml`, `SnpsBySpanLogic`) and is a separate change.
- **Fixing the Set B null-check asymmetry** in `FindMajorAllelesPlugin` (§3).
- **Harmonising the two percent-called prompts** (§5) beyond the implementer's call.
- **Per-gene coding consequences** from `apidb.VariationTranscriptProduct`.
- **`ReadFrequencyPercent` as a functional parameter.** On haploid organisms all four
  `readFreq*` directories hold identical data, because the upstream caller runs
  `freebayes --min-alternate-fraction 0.8`. Both read-frequency params here select their
  directory correctly; changing either will not change results on a haploid site, and that is
  not a defect in this search. This bites twice as hard here, since the symmetry check in §8.4
  would also pass trivially if the two sets read the same files — so treat §8.4 as testing the
  *threshold* plumbing, not the read-frequency plumbing.
