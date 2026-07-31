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

Params: `organism` (single pick), `strain` (enum, **dependent on organism**),
`sequenceId`, `start`, `end`, `strand`.

The organism param's **internal value is `org_abbrev`**, so the partition key is
available directly to every query without an extra lookup. Precedent:
`organismParams.organism_span` is compared straight against `org_abbrev` columns at
`spanQueries.xml:203-205`. The display organism name, when needed for a defline or a
join, comes from `webready.organismabbreviation_p` keyed on the same `org_abbrev`.

Three gates, all as joins/filters so bad input yields **zero records** rather than a
broken download:

1. `strain` is in the vocabulary for the chosen organism (§5.2 query);
2. `refSeq` belongs to the chosen organism — join `webready.genomicseqattributes_p`
   constraining `org_abbrev` to the chosen organism, which is both the partition key and
   the organism-membership check that `DynSpansBySourceId` omits;
3. `1 <= refStart <= refEnd <= gsa.length`.

### 5.2 Strain vocabulary (dependent param)

```sql
SELECT DISTINCT regexp_replace(pan.name, '_Indel$', '') AS strain
FROM apidb.indel i
  JOIN study.protocolappnode pan ON pan.protocol_app_node_id = i.protocol_app_node_id
  JOIN webready.genomicseqattributes_p gsa ON gsa.na_sequence_id = i.na_sequence_id
WHERE gsa.org_abbrev = $$organism$$             -- partition key; param's internal value
```

(`$$organism$$` is the `org_abbrev` internal value per §5.1, so this both scopes the
vocabulary to the chosen organism and hits the partition.)

This is the controlled vocabulary required by the brief: strain names come from
`apidb.indel`, scoped per organism. No tuning table exists for it.

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
