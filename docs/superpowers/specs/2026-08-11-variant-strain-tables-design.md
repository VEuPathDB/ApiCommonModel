# Variant record: per-strain tables read directly from the merged VCF

Date: 2026-08-11
Status: design approved, not yet implemented
Repos touched: `ApiCommonWebService`, `ApiCommonModel`, `web-monorepo`

## 1. Purpose

The Variant record page currently describes a locus in aggregate — allele frequencies,
call rates, strain counts — but offers no way to see *which* strain carried *what*. The
legacy SNP record did, via three SQL-backed tables over loaded data.

This spec rebuilds that capability **without loading anything**, by reading the merged
annotated VCF at request time. The file is already published per organism for JBrowse;
nothing new has to be produced, loaded, or kept in sync.

Three deliverables:

| # | Deliverable | Grain |
|---|---|---|
| A | `VariantStrains` table | one row per VCF sample |
| B | `VariantCountrySummary` table | one row per country |
| C | Strain filter on the record page | EDA metadata only |

## 2. The enabling mechanism, and why it is free

A WDK record table can be backed by a **`processQuery`** rather than a `sqlQuery` — a
WSF plugin whose Java produces the rows. `StubSnpsByGene` demonstrates the pattern:

- `ApiCommonModel/Model/lib/wdk/model/records/geneRecord.xml:755` — the `<table>`
- `.../records/geneTableQueries.xml:187` — the `<processQuery>`
- `ApiCommonWebService/.../wsfplugin/tablequeries/SnpsByGene.java` — the plugin

The plugin's required params are `PRIMARY_KEY_PARAM_NAME` and `TABLE_NAME_PARAM_NAME`,
both supplied by WDK; it resolves PK column names off the record class.

**These record-page tables are not cached.** This was checked carefully because it
determines whether the design is viable at all:

- `SingleRecordAnswerValue.getTableFieldResultList()` (`WDK/.../answer/single/SingleRecordAnswerValue.java:159`)
  routes a table field with no SQL query to `TableFieldProcessQueryResult`.
- `TableFieldProcessQueryResult.getResultList()` ends in `queryInstance.getUncachedResults()`,
  which invokes the plugin and collects into an in-memory `ArrayResultList`.
- `DynamicTableValue.java:68` routes the same way, so it holds from both entry points.
- `SingleRecordAnswerValue` overrides `cacheInitiallyExistedForSpec()` to `return false`,
  commented *"does not use WDK cache"*.

So no `QueryResult<N>` table is created, no DDL runs on page view, and there is nothing
to evict. Note this is **specific to record tables**: `ProcessQueryInstance.getResults()`
is a bare `return getCachedResults(...)`, and `ProcessQuery.isCacheable()` is a hardcoded
`return true` with no XML override. A process query reached any other way *does* cache.

Deliverable C avoids the question entirely by being backed by a `SqlQuery`, whose
`isCacheable()` honours both the global switch and an XML attribute.

## 3. Architecture

Four components in `ApiCommonWebService`, only the last two aware of WDK:

```
VariantStrainsPlugin        VariantGroupSummaryPlugin      (WSF plugins, thin)
            \                        /
             \                      /
          VariantLocusComposer  — joins calls to metadata, aggregates
             /                      \
            /                        \
   MergedVcfReader              SampleMetadataLookup
   + CannIndex                  (EDA EAV query)
   (htsjdk + tabix)
```

- **`MergedVcfReader`** — `(vcfPath, sequenceId, position)` → `List<SampleCall>{ name,
  gt, dp, alleles, readFrequency, caKeys, isCoverageFilled }`. One tabix seek. No WDK
  types, so it unit-tests against a fixture VCF with no database and no container.
- **`CannIndex`** — parses the INFO `CANN` string into `key → {codon, aa, effect,
  transcriptId, posInCds, posInCodon, hgvsC, hgvsP}` and resolves a sample's `CA` value
  to amino acids. Pure string handling.
- **`SampleMetadataLookup`** — `sample_stable_id → attribute values`, one query against
  `eda.attributevalue_<suffix>`.
- **The two plugins** — shape composed data into rows and nothing else.

**The join and the aggregation happen in Java**, over ~537 rows per locus. This is
deliberate. A cache-table join was considered and rejected: no `<sqlQuery>` can name
another query's cache table (the only cache macros, `##WDK_CACHE_TABLE##` and
`##WDK_CACHE_INSTANCE_ID##`, are valid solely inside a `PostCacheUpdateSql`), the table
name is per-instance (`ResultFactory.getCacheTableName(instanceId)` → `QueryResult<N>`),
and — decisively — record tables are uncached, so there is no cache table to join to.

**Rule:** `MergedVcfReader` returns domain objects, never rows into a `PluginResponse`.
Deliverables A and B share one composer; a future REST-backed interactive section must be
able to consume the same layer without a plugin in the path.

## 4. Locus and file resolution

The plugin receives only the primary key (`source_id`, `project_id`). One SQL against the
variant tuning table keyed on `source_id` yields:

- `sequence_source_id` and `location` — the tabix coordinate. Both are already first-class
  non-internal attributes on the record, added for exactly this purpose (see the comment
  block at `variantRecords.xml:68`).
- the organism's `name_for_filenames`
- the EDA sample table suffix — adapting `EdaSampleTableSuffix`
  (`variantParams.xml:399`), keyed on the variant's organism rather than a picked one.

The VCF path is then:

```
${WEBSERVICEMIRROR}/${projectId}/build-${buildNumber}/${nameForFiles}/dnaseq/vcf/merged.ann.vcf.gz
```

All three values come from `WdkModel` — `getProperties().get("WEBSERVICEMIRROR")`,
`getProjectId()`, `getBuildNumber()` — the same way `JBrowseService` resolves them.

Deliberately **not** via a `WebServicesPath` param as the HSSS plugins use
(`HighSpeedSnpSearchAbstractPlugin.PARAM_WEBSVCPATH`, internal value
`@WEBSERVICEMIRROR@/PROJECT_GOES_HERE/build-<N>`): a record table has no param UI to hang
one on, and the `PROJECT_GOES_HERE` substitution exists only to work around that.

## 5. VCF semantics that the composer must honour

These are properties of `dnaseq-nextflow/bin/processSequenceVariations.jl`, which writes
the file. Getting any of them wrong yields numbers that silently disagree with the
attributes displayed in the overview panel on the same page.

### 5.1 `CANN` / `CA` — the annotation indirection

`CANN` is an **INFO** field: comma-separated entries of
`key|codon|aa|effect|transcript_id|pos_in_cds|pos_in_codon|hgvs_c|hgvs_p`. `r`-prefixed
keys describe reference alleles per transcript, `k`-prefixed the alt alleles.

`CA` is a **FORMAT** field naming the CANN key(s) for that sample's genotype. Alleles are
separated by `/` (unphased) or `|` (phased); multiple transcript keys for one allele are
separated by `;`. Bare `r` means "reference allele, no CDS annotation"; `.` means missing.

So a sample's amino acid is `CA` → `CANN` lookup → field 3. A sample can legitimately
resolve to several amino acids when the locus sits in a multi-transcript gene.

### 5.2 Coverage-filled reference calls

`fill_missing_coverage_gt` (`processSequenceVariations.jl:2452`) rewrites every missing
genotype whose position `coverage.tsv` reports as covered: `GT = "0"` (or `0/0` at ploidy
2), `DP = round(coverage)`, **every other FORMAT field `.`**. `handle_variant_record!:2711`
passes this modified data to `write_vcf_entry`, so these calls are present in the
published VCF.

Two consequences:

- A remaining `.` genotype means genuinely **no coverage**, matching the record's
  `no_call_strain_count`. Measured at 16.3% of genotypes over 1500 loci × 537 samples.
- A coverage-filled row has **no `AO`/`RO`**, so read frequency cannot be computed from
  it. The pipeline's own synthesized `Variation` sets `percent = "100"`
  (`processSequenceVariations.jl:1459`). Filled rows must therefore render read frequency
  as **100%**, not 0 and not blank. They are distinguishable from real reference calls,
  which carry real `AO`/`RO`.

### 5.3 Allele rendering is IUPAC

`gt_to_base` (`processSequenceVariations.jl:1335`):

- homozygous or single present allele → that allele
- het of exactly two single-character SNP alleles → **IUPAC ambiguity code**
- complex or higher-order het → the first non-ref allele
- missing → empty

This is the convention the loaded attributes already use, and it keeps a diploid call on
one row, which is a requirement (§6).

### 5.4 Frequencies are chromosome-weighted

`aggregate_locus_alleles` (`processSequenceVariations.jl:1820`) adds weight **1 per
chromosome slot per strain**, so a het diploid contributes 1 to each of two alleles, and
the denominator is `Σ per-strain ploidy` — not a strain count. Formatted `%.4f`.

For haploid *P. falciparum* this coincides with strain counts; on aneuploid TriTryp and
Fungi organisms it does not, and a strain-count implementation would silently diverge
there.

Ranking for major/minor: `sort by (-weight, allele, ref span)` — deterministic. The
reference competes for a class's major/minor slot, but **only when that class actually has
an alt allele**, and is matched to the SNP or indel class by its ref-string.

### 5.5 Read frequency

`compute_percent` (`processSequenceVariations.jl:1394`) is `AO/(RO+AO)*100` at `%.2f`,
taking the first non-ref slot. For a reference slot in a strain that also carries an alt,
the reference's percentage is `100 − altfrac`.

## 6. Deliverable A — `VariantStrains`

One row per VCF sample, **single row regardless of ploidy**.

| Column | Source |
|---|---|
| Strain | VCF sample name (= EDA `sample_stable_id`) |
| Country | EDA, joined in Java |
| GT | raw genotype string — `0`, `0/1` |
| Allele | §5.3 — IUPAC for hets |
| DP | FORMAT `DP` |
| Read Frequency | §5.5, or 100% for coverage-filled rows (§5.2) |
| AAProduct | `CA` → `CANN` → distinct amino acids, comma-joined |

**All samples get a row, including no-calls.** A `.` genotype renders as "No call" with
empty DP/Allele/AAProduct. The record already advertises `no_call_strain_count`, so a
table that silently omits them would contradict the panel above it.

**AAProduct collapses to distinct amino acids.** A sample's `CA` can name several
transcripts; since `TranscriptProducts` already gives per-transcript detail, this table
stays one-row-per-strain and joins distinct values with a comma.

The VCF sample names are EDA `sample_stable_id`s directly — established in
`2026-08-05-hsss-variation-plumbing-design.md` §6 and unchanged. No mapping layer.

## 7. Deliverable B — `VariantCountrySummary`

One row per country, following legacy `CountrySummary` (`snpRecords.xml:419`).

| Column | Meaning |
|---|---|
| Country | the EDA attribute named in §7.1 |
| #Strains | genotyped strains from that country |
| Major Allele | allele + frequency |
| Minor Allele | allele + frequency |
| Other Allele | allele + frequency |

**Only samples with a Country value are included.** Samples lacking one are excluded
entirely, and so is the reference strain, which has no collection site in EDA (see the
comment block at `variantParams.xml:476`).

**Frequencies are computed within each country's own genotyped chromosomes**, weighted per
§5.4. This makes each row independently interpretable — "in Mali, 80% of chromosomes carry
C". It also means these frequencies **deliberately do not match** the locus-wide
`snp_major_allele_frequency` in the overview panel; the column help must say so, or the
apparent contradiction will read as a bug.

Because samples without a country are dropped, the per-country strain counts will not sum
to the record's `called_strain_count`. The table must state how many samples were excluded
for lack of a country, or the shortfall reads as data loss.

### 7.1 The grouping attribute is declared, not hardcoded

The attribute is named in model XML so other sites can point at their own without a code
change. Hardcoding a per-instance identifier into shared model XML is the failure mode the
dataset-gate notes in `CLAUDE.md` warn about.

**Key on `provider_label`, not `stable_id`.** EDA `stable_id`s are `VAR_<hash>` digests of
the provider label — stable per label, but the label itself is site-specific. Same
reasoning `SamplesMetadataByStudyWithRef` records for its own attribute matching.

The value is **`["country"]`**; its `display_name` is the lowercase `country`.

**Not `geographic_location`, which is what legacy used.** Both attributes exist in the
*P. falciparum* dnaseq study (`s3be28bbe14_sample`), so a naive port would have taken the
wrong one:

| provider_label | display_name | samples with a value | distinct values |
|---|---|---|---|
| `["country"]` | country | **536 / 537** | 20 |
| `["geographic_location"]` | Geographic location | 111 / 537 | 10 |
| `["collection_site"]` | Collection site | 180 / 537 | 5 |

The EDA study holds exactly 537 samples, matching the VCF's 537 sample columns. The single
sample with no country is `707A`. Top countries: Thailand 181, French Guiana 169,
Senegal 70, Gambia 65, Mali 23, Uganda 11.

### 7.2 Not every organism has the attribute, and there is no fallback

**14 of the 62 dnaseq EDA studies have no `["country"]` attribute at all** — not null
values, but no row in `eda.attributegraph_<suffix>`. On PlasmoDB these are the rodent
malaria lines (*P. chabaudi*, *P. vinckei*, *P. yoelii*); elsewhere *L. major*,
*L. mexicana*, *L. braziliensis*, the three *T. cruzi* assemblies, *T. brucei gambiense*,
*T. evansi*, *Crithidia fasciculata*, *S. cerevisiae* S288C, and *Coccidioides immitis*.

**A fallback to `geographic_location` or `collection_site` is deliberately not built.** 13
of those 14 studies have no geography attribute of any kind. The exception, *P. yoelii*
17X, has a `geographic_location` attribute whose only populated value across 6 samples is
`Lowlands West and Central Africa` — not a country and not aggregatable. A fallback chain
would rescue nothing while adding a branch that silently changes what the column means.

These are lab lines and reference assemblies with no collection geography, which is normal.
Most hold 1–14 samples; the one substantial study is *S. cerevisiae* S288C at 230.

So table B renders as **empty, without error**, when the organism's study has no country
attribute — the same way an absent merged VCF yields an empty table (§9).

## 8. Deliverable C — the record-page strain filter

A port of the legacy SNP record's mechanism, which is four pieces:

| Piece | Legacy location | Ours |
|---|---|---|
| No-op id query hosting the params | `geneQueries.xml:6051` `SnpAlignment.SnpAlignmentForm` — `SELECT '' as source_id, '' as project_id WHERE 1 = 0`; **commented out** | new `VariantAlignment.VariantAlignmentForm` |
| Question | `geneQuestions.xml:6305`; also commented out | `VariantAlignmentForm` |
| filterParam | `snpParams.ngsSnp_strain_meta` | new `variant_strain_meta` |
| Render anchor | `snpRecords.xml:244` `<textAttribute name="snps_alignment_form">` | textAttribute on `VariantRecordClass` |
| Client component | `genomics-site/.../records/SnpRecordClasses.SnpRecordClass.jsx` + `common/Snps.jsx` — `RecordAttributeSection` intercepts the attribute name and renders `<FilterParamNew>` | `VariantRecordClasses.VariantRecordClass.jsx` |
| Question loader | `storeModules/Record.js:275` `observeSnpsAlignment` — epic on `RECORD_UPDATE` dispatching `updateActiveQuestion` with `initialParamData: { organismSinglePick, ngsSnp_strain_meta: '{"filters":[]}' }` | a variant branch in the same epic |

Written fresh in the variant files rather than uncommenting the snp ones: `snpParams.xml`
is imported inside the commented-out snp block in `apiCommonModel.xml` and is unimported
dead code (see `2026-08-06-genetic-variation-searches-port-design.md` §4.4).

`variant_strain_meta` points at **`SamplesMetadataByStudy`**, not the `WithRef` variant the
searches use. `WithRef` synthesizes a reference-strain row because HSSS carries it as
strain id 1; here the filter selects VCF samples, and `3D7_WTSI` — a real resequenced
isolate — is in the VCF while the reference itself is not a sample column. Offering it
would be an option with no corresponding row, the same reasoning `cnv_sample_meta` already
records.

The form's submit target is **out of scope**. Legacy POSTed `filter_param_value` to
`/cgi-bin/isolateAlignment`; the MSA now lives in SequenceRetrievalTool and wiring it is a
separate, small piece of work once this lands.

### 8.1 Two traps

- `Snps.jsx` opens with `if (questionStatus != 'complete') return null`. If the epic does
  not fire, the section renders **blank, with no error anywhere**.
- `organismSinglePick` is a depended param of the filter, and a record page has no organism
  picker. The epic seeds it from the record's own `organism_text`, which the variant record
  also carries.

## 9. Error handling

| Condition | Behaviour |
|---|---|
| No merged VCF for the organism | Empty table, no error. Not every organism has a merged call set; `JbrowseOrgSpecificNaTracks.pm:856` already treats absence as normal and silent, and the table should agree. |
| VCF present, `.tbi` absent | **Hard failure.** Streaming 809 MB per page view is not a fallback. |
| Locus not found in the VCF | Empty table. A record whose locus is absent from the call set is a data inconsistency worth surfacing in logs, not a page error. |

## 10. Testing

- **Unit** — `CannIndex` against fixture `CANN`/`CA` strings, including multi-transcript
  `;` keys, phased `|`, bare `r`, and `.`. `MergedVcfReader` against a small fixture VCF
  committed to the repo, carrying the same header quirks as the real file (§11).
- **Composer** — frequency arithmetic against a hand-computed fixture covering: haploid,
  diploid het, coverage-filled reference, missing genotype, and a sample with no country.
- **Integration** — verified on the running instance via the record page and
  `/service/record-types/variation`.

`wdkQuery -showQuery` does **not** apply: a process query has no SQL to render, so the
usual `sqlQuery` verification step is unavailable here.

## 11. Risks

**The VCF header is under-declared.** It declares only `CANN`, `CA`, and `DFS`. There is
no `##FORMAT=<ID=GT>`, no `DP`, no `AD/RO/QR/AO/QA`, and no `##contig` lines. Every INFO
field additionally begins with a bare `.` (`.;CANN=...;ANN=...`) — a dangling flag key.
htsjdk's `VCFCodec` is strict about undeclared keys.

**The first implementation task is a spike** that parses the real file with htsjdk and
establishes what it does with these. If it throws, the choice is a lenient codec, a
`VCFHeader` repaired in code, or a fix in the pipeline that writes the header. This is an
afternoon's work up front versus a blocked build later.

**htsjdk resolves version-less.** `ApiCommonWebService/WSFPlugin/pom.xml:76` declares
`com.github.samtools:htsjdk` with no `<version>`, and `ApiCommonWebService/pom.xml`'s
`dependencyManagement` does not manage it, so it must come from the parent
`org.gusdb:gus-project-pom:1.0.0`. Confirm `5.0.0` resolves — or add it — before writing
plugin code; a version-less dependency that fails to resolve is a confusing first failure.

**Per-request latency is by design.** Every page view performs one tabix seek and one EDA
query. There is no caching (§2), which is the point, but it should be measured once the
table is live.

## 12. Out of scope

- User-selectable metadata columns and user-driven aggregation. Deferred; §3's layering
  exists so a REST-backed interactive section can consume the composer later without a
  rewrite.
- Per-row checkbox selection.
- Wiring the filter to SequenceRetrievalTool.
- Strain sequence reconstruction for MSA. These strains have no assembled sequence — they
  exist only as calls against the reference — so aligning them requires applying genotypes
  to the reference FASTA. Its own project.
