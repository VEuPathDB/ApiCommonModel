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

`shift` is a **signed per-event delta**, never zero: range −101..+80, with 21,945,521
negative and 21,640,063 positive rows. The strain offset at a reference position is
therefore a *prefix sum*, partitioned by `(protocol_app_node_id, na_sequence_id)`.

### `study.protocolappnode` — strain vocabulary

Strain name is `name` with the suffix `_Indel` removed: `A0003_Indel`, `S7_Indel`,
`A17-48H-7_Indel`, `X10462-P1C9_Indel`.

Verified properties of the 6,119 distinct names appearing in `apidb.indel`:

| Property | Result | Consequence |
|---|---|---|
| contain `:` | **0** | the colon-delimited PK grammar (§3) is unambiguous |
| end in `_Indel` | **6,119 / 6,119** | the suffix strip is uniform; no special cases |
| contain any other `_` | **0** | `<strain>_<refSeq>` concatenation is unambiguous |
| map to >1 organism | **126** (256 nodes) | strain name is **not** globally unique — see §5.2 |
| `(name, na_sequence_id)` -> >1 node | **0** | sequence-scoped resolution is unambiguous *today* |

That last row is a **data-dependent invariant with no constraint enforcing it**. §5.2
specifies a query shape that turns a future violation into an error rather than silent
corruption.

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
**`<strain>_<refSeq>`**. `checkUniqueIds.sh` hard-fails (exit 125) on any duplicate
defline across the merged file, so it is **one merged multi-strain FASTA**, not one file
per strain — meaning one seqret sequence type suffices whenever §8 is picked up.

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
on the portal. This record instead takes `project_id` from the data
(`webready.GenomicSeqAttributes_p.project_id`), so it is populated correctly on every
project including UniDB and needs no fork. One query, one PK, no variants.

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

**As implemented** (commits `19defeba2`, `3ead3adac`):

```
^([^:_]+):([^:]+):(\d+)-(\d+):(f|r)$
```

Two details of that pattern are load-bearing:

- Fields are `[^:]+`, not DynSpan's greedy `(.*)`, so an ID carrying an extra colon is
  **rejected** rather than mis-parsed into a different segment.
- The **strain** group additionally excludes `_`, because the FASTA key is
  `<strain>_<refSeq>` and reference sequence IDs legitimately contain underscores
  (`Pf3D7_01_v3`). Without that exclusion, strain `A_B` + sequence `C` and strain `A` +
  sequence `B_C` would both yield the key `A_B_C`. No current strain name contains an
  underscore (0 of 6,119), so this is inert today and converts a future ambiguous key
  into a loud parse failure. Group 2 stays `[^:]+`.

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

Params: `strain`, `sequenceId`, `start`, `end`, `strand`. **There is no organism param.**

### 5.1.1 Why no organism input

An earlier draft took an organism as a first param, used it to prune the `org_abbrev`
partition key and to check that the reference sequence belonged to it. That was redundant
input: **a reference sequence ID already determines its organism.** Being handed an
organism as well only creates a consistency question the query then has to answer.

Dropping it removes three problems at once:

- **No partition-key concern.** Resolve the sequence through unpartitioned
  `dots.ExternalNaSequence` (`source_id_uniq` index; carries `na_sequence_id`, `taxon_id`,
  `length`) rather than `webready.GenomicSeqAttributes_p`. Same table path §5.3 already
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

Three gates, all as filters so bad input yields **zero records** rather than a broken
download:

1. the reference sequence exists — `dots.ExternalNaSequence.source_id = $$sequenceId$$`;
2. `1 <= refStart <= refEnd <= ens.length`;
3. the strain has indel data on **this** sequence — an `EXISTS` over `apidb.indel` joined to
   `study.protocolappnode`, matched on `na_sequence_id`.

Gate 3 subsumes the organism check the earlier draft did explicitly: if the strain has indel
rows on that sequence, strain and sequence are consistent **by construction**. That is a
stronger guarantee than validating against a user-supplied organism, and it is what the
original requirement ("validate the reference sequence against the reference organism")
actually wanted.

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
  across all 43.6M indel rows and hash-aggregates text keys — measured 12,085ms versus
  2,681ms for identical output.
- `pan.name LIKE '%\_Indel'` makes the suffix invariant executable rather than merely
  documented; `regexp_replace` silently passes a non-conforming name through, which would
  become a bogus strain option. The backslash escape matters — `_` is a single-character
  wildcard in `LIKE`.

This is the controlled vocabulary required by the brief: strain names come from
`apidb.indel` (via `study.protocolappnode`, which is where the name actually lives). No
tuning table exists for it. Scoping to a *relevant* strain is not the vocabulary's job —
gate 3 of §5.1 rejects a strain with no data on the requested sequence.

### 5.3 Attribute query: `StrainSegmentAttributes.Coords`

Emits `strain_seq_id`, `strain_start`, `strain_end`, `strain_length`, `organism`.

`strain_seq_id` is `strain || '_' || refSeq` — pure concatenation, matching the FASTA
key (§2). Offsets in one index-assisted pass per `(strain, sequence)`, bounded by
`location <= ref_end`, using conditional aggregation rather than two correlated
subqueries:

```sql
SUM(CASE WHEN i.location <  seg.ref_start THEN i.shift ELSE 0 END) AS offset_start,
SUM(CASE WHEN i.location <= seg.ref_end   THEN i.shift ELSE 0 END) AS offset_end
```

**Resolve `protocol_app_node_id` via `(name, na_sequence_id)` and `GROUP BY` the
resolved node — never join on name alone.** 126 strain names map to more than one
organism (§2). Grouping by node makes a future collision produce two rows per primary
key, which WDK rejects with an error. Joining on name alone would sum two strains'
shifts into one plausible-looking wrong answer with nothing to detect it.

**Boundary rule (to be QA'd, per §9):** an indel exactly at `refStart` lies inside the
segment, so it shifts the end but not the start — hence `<` for start, `<=` for end. An
off-by-one here is silent and yields sequence that looks correct.

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

`##WDK_ID_SQL##` is expanded **once**, into a `WITH ids AS (...)` CTE referenced twice.
Precedent: `transcriptAttributeQueries.xml:209`. Postgres materializes it (confirmed: a
single `CTE ids` node with two `CTE Scan` references), so the id set is scanned once and
the four `split_part` expressions exist in one place.

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
- the BED feature provider (§7) rejects `strain_end < strain_start` with an explicit
  error. That is the right place for it — a malformed BED interval must fail loudly rather
  than reach a FASTA lookup.

## 6. Record class (`ApiCommonModel`)

`StrainSegmentRecordClasses.StrainSegmentRecordClass`,
`urlName="strain-genomic-segment"`, `doNotTest="true"`.

Reporters: **`bed` only** (see §8). Attributes: exactly those §5.3 emits, plus the
`idAttribute`. No tables, no summary view, no text attributes for display.

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

- **Omission** — `DynSpansBySegIds` (commented "SegIds only WEBSERVICES",
  `spanQueries.xml:7`) and `DynSpansByLocation` are both absent from `individuals.txt`
  and the model builds. A question stays addressable by name through the service API
  regardless of ontology presence. This is the precedent for a *hand-written*
  webservice-only span search — exactly our case.
- **`internal` + `webservice`** — all 42 users are *injected per-dataset* searches, which
  need ontology presence for categorization to work. Not our situation.

Consequence for verification: the search must be **absent** from
`/service/ontologies/Categories` (§9.4). Also, since no ontology node is added, this work
does **not** touch categorization — so `wb model` suffices and `wb ontology` is not
required. (It would be required if a row were ever added.)

## 7. BED reporter (`ApiCommonWebsite`)

`BedStrainSegmentReporter extends BedReporter` + `StrainSegmentFeatureProvider
implements BedFeatureProvider`, following `BedGenomicSequenceReporter` /
`GenomicSequenceFeatureProvider` — the existing precedent for a provider that computes
coordinates from **attributes** rather than from the PK.

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

```
>A0003:AACB03000001:100-200:f | Aspergillus fumigatus Af293 | A0003 | ref 100 to 200 | strain 143 to 241 | segment_length=99
```

Carrying both coordinate systems is the payoff for choosing reference coordinates in
the PK (§3).

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
| Prefix-sum cost | heaviest strain/sequence pair carries ~115k events; the `location <= ref_end` bound plus `ix0`/`ix1` should hold, but measure on Af293 |
| Categorization rebuild | not applicable — §6.1 adds no ontology node, so `wb model` suffices. If a row is ever added, it becomes `wb ontology` (a superset of `wb model`). |
