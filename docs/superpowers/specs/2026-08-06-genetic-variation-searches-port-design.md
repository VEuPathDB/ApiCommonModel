# Genetic Variation searches port — design

**Date:** 2026-08-06
**Status:** designed
**Scope:** Port the four remaining Genetic Variation searches onto the merged-dnaseq /
EDA world: `GenesByNgsSnps`, `SequencesByPloidy`, `GenesByCopyNumber`,
`GenesByCopyNumberComparison`.
**Repo:** `ApiCommonModel` only, branch `dnaseq-merge-experiments`.
**Builds on:** `2026-08-05-hsss-variation-plumbing-design.md` (ApiCommonWebService) and the
five `variation*` search specs. Those established the organism → EDA-study → samples-filter
pattern this spec reuses.

## 1. Purpose

Five variation searches now work against the merged dnaseq EDA studies. Four searches
remain, and they are the last consumers of two dead subsystems:

- the **snp** `paramSet`, which is absent from the assembled model (its `<import>` sits
  inside a commented block in `apiCommonModel.xml`); and
- the **PAN provenance graph** (`study.Input` → `webready.PANIO_p`), which is no longer
  loaded.

The four searches split into two families with unrelated blockers, but they share the
sample-selection pattern and are categorized together, so they are specified together and
built in three phases (§2).

### 1.1 Current state, verified

Against the assembled model and `unidb_shu_a`:

| Search | model XML | ontology row | blocker |
|---|---|---|---|
| `GenesByNgsSnps` | **commented out** (question + `processQuery`) | live, orphaned (`individuals.txt:99`) | referenced `snpParams.*`; plugin now fixed |
| `GenesByCopyNumber` | live | `##` commented (`:100`) | reads empty `webready.GeneCopyNumbers_p` |
| `GenesByCopyNumberComparison` | live | `##` commented (`:101`) | same |
| `SequencesByPloidy` | live | `##` commented (`:138`) | reads dead `CNV_strain` / `organismSinglePickCnv` |

Three of the four are *live but dark*: they build, and nothing surfaces them.

### 1.2 Why the CNV tables are empty — root cause

`webready.GeneCopyNumbers_p` and `ChrCopyNumbers_p` both inner-join `webready.PANIO_p`.
`PANIO_p` is empty because it inner-joins `study.Input`, and **`study.Input` has 0 rows**
on this build (`study.Output` 1,356; `study.ProtocolApp` 1,356). So `input_pan_id` and
`output_pan_id` — which all three CNV searches use for *both* sample identity and organism
scoping — have no data behind them.

This is not a dev-subset artifact. It means the CNV searches cannot be repaired by swapping
a param; the join they are built on has to be replaced.

The underlying data is fine: `apidb.genecopynumber` 3,404,180 rows, `apidb.chrcopynumber`
4,936 rows.

### 1.3 What replaces the PAN graph

Everything the dead columns supplied is available elsewhere, and was verified rather than
assumed:

| lost | replacement | evidence |
|---|---|---|
| organism scoping via `org_abbrev` on the tuning table | `org_abbrev` / `organism` / `taxon_id` from `webready.TranscriptAttributes_p` (69,397 rows) and `GenomicSeqAttributes_p` (8,348 rows) | **all** 3,389,444 gene-CNV rows find a match on `gene_na_feature_id` (fanning out to 3,404,180 result rows via multi-transcript genes); **all** 4,936 chr-CNV rows join on `na_sequence_id` |
| sample identity via `output_pan_id` | `study.protocolappnode.name` minus its `_GeneCNV` / `_Ploidy` suffix, which **is** an EDA sample stable ID | 441/441 gene-CNV and 452/452 chr-CNV names match exactly; per-organism 216/216 pfal3D7, 232/232 afumAf293, 4/4 tbruTREU927 |
| gene↔chr correlation via `input_pan_id` | `eda_sample_stable_id` + `na_sequence_id` | all 441 gene-CNV samples present among the 452 chr-CNV samples |

## 2. Sequencing

`GenesByNgsSnps` depends on none of the CNV work, so it ships first and the Jenkins halt
blocks only half the effort.

| Phase | Work | Gate |
|---|---|---|
| **1** | `GenesByNgsSnps`: uncomment, repoint params, ontology, live QA | none — HSSS plumbing already deployed |
| **2** | Corrected CNV table SQL proven in the `jbrestel` schema; `apiTuningManager.xml` entries; `webready/*.psql` corrections | — |
| **HALT** | **John builds the tuning tables in Jenkins.** Nothing in phase 3 can be exercised before this. | |
| **3** | Three CNV searches: model XML, ontology, live QA | phase 2's tables |

`jbrestel.*` is a throwaway proof of concept and must never appear in a commit. The
committed model names `apidbtuning.*` (§7).

## 3. The corrected CNV tables

Two logical tables, each defined in two places (§7 explains why):

- transitional: `apidbtuning.GeneCopyNumbers`, `apidbtuning.ChrCopyNumbers`
- permanent: `webready.GeneCopyNumbers_p`, `webready.ChrCopyNumbers_p`

### 3.1 `GeneCopyNumbers`

```sql
SELECT DISTINCT
    ta.project_id
  , ta.org_abbrev
  , ta.organism
  , ta.taxon_id
  , ta.source_id
  , ta.gene_source_id
  , regexp_replace(pan.name, '_GeneCNV$', '') AS eda_sample_stable_id
  , gcn.haploid_number  AS raw_estimate
  , COALESCE(r.ref_cn, 1) AS ref_cn      -- see 3.5, NOT gcn.ref_copy_number
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
```

### 3.2 `ChrCopyNumbers`

```sql
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
```

### 3.3 Changes from today's definitions, and why

1. **The `PANIO_p` join is gone**, along with `input_pan_id` / `output_pan_id`. §1.2.
2. **Organism identity comes from the attribute tables**, carrying `org_abbrev`,
   `organism`, and `taxon_id`. Carrying all three is deliberate: the searches filter on
   `organism` (§4.1) while the permanent partitioned table prunes on `org_abbrev`, and
   nothing should have to translate between them at query time.
3. **New `eda_sample_stable_id`** — the join key the samples filterParam produces. Without
   it every search would have to round-trip through `study.protocolappnode` and re-derive
   the same string.
4. **The `strain` column is retired.** Its derivation,
   `REGEXP_REPLACE(pan.name, '_[A-Za-z0-9]+ (.+)$', '')`, requires a **space** that these
   names never contain, so it is a no-op and `strain` currently holds the un-stripped
   `427_GeneCNV`. `eda_sample_stable_id` replaces it, correctly. The searches' `strains`
   *output* column (the aggregated list of matching samples) is unaffected and keeps its
   name — it is now aggregated from `eda_sample_stable_id`.
5. **The rounding CASE is preserved verbatim**, including its gap at exactly `0.01` (a
   value that falls through to `round()` → `0`). No row currently has that value, so the
   gap is inert; it is kept anyway because a port must not silently change data semantics.
   Both columns are load-bearing: searches *filter* on the rounded `haploid_number` and
   *display* medians of `raw_estimate`.
6. **`ChrCopyNumbers` sources from `GenomicSeqAttributes_p`**, not `TranscriptAttributes_p`
   as today. Chromosome ploidy is sequence-level; reaching through the transcript table for
   it was incidental. `SequencesByPloidy` already reads `GenomicSeqAttributes_p`, so this
   also makes the table and its main consumer agree.

### 3.4 Physical design

| | transitional (`apidbtuning`) | permanent (`webready`) |
|---|---|---|
| partitioning | **none** | partitioned on `org_abbrev` (unchanged) |
| index | btree `(organism, eda_sample_stable_id)` | existing `_ix.psql`, updated to drop `input_pan_id` |

The transitional table is unpartitioned on purpose. `apidbtuning` does support partitioned
tables (`allgeneproducts_p1118`, `profile_p1118` are `relkind='p'`), so this is a choice,
not a limitation: the whole table is ~3.4M rows, every search filters to one organism, and
a composite btree serves that nearly as well as a prune. Partitioning is build complexity
on an object scheduled for deletion in one release (§7).

The two `_ix.psql` files must drop `input_pan_id` from the index definition, since the
column is gone.

### 3.5 `ref_cn` is recomputed from the annotation — a definitional change

Added after implementation, when the fan-out below surfaced in live QA.

`apidb.genecopynumber.ref_copy_number` is **not** usable. Two separate problems:

1. **It is per-sample.** The loader counts only ortholog-group members present in *that
   sample's own result set*, so a partially-covered sample reports fewer. Proven by exact
   match: of the 72 pfal genes in group `OG7_0000041`, sample `B082` has all 72 present and
   stores 72; `D003` 63/63; `G213` 51/51; `M283` 46/46. The 202 fully-covered samples all
   store 72.

   This broke the searches outright. `hit_medians` does `GROUP BY … s.ref_cn`, so a gene
   with several distinct values emitted several rows, and WDK rejected the answer:
   *"Joined attribute query returned a different number of rows (376) than the ID query
   alone (100)"*. 812 pfal genes were affected.

2. **It counts the group genome-wide**, while the attribute's own help text says *"both on
   the same chromosome and in the same ortholog group"*. The stored values only ever matched
   the group-wide count.

So `ref_cn` is computed here instead, from `TranscriptAttributes_p` ⋈
`apidb.orthologgroupaasequence`, restricted to the same chromosome. It is reference-only,
hence constant per gene — the fan-out disappears at source — and it matches the
documentation.

**This moves result sets and was approved deliberately.** `OG7_0000041`'s 72 pfal genes span
13 chromosomes, so its members drop from 72 to 1–12. Roughly a quarter to a half of all rows
change value, and `GenesByCopyNumberComparison`'s entire predicate is
`haploid_number <op> ref_cn`. Verified impact on a 10-sample pfal run: amplified calls move
3,411 → 3,522 (+3%), because 3,933 of 5,285 genes are unchanged either way.

`COALESCE(…, 1)` covers a gene in no ortholog group — 67 in pfal. Note `ref_cn = 1` is also
the *normal* result (89% of pfal genes have no same-chromosome paralog), so a table built
before the orthomcl load would be silently indistinguishable from a correct one for most
rows. The tuningManager copy guards this with an `externalDependency` on
`apidb.OrthologGroupAaSequence`; in the webready copy it is a workflow ordering requirement.

**The loader is still wrong** and worth a separate ticket — every rebuild keeps writing
sample-contaminated values into `apidb.genecopynumber` for anyone else reading it.

## 4. Params

### 4.1 CNV organism: a `queryRef` override, not a new param

The three CNV searches keep using **`organismParams.organismSinglePick`**, overriding its
vocabulary per query:

```xml
<paramRef ref="organismParams.organismSinglePick" queryRef="organismVQ.CNVDnaSeq"/>
```

This is the pattern the original `GenesByNgsSnps` used (`queryRef="organismVQ.withNgsSNPsTree"`).

**It must not be a new param.** `variationParams.eda_sample_table_suffix` and the samples
filterParam both declare `dependedParamRef="organismParams.organismSinglePick"` and
interpolate `$$organismSinglePick$$`. A genuinely new organism param would leave that chain
pointing at a param the query no longer has, so the samples filter would silently never
scope to the chosen organism.

`organismVQ.CNVGene` / `organismVQ.CNVChr` (two, see below) return `term` = **scientific name**, matching
`organismSinglePick`'s convention. The dead `organismVQ.CNV` returned
`string_agg(o.abbrev)` — a comma-joined list of abbreviations — which is a second reason
nothing downstream lined up. It lists organisms that actually have CNV rows, so an organism
that would return nothing is not selectable.

### 4.2 Add

| item | file | notes |
|---|---|---|
| `organismVQ.CNVDnaSeq` | `organismParams.xml` | §4.1 |
| `variationParams.cnv_sample_meta` | `variationParams.xml` | same `metadataQueryRef` / `backgroundQueryRef` / `ontologyQueryRef` and `dependedParamRef` as `variation_sample_meta`; prompt `Strain/Sample` |

`cnv_sample_meta` deliberately has **no `minSelectedCount`**. `variation_sample_meta`
requires 2 because polymorphism within a group of one is undefined; a copy-number query on
a single sample is perfectly meaningful.

It is a separate param rather than a reuse of `variation_sample_meta` because that name is
a contract with `FindPolymorphismsPlugin.getStrainFilterParamName()`, and because the two
differ in `minSelectedCount`. WDK clones a dependent param's queries per param, so sharing
the three query definitions costs nothing — the same arrangement `variation_sample_meta_a`
and `_b` already use.

### 4.3 Retire

| item | file | reason |
|---|---|---|
| `organismParams.organismSinglePickCnv` | `organismParams.xml` | only consumer is the CNV searches |
| `organismVQ.CNV` | `organismParams.xml` | returns **0 rows** — no datasource matches `%copynumbervariations_%`; CNV now rides `isolates`/`Dna_Seq` |
| `sharedParams.CNV_strain` | `sharedParams.xml` | reads tables that do not exist |
| `SharedVQ.CnvSamplesMetadataByOrganism` | `sharedParams.xml` | reads `apidbTuning.Metadata` — **table does not exist** |
| `SharedVQ.CnvMetadataSpecByOrganism` | `sharedParams.xml` | reads `apidbTuning.Ontology` — **table does not exist** |

Before removing each, confirm no other consumer with a search of the assembled model, not a
`grep` of the source — `grep` matches inside comment blocks, which is how the snp import was
previously misread.

### 4.4 Reuse unchanged

All fourteen supporting params were verified live in the assembled model and need no work:

- `geneParams`: `snp_class`, `occurrences_lower`, `occurrences_upper`, `dn_ds_ratio_lower`,
  `dn_ds_ratio_upper`, `snp_density_lower`, `snp_density_upper`, `copyNumber`, `CNV_type`,
  `operator`, `comparisonOperator`, `medianOrIndividual`
- `genomicParams`: `chrCopyNumber`, `medianOrIndividual`

### 4.5 `GenesByNgsSnps` param repointing

`snpParams` is absent from the assembled model, so every `snpParams.*` ref must move to its
`variationParams` twin — which exists precisely because of this (see the variation searches
spec, §4.4):

| was | becomes |
|---|---|
| `snpParams.WebServicesPath` | `variationParams.WebServicesPath` |
| `snpParams.ReadFrequencyPercent` | `variationParams.ReadFrequencyPercent` |
| `snpParams.MinPercentMinorAlleles` | `variationParams.MinPercentMinorAlleles` |
| `snpParams.MinPercentIsolateCalls` | `variationParams.MinPercentIsolateCalls` |
| `snpParams.ngsSnp_strain_meta` | `variationParams.variation_sample_meta` |
| `organismSinglePick` + `queryRef="organismVQ.withNgsSNPsTree"` | `organismSinglePick` + `queryRef="organismVQ.withVariationsTree"` (swap the override, do **not** drop it) |

The strain-filter repoint is not a preference: `FindGenesWithSnpCharsPlugin extends
FindPolymorphismsPlugin`, so it inherits `getStrainFilterParamName()` returning
`variation_sample_meta`. The XML param name must equal that string or the search fails at
run time, not build time.

`organismVQ.withNgsSNPsTree` reads `apidbtuning.snpstrains`, which does not exist in this
build. The replacement is `organismVQ.withVariationsTree` — what the four working variation
`processQuery`s use (`variationQueries.xml:44, 87, 127, 170`).

**Do not drop the override entirely.** Plain `organismSinglePick` falls back to
`organismVQ.withGenes`, i.e. every annotated organism in the project. Choosing one with no
dnaseq study makes `eda_sample_table_suffix` return zero rows, so the samples filter has
nothing to render and the search breaks rather than returning an empty result.
`withVariationsTree` restricts to organisms having an `isolates`/`Dna_Seq` datasource.

## 5. Queries

### 5.1 `GeneId.GenesByNgsSnps` (`geneQueries.xml`)

Uncomment the `processQuery`; apply §4.5. Everything else stands:

- the three `postCacheUpdateSql` blocks read `webready.TranscriptAttributes_p` (healthy) and
  `%%PARTITION_KEYS%%`, which the webapp's partition layer substitutes at run time;
- the eleven `wsColumn` declarations are the plugin's own output contract and are unchanged;
- `processName` stays `…highspeedsnpsearch.FindGenesWithSnpCharsPlugin`.

Drop the `testParamValues` blocks naming `ngsSnp_strain_meta` — the param no longer exists
under that name, and their values are old strain names rather than EDA sample stable IDs.

### 5.2 `GeneId.GenesByCopyNumber` and `GenesByCopyNumberComparison` (`geneQueries.xml`)

Both share one `bySample` CTE; the edits are identical in each.

| was | becomes |
|---|---|
| `FROM webready.GeneCopyNumbers_p g, webready.ChrCopyNumbers_p c` | `FROM apidbtuning.GeneCopyNumbers g, apidbtuning.ChrCopyNumbers c` |
| `c.output_pan_id IN ($$CNV_strain$$)` | `c.eda_sample_stable_id IN ($$cnv_sample_meta$$)` |
| `g.input_pan_id = c.input_pan_id` | `g.eda_sample_stable_id = c.eda_sample_stable_id` |
| `g.org_abbrev = $$organismSinglePickCnv$$` / `c.org_abbrev = …` | `g.organism = $$organismSinglePick$$` / `c.organism = …` |
| `g.strain` (in the `string_agg`) | `g.eda_sample_stable_id` |

`g.na_sequence_id = c.na_sequence_id` is retained. Together with the sample equality it
reproduces exactly what the `input_pan_id` join meant: *the same sample's ploidy for the
chromosome this gene sits on*.

The `medians` / `hit_medians` CTEs, the `percentile_cont` aggregates, the `CASE` gates on
`$$CNV_type$$` / `$$operator$$` / `$$medianOrIndividual$$` / `$$comparisonOperator$$`, and
the fifteen output columns are all unchanged.

### 5.3 `SequenceIds.ByCopyNumber` (`genomicQueries.xml`)

This one reads base tables today and never touched `ChrCopyNumbers_p`. Move it onto
`apidbtuning.ChrCopyNumbers` so the three CNV searches share one definition of what a
sample and a ploidy are, and so it stops carrying its own copy of the broken `strain` regex:

| was | becomes |
|---|---|
| `FROM apidb.chrcopynumber ccn, study.protocolappnode pan, webready.GenomicSeqAttributes_p sa` | `FROM apidbtuning.ChrCopyNumbers c` |
| `ccn.protocol_app_node_id IN ($$CNV_strain$$)` | `c.eda_sample_stable_id IN ($$cnv_sample_meta$$)` |
| `string_agg(REGEXP_REPLACE(s.name, '_[A-Za-z0-9]+ (.+)$', ''), ', ' …)` | `string_agg(c.eda_sample_stable_id, ', ' …)` |
| *(no organism filter — it had none)* | `c.organism = $$organismSinglePick$$` |

Adding the organism filter is a **behaviour fix, not a regression**: the query previously
constrained organism only implicitly, through `CNV_strain`'s organism-scoped vocabulary. With
the sample list now coming from an EDA study, the constraint must be explicit or a sample
name colliding across organisms would leak rows.

## 6. Questions and categorization

### 6.1 `GenesByNgsSnps` (`geneQuestions.xml`)

Uncomment. Keep `displayName`, `shortDisplayName`, both project-scoped `<description>`
blocks, the `attributesList`, and all eight `dynamicAttributes`. Remove the deprecated
`<propertyList name="organism">` blocks — the file's own comment marks them deprecated and
they encode a fixed organism list this search no longer needs.

`searchCategory="Population Biology"` is retained.

### 6.2 `GenesByCopyNumber` / `GenesByCopyNumberComparison` (`geneQuestions.xml`)

Both have their `attributesList` **commented out**, so ten CNV columns are declared in
`dynamicAttributes` and never shown — the searches return bare gene rows. Restore it with
the CNV columns only:

```xml
<attributesList
  summary="strains,ref_cn,median_raw_hits,median_haploid_hits,median_ploidy_hits,median_gene_dose_hits"
  sorting="median_haploid_hits desc"/>
```

The `sorting` attribute is **new** — the commented original carried none, and an unsorted
copy-number result is not useful. `median_haploid_hits desc` puts the highest-amplification
genes first, which is what the search is usually asked for. It is a judgment call, not a
restoration; change it freely if the biologists prefer another default.

The commented original also named `gene_product`, `chromosome`, and `orthomcl_link`. All
three were verified to exist on `TranscriptRecordClass` (`transcriptRecord.xml:339`, `:327`,
`:869`), so their absence here is a **deliberate choice to keep the summary to what the
search is about**, not a workaround for missing attributes. Recorded so it is not
re-litigated as an oversight.

The `_all` variants (`median_raw_all`, `median_haploid_all`, `median_ploidy_all`,
`median_gene_dose_all`) stay declared but out of the default summary, as in the original.

### 6.3 `SequencesByPloidy` (`genomicQuestions.xml`)

Params only (§4, §5.3). `attributesList`, `dynamicAttributes`, `summary`, and `description`
are unchanged.

### 6.4 `individuals.txt`

| line | action |
|---|---|
| 99 `GeneQuestions.GenesByNgsSnps` | already live and correct — becomes non-orphaned once §6.1 lands |
| 100 `GeneQuestions.GenesByCopyNumber` | uncomment (`##` → live) |
| 101 `GeneQuestions.GenesByCopyNumberComparison` | uncomment |
| 138 `GenomicSequenceQuestions.SequencesByPloidy` | uncomment **and** move `topic_0219`/`Curation and Annotation` → `topic_0199`/`Genetic Variation` |

All five variation searches sit under `topic_0199`, so this puts all eight dnaseq searches
in one menu section.

Build target is **`wb ontology`**, not `wb model` — categorization changed. `wb ontology` is
a superset of `wb model`, so it is the single call for both phases.

## 7. The transitional tables, and their sunset

The webready tables are built per organism by the workflow, which has already completed for
this release. Rather than block on a workflow re-run, the corrected definitions land in two
places:

1. **`apiTuningManager.xml`** gains `GeneCopyNumbers` and `ChrCopyNumbers` tuning tables
   (§3), buildable now via Jenkins. The committed model XML references these.
2. **`webready/orgSpecific/*.psql`** (4 files: two definitions, two indexes) are corrected
   to match, taking effect at the next workflow run.

Both are written from SQL already proven in the `jbrestel` schema (§2), so they are two
copies of a verified definition rather than two guesses.

**Sunset, one release later** — this is a scheduled deletion, not an aspiration:

- delete the two `<tuningTable>` entries from `apiTuningManager.xml`;
- repoint **five** references from `apidbtuning.X` to `webready.X_p`: the three queries (§5.2 ×2, §5.3) **and** the two organism vocabularies `organismVQ.CNVGene` / `organismVQ.CNVChr`, which also name the transitional tables;
- change the organism predicate from `organism = …` back to `org_abbrev = …` **only if**
  partition pruning measures better than the composite index — the `organism` column is
  carried on the webready table too (§3.3), so no schema change is required either way.

Each of the two definition sites must carry a comment naming the other and naming this
section, so an edit to one cannot silently diverge from the other during the release they
coexist.

## 8. Verification

### 8.1 Phase 1 — `GenesByNgsSnps`

1. `bin/veup-build.sh plasmodb wb ontology`
2. `/service/record-types/transcript` → confirm `GenesByNgsSnps` in `searches`. This, not
   the category tree, is the source of truth for "does this site have the search" — the
   tree is not project-filtered.
3. `/service/ontologies/Categories` → confirm it sits under the `Genetic Variation` node.
4. Run it live in the app with a small sample set; confirm non-zero results and populated
   SNP-characteristic columns. This also exercises the HSSS `/dnaseq` directory and the
   `Variant_` ID work end to end.

### 8.2 Phase 2 — CNV tables

1. Build both tables in the `jbrestel` schema from §3's SQL.
2. Parity checks against the base tables:
   - every one of `apidb.genecopynumber`'s 3,389,444 rows is represented — none dropped by
     the join. The join fans out to 3,404,180 rows because a gene may have several
     transcripts, and `SELECT DISTINCT` then collapses rows identical across all selected
     columns, so the final count sits at or below 3,404,180 and **above** 3,389,444 is not
     expected. Assert no base row is lost, rather than asserting an exact total.
   - the `gene_type IN ('protein coding', 'protein coding gene')` filter currently removes
     **nothing** (3,404,180 both with and without it). It is retained because it is the
     original definition's semantics, but a parity check must not treat it as load-bearing.
   - chr-CNV = 4,936 rows exactly (no fan-out — the join is on `na_sequence_id`).
   - `eda_sample_stable_id` distinct counts 441 (gene) / 452 (chr), with all 441 present
     among the 452.
3. Spot-check the rounding CASE: rows below `0.01`, between `0.01` and `1.85`, and above.
4. `EXPLAIN (ANALYZE)` the `bySample` CTE at 10 / 50 / all samples and confirm the index is
   used. Baselines measured on base tables for pfal3D7: 218 ms / 986 ms / 4.1 s.

### 8.3 Phase 3 — CNV searches

Live QA is only possible after the Jenkins build. Before it:

```
ssh <host> 'bash -lc "source <docroot>/../etc/setenv && \
  wdkQuery -model $(python3 bin/resolve.py --profile profiles/plasmodb.yml --field model) \
    -query GeneId.GenesByCopyNumber -showQuery"'
```

Take the rendered SQL, repoint `apidbtuning.` → `jbrestel.`, and run it read-only in psql.
Repeat for `GenesByCopyNumberComparison` and `SequenceIds.ByCopyNumber`. This verifies the
SQL WDK actually assembles, which the raw model XML does not show.

After the Jenkins build: run all three live, confirming the organism dropdown is populated
(the old vocab returned zero rows), the samples filter tree renders from EDA, and the
restored CNV columns appear in the results table.

Note the appDb tunnel target moves between sessions — confirm the database and port before
querying rather than reusing a previous session's.

## 9. Accepted tradeoffs

Recorded as decisions with reasons, so they read as intent:

1. **The shared dnaseq param trio stays in `variationParams.xml`.** The organism →
   `eda_sample_table_suffix` → samples-filter chain will serve eight searches across three
   record classes (`variation`, `transcript`, `genomic sequence`), and a genomic-sequence
   ploidy search referencing a paramSet named `variationParams` is a naming lie. Promoting
   it to a neutral file was considered and rejected for this spec: it would mean renaming
   `paramRef`s in five searches that currently work, and the naming cost is cosmetic while
   the regression risk is not. Revisit if a fourth record class joins.

2. **The transitional tuning tables create a one-release cleanup.** §7 schedules it
   explicitly, because "trivial cleanup next release" is how permanent tables are born.

3. **Select-all remains slow.** ~4.1 s at 216 samples here; production pfal has ~538 strains
   in the HSSS directories, extrapolating to roughly 10 s. The tuning table narrows this but
   cannot remove it — the aggregation reads the same row volume either way. Accepted as a
   tail case: CNV searches are normally run on a handful of samples. If it becomes a real
   complaint, the fix is a materialized per-organism median, not a different table layout.

4. **`GenesByNgsSnps` gets no `minSelectedCount` change.** It inherits
   `variation_sample_meta`'s minimum of 2, which is correct for it — SNP characteristics are
   computed from differences *between* selected samples.

## 10. Out of scope

- `GeneQuestions.GenesBySnps` (`individuals.txt:116`) — a second orphaned ontology row for a
  question the model does not define. Harmless; it belongs to the older, non-HTS snp search
  and has no port target in this spec.
- The `FindChipPolymorphismsPlugin` / `FindChipSnpMajorAllelesPlugin` chip searches, still
  pointing at `/highSpeedChipSnpSearch`. Equally dead, deliberately untouched.
- Re-running the workflow to populate `webready.*_p`. §7 is precisely the arrangement that
  avoids needing it.
