# `VariationsByLocation` and `VariationsByGeneIds` — design

**Date:** 2026-08-05
**Status:** approved
**Scope:** Two searches on the `variation` record, ported from the deprecated `snp` record's
`NgsSnpsByLocation` and `NgsSnpsByGeneIds`. Both are HSSS `processQuery`s that reuse the
param machinery built for `VariationsByIsolateGroup` and add one region restriction each.
**Implementation target:** `ApiCommonModel`, plus a one-constant change in
`ApiCommonWebService` (§5). Branch `dnaseq-merge-experiments`.
**Prerequisites, both implemented:**
- `2026-08-05-hsss-variation-plumbing-design.md` (`ApiCommonWebService`)
- `2026-08-05-variations-by-isolate-group-design.md` — this spec reuses its params
  wholesale. Section references prefixed `group §` point there; `plumbing §` to the former.

## 1. Purpose

`VariationsByIsolateGroup` answers "what differs within this group of samples, genome-wide."
These two restrict the same computation to a region of interest:

- **`VariationsByLocation`** — a chromosome or sequence ID, with optional start/end.
- **`VariationsByGeneIds`** — a gene list, resolved to the genes' genomic intervals.

They are the cheapest two of the three remaining ports, because the expensive part —
the organism vocabulary, the hidden EDA table-suffix param, and the EDA-driven samples
filter — already exists and is verified working end to end (group §8.2, confirmed live:
216 samples, 7 categories, 506,772 results, `Variant_*` IDs resolving to record pages).

Both plugins extend `FindPolymorphismsPlugin`, so they inherit
`getStrainFilterParamName() → variation_sample_meta` and need no further contract work
beyond §5.

## 2. Reused unchanged — the whole point of doing `ByIsolateGroup` first

| Component | Where |
|---|---|
| `organismVQ.withVariationsTree` | `organismParams.xml`, group §4.1 |
| `variationParams.eda_sample_table_suffix` + `VariationVQ.EdaSampleTableSuffix` | group §4.2 |
| `variationParams.variation_sample_meta` + `VariationVQ.SamplesMetadataByStudy` / `SampleOntologyByStudy` | group §4.3, §5 |
| `variationParams.WebServicesPath`, `ReadFrequencyPercent`, `MinPercentMinorAlleles`, `MinPercentIsolateCalls` | group §4.4 |
| `sharedParams.sequenceId`, `start_point`, `end_point` | live; `ByLocation` only |
| `sharedParams.ds_gene_ids` | live; `ByGeneIds` only |
| The five `wsColumn`s and the `dynamicAttributes` block | plugin-dictated, group §7.1 |

The four `sharedParams` entries were each confirmed present in the **assembled** model
(`wdkXml -model PlasmoDB`), not merely in the file — see §3 for why that distinction is
load-bearing here.

`ds_gene_ids` is a `datasetParam` with `recordClassRef="TranscriptRecordClasses.TranscriptRecordClass"`.
It is generic (any gene list) and needs no variation-specific replacement.

## 3. Three dead lookalikes (`grep` finds them; the model does not have them)

This is the same trap that cost a correction in the previous spec, and it appears three more
times. In every case the source file contains the name and the assembled model does not.

| Name | Why it is unusable |
|---|---|
| `sharedParams.ngsSnp_strain_meta_a` / `_m` / `_a_wiz` / `_m_wiz` | **Inside a commented-out region** of `sharedParams.xml`. Parses as XML comments; absent from the model. (Their `metadataQueryRef`s point at `SnpVQ.*`, itself absent — see group §4.4.) Affects `ByTwoIsolateGroups`, not this spec, but recorded here because the discovery belongs with the others. |
| `organismVQ.withNgsSNPs` | Live XML, but reads `apidbtuning.snpstrains`, **which does not exist in this build** — the same dead table that forced the `withVariationsTree` rewrite. |
| `sharedParams.chromosomeOptionalForNgsSnps` | Live *and* in the assembled model, so it looks reusable. It is not: its vocabulary `SharedVQ.ChromosomeForNgsSnps` overrides the organism param to the dead `organismVQ.withNgsSNPs`, **and** its SQL keys on `org_abbrev = '$$organismSinglePick$$'` while our organism param deliberately carries the **taxon name** (group §2). Even against a live table that comparison matches nothing. |

> **Verify absence with the bare name, never `name="x"`.** `wdkXml` prints attributes
> single-quoted (`name='x'`), so a double-quoted grep pattern reports zero regardless of what
> the model contains — a check that can only pass. Print the full paramSet list alongside.

## 4. The chromosome param — new, rewritten

### 4.1 `variationParams.chromosomeOptionalForVariations`

```xml
<flatVocabParam name="chromosomeOptionalForVariations"
                queryRef="VariationVQ.ChromosomeForVariations"
                prompt="Chromosome"
                multiPick="false"
                quote="true"
                dependedParamRef="organismParams.organismSinglePick">
```

Shape carried over from the snp original. It lives in `variationParams` rather than
`sharedParams` because only variation searches use it, and because §5 renames the plugin's
constant to match.

### 4.2 `VariationVQ.ChromosomeForVariations`

```sql
SELECT * FROM (
    SELECT DISTINCT s.chromosome AS term,
                    s.source_id  AS internal,
                    s.chromosome_order_num
    FROM webready.GenomicSeqAttributes_p s
    WHERE s.organism = '$$organismSinglePick$$'
      AND s.chromosome IS NOT NULL
  UNION
    SELECT 'Choose chromosome' AS term, 'choose' AS internal, -1 AS chromosome_order_num
) t
ORDER BY chromosome_order_num
```

Two changes from `SharedVQ.ChromosomeForNgsSnps`, both forced:

- **`s.organism`, not `s.org_abbrev`.** The organism param's internal value is the scientific
  taxon name, because `HighSpeedSnpSearchAbstractPlugin` resolves it through `sres.TaxonName`
  to get `name_for_filenames` for the webservices path (group §2). `GenomicSeqAttributes_p`
  carries both columns, so this is a one-word change.
- **No `queryRef` override on a depended organism param.** The original pointed at the dead
  `organismVQ.withNgsSNPs`; the paramRef in each `processQuery` supplies
  `organismVQ.withVariationsTree` instead (§6).

Verified 2026-08-05 against `unidb_shu_a`: for `Plasmodium falciparum 3D7` this returns
**15 rows in 26 ms** — the 14 chromosomes, `term` `01` through `14` in `chromosome_order_num`
order, plus the sentinel.

**The `internal` is the sequence source ID, and that is what makes it work:** chromosome `01`
yields `Pf3D7_01_v3`, which is exactly the sequence identifier the HSSS files carry — the
live `ByIsolateGroup` run returned `Variant_Pf3D7_01_v3_1`. The value feeds the position
filter directly with no mapping.

`webready.GenomicSeqAttributes_p` is `LIST`-partitioned on `org_abbrev`, so filtering on
`organism` forfeits partition pruning. Measured at 25 ms, which is well inside what a
vocabulary query needs, so the simpler predicate wins over a join to recover the abbreviation.
If it ever becomes hot, the fix is to resolve `org_abbrev` from the taxon name in a subquery —
not to change what the organism param carries.

The `'Choose chromosome'/'choose'` sentinel row is carried over deliberately; see §4.3.

### 4.3 The empty-sequence contract — port it faithfully, and do not "fix" it

`FindPolymorphismsWithSeqFilterPlugin.makeCommandToCreateBashScript` reads:

```java
String seq = params.get(PARAM_SEQUENCE);
if (seq.contains("No Match")) seq = chromosome;
```

This looks like dead code — `sequenceId` has no default value, so a blank box would appear to
leave `seq` empty and the fallback unreachable, making the chromosome dropdown decorative.
**It is not dead.** `sharedParams.sequenceId` carries twelve per-project `<suggest>` children,
each with:

```xml
<suggest includeProjects="PlasmoDB" default="(Example: Pf3D7_04_v3)"
         allowEmpty="true" emptyValue="No Match"/>
```

WDK substitutes the literal string `No Match` for an empty value, which is precisely what the
guard tests. Sequence ID takes precedence; the chromosome dropdown is the fallback when the
box is left empty. The coupling is invisible from either side alone — the Java names a magic
string, the model supplies it from an attribute on a child element — which is why it is
recorded here.

Consequences for this port, all deliberate:

- Keep `seq.contains("No Match")` exactly as is. Widening it to also treat blank/null as empty
  was considered and **rejected**: it would be a behavior change to a plugin shared with the
  chip-snp searches, in service of a case that cannot arise while `emptyValue` is set.
- Keep the `'choose'` sentinel in the vocabulary, so "no chromosome chosen" is a real value
  rather than an empty param.
- `end_point` of `0` means "to the end of the sequence" — the plugin maps it to `1000000000`.
  Carried over as-is; the param's prompt already says `End Location (0 = end)`.

## 5. `ApiCommonWebService`: one constant

```java
-  public static final String PARAM_CHROMOSOME = "chromosomeOptionalForNgsSnps";
+  public static final String PARAM_CHROMOSOME = "chromosomeOptionalForVariations";
```

in `FindPolymorphismsWithSeqFilterPlugin`. Nothing else in that class changes.

Why rename at all, when overriding the existing param's `queryRef` would have avoided a
cross-repo change: the strain filter was already renamed to `variation_sample_meta`
(plumbing §3.5). Leaving the chromosome name alone would produce a single `processQuery`
declaring `variation_sample_meta` and `chromosomeOptionalForNgsSnps` side by side — a
half-renamed contract, which is worse than either uniform choice and invites the next reader
to re-derive that the snp-era name is meaningless. The plugin is variation-only from here.

Requires `bld ApiCommonWebService` before the model change can be exercised. `PARAM_SEQUENCE`,
`PARAM_START_POINT`, and `PARAM_END_POINT` are already generic and keep their names.

## 6. The two searches

Both `processQuery`s share this prefix — organism param with the variation vocabulary, then
the hidden suffix param, then the samples filter, then the four thresholds:

```xml
<paramRef ref="organismParams.organismSinglePick" prompt="Organism"
          displayType="treeBox" quote="false"
          queryRef="organismVQ.withVariationsTree"/>
<paramRef ref="variationParams.eda_sample_table_suffix"/>
...
<paramRef ref="variationParams.variation_sample_meta" prompt="Samples"/>
<paramRef ref="variationParams.WebServicesPath"/>
<paramRef ref="variationParams.ReadFrequencyPercent"/>
<paramRef ref="variationParams.MinPercentMinorAlleles"/>
<paramRef ref="variationParams.MinPercentIsolateCalls"/>
```

`quote="false"` on the organism param is required for the dependent-param query; the plugin
strips quotes for its own use.

### 6.1 `VariationsByLocation`

`processName="...highspeedsnpsearch.FindPolymorphismsWithSeqFilterPlugin"`, inserting after
the suffix param:

```xml
<paramRef ref="variationParams.chromosomeOptionalForVariations" multiPick="false"/>
<paramRef ref="sharedParams.sequenceId"/>
<paramRef ref="sharedParams.start_point"/>
<paramRef ref="sharedParams.end_point"/>
```

Question `displayName="Genomic Location"`, `shortDisplayName="Location"`.

### 6.2 `VariationsByGeneIds`

`processName="...highspeedsnpsearch.FindSnpsByGeneIdsPlugin"`, inserting:

```xml
<paramRef ref="sharedParams.ds_gene_ids" default="PF3D7_1133400" includeProjects="PlasmoDB,UniDB"/>
<paramRef ref="sharedParams.ds_gene_ids" default="TcCLB.403869.10" includeProjects="TriTrypDB"/>
<paramRef ref="sharedParams.ds_gene_ids" default="Afu2g00910"     includeProjects="FungiDB"/>
```

The per-project `default` on the paramRef is the snp original's pattern. Defaults are supplied
only for the three projects with variation data loaded today; `AmoebaDB`, `CryptoDB`,
`MicrosporidiaDB`, `PiroplasmaDB`, and `ToxoDB` owe one when their data lands — omitted rather
than invented, matching the `variation_id` param (searches §4).

Question `displayName="Gene ID(s)"`, `shortDisplayName="Gene IDs"`.

**No gene→variation join is needed anywhere in the model.** `FindSnpsByGeneIdsPlugin`
resolves the gene list to genomic intervals itself:

```sql
select g.sequence_id, g.start_min, g.end_max
from webready.GeneAttributes_p g, (<gene_list>) user_genes
where g.source_id = user_genes.gene_source_id
```

writes them to `genomicLocations.txt`, and HSSS filters variant positions by interval via
`hsssGenomicLocationsFilter`. `webready.geneattributes_p` exists in this build (verified), so
that SQL is untouched. The gene↔variation relationship is **positional**, not product-based:
`apidb.VariationTranscriptProduct` (4.6M rows, keyed `sequence_source_id, location,
na_feature_id`) is real and populated but plays no part in this path. Reporting per-gene coding
consequences would be a scope increase beyond the snp original and is explicitly not in this
spec (§9).

### 6.3 Both questions

Same `attributesList` as `ByIsolateGroup`:

```xml
<attributesList summary="variation_location,gene_ids,variant_type,PercentMinorAlleles,PercentIsolateCalls,Phenotype"/>
```

and each needs **its own `dynamicAttributes` block** declaring `PercentMinorAlleles`,
`PercentIsolateCalls`, and `Phenotype` — copied from `VariationsByIsolateGroup`.

> **`dynamicAttributes` is mandatory, not decoration.** `attributesList` may not name a
> `processQuery`'s `wsColumn`s until they are declared on the question; without the block the
> build fails with `Summary attribute field [PercentMinorAlleles] defined in question [...] is
> invalid`. This cost a build cycle on the previous search.

`noSummaryOnSingleRecord` is not set, for the same reason as `ByIsolateGroup`: a one-hit
analytical result wants its context.

## 7. Ontology, and the `searchCategory` question closed

Two rows in `Model/lib/wdk/ontology/individuals.txt`, parent
`http://edamontology.org/topic_0199`, `targetType` `search`, scopes `menu` + `webservice` —
identical placement to the two existing variation searches. Derive each row by substitution
from the `VariationBySourceId` row rather than typing it: the file is tab-delimited with
load-bearing empty fields and a trailing tab.

**No `searchCategory` on either question, and the previous spec's "it arrives with
ByLocation/ByGeneIds" resolves to "it never arrives."** `searchCategory` appears **zero times**
in the 17,763-line `wdkXml` dump of the assembled model — it is legacy and is not surfaced by
the service. Menu grouping comes from the category ontology, which these rows handle.

Build both with **`wb ontology`, not `wb model`** — a categorization change leaves the OWL
stale with no error anywhere.

## 8. Verification

Everything in §4.2 is already verified by execution. What a live run must establish, per search:

1. `wb ontology` completes; `/service/record-types/variation` lists the new search
   (project-filtered, so this is the source of truth for presence).
2. **`ByLocation`:** the chromosome dropdown offers `01`–`14`; choosing `01` and submitting with
   the sequence box left empty returns rows confined to `Pf3D7_01_v3`. That last clause is the
   real test — it exercises the `emptyValue`→`No Match`→chromosome-fallback chain of §4.3 end to
   end. Then repeat with an explicit `sequenceId` and a start/end window and confirm the window
   is respected.
3. **`ByGeneIds`:** the PlasmoDB default `PF3D7_1133400` returns rows whose locations fall inside
   that gene's `start_min`/`end_max` (check against `webready.GeneAttributes_p`). **This is the
   first real exercise of `hsssGenomicLocationsFilter`**, whose ID join was fixed in the
   plumbing *plan*'s Task 1b (a second composition site found during implementation, so it is
   in the plan rather than that spec) — the installed copy in `gus_home` was confirmed to carry
   the fix (`underscore=2, dotted=0`). A wrong ID form here surfaces as *zero results with no
   error*, so a non-empty result set is the assertion.
4. Returned IDs are `Variant_<sequence>_<location>` and resolve to real record pages.
5. `veup-logs.sh plasmodb mark/since` around each: error logs silent.

Fetches in step 1 must come from an authenticated app page; a raw `curl` redirects to autologin,
and a tab bounced to that gate makes relative `fetch` calls answer for **veupathdb.org
production**. Check `window.location.origin` first. Note the app path redirects to the webapp
context — on this instance `/plasmo.jbrestel/app`, service at `/plasmo.jbrestel/service` — so
build relative paths from the post-redirect location, not from `/a/`.

Screenshots were unavailable during the previous search's verification (the Chrome extension's
script injection times out on this instance, reproducibly, including on known-good pages).
`javascript_tool` and the service endpoints work; plan verification around them.

## 9. Out of scope

- **`VariationsByTwoIsolateGroups`.** Its own spec: a different plugin
  (`FindMajorAllelesPlugin`), an 11-column `wsColumn` set, five doubled threshold params, and
  **two new EDA-driven filter params** — `ngsSnp_strain_meta_a`/`_m` cannot be reused (§3), so
  Set A and Set B must be built fresh from `variation_sample_meta`'s shape. That spec **must
  not forget** `FindMajorAllelesPlugin`'s hardcoded `ngsSnp_strain_meta_a` / `_m` names, and
  should decide deliberately what the odd `_m` becomes given its prompts read "Set B".
- **`NgsSnpsByTwoIsolateGroupsWiz`** — a sixth search (PlasmoDB/UniDB only) using the
  `*_wiz` params. Decide with `ByTwoIsolateGroups` whether it is worth porting at all.
- **Per-gene coding consequences** from `apidb.VariationTranscriptProduct` (§6.2). A feature,
  not a port.
- **Deleting the dead `snpParams.xml`** and the commented-out snp regions of `sharedParams.xml`.
  Own change, own blast radius.
- **`ReadFrequencyPercent` as a functional parameter.** Investigated 2026-08-05: for haploid
  organisms the upstream caller runs `freebayes --min-alternate-fraction 0.8`
  (`dnaseq-nextflow/modules/snp.nf:25`), so every variant reaching
  `processSequenceVariations.jl`'s cutoff ladder `(20,40,60,80)` already passes 80, and all four
  `readFreq*` directories receive identical writes — confirmed on disk (equal byte sizes,
  matching `md5sum`, distinct inodes). The param correctly selects its directory; the
  directories hold the same data. **Any QA that tries to verify "changing read frequency changes
  results" will get a false negative on a haploid site**, which is worth knowing before it is
  reported as a bug in these searches. Not ours to fix.
