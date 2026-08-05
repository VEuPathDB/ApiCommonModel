# Variation record — design

**Date:** 2026-07-30
**Status:** approved (attributes and record-page tables)
**Scope:** WDK record class, attributes, tuning table, and record-page tables for a new
`variation` record. **Searches (questions) are out of scope** — a separate spec.
**Implementation target:** `ApiCommonModel` (branch `dnaseq-merge-experiments`)

## 1. Purpose

Introduce a `variation` record representing a **single variant locus** — one
(sequence, position) pair — uniquely identified by `source_id`. It replaces the
deprecated `snp` record, which is not merely unused but **unbuildable**: its sole
backing relation `apidbtuning.SnpAttributes` does not exist in the current build, and
the per-strain table it depended on (`apidb.SequenceVariation`) has 0 rows.

The new record is deliberately **aggregate-only**. Per-strain allele data is too large
for a relational table and lives in VCF files; see §9 for how the record is shaped to
accept it later without being reshaped.

## 2. Data sources

Base tables from
`ApidbSchema/Main/lib/sql/apidbschema/Postgres/createVariationTables.sql`.
Row counts and cardinalities below were measured against `unidb_shu_a` on 2026-07-30.

### `apidb.VariationFeature` — 4,390,908 rows
One row per locus. PK `(sequence_source_id, location)`, `UNIQUE (source_id)`.
Already record-shaped, which is what makes the hybrid sourcing rule in §3.1 viable.

`source_id` format: `Variant_<sequence_source_id>_<location>` (e.g.
`Variant_Pf3D7_01_v3_29514`).

Carries **two parallel allele summaries** — 9 `snp_*` columns and 10 `indel_*` columns
(19 in total; `indel_frame_effect` has no SNP counterpart) — plus locus-level call
statistics.

| `variant_type` | `is_coding=0` | `is_coding=1` | populates |
|---|---|---|---|
| `SNV` | 2,350,257 | 1,649,759 | `snp_*` only |
| `INDEL` | 232,957 | 28,085 | `indel_*` only |
| `MIXED` | 116,786 | 13,064 | **both** |

The 129,850 `MIXED` loci describe the same strains two ways. Example
`Pf3D7_01_v3:12` — SNP view: major `A`, minor `C`; indel view: major `A`, minor `AC`.
This is why §6 keeps two named sections rather than collapsing.

Observed data note: `snp_major_genomic_hgvs` / `indel_major_genomic_hgvs` are null
whenever the major allele equals the reference, which was true at every sampled locus.
The `*_minor_genomic_hgvs` columns are the ones that reliably carry content.

### `apidb.VariationTranscriptProduct` — 4,595,009 rows
Locus × transcript × observed codon. `na_feature_id` resolves exclusively to
`subclass_view = 'Transcript'` (23,456 distinct transcripts).

- 1,690,908 loci have transcript products; per locus: 1 transcript (1,687,832),
  2 (3,024), 3 (52).
- By **gene**: 1 gene (1,690,354), 2 genes (554).
- Every `is_coding = 1` locus has at least one transcript product — no orphans.

### `apidb.VariationEffect` — 6,789,700 rows
Locus × allele × transcript × caller. `na_feature_id` is nullable (intergenic).
48 distinct `(impact, effect, source)` combinations.

Two callers, which are **complementary rather than redundant**:

| | rows |
|---|---|
| `snpeff` | 4,849,915 |
| `product_call` | 1,939,785 |
| paired and agreeing on `effect` | 1,574,445 |
| paired and **disagreeing** | 377,979 (19% of paired) |
| `product_call` with no `snpeff` counterpart | 139 |

Pairing is on `(sequence_source_id, location, allele, na_feature_id)`, so rows with a
null `na_feature_id` (intergenic) are excluded from the pairing counts — the
agree/disagree figures describe gene-associated calls only.

`snpeff` annotates each variant in isolation. `product_call` is strain-aware and knows
when a variant sits downstream of a frameshift. Top disagreements:

| `product_call` | `snpeff` | rows |
|---|---|---|
| `downstream_frameshift` | `synonymous_variant` | 107,784 |
| `downstream_frameshift` | `missense_variant` | 104,550 |
| `missense_variant` | `synonymous_variant` | 60,020 |
| `synonymous_variant` | `missense_variant` | 22,953 |
| `downstream_frameshift` | `frameshift_variant` | 13,033 |
| `inframe_deletion_unnormalized` | `disruptive_inframe_deletion` | 10,586 |

By gene via `VariationEffect` (broader than products — covers intron/UTR/non-coding):
1 gene (2,853,792), 2 genes (25,042), 3 genes (503).

### Provenance
`external_database_release_id` → 3 loaded datasets: `pfal3D7_dnaSeqVariations`
(620,467), `tbruTREU927_dnaSeqVariations` (652,689), `afumAf293_dnaSeqVariations`
(3,117,752).

### Schema drift to flag
The live `apidb.VariationTranscriptProduct` has a column **absent from the checked-in
DDL**: `downstream_of_frameshift_strain_ids`. It is 100% null (0 of 4,595,009 rows).
This design ignores it. Either the DDL or the table should be reconciled; if the
column is intended to carry per-strain IDs it overlaps the §9 VCF work and should be
designed there, not smuggled in as a string column.

## 3. Design decisions

### 3.1 Sourcing rule (governing invariant)

> **Intrinsic per-locus facts read directly from `apidb.VariationFeature`. Anything
> derived, aggregated, or requiring a join lives in `apidbtuning.VariationAttributes`.**

Rationale: three options were considered — a full BFMV-style denormalized tuning table
(as the old `snp` record used), direct queries against base tables only, and this
hybrid. Direct-only is disqualified by WDK's attribute-query contract, which is
"one query returning every record's value for these columns" and therefore structurally
wants a pre-materialized one-row-per-record relation; the derived rollups would be
recomputed on every query over a 4.4M × 6.8M join.

A hybrid is normally the worst option, because it leaves attributes scattered with no
rule for where a new column belongs. It is sound **here specifically** because
`VariationFeature` is already one row per locus with a unique `source_id`, so the rule
above is decidable for any future column with no exceptions.

The hybrid also wins on one concrete axis: it keeps large derived strings out of the
tuning table entirely (see §3.4).

### 3.2 Both allele classes are preserved

Two named attribute sections, "SNP Alleles" and "Indel Alleles". No collapse, because
collapsing loses half the data for 129,850 `MIXED` loci and buries the choice in a
`COALESCE` no one can see from the page.

**Correction (verified 2026-07-30): the sections are NOT hidden when their class is absent.**
An earlier draft of this spec claimed they would be. WDK renders a null attribute inside a
record-page section as a "No data available" row, and there is no declarative way to hide a
whole section — so a pure-SNV locus shows a 12-row empty "Indel Alleles" section (~4.0M
loci) and an INDEL locus shows an empty "SNP Alleles" one (~261k loci).

The load-bearing half of this decision holds: both classes are preserved and never
collapsed. Only the cosmetic half is unmet. Note the contrast with the record **overview**,
which is a `<dl>` where the client *does* drop pairs whose value is empty — which is why
§6.7's `*_allele_and_freq` strings are assembled in SQL to be NULL rather than " ()".

**Open decision for the record owner:** accept the empty sections, or hide them with a
client-side component. Deliberately left open rather than silently diverging.

Because WDK tables render **only on individual record pages**, results-page columns must
be pre-aggregated. Two collapsed columns exist for that purpose only
(`collapsed_allele`, `collapsed_minor_allele_frequency`, §6.7). The two sections remain
canonical; the collapsed columns are explicitly derived conveniences.

### 3.3 Gene linkage is many-to-many

The tables are the source of truth. Any single-gene attribute is an **aggregate**, never
a lookup. 99.1% of loci are single-gene, but 25,545 loci are not, and a `string_agg`
today costs nothing while a baked-in single-gene assumption would need unpicking from
the tuning table, the summary columns, the download reporter, and any future search
param.

Consequence: **no record-level `gene_strand`**, and no gene-strand reverse-complemented
flank attributes. Strand is not singular once a locus can hit two genes, so strand moves
into the transcript table (§7.1) where it is unambiguous. This is the one thing the old
`snp` record had that is deliberately dropped.

### 3.3a Tuning-table dependency ordering

`VariationAttributes` depends on two other tuning tables — `TranscriptAttributes` (for
the gene aggregate) and `GenomicSeqAttributes` (for `project_id`/`organism`). The tuning
manager expresses this natively:

```xml
<internalDependency name="TranscriptAttributes"/>
<internalDependency name="GenomicSeqAttributes"/>
<internalDependency name="DatasetPresenter"/>
<externalDependency name="apidb.VariationFeature"/>
<externalDependency name="apidb.VariationTranscriptProduct"/>
<externalDependency name="apidb.VariationEffect"/>
```

This matters because built out of order the gene aggregate yields a silently empty
`gene_ids` rather than an error. Declaring both `internalDependency` elements is not
optional.

### 3.4 No sequence-context attributes

The old `snp` record had `lflank`, `rflank`, `snp_context`, and gene-strand variants of
each, computed by `substr` against `dots.NaSequence`. These are **not carried forward** —
no longer needed; JBrowse covers genomic context.

This removes the record's only dependency on `dots.NaSequence` at attribute-query time,
and avoids materializing ~570 MB of flank strings across 4.4M rows to serve attributes
that would only ever render on a single record page.

### 3.5 Effect rollups are per-caller

`most_severe_impact` and `effect_summary` are each **two columns**, one per caller.
Merging them (worst-case-wins across both) would produce a single sortable column, but
the 19% disagreement rate is the scientific content of the pipeline, not noise to be
resolved — a user must be able to see that `product_call` says `downstream_frameshift`
where `snpeff` says `synonymous_variant`. A merged impact alongside split effect lists
would also be an odd asymmetry.

## 4. Record class

```
recordClassSet name="VariationRecordClasses"
  includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,
                   PlasmoDB,TriTrypDB,ToxoDB,UniDB"
```
That is the deprecated `SnpRecordClass` project list verbatim — every project that had
`snp` records gets `variation` records. (Data is currently loaded for only PlasmoDB,
TriTrypDB, and FungiDB; the record simply returns nothing for the others until loaded.)

```
recordClass name="VariationRecordClass" urlName="variation"
            displayName="Variation" displayNamePlural="Variations"
```

**Primary key:** `source_id` + `project_id`, with `project_id` excluded for UniDB —
matching `SnpRecordClass`. `aliasQueryRef` points at `VariationAttributes.VariationAlias`.

**`idAttribute`** `primary_key`, display `$$source_id$$`.

**Coordinate invariant (load-bearing):** `sequence_source_id` and `location` are
exposed, non-internal, independently addressable attributes — never merely parsed out of
`source_id`. This is the coordinate a tabix/VCF lookup and an EDA join both key on, and
it is what makes §9 additive rather than a reshape.

**Reporters:** `attributesTabular`, `tableTabular`, `fullRecord`, `xml`, `json` — same
set and configuration as `SnpRecordClass`.

**`testParamValues`** (coding SNVs with transcript products, verified present):

| project | `source_id` |
|---|---|
| PlasmoDB | `Variant_Pf3D7_01_v3_100057` |
| TriTrypDB | `Variant_11L3_v3_26886` |
| FungiDB | `Variant_Chr1_A_fumigatus_Af293_1000005` |
| UniDB | `Variant_Pf3D7_01_v3_100057` (no `project_id`) |

Remaining projects need values once their data loads; until then their record class has
no testable ID. Note this rather than inventing IDs.

## 5. `apidbtuning.VariationAttributes`

One row per locus (4,390,908). Derived, aggregated, or join-requiring columns **only** —
per §3.1.

| column | source / derivation |
|---|---|
| `source_id` | `VariationFeature.source_id` (PK half) |
| `project_id` | taxon → project mapping (PK half) |
| `sequence_source_id`, `location` | join key to base tables; §4 invariant |
| `location_text` | `to_char(location,'99,999,999')` |
| `organism`, `ncbi_tax_id` | join `apidbtuning.GenomicSeqAttributes` on `source_id = sequence_source_id` |
| `chromosome_order_num` | same join; default sort key |
| `dataset` | `coalesce(DatasetPresenter.display_name, ExternalDatabase.name)` — see note |
| `gene_ids` | `string_agg(DISTINCT gene_source_id)` over both child tables |
| `gene_count` | `count(DISTINCT gene_source_id)` |
| `most_severe_impact_snpeff` | rank aggregate, `source='snpeff'` |
| `most_severe_impact_product_call` | rank aggregate, `source='product_call'` |
| `effect_summary_snpeff` | `string_agg(DISTINCT effect)`, `source='snpeff'` |
| `effect_summary_product_call` | `string_agg(DISTINCT effect)`, `source='product_call'` |
| `collapsed_allele` | §6.7 |
| `collapsed_minor_allele_frequency` | §6.7 |

**Impact rank:** `HIGH` > `MODERATE` > `LOW` > `MODIFIER`. Loci with no
`VariationEffect` row for a given caller get null for that caller's two columns (common
for `product_call`, which covers 2.9M fewer loci than `snpeff`).

**Gene aggregate:** built from `VariationEffect` **and**
`VariationTranscriptProduct`, joined to `apidbtuning.TranscriptAttributes` on
`na_feature_id`. `VariationEffect` alone reaches 2.88M loci vs 1.69M for products, so
`VariationEffect` supplies most of the coverage; products are unioned in so a locus with
a product but no effect row is not missed.

**`project_id` / `organism` / `chromosome_order_num` derivation:** all three come from
`apidbtuning.GenomicSeqAttributes` joined on `source_id = sequence_source_id`. Verified
to match **100%** of the 4,390,908 loci (3 projects, 3 organisms). This is a cleaner
source than `dots.NaSequence` → taxon and adds an `internalDependency` on
`GenomicSeqAttributes`.

**`dataset` caveat.** The three loaded external databases
(`pfal3D7_dnaSeqVariations` etc.) have **no matching `apidbtuning.DatasetPresenter`
row**, so `dataset` renders the raw external-database name today. This is not a model
bug: dataset presenters exist per **dnaseq experiment**
(`*_dnaseqExperiment_RSRC`, one per strain/isolate collection), whereas a
`*_dnaSeqVariations` external database is the *merged* call set across many such
experiments. So `dataset` is a single provenance string ("which call set"), and the list
of contributing experiments is inherently per-strain and therefore belongs to the §9
seam, not here. The `coalesce` is retained so a future presenter is picked up
automatically.

Indexes: PK on `(source_id, project_id)`, plus `(sequence_source_id, location)` and
`(chromosome_order_num, location)` for the default sort.

Everything **not** in this table — `variant_type`, `is_coding`, all 19
`snp_*`/`indel_*` columns, `reference_strain`, `call_rate`, and every strain count —
reads directly from `apidb.VariationFeature`.

## 6. Attributes

Source key: **VF** = `apidb.VariationFeature` (direct attribute query) ·
**VA** = `apidbtuning.VariationAttributes` · **text** = WDK `textAttribute`

### 6.1 Identity & location
| attribute | src | display name | notes |
|---|---|---|---|
| `primary_key` | — | Variation ID | `idAttribute` |
| `sequence_source_id` | VA | Sequence | |
| `location` | VA | Position | numeric, sortable |
| `location_text` | VA | — | comma-formatted |
| `variation_location` | text | Location | `$$sequence_source_id$$: $$location_text$$` |
| `chromosome_order_num` | VA | Chromosome | default sort |
| `organism_text` | VA | Organism | download form |
| `formatted_organism` | VA | Organism | italic abbreviated form, as `snp` |
| `organism` | text | Organism | italic wrapper over `organism_text` |
| `ncbi_tax_id` | VA | NCBI Taxon ID | `inReportMaker="false"` |
| `dataset` | VA | Variant Call Set | named for what it is: the merged call set, not a presenter-backed dataset |

### 6.2 Classification
| attribute | src | notes |
|---|---|---|
| `variant_type` | VF | `SNV` / `INDEL` / `MIXED` |
| `is_coding` | VF | rendered `coding` / `non-coding` |
| `reference_strain` | VF | |

### 6.3 SNP alleles — section "SNP Alleles", hidden when `snp_ref_allele is null`
All VF: `snp_ref_allele`, `snp_major_allele`, `snp_major_allele_frequency`,
`snp_major_allele_strain_count`, `snp_minor_allele`, `snp_minor_allele_frequency`,
`snp_minor_allele_strain_count`, `snp_major_genomic_hgvs`, `snp_minor_genomic_hgvs`.

Plus text attributes `snp_major_allele_and_freq` / `snp_minor_allele_and_freq`
rendering `C (0.9571)`.

`help` on both `*_genomic_hgvs` attributes must state that the major-allele HGVS is null
when the major allele equals the reference, so it does not read as missing data.

### 6.4 Indel alleles — section "Indel Alleles", hidden when `indel_ref_allele is null`
The same nine shapes with the `indel_` prefix, plus `indel_frame_effect`, plus the two
matching `*_allele_and_freq` text attributes. Same HGVS `help`.

### 6.5 Strain / call statistics
All VF: `distinct_strain_count`, `called_strain_count`, `no_call_strain_count`,
`call_rate`, `total_ploidy_count`, `het_strain_count`, `ref_allele_frequency`.

This group is the natural anchor for the future strain table (§9).

**Semantics caveat, measured 2026-07-30.** These counts do **not** partition one
population, despite the naming inviting that reading. `called_strain_count +
no_call_strain_count` is near-constant per dataset (232 for the Pf panel, 4 for another) —
it is the size of the whole assayed strain panel. `distinct_strain_count` tracks something
narrower, roughly `total_ploidy_count / 2`, i.e. strains actually carrying a called allele
configuration. At `Variant_Pf3D7_01_v3_29514`: 159 + 57 = 216, while
`distinct_strain_count` and `total_ploidy_count` are both 160.

So "Strain Count" and "Called Strain Count" come from different universes. This is a
property of `apidb.VariationFeature`, not of this record. It matters for §9: whoever builds
the per-strain table should reconcile the naming, or at minimum document which denominator
each frequency column uses, before users start computing ratios across the two.

All seven columns are schema-nullable, though no NULLs exist in the current 4,390,908 rows.

### 6.6 Gene linkage
| attribute | src | notes |
|---|---|---|
| `gene_ids` | VA | aggregated, sortable as string; used directly in summaries and the overview |
| `gene_count` | VA | |

**Correction (2026-07-30): there is no `linkedGeneIds` attribute.** This spec originally
called for "one link per ID", but WDK's `linkAttribute` builds exactly one URL and cannot
render N links from an aggregated string. A `textAttribute` fallback rendered text
byte-identical to `gene_ids`, i.e. a second column also displayed as "Gene ID(s)" with the
same content, so it was removed. Per-ID hyperlinks would need a client-side component;
until then `gene_ids` is plain text.

### 6.7 Effect rollups & collapsed summary columns
All VA: `most_severe_impact_snpeff`, `most_severe_impact_product_call`,
`effect_summary_snpeff`, `effect_summary_product_call`.

`collapsed_allele` — `ref>minor` per class, both classes joined with `; ` for `MIXED`:

| `variant_type` | example |
|---|---|
| `SNV` | `T>C` |
| `INDEL` | `AC>A` |
| `MIXED` | `A>C; A>AC` |

`collapsed_minor_allele_frequency` — `greatest()` of the two classes' minor-allele
frequencies. Exists because MAF is the most-sorted-on quantity in any variant table and
a `MIXED` locus otherwise has no single sortable frequency.

**Impact columns need a rank sort key.** `most_severe_impact_*` hold text, so WDK sorts
them alphabetically (`HIGH, LOW, MODERATE, MODIFIER`) — contradicting the documented
severity order. Each therefore declares `sortingColumn` pointing at a computed rank column
(`CASE HIGH→4, MODERATE→3, LOW→2, MODIFIER→1`) emitted by the same attribute query. The
rank columns are `internal="true"`. No tuning-table column is needed for this.

Both carry `help` naming them as derived, with the two sections as canonical.

### 6.8 Record overview

Two-panel `textAttribute` `record_overview`, following `SnpRecordClass`'s structure:

- **Left** — Organism, Location, Variant Type, Coding?, Reference Strain, Gene(s)
  (`linkedGeneIds`), Most Severe Impact (both callers).
- **Right** — the SNP Alleles and Indel Alleles sections (§6.3, §6.4), then call
  statistics (`distinct_strain_count`, `called_strain_count`, `no_call_strain_count`,
  `call_rate`, `het_strain_count`).

### 6.9 Default summary & sorting
```
summary = variation_location, linkedGeneIds, variant_type, collapsed_allele,
          collapsed_minor_allele_frequency, most_severe_impact_snpeff,
          most_severe_impact_product_call, distinct_strain_count
sorting = chromosome_order_num asc, location asc
```
Plus an `organism`-leading variant for UniDB / EuPathDB, mirroring `SnpRecordClass`.

## 7. Record-page tables

> Tables render **only** on individual record pages, so everything here is scoped to
> one locus.

### 7.1 `TranscriptProducts` — "Variant Products by Transcript"
`queryRef="VariationTables.TranscriptProducts"`.
`apidb.VariationTranscriptProduct` joined to `apidbtuning.TranscriptAttributes` on
`na_feature_id`. One row per (transcript, observed codon) — 5 rows for
`Variant_Pf3D7_01_v3_29514`.

Columns: `linkedGeneId`, `linkedTranscriptId`, `gene_product`, `strand` (the
unambiguous home for strand, per §3.3), `pos_in_cds`, `pos_in_protein`, `codon`,
`pos_in_codon`, `product`, `matches_ref_codon`, `matches_ref_product`, `strain_count`,
`hgvs_p`.

### 7.2 `PredictedEffects` — "Predicted Effects"
`queryRef="VariationTables.PredictedEffects"`.
`apidb.VariationEffect` **left** joined to `apidbtuning.TranscriptAttributes` (left,
because `na_feature_id` is null for intergenic calls).

Columns: `allele`, `linkedGeneId`, `transcript_source_id`, `impact`, `effect`, `hgvs_c`,
`source`.

Note: `transcript_source_id` is plain text here, not a link. There is no standalone
transcript record to link to — `TranscriptProducts` (§7.1) anchors into the gene page
instead, and repeating that indirection on every effect row was not worth it.

One table with a visible `source` column, not two tables — provenance travels with
every row, and the disagreement stays legible instead of requiring the user to read two
tables and diff them. `help` on `source` must explain that `snpeff` annotates variants
in isolation while `product_call` is strain-aware, and specifically what
`downstream_frameshift` means, since that accounts for 232,946 of the 377,979
disagreements (62%).

### 7.3 Deliberately absent
- **Strains / Samples** — deferred to §9.
- **Allele Summary**, **Country Summary** — both read `apidb.SequenceVariation`
  (0 rows). They return with §9, sourced from VCF + EDA metadata, not rebuilt now.
- **Other variants at this location** — the old `Providers` table read
  `apidbtuning.SnpChipAttributes`, which does not exist in this build. Out of scope.

## 8. Category ontology

New entries in `Model/lib/wdk/ontology/individuals.txt` for
`VariationRecordClasses.VariationRecordClass`. Because these are categorization changes,
**`wb ontology` is required** — `wb model` alone will not regenerate the OWL.

Parent categories, reusing existing nodes:

| group | parent |
|---|---|
| identity & location (§6.1) | `GenomicSequenceLocationCategory` |
| classification (§6.2) | `http://edamontology.org/topic_2885` (DNA Polymorphism) |
| SNP Alleles (§6.3) | new child node under `topic_2885`, display term "SNP Alleles" |
| Indel Alleles (§6.4) | new child node under `topic_2885`, display term "Indel Alleles" |
| strain / call statistics (§6.5) | new child node under `topic_2885`, "Strain Statistics" |
| gene linkage (§6.6) | `http://edamontology.org/topic_0199` (Genetic Variation) |
| effect rollups (§6.7) | `topic_0199` |
| both tables (§7) | `topic_0199` |

Verify placement afterwards via `/service/ontologies/Categories` and
`/service/record-types/variation` from an authenticated app page — the assembled tree,
not the record page, is the source of truth. Note that `/service/ontologies/Categories`
is **not** project-filtered, so for "does this site actually have it" trust
`/service/record-types/variation`.

## 9. Deferred: per-strain data (the seam)

Per-strain allele data is too large for a relational table and lives in **VCF files**.
The longer-term goal is to read the VCF to populate strain/sample tables, joined with
sample metadata from **EDA**.

This is not a future `<sqlQuery>`. It will be a service- or plugin-backed table, which
is a different *kind* of thing from every other table on this record. The seam is
therefore about **identity, not a query stub**:

1. `sequence_source_id` and `location` are exposed first-class attributes (§4) — the
   coordinate a tabix lookup and an EDA sample join both key on. Nothing has to
   string-parse `source_id` to get coordinates.
2. `apidbtuning.VariationAttributes` guarantees exactly one row per locus keyed by
   those coordinates — a single stable join target.
3. §6.5 groups the aggregate call statistics together, so the strain table lands
   beside the counts it details rather than in an unrelated section.

Get these right and the strain section is additive. The three tables removed in §7.3
(Strains/Samples, Allele Summary, Country Summary) all return through this seam.

## 10. Out of scope

- **Searches / questions** — separate spec.
- **Deleting the `snp` record XML.** `snpRecords.xml`, `snpAttributeQueries.xml`,
  `snpTableQueries.xml`, `snpQuestions.xml`, and their `individuals.txt` entries still
  reference `apidbtuning.SnpAttributes`, which no longer exists. Removing them is a
  separate change with its own blast radius (`recordParams.xml`, `spanQuestions.xml`,
  and the `SnpsBySpanLogic` dynamic-span record all reference it).
- **JBrowse track integration** for the new record.
- Reconciling the `downstream_of_frameshift_strain_ids` drift noted in §2.
