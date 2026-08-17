# Variant Genomic Colocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Genomic Colocation combine step work for the Short Variant record in both directions, and repair the Oracle→Postgres damage that currently limits colocation to genes ↔ genes.

**Architecture:** Replace the record-class `if/else` in `SpanCompositionPlugin.getSpanSql` with a `SpanSource` interface plus a registry keyed by record-class full name. Three implementations — Transcript, DynSpan, Variant. An unregistered record class throws rather than falling back. The model then declares Variant as a legal colocation input (`span_a`/`span_b`), adds a `VariantsBySpanLogic` question, and places it in the category ontology.

**Tech Stack:** Java 17, Maven, JUnit 4, WDK/WSF plugin framework, WDK model XML, PostgreSQL 18.

**Spec:** `docs/superpowers/specs/2026-08-15-variant-genomic-colocation-design.md`

---

## Working environment

Both repos are edited **in place** under `~/workspaces/plasmodb`. Do **not** create a git worktree — mutagen syncs only the instance directory, so a worktree would never reach the webserver and every build would verify stale code.

Paths used throughout:

- Local model repo: `~/workspaces/plasmodb/ApiCommonModel`
- Local plugin repo: `~/workspaces/plasmodb/ApiCommonWebService`
- Remote plugin repo: `/var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService`
- appDb for read-only SQL checks: `psql -h localhost -p 5433 -U jbrestel -d genomicsdb_071n`

**Maven does not work locally** — the parent POM `org.gusdb:gus-project-pom` is unresolvable without GitHub Packages auth, so `mvn` fails with `'dependencies.dependency.version' for com.github.samtools:htsjdk:jar is missing`. Unit tests run on the remote, over a login shell. After editing locally, give mutagen a moment to deliver, then:

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Ignore `bind [127.0.0.1]:NNNN: Address already in use` lines in ssh output — that is a pre-existing tunnel holding those forwards, not an error in your command.

## Two invariants you must not break

1. **Every `SpanSource` must alias its location table `fl`.** `getStartStop` hardcodes `String table = "fl."` (`SpanCompositionPlugin.java:351`) when building the `region[]` expressions that every builder interpolates. An alias other than `fl` produces SQL that references a table that isn't there.
2. **`is_top_level = 1` must stay on the Transcript source.** 2,503 rows in `apidb.FeatureLocation` have `is_top_level = 0`; they are human pseudoautosomal-region genes carrying duplicate chrX/chrY placements. Removing the filter double-counts them.

## File structure

| File | Responsibility | Action |
|---|---|---|
| `ApiCommonWebService/WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java` | Span logic; gains `SpanSource` + registry, loses the `if/else` and the SNP branch | Modify |
| `ApiCommonWebService/WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanSourceTest.java` | Unit tests for the three sources and the registry lookup | Create |
| `ApiCommonModel/Model/lib/wdk/model/questions/params/spanParams.xml` | Declares legal colocation inputs | Modify (`:167`, `:253`) |
| `ApiCommonModel/Model/lib/wdk/model/questions/spanQuestions.xml` | Declares colocation questions | Modify (replace commented SNP blocks) |
| `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt` | Category tree placement | Modify (`:207-208`) |

---

## Task 1: Branch `ApiCommonWebService`

`ApiCommonModel` is already on `feat/variant-colocation`. The plugin repo is not.

**Files:** none changed — git state only.

- [ ] **Step 1: Confirm the current branch is `master`**

```bash
git -C ~/workspaces/plasmodb/ApiCommonWebService rev-parse --abbrev-ref HEAD
```

Expected: `master`

- [ ] **Step 2: Create the feature branch, same name as the model repo**

```bash
git -C ~/workspaces/plasmodb/ApiCommonWebService checkout -b feat/variant-colocation
```

Expected: `Switched to a new branch 'feat/variant-colocation'`

- [ ] **Step 3: Reconcile the remote's refs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-git-sync.sh plasmodb
```

Expected: every repo `ok`, `web-monorepo` in the `skipped` block. `ApiCommonModel` may report `UNPUSHED` because the design-doc commit exists only locally; that is expected and harmless.

---

## Task 2: `SpanSource` interface and registry lookup

Introduce the abstraction and the failing-lookup behavior first, with no sources registered yet.

**Files:**
- Modify: `ApiCommonWebService/WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java`
- Create: `ApiCommonWebService/WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanSourceTest.java`

Note a deliberate deviation from the spec's §3.2 sketch: `createTableSql` takes **no** `WdkModel` argument. The spec included one because the old SNP branch called `wdkModel.getProjectId()`; the Variant source reads the real `project_id` column instead, so no source needs the model. Dropping it makes every source a pure function of its arguments and the tests trivial.

- [ ] **Step 1: Write the failing test**

Create `WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanSourceTest.java`:

```java
package org.apidb.apicomplexa.wsfplugin.spanlogic;

import org.gusdb.wdk.model.WdkModelException;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

public class SpanSourceTest {

  @Test
  public void unregisteredRecordClassThrowsNamingTheClass() {
    try {
      SpanCompositionPlugin.spanSourceFor("OrfRecordClasses.OrfRecordClass");
      fail("expected WdkModelException for an unregistered record class");
    }
    catch (WdkModelException e) {
      assertTrue("message should name the record class, was: " + e.getMessage(),
          e.getMessage().contains("OrfRecordClasses.OrfRecordClass"));
    }
  }

  @Test
  public void transcriptRecordClassIsRegistered() throws WdkModelException {
    assertNotNull(SpanCompositionPlugin.spanSourceFor("TranscriptRecordClasses.TranscriptRecordClass"));
  }

  @Test
  public void dynSpanRecordClassIsRegistered() throws WdkModelException {
    assertNotNull(SpanCompositionPlugin.spanSourceFor("DynSpanRecordClasses.DynSpanRecordClass"));
  }

  @Test
  public void variantRecordClassIsRegistered() throws WdkModelException {
    assertNotNull(SpanCompositionPlugin.spanSourceFor("VariantRecordClasses.VariantRecordClass"));
  }

  @Test
  public void onlyVariantIsStrandless() throws WdkModelException {
    assertEquals(false,
        SpanCompositionPlugin.spanSourceFor("TranscriptRecordClasses.TranscriptRecordClass").isStrandless());
    assertEquals(false,
        SpanCompositionPlugin.spanSourceFor("DynSpanRecordClasses.DynSpanRecordClass").isStrandless());
    assertEquals(true,
        SpanCompositionPlugin.spanSourceFor("VariantRecordClasses.VariantRecordClass").isStrandless());
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Expected: compilation failure — `cannot find symbol: method spanSourceFor(String)`.

- [ ] **Step 3: Add the interface, registry, and lookup**

In `SpanCompositionPlugin.java`, add `import java.util.Map;` if absent (it is already imported). Immediately after the `Flag` class (currently `:100-102`), insert:

```java
  /**
   * Where a record type's genomic coordinates come from. One implementation per record
   * class that may be an input to colocation.
   *
   * Implementations MUST alias their location table "fl" -- getStartStop() hardcodes that
   * prefix when building the region expressions interpolated into every builder.
   */
  interface SpanSource {

    /** Full CREATE TABLE statement producing the per-record span temp table. */
    String createTableSql(String tableName, String[] region, String cacheSql);

    /**
     * True for a point feature with no meaningful strand. Suppresses the same-strand /
     * opposite-strand filter for the whole comparison; without it, "same strand" would
     * silently match only forward-strand records.
     */
    default boolean isStrandless() {
      return false;
    }
  }

  private static final Map<String, SpanSource> SPAN_SOURCES = Map.of(
      "TranscriptRecordClasses.TranscriptRecordClass", new TranscriptSpanSource(),
      "DynSpanRecordClasses.DynSpanRecordClass", new DynSpanSource(),
      "VariantRecordClasses.VariantRecordClass", new VariantSpanSource());

  static SpanSource spanSourceFor(String recordClassName) throws WdkModelException {
    SpanSource source = SPAN_SOURCES.get(recordClassName);
    if (source == null) {
      throw new WdkModelException("Genomic colocation is not configured for record class " +
          recordClassName + ". Register a SpanSource for it in SpanCompositionPlugin.");
    }
    return source;
  }
```

Then add the three placeholder implementations at the end of the class, just before its closing brace. They are filled in by Tasks 3-5; for now they must compile:

```java
  static class TranscriptSpanSource implements SpanSource {
    @Override
    public String createTableSql(String tableName, String[] region, String cacheSql) {
      throw new UnsupportedOperationException("filled in by Task 3");
    }
  }

  static class DynSpanSource implements SpanSource {
    @Override
    public String createTableSql(String tableName, String[] region, String cacheSql) {
      throw new UnsupportedOperationException("filled in by Task 4");
    }
  }

  static class VariantSpanSource implements SpanSource {
    @Override
    public String createTableSql(String tableName, String[] region, String cacheSql) {
      throw new UnsupportedOperationException("filled in by Task 5");
    }

    @Override
    public boolean isStrandless() {
      return true;
    }
  }
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Expected: `Tests run: 5, Failures: 0, Errors: 0, Skipped: 0`

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanSourceTest.java
git commit -m "Add SpanSource interface and record-class registry

An unregistered record class now throws rather than silently falling back
to a bare apidb.FeatureLocation join that was never validated for it."
```

---

## Task 3: `TranscriptSpanSource`

Move the existing `getTranscriptSpanSql` body behind the interface, **byte-for-byte**. This is the only colocation path that works in production today, so it changes in placement only.

**Files:**
- Modify: `ApiCommonWebService/.../SpanCompositionPlugin.java`
- Test: `ApiCommonWebService/.../SpanSourceTest.java`

- [ ] **Step 1: Write the failing test**

Append to `SpanSourceTest.java`, inside the class:

```java
  private static final String[] REGION = { "(CASE WHEN COALESCE(fl.is_reversed, 0) = 0 THEN (start_min + 1*(0)) END)",
                                           "(CASE WHEN COALESCE(fl.is_reversed, 0) = 0 THEN (end_max + 1*(0)) END)" };
  private static final String CACHE = "(SELECT source_id, gene_source_id, project_id, wdk_weight FROM some_cache)";

  private static String sqlFor(String recordClassName) throws WdkModelException {
    return SpanCompositionPlugin.spanSourceFor(recordClassName).createTableSql("temp_1", REGION, CACHE);
  }

  @Test
  public void transcriptSourceJoinsOnGeneAndKeepsTopLevelFilter() throws WdkModelException {
    String sql = sqlFor("TranscriptRecordClasses.TranscriptRecordClass");
    assertTrue(sql, sql.contains("FROM apidb.FeatureLocation fl"));
    assertTrue(sql, sql.contains("fl.feature_source_id = ca.gene_source_id"));
    assertTrue("is_top_level filter is load-bearing for PAR genes: " + sql,
        sql.contains("fl.is_top_level = 1"));
    assertTrue(sql, sql.contains("fl.feature_type = 'GeneFeature'"));
    assertTrue(sql, sql.contains("CREATE TABLE temp_1 AS"));
  }

  @Test
  public void noSourceEmitsOracleOnlyConstructs() throws WdkModelException {
    for (String rc : new String[] { "TranscriptRecordClasses.TranscriptRecordClass",
                                    "DynSpanRecordClasses.DynSpanRecordClass",
                                    "VariantRecordClasses.VariantRecordClass" }) {
      String sql = sqlFor(rc);
      assertTrue(rc + " must not use rownum: " + sql, !sql.contains("rownum"));
      assertTrue(rc + " must not use DECODE: " + sql, !sql.contains("DECODE("));
      assertTrue(rc + " must alias its location table fl: " + sql, sql.contains(" fl,") || sql.contains(" fl "));
    }
  }
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Expected: FAIL with `UnsupportedOperationException: filled in by Task 3`.

- [ ] **Step 3: Implement `TranscriptSpanSource`**

Replace the placeholder body:

```java
  static class TranscriptSpanSource implements SpanSource {
    @Override
    public String createTableSql(String tableName, String[] region, String cacheSql) {
      StringBuilder builder = new StringBuilder();
      builder.append("CREATE TABLE " + tableName + " AS ");
      builder.append("SELECT DISTINCT ca.source_id, ca.gene_source_id, ");
      builder.append("       fl.sequence_source_id, fl.feature_type, ");
      builder.append("       ca.wdk_weight, ca.project_id, ");
      builder.append("       COALESCE(fl.is_reversed, 0) AS is_reversed, ");
      builder.append("   " + region[0] + " AS begin, " + region[1] + " AS end ");
      builder.append("FROM apidb.FeatureLocation fl, " + cacheSql + " ca ");
      builder.append("WHERE fl.feature_source_id = ca.gene_source_id");
      builder.append("  AND fl.is_top_level = 1");
      builder.append("  AND fl.feature_type = 'GeneFeature'");
      return builder.toString();
    }
  }
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest#transcriptSourceJoinsOnGeneAndKeepsTopLevelFilter"'
```

Expected: the transcript test passes. `noSourceEmitsOracleOnlyConstructs` still fails on the other two sources — that is correct at this point.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanSourceTest.java
git commit -m "Move transcript span SQL behind SpanSource, unchanged"
```

---

## Task 4: `DynSpanSource` — the `DECODE` fix

The old DynSpan branch built a `locTable` that the shared builder then wrapped. Collapse both into one source, port `DECODE` to `CASE WHEN`, and drop the synthetic `is_top_level` / `feature_type` columns that existed only to satisfy filters the shared builder no longer applies.

`regexp_substr` with Oracle's 4-argument signature is **kept** — verified working on PostgreSQL 18.4: `select regexp_substr('chr1:100-200:r','[^:]+',1,3)` returns `r`.

**Files:**
- Modify: `ApiCommonWebService/.../SpanCompositionPlugin.java`
- Test: `ApiCommonWebService/.../SpanSourceTest.java`

- [ ] **Step 1: Write the failing test**

Append to `SpanSourceTest.java`, inside the class:

```java
  @Test
  public void dynSpanSourceParsesCoordinatesWithoutOracleSyntax() throws WdkModelException {
    String sql = sqlFor("DynSpanRecordClasses.DynSpanRecordClass");
    assertTrue(sql, sql.contains("CASE WHEN regexp_substr(source_id, '[^:]+', 1, 3) = 'r' THEN 1 ELSE 0 END AS is_reversed"));
    assertTrue("coordinates come from the step's own cache table: " + sql, sql.contains(CACHE));
    assertTrue("one row per record, so no is_top_level: " + sql, !sql.contains("is_top_level"));
    assertTrue("one row per record, so no feature_type: " + sql, !sql.contains("feature_type"));
    assertTrue(sql, sql.contains("fl.feature_source_id = ca.source_id"));
  }
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Expected: FAIL with `UnsupportedOperationException: filled in by Task 4`.

- [ ] **Step 3: Add the shared one-row builder and implement `DynSpanSource`**

Add this private static helper to the class, next to the sources. Note it does **not** select `feature_type` — nothing downstream reads it (`composeSql` selects only `source_id`, `gene_source_id`, `project_id`, `wdk_weight`, `begin`, `end`, `is_reversed`), and requiring it would force every source to synthesize a meaningless label:

```java
  /**
   * Standard span table for a source that yields exactly one row per record. No
   * is_top_level / feature_type filtering: that exists only to pick one row out of
   * apidb.FeatureLocation, where a feature has several.
   */
  private static String oneRowPerRecordSql(String tableName, String[] region, String locTable,
      String cacheSql) {
    StringBuilder builder = new StringBuilder();
    builder.append("CREATE TABLE " + tableName + " AS ");
    builder.append("SELECT DISTINCT fl.feature_source_id AS source_id, 'dontcare' as gene_source_id, ");
    builder.append("       fl.sequence_source_id, ");
    builder.append("       ca.wdk_weight, ca.project_id, ");
    builder.append("       COALESCE(fl.is_reversed, 0) AS is_reversed, ");
    builder.append("   " + region[0] + " AS begin, " + region[1] + " AS end ");
    builder.append("FROM " + locTable + " fl, " + cacheSql + " ca ");
    builder.append("WHERE fl.feature_source_id = ca.source_id");
    return builder.toString();
  }
```

Then replace the `DynSpanSource` placeholder:

```java
  static class DynSpanSource implements SpanSource {
    @Override
    public String createTableSql(String tableName, String[] region, String cacheSql) {
      String locTable = "(SELECT source_id AS feature_source_id, project_id, " +
          "        regexp_substr(source_id, '[^:]+', 1, 1) as sequence_source_id, " +
          "        regexp_substr(regexp_substr(source_id, '[^:]+', 1, 2), '[^\\-]+', 1,1) as start_min, " +
          "        regexp_substr(regexp_substr(source_id, '[^:]+', 1, 2), '[^\\-]+', 1,2) as end_max, " +
          "        CASE WHEN regexp_substr(source_id, '[^:]+', 1, 3) = 'r' THEN 1 ELSE 0 END AS is_reversed " +
          "  FROM " + cacheSql + ")";
      return oneRowPerRecordSql(tableName, region, locTable, cacheSql);
    }
  }
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Expected: the DynSpan test passes. `noSourceEmitsOracleOnlyConstructs` still fails on Variant only.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanSourceTest.java
git commit -m "Port DynSpan span SQL to Postgres: DECODE -> CASE WHEN

Also drops the synthetic is_top_level/feature_type columns, which existed
only to satisfy filters the one-row-per-record builder no longer applies."
```

---

## Task 5: `VariantSpanSource`

**Files:**
- Modify: `ApiCommonWebService/.../SpanCompositionPlugin.java`
- Test: `ApiCommonWebService/.../SpanSourceTest.java`

- [ ] **Step 1: Write the failing test**

Append to `SpanSourceTest.java`, inside the class:

```java
  @Test
  public void variantSourceIsAZeroLengthFeatureFromVariationAttributes() throws WdkModelException {
    String sql = sqlFor("VariantRecordClasses.VariantRecordClass");
    assertTrue(sql, sql.contains("FROM ApidbTuning.VariationAttributes va"));
    assertTrue("start and end are the same point: " + sql,
        sql.contains("va.location AS start_min") && sql.contains("va.location AS end_max"));
    assertTrue("a point feature has no strand: " + sql, sql.contains("0 AS is_reversed"));
    assertTrue("project_id comes from the row, not the model: " + sql, sql.contains("va.project_id"));
    assertTrue("one row per record, so no is_top_level: " + sql, !sql.contains("is_top_level"));
    assertTrue(sql, sql.contains("fl.feature_source_id = ca.source_id"));
  }
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Expected: FAIL with `UnsupportedOperationException: filled in by Task 5`.

- [ ] **Step 3: Implement `VariantSpanSource`**

Replace the placeholder body, keeping the `isStrandless()` override already present:

```java
  static class VariantSpanSource implements SpanSource {
    @Override
    public String createTableSql(String tableName, String[] region, String cacheSql) {
      String locTable = "(SELECT va.source_id AS feature_source_id, va.project_id, " +
          "        va.sequence_source_id, " +
          "        va.location AS start_min, va.location AS end_max, " +
          "        0 AS is_reversed " +
          "  FROM ApidbTuning.VariationAttributes va)";
      return oneRowPerRecordSql(tableName, region, locTable, cacheSql);
    }

    @Override
    public boolean isStrandless() {
      return true;
    }
  }
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test -Dtest=SpanSourceTest"'
```

Expected: `Tests run: 9, Failures: 0, Errors: 0, Skipped: 0` — every test, including `noSourceEmitsOracleOnlyConstructs`.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanSourceTest.java
git commit -m "Add VariantSpanSource over ApidbTuning.VariationAttributes"
```

---

## Task 6: Wire `getSpanSql` to the registry and delete the dead paths

**Files:**
- Modify: `ApiCommonWebService/.../SpanCompositionPlugin.java` (`:100-102`, `:385`, `:429-476`, `:479-497`)

- [ ] **Step 1: Rename the flag**

At `:100-102`, change:

```java
  private static class Flag {
    private boolean hasSnp = false;
  }
```

to:

```java
  private static class Flag {
    /** Set when either input is a point feature with no meaningful strand. */
    private boolean strandless = false;
  }
```

At `:385` in `composeSql`, change `if (!flag.hasSnp) {` to `if (!flag.strandless) {`.

- [ ] **Step 2: Replace the if/else with the registry lookup**

In `getSpanSql`, delete the whole block from `String rcName = ...` through the `else { locTable = "apidb.FeatureLocation"; }` (currently `:429-449`), and delete the `String sql = rcName.equals("TranscriptRecordClasses.TranscriptRecordClass") ? ... : ...;` ternary (currently `:464-466`). The method body from the `rcName` line onward becomes:

```java
    String rcName = answerValue.getQuestion().getRecordClass().getFullName();
    SpanSource source = spanSourceFor(rcName);
    if (source.isStrandless())
      flag.strandless = true;

    // get a temp table name
    DBPlatform platform = wdkModel.getAppDb().getPlatform();
    DataSource dataSource = wdkModel.getAppDb().getDataSource();
    String schema = wdkModel.getAppDb().getDefaultSchema();
    try {
      String tableName = null;
      while (true) {
        tableName = TEMP_TABLE_PREFIX + random.nextInt(Integer.MAX_VALUE);
        if (!platform.checkTableExists(dataSource, schema, tableName))
          break;
      }

      String sql = source.createTableSql(tableName, region, cacheSql);
      logger.debug("SPAN SQL: " + sql);

      // cache the sql
      SqlUtils.executeUpdate(dataSource, sql, "span-logic-child");

      return tableName;
    }
    catch (SQLException ex) {
      throw new WdkModelException(ex);
    }
  }
```

- [ ] **Step 3: Delete the two obsolete builders**

Delete `getStandardSpanSql` entirely (currently `:479-497`). It is the only remaining home of `AND rownum = 1`, which is **deleted rather than ported**: it filtered all rows to the `feature_type` of one arbitrary joined row — a defensive no-op even on Oracle (only 95 `feature_source_id`s in 46M `apidb.FeatureLocation` rows have more than one distinct `feature_type`), and after this refactor it would sit only on paths that are one-row-per-record by construction.

Delete `getTranscriptSpanSql` (currently `:500-514`); `TranscriptSpanSource` replaced it in Task 3.

- [ ] **Step 4: Verify nothing Oracle-only or SNP-specific remains**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
grep -nE 'rownum|DECODE\(|hasSnp|SnpRecordClasses|getStandardSpanSql|getTranscriptSpanSql' \
  WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java
```

Expected: **no output**. Any hit means a deletion was missed.

- [ ] **Step 5: Run the full plugin test suite**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test"'
```

Expected: all tests pass, including the pre-existing `variants` and `motifsearch` suites. `SpanSourceTest` contributes 9.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/spanlogic/SpanCompositionPlugin.java
git commit -m "Dispatch span sources through the registry; drop dead Oracle and SNP paths

- getSpanSql looks up a SpanSource instead of branching on record-class name
- Flag.hasSnp -> Flag.strandless, named after the property not one record type
- deletes the unreachable SnpRecordClass branch: every SNP import is commented
  out of apiCommonModel.xml, so that record class cannot exist at runtime
- deletes the rownum subquery rather than porting it"
```

---

## Task 7: Declare Variant a legal colocation input

Without this, a variant result cannot be offered as a colocation input and the variants → genes direction is impossible.

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/spanParams.xml` (`:167`, `:253`)

- [ ] **Step 1: Add the record class to `span_a`**

In the `<answerParam name="span_a" ...>` block, after the `TranscriptRecordClasses.TranscriptRecordClass` line and before the `DynSpanRecordClasses.DynSpanRecordClass` line, insert:

```xml
              <recordClass ref="VariantRecordClasses.VariantRecordClass" includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB" />
```

- [ ] **Step 2: Add the same line to `span_b`**

Insert the identical line in the `<answerParam name="span_b" ...>` block, in the same position.

- [ ] **Step 3: Verify both were added**

```bash
grep -c 'VariantRecordClasses.VariantRecordClass' \
  ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/params/spanParams.xml
```

Expected: `2`

- [ ] **Step 4: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/spanParams.xml
git commit -m "Allow Short Variant results as genomic colocation inputs"
```

---

## Task 8: Add the `VariantsBySpanLogic` question

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/spanQuestions.xml` (replace the commented SNP blocks at `:368-397` and the `SnpsChipsBySpanLogic` block that follows)

- [ ] **Step 1: Replace the commented SNP blocks**

Delete the commented-out `SnpsBySpanLogic` block and the commented-out `SnpsChipsBySpanLogic` block in their entirety, along with the `<!-- SNPs -->` banner comment above them. In their place put:

```xml
  <!--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->
  <!-- Short Variants   -->
  <!--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++-->

    <question name="VariantsBySpanLogic"
              displayName="Short Variants By Relative Location"
              shortDisplayName="Variants by Rel Loc"
              queryRef="SpanId.RecordsBySpanLogic"
              recordClassRef="VariantRecordClasses.VariantRecordClass"
              includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">
        <attributesList
               summary="variant_location,gene_ids,variant_type,matched_count,feature_region,matched_regions"
               sorting="chromosome_order_num asc,location asc"
        />
        <summary>
         Get short variants with span logic operation against other results
        </summary>
        <description>
          <![CDATA[
              Get short variants with span logic operation against other results
          ]]>
        </description>

         <dynamicAttributes>
           <columnAttribute name="matched_count" displayName="Match Count" align="center"/>
           <columnAttribute name="feature_region" displayName="Region" align="center"/>
           <columnAttribute name="matched_regions" displayName="Matched Regions" truncateTo="4000"/>
         </dynamicAttributes>
    </question>
```

Three things here are deliberate and must not be "corrected":
- `includeProjects` is copied from the `VariantRecordClasses` recordClassSet, so the search exists exactly where the record does.
- `sorting` mirrors the record's own default (`variantRecords.xml:304`). Do **not** sort on `variant_location` — it is a `textAttribute`, not a sortable column.
- The three dynamic columns must be named in `attributesList` explicitly or they do not render, even though they are declared in `dynamicAttributes`.
- There are **no** CDS or gene dynamic attributes. The old SNP question's `linkedGeneId` and `position_in_protein` are dropped on purpose.

- [ ] **Step 2: Verify no SNP span questions remain**

```bash
grep -nE 'SnpsBySpanLogic|SnpsChipsBySpanLogic' \
  ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/spanQuestions.xml
```

Expected: **no output**.

- [ ] **Step 3: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/spanQuestions.xml
git commit -m "Add VariantsBySpanLogic, replacing the commented SNP span questions"
```

---

## Task 9: Place the search in the category ontology

`wb model` does **not** regenerate the category OWL. Skipping this leaves the search uncategorized with no error anywhere.

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt` (`:207-208`)

- [ ] **Step 1: Replace the two SNP lines with one Variant line**

The file is 14 tab-separated fields: field 1 is the id, field 4 `recordClassName`, field 5 `targetType`, field 6 `name`, fields 2-3 and 7-14 empty. Entries are sorted alphabetically within each record-class block, so the Variant line goes **after** `SnpsChipsBySpanLogic`'s old position.

Delete lines 207 and 208 (`...SnpsBySpanLogic` and `...SnpsChipsBySpanLogic`) and insert in their place, preserving tabs exactly:

```
DynSpanRecordClasses.DynSpanRecordClass.SpanQuestions.VariantsBySpanLogic			DynSpanRecordClasses.DynSpanRecordClass	search	SpanQuestions.VariantsBySpanLogic								
```

That is: name, three tabs, `DynSpanRecordClasses.DynSpanRecordClass`, tab, `search`, tab, `SpanQuestions.VariantsBySpanLogic`, then eight trailing tabs.

Every `BySpanLogic` entry sits under the `DynSpanRecordClass` parent regardless of its own record type. That is a quirk of the existing tree — mirror it, do not fix it here.

- [ ] **Step 2: Verify the field count and that SNP entries are gone**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
awk -F'\t' '/VariantsBySpanLogic/{print FILENAME": "NF" fields"}' Model/lib/wdk/ontology/individuals.txt
grep -c 'SnpsBySpanLogic\|SnpsChipsBySpanLogic' Model/lib/wdk/ontology/individuals.txt
```

Expected: `14 fields`, and `0` for the grep.

- [ ] **Step 3: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "Place VariantsBySpanLogic in the category ontology"
```

---

## Task 10: Build

**Files:** none — build only.

- [ ] **Step 1: Reconcile remote refs before building**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-git-sync.sh plasmodb
```

Expected: repos `ok` or `UNPUSHED` (local-only commits are fine — mutagen already delivered the files); `web-monorepo` skipped.

- [ ] **Step 2: Confirm no monorepo overlay is active**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-mono.sh status plasmodb
```

Expected: `overlay: none active` and `rebuilder: ok`. If an overlay is active, run `bin/veup-mono.sh down plasmodb` first.

- [ ] **Step 3: Run the build**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb full
```

`wb full` is required, not `wb model` or `wb ontology`: Java changed in `ApiCommonWebService` (which `wb model` does not build) **and** `individuals.txt` changed (which `wb model` does not regenerate). Expect this to be slow; quiet is not hung.

Expected: build succeeds and the webapp reloads.

---

## Task 11: Verify the generated SQL against the real database

Cheaper than a page load, and it isolates SQL errors from model errors.

**Files:** none — verification only.

- [ ] **Step 1: Confirm the Variant location source returns one row per variant**

```bash
psql -h localhost -p 5433 -U jbrestel -d genomicsdb_071n -Atc "
  SELECT count(*), count(distinct source_id)
  FROM ApidbTuning.VariationAttributes
  WHERE sequence_source_id = 'Pf3D7_01_v3'"
```

Expected: the two numbers are **equal**. That is the one-row-per-record premise the `oneRowPerRecordSql` builder depends on. If they differ, stop — the design assumption is wrong and Task 5 needs revisiting.

- [ ] **Step 2: Execute a representative Variant span table build, read-only**

```bash
psql -h localhost -p 5433 -U jbrestel -d genomicsdb_071n -Atc "
  SELECT DISTINCT fl.feature_source_id AS source_id, 'dontcare' as gene_source_id,
         fl.sequence_source_id,
         1 AS wdk_weight, fl.project_id,
         COALESCE(fl.is_reversed, 0) AS is_reversed,
         (CASE WHEN COALESCE(fl.is_reversed, 0) = 0 THEN (start_min + 1*(0)) END) AS begin,
         (CASE WHEN COALESCE(fl.is_reversed, 0) = 0 THEN (end_max + 1*(0)) END) AS end
  FROM (SELECT va.source_id AS feature_source_id, va.project_id, va.sequence_source_id,
               va.location AS start_min, va.location AS end_max, 0 AS is_reversed
          FROM ApidbTuning.VariationAttributes va) fl,
       (SELECT 'Variant_Pf3D7_01_v3_100057' AS source_id) ca
  WHERE fl.feature_source_id = ca.source_id"
```

Expected: exactly one row, with `begin` and `end` both equal to `100057`, and `is_reversed` `0`.

- [ ] **Step 3: Confirm the coordinate matches the record**

```bash
psql -h localhost -p 5433 -U jbrestel -d genomicsdb_071n -Atc "
  SELECT source_id, sequence_source_id, location
  FROM ApidbTuning.VariationAttributes
  WHERE source_id = 'Variant_Pf3D7_01_v3_100057'"
```

Expected: `location` equals the `begin`/`end` from Step 2.

---

## Task 12: Live QA on the running instance

**Files:** none — verification only.

App URL: `https://jbrestel.plasmodb.org`. Use Claude in Chrome. Mark the logs first so a failure is readable:

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark qa
```

- [ ] **Step 1: Confirm the search is registered and correctly placed**

From an already-authenticated app page (a raw `curl` 307-redirects to autologin, and an unauthenticated tab silently answers for **production**), check `window.location.origin` is `https://jbrestel.plasmodb.org` first, then fetch:

- `/service/record-types/variation` → its `searches` list must contain `VariantsBySpanLogic`.
- `/service/ontologies/Categories` → the `VariantsBySpanLogic` node must exist under the `DynSpanRecordClass` parent, alongside `GenesBySpanLogic` and `DynSpansBySpanLogic`.

`/service/record-types/<type>` is the authority on whether this site has the search; the category tree is not project-filtered.

- [ ] **Step 2: Genes → Variants**

Run any gene search, then add a Colocate step producing **Short Variants**. Expected: non-zero results; the summary shows Location, Gene ID(s), Variant Type, Match Count, Region, Matched Regions.

- [ ] **Step 3: Variants → Genes**

Run any Short Variant search, then Colocate producing **Genes**. Expected: non-zero results. This direction proves Task 7 worked — before it, Variant could not be offered as an input at all.

- [ ] **Step 4: The strandless path**

Repeat Step 2 with the strand selector set to **same strand**, then **opposite strand**. Expected: both return the same non-zero count as the default. A zero result means `isStrandless()` is not reaching `flag.strandless`.

- [ ] **Step 5: DynSpan regression — genes ↔ genomic segments**

Run a genomic-segment or motif search, then Colocate against a gene result. Expected: non-zero results. This path is broken on `master` (both `rownum` and `DECODE`) and is the main regression risk of this change.

- [ ] **Step 6: Read the logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since qa --quiet
```

Expected: the error logs reported `silent:`.

- [ ] **Step 7: Spot-check one hit against the database**

Take one variant from the Step 2 result and confirm the gene it colocated with actually contains its `location`:

```bash
psql -h localhost -p 5433 -U jbrestel -d genomicsdb_071n -Atc "
  SELECT va.source_id, va.location, fl.feature_source_id, fl.start_min, fl.end_max
  FROM ApidbTuning.VariationAttributes va, apidb.FeatureLocation fl
  WHERE va.source_id = '<VARIANT_ID_FROM_RESULT>'
    AND fl.feature_source_id = '<GENE_ID_FROM_RESULT>'
    AND fl.feature_type = 'GeneFeature'
    AND fl.is_top_level = 1"
```

Expected: one row, with `location` between `start_min` and `end_max`.

---

## Task 13: Known risk to check, not to fix

**Files:** none — investigation only.

- [ ] **Step 1: Check the UniDB column-shift risk**

`RecordsBySpanLogic` declares `wsColumn project_id` unconditionally (`spanQueries.xml:322`), while `VariantRecordClass`'s primary key excludes `project_id` on UniDB (`variantRecords.xml:34`). `DynSpanRecordClass` has the identical PK shape (`dynSpanRecord.xml:12`) and shares that query, so this is pre-existing rather than introduced here — but DynSpan colocation has been broken on Postgres, so nobody has exercised it.

If a UniDB instance is available, run Task 12 Steps 2-3 against it and check that result rows are not shifted by one column. Report the finding. **Do not change the shared query** — it is used by DynSpan too, and a blind edit there breaks a working path to fix a hypothetical one.

---

## Task 14: Finish the branch

- [ ] **Step 1: Confirm the full test suite still passes**

```bash
ssh cedar 'bash -lc "cd /var/www/PlasmoDB/plasmo.jbrestel/project_home/ApiCommonWebService && mvn -q -pl WSFPlugin test"'
```

Expected: all tests pass.

- [ ] **Step 2: Review the complete diff in both repos**

```bash
git -C ~/workspaces/plasmodb/ApiCommonWebService diff master...feat/variant-colocation
git -C ~/workspaces/plasmodb/ApiCommonModel  diff master...feat/variant-colocation
```

- [ ] **Step 3: Use superpowers:finishing-a-development-branch to decide on merge or PR**

Both repos carry the same branch name, `feat/variant-colocation`, and must be merged together — the model references a plugin behavior that only exists on the plugin branch.
