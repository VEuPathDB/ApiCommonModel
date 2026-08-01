# Strain Genomic Segment Record Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an internal `strain-genomic-segment` WDK record class that takes a single reference-coordinate genomic location plus a strain, and emits a BED feature in that strain's consensus-sequence coordinates.

**Architecture:** The record's primary key carries *reference* coordinates plus the strain (`<strain>:<refSeq>:<refStart>-<refEnd>:<f|r>`). One ID query validates strain, reference sequence, and range, returning zero rows if any gate fails. One attribute query converts reference to strain coordinates by prefix-summing `apidb.indel.shift`. A `BedFeatureProvider` reads those attributes and writes a BED line whose `chrom` is `<strain>_<refSeq>` — the key into the strain consensus FASTA. The pipeline deliberately stops at BED; seqret wiring is out of scope.

**Tech Stack:** WDK model XML (`ApiCommonModel`), Java 11 + JUnit 4 (`ApiCommonWebsite/Model`), PostgreSQL 18, Maven, `wb` build wrapper.

**Design spec:** `docs/superpowers/specs/2026-07-31-strain-segment-record-design.md` (this repo). Read it first — it records the measured data facts and the reasoning behind each decision.

---

## Orientation for someone new to this codebase

**Two repos, one branch name.** Model XML lives in `ApiCommonModel`; Java lives in `ApiCommonWebsite`. Both have a `strain-segment-record` branch off `master` in `~/workspaces/fungidb/`. Commit in whichever repo you touched.

**Nothing builds locally.** `~/workspaces/fungidb` is synced by mutagen to `cedar:/var/www/jbrestel.fungidb.org/project_home`, and all builds and tests run on `cedar`. Edit locally, save, and mutagen carries the bytes within a second or two. Never build in the local checkout.

**After any commit or branch switch, run `bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb`.** Mutagen ignores `.git`, so the remote's refs go stale and its `git status` fills with modifications that are not real. This script reconciles refs only and never touches file contents. A local commit you have not pushed reports `UNPUSHED` and is skipped — that is expected and harmless here, since the build reads files, not git.

**An XML file that no one imports is inert.** `Model/lib/wdk/apiCommonModel.xml` lists every model file. Until you add an `<import>`, a new file is not parsed and cannot break the build. Tasks 2-4 exploit this: they land XML that is not yet imported, so each can be committed safely without a working model. Task 5 wires it in and is the first task that can fail a build.

**Useful commands:**

```bash
# build the model on the remote (also reloads the webapp)
bash ~/workspaces/agentic-veupath-dev/bin/veup-build.sh fungidb wb model

# render a query's SQL exactly as WDK will run it, without executing
ssh cedar 'bash -lc "source /var/www/jbrestel.fungidb.org/etc/setenv && \
  wdkQuery -model FungiDB -query <QuerySet.queryName> -showQuery"'

# read-only SQL against the app database
psql -h localhost -p 5439 -d genomicsdb_rebuild01 -c "<sql>"

# log delta around a page load
bash ~/workspaces/agentic-veupath-dev/bin/veup-logs.sh fungidb mark t1
bash ~/workspaces/agentic-veupath-dev/bin/veup-logs.sh fungidb since t1
```

`wb ontology` is **not** needed: this work adds no ontology node (spec §6.1). `wb model` suffices.

> **`wb model` does NOT compile `ApiCommonWebsite/Model`.** Verified in `gus_home/bin/wb`: the
> `model` target runs `bld EbrcModelCommon/Model; bld ApiCommonModel/Model` and nothing else;
> `site` covers `Website/Site` and `ontology` adds `Presenters/Model`. No `wb` target builds
> `ApiCommonWebsite/Model`. So after editing Java there (Tasks 1 and 6), run:
>
> ```bash
> ssh cedar 'bash -lc "source /var/www/jbrestel.fungidb.org/etc/setenv && bld ApiCommonWebsite/Model"'
> ```
>
> **Running more than one test class:** this module is on surefire 2.12.4, where `-Dtest=A+B`
> matches **zero** tests and still reports `BUILD SUCCESS` — a green run that tested nothing.
> Use a comma: `-Dtest=StrainSegmentIdTest,StrainSegmentFeatureProviderTest`. Always check the
> `Tests run:` counts rather than trusting the exit status.
>
> **The failure mode is misleading, which is why this is worth knowing:** `mvn test` compiles
> to `target/classes`, which is not on `wdkXml`'s classpath — the jar must be installed into
> `gus_home/lib/java`. Skip the `bld` and `wb model` fails with `Implementation class for
> reporter 'bed' … cannot be found` / `ClassNotFoundException`, which reads as "the XML
> registration is wrong" when in fact the XML is fine and the class simply was never deployed.
> Do not respond to that error by reverting the `<reporter>` element.

---

## File structure

**`ApiCommonModel`** — all paths under `Model/lib/wdk/`:

| File | Responsibility |
|---|---|
| `model/questions/params/strainSegmentParams.xml` | *new* — the `strain` flat-vocab param and its **global** vocabulary query (not organism-dependent; there is no organism param — spec §5.1.1) |
| `model/questions/queries/strainSegmentQueries.xml` | *new* — the ID query; all four validation gates live here |
| `model/records/strainSegmentAttributeQueries.xml` | *new* — the reference-to-strain coordinate conversion |
| `model/records/strainSegmentRecord.xml` | *new* — record class and attributes. The BED `<reporter>` element is added in **Task 6**, not Task 5: WDK's `ReporterRef.resolveReferences` does `Class.forName` at model-load time, so registering it before the Java class exists hard-fails the build |
| `model/questions/strainSegmentQuestions.xml` | *new* — the question that binds query to record class |
| `apiCommonModel.xml` | *modify* — five `<import>` lines near the existing span imports at 419-423 |

**`ApiCommonWebsite`** — all paths under `Model/src/`:

| File | Responsibility |
|---|---|
| `main/java/org/apidb/apicommon/model/report/bed/util/StrainSegmentId.java` | *new* — the single parse/format authority for the PK grammar |
| `test/java/org/apidb/apicommon/model/report/bed/util/StrainSegmentIdTest.java` | *new* — unit tests for the grammar |
| `main/java/org/apidb/apicommon/model/report/bed/feature/StrainSegmentFeatureProvider.java` | *new* — record to BED fields |
| `main/java/org/apidb/apicommon/model/report/bed/BedStrainSegmentReporter.java` | *new* — three-line reporter wiring |

One responsibility each. The grammar class is the only piece with no WDK dependencies, which is exactly why it is the only piece that gets real unit tests — everything else needs a live `RecordInstance` and is verified against the running site.

---

## Task 1: The PK grammar class

> **COMPLETE — amended twice after code review.** Commits `19defeba2` (as written below),
> `3ead3adac` (review fixes), `65126443a` (bug fix). The code block in Step 3 is what was
> *planned*; the shipped version differs, all worth knowing if you touch this class:
> the regex is `^([^:]+):([^:]+):(\d+)-(\d+):(f|r)$` — every field excludes only `':'`,
> the sole delimiter; validation lives in the private constructor rather than `parse()`,
> and adds a `refStart < 1` check; and both `parseInt` calls rethrow with the full ID in
> the message. 20 tests, not 12. See spec §3.1 for the reasoning.
>
> **The strain group was briefly `[^:_]+` and that was a live bug**, rejecting the 1,494 of
> 6,119 strain names (24%) that contain an underscore. It came from a false "no strain name
> contains an underscore" measurement asserted in Task 2's preamble. Do not reintroduce it:
> narrowing the grammar cannot make `<strain>_<refSeq>` reversible anyway, because reference
> sequence IDs contain underscores too. The key is opaque; parse the PK instead.

The `ApiCommonWebsite/Model` module has JUnit 4 on its classpath but no `src/test/java` tree yet. You are creating it. Standard Maven layout means Surefire picks it up with no POM change.

**Files:**
- Create: `ApiCommonWebsite/Model/src/test/java/org/apidb/apicommon/model/report/bed/util/StrainSegmentIdTest.java`
- Create: `ApiCommonWebsite/Model/src/main/java/org/apidb/apicommon/model/report/bed/util/StrainSegmentId.java`

- [ ] **Step 1: Write the failing test**

Create `StrainSegmentIdTest.java`:

```java
package org.apidb.apicommon.model.report.bed.util;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;

import org.junit.Test;

public class StrainSegmentIdTest {

  @Test
  public void parsesForwardStrandId() {
    StrainSegmentId id = StrainSegmentId.parse("A0003:AACB03000001:100-200:f");
    assertEquals("A0003", id.getStrain());
    assertEquals("AACB03000001", id.getRefSeq());
    assertEquals(100, id.getRefStart());
    assertEquals(200, id.getRefEnd());
    assertEquals(StrandDirection.forward, id.getStrand());
  }

  @Test
  public void parsesReverseStrandId() {
    StrainSegmentId id = StrainSegmentId.parse("S7:AACB03000001:1-50:r");
    assertEquals("S7", id.getStrain());
    assertEquals(StrandDirection.reverse, id.getStrand());
  }

  // The BED chrom column must equal the dnaseq consensus FASTA defline,
  // which makeConsensusFastaFromVcfAndBed.py writes as <sample>_<chrom>.
  @Test
  public void strainSeqIdMatchesFastaKey() {
    assertEquals("A0003_AACB03000001",
        StrainSegmentId.parse("A0003:AACB03000001:100-200:f").getStrainSeqId());
  }

  // Real strain names contain hyphens; the range is a separate colon field so this is safe.
  @Test
  public void strainNameWithHyphensSurvives() {
    StrainSegmentId id = StrainSegmentId.parse("X10462-P1C9:AACB03000001:1-50:r");
    assertEquals("X10462-P1C9", id.getStrain());
    assertEquals(1, id.getRefStart());
    assertEquals(50, id.getRefEnd());
  }

  @Test
  public void formatRoundTripsBothStrands() {
    String forward = "A17-48H-7:AACB03000001:5-9:f";
    String reverse = "A17-48H-7:AACB03000001:5-9:r";
    assertEquals(forward, StrainSegmentId.parse(forward).format());
    assertEquals(reverse, StrainSegmentId.parse(reverse).format());
  }

  // DynSpan's greedy "^(.*):" regex silently mis-parses these. We reject instead.
  @Test
  public void rejectsColonInSequenceIdRatherThanMisparsing() {
    assertRejected("A0003:AAC:B03:100-200:f");
  }

  @Test
  public void rejectsMissingStrand() {
    assertRejected("A0003:AACB03000001:100-200");
  }

  @Test
  public void rejectsMissingStrain() {
    assertRejected("AACB03000001:100-200:f");
  }

  @Test
  public void rejectsStartGreaterThanEnd() {
    assertRejected("A0003:AACB03000001:200-100:f");
  }

  @Test
  public void rejectsNonNumericCoordinates() {
    assertRejected("A0003:AACB03000001:abc-200:f");
  }

  @Test
  public void rejectsBadStrandLetter() {
    assertRejected("A0003:AACB03000001:100-200:x");
  }

  @Test
  public void rejectsNull() {
    assertRejected(null);
  }

  private static void assertRejected(String sourceId) {
    try {
      StrainSegmentId.parse(sourceId);
      fail("expected IllegalArgumentException for: " + sourceId);
    }
    catch (IllegalArgumentException expected) {
      // expected
    }
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
ssh cedar 'bash -lc "cd /var/www/jbrestel.fungidb.org/project_home/ApiCommonWebsite/Model && \
  mvn -Dtest=StrainSegmentIdTest -DfailIfNoTests=true test"'
```

Expected: **compilation failure** — `cannot find symbol: class StrainSegmentId`.

If instead you get "No tests were executed", the `src/test/java` tree is not being picked up; confirm the file path matches the package exactly.

- [ ] **Step 3: Write the implementation**

Create `StrainSegmentId.java`:

```java
package org.apidb.apicommon.model.report.bed.util;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The single parse/format authority for the strain genomic segment primary key.
 *
 * Grammar: {@code <strain>:<refSeq>:<refStart>-<refEnd>:<f|r>}
 * Example: {@code A0003:AACB03000001:100-200:f}
 *
 * Coordinates are 1-based, inclusive, and expressed in REFERENCE coordinates.
 * Strain coordinates are derived by the attribute query, not stored here.
 *
 * Note the field patterns are {@code [^:]+} rather than DynSpan's greedy {@code (.*)}.
 * DynSpan's SQL and Java parsers disagree on IDs containing extra colons; this one
 * rejects them instead of guessing.
 */
public class StrainSegmentId {

  private static final Pattern PATTERN =
      Pattern.compile("^([^:]+):([^:]+):(\\d+)-(\\d+):(f|r)$");

  private final String _strain;
  private final String _refSeq;
  private final int _refStart;
  private final int _refEnd;
  private final StrandDirection _strand;

  private StrainSegmentId(String strain, String refSeq, int refStart, int refEnd,
      StrandDirection strand) {
    _strain = strain;
    _refSeq = refSeq;
    _refStart = refStart;
    _refEnd = refEnd;
    _strand = strand;
  }

  public static StrainSegmentId parse(String sourceId) {
    if (sourceId == null) {
      throw new IllegalArgumentException("Strain segment ID may not be null");
    }
    Matcher m = PATTERN.matcher(sourceId);
    if (!m.matches()) {
      throw new IllegalArgumentException(String.format(
          "Strain segment ID '%s' does not match required pattern %s",
          sourceId, PATTERN.pattern()));
    }
    int start = Integer.parseInt(m.group(3));
    int end = Integer.parseInt(m.group(4));
    if (start > end) {
      throw new IllegalArgumentException(String.format(
          "Strain segment ID '%s' has start %d greater than end %d", sourceId, start, end));
    }
    return new StrainSegmentId(m.group(1), m.group(2), start, end,
        StrandDirection.fromEfOrEr(m.group(5)));
  }

  public String format() {
    return String.format("%s:%s:%d-%d:%s", _strain, _refSeq, _refStart, _refEnd,
        StrandDirection.reverse.equals(_strand) ? "r" : "f");
  }

  /**
   * The key into the strain consensus FASTA, and therefore the BED chrom column.
   * Written by dnaseq-nextflow as {@code <sample>_<chrom>}.
   */
  public String getStrainSeqId() {
    return _strain + "_" + _refSeq;
  }

  public String getStrain() { return _strain; }
  public String getRefSeq() { return _refSeq; }
  public int getRefStart() { return _refStart; }
  public int getRefEnd() { return _refEnd; }
  public StrandDirection getStrand() { return _strand; }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
ssh cedar 'bash -lc "cd /var/www/jbrestel.fungidb.org/project_home/ApiCommonWebsite/Model && \
  mvn -Dtest=StrainSegmentIdTest -DfailIfNoTests=true test"'
```

Expected: `Tests run: 12, Failures: 0, Errors: 0, Skipped: 0`.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/fungidb/ApiCommonWebsite
git add Model/src/main/java/org/apidb/apicommon/model/report/bed/util/StrainSegmentId.java \
        Model/src/test/java/org/apidb/apicommon/model/report/bed/util/StrainSegmentIdTest.java
git commit -m "Add StrainSegmentId, the parse/format authority for strain segment PKs"
bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Task 2: Strain vocabulary param

The strain list must come from `apidb.indel` (the requirement). There is no strain column on `apidb.indel`; strain is `study.protocolappnode.name` minus a `_Indel` suffix. All 6,119 names carry that suffix and **none contains a colon**, which is what makes the primary key parseable — `':'` is its only delimiter.

> **CORRECTION — an earlier draft of this line claimed "none contains any other underscore".
> That is FALSE: 1,494 of the 6,119 names (24%) contain an underscore** — `1_01_01`,
> `Af293_resequence2`, `China_LZCH-36`, `USGS_28834_1_NV`. The `_Indel` strip is still
> unambiguous (it is anchored to the end), but the `<strain>_<refSeq>` concatenation is
> **not reversible** and must be treated as an opaque key. This bad fact propagated into
> Task 1's regex as `[^:_]+` for the strain group, which silently rejected ~24% of
> legitimate primary keys until it was caught in review. Consumers needing the strain parse
> it from the primary key, where `':'` delimits unambiguously.

> **REVISED after review — there is no organism param.** An earlier draft made this
> vocabulary depend on an organism param and scope itself with `org_abbrev`. That was
> redundant: the search is handed a sequence ID, which already determines its organism.
> The vocabulary is now **global** (6,119 strains, 2.9s, cached once rather than once per
> organism), and relevance is enforced by the ID query's `EXISTS` gate instead. See spec
> §5.1.1 for why, including the tree-vocabulary trap that made the organism-scoped version
> silently return nothing. The Step 1 content below is the revised version.

**Files:**
- Create: `ApiCommonModel/Model/lib/wdk/model/questions/params/strainSegmentParams.xml`

- [ ] **Step 1: Create the param file**

```xml
<wdkModel>

  <paramSet name="StrainSegmentParams">

    <flatVocabParam name="strain"
                    queryRef="StrainSegmentVQ.StrainsByOrganism"
                    prompt="Strain / isolate"
                    multiPick="false"
                    dependedParamRef="organismParams.organismSinglePick">
      <help>
        Strain or isolate whose coordinate system the returned segment is expressed in.
        The list is restricted to strains that have indel data loaded for the selected
        organism.
      </help>
    </flatVocabParam>

  </paramSet>

  <!--===========================================================================-->
  <!--  Vocab queries                                                            -->
  <!--===========================================================================-->

  <querySet name="StrainSegmentVQ" queryType="vocab" isCacheable="true">

    <!-- Strain identity is protocolappnode.name minus the '_Indel' suffix; there is
         no strain column on apidb.indel.  Scoped by org_abbrev, which is both the
         organism gate and the partition key of webready.GenomicSeqAttributes_p. -->
    <sqlQuery name="StrainsByOrganism" doNotTest="true">
      <paramRef ref="organismParams.organismSinglePick"
                quote="true"
                queryRef="organismVQ.withStrainsChromosome"/>
      <column name="internal"/>
      <column name="term"/>
      <column name="display"/>
      <sql>
        <![CDATA[
          SELECT strain AS internal, strain AS term, strain AS display
          FROM (
            SELECT DISTINCT regexp_replace(pan.name, '_Indel$', '') AS strain
            FROM apidb.indel i
               , study.protocolappnode pan
               , webready.GenomicSeqAttributes_p gsa
            WHERE pan.protocol_app_node_id = i.protocol_app_node_id
              AND gsa.na_sequence_id = i.na_sequence_id
              AND gsa.org_abbrev IN ($$organismSinglePick$$)
          ) t
          ORDER BY strain
        ]]>
      </sql>
    </sqlQuery>

  </querySet>

</wdkModel>
```

- [ ] **Step 2: Verify the vocabulary SQL directly**

The file is not imported yet, so `wdkQuery` cannot see it. Run the inner SQL by hand for the QA organism (*Aspergillus fumigatus* Af293, `org_abbrev` = `afumAf293`):

```bash
psql -h localhost -p 5439 -d genomicsdb_rebuild01 -c "
SELECT count(*) AS strains FROM (
  SELECT DISTINCT regexp_replace(pan.name, '_Indel\$', '') AS strain
  FROM apidb.indel i, study.protocolappnode pan, webready.GenomicSeqAttributes_p gsa
  WHERE pan.protocol_app_node_id = i.protocol_app_node_id
    AND gsa.na_sequence_id = i.na_sequence_id
    AND gsa.org_abbrev IN ('afumAf293')
) t;"
```

Expected: `1117`. If you get `0`, confirm the `org_abbrev` spelling with
`SELECT DISTINCT org_abbrev FROM webready.organismabbreviation_p WHERE organism LIKE 'Aspergillus fumigatus%';`

Note the cost: this touches roughly 5.1M indel rows for Af293. It is declared
`isCacheable="true"` so it runs once per organism. Record the wall-clock time. If it
exceeds ~30 seconds, note it for follow-up — the fix is a small tuning table keyed on
`(org_abbrev, strain)`, but do not build that speculatively.

- [ ] **Step 3: Commit**

```bash
cd ~/workspaces/fungidb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/strainSegmentParams.xml
git commit -m "Add organism-dependent strain vocabulary param for strain segments"
bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Task 3: ID query with all four validation gates

Input is a **single** reference location, not a set. Every gate is a filter, so invalid
input yields zero records rather than a broken download — the failure mode
`DynSpansBySegIds` gets wrong by doing no validation at all.

`sequence_strand` has internal values `f` and `r` (`spanParams.xml:347-363`), so it drops
straight into the PK with no `CASE`. `end_point_segment` documents `0 = end`, which the
`CASE` below honours.

**Do not add `queryRef="organismVQ.withStrainsChromosome"` to the organism `paramRef`**,
even though `DynSpansBySourceId` does. That query is declared for only 10 projects, so
referencing it forces an `includeProjects` guard onto everything that depends on it — and
this record is meant to work on all projects. Worse, its SQL selects from
`apidbtuning.GenomicSeqAttributes`, which **does not exist in this database** (verified
2026-07-31; the same absence that stops DynSpan's `Bfmv` query from running here). Let
`organismParams.organismSinglePick` use its own default vocab query, `organismVQ.withGenes`,
which carries no `includeProjects`.

Note `organismSinglePick` is declared `multiPick="true" maxSelectedCount="1"`
(`organismParams.xml:256-262`), so WDK substitutes a quoted comma-separated list even
though only one value can be chosen. `IN (...)` is therefore required and `=` would be a
bug.

**Param quoting — write params UNQUOTED in the SQL.** This codebase quotes enum and vocab
params by default; `spanQueries.xml:303` has to say `quote="false"` explicitly to turn it
off. So `$$sequence_strand$$` and `$$strain$$` arrive already wrapped in single quotes, and
adding your own would produce `''f''`. Set `quote="true"` on the `strain` paramRef to make
the intent explicit, then reference both bare.

The codebase is genuinely inconsistent here (`spanQueries.xml:400` uses bare
`$$liberal_conservative$$` while `:417` writes `'$$any_or_all_DynSeg$$'`), so this cannot be
settled by reading alone. **Task 5 Step 5 is where it gets confirmed**: `wdkQuery -showQuery`
renders the assembled SQL, and doubled quotes will be visible there. If they appear, remove
the `quote="true"` rather than adding literal quotes.

Also prefer `pan.name = CONCAT($$strain$$, '_Indel')` over `regexp_replace(pan.name, ...)
= $$strain$$` in the EXISTS gate. Same lesson as Task 2: comparing a plain string lets the
database use an index on `name`, whereas applying `regexp_replace` to every candidate row
forces a scan and computes a function per row to reach the same answer.

**One `<sql>` block, no project variants.** Do not add `includeProjects` or
`excludeProjects` to anything in this task. `project_id` is selected from
`webready.GenomicSeqAttributes_p`, not from `@PROJECT_ID@`, so it is correct on every
project including UniDB. DynSpan duplicates its queries for UniDB precisely because it
uses `@PROJECT_ID@`, which is meaningless on the portal — that is a problem this design
avoids rather than a pattern to copy.

**Files:**
- Create: `ApiCommonModel/Model/lib/wdk/model/questions/queries/strainSegmentQueries.xml`

- [ ] **Step 1: Create the ID query file**

```xml
<wdkModel>

  <querySet name="StrainSegmentId" queryType="id" isCacheable="true">

    <!-- Four gates, all as filters so bad input returns zero rows:
           1. org_abbrev  - partition key AND organism membership
           2. source_id   - the reference sequence exists in that organism
           3. range       - 1 <= start <= end <= sequence length
           4. EXISTS      - the strain has indel data on this very sequence
         Gate 4 is scoped by na_sequence_id, never by strain name alone: 126 strain
         names map to more than one organism. -->
    <sqlQuery name="StrainSegmentsByRefSegment" doNotTest="true">
      <paramRef ref="organismParams.organismSinglePick"
                displayType="select"
                quote="true"/>
      <paramRef ref="StrainSegmentParams.strain" quote="true"/>
      <paramRef ref="sharedParams.sequenceId"/>
      <paramRef ref="sharedParams.start_point" default="1"/>
      <paramRef ref="sharedParams.end_point_segment"/>
      <paramRef ref="SpanParams.sequence_strand"/>

      <column name="source_id"/>
      <column name="project_id"/>

      <sql>
        <![CDATA[
          SELECT CONCAT($$strain$$, ':', seg.ref_seq, ':',
                        seg.ref_start, '-', seg.ref_end, ':',
                        $$sequence_strand$$)              AS source_id
               , seg.project_id
          FROM (
            SELECT gsa.source_id                           AS ref_seq
                 , gsa.project_id
                 , $$start_point$$::integer               AS ref_start
                 , CASE WHEN $$end_point_segment$$::integer = 0
                          THEN gsa.length::integer
                        ELSE $$end_point_segment$$::integer
                   END                                     AS ref_end
                 , gsa.length::integer                     AS seq_length
                 , gsa.na_sequence_id
            FROM webready.GenomicSeqAttributes_p gsa
            WHERE gsa.org_abbrev IN ($$organismSinglePick$$)
              AND gsa.source_id = $$sequenceId$$
          ) seg
          WHERE seg.ref_start >= 1
            AND seg.ref_end   >= seg.ref_start
            AND seg.ref_end   <= seg.seq_length
            AND EXISTS (
                  SELECT 1
                  FROM apidb.indel i
                     , study.protocolappnode pan
                  WHERE i.protocol_app_node_id = pan.protocol_app_node_id
                    AND i.na_sequence_id = seg.na_sequence_id
                    AND pan.name = CONCAT($$strain$$, '_Indel')
                )
        ]]>
      </sql>
    </sqlQuery>

  </querySet>

</wdkModel>
```

- [ ] **Step 2: Verify each gate by hand**

Still not imported, so run the assembled SQL directly. Substitute a real strain and
contig for Af293 first:

```bash
psql -h localhost -p 5439 -d genomicsdb_rebuild01 -c "
SELECT gsa.source_id, gsa.na_sequence_id, gsa.length,
       regexp_replace(pan.name,'_Indel\$','') AS strain
FROM webready.GenomicSeqAttributes_p gsa
   , apidb.indel i, study.protocolappnode pan
WHERE gsa.org_abbrev = 'afumAf293'
  AND i.na_sequence_id = gsa.na_sequence_id
  AND pan.protocol_app_node_id = i.protocol_app_node_id
  AND i.location BETWEEN 100 AND 200
LIMIT 1;"
```

**Record all four values now — Tasks 4 and 7 substitute them.** Write them down:

| placeholder used later | value from this query |
|---|---|
| `<CONTIG>` | `source_id` |
| `<NA_SEQ_ID>` | `na_sequence_id` |
| `<STRAIN>` | `strain` |
| sequence length | `length` |

The `location BETWEEN 100 AND 200` clause is there on purpose: it picks a contig/strain
pair that actually has indels in the 100-200 window, so the Task 7 shift check has a
non-zero offset to prove and does not silently pass on a segment with no indels at all.

Then run the query body four more times, each with one gate deliberately broken, and
confirm **zero rows** every time:

| Break | Expect |
|---|---|
| `source_id` set to `'NO_SUCH_CONTIG'` | 0 rows |
| `strain` set to `'NO_SUCH_STRAIN'` | 0 rows |
| `ref_end` set beyond `seq_length` | 0 rows |
| `ref_start` set to `0` | 0 rows |

A gate that still returns a row is a bug — fix it before moving on. This is the whole
point of the task.

- [ ] **Step 3: Commit**

```bash
cd ~/workspaces/fungidb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/strainSegmentQueries.xml
git commit -m "Add validating ID query for strain genomic segments"
bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Task 4: Attribute query — reference to strain coordinates

`shift` is a signed per-event delta (never zero, range −101..+80), so the strain offset at
a reference position is a prefix sum partitioned by `(protocol_app_node_id, na_sequence_id)`.

Two things make this query's shape non-obvious:

1. **It cannot use `webready.*_p`.** Attribute queries receive only PK columns, so there
   is no `org_abbrev` to prune partitions with, and every index on those tables is
   `org_abbrev`-prefixed. There is also no unpartitioned `GenomicSeqAttributes` in this
   database — `apidbtuning` exists but does not contain it, which is why DynSpan's `Bfmv`
   query cannot run here at all. Instead use the unpartitioned GUS core path:
   `dots.externalnasequence` (view; `source_id_uniq` index on `source_id`; carries
   `na_sequence_id`, `taxon_id`, `length`) joined to `apidb.organism` and `sres.taxonname`.
2. **`GROUP BY` the resolved node, not just the segment.** If a strain name ever resolves
   to two nodes on one sequence, this produces two rows per PK and WDK errors. Joining on
   name alone would instead sum two strains' shifts into one plausible-looking wrong
   answer with nothing to detect it.

**Boundary rule:** an indel exactly at `ref_start` lies inside the segment, so it shifts
the end but not the start — `<` for start, `<=` for end. This is the deferred QA item;
implement as written and verify in Task 7.

**Files:**
- Create: `ApiCommonModel/Model/lib/wdk/model/records/strainSegmentAttributeQueries.xml`

- [ ] **Step 1: Create the attribute query file**

```xml
<wdkModel>

  <querySet name="StrainSegmentAttributes" queryType="attribute" isCacheable="false">

    <sqlQuery name="Coords" doNotTest="true">
      <column name="source_id" ignoreCase="true" columnType="string"/>
      <column name="project_id" ignoreCase="true" columnType="string"/>
      <column name="strain" columnType="string"/>
      <column name="ref_seq" columnType="string"/>
      <column name="ref_start" columnType="number"/>
      <column name="ref_end" columnType="number"/>
      <column name="strain_seq_id" columnType="string"/>
      <column name="strain_start" columnType="number"/>
      <column name="strain_end" columnType="number"/>
      <column name="strain_length" columnType="number"/>
      <column name="organism" columnType="string"/>

      <!-- split_part, not positional regexp_substr: it does not silently renumber
           fields when one is empty.  Strain names contain '-', which is safe only
           because the range is its own colon-delimited field. -->
      <sql>
        <![CDATA[
          SELECT ids.source_id
               , ids.project_id
               , ids.strain
               , ids.ref_seq
               , ids.ref_start
               , ids.ref_end
               , ids.strain || '_' || ids.ref_seq                    AS strain_seq_id
               , ids.ref_start + COALESCE(off.offset_start, 0)        AS strain_start
               , ids.ref_end   + COALESCE(off.offset_end,   0)       AS strain_end
               , (ids.ref_end   + COALESCE(off.offset_end,   0))
                 - (ids.ref_start + COALESCE(off.offset_start, 0)) + 1 AS strain_length
               , tn.name                                             AS organism
          FROM (
            SELECT t.source_id
                 , t.project_id
                 , split_part(t.source_id, ':', 1)                            AS strain
                 , split_part(t.source_id, ':', 2)                            AS ref_seq
                 , split_part(split_part(t.source_id, ':', 3), '-', 1)::integer AS ref_start
                 , split_part(split_part(t.source_id, ':', 3), '-', 2)::integer AS ref_end
            FROM (##WDK_ID_SQL##) t
          ) ids
          JOIN dots.ExternalNaSequence ens ON ens.source_id = ids.ref_seq
          JOIN sres.TaxonName tn           ON tn.taxon_id = ens.taxon_id
                                          AND tn.name_class = 'scientific name'
          LEFT JOIN (
            SELECT i.na_sequence_id
                 , regexp_replace(pan.name, '_Indel$', '')                 AS strain
                 , seg.ref_start
                 , seg.ref_end
                 , SUM(CASE WHEN i.location <  seg.ref_start THEN i.shift ELSE 0 END) AS offset_start
                 , SUM(CASE WHEN i.location <= seg.ref_end   THEN i.shift ELSE 0 END) AS offset_end
            FROM apidb.indel i
               , study.protocolappnode pan
               , (
                   SELECT DISTINCT
                          split_part(t.source_id, ':', 1)                            AS strain
                        , split_part(t.source_id, ':', 2)                            AS ref_seq
                        , split_part(split_part(t.source_id, ':', 3), '-', 1)::integer AS ref_start
                        , split_part(split_part(t.source_id, ':', 3), '-', 2)::integer AS ref_end
                   FROM (##WDK_ID_SQL##) t
                 ) seg
               , dots.ExternalNaSequence ens2
            WHERE pan.protocol_app_node_id = i.protocol_app_node_id
              AND ens2.source_id = seg.ref_seq
              AND i.na_sequence_id = ens2.na_sequence_id
              AND regexp_replace(pan.name, '_Indel$', '') = seg.strain
              AND i.location <= seg.ref_end
            GROUP BY i.na_sequence_id
                   , regexp_replace(pan.name, '_Indel$', '')
                   , seg.ref_start
                   , seg.ref_end
                   , i.protocol_app_node_id
          ) off ON off.strain    = ids.strain
               AND off.ref_start = ids.ref_start
               AND off.ref_end   = ids.ref_end
        ]]>
      </sql>
    </sqlQuery>

  </querySet>

</wdkModel>
```

Note `i.protocol_app_node_id` in the `GROUP BY` but not the `SELECT`: that is deliberate.
It is what turns a future name-to-two-nodes collision into duplicate rows and a WDK error
instead of a silently summed wrong offset.

- [ ] **Step 2: Verify the prefix sum against a hand calculation**

Pick a strain and contig with indels, then compare. Substitute the values you found in
Task 3 Step 2:

```bash
psql -h localhost -p 5439 -d genomicsdb_rebuild01 -c "
WITH seg AS (SELECT '<STRAIN>'::text AS strain, <NA_SEQ_ID>::numeric AS na_seq, 100 AS s, 200 AS e)
SELECT SUM(CASE WHEN i.location <  seg.s THEN i.shift ELSE 0 END) AS offset_start
     , SUM(CASE WHEN i.location <= seg.e THEN i.shift ELSE 0 END) AS offset_end
FROM apidb.indel i, study.protocolappnode pan, seg
WHERE pan.protocol_app_node_id = i.protocol_app_node_id
  AND i.na_sequence_id = seg.na_seq
  AND regexp_replace(pan.name,'_Indel\$','') = seg.strain
  AND i.location <= seg.e;"
```

Then verify independently that the offsets are just running sums:

```bash
psql -h localhost -p 5439 -d genomicsdb_rebuild01 -c "
SELECT i.location, i.shift
FROM apidb.indel i, study.protocolappnode pan
WHERE pan.protocol_app_node_id = i.protocol_app_node_id
  AND i.na_sequence_id = <NA_SEQ_ID>
  AND regexp_replace(pan.name,'_Indel\$','') = '<STRAIN>'
  AND i.location <= 200
ORDER BY i.location;"
```

Add the `shift` values by hand: those with `location < 100` must equal `offset_start`,
those with `location <= 200` must equal `offset_end`. They must match exactly.

- [ ] **Step 3: Commit**

```bash
cd ~/workspaces/fungidb/ApiCommonModel
git add Model/lib/wdk/model/records/strainSegmentAttributeQueries.xml
git commit -m "Add strain coordinate conversion attribute query"
bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Task 5: Record class, question, and imports — first build

This is the first task that can break the build, because it is the task that makes the
model load the new files.

The record class is deliberately bare: no tables and no reporters beyond `bed` (added in
Task 6). `useBasket="false"` is required — the default is `true`
(`RecordClass.java:303`) and would inject basket questions and client affordances (spec
§6). `doNotTest="true"` keeps it out of the WDK sanity tests, matching DynSpan.

"No record page" is an **intent, not a guarantee**: WDK injects a `_default` summary view,
a `_default` "Overview" record view, and `DefaultJsonReporter` unconditionally (spec §6),
and the nine `columnAttribute`s *are* display attributes — they must stay that way because
the BED reporter reads them. A record-page request is not a supported operation and is not
verified to do anything graceful.

**No `individuals.txt` entry.** Omitting the row is what keeps the search out of the
category tree while leaving it addressable by name through the service API — the same
mechanism `DynSpansBySegIds` relies on (spec §6.1). Note `DynSpansByLocation` is **not** a
second precedent: it is only an `<sqlQuery>` (`spanQueries.xml:266`) with no `<question>`
and no references anywhere, i.e. a dead id query (spec §5.1).

**Files:**
- Create: `ApiCommonModel/Model/lib/wdk/model/records/strainSegmentRecord.xml`
- Create: `ApiCommonModel/Model/lib/wdk/model/questions/strainSegmentQuestions.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/apiCommonModel.xml` (near lines 419-423)

- [ ] **Step 1: Create the record class**

```xml
<wdkModel>

  <recordClassSet name="StrainSegmentRecordClasses">

    <!-- Internal record class.  Sole purpose: convert a reference-coordinate genomic
         segment plus a strain into a BED feature in that strain's coordinates.
         INTENT, not a guarantee: no tables, no reporters beyond 'bed' (Task 6), no
         ontology rows, so nothing wires up a record page or a saved strategy.  WDK still
         injects a '_default' summary view, a '_default' "Overview" record view, and the
         DefaultJsonReporter unconditionally, so do not claim those are absent.  The
         columnAttributes below ARE display attributes and must stay so; the BED reporter
         reads them.  useBasket="false" is required: the default is true
         (RecordClass.java:303).
         Works on every project: no includeProjects/excludeProjects anywhere, including
         on the PK columns.  project_id comes from the data, not @PROJECT_ID@. -->
    <recordClass name="StrainSegmentRecordClass"
                 urlName="strain-genomic-segment"
                 displayName="Strain Genomic Segment"
                 shortDisplayName="Strain Segment"
                 useBasket="false"
                 doNotTest="true">

      <primaryKey aliasPluginClassName="org.gusdb.wdk.model.record.GenericRecordPrimaryKeyAliasPlugin">
        <columnRef>source_id</columnRef>
        <columnRef>project_id</columnRef>
      </primaryKey>

      <idAttribute name="primary_key" displayName="Strain Segment ID">
        <text><![CDATA[ $$source_id$$ ]]></text>
      </idAttribute>

      <!-- NO <reporter> element in Task 5: ReporterRef.resolveReferences does a
           Class.forName at model-load time and fails the build while
           BedStrainSegmentReporter does not exist.  Task 6, Step 4 adds it, with
           scopes="results" (NOT "results,record"); see spec section 7. -->

      <attributeQueryRef ref="StrainSegmentAttributes.Coords">
        <columnAttribute name="strain"        displayName="Strain"/>
        <columnAttribute name="ref_seq"       displayName="Reference Sequence ID"/>
        <columnAttribute name="ref_start"     displayName="Reference Start"/>
        <columnAttribute name="ref_end"       displayName="Reference End"/>
        <columnAttribute name="strain_seq_id" displayName="Strain Sequence ID"/>
        <columnAttribute name="strain_start"  displayName="Strain Start"/>
        <columnAttribute name="strain_end"    displayName="Strain End"/>
        <columnAttribute name="strain_length" displayName="Strain Segment Length"/>
        <columnAttribute name="organism"      displayName="Organism"/>
      </attributeQueryRef>

    </recordClass>

  </recordClassSet>

</wdkModel>
```

- [ ] **Step 2: Create the question**

```xml
<wdkModel>

  <questionSet name="StrainSegmentQuestions" displayName="Strain Genomic Segments">

    <!-- Intentionally absent from Model/lib/wdk/ontology/individuals.txt so it does not
         appear in the category tree.  Still reachable by name via the service API, the
         same mechanism DynSpansBySegIds relies on (spanQuestions.xml:15).
         DynSpansByLocation is NOT a second precedent: it is a bare sqlQuery with no
         question and no references (spec section 5.1). -->
    <question name="StrainSegmentsByRefSegment"
              displayName="Strain Genomic Segment by Reference Location"
              shortDisplayName="Strain Segment"
              queryRef="StrainSegmentId.StrainSegmentsByRefSegment"
              recordClassRef="StrainSegmentRecordClasses.StrainSegmentRecordClass">

      <!-- summary mirrors what the BED download consumes, so the list means something to
           a consumer.  NO sorting attribute: prepareSortingSqls (AnswerValue.java:748..800)
           splices a QueryColumnAttributeField's attribute query into the ordering/paging
           SQL, so sorting on strain_seq_id would re-run the apidb.indel prefix-sum
           aggregation just to order rows.  Undeclared, WDK falls back to the idAttribute
           against the id query alone (RecordClass.java:1441..1443), which is free, and
           strain_seq_id is a pure function of the PK so nothing is lost. -->
      <attributesList summary="organism,strain,ref_seq,ref_start,ref_end,strain_seq_id,strain_start,strain_end,strain_length"/>

      <summary>
        Given a genomic location in reference coordinates and a strain, return the
        equivalent segment in that strain's consensus sequence coordinates.
      </summary>

      <description>
        <![CDATA[
        Internal, webservice-only search. ... (see the checked-in file for full text)
        ]]>
      </description>

    </question>

  </questionSet>

</wdkModel>
```

- [ ] **Step 3: Register all five files**

In `Model/lib/wdk/apiCommonModel.xml`, immediately after the existing span imports
(currently lines 419-423), add:

```xml
  <import file="model/records/strainSegmentAttributeQueries.xml"/>
  <import file="model/records/strainSegmentRecord.xml"/>
  <import file="model/questions/params/strainSegmentParams.xml"/>
  <import file="model/questions/queries/strainSegmentQueries.xml"/>
  <import file="model/questions/strainSegmentQuestions.xml"/>
```

Order matters only in that WDK resolves references after parsing all files, so any order
within this block is fine — but keep it grouped and adjacent to the span imports so the
next person finds it.

- [ ] **Step 4: Build the model**

```bash
bash ~/workspaces/agentic-veupath-dev/bin/veup-build.sh fungidb wb model
```

Expected: build completes and the webapp reloads.

If it fails, read the error for the specific unresolved reference — a mistyped
`queryRef`, `paramRef`, or column name is the usual cause. A column declared in
`<columnAttribute>` but absent from the attribute query's `<column>` list will fail here.

- [ ] **Step 5: Confirm the SQL assembles as WDK will run it**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.fungidb.org/etc/setenv && \
  wdkQuery -model FungiDB -query StrainSegmentAttributes.Coords -showQuery"'
ssh cedar 'bash -lc "source /var/www/jbrestel.fungidb.org/etc/setenv && \
  wdkQuery -model FungiDB -query StrainSegmentId.StrainSegmentsByRefSegment -showParams"'
```

Expected: the ID query lists **five** params — `strain`, `sequenceId`, `start_point`,
`end_point_segment`, `sequence_strand`. There is **no** organism param (spec §5.1.1); if
you see one, something is wrong.

The attribute query prints wrapped as `SELECT o.* FROM (…) o` with `##WDK_ID_SQL##`
**still literal, NOT expanded** — and that is correct, not a failure. Run standalone
through `QueryTester` there is no answer or step to supply the ID SQL, so nothing
substitutes the macro (the log also reports `params: [ ]`). Substitution happens in the
answer-value layer at request time. What this step proves is that the query is
registered, parses, and resolves — *executing* it against real IDs is Task 7's job.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/fungidb/ApiCommonModel
git add Model/lib/wdk/model/records/strainSegmentRecord.xml \
        Model/lib/wdk/model/questions/strainSegmentQuestions.xml \
        Model/lib/wdk/apiCommonModel.xml
git commit -m "Add strain segment record class and question, and import the model files"
bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Task 6: BED feature provider and reporter

`BedReporter` streams the attributes a provider declares and calls
`getRecordAsBedFields` per record. `GenomicSequenceFeatureProvider` is the precedent for
a provider that computes coordinates from attributes rather than from the PK.

Two BED columns, two very different constraints:

- **`chrom` is hard.** `BedLine.bed6`'s first argument *is* the chrom column, and it must
  equal `<strain>_<refSeq>` or the FASTA index lookup fails. `bed6` also converts start
  to 0-based for you — pass 1-based coordinates.
- **`name` is free.** Under `deflineFormat=QUERYONLY`, seqret emits `'>' + name`
  verbatim, so this becomes the eventual FASTA defline. `RequestedDeflineFields` is
  populated only when the caller passes `deflineType=full`, so the default stays bare.

**Files:**
- Create: `ApiCommonWebsite/Model/src/main/java/org/apidb/apicommon/model/report/bed/feature/StrainSegmentFeatureProvider.java`
- Create: `ApiCommonWebsite/Model/src/main/java/org/apidb/apicommon/model/report/bed/BedStrainSegmentReporter.java`
- Modify: `ApiCommonModel/Model/lib/wdk/model/records/strainSegmentRecord.xml` — register the
  reporter (Task 5 deliberately left this out; see Step 4 below). **Two repos, one task.**

> **The registration in Step 4 is not optional bookkeeping — without it the BED download
> simply is not offered, with no error anywhere.** Task 7's download call would fail with an
> unknown-format error and the cause would not be obvious. Do not consider this task done
> with only the Java side written.

**This task must also reject the inverted-interval case.** `StrainSegmentAttributes.Coords`
deliberately leaves `strain_start`/`strain_end` unclamped so that a segment lying inside a
deletion reports `strain_end < strain_start` (only `strain_length` is clamped to 0 — spec
§5.3.2). Nothing upstream rejects it, so the provider **must**: an inverted interval that
reaches a FASTA lookup is a silent wrong answer. Verified live example to test against:
PK `366.1:Pf3D7_10_v3:331757-331757:f` yields `strain_start 331658`, `strain_end 331604`,
`strain_length 0`.

- [ ] **Step 1: Create the feature provider**

```java
package org.apidb.apicommon.model.report.bed.feature;

import java.util.List;

import org.apidb.apicommon.model.report.bed.util.BedLine;
import org.apidb.apicommon.model.report.bed.util.DeflineBuilder;
import org.apidb.apicommon.model.report.bed.util.RequestedDeflineFields;
import org.apidb.apicommon.model.report.bed.util.StrainSegmentId;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.record.RecordInstance;
import org.json.JSONObject;

/**
 * Emits one BED line per strain genomic segment.
 *
 * The chrom column must be the strain consensus FASTA key (<strain>_<refSeq>); the name
 * column becomes the FASTA defline downstream and carries both coordinate systems.
 */
public class StrainSegmentFeatureProvider implements BedFeatureProvider {

  private static final String ATTR_STRAIN_SEQ_ID = "strain_seq_id";
  private static final String ATTR_STRAIN_START = "strain_start";
  private static final String ATTR_STRAIN_END = "strain_end";
  private static final String ATTR_ORGANISM = "organism";

  private final RequestedDeflineFields _requestedDeflineFields;

  public StrainSegmentFeatureProvider(JSONObject config) {
    _requestedDeflineFields = new RequestedDeflineFields(config);
  }

  @Override
  public String getRequiredRecordClassFullName() {
    return "StrainSegmentRecordClasses.StrainSegmentRecordClass";
  }

  @Override
  public String[] getRequiredAttributeNames() {
    return new String[] {
        ATTR_STRAIN_SEQ_ID,
        ATTR_STRAIN_START,
        ATTR_STRAIN_END,
        ATTR_ORGANISM
    };
  }

  @Override
  public String[] getRequiredTableNames() {
    return new String[0];
  }

  @Override
  public List<List<String>> getRecordAsBedFields(RecordInstance record) throws WdkModelException {
    String featureId = getSourceId(record);

    StrainSegmentId id;
    try {
      id = StrainSegmentId.parse(featureId);
    }
    catch (IllegalArgumentException e) {
      throw new WdkModelException(e.getMessage(), e);
    }

    // chrom must be the FASTA key; take it from the attribute rather than recomputing,
    // so the model stays the single source of truth for what was looked up.
    String strainSeqId = stringValue(record, ATTR_STRAIN_SEQ_ID);
    Integer strainStart = integerValueWithZeroForEmpty(record, ATTR_STRAIN_START);
    Integer strainEnd = integerValueWithZeroForEmpty(record, ATTR_STRAIN_END);

    if (strainStart < 1 || strainEnd < strainStart) {
      throw new WdkModelException(String.format(
          "Strain segment %s produced invalid strain coordinates %d-%d",
          featureId, strainStart, strainEnd));
    }

    DeflineBuilder defline = new DeflineBuilder(featureId);

    if (_requestedDeflineFields.contains("organism")) {
      defline.appendRecordAttribute(record, ATTR_ORGANISM);
    }
    if (_requestedDeflineFields.contains("strain")) {
      defline.appendValue(id.getStrain());
    }
    if (_requestedDeflineFields.contains("description")) {
      defline.appendValue("segment of strain genomic sequence");
    }
    if (_requestedDeflineFields.contains("reference_position")) {
      defline.appendPosition(id.getRefSeq(), id.getRefStart(), id.getRefEnd(), id.getStrand());
    }
    if (_requestedDeflineFields.contains("position")) {
      defline.appendPosition(strainSeqId, strainStart, strainEnd, id.getStrand());
    }
    if (_requestedDeflineFields.contains("segment_length")) {
      defline.appendSegmentLength(strainStart, strainEnd);
    }

    return List.of(BedLine.bed6(strainSeqId, strainStart, strainEnd, defline, id.getStrand()));
  }
}
```

- [ ] **Step 2: Create the reporter**

```java
package org.apidb.apicommon.model.report.bed;

import org.apidb.apicommon.model.report.bed.feature.StrainSegmentFeatureProvider;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wdk.model.report.Reporter;
import org.gusdb.wdk.model.report.ReporterConfigException;
import org.json.JSONObject;

public class BedStrainSegmentReporter extends BedReporter {

  @Override
  public Reporter configure(JSONObject config) throws ReporterConfigException, WdkModelException {
    return configure(() -> new StrainSegmentFeatureProvider(config), getContentDisposition(config));
  }

}
```

- [ ] **Step 3: Verify it compiles and the grammar tests still pass**

```bash
ssh cedar 'bash -lc "cd /var/www/jbrestel.fungidb.org/project_home/ApiCommonWebsite/Model && \
  mvn -Dtest=StrainSegmentIdTest,StrainSegmentFeatureProviderTest -DfailIfNoTests=true test"'
```

Expected, as actually observed from this exact invocation: `StrainSegmentIdTest` **20**,
`StrainSegmentFeatureProviderTest` **10**, `Tests run: 30, Failures: 0`, no compilation
errors. (An earlier revision of this step said 12 — that predated both the underscore
regression tests and this task's provider tests.)

Read the `Tests run:` counts; do not trust the exit status alone. See the surefire warning
in "Useful commands" above — `-Dtest=A+B` matches nothing on this module and, combined with
`-DfailIfNoTests=false`, reports `BUILD SUCCESS` having run no tests at all.

`BedReporter.configure` validates at runtime that the record class matches
`getRequiredRecordClassFullName()` and that every declared attribute exists on it, so a
typo in an attribute name surfaces on first use, not at compile time. That is what Task 7
Step 2 checks.

- [ ] **Step 4: Register the reporter on the record class**

Task 5 could not do this: WDK's `ReporterRef.resolveReferences`
(`WDK/Model/src/main/java/org/gusdb/wdk/model/report/ReporterRef.java:213-224`) calls
`Class.forName(getImplementation())` at model-load time and throws
`WdkModelException("… cannot be found.")` on `ClassNotFoundException`. Registering a
reporter whose class did not yet exist would have hard-failed the build. Now that
`BedStrainSegmentReporter` exists, add it.

In `ApiCommonModel/Model/lib/wdk/model/records/strainSegmentRecord.xml`, replace the
Task-6 placeholder comment inside `<recordClass>` with:

```xml
      <reporter name="bed"
                displayName="BED - coordinates in strain sequence, configurable"
                scopes="results"
                implementation="org.apidb.apicommon.model.report.bed.BedStrainSegmentReporter"/>
```

`name="bed"` is the string Task 7 passes as `reportName`, so it must match exactly.

- [ ] **Step 5: Rebuild so the model picks up the registration**

```bash
bash ~/workspaces/agentic-veupath-dev/bin/veup-build.sh fungidb wb model
```

Expected: build succeeds. If it fails with "Implementation class for reporter 'bed' …
cannot be found", the Java class did not compile into the deployed webapp — fix that
before continuing, since Task 7 cannot pass without it.

- [ ] **Step 6: Commit — both repos**

```bash
cd ~/workspaces/fungidb/ApiCommonWebsite
git add Model/src/main/java/org/apidb/apicommon/model/report/bed/feature/StrainSegmentFeatureProvider.java \
        Model/src/main/java/org/apidb/apicommon/model/report/bed/BedStrainSegmentReporter.java
git commit -m "Add BED reporter and feature provider for strain genomic segments"

cd ~/workspaces/fungidb/ApiCommonModel
git add Model/lib/wdk/model/records/strainSegmentRecord.xml
git commit -m "Register the BED reporter on the strain segment record class"

bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Task 7: End-to-end verification

> ## RESOLVED 2026-07-31 — instance repointed at an appDb that has indels
>
> John updated `etc/conifer_site_vars.yml` to swap the appDb from LDAP `genomicsdb_devn`
> (`genomicsdb_070n`, **no `apidb.indel` at all**) to `appDb_ldapCommonName: UniDB_shu_a` /
> `jdbc:postgresql://ares12.penn.apidb.org:5432/unidb_shu_a`.
>
> **The first gated rebuild still failed, and that turned out to be a checkout problem, not a
> gate problem.** `rebuilder --gusjvmopts -Dpresenter.dataset.gate=on` died at WDK cache
> creation:
>
> ```
> PSQLException: relation "eda.attributegraph_sd9c28df5a4_gnphntyd" does not exist
>   for query TranscriptAttributes.MetaPhenotypeVariablesNumericFungiDB_VEuPathDB_curated_phenotype_Phenotype_RSRC
> <rebuilder> FATAL: I was unable to recreate the WDK cache.
> ```
>
> That query name embeds a dataset (`VEuPathDB_curated_phenotype_Phenotype_RSRC`) that has **no
> row in `apidb.datasource`** here, i.e. exactly what the gate is supposed to skip. It was not
> skipped, and `$GUS_HOME/lib/wdk/presentersNotLoaded.txt` did not exist — the gate never ran.
> Cause: **the gate implementation is not on `master`.** It lives on the
> `dnaseq-merge-experiments` branch that plasmodb uses, so this checkout had the flag but not
> the code that honours it. Fixed by putting `EbrcModelCommon`, `ApiCommonDatasets`, and
> `ApiCommonPresenters` on that branch in this workspace.
>
> The gate is required here because this appDb holds a subset of the loaded data while
> `datasetPresenters` is a superset by design.
>
> **The new appDb is reachable locally on port 5432** (`psql -h localhost -p 5432 -d unidb_shu_a`).
> It is a **third** database, so the §2 figures — measured on `genomicsdb_rebuild01` — do not
> describe it. Measured on `unidb_shu_a`:
>
> | | `rebuild01` (spec §2) | `unidb_shu_a` (what the site now queries) |
> |---|---|---|
> | `apidb.indel` rows | 43,585,584 | 1,855,449 |
> | strains (`_Indel` nodes) | 6,119 | **452** |
> | sequences with indels | 20,823 | 120 |
> | `apidb.organism` | 967 | 13 |
>
> Indel-bearing projects here: TriTrypDB (95 sequences), PlasmoDB (16), **FungiDB (9 sequences,
> 232 strains)** — so this FungiDB site does have usable data. Expect the strain vocabulary to
> offer **452** options, not 6,119, and note the §5.2 vocabulary timing (57 ms) was measured
> against the larger database.
>
> ### Verified test cases for Steps 3-6 — use these
>
> Both on strain `A17-48H-7`, sequence `Chr1_A_fumigatus_Af293` (length 4,918,979), offsets
> computed read-only against `unidb_shu_a`:
>
> | Case | `start_point` | `end_point_segment` | offset_start | offset_end | expected `strain_start` | expected `strain_end` |
> |---|---|---|---|---|---|---|
> | A | 20000 | 25000 | +71 | +75 | 20071 | 25075 |
> | B | 1 | 1000 | **0** | +3 | 1 | 1003 |
>
> Case B is the plan's required "`offset_start` is 0 but `offset_end` is not" check — it proves
> the two offsets are computed independently rather than one being copied to the other.
> Case A's offsets differ from each other (71 vs 75), which is a second, weaker form of the
> same check.
>
> For case A the BED line must be:
> `A17-48H-7_Chr1_A_fumigatus_Af293` / `20070` (0-based, so `strain_start - 1`) / `25075` /
> `A17-48H-7:Chr1_A_fumigatus_Af293:20000-25000:f` / `.` / `+`
>
> ---
>
> **Original blocker, kept for the record.** **Discovered 2026-07-31, while starting this task.** Steps 3-6 cannot run on
> `jbrestel.fungidb.org` as it is currently configured, and this invalidates one premise of
> the whole plan.
>
> Every SQL fact in this spec and plan was measured against **`genomicsdb_rebuild01`**
> (`localhost:5439`). But the site's `appDb` resolves through LDAP:
>
> ```
> gus_home/config/FungiDB/model-config.xml → <appDb ldapCommonName="genomicsdb_devn">
> ldapsearch cn=genomicsdb_devn → dbname=genomicsdb_070n, host=ares13.penn.apidb.org:5432
> ```
>
> i.e. the running site queries **`genomicsdb_070n`** (reachable locally on port **5433**),
> a different database. Measured there:
>
> | | `genomicsdb_rebuild01` (verified against) | `genomicsdb_070n` (what the site queries) |
> |---|---|---|
> | `apidb.indel` | 43,585,584 rows | **relation does not exist** |
> | `study.protocolappnode` `%_Indel` | 6,119 | **0** |
> | `dots.externalnasequence` | 10,331,542 | 10,168,874 |
> | `apidb.organism` | 967 | 957 |
>
> So the ID query's `EXISTS` over `apidb.indel` will not return zero rows — it will raise
> `relation "apidb.indel" does not exist`. The search errors rather than coming back empty.
>
> **What this does and does not invalidate.** The SQL correctness work stands: the queries were
> verified against a database that really does hold this data, and `rebuild01` is where the
> indel load exists. What is *not* established is that any deployed site can run them.
> Note also that the earlier decision to move development from giardiadb to fungidb ("giardiadb
> has zero indel rows") was itself made by querying `rebuild01`, so it chose the right *data*
> but told us nothing about either instance's actual appDb.
>
> **Steps 1-2 are unaffected** — they read model metadata, not the appDb.
>
> **Resolving it is a decision for John, not a workaround to pick unilaterally.** The options:
> point this instance's `appDb` at `genomicsdb_rebuild01` (a `model-config.xml` change, which
> conifer generates from a template, so it is not a one-line edit); stand up or find an
> instance whose appDb already has the indel load; or wait for `apidb.indel` to reach the
> current workflow database. Until then Task 7 Steps 3-6, and the deferred `refStart`-boundary
> QA question, cannot be answered on this instance.

- [ ] **Step 1: Rebuild and confirm registration**

```bash
bash ~/workspaces/agentic-veupath-dev/bin/veup-build.sh fungidb wb model
```

Then, from an already-loaded page on `https://jbrestel.fungidb.org` (a raw curl
307-redirects to autologin), run in the browser console:

```javascript
await (await fetch('/a/service/record-types/strain-genomic-segment')).json()
```

Expected: the record type resolves, `searches` contains `StrainSegmentsByRefSegment`, and
`attributes` lists the nine columns from Task 5.

- [ ] **Step 2: Confirm it is NOT in the category tree**

```javascript
const t = await (await fetch('/a/service/ontologies/Categories')).json();
JSON.stringify(t).includes('StrainSegmentsByRefSegment')
```

Expected: **`false`**. If `true`, something added an ontology node — remove it.

- [ ] **Step 3: Run the search and download BED**

```javascript
const r = await fetch('/a/service/answer', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    searchName: 'StrainSegmentsByRefSegment',
    searchConfig: {parameters: {
      // NO organism param -- the search does not declare one (spec §5.1.1) and WDK
      // rejects unknown parameters.  Five params exactly.
      strain: '<STRAIN>',                // from Task 3 Step 2
      sequenceId: '<CONTIG>',            // from Task 3 Step 2
      start_point: '100',
      end_point_segment: '200',
      sequence_strand: 'f'
    }},
    reportName: 'bed',
    reportConfig: {attachmentType: 'plain'}
  })
});
console.log(await r.text());
```

Expected: one tab-delimited BED line where

- column 1 (`chrom`) is `<STRAIN>_<CONTIG>` — **must** match the FASTA defline exactly;
- column 2 is `strain_start - 1` (bed6 converts to 0-based);
- column 3 is `strain_end`;
- column 4 is the source_id (bare, since `deflineType` defaults to short);
- column 6 is `+`.

If you get `### The result is empty ###`, one of the four gates rejected the input —
re-run the Task 3 Step 2 query to find which.

- [ ] **Step 4: Prove the coordinates actually shifted**

Compare the BED output against the reference coordinates you requested:

```bash
psql -h localhost -p 5439 -d genomicsdb_rebuild01 -c "
SELECT SUM(CASE WHEN i.location <  100 THEN i.shift ELSE 0 END) AS offset_start
     , SUM(CASE WHEN i.location <= 200 THEN i.shift ELSE 0 END) AS offset_end
FROM apidb.indel i, study.protocolappnode pan
WHERE pan.protocol_app_node_id = i.protocol_app_node_id
  AND i.na_sequence_id = <NA_SEQ_ID>
  AND regexp_replace(pan.name,'_Indel\$','') = '<STRAIN>'
  AND i.location <= 200;"
```

BED column 3 must equal `200 + offset_end`, and column 2 must equal
`100 + offset_start - 1`. If `offset_start` and `offset_end` are both non-zero and the
BED coordinates equal the unshifted reference values, the `LEFT JOIN` in Task 4 is not
matching — that is the bug to chase.

Pick a second case where `offset_start` is `0` but `offset_end` is not (a segment whose
only indels fall inside it) to confirm the two offsets are computed independently.

- [ ] **Step 5: Check the request logged clean**

```bash
bash ~/workspaces/agentic-veupath-dev/bin/veup-logs.sh fungidb mark bed1
# re-run the Step 3 fetch
bash ~/workspaces/agentic-veupath-dev/bin/veup-logs.sh fungidb since bed1 --quiet
```

Expected: error logs report `silent:`. Anything in `wdk` or the error logs is a real
problem even if the BED output looked right.

- [ ] **Step 6: Verify the defline fields work**

Re-run Step 3 with `reportConfig` set to:

```javascript
{attachmentType: 'plain', deflineType: 'full',
 deflineFields: ['organism','strain','reference_position','position','segment_length']}
```

Expected: BED column 4 becomes a pipe-delimited defline carrying organism, strain, both
coordinate systems, and the length — confirming both `ref_*` and `strain_*` values are
present and different.

- [ ] **Step 7: Commit any fixes**

```bash
cd ~/workspaces/fungidb/ApiCommonModel   # or ApiCommonWebsite
git add -u && git commit -m "Fix <specific issue> found in end-to-end verification"
bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Task 8: Include UniDB on the existing eQTL genomic-segment search

Independent of everything above, and safe to do first or last. The spec requires UniDB be
included for **existing** genomic segments as well as the new record.

Background you need: the portal site deploys as tomcat project `EuPathDB` but its **WDK
model name is `UniDB`**, and `includeProjects` matches the *model* name. So
`includeProjects="EuPathDB"` never fires on that site. Repo-wide there are 42 files still
carrying legacy `EuPathDB` in `includeProjects` versus 760 `UniDB` occurrences — **do not
try to fix them all**, that is a separate cleanup. Only the genomic-segment files are in
scope, and in those there is exactly one live defect.

Audit of `EuPathDB` in the span model files, so you can see why only one line changes:

| Location | Verdict |
|---|---|
| `spanQuestions.xml:346` | inside a commented-out `IsolatesBySpanLogic` block — dead, leave it |
| `spanQuestions.xml:478` | `includeProjects="PlasmoDB,EuPathDB,UniDB"` — already has UniDB, harmless |
| `spanQuestions.xml:489` | **live defect** — `attributesList` scoped to `EuPathDB` only, so UniDB gets no summary list |
| `spanQuestions.xml:634` | an `excludeProjects` that does not name UniDB, so UniDB stays included — which is what we want |

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/spanQuestions.xml:489`

- [ ] **Step 1: Confirm the defect before changing it**

```bash
sed -n '478,495p' ~/workspaces/fungidb/ApiCommonModel/Model/lib/wdk/model/questions/spanQuestions.xml
```

Expected: question `DynSpansByEQTLtoGenes` includes `UniDB`, but the second
`<attributesList>` is scoped `includeProjects="EuPathDB"`. Confirm the two
`<attributesList>` bodies differ only in `sorting` whitespace — if they differ
substantively, stop and ask, because then the intent was not a simple rename.

- [ ] **Step 2: Add UniDB to the attributesList scope**

Change line 489 from:

```xml
        <attributesList includeProjects="EuPathDB"
```

to:

```xml
        <attributesList includeProjects="EuPathDB,UniDB"
```

Adding rather than replacing: `EuPathDB` is inert, and leaving it keeps this diff a pure
addition, so it cannot regress a site that somehow still uses the old model name.

- [ ] **Step 3: Build and verify the portal is unaffected in fungidb**

```bash
bash ~/workspaces/agentic-veupath-dev/bin/veup-build.sh fungidb wb model
```

Expected: build succeeds. This change is a no-op on FungiDB (whose model name is
`FungiDB`, matching neither scope), so the only thing being proven here is that the model
still parses. Verifying the portal behaviour itself needs a UniDB instance and is out of
scope for this branch — note it for whoever builds the portal next.

- [ ] **Step 4: Commit**

```bash
cd ~/workspaces/fungidb/ApiCommonModel
git add Model/lib/wdk/model/questions/spanQuestions.xml
git commit -m "Include UniDB in the eQTL genomic segment attributesList scope

The portal's WDK model name is UniDB, not EuPathDB, so an attributesList
scoped to EuPathDB never applied there and the search rendered without its
intended summary columns."
bash ~/workspaces/agentic-veupath-dev/bin/veup-git-sync.sh fungidb
```

---

## Deferred, deliberately

- **seqret wiring** (spec §8). Adding the FASTA step needs a `SequenceType` enum value, a
  switch arm in `SequenceReporter.getSequenceTypeByRecordClassFullName`, the `sequence`
  reporter on the record class, and deployment env vars. No service code changes.
- **The `<`/`<=` boundary at `ref_start`.** Implemented as specified; Task 7 Step 4 is
  where it gets challenged. Once seqret is wired, a wrong boundary shows up as
  `" | error_code=NOT_REQUESTED_LENGTH"` appended to a defline — seqret fails open rather
  than erroring, so it is only visible to someone reading deflines.
- **A strain tuning table.** Only if Task 2 Step 2 shows the vocabulary query is too slow.
  Do not build it speculatively.
