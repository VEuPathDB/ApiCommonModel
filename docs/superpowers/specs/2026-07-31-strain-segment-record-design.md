# Strain genomic segment record — design

**Date:** 2026-07-31
**Status:** draft (design agreed in session; not yet reviewed)
**Scope:** WDK record class, one search, attribute query, and BED reporter for a new
**internal** `strain-genomic-segment` record. **FASTA/seqret wiring is out of scope** —
the pipeline deliberately stops at the BED reporter (§8).
**Implementation target:** `ApiCommonModel` + `ApiCommonWebsite`, branch
`strain-segment-record` (created off `master`), fungidb checkout.

**Path conventions:** paths are relative to their repository root. `Model/lib/wdk/...`
is in `ApiCommonModel` (this repo); `Model/src/main/java/org/apidb/apicommon/model/report/...`
is in `ApiCommonWebsite`; `bin/` and `modules/` are in `dnaseq-nextflow`;
`src/main/java/org/veupathdb/service/sr/...` is in `service-sequence-retrieval`.

## 1. Purpose

Deliver a FASTA download of genomic segments expressed in **isolate/strain
coordinates**, given segment coordinates in **reference** coordinates as input.

Strain consensus sequences differ in length from the reference — `build_consensus` in
`dnaseq-nextflow/bin/makeConsensusFastaFromVcfAndBed.py` emits the called allele for
homozygous indels — so a reference interval does not address the same bases in a strain
contig. `apidb.indel` records the per-event shifts needed to translate between them.

The record class exists **only** to carry this business logic from user-selected strain +
reference location to a BED feature. It is not user-facing, has no record page, and
supports no saved strategies.

### Non-goals

- No record page, no summary view, no tables, no `fullRecord`/`attributesTabular`
  reporters. A record-page request for this class should fail, not render empty.
- No saved strategies. This removed the only argument for baking strain coordinates
  into the primary key (§3).
- No coding/protein coordinates. `apidb.indel` is genomic; `codingIndels.db` is a
  separate upstream artifact and a separate problem.

## 2. Data sources

Measured 2026-07-31 against `genomicsdb_rebuild01` (ssh tunnel, `localhost:5439`).

> **Which database these numbers describe matters, and it is not the one the dev site queries.**
> `jbrestel.fungidb.org` resolves its `appDb` through LDAP `genomicsdb_devn` →
> `genomicsdb_070n` (ares13, local port 5433), where **`apidb.indel` does not exist at all**
> and there are **0** `_Indel` protocol app nodes. Every figure below is from
> `genomicsdb_rebuild01`, which does hold the indel load. The queries in §5 are therefore
> verified correct against real data, but have never been executed by a deployed site — see
> the BLOCKED banner on plan Task 7.

### `apidb.indel` — 43,585,584 rows

```
indel_id, protocol_app_node_id, na_sequence_id, location, shift  (+ GUS housekeeping)
PK indel_id;  ix0 (na_sequence_id, indel_id);  ix1 (protocol_app_node_id, indel_id)
FK -> dots.nasequenceimp, study.protocolappnode
```

6,249 distinct `protocol_app_node_id`, 20,823 distinct `na_sequence_id`.

**There is no strain column.** Upstream there is — `makeGenomicIndelDb` in
`dnaseq-nextflow/modules/mergeExperiments.nf` builds
`genomic_indels(strain, sequence_id, position, shift)` — but the GUS load normalizes
strain into `study.protocolappnode`, so on the website side strain identity is one join
away. This is the single most misleading thing about the table and the reason §4.1 exists.

**`location` is the VCF anchor base, not the first affected base.** Established 2026-07-31 by
reconstructing strain sequence from reference: for each event, the only deletion offsets that
reproduce the observed consensus start at `location + 1`, never at `location` itself.

| strain | recorded offset in segment | offsets that reproduce the strain |
|---|---|---|
| A17-10A-1 | 1207 | **1208**-1212 |
| E-1-75s-2 | 2492 | **2493**-2495 |

So a deletion covers `location+1 … location+|shift|` and `location` is the last *unaffected*
base. This **confirms** the `<` / `<=` asymmetry in §5.3: an event whose `location` equals
`refStart` deletes bases starting at `refStart+1`, i.e. genuinely inside the segment, so it
must shift the end and not the start — which is what the query does.

Two caveats it also exposes:

1. **Event position is ambiguous within repeat context.** Several offsets reproduce the same
   consensus (1208-1212 above, a 5-wide window). VCF left-normalizes; aligners tend to place
   gaps rightmost. Nothing is wrong, but a segment boundary landing inside that window inherits
   the ambiguity, and no convention we control resolves it. This is the honest answer to the
   deferred "refStart sits inside the segment" question: for events fully outside or fully
   inside a segment the arithmetic is exact; for an event *straddling* a boundary the reference
   base may not exist in the strain at all, so no exact strain coordinate exists to return.
2. **Only the net shift is meaningful, not the decomposition.** Verified on an insertion region
   (A17-58A-3, ref 491000-493500): the table records `-1, -6, +31, -1` while a clustalo
   alignment of the real consensus resolves the same region as `-1, +25, -1`. Both sum to
   **+23**, and the recorded `-6/+31` pair 40 bp apart is one compound variant the aligner
   renders as a single `+25`. The prefix sum consumes only the sum, so this is harmless -- but
   do not expect a one-to-one correspondence between rows here and gaps in an alignment.

`shift` is a **signed per-event delta**, never zero: range −101..+80, with 21,945,521
negative and 21,640,063 positive rows. The strain offset at a reference position is
therefore a *prefix sum*, partitioned by `(protocol_app_node_id, na_sequence_id)`.

### `study.protocolappnode` — strain vocabulary

Strain name is `name` with the suffix `_Indel` removed: `A0003_Indel`, `S7_Indel`,
`A17-48H-7_Indel`, `X10462-P1C9_Indel`.

Verified properties of the 6,119 distinct names appearing in `apidb.indel`.

> **Provenance — this whole table was measured on `genomicsdb_rebuild01`, which is a
> different and much larger database than the live appDb.** On `unidb_shu_a` (measured
> 2026-07-31) there are **452** `_Indel` protocol app nodes, **452** distinct names, **0**
> names mapping to more than one organism, **0** nodes spanning more than one organism, and
> `(strain, taxon)` resolving to exactly one node in **452 / 452** cases — i.e. none of the
> ambiguity below is live here yet. Everything downstream is written to be correct under the
> rebuild01 shape, because that shape is what this data grows into; do not "simplify" a
> query by citing the live zeroes.

| Property (on `genomicsdb_rebuild01`) | Result | Consequence |
|---|---|---|
| contain `:` | **0** | the colon-delimited PK grammar (§3) is unambiguous |
| end in `_Indel` | **6,119 / 6,119** | the suffix strip is uniform; no special cases |
| contain any other `_` | **1,494** (24%) | `<strain>_<refSeq>` is **not** reversible — see §3.1 |
| map to >1 organism | **126** (256 nodes) | strain name is **not** globally unique — see §5.2 |
| `(name, na_sequence_id)` -> >1 node | **0** | sequence-scoped resolution is unambiguous *today* |

**Correction (re-measured 2026-07-31).** An earlier revision of this spec recorded "contain
any other `_`: 0" as verified fact. It is wrong: 1,494 of the 6,119 names contain an
underscore (`1_01_01`, `Af293_resequence2`, `China_LZCH-36`, `USGS_28834_1_NV`). The
`<strain>_<refSeq>` FASTA key is therefore a **one-way, opaque** key — correct to build,
never to split. Anything needing the strain or the sequence back takes it from the primary
key, where `:` delimits unambiguously (0 names contain `:`). See §3.1 for the consequence
for `StrainSegmentId`'s pattern, which relied on the false claim.

The last row is a **data-dependent invariant with no constraint enforcing it**, and it is
the narrow one that matters: all 126 duplicated names *already* resolve to two or more
protocol app nodes (122 to two, 4 to three) that all carry indel rows today, so the ambiguity
is live in the data — what keeps it harmless is only that no `(name, na_sequence_id)` pair is
served by more than one node. §5.2/§5.3
specify a query shape that turns a future violation of *that* into an error rather than
silent corruption.

### `webready.genomicseqattributes_p` — reference sequences

`Partition key: LIST (org_abbrev)`. Every unique index is `org_abbrev`-prefixed
(`seqattr_source_id`, `seqattr_naseqid`, `pk_seqattr_`, `seqattr_taxsrc_id`).

> **Every query against a `webready.*_p` table must constrain `org_abbrev`.** The column
> is `org_abbrev`, not `organism_abbrev`. Omitting it scans all partitions (831 on
> `organismabbreviation_p`) and uses no index.

**As it turns out, this design touches no `webready.*_p` table at all** — see §5.1.1. Both
the ID query and the attribute query resolve sequences through unpartitioned
`dots.ExternalNaSequence`, so the partition-key rule above never binds. It is recorded
because it drove an earlier draft and because anyone extending this record needs to know it
applies the moment they reach for a `_p` table.

`organism -> org_abbrev` comes from `webready.organismabbreviation_p`
(`organism`, `org_abbrev`, `project_id`, `sanitized_org_abbrev`, `name_for_filenames`).

Note: `apidbtuning.organismattributes` and `apidbtuning.GenomicSeqAttributes` — both
joined by DynSpan's `Bfmv` query — **do not exist in this database**. Only the
`webready.*_p` forms do. New queries target `webready.*_p` exclusively.

### Strain consensus FASTA (for §7 context only)

`makeConsensusFastaFromVcfAndBed.py:233` writes deflines as `<sample>_<chrom>`, i.e.
**`<strain>_<refSeq>`**. **Verified against real artifacts 2026-07-31** (`A17-10A-1_consensus.fa.gz`):
deflines are exactly `>A17-10A-1_Chr1_A_fumigatus_Af293`, and the `chrom` this record emits
byte-matches them.

**Correction:** an earlier revision inferred from `checkUniqueIds.sh` that the pipeline emits
**one merged multi-strain FASTA**. The delivered artifacts are **one gzipped file per strain**
(`<strain>_consensus.fa.gz`, 9 deflines each for Af293). The uniqueness check is still
consistent with that, but the packaging inference was wrong, and §8 should not assume a single
merged file when seqret wiring is picked up.

## 3. Identity

```
source_id = <strain>:<refSeq>:<refStart>-<refEnd>:<f|r>
            A0003:AACB03000001:100-200:f
```

Primary key columns: `source_id` and `project_id`, uniformly.

**No `includeProjects` or `excludeProjects` anywhere** — not on the record class, the
question, the queries, or the PK columns. The record works on every project, UniDB
included.

This is a deliberate departure from DynSpan, which carries an `excludeProjects="UniDB"` PK
column *and* duplicated UniDB `<sql>` variants (`dynSpanAttributeQueries.xml:16-33`). That
fork exists because DynSpan derives `project_id` from `@PROJECT_ID@`, which is meaningless
on the portal. This record instead takes `project_id` from the data — `apidb.organism.project_name`,
joined on `taxon_id` (an earlier draft of this line named `webready.GenomicSeqAttributes_p.project_id`;
§5.1.1 explains why the implementation uses the unpartitioned `apidb.organism` instead) — so it is
populated correctly on every project including UniDB and needs no fork. One query, one PK, no variants.

Note this is separate from the requirement to add UniDB to the **existing**
genomic-segment `includeProjects` lists where absent — that concerns pre-existing
searches, not this record.

Coordinates in the PK are **reference** coordinates — the input, not the output. Strain
coordinates are derived in the attribute query (§5.2). Rationale:

- Provenance: the defline can report both what was requested and what was returned.
- A reload of the dnaseq indel data is picked up automatically; nothing recomputes stale.
- `(strain, refSeq)` resolves to exactly one `protocol_app_node_id` (§2), so
  strain-in-the-PK is sufficient to validate strain against the indel vocabulary, which
  is the stated requirement.

### 3.1 Parse the grammar once

DynSpan implements its ID grammar **five** times — SQL `regexp_substr` at
`dynSpanAttributeQueries.xml:66-71` and `spanQueries.xml:51,62`, SQL `CONCAT`
construction at `spanQueries.xml:120,197,275,396`, a Java regex at
`DynSpanFeatureProvider.java:18`, and construction at `GffSpanDatasetParser.java:66`.
The SQL and Java parsers **disagree**: SQL takes the first colon token as the sequence
ID, the Java regex is greedy (`^(.*):(\d+)-(\d+):(f|r)$`) and takes the last two tokens
as range and strand. A sequence ID containing a colon parses differently on each side.

This spec adds **one** Java class, `StrainSegmentId`, with `parse`/`format`, used by the
feature provider. On the SQL side use `split_part(source_id, ':', N)`, not positional
`regexp_substr` — it does not silently renumber fields when one is empty. Strain names
contain `-` (`A17-48H-7`), which is safe only because the range is its own colon field;
the range must never be parsed out of the whole string positionally.

**As implemented** (commits `19defeba2`, `3ead3adac`, corrected by `65126443a`):

```
^([^:]+):([^:]+):(\d+)-(\d+):(f|r)$
```

Every field is `[^:]+`, not DynSpan's greedy `(.*)`, so an ID carrying an extra colon is
**rejected** rather than mis-parsed into a different segment. `':'` is the only excluded
character because it is the only delimiter.

**Defect found and fixed in review — the strain group was originally `[^:_]+`.** The `_`
exclusion was added on the belief that no strain name contains an underscore ("0 of
6,119"), as inert insurance against an ambiguous `<strain>_<refSeq>` FASTA key. That belief
was **false**: 1,494 of the 6,119 strain names contain an underscore (§2, re-measured
2026-07-31), so `parse()` was silently rejecting roughly a quarter of all legitimate strain
segment IDs — e.g. `Af293_resequence2:Chr1_A_fumigatus_Af293:1-100:f`. Fixed in
`65126443a`, with regression tests over the real underscore-bearing names; those five tests
fail against the old pattern and pass against the new one.

The lesson is worth keeping, because the exclusion could not have worked anyway: narrowing
the grammar cannot make `<strain>_<refSeq>` reversible, since reference sequence IDs contain
underscores too (`Chr1_A_fumigatus_Af293`), so `A_B`+`C` is indistinguishable from
`A`+`B_C`. The real defense is never reversing the key — see §3.1.

  The ambiguity the exclusion was meant to prevent is real (strain `A_B` + sequence `C` and
  strain `A` + sequence `B_C` both yield the key `A_B_C`) but cannot be prevented by
  narrowing the grammar, because both halves genuinely contain `_`. It is instead avoided by
  **never reversing the key**: `strain_seq_id` is opaque output only, and every consumer that
  needs the strain or the sequence reads them from the primary key's `:`-delimited fields
  (§2, §5.3). Verified 0 actual key collisions in today's data; if one ever appears it is a
  data problem to detect, not a grammar to tighten.

Validation lives in the private constructor, not in `parse()`, so that any later
from-parts factory cannot bypass it. It rejects `refStart < 1` (a 0 start would reach
`BedLine.locationToZeroBased()` and emit `chromStart = -1`, a malformed BED line),
`refEnd < refStart`, and any strand other than forward or reverse.

## 4. Where DynSpan gets validation wrong

Recorded because the new search must not repeat it.

| Location | Behaviour |
|---|---|
| `spanQueries.xml:10-22` (`DynSpansBySegIds`) | webservice-only; **zero** validation. Any string becomes a record. |
| `spanQueries.xml:48-67` (`DynSpansBySourceId`) | only existence check anywhere; **silently drops** bad rows. Does not check organism membership or sequence length. Its organism/chromosome params appear in no `WHERE` clause — they are form scaffolding. |
| `dynSpanAttributeQueries.xml:74-75` (`Bfmv`) | `LEFT JOIN` seq attrs then `INNER JOIN` organism attrs, so an unknown sequence yields a null organism that the inner join deletes. Attributes vanish; no error. |
| `DynSpanFeatureProvider.java:46-48` | the **only** place that throws — at download time, after the search succeeded. |

## 5. Model changes (`ApiCommonModel`)

### 5.1 Search: `StrainSegmentId.StrainSegmentsByRefSegment`

Input is a **single reference location**, modeled on `DynSpansByLocation`
(`spanQueries.xml:266`), not a `datasetParam` — so `SpanParams.span_id` and its
`recordClassRef` to DynSpan are not involved.

**Caveat on that precedent, verified 2026-07-31:** `DynSpansByLocation` is *only* an
`<sqlQuery>`. No `<question>` wraps it, and nothing *consumes* it across
ApiCommonModel, ApiCommonWebsite, ApiCommonWebService, EbrcModelCommon or
EbrcWebsiteCommon — it is a dead id query. (It is not literally unmentioned: the
`Model/vp2TuningTablesEffort` inventories name it twice, and `tableUsageMap.json` records
`"SpanId.DynSpansByLocation": []` — an empty usage list, which independently corroborates
that nothing uses it.) So "modeled on `DynSpansByLocation`" means
modeled on a query **no question has ever exercised**: the param shape below has no live
precedent and inherits no operational confidence. Worth knowing when the params
misbehave — there is no working sibling to diff against.

Params: `strain`, `sequenceId`, `start`, `end`, `strand`. **There is no organism param.**

### 5.1.1 Why no organism input

An earlier draft took an organism as a first param, used it to prune the `org_abbrev`
partition key and to check that the reference sequence belonged to it. That was redundant
input: **a reference sequence ID already determines its organism.** Being handed an
organism as well only creates a consistency question the query then has to answer.

Dropping it removes three problems at once:

- **No partition-key concern.** Resolve the sequence through unpartitioned
  `dots.ExternalNaSequence` (carries `na_sequence_id`, `taxon_id`, `length`; `source_id`
  uniqueness is enforced by `source_id_uniq` on the **base table** `dots.nasequenceimp` —
  `ExternalNaSequence` is a view, so it holds no index of its own. The guarantee is
  therefore stronger than "unique among external sequences": it is unique across all of
  `nasequenceimp`, which is what makes "one input location yields one record" structural
  rather than a data accident. Measured: 10,331,542 rows, 0 duplicate non-null `source_id`,
  the only gap being 17 NULLs that can never match `= $$sequenceId$$`.) rather than `webready.GenomicSeqAttributes_p`. Same table path §5.3 already
  uses, so the two queries become consistent instead of divergent.
- **No `@PROJECT_ID@`.** `project_id` for the PK comes from `apidb.organism.project_name`
  via `taxon_id` — unpartitioned, correct on every project, still one query.
- **No vocabulary-shape trap.** See the note below; this is the defect that prompted the
  redesign.

> **The trap, recorded because it cost a round of rework.** With an organism param, the
> obvious `org_abbrev IN ($$organismSinglePick$$)` is wrong. That param defaults to
> `organismVQ.withGenes` (`organismParams.xml:677`), a *tree* vocabulary projecting
> `string_agg(fq.abbrev, ', ') AS internal` grouped by `term, parentTerm` — so a leaf term
> gives one abbrev but any grouping node gives `'afumAf293, afumA1163'`. Quoted, that is a
> single literal matching **nothing**: verified, `org_abbrev IN ('afumAf293, afumA1163')`
> returns 0 rows, with no error and no log line. Most of the model dodges this by overriding
> `queryRef` to a flat abbrev vocabulary, but every such vocabulary carries
> `includeProjects`/`excludeProjects`, which this record may not have. Not taking an
> organism at all sidesteps the whole question.

**Five** gates, all as filters so bad input yields **zero records** rather than a broken
download. This numbering is mirrored verbatim in the header comment of
`strainSegmentQueries.xml`; renumber both or neither.

1. the reference sequence exists — `dots.ExternalNaSequence.source_id = $$sequenceId$$`;
2. `1 <= refStart <= refEnd <= ens.length`;
3. the strain has indel data somewhere on **this sequence's organism** — an `EXISTS` over
   `apidb.indel` joined to `study.protocolappnode` and back to `dots.ExternalNaSequence`,
   matched on `taxon_id` (**not** on `na_sequence_id`; see "Gate 3 is organism-level" below);
4. the reference sequence ID contains no `':'` — `seg.ref_seq NOT LIKE '%:%'`;
5. the sequence's `taxon_id` has an `apidb.organism` row — the *inner* join that also
   supplies `project_id`. It belongs in this list because it filters: a sequence whose
   `taxon_id` has no `apidb.organism` row yields no record at all. That is intended — such
   a sequence sits outside every project and so has no `project_id` to key a record on —
   and it must not become a `LEFT JOIN`, since a NULL `project_id` would mint a malformed
   primary key.

Gate 4 exists because `':'` is the only delimiter in the minted primary key, so a
colon-bearing `source_id` yields an ID that §5.3 mis-parses and then dies on
(`'ncRNA'::integer` aborts the *entire* attribute query, every row on the page). On
`genomicsdb_rebuild01` — a **different, larger database**, not the live appDb — 10,704
`dots.ExternalNaSequence` source_ids contain a colon (`bld68_Tb927.1.05:mRNA` and similar
transcript-level features) while **0** of its 20,823 indel-bearing sequences do. On
`unidb_shu_a` (live, measured 2026-07-31) it is **0 of 160,581** source_ids, with 120
indel-bearing sequences. Either way the gate is unreachable today, which is exactly why it
is worth having: the grammar's soundness should not rest on which features happen to get
indel-called. Verified the gate costs nothing real — it refuses 0 indel-bearing sequences
and all **9** Af293 sequences (8 chromosomes plus `mito_A_fumigatus_Af293`) still pass.

Note what gate 4 does **not** cover: it is sequence-side only. `$$strain$$` is concatenated
into the PK ahead of the first colon and is never colon-checked. That field is safe because
the `flatVocab` it comes from holds no colon-bearing value (0 of 452 on `unidb_shu_a`,
0 of 6,119 on rebuild01) — a property of the data, not of the SQL.

Gate 3 subsumes the organism check the earlier draft did explicitly: if the strain has indel
rows against that sequence's organism, strain and sequence are consistent **by
construction**. That is a stronger guarantee than validating against a user-supplied
organism, and it is what the original requirement ("validate the reference sequence against
the reference organism") actually wanted.

#### Gate 3 is organism-level, and that is deliberate

**Corrected 2026-07-31 after end-to-end QA.** Gate 3 originally matched on
`na_sequence_id`, so it did double duty: it proved strain/sequence consistency (its job,
and the reason §5.1.1 can drop the organism param) *and* it required indel data on that
exact contig (not its job, and wrong).

The second requirement is wrong because **zero indels on a contig is a valid, ordinary
state**, not a missing-data state. It means the strain matches the reference there: the
strain coordinates equal the reference coordinates, `StrainSegmentAttributes.Coords`
already returns exactly that identity mapping via its `LEFT JOIN` + `COALESCE(..., 0)`
(no change needed there — verified against a zero-indel PK, which yields `100-200 ->
100-200` with the correct `strain_seq_id`), and the contig **is** present in that strain's
consensus FASTA. Refusing the request produced `### The result is empty ###` for a request
the data fully supports.

Scale of the defect: **689 of the 6,068 valid strain/sequence pairs (11%)** in `unidb_shu_a`
were refused this way. The case that surfaced it: `A17-10A-1` + `mito_A_fumigatus_Af293`
returned empty, yet `>A17-10A-1_mito_A_fumigatus_Af293` is present in
`A17-10A-1_consensus.fa.gz`.

So the gate now matches on `ens2.taxon_id = seg.taxon_id`. Stated plainly:

| | |
|---|---|
| What gate 3 **now proves** | this strain was sequenced against this organism, so the strain name and the reference sequence are mutually consistent and the minted PK is meaningful |
| What it **no longer proves** | this strain has indel data on this exact contig — which was never a precondition for a valid request |

Weakening it is safe because the substitution is exact, not approximate (re-verified
against `unidb_shu_a`):

- `(strain name, taxon)` resolves to **exactly one** `protocol_app_node` — 452 / 452 pairs,
  zero exceptions. Organism scoping is therefore no less specific than node scoping.
- **0** `protocol_app_node_id` values span more than one organism.
- It remains scoped by organism, never by strain name alone. On `unidb_shu_a` that scope is
  currently free — all 452 `_Indel` nodes carry 452 distinct names and **0** names span more
  than one organism — so the "126 strain names map to more than one organism" figure quoted
  in §2 is a `genomicsdb_rebuild01` measurement, **not** a live one. The taxon scope is what
  keeps this query correct whenever that situation recurs here, and the cross-organism case
  still returns zero rows today (`A17-10A-1` + `Pf3D7_01_v3`).

**Cost, both paths** (`EXPLAIN ANALYZE` on `unidb_shu_a`, 2026-07-31). The earlier claim
"0.35 ms, no sequential scan" measured only the accept path and was wrong in detail:

| Path | Old (exact-sequence gate) | New (organism gate) |
|---|---|---|
| **Accept** (`A17-48H-7` + `mito_A_fumigatus_Af293`) | — | **~0.33 ms**, `EXISTS` early-exits on the first matching indel row via `indel_ix1` |
| **Reject**, largest strain (`A17-48H-7`, 108,091 indel rows, vs `Pf3D7_01_v3`) | ~53 ms | **~101 ms** (≈2×) |
| **Reject**, smallest strain (`C044`, 4 indel rows) | — | **~0.33 ms** |

Two corrections to the old claim. (i) "No sequential scan" is false in detail: the plan
contains a `Seq Scan on organism o` (5 rows) — harmless, but it is there. (ii) The reject
path is where this change costs something, and it is unavoidable: a *false* `EXISTS` must
exhaust every indel row the strain owns, so the cost scales with **the strain's row count**,
not the database's. Reviewers measured the same reject at 79–99 ms new vs 8.9–56 ms old
depending on the plan chosen (2–9×). On a 43.5M-row database the worst case would be
substantially larger.

> **Rejected optimisation: do not rewrite the `EXISTS` as a `LIMIT 1` scalar subquery.**
> Resolving the strain to a single `protocol_app_node` and comparing its organism directly
> would make the reject path O(1). It was considered and **deliberately rejected**: it is
> correct only while "no `protocol_app_node_id` spans more than one organism" holds, and if
> that ever breaks it silently picks an arbitrary organism and admits or refuses the wrong
> pairs, with no error anywhere. `EXISTS` degrades to *slow* rather than to *wrong*, which
> is the trade this record wants. Revisit only with a schema constraint enforcing the
> one-node-per-(strain, organism) invariant.

> **The one assumption a future reader must re-check** (also listed in §10). Organism-level
> gating admits every contig of the organism, so the minted `chrom` is guaranteed to exist
> in the strain's consensus FASTA only while **a strain set covers every contig of its
> organism's reference**.
>
> **Frame it as set equality, not as a one-way pipeline omission.** The invariant is that
> the taxon's `dots.ExternalNaSequence` rows and the consensus deflines are the *same set*.
> It can drift from either side:
>
> - *FASTA side* — the consensus pipeline omits a reference contig. The gate then mints an
>   ID whose `chrom` has no FASTA entry.
> - *DB side* — a **non-genomic** sequence gains a row under a strain-bearing taxon. It is
>   then a contig of the organism as far as gate 3 is concerned, but was never a consensus
>   target. The gate-4 paragraph above supplies the live example of the shape:
>   `bld68_Tb927.1.05:mRNA`, a *T. brucei* transcript-level `source_id` — 10,704 such rows
>   exist on `genomicsdb_rebuild01`. **Gate 4's colon filter is currently the only thing
>   stopping those**, and it stops them by an accident of naming (transcript-level IDs
>   happen to carry a colon), not by any check on what kind of sequence it is. A
>   non-genomic row without a colon in its `source_id` would pass every gate.
>
> **Verification (2026-07-31), done on the organism where the risk actually lives.** Af293
> alone would have been the easy case; the check was run on three organisms, chosen so that
> one of them has contigs no strain has ever indeled:
>
> | Organism | Pairs admitted | Newly admitted | …of those, on contigs **no strain ever indeled** |
> |---|---|---|---|
> | *P. falciparum* 3D7 | 3,456 | 381 | **0** |
> | *A. fumigatus* Af293 | 2,088 | 65 | **0** |
> | *T. brucei* TREU927 | 524 | 243 | **144** |
>
> TREU927 is the case that could have broken: it has **131** sequences in the DB, **36** of
> them never indeled by any strain, and organism scoping newly admits **144** pairs sitting
> on exactly those 36 contigs — pairs the old gate refused and for which there is no indel
> evidence at all that the contig was sequenced. So the FASTAs were checked directly.
> `STIB247_consensus.fa.gz`, `gambiense_consensus.fa.gz` and
> `TREU927_resequence1_consensus.fa.gz` each carry **131** deflines, and set-comparing each
> one's `<chrom>` fields against the DB's 131 `source_id`s gives **0 missing in either
> direction** — in particular **0 of the 36 never-indeled contigs is absent from any of the
> three FASTAs**. The invariant holds on the organism that would have exposed it, not merely
> on the one that could not.
>
> If a future pipeline ever dropped a contig from the consensus, or a non-genomic row landed
> under a strain-bearing taxon, this gate *would* mint an ID whose `chrom` is absent from the
> FASTA, and gate 3 would need a per-strain contig manifest rather than a taxon match.

Gate 4 becomes slightly more load-bearing under organism scoping, since it can no longer
rely on colon-free-ness being a property of the *indel-bearing* subset. It still refuses
nothing real: in `unidb_shu_a` **0** sequences reachable through gate 1+2 contain a colon
(the 10,704 figure quoted *above*, in the gate-4 paragraph, was measured on
`genomicsdb_rebuild01`, a different database), and all 9 Af293 contigs pass.

Strain membership itself is enforced by WDK, which validates a `flatVocabParam` value
against its vocabulary — that is what makes strain names a controlled vocabulary sourced
from `apidb.indel`, as required.

### 5.2 Strain vocabulary (global, not organism-dependent)

With no organism param there is nothing to depend on, so the vocabulary is global:

```sql
SELECT strain AS internal, strain AS term, strain AS display
FROM (
  SELECT DISTINCT regexp_replace(pan.name, '_Indel$', '') AS strain
  FROM (SELECT DISTINCT protocol_app_node_id FROM apidb.indel) x
     , study.protocolappnode pan
  WHERE pan.protocol_app_node_id = x.protocol_app_node_id
    AND pan.name LIKE '%\_Indel'
) t
ORDER BY strain
```

**6,119 strains in 2.9s**, measured 2026-07-31. Cached once globally rather than once per
organism, so cheaper in aggregate than the per-organism version it replaces (2.66s each).

Two shape details carried over from review, both load-bearing:

- Dedupe on the numeric `protocol_app_node_id` (6,249 values) **before** computing
  `regexp_replace`, not after. Deduping on the regexp'd string instead runs the function
  across all 43.6M indel rows and hash-aggregates text keys (timings and row counts here are
  `genomicsdb_rebuild01`; the live `unidb_shu_a` holds 1,855,449 indel rows over 1,356
  `protocolappnode` rows, so the same shape is simply cheaper) — measured 12,085ms versus
  2,681ms for identical output.
- `pan.name LIKE '%\_Indel'` makes the suffix invariant executable rather than merely
  documented; `regexp_replace` silently passes a non-conforming name through, which would
  become a bogus strain option. The backslash escape matters — `_` is a single-character
  wildcard in `LIKE`.

This is the controlled vocabulary required by the brief: strain names come from
`apidb.indel` (via `study.protocolappnode`, which is where the name actually lives). No
tuning table exists for it. Scoping to a *relevant* strain is not the vocabulary's job —
gate 3 of §5.1 rejects a strain with no indel data on the requested sequence's **organism**.
(It does *not* require data on that exact sequence; see §5.1.1.)

### 5.3 Attribute query: `StrainSegmentAttributes.Coords`

Emits eleven columns. Derived: `strain_seq_id`, `strain_start`, `strain_end`,
`strain_length`, `organism`. Passed through from the primary key so that consumers never
re-parse it: `source_id`, `project_id`, `strain`, `ref_seq`, `ref_start`, `ref_end` — §7's
defline needs the strain and the reference range, and decomposing the PK in exactly one
place is the whole point of §3.1.

`strain_seq_id` is `strain || '_' || refSeq` — pure concatenation, matching the FASTA
key (§2), and **opaque**: build it, never split it (§3.1). Offsets in one index-assisted
pass per `(strain, sequence)`, bounded by `location <= ref_end`:

```sql
SUM(CASE WHEN i.location < seg.ref_start THEN i.shift ELSE 0 END) AS offset_start,
SUM(i.shift)                                                     AS offset_end
```

Only the *start* offset needs conditional aggregation. The end bound
`i.location <= seg.ref_end` is in the `WHERE`, so every surviving row is in scope for the
end sum; an earlier revision wrote a mirrored
`CASE WHEN i.location <= seg.ref_end` whose `ELSE` branch was unreachable (verified 0 rows
disagreeing) and which made the boundary asymmetry appear to live in two places instead of
one.

**Resolve `protocol_app_node_id` via `(name, na_sequence_id)` and `GROUP BY` the
resolved node — never join on name alone.** All 126 duplicated strain names (§2) *already*
have two or more protocol app nodes (122 to two, 4 to three), all carrying indel rows
today, so the collision is live in the
data; what keeps it harmless is the narrower invariant the `i.na_sequence_id =
ens.na_sequence_id` join depends on — **no `(name, na_sequence_id)` pair is served by two
nodes (0 today)**. Grouping by node makes a violation of that produce two rows per primary
key, which WDK rejects with an error. Joining on name alone would sum two strains' shifts
into one plausible-looking wrong answer with nothing to detect it.

**Boundary rule (to be QA'd, per §9):** an indel exactly at `refStart` lies inside the
segment, so it shifts the end but not the start — hence `<` for start and `<=` (as the
`WHERE` bound) for end. An off-by-one here is silent and yields sequence that looks correct.

### 5.3.1 Group and join on the primary key, not on coordinates

An earlier implementation grouped the offsets subquery on `(strain, ref_start, ref_end)`
and joined on the same triple. **That silently corrupted every multi-record answer set.**
One `protocol_app_node_id` spans *all* of a strain's sequences (one Af293 node carries
indels on all 8 chromosomes), so two segments of the same strain on different sequences
collapsed into a single group whose `SUM` spanned both, and the join handed that conflated
row to both records. Measured on two 1-100000 segments of `NRZ-2016-071`, whose true
offsets are 12 (Chr1) and 14 (Chr2): both reported `strain_end = 100026`, i.e. 100000 + 26.
No error, no duplicate row, and `strain_seq_id` stayed correct — so the BED line pointed at
the right contig with another chromosome's indel budget applied to its coordinates. A
single-record test cannot see this; a reporter over a multi-segment result set is the
normal case.

Adding `ref_seq` to the grouping would fix the symptom. Instead **group and join on
`source_id`** — the whole primary key — so "one row per input PK" holds by construction
rather than by an argument about which coordinate fields happen to discriminate. Verified
after the change: 100012 and 100014 respectively, and a third id differing only in strand
yields 3 rows rather than 6 (strand correctly does not discriminate, since offsets do not
depend on it).

`i.protocol_app_node_id` stays in the `GROUP BY` alongside `source_id`, still absent from
the `SELECT` — that is the collision detector described above, and it is now the only
grouping column that is not the PK.

`##WDK_ID_SQL##` is expanded **once**, into a `WITH parsed AS (...)` CTE; `ids` adds the
resolved `dots.ExternalNaSequence` row to it and is referenced twice. Precedent:
`transcriptAttributeQueries.xml:209`. Postgres materializes `ids` (confirmed: a single
`CTE ids` node with two `CTE Scan` references), so the id set is scanned once and the four
`split_part` expressions exist in one place.

Three further structural rules, each guarding a silent-wrong-answer mode:

- **`ids` resolves the reference sequence, and is the *only* place that does.** It therefore
  *filters* as well as projects — an unknown `ref_seq` drops the row here, which is exactly
  the "unknown sequence yields no record" rule. The offsets subquery originally repeated the
  same `dots.ExternalNaSequence` lookup (a second index scan per PK, and the same rule
  enforced in two places); it now consumes `ids.na_sequence_id`.
- **The offsets are summed over a `DISTINCT` id set (`segs`), not the raw one.** Scanning the
  raw set makes the sums proportional to input multiplicity: a repeated `source_id` in
  `##WDK_ID_SQL##` joins each indel row once per duplicate and `GROUP BY source_id` collapses
  them into one group whose `SUM` is multiplied. Demonstrated before the fix — PK
  `366.1:Pf3D7_10_v3:331757-331757:f` supplied twice yielded offsets −198/−306 instead of
  −99/−153, silently. Not reachable through today's ID query, but keying on the PK is
  supposed to make one-row-per-PK true *by construction*, not by an argument about the input.
  Regression test: the same PK twice must yield 2 rows with the single-copy offsets.
- **`strain_length` is computed in an outer `SELECT` from the named `strain_start` /
  `strain_end` columns**, because a `SELECT` cannot reference its own aliases and the offset
  arithmetic would otherwise be written twice. A partial edit to one copy would yield a
  length that disagrees with its own start and end.

### 5.3.2 A segment inside a deletion inverts, deliberately

The boundary asymmetry means a deletion at `refStart` shifts the end but not the start, so
a short segment lying inside a deletion produces `strain_end < strain_start`. This is
reachable with ordinary input, not a torture case: `apidb.indel` has 180,998 rows with
`shift <= -20` and the ID query permits `start = end`. Real example — PK
`366.1:Pf3D7_10_v3:331757-331757:f`, a 1-bp segment on a `shift = -54` event, gives
`strain_start = 331658`, `strain_end = 331604`.

That arithmetic is *correct*: the reference base does not exist in that strain, so the
range maps to nothing. So:

- `strain_start` and `strain_end` report the true, possibly inverted values — **not**
  clamped, because the reporter needs to see the inversion;
- `strain_length` is `GREATEST(..., 0)`, since a negative length is not a defensible
  attribute value;
- `StrainSegmentFeatureProvider` (§7) **MUST** reject `strain_end < strain_start` with an
  explicit error. That is the right place for it — a malformed BED interval must fail loudly
  rather than reach a FASTA lookup. **Implemented** in `ApiCommonWebsite` `a3c062e03`, hardened
  in `e5346e9c4`. The guard is now three conditions, and leaving `strain_start`/`strain_end`
  unclamped depends on all three:
  1. `strain_end < strain_start` — the deletion inversion this section is about;
  2. `strain_start < 1` — would emit `chromStart = -1` via `BedLine.locationToZeroBased`;
  3. the `strain_seq_id` attribute must equal the key `StrainSegmentId` computes from the
     primary key — a tripwire for any future rewrite of that column, since a divergence would
     otherwise be a BED line naming the wrong contig with no error.

  All three throw `WdkModelException` naming the primary key and the offending values, before
  `DeflineBuilder` or `BedLine.bed6` sees them; `BedReporter.write` does not swallow it, so the
  download aborts. Covered by `StrainSegmentFeatureProviderTest` (10 tests), including the live
  case `366.1:Pf3D7_10_v3:331757-331757:f`. **If that guard is ever removed, these columns must
  be clamped instead.**

## 6. Record class (`ApiCommonModel`)

`StrainSegmentRecordClasses.StrainSegmentRecordClass`,
`urlName="strain-genomic-segment"`, `doNotTest="true"`, **`useBasket="false"`**.

`useBasket="false"` is required, not cosmetic: `RecordClass.useBasket` defaults to `true`
(`RecordClass.java:303`), and `WdkModel.addBasketReferences` (`WdkModel.java:646-652`)
then injects `..._RealtimeBasket` / `..._SnapshotBasket` questions and their `user_baskets`
id queries, while `RecordClassFormatter.java:75` reports `useBasket` to the client so the
results table offers basket affordances. Matches every other internal record class here
(`fileRecord.xml:4`, `userfileRecords.xml:4`, `ajaxRecords.xml:16,35`); DynSpan leaving the
default alone is not a counterexample, since DynSpan is user-facing.

Reporters: **`bed` only** (plus WDK's unavoidable default JSON reporter — see below).
Attributes: a `columnAttribute` for each of the nine non-primary-key columns §5.3 emits —
the passed-through `strain`, `ref_seq`, `ref_start`, `ref_end` included, since §7's defline
consumes them — plus the `idAttribute` over the `source_id`/`project_id` primary key. No
tables.

**What "no record page" does and does not mean.** It is an intent, not something WDK
enforces. WDK unconditionally injects a `_default` summary view
(`RecordClass.java:1306` → `SummaryView.createSupportedSummaryViews`), a `_default` record
view displayed as "Overview" (`RecordClass.java:1346` →
`RecordView.createSupportedRecordViews`), and `DefaultJsonReporter`
(`RecordClass.java:1137-1139`). The nine `columnAttribute`s are ordinary *display*
attributes — they carry `displayName` and are not `internal="true"`, and they must stay
that way because the BED reporter reads them. The real basis for "non-user-facing" is
narrower and sufficient: no tables, no reporters beyond `bed`, no ontology rows, so nothing
wires up a record page. A record-page request is not a supported operation and is not
verified to degrade gracefully.

Register the new files in `Model/lib/wdk/apiCommonModel.xml`, alongside the existing
span imports at lines 419-423.

### 6.1 Keeping it non-user-facing

`Model/lib/wdk/ontology/individuals.txt` is a 14-column TSV:

| col | meaning |
|---|---|
| 1 | full node name |
| 4 | `recordClassName` |
| 5 | `targetType` (`search` / `table` / `attribute` / `dataset`) |
| 6 | `name` (e.g. `SpanQuestions.DynSpansBySourceId`) |
| 12-14 | three `scope` columns |

Scope combinations across the 202 `targetType=search` rows, measured 2026-07-31:

| scopes | count |
|---|---|
| `menu` `webservice` | 95 |
| `internal` `webservice` | 42 |
| *(none)* | 27 |
| `webservice` | 17 |
| `menu` | 15 |
| `internal` | 6 |

**Decision: add no row at all for the new search.** Two mechanisms could hide it, and
omission is the right one here:

- **Omission** — `DynSpansBySegIds` (`spanQuestions.xml:15`, commented "SegIds only
  WEBSERVICES" at `spanQueries.xml:7`) is absent from `individuals.txt` and the model
  builds. A question stays addressable by name through the service API regardless of
  ontology presence. This is *the* precedent for a hand-written webservice-only span
  search — exactly our case, and it is the **only** one. An earlier draft of this spec
  also cited `DynSpansByLocation`; that was wrong and is corrected in §5.1 —
  `DynSpansByLocation` is only an `<sqlQuery>` (`spanQueries.xml:266`) with no
  `<question>` and no references anywhere, so it demonstrates nothing about service-API
  reachability.
- **`internal` + `webservice`** — all 42 users are *injected per-dataset* searches, which
  need ontology presence for categorization to work. Not our situation.

Consequence for verification: the search must be **absent** from
`/service/ontologies/Categories` (§9.4). Also, since no ontology node is added, this work
does **not** touch categorization — so `wb model` suffices and `wb ontology` is not
required. (It would be required if a row were ever added.)

## 7. BED reporter (`ApiCommonWebsite` **and one model-side element**)

Three deliverables, not two. The third is easy to lose because it lives in a different
repo from the other two:

1. `BedStrainSegmentReporter extends BedReporter` (`ApiCommonWebsite`)
2. `StrainSegmentFeatureProvider implements BedFeatureProvider` (`ApiCommonWebsite`)
3. the `<reporter>` element on the record class (`ApiCommonModel`,
   `Model/lib/wdk/model/records/strainSegmentRecord.xml`) — **exact shape**:

```xml
<reporter name="bed" displayName="BED - coordinates in strain sequence, configurable" scopes="results" implementation="org.apidb.apicommon.model.report.bed.BedStrainSegmentReporter"/>
```

`scopes="results"`, *not* `"results,record"`. The precedents `dynSpanRecord.xml:35` and
`genomicRecords.xml:121` use `"results,record"`, but this class must not claim a `record`
scope: §6 gives it no record page to download from.

`name="bed"` is the literal string §9's verification passes as `reportName`, so it must
match exactly.

The element cannot land before the Java class: `ReporterRef.resolveReferences` does
`Class.forName` on the implementation at model-load time and hard-fails the build if it is
absent. Hence it ships in Task 6 alongside the reporter, not in Task 5 — which is exactly
why it is at risk of being forgotten (see §10): **omit it and there is no BED download and
no error anywhere**, because nothing in the model or the Java code references the reporter
by name at build time.

`BedStrainSegmentReporter` / `StrainSegmentFeatureProvider` follow
`BedGenomicSequenceReporter` / `GenomicSequenceFeatureProvider` — the existing precedent
for a provider that computes coordinates from **attributes** rather than from the PK.

`getRequiredAttributeNames()` = `{strain_seq_id, strain_start, strain_end, organism}`.
Strain is parsed from the PK, so it needs no attribute.

The two BED columns have very different constraints:

| Column | Constraint |
|---|---|
| `chrom` | **Hard.** Must equal `<strain>_<refSeq>` — the strain FASTA index key. Lookup fails otherwise. |
| `name` | **Free.** Under `deflineFormat=QUERYONLY`, `Deflines.deflineForFeature` emits `'>' + feature.getName()` verbatim, so this becomes the output defline. Ours to design. |

So `chrom = strain_seq_id`, and the `name` column carries provenance via
`DeflineBuilder`, honouring `RequestedDeflineFields` as `DynSpanFeatureProvider` does
(`DynSpanFeatureProvider.java:57-72`):

The shape `DeflineBuilder.appendPosition` actually produces, with all fields requested
(`deflineType=full`):

```
>A0003:AACB03000001:100-200:f | Aspergillus fumigatus Af293 | A0003 | AACB03000001, forward strand, 100 to 200 | A0003_AACB03000001, forward strand, 143 to 241 | segment_length=99
```

Carrying both coordinate systems is the payoff for choosing reference coordinates in
the PK (§3). The two ranges stay distinguishable because the first names the reference
sequence and the second carries the strain prefix.

**An earlier revision illustrated the two ranges as `ref 100 to 200 | strain 143 to 241`.**
Nothing ever emitted that. Matching it would have meant adding a `DeflineBuilder` method or
hand-rolling strings — duplicating the builder for cosmetics — and it silently dropped the
strand, which `appendPosition` includes. The `name` column is declared **Free** above and
the normative requirement is only that it carry provenance through `DeflineBuilder` honouring
`RequestedDeflineFields`, which the implementation satisfies literally. Recorded so nobody
"fixes" working code to match a retired example, and so §9 verifies against the real string.

## 8. Deferred: seqret wiring

Sequence types in `service-sequence-retrieval` are pure configuration —
`ReferenceDAOFactory.init()` reads `ALL_REFERENCE_SEQUENCE_NAMES` plus per-name
`_FASTA_FILE`, `_INDEX_FILE`, `_IS_STRANDED`, `_MAX_SEQUENCES_PER_REQUEST`,
`_MAX_TOTAL_BASES_PER_REQUEST`. **No service code change is needed.**

When picked up, the work is: add a `SequenceType` enum value and one switch arm in
`SequenceReporter.getSequenceTypeByRecordClassFullName` (`SequenceReporter.java:94-113`)
— the single hard-coded record-class-to-FASTA seam — register the `sequence` reporter on
the record class, and add the env vars. `SequenceType.name()` goes straight into the
request URL and `ReferenceDAOFactory.get()` lowercases, so the enum name must equal the
configured sequence name.

## 9. Verification

**Development target is fungidb** (`~/workspaces/fungidb`, branch
`strain-segment-record`, sync up). **Not giardiadb:** it has 6,902 Giardia sequences
across 14 organisms and **zero** `apidb.indel` rows, so nothing there exercises this code.

QA organism: *Aspergillus fumigatus* Af293 — 1,117 strains, 5,085,377 indels. Other
dense options: *Cryptococcus neoformans* H99 (875), *Candida auris* B8441 (502),
*Cryptococcus deuterogattii* R265 (293).

1. **SQL as WDK runs it** — `wdkQuery -model FungiDB -query
   StrainSegmentAttributes.Coords -showQuery` (and `-showParams`). Renders post-injection
   SQL without executing. Requires a prior `wb model`.
2. **Execute** the rendered SQL read-only in psql against the tunnelled genomicsdb.
   `%%PARTITION_KEYS%%` does not apply — this is not a partitioned gene-table query.
3. **Registration** — `/service/record-types/strain-genomic-segment` lists the class and
   its searches. Fetch from an authenticated app page (`javascript_tool`), since a raw
   curl 307s to autologin.
4. **Invisibility** — the search must be **absent** from `/service/ontologies/Categories`.
   That endpoint is not project-filtered, so absence there is the meaningful check.
5. **Shift correctness** — the boundary rule in §5.3. Pick a strain and sequence with
   known indels, compute the expected prefix sum directly in psql, compare against
   `strain_start`/`strain_end`.
6. **Free signal for §5.3 once §8 lands:** seqret validates the feature against the
   strain contig's indexed length and *fails open*, appending
   `" | error_code=NOT_REQUESTED_LENGTH"` to the defline when `end > indexLength`
   (`Deflines.java`). A correct implementation never produces it. It is silent by
   design — nothing errors — so it only helps if deflines are actually read.

## 10. Risks and open items

| Item | Status |
|---|---|
| `<`/`<=` boundary at `refStart` | **open** — ships as specified, QA per §9.5 |
| Ontology absence hides the search | **verified** 2026-07-31 — see §6.1 |
| `(name, na_sequence_id)` uniqueness | true today, unconstrained; §5.3 grouping converts a violation to an error |
| **A strain set covers every contig of its organism's reference** | true today, unconstrained — the residual assumption introduced by organism-level gate 3 (§5.1.1). Really *set equality* between a taxon's `dots.ExternalNaSequence` rows and the consensus deflines, and it can drift from either side (a pipeline dropping a contig; a non-genomic sequence gaining a row under a strain-bearing taxon, which only gate 4's colon filter incidentally catches). Verified on three organisms including *T. brucei* TREU927, where 144 newly-admitted pairs sit on 36 never-indeled contigs and all 131 deflines match the DB set exactly. Nothing enforces it; a breach mints an ID whose `chrom` has no FASTA entry, with **no error anywhere**. Fix would be a per-strain contig manifest. |
| Reject-path cost of gate 3 | **accepted, measured** — a false `EXISTS` scans all of a strain's indel rows: ~101 ms vs ~53 ms for the largest strain here (§5.1.1). The `LIMIT 1` rewrite that would fix it is rejected on purpose; it trades slow for silently wrong. |
| Prefix-sum cost | heaviest strain/sequence pair carries ~115k events; the `location <= ref_end` bound plus `ix0`/`ix1` should hold, but measure on Af293 |
| Categorization rebuild | not applicable — §6.1 adds no ontology node, so `wb model` suffices. If a row is ever added, it becomes `wb ontology` (a superset of `wb model`). |
| **Model-side `<reporter name="bed">` element silently missing** | **open until Task 6** — it ships in a different repo from the two Java classes (§7.3), and nothing references it at build time. Omit it and there is no BED download and **no error anywhere**: `/service/record-types/strain-genomic-segment` simply lists no `bed` format. Verification: that endpoint's `formats` must contain `bed` with `scopes` = `results` only. |
| Reporter `scopes` over-claimed | **open until Task 6** — copying `scopes="results,record"` from `dynSpanRecord.xml:35` / `genomicRecords.xml:121` would advertise a record-scope download on a class with no record page. Must be `scopes="results"`. |
