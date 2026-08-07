# GeneVariationSummary — gene-page Genetic Variation section

Status: design, prototype validated
Prototype: `jbrestel.gene_variation_summary_v3` in `unidb_shu_a` (27,297 genes, 3 organisms)
Supporting: `jbrestel.gene_cds_sites`, `jbrestel.codon_sites`

## 1. What this replaces

Six attributes retired from the gene and transcript records — `total_hts_snps`,
`hts_nonsynonymous_snps`, `hts_synonymous_snps`, `hts_noncoding_snps`,
`hts_stop_codon_snps`, `hts_nonsyn_syn_ratio`. They are already commented out on master
(`geneRecord.xml:331-343`, `transcriptRecord.xml`, and the `TranscriptAttributes_p.psql`
that fed them), so this is a rebuild, not a migration.

Two defects in the old set that must not be carried forward:

**Synonymous was never measured.** It was a residual:
`total - nonsyn - stop - noncoding`. Anything the old pipeline failed to classify landed
in "synonymous," inflating the denominator and biasing the ratio downward. The retired
values are not a target to reproduce.

**The ratio reported 0 when undefined.** `case when hts_synonymous_snps = 0 then 0`
displayed *maximal* nonsynonymous signal as the *minimum* value. 3,200 of 5,579 pfal
genes have fewer than 5 synonymous sites, so this was not an edge case.

## 2. Why the old attributes could not simply be fixed

They were welded into `TranscriptAttributes_p` / `GeneAttributes_p` — giant
workflow-built flat views. They could not be rebuilt, re-derived, or project-gated
without a full workflow run, so when the SNP data model changed, the only affordable
move was to comment out thirty lines across six files.

`GeneVariationSummary` is therefore its own tuning table, with `externalDependency` on
the three `apidb.Variation*` tables. It rebuilds when the variation data reloads, and it
is additive — which also lets it land on master ahead of the model change that consumes
it.

## 3. Grain

Two grains, each used where it is correct. Mixing them is a bug the prototype had in v2.

| output | grain |
|---|---|
| display counts | per **gene**, unioned across transcripts, most-severe-wins |
| π and πN/πS | **representative transcript only** (longest CDS) |

πN/πS is defined for one CDS. Counting variants across all transcripts while normalizing
by one transcript's site counts lets a variant in a transcript-specific exon enter the
numerator while that exon's sites never enter the denominator.

Only 1.2% of pfal genes have more than one transcript (max 3), and afum has none — but
the grain is declared rather than assumed, because splicing annotation density is an
annotation property and this table is cross-project.
`rep_transcript_source_id` is stored so every π value is attributable to a named CDS.

Source is `apidb.VariationEffect` alone. At gene×locus grain
`VariationTranscriptProduct` contributes **zero** pairs that `VariationEffect` lacks
(2,905,385 vs 1,691,462, 0 product-only), so the defensive UNION in `VariationAttributes`
is dead code at this grain.

## 4. Effect classification

Each (gene, locus) gets exactly **one** class by severity rank, so the eleven class
counts **partition** `total_variants` and add up on the page. Verified at 0 violations,
as does the four-way impact summary.

A locus that is missense in one transcript and synonymous in another counts as missense —
the same "nonsyn wins" semantics the retired columns used.

Ranks: frameshift(1) · nonsense(2) · splice-disruptive(3) · inframe-indel(4) ·
missense(5) · splice-region(6) · synonymous(7) · UTR(8) · noncoding-exon(9) · intron(10) ·
other(11). LOF = ranks 1–3.

### Two callers, asymmetric

`snpeff` and `product_call` disagree on 19% of paired gene-associated calls, so both are
reported — but they are not symmetric. `product_call` covers **coding only** (no
intergenic, UTR, or intron) and carries 230,532 `downstream_frameshift` rows with no
syn/nonsyn meaning.

- caller-independent: variant totals, SNV/indel/MIXED, call rate, frequency bins, het
- `snpeff` only: the eleven-class partition, UTR/intron/noncoding counts, impact summary
- both: missense/synonymous/LOF counts, π, πN/πS

## 5. Ploidy and sample size — the part that governs display

Sample size is a **per-locus** property, not per-organism. `min(called_strain_count)` is
1 in all three organisms, and 35% of pfal loci have fewer than 100 alleles.

Measured, never hardcoded (`total_ploidy_count / called_strain_count`):

| organism | effective ploidy | strains | max alleles | distinct MAF values |
|---|---|---|---|---|
| pfal3D7 | 1.01 (haploid) | 215 | 236 | 4,110 |
| afumAf293 | 2.01 | 232 | 468 | 4,814 |
| tbruTREU927 | 2.27 (diploid) | **4** | 12 | **18** |

`afumAf293` is a **haploid fungus being called as diploid** — 17% of its loci carry
heterozygous calls. Almost certainly a variant caller left at its diploid default. It
inflates afum allele denominators 2× and manufactures 1.8M "rare" variants. A hardcoded
ploidy lookup would encode that bug as truth; a measured value self-corrects when the
calling is fixed. **Raise with whoever ran that pipeline** — it is a data-production
issue, not something to paper over here.

`snp_minor_allele_frequency` is a true **allele** frequency (verified against pfal to
within 2×10⁻⁵ using `total_ploidy_count` as denominator), so `2p(1-p)` is valid at any
ploidy. But `*_minor_allele_strain_count` is a **strain** count — different units — so
"singleton" is defined on allele copies, `round(maf × total_ploidy_count) = 1`.

π carries the `n/(n-1)` finite-sample correction: ~0.4% at pfal's 236 alleles, ~9% at
tbru's 12.

### Validity domains — suppress, never degrade

Each frequency-derived statistic accumulates only over loci clearing an allele floor, and
publishes how many contributed.

| statistic | floor (alleles) | contributing count |
|---|---|---|
| raw counts (`n_missense`, `n_lof`, …) | none — always valid | — |
| nonsyn/syn count ratio | ≥5 synonymous loci | `n_synonymous` |
| π, πN/πS | 4 (+ ≥5 synonymous loci for the ratio) | `n_loci_pi` |
| common / very-common bins | 20 | `n_loci_freq20` |
| rare / singleton bins | 100 | `n_loci_freq100` |

Below a floor the value is **NULL, never 0**. An organism with one sample plus a
reference has 2 alleles, where MAF can only be 0.5: π would compute to a rescaled variant
density carrying no frequency information, and `n/(n-1)` = 2 is a 100% correction — the
estimator announcing it should not be used. Rendering `0.00` there would repeat the exact
defect of the retired `hts_nonsyn_syn_ratio`, this time on a statistic users would
reasonably trust.

Verified behaviour: for tbru **every** frequency bin is blank across all 11,689 genes,
while **every** count is present. A single-sample organism keeps everything the old
section had and simply omits the population genetics.

## 6. Display design

**Sample basis first.** A biologist cannot read any of this without knowing what it is
based on. The section opens with strain count, effective ploidy, and mean call rate — not
buried in a tooltip.

Then, in order:

1. **Basis** — strains sampled, ploidy, mean call rate
2. **Counts** — total variants, SNV / indel / MIXED, variants per kb
3. **Predicted consequences** — impact summary (HIGH/MODERATE/LOW/MODIFIER), then effect classes
4. **Loss of function** — LOF count, and the common-LOF subset called out separately
5. **Selection** — πN/πS, π per site, common-missense fraction
6. **Continuity** — nonsyn/syn count ratio, explicitly labelled as a raw count ratio

### The count ratio is not a selection statistic — label it so

pfal's median nonsyn/syn **count** ratio is 2.22, while its median **site-normalized**
πN/πS is 0.512. A biologist reading 2.22 concludes positive selection; the correct
reading is purifying selection. The count ratio does not divide by mutational
opportunity, and there are roughly 4.7× more nonsynonymous than synonymous sites.

So πN/πS is the selection statistic. The count ratio is retained only for continuity with
what users remember, and must be labelled as a raw ratio of counts.

### Help text (biologist-facing)

**Variants** — Positions in this gene where at least one sequenced strain differs from
the reference. Counted once per position, not once per strain.

**Strains sampled / ploidy** — How many strains carry a call at these positions, and
whether they were called as haploid or diploid. All statistics below are only as good as
this number.

**Mean call rate** — Average fraction of strains with a confident call. A low call rate
means few variants may reflect poor coverage rather than genuine conservation — the most
common misreading of variation data.

**Impact** — Severity predicted by SnpEff. HIGH disrupts the protein (frameshift,
premature stop, lost start, disrupted splice site); MODERATE changes an amino acid;
LOW is synonymous or nearly so; MODIFIER is non-coding.

**Loss-of-function variants** — Frameshifts, premature stops, and disrupted splice sites.
A **common** LOF variant segregating in wild isolates suggests the gene is dispensable; a
singleton is more likely a sequencing artefact. The two are reported separately for that
reason.

**π (nucleotide diversity)** — Average probability that two randomly chosen strains
differ at a given site in this CDS. Higher means more diverse.

**πN/πS** — Nonsynonymous diversity divided by synonymous diversity, each normalized by
the number of sites of that class in *this* gene's codons. Below 1 suggests purifying
selection (amino-acid changes removed); above 1 suggests diversifying or balancing
selection, typical of surface antigens under immune pressure. Most genes fall below 1.

**Common variants** — Minor allele frequency above 5%. Requires at least 20 sampled
alleles; blank when the sample is too small to tell common from rare.

**Blank vs zero** — A blank value means *not enough data to calculate*, not zero. Each
statistic requires a minimum number of sampled alleles; below that it is suppressed
rather than shown as an unreliable number.

That last line is the single most important piece of help text in the section.

## 7. Validation

Known *P. falciparum* genes behave as a malaria biologist would expect. Site-normalized
πN/πS, snpeff:

| gene | | πN/πS | π/site | common missense | call rate |
|---|---|---|---|---|---|
| PF3D7_1133400 | AMA1 | 10.32 | high | 57 / 62 | 0.723 |
| PF3D7_0206800 | MSP2 | 13.49 | high | 32 / 39 | 0.521 |
| PF3D7_0930300 | MSP1 | 1.94 | high | 78 / 94 | 0.687 |
| PF3D7_0304600 | CSP | 3.70 | mid | 14 / 15 | 0.821 |
| PF3D7_0709000 | PfCRT | 24.99 | mid | 12 / 22 | **0.424** |
| PF3D7_1343700 | Kelch13 | 3.67 | low | **1 / 8** | 0.480 |

The vaccine candidates under balancing selection (AMA1, MSP1, MSP2) top the diversity
ranking with common-missense-dominated spectra. Kelch13, conserved with only rare
artemisinin-resistance mutations, is low and rare-dominated. PfCRT and DHFR show drug-
selection signatures — but note PfCRT's 0.424 call rate, exactly the case where the
confidence indicator earns its place.

Genome-wide medians land where population genetics expects: πN/πS of 0.512 (pfal), 0.214
(tbru), 0.185 (afum), all below 1; pfal π of 1.5×10⁻³ per site matches published
*P. falciparum* estimates.

πN/πS tracks inversely with the number of synonymous sites carrying variation — MSP1 at
1.94 on 28 sites is solid; DHFR's 26.9 rests on one. Hence the ≥5 guard.

## 8. Site counting (Nei–Gojobori)

Per codon, per position, the fraction of the 3 possible single-nucleotide changes that
are synonymous. Summed over 3 positions gives (S, N) per codon with S + N = 3. Stop
codons are excluded; a change creating a stop is nonsynonymous.

Because this depends only on the codon it is a **61-row lookup** derived inline from the
genetic code (not hardcoded, so the code table is the single source of truth). Validated
against known degeneracy: ATG and TGG give 0 synonymous sites, four-fold codons exactly
1.0, two-fold 1/3, and the position-1 cases correctly (TTA 0.667 via TTA↔CTA, CGA 1.333).

CDS comes from **`webready.CodingSequence_p`**, not from
`substr(spliced_sequence, five_prime_utr_length + 1, cds_length)`. Both were verified in
frame and agree exactly (5,318 of 5,720 pfal genes match; the 402 unmatched are
non-coding genes with no CDS, correctly receiving NULL site counts), but
`CodingSequence_p` removes the `dots.SplicedNaSequence` / `dots.Transcript` joins and a
whole class of frame bug. A length-divisible-by-3 filter guards the 477 of 63,765
out-of-frame rows genome-wide (none in the loaded organisms).

### Shape: LATERAL, not a flat expansion

The codons are streamed per-CDS through a `CROSS JOIN LATERAL` aggregate rather than
expanded into one row per codon genome-wide. Measured over all 63,082 genes in
`unidb_shu_a`:

| shape | time | rows | disagreements |
|---|---|---|---|
| flat CTE expansion | 51.6 s | 63,082 | — |
| `LATERAL` per-gene aggregate | **30.8 s** | 63,082 | **0** |

So the codon work is **31 seconds**, not the bottleneck — the `VariationEffect`
aggregation is. Do not "optimize" it back into a flat expansion or a temp table.

A PL/pgSQL loop would achieve the same streaming, but it forces procedural code into two
files that must mirror each other. Staying declarative keeps the tuningManager and
webready copies textually comparable, which is what makes the mirroring obligation
enforceable by reading.

## 8a. Partitioning

`webready.GeneVariationSummary_p` is declaratively partitioned `LIST (org_abbrev)`, via
the standard `:CREATE_AND_POPULATE` / `:DECLARE_PARTITION` directives used by all 62
`orgSpecific` psql files. Confirmed against the live database: every comparable webready
table (`transcriptattributes_p`, `codingsequence_p`, `genomicseqattributes_p`, and both
CNV tables `genecopynumbers_p` / `chrcopynumbers_p`) is `relkind = 'p'` with
`LIST (org_abbrev)` and 8 partitions. The CNV tables therefore needed no change.

Leading column order follows the convention `project_id, org_abbrev, modification_date, …`
— the partition key must be present and NOT NULL.

Minor pre-existing inconsistency worth a cleanup: the branch's corrected
`GeneCopyNumbers_p.psql` emits `modification_date` fifth rather than third, deviating from
that convention. Harmless, but it makes the two CNV files and this one look gratuitously
different.

### The constant matters more than the per-gene refinement

Pooled synonymous-site fraction in pfal is **17.49%**, not the textbook ~25% — an AT-bias
effect worth 1.43× on every gene. Per-gene spread is second-order (p25–p75 = 16.9–19.0%,
full range 13.2–24.6%).

So most of the correction comes from using the right *constant*, which itself can only be
discovered by running this analysis. Per-gene values are retained because the table is
cheap once built (24,822 rows, rebuilt only when the annotation changes) and it removes an
approximation that would otherwise need defending.

## 9. Known limitations

- **Jukes–Cantor multiple-hit correction not applied.** Unnecessary at within-species
  diversity (π ≈ 10⁻³); would matter for between-species divergence.
- **Nei–Gojobori assumes equal mutation probabilities.** Transitions outnumber
  transversions and are more often synonymous at position 3, so S is slightly
  underestimated. The modified method with a transition/transversion ratio would refine
  this; not worth it for per-gene ranking.
- **tbru rests on 4 strains** (18 distinct MAF values across 571,851 loci). π is computed
  where the floor permits, but is noisy; all frequency bins are correctly suppressed.
- **`downstream_of_frameshift_strain_ids`** exists in the live
  `apidb.VariationTranscriptProduct` but not the checked-in DDL, 100% null across
  4,595,009 rows. Reconcile DDL or table; overlaps the VCF work if it is meant to carry
  per-strain IDs.
