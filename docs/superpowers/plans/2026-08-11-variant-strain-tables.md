# Variant Strain Tables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two per-strain tables to the Variant record page — one row per VCF sample, and one row per country — read directly from the published merged VCF at request time, plus a port of the legacy SNP record's EDA strain filter.

**Architecture:** A WSF plugin backs each record table (`processQuery`, not `sqlQuery`). Record-page table queries run **uncached** via `TableFieldProcessQueryResult.getUncachedResults()`, so each page view performs one tabix seek and one EDA query with nothing persisted. Pure VCF/annotation parsing lives in WDK-free classes that unit-test against a committed fixture; the plugins are thin shims over a shared composer.

**Tech Stack:** Java 17, htsjdk (tabix VCF random access), JUnit 4, WDK WSF plugin API, WDK model XML, React (`web-monorepo` genomics-site).

**Design doc:** `ApiCommonModel/docs/superpowers/specs/2026-08-11-variant-strain-tables-design.md`

---

## Environment facts (verified 2026-08-11)

| Fact | Value |
|---|---|
| Local checkout | `~/workspaces/plasmodb` (do **not** use a git worktree — mutagen syncs this directory only) |
| Branch | `dnaseq-merge-experiments` in every repo (already a feature branch; do not create another) |
| Remote host | `cedar` |
| Remote setenv | `/var/www/jbrestel.plasmodb.org/etc/setenv` |
| Remote project_home | `/var/www/jbrestel.plasmodb.org/project_home` |
| App URL | `https://jbrestel.plasmodb.org` |
| Real VCF | `/var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-71/Pfalciparum3D7/dnaseq/vcf/merged.ann.vcf.gz` (809 MB, `.tbi` present, 537 samples) |
| appDb (tunnel) | `psql -h localhost -p 5433 -d genomicsdb_071n` |
| Test source root | `ApiCommonWebService/WSFPlugin/src/test/java/` (the only Maven test dir; `ApiCommonWebService/Test/` is **not** a module and does not run) |
| Test framework | JUnit 4 (`org.junit.Test`, `org.junit.Assert`) |

**Building.** Java changes in `ApiCommonWebService` require `wb full` — `wb model` builds only
`EbrcModelCommon/Model` and `ApiCommonModel/Model` and will silently not pick up plugin changes.
Model XML changes need `wb model`; anything touching `individuals.txt` needs `wb ontology`
(a superset of `wb model`).

```bash
bin/veup-build.sh plasmodb wb full        # from ~/workspaces/agentic-veupath-dev
bin/veup-build.sh plasmodb wb ontology
```

Flags go **before** the profile name (`veup-build.sh --dry-run plasmodb wb model`).

**Running a unit test on cedar** (mutagen carries local edits over; allow a second or two):

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=CannIndexTest -DfailIfNoTests=false"'
```

---

## File Structure

**Create — `ApiCommonWebService/WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/`**

| File | Responsibility |
|---|---|
| `CannEntry.java` | One parsed `CANN` entry (record type) |
| `CannIndex.java` | Parse the INFO `CANN` string; resolve a sample's `CA` value to amino acids |
| `SampleCall.java` | One sample's call at a locus (record type) |
| `LocusCalls.java` | A locus: ref/alt alleles, `CannIndex`, all `SampleCall`s (record type) |
| `MergedVcfReader.java` | htsjdk + tabix seek → `LocusCalls`. No WDK types |
| `VariantLocusResolver.java` | PK → sequence/position/organism-file-name/EDA suffix + VCF path |
| `SampleMetadataLookup.java` | EDA `sample_stable_id → country` |
| `StrainRow.java`, `CountryRow.java` | Output row record types |
| `VariantLocusComposer.java` | Join calls to metadata; ploidy-weighted aggregation |
| `VariantStrainsPlugin.java` | WSF plugin for table A |
| `VariantCountrySummaryPlugin.java` | WSF plugin for table B |

**Create — test**

- `.../src/test/java/org/apidb/apicomplexa/wsfplugin/variants/CannIndexTest.java`
- `.../src/test/java/org/apidb/apicomplexa/wsfplugin/variants/MergedVcfReaderTest.java`
- `.../src/test/java/org/apidb/apicomplexa/wsfplugin/variants/VariantLocusComposerTest.java`
- `.../src/test/java/org/apidb/apicomplexa/wsfplugin/variants/HtsjdkRealFileSpikeTest.java`
- `.../src/test/resources/variants/fixture.vcf` (uncompressed; the reader handles both)

**Modify**

- `ApiCommonModel/Model/lib/wdk/model/records/variantTableQueries.xml` — two `processQuery`s
- `ApiCommonModel/Model/lib/wdk/model/records/variantRecords.xml` — two `<table>`s + one `<textAttribute>`
- `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt` — three rows
- `ApiCommonModel/Model/lib/wdk/model/questions/params/variantParams.xml` — `variant_strain_meta` filterParam
- `ApiCommonModel/Model/lib/wdk/model/questions/queries/variantQueries.xml` — no-op form query
- `ApiCommonModel/Model/lib/wdk/model/questions/variantQuestions.xml` — `VariantAlignmentForm` question

**Modify — `web-monorepo` (separate checkout on cedar, branch from `main`)**

- `packages/sites/genomics-site/webapp/wdkCustomization/js/client/components/records/VariantRecordClasses.VariantRecordClass.jsx`
- `packages/sites/genomics-site/webapp/wdkCustomization/js/client/components/common/VariantStrainFilter.jsx`
- `packages/sites/genomics-site/webapp/wdkCustomization/js/client/storeModules/Record.js`

---

## Task 1: Retire the htsjdk risks

Two unknowns block everything: whether `htsjdk` resolves at all (declared version-less), and
whether its `VCFCodec` tolerates this file's under-declared header. Both are cheap to settle and
expensive to meet later.

**Files:**
- Modify: `ApiCommonWebService/WSFPlugin/pom.xml`
- Create: `ApiCommonWebService/WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/variants/HtsjdkRealFileSpikeTest.java`

- [ ] **Step 1: Check whether htsjdk resolves today**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin dependency:get -Dartifact=com.github.samtools:htsjdk:5.0.0 && \
  mvn -pl WSFPlugin dependency:tree -Dincludes=com.github.samtools:htsjdk"'
```

Expected: either a version printed in the tree, or an error naming `htsjdk` with no version.

- [ ] **Step 2: Pin the version if the tree showed none**

If Step 1 reported a missing version, add to `ApiCommonWebService/pom.xml` inside the existing
`<dependencyManagement><dependencies>` block (before `</dependencies>` at line 71):

```xml
	    <dependency>
	      <groupId>com.github.samtools</groupId>
	      <artifactId>htsjdk</artifactId>
		  <version>5.0.0</version>
	    </dependency>
```

If Step 1 already printed a version, skip this step and record the version in the commit message.

- [ ] **Step 3: Write the spike test**

It reads the real file, so it skips unless a path is supplied. `Assume` keeps it green in CI.

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import htsjdk.variant.variantcontext.Genotype;
import htsjdk.variant.variantcontext.VariantContext;
import htsjdk.variant.vcf.VCFFileReader;
import org.junit.Assume;
import org.junit.Test;

import java.io.File;
import java.util.Iterator;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

/**
 * Spike against the real published VCF. Skipped unless -Dvariants.vcf is supplied,
 * because the file is 809MB and lives only on the webserver.
 *
 * Run:
 *   mvn -pl WSFPlugin test -Dtest=HtsjdkRealFileSpikeTest \
 *     -Dvariants.vcf=/var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-71/Pfalciparum3D7/dnaseq/vcf/merged.ann.vcf.gz
 */
public class HtsjdkRealFileSpikeTest {

  @Test
  public void readsRealFileDespiteUnderDeclaredHeader() {
    String path = System.getProperty("variants.vcf");
    Assume.assumeNotNull(path);

    try (VCFFileReader reader = new VCFFileReader(new File(path), true)) {
      assertNotNull("header", reader.getFileHeader());
      assertFalse("samples", reader.getFileHeader().getGenotypeSamples().isEmpty());

      // Pf3D7_01_v3:29514 is a coding locus with a populated CANN (verified).
      Iterator<VariantContext> it = reader.query("Pf3D7_01_v3", 29514, 29514);
      assertTrue("locus found", it.hasNext());
      VariantContext vc = it.next();

      assertNotNull("CANN", vc.getAttributeAsString("CANN", null));

      Genotype g = vc.getGenotype(0);
      assertNotNull("GT", g.getType());
      assertTrue("DP present", g.hasDP());
      assertNotNull("CA", g.getExtendedAttribute("CA"));
    }
  }
}
```

- [ ] **Step 4: Run the spike against the real file**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=HtsjdkRealFileSpikeTest -DfailIfNoTests=false \
  -Dvariants.vcf=/var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-71/Pfalciparum3D7/dnaseq/vcf/merged.ann.vcf.gz"'
```

Expected: PASS.

**If it fails on the header** (`TribbleException` about an undeclared `GT`/`DP`/`AO` key, or the
leading bare `.` in INFO), the fix is a lenient codec. Add before the reader is constructed:

```java
htsjdk.variant.vcf.VCFStandardHeaderLines.addStandardFormatLines(
    reader.getFileHeader().getFormatHeaderLines(), true,
    htsjdk.variant.vcf.VCFConstants.GENOTYPE_KEY,
    htsjdk.variant.vcf.VCFConstants.DEPTH_KEY);
```

If that is not sufficient, stop and report the exact exception — the remaining options are
repairing the `VCFHeader` in code or fixing the header in `dnaseq-nextflow`, and that is a
decision for the spec author, not a silent workaround.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/variants/HtsjdkRealFileSpikeTest.java pom.xml
git commit -m "Prove htsjdk reads the merged VCF's under-declared header

The published merged.ann.vcf.gz declares only CANN, CA and DFS - no GT, DP,
AD/RO/QR/AO/QA or contig lines - and every INFO field opens with a bare '.'.
This spike settles what htsjdk does with that before any code depends on it.

Skipped unless -Dvariants.vcf names the file, which lives only on the webserver."
```

---

## Task 2: `CannEntry` and `CannIndex`

**Files:**
- Create: `.../variants/CannEntry.java`
- Create: `.../variants/CannIndex.java`
- Test: `.../variants/CannIndexTest.java`

- [ ] **Step 1: Write the failing test**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import org.junit.Test;

import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class CannIndexTest {

  /** Real CANN from Pf3D7_01_v3:29514. */
  private static final String CANN =
      "r0|GTG|V|reference|PF3D7_0100100.1|5|2|.|.," +
      "r1|GTN|V|reference|PF3D7_0100100.1|5|2|.|.," +
      "k0|GCG|A|missense|PF3D7_0100100.1|5|2|c.5T>C|p.Val2Ala," +
      "k1|ATG|M|missense|PF3D7_0100100.1|5|2|.|p.Val2Met";

  @Test
  public void parsesEntriesByKey() {
    CannIndex index = CannIndex.parse(CANN);
    CannEntry k0 = index.get("k0").orElseThrow();
    assertEquals("GCG", k0.codon());
    assertEquals("A", k0.aminoAcid());
    assertEquals("missense", k0.effect());
    assertEquals("PF3D7_0100100.1", k0.transcriptId());
    assertEquals("c.5T>C", k0.hgvsC());
  }

  @Test
  public void resolvesSingleKey() {
    assertEquals(List.of("A"), CannIndex.parse(CANN).aminoAcidsFor("k0"));
  }

  @Test
  public void resolvesDiploidSlotsAndDeduplicates() {
    // Two slots, two keys, same amino acid V -> one value, not two.
    assertEquals(List.of("V"), CannIndex.parse(CANN).aminoAcidsFor("r0/r1"));
    // Distinct amino acids keep both, in encounter order.
    assertEquals(List.of("V", "A"), CannIndex.parse(CANN).aminoAcidsFor("r0/k0"));
  }

  @Test
  public void resolvesPhasedSeparator() {
    assertEquals(List.of("V", "A"), CannIndex.parse(CANN).aminoAcidsFor("r0|k0"));
  }

  @Test
  public void resolvesMultipleTranscriptKeysForOneAllele() {
    assertEquals(List.of("A", "M"), CannIndex.parse(CANN).aminoAcidsFor("k0;k1"));
  }

  @Test
  public void bareRefAndMissingYieldNothing() {
    CannIndex index = CannIndex.parse(CANN);
    assertTrue(index.aminoAcidsFor("r").isEmpty());
    assertTrue(index.aminoAcidsFor(".").isEmpty());
    assertTrue(index.aminoAcidsFor("").isEmpty());
    assertTrue(index.aminoAcidsFor(null).isEmpty());
  }

  @Test
  public void emptyCannParsesToEmptyIndex() {
    assertTrue(CannIndex.parse(".").aminoAcidsFor("k0").isEmpty());
    assertTrue(CannIndex.parse(null).aminoAcidsFor("k0").isEmpty());
  }

  @Test
  public void unknownKeyIsSkippedNotThrown() {
    assertEquals(List.of("A"), CannIndex.parse(CANN).aminoAcidsFor("k0/k99"));
  }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=CannIndexTest -DfailIfNoTests=false"'
```

Expected: compilation failure — `CannIndex` does not exist.

- [ ] **Step 3: Implement `CannEntry`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

/**
 * One entry of the VCF INFO CANN field, whose format is
 * key|codon|aa|effect|transcript_id|pos_in_cds|pos_in_codon|hgvs_c|hgvs_p
 *
 * r-prefixed keys describe a reference allele per transcript, k-prefixed an alt allele.
 * hgvsC/hgvsP are "." for anything but a coding substitution.
 */
public record CannEntry(
    String key,
    String codon,
    String aminoAcid,
    String effect,
    String transcriptId,
    String posInCds,
    String posInCodon,
    String hgvsC,
    String hgvsP
) {}
```

- [ ] **Step 4: Implement `CannIndex`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Index over a locus's CANN entries, and the CA -> amino acid resolution that the
 * per-strain table needs.
 *
 * CA (a FORMAT field) names the CANN key(s) for one sample's genotype:
 *   - allele slots are separated by '/' (unphased) or '|' (phased)
 *   - multiple transcript keys for ONE allele are separated by ';'
 *   - a bare "r" means "reference allele, no CDS annotation"
 *   - "." means missing
 */
public class CannIndex {

  private static final CannIndex EMPTY = new CannIndex(Map.of());

  private final Map<String, CannEntry> _byKey;

  private CannIndex(Map<String, CannEntry> byKey) {
    _byKey = byKey;
  }

  public static CannIndex parse(String cannValue) {
    if (cannValue == null || cannValue.isEmpty() || ".".equals(cannValue)) return EMPTY;

    Map<String, CannEntry> byKey = new LinkedHashMap<>();
    for (String raw : cannValue.split(",")) {
      if (raw.isEmpty() || ".".equals(raw)) continue;
      // -1 keeps trailing empty fields, so a truncated entry is skipped rather than
      // silently shifting every field left.
      String[] f = raw.split("\\|", -1);
      if (f.length < 9) continue;
      byKey.put(f[0], new CannEntry(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8]));
    }
    return byKey.isEmpty() ? EMPTY : new CannIndex(byKey);
  }

  public Optional<CannEntry> get(String key) {
    return Optional.ofNullable(_byKey.get(key));
  }

  /**
   * Distinct amino acids named by a sample's CA value, in encounter order.
   * A sample legitimately resolves to several when the locus sits in a
   * multi-transcript gene.
   */
  public List<String> aminoAcidsFor(String caValue) {
    List<String> out = new ArrayList<>();
    if (caValue == null || caValue.isEmpty() || ".".equals(caValue)) return out;

    for (String slot : caValue.split("[/|]")) {
      for (String key : slot.split(";")) {
        if (key.isEmpty() || ".".equals(key) || "r".equals(key)) continue;
        CannEntry entry = _byKey.get(key);
        if (entry == null) continue;
        String aa = entry.aminoAcid();
        if (aa == null || aa.isEmpty() || ".".equals(aa)) continue;
        if (!out.contains(aa)) out.add(aa);
      }
    }
    return out;
  }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=CannIndexTest -DfailIfNoTests=false"'
```

Expected: PASS, 8 tests.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/ \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/variants/CannIndexTest.java
git commit -m "Add CANN parsing and CA -> amino acid resolution

CANN is an INFO field; CA is the per-sample FORMAT field naming which CANN
entries describe that sample's genotype. Slots split on / or |, transcript keys
within a slot on ';', bare 'r' means reference-with-no-CDS-annotation."
```

---

## Task 3: `SampleCall`, `LocusCalls`, `MergedVcfReader`

**Files:**
- Create: `.../variants/SampleCall.java`, `.../variants/LocusCalls.java`, `.../variants/MergedVcfReader.java`
- Create: `.../src/test/resources/variants/fixture.vcf`
- Test: `.../variants/MergedVcfReaderTest.java`

### Read-frequency definition

`Read Frequency` is **the fraction of reads supporting the called allele**:

- alt call → `AO[altIndex] / (RO + AO[altIndex]) * 100`, where `altIndex` is the index of
  the allele THIS sample carries — `vc.getAlleleIndex(allele) - 1`, since `getAlleleIndex`
  is 0 for the reference. Not `sum(AO)`: on a multi-allelic record that would dilute the
  called allele with reads supporting an alt the sample does not carry.
- reference call with real `RO`/`AO` → `RO / (RO + AO_total) * 100`. Summing IS correct
  here — reference support is measured against all non-reference reads.
- coverage-filled reference call (all of `AD/RO/QR/AO/QA` absent) → `100.00`
- no call → `null`

The asymmetry between the two branches is deliberate; do not "simplify" them to match.

**The published file is biallelic by construction.** `write_vcf_entry` emits one record per
unique alt, so the multi-allelic path is defensive, not hot. Measured on the real file:
548,040 alt calls across 40,000 loci, none with more than one nonzero `AO` and no record
with more than one ALT. The indexed form is still what the code must implement, because a
formula that only happens to be right is a trap for the next reader.

This deliberately differs from `processSequenceVariations.jl`'s `compute_percent`, which always
reports the *alt* fraction and returns `0.0` for a reference-only genotype. That convention suits
`allele.dat`, where the caller knows the orientation; in a column headed "Read Frequency" next to
a reference allele, `0.0` would read as "no reads support this call", which is the opposite of the
truth. See spec §5.5.

- [ ] **Step 1: Create the fixture VCF**

Reproduces the real file's header quirks deliberately: only `CANN`/`CA`/`DFS` declared, no
`##contig`, and INFO opening with a bare `.`.

Create `ApiCommonWebService/WSFPlugin/src/test/resources/variants/fixture.vcf`:

```
##fileformat=VCFv4.2
##INFO=<ID=CANN,Number=.,Type=String,Description="Coding annotation entries">
##FORMAT=<ID=CA,Number=1,Type=String,Description="CANN key(s) per GT allele">
##FORMAT=<ID=DFS,Number=1,Type=Integer,Description="Downstream of frameshift">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	S_ALT	S_FILLED	S_NOCALL	S_REFREAL	S_DIPHET
chr1	100	.	T	C	.	.	.;CANN=r0|GTG|V|reference|T1.1|5|2|.|.,k0|GCG|A|missense|T1.1|5|2|c.5T>C|p.Val2Ala	GT:DP:AD:RO:QR:AO:QA:CA:DFS	1:5:1,4:1:28:4:121:k0:0	0:128:.:.:.:.:.:r0:0	.:.:.:.:.:.:.:.:.	0:10:8,2:8:200:2:50:r0:0	0/1:20:10,10:10:250:10:260:r0/k0:0
```

Then compress and index it — `MergedVcfReader` requires an index, because streaming the real
809 MB file per page view is not a fallback. Commit all three files.

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService/WSFPlugin/src/test/resources/variants
bgzip -kf fixture.vcf && tabix -f -p vcf fixture.vcf.gz
ls -la
```

Expected: `fixture.vcf`, `fixture.vcf.gz`, `fixture.vcf.gz.tbi`.

- [ ] **Step 2: Write the failing test**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import org.junit.Test;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class MergedVcfReaderTest {

  private Map<String, SampleCall> callsAt(String seq, int pos) {
    Path vcf = Paths.get("src/test/resources/variants/fixture.vcf.gz");
    try (MergedVcfReader reader = new MergedVcfReader(vcf)) {
      LocusCalls locus = reader.read(seq, pos).orElseThrow();
      assertEquals("T", locus.refAllele());
      return locus.calls().stream()
          .collect(Collectors.toMap(SampleCall::sampleName, Function.identity()));
    }
  }

  @Test
  public void altCallCarriesAlleleDepthAndReadFrequency() {
    SampleCall c = callsAt("chr1", 100).get("S_ALT");
    assertEquals("1", c.genotype());
    assertEquals("C", c.allele());
    assertEquals(Integer.valueOf(5), c.depth());
    assertEquals("80.00", c.readFrequency());   // AO 4 / (RO 1 + AO 4)
    assertFalse(c.noCall());
  }

  @Test
  public void coverageFilledReferenceCallReportsFullSupport() {
    SampleCall c = callsAt("chr1", 100).get("S_FILLED");
    assertEquals("T", c.allele());
    assertEquals(Integer.valueOf(128), c.depth());
    assertTrue(c.coverageFilled());
    assertEquals("100.00", c.readFrequency());
  }

  @Test
  public void realReferenceCallReportsReferenceSupport() {
    SampleCall c = callsAt("chr1", 100).get("S_REFREAL");
    assertEquals("T", c.allele());
    assertFalse(c.coverageFilled());
    assertEquals("80.00", c.readFrequency());   // RO 8 / (RO 8 + AO 2)
  }

  @Test
  public void noCallIsPresentButEmpty() {
    SampleCall c = callsAt("chr1", 100).get("S_NOCALL");
    assertTrue(c.noCall());
    assertEquals("", c.allele());
    assertNull(c.depth());
    assertNull(c.readFrequency());
  }

  @Test
  public void diploidHetCollapsesToIupacOnOneRow() {
    SampleCall c = callsAt("chr1", 100).get("S_DIPHET");
    assertEquals("Y", c.allele());              // T + C
    assertEquals("0/1", c.genotype());
    assertEquals(2, c.ploidy());
  }

  @Test
  public void chromosomeAllelesKeepOneEntryPerSlot() {
    Map<String, SampleCall> calls = callsAt("chr1", 100);
    // The aggregation weight: duplicates are kept, IUPAC is NOT used here.
    assertEquals(List.of("T", "C"), calls.get("S_DIPHET").chromosomeAlleles());
    assertEquals(List.of("C"), calls.get("S_ALT").chromosomeAlleles());
    assertEquals(List.of(), calls.get("S_NOCALL").chromosomeAlleles());
  }

  @Test
  public void absentLocusIsEmptyNotAnError() {
    Path vcf = Paths.get("src/test/resources/variants/fixture.vcf.gz");
    try (MergedVcfReader reader = new MergedVcfReader(vcf)) {
      assertTrue(reader.read("chr1", 999).isEmpty());
    }
  }
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=MergedVcfReaderTest -DfailIfNoTests=false"'
```

Expected: compilation failure — `MergedVcfReader` does not exist.

- [ ] **Step 4: Implement `SampleCall` and `LocusCalls`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import java.util.List;

/**
 * One sample's call at one locus. A single row regardless of ploidy: a diploid
 * het collapses into an IUPAC ambiguity code in {@code allele}.
 *
 * @param allele            display form - IUPAC for a het. NOT for aggregating.
 * @param chromosomeAlleles one entry per chromosome slot, duplicates kept. This is
 *                          the aggregation weight; a diploid het has two entries.
 * @param readFrequency     support for the CALLED allele as a percentage string, or
 *                          null when unknown. See MergedVcfReader for the definition.
 */
public record SampleCall(
    String sampleName,
    String genotype,
    Integer depth,
    String allele,
    String readFrequency,
    List<String> aminoAcids,
    List<String> chromosomeAlleles,
    int ploidy,
    boolean noCall,
    boolean coverageFilled
) {}
```

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import java.util.List;

public record LocusCalls(
    String sequenceId,
    int position,
    String refAllele,
    List<String> altAlleles,
    CannIndex cann,
    List<SampleCall> calls
) {}
```

- [ ] **Step 5: Implement `MergedVcfReader`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import htsjdk.variant.variantcontext.Allele;
import htsjdk.variant.variantcontext.Genotype;
import htsjdk.variant.variantcontext.VariantContext;
import htsjdk.variant.vcf.VCFFileReader;

import java.io.File;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * Random access into the dnaseq pipeline's merged annotated VCF, by (sequence, position).
 *
 * Deliberately free of WDK types so it can be unit-tested against a fixture with no
 * database and no container, and so a future REST-backed consumer can use it directly.
 */
public class MergedVcfReader implements AutoCloseable {

  private static final Map<String, String> IUPAC = Map.of(
      "AC", "M", "AG", "R", "AT", "W", "CG", "S", "CT", "Y", "GT", "K");

  private final VCFFileReader _reader;

  public MergedVcfReader(Path vcfPath) {
    // requireIndex = true: streaming an 809MB file per page view is not a fallback.
    _reader = new VCFFileReader(new File(vcfPath.toString()), true);
  }

  public Optional<LocusCalls> read(String sequenceId, int position) {
    Iterator<VariantContext> it = _reader.query(sequenceId, position, position);
    if (!it.hasNext()) return Optional.empty();

    VariantContext vc = it.next();
    String ref = vc.getReference().getBaseString();
    List<String> alts = new ArrayList<>();
    for (Allele a : vc.getAlternateAlleles()) alts.add(a.getBaseString());

    CannIndex cann = CannIndex.parse(vc.getAttributeAsString("CANN", null));

    List<SampleCall> calls = new ArrayList<>();
    for (String sample : _reader.getFileHeader().getGenotypeSamples()) {
      calls.add(toCall(vc, vc.getGenotype(sample), sample, ref, cann));
    }
    return Optional.of(new LocusCalls(sequenceId, position, ref, alts, cann, calls));
  }

  private SampleCall toCall(VariantContext vc, Genotype g, String sample, String ref,
                            CannIndex cann) {
    // Null check FIRST: a no-call genotype must not be dereferenced below.
    if (g == null || g.isNoCall()) {
      return new SampleCall(sample, ".", null, "", null, List.of(), List.of(), 0, true, false);
    }

    Integer depth = g.hasDP() && g.getDP() >= 0 ? Integer.valueOf(g.getDP()) : null;

    // A coverage-filled reference call carries GT and DP only; every other FORMAT
    // field was written as '.' by fill_missing_coverage_gt. It is distinguishable
    // from a real reference call, which carries real RO/AO.
    int[] ro = intsOf(g.getExtendedAttribute("RO"));
    int[] ao = intsOf(g.getExtendedAttribute("AO"));
    boolean filled = g.isHomRef() && ro.length == 0 && ao.length == 0;

    return new SampleCall(
        sample,
        genotypeString(vc, g),
        depth,
        allele(g, ref),
        readFrequency(vc, g, ro, ao, filled),
        cann.aminoAcidsFor(asString(g.getExtendedAttribute("CA"))),
        chromosomeAlleles(g),
        g.getPloidy(),
        false,
        filled);
  }

  /** One entry per chromosome slot, duplicates kept — this is the aggregation weight. */
  private List<String> chromosomeAlleles(Genotype g) {
    List<String> out = new ArrayList<>();
    for (Allele a : g.getAlleles()) {
      if (a.isNoCall()) continue;
      out.add(a.getBaseString());
    }
    return out;
  }

  /** IUPAC for a het of two single-base alleles; otherwise the first non-ref allele. */
  private String allele(Genotype g, String ref) {
    List<String> bases = new ArrayList<>();
    for (Allele a : g.getAlleles()) {
      if (a.isNoCall()) continue;
      String s = a.getBaseString();
      if (!bases.contains(s)) bases.add(s);
    }
    if (bases.isEmpty()) return "";
    if (bases.size() == 1) return bases.get(0);

    if (bases.size() == 2 && bases.get(0).length() == 1 && bases.get(1).length() == 1) {
      String key = bases.get(0).compareTo(bases.get(1)) < 0
          ? bases.get(0) + bases.get(1)
          : bases.get(1) + bases.get(0);
      String iupac = IUPAC.get(key);
      if (iupac != null) return iupac;
    }
    for (String b : bases) if (!b.equals(ref)) return b;
    return bases.get(0);
  }

  private String readFrequency(VariantContext vc, Genotype g, int[] ro, int[] ao,
                               boolean filled) {
    if (filled) return "100.00";
    if (ro.length == 0 && ao.length == 0) return null;

    int refCount = ro.length > 0 ? ro[0] : 0;
    int altTotal = 0;
    for (int v : ao) altTotal += v;

    if (g.isHomRef()) {
      // Reference support is measured against ALL non-reference reads, so summing is right.
      int total = refCount + altTotal;
      return total <= 0 ? null
          : String.format(Locale.ROOT, "%.2f", refCount * 100.0 / total);
    }

    // Alt support must come from the entry for the allele THIS sample carries, not a sum
    // over every alt. The published file is biallelic (the pipeline emits one record per
    // alt), so this is defensive rather than hot - but a formula that is only accidentally
    // right is a trap. Fall back to the sum if the index is out of range rather than throw.
    int altCount = altTotal;
    for (Allele a : g.getAlleles()) {
      if (a.isNoCall() || a.isReference()) continue;
      int i = vc.getAlleleIndex(a) - 1;
      if (i >= 0 && i < ao.length) altCount = ao[i];
      break;
    }

    int total = refCount + altCount;
    return total <= 0 ? null
        : String.format(Locale.ROOT, "%.2f", altCount * 100.0 / total);
  }

  /**
   * The raw VCF genotype, e.g. "0", "0/1", "1|1". Indices come from the VariantContext,
   * which is the only thing that knows the locus's full allele ordering — deriving them
   * from the genotype's own alleles would misnumber a sample that carries only alt 2.
   */
  private String genotypeString(VariantContext vc, Genotype g) {
    StringBuilder sb = new StringBuilder();
    List<Allele> alleles = g.getAlleles();
    for (int i = 0; i < alleles.size(); i++) {
      if (i > 0) sb.append(g.isPhased() ? '|' : '/');
      Allele a = alleles.get(i);
      sb.append(a.isNoCall() ? "." : String.valueOf(vc.getAlleleIndex(a)));
    }
    return sb.toString();
  }

  private static String asString(Object o) {
    return o == null ? null : String.valueOf(o);
  }

  /** Parses a comma-separated integer FORMAT value; '.' and absent both yield empty. */
  private static int[] intsOf(Object raw) {
    String s = asString(raw);
    if (s == null || s.isEmpty() || ".".equals(s)) return new int[0];
    String[] parts = s.split(",");
    List<Integer> vals = new ArrayList<>();
    for (String p : parts) {
      if (p.isEmpty() || ".".equals(p)) continue;
      try { vals.add(Integer.valueOf(p.trim())); } catch (NumberFormatException ignored) { }
    }
    int[] out = new int[vals.size()];
    for (int i = 0; i < out.length; i++) out[i] = vals.get(i);
    return out;
  }

  @Override
  public void close() {
    _reader.close();
  }
}
```

- [ ] **Step 6: Run to verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=MergedVcfReaderTest -DfailIfNoTests=false"'
```

Expected: PASS, 7 tests.

- [ ] **Step 7: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/ \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/variants/MergedVcfReaderTest.java \
        WSFPlugin/src/test/resources/variants/
git commit -m "Read per-sample calls from the merged VCF by tabix seek

One row per sample regardless of ploidy - a diploid het collapses to an IUPAC
ambiguity code, matching processSequenceVariations.jl's gt_to_base.

Read frequency reports support for the CALLED allele, so a reference call shows
RO/(RO+AO) rather than the pipeline's alt-centric 0.0, and a coverage-filled
call (GT and DP only, every other FORMAT field '.') shows 100.

The fixture reproduces the real file's under-declared header on purpose."
```

---

## Task 4: `VariantLocusResolver` and `SampleMetadataLookup`

**Files:**
- Create: `.../variants/VariantLocusResolver.java`
- Create: `.../variants/SampleMetadataLookup.java`

No unit test: both are thin wrappers over SQL that cannot run without an appDb. They are
exercised end-to-end in Task 6. The SQL in both was verified against `genomicsdb_071n` on
2026-08-11 and returned `Pf3D7_01_v3|100057|Pfalciparum3D7|s3be28bbe14_sample` for
`Variant_Pf3D7_01_v3_100057`.

- [ ] **Step 1: Implement `VariantLocusResolver`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import org.gusdb.fgputil.db.SqlUtils;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;

import javax.sql.DataSource;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Optional;

/**
 * Resolves a Variant primary key to everything the VCF read needs: the tabix
 * coordinate, the organism's file-name form, and the EDA sample table suffix.
 *
 * The VCF path is derived from WdkModel properties rather than a WDK param. The HSSS
 * plugins take a WebServicesPath param whose internal value embeds PROJECT_GOES_HERE,
 * but that exists only because a search has a param form to hang it on; a record table
 * does not.
 */
public class VariantLocusResolver {

  public record Locus(String sequenceId, int position, String nameForFiles, String edaSuffix) {}

  private static final String SQL =
      "SELECT va.sequence_source_id, va.location, o.name_for_filenames, " +
      "       (SELECT DISTINCT s.internal_abbrev || '_' || lower(e.internal_abbrev) " +
      "          FROM apidb.datasource ds " +
      "          JOIN sres.externaldatabase ed ON ed.name = ds.name " +
      "          JOIN sres.externaldatabaserelease edr ON edr.external_database_id = ed.external_database_id " +
      "          JOIN eda.studyexternaldatabaserelease sedr ON sedr.external_database_release_id = edr.external_database_release_id " +
      "          JOIN eda.study s ON s.study_id = sedr.study_id " +
      "          JOIN eda.entitytypegraph e ON e.study_id = s.study_id " +
      "         WHERE ds.type = 'isolates' AND ds.subtype = 'Dna_Seq' " +
      "           AND ds.taxon_id = o.taxon_id AND s.internal_abbrev IS NOT NULL) AS eda_suffix " +
      "FROM ApidbTuning.VariationAttributes va " +
      "JOIN sres.taxonname tn ON tn.name = va.organism AND tn.name_class = 'scientific name' " +
      "JOIN apidb.organism o  ON o.taxon_id = tn.taxon_id " +
      "WHERE va.source_id = ?";

  private final WdkModel _wdkModel;

  public VariantLocusResolver(WdkModel wdkModel) {
    _wdkModel = wdkModel;
  }

  public Optional<Locus> resolve(String sourceId) throws WdkModelException {
    DataSource ds = _wdkModel.getAppDb().getDataSource();
    try (java.sql.Connection conn = ds.getConnection();
         PreparedStatement ps = conn.prepareStatement(SQL)) {
      ps.setString(1, sourceId);
      try (ResultSet rs = ps.executeQuery()) {
        if (!rs.next()) return Optional.empty();
        return Optional.of(new Locus(
            rs.getString(1), rs.getInt(2), rs.getString(3), rs.getString(4)));
      }
    }
    catch (SQLException e) {
      throw new WdkModelException("Could not resolve variant locus for " + sourceId, e);
    }
  }

  /**
   * ${WEBSERVICEMIRROR}/${projectId}/build-${buildNumber}/${nameForFiles}/dnaseq/vcf/merged.ann.vcf.gz
   * — the same three properties JBrowseService uses.
   */
  public Path vcfPath(Locus locus) {
    String mirror = _wdkModel.getProperties().get("WEBSERVICEMIRROR");
    return Paths.get(mirror,
        _wdkModel.getProjectId(),
        "build-" + _wdkModel.getBuildNumber(),
        locus.nameForFiles(),
        "dnaseq", "vcf", "merged.ann.vcf.gz");
  }
}
```

- [ ] **Step 2: Implement `SampleMetadataLookup`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;

import javax.sql.DataSource;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * EDA sample metadata for one dnaseq study.
 *
 * VCF sample names ARE EDA sample_stable_ids, so no mapping layer is needed - established
 * in 2026-08-05-hsss-variation-plumbing-design.md section 6.
 *
 * Keyed on provider_label rather than stable_id: EDA stable_ids are VAR_&lt;hash&gt; digests
 * of the provider label, stable per label but site-specific.
 */
public class SampleMetadataLookup {

  /** Verified: covers 536 of 537 Pf samples, against geographic_location's 111. */
  public static final String COUNTRY_LABEL = "[\"country\"]";

  private static final String SQL_TEMPLATE =
      "SELECT av.sample_stable_id, av.string_value " +
      "FROM eda.attributevalue_%1$s av " +
      "JOIN eda.attributegraph_%1$s ag ON ag.stable_id = av.attribute_stable_id " +
      "WHERE ag.provider_label = ? AND av.string_value IS NOT NULL";

  private final WdkModel _wdkModel;

  public SampleMetadataLookup(WdkModel wdkModel) {
    _wdkModel = wdkModel;
  }

  /**
   * sample_stable_id -&gt; value for one attribute. Returns an empty map when the study
   * has no such attribute at all, which is normal: 14 of the 62 dnaseq studies carry no
   * country attribute (lab lines and reference assemblies).
   */
  public Map<String, String> valuesBySample(String edaSuffix, String providerLabel)
      throws WdkModelException {
    // edaSuffix is not user input - it comes from apidb/eda catalogue tables via
    // VariantLocusResolver - but validate anyway, since it is interpolated as an identifier.
    if (edaSuffix == null || !edaSuffix.matches("[A-Za-z0-9_]+")) {
      throw new WdkModelException("Refusing to use unsafe EDA table suffix: " + edaSuffix);
    }

    Map<String, String> out = new LinkedHashMap<>();
    DataSource ds = _wdkModel.getAppDb().getDataSource();
    String sql = String.format(SQL_TEMPLATE, edaSuffix);

    try (java.sql.Connection conn = ds.getConnection();
         PreparedStatement ps = conn.prepareStatement(sql)) {
      ps.setString(1, providerLabel);
      try (ResultSet rs = ps.executeQuery()) {
        while (rs.next()) out.put(rs.getString(1), rs.getString(2));
      }
    }
    catch (SQLException e) {
      // A missing attributevalue_<suffix> table means this organism has no dnaseq EDA
      // study; an empty map is the correct answer, not a page error.
      return Map.of();
    }
    return out;
  }
}
```

- [ ] **Step 3: Compile**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && mvn -q -pl WSFPlugin compile"'
```

Expected: BUILD SUCCESS.

- [ ] **Step 4: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/
git commit -m "Resolve variant locus, VCF path and EDA sample metadata

The locus query returns sequence, position, name_for_filenames and the EDA
sample table suffix in one round trip; verified against genomicsdb_071n.

Metadata is keyed on provider_label ['country'], not the VAR_<hash> stable_id,
which is a digest of the label and therefore site-specific."
```

---

## Task 5: `VariantLocusComposer` — strain rows

**Files:**
- Create: `.../variants/StrainRow.java`, `.../variants/VariantLocusComposer.java`
- Test: `.../variants/VariantLocusComposerTest.java`

- [ ] **Step 1: Write the failing test**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import org.junit.Test;

import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.junit.Assert.assertEquals;

public class VariantLocusComposerTest {

  private static SampleCall call(String name, String gt, String allele, int ploidy,
                                 String freq, List<String> aas) {
    return new SampleCall(name, gt, 10, allele, freq, aas,
        Collections.nCopies(ploidy, allele), ploidy, false, false);
  }

  private static SampleCall noCall(String name) {
    return new SampleCall(name, ".", null, "", null, List.of(), List.of(), 0, true, false);
  }

  private static LocusCalls locus(List<SampleCall> calls) {
    return new LocusCalls("chr1", 100, "T", List.of("C"), CannIndex.parse("."), calls);
  }

  @Test
  public void strainRowsKeepEverySampleIncludingNoCalls() {
    LocusCalls l = locus(List.of(
        call("S1", "1", "C", 1, "80.00", List.of("A")),
        noCall("S2")));
    List<StrainRow> rows = new VariantLocusComposer()
        .strainRows(l, Map.of("S1", "Mali"));

    assertEquals(2, rows.size());
    assertEquals("Mali", rows.get(0).country());
    assertEquals("C", rows.get(0).allele());
    assertEquals("A", rows.get(0).aaProduct());

    assertEquals("No call", rows.get(1).genotype());
    assertEquals("", rows.get(1).allele());
    assertEquals("", rows.get(1).country());
  }

  @Test
  public void multipleTranscriptAminoAcidsAreCommaJoined() {
    LocusCalls l = locus(List.of(call("S1", "1", "C", 1, "80.00", List.of("A", "M"))));
    assertEquals("A, M",
        new VariantLocusComposer().strainRows(l, Map.of()).get(0).aaProduct());
  }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=VariantLocusComposerTest -DfailIfNoTests=false"'
```

Expected: compilation failure — `StrainRow` does not exist.

- [ ] **Step 3: Implement `StrainRow`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

public record StrainRow(
    String strain,
    String country,
    String genotype,
    String allele,
    String depth,
    String readFrequency,
    String aaProduct
) {}
```

- [ ] **Step 4: Implement `VariantLocusComposer.strainRows`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Joins per-sample VCF calls to EDA metadata and aggregates them.
 *
 * The join and the aggregation are done here, in Java, over ~537 rows per locus.
 * Both delivery surfaces (the two table plugins today, a REST endpoint later) consume
 * this class; nothing above it may reach into the VCF directly.
 */
public class VariantLocusComposer {

  public List<StrainRow> strainRows(LocusCalls locus, Map<String, String> countryBySample) {
    List<StrainRow> rows = new ArrayList<>();
    for (SampleCall c : locus.calls()) {
      String country = countryBySample.getOrDefault(c.sampleName(), "");
      if (c.noCall()) {
        // Present, not omitted: the record advertises no_call_strain_count, so a table
        // that hid these would contradict the overview panel above it.
        rows.add(new StrainRow(c.sampleName(), country, "No call", "", "", "", ""));
        continue;
      }
      rows.add(new StrainRow(
          c.sampleName(),
          country,
          c.genotype(),
          c.allele(),
          c.depth() == null ? "" : String.valueOf(c.depth()),
          c.readFrequency() == null ? "" : c.readFrequency(),
          String.join(", ", c.aminoAcids())));
    }
    return rows;
  }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=VariantLocusComposerTest -DfailIfNoTests=false"'
```

Expected: PASS, 2 tests.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/ \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/variants/VariantLocusComposerTest.java
git commit -m "Compose per-strain rows from VCF calls and EDA metadata

No-call samples get a row rather than being dropped - the record already
advertises no_call_strain_count, so omitting them would contradict the panel
above the table. A sample resolving to several transcripts' amino acids stays
on one row with the values comma-joined."
```

---

## Task 6: `VariantStrainsPlugin` and the model wiring for table A

**Files:**
- Create: `.../variants/VariantStrainsPlugin.java`
- Modify: `ApiCommonModel/Model/lib/wdk/model/records/variantTableQueries.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/records/variantRecords.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt`

- [ ] **Step 1: Implement the plugin**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.ArrayUtil;
import org.gusdb.fgputil.json.JsonUtil;
import org.gusdb.fgputil.runtime.InstanceManager;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wsf.plugin.AbstractPlugin;
import org.gusdb.wsf.plugin.DelayedResultException;
import org.gusdb.wsf.plugin.PluginModelException;
import org.gusdb.wsf.plugin.PluginRequest;
import org.gusdb.wsf.plugin.PluginResponse;
import org.gusdb.wsf.plugin.PluginUserException;
import org.json.JSONArray;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.gusdb.wdk.model.answer.single.SingleRecordQuestionParam.PRIMARY_KEY_PARAM_NAME;
import static org.gusdb.wdk.model.record.TableField.TABLE_NAME_PARAM_NAME;

/** One row per VCF sample at this variant's locus. */
public class VariantStrainsPlugin extends AbstractPlugin {

  private static final Logger LOG = Logger.getLogger(VariantStrainsPlugin.class);

  static final String[] DATA_COLUMNS =
      { "strain", "country", "genotype", "allele", "depth", "read_frequency", "aa_product" };

  @Override
  public String[] getRequiredParameterNames() {
    return new String[] { PRIMARY_KEY_PARAM_NAME, TABLE_NAME_PARAM_NAME };
  }

  @Override
  public String[] getColumns(PluginRequest request) throws PluginModelException {
    return ArrayUtil.concatenate(getPkColumnNames(request), DATA_COLUMNS);
  }

  @Override
  public void validateParameters(PluginRequest request) {
    // PK value has already been validated by the record service.
  }

  @Override
  protected int execute(PluginRequest request, PluginResponse response)
      throws PluginModelException, PluginUserException, DelayedResultException {

    String[] pkValues = JsonUtil.toStringArray(
        new JSONArray(request.getParams().get(PRIMARY_KEY_PARAM_NAME)));
    String sourceId = pkValues[0];

    WdkModel wdkModel = InstanceManager.getInstance(WdkModel.class, request.getProjectId());

    try {
      VariantLocusResolver resolver = new VariantLocusResolver(wdkModel);
      Optional<VariantLocusResolver.Locus> maybeLocus = resolver.resolve(sourceId);
      if (maybeLocus.isEmpty()) {
        LOG.warn("No locus row for variant " + sourceId + "; returning an empty table.");
        return 0;
      }
      VariantLocusResolver.Locus locus = maybeLocus.get();

      Path vcf = resolver.vcfPath(locus);
      if (!Files.exists(vcf)) {
        // Not every organism has a merged call set. Absence is normal and silent,
        // matching JbrowseOrgSpecificNaTracks.pm.
        LOG.info("No merged VCF at " + vcf + "; returning an empty table.");
        return 0;
      }

      Map<String, String> countries = new SampleMetadataLookup(wdkModel)
          .valuesBySample(locus.edaSuffix(), SampleMetadataLookup.COUNTRY_LABEL);

      try (MergedVcfReader reader = new MergedVcfReader(vcf)) {
        Optional<LocusCalls> calls = reader.read(locus.sequenceId(), locus.position());
        if (calls.isEmpty()) {
          LOG.warn("Variant " + sourceId + " is absent from " + vcf);
          return 0;
        }
        List<StrainRow> rows = new VariantLocusComposer().strainRows(calls.get(), countries);
        for (StrainRow r : rows) {
          response.addRow(ArrayUtil.concatenate(pkValues, new String[] {
              r.strain(), r.country(), r.genotype(), r.allele(),
              r.depth(), r.readFrequency(), r.aaProduct()
          }));
        }
      }
    }
    catch (WdkModelException e) {
      throw new PluginModelException("Could not build the strains table for " + sourceId, e);
    }
    return 0;
  }

  private String[] getPkColumnNames(PluginRequest request) {
    WdkModel wdkModel = InstanceManager.getInstance(WdkModel.class, request.getProjectId());
    String questionFullName = request.getContext().get(Utilities.CONTEXT_KEY_QUESTION_FULL_NAME);
    return wdkModel.getQuestionByFullName(questionFullName).orElseThrow()
        .getRecordClass().getPrimaryKeyDefinition().getColumnRefs();
  }
}
```

- [ ] **Step 2: Add the processQuery**

In `ApiCommonModel/Model/lib/wdk/model/records/variantTableQueries.xml`, inside the existing
`<querySet name="VariantTables" ...>`, before its closing `</querySet>`:

```xml
    <!-- Read straight from the dnaseq pipeline's merged annotated VCF at request time.
         Record-page table queries run UNCACHED (SingleRecordAnswerValue routes them to
         TableFieldProcessQueryResult.getUncachedResults), so this costs one tabix seek
         per page view and persists nothing. -->
    <processQuery name="VariantStrains"
                  processName="org.apidb.apicomplexa.wsfplugin.variants.VariantStrainsPlugin">
      <wsColumn name="source_id"      width="255"/>
      <wsColumn name="project_id"     width="255"/>
      <wsColumn name="strain"         width="255"/>
      <wsColumn name="country"        width="255"/>
      <wsColumn name="genotype"       width="60"/>
      <wsColumn name="allele"         width="255"/>
      <wsColumn name="depth"          width="30"/>
      <wsColumn name="read_frequency" width="30"/>
      <wsColumn name="aa_product"     width="255"/>
    </processQuery>
```

- [ ] **Step 3: Add the table to the record**

In `ApiCommonModel/Model/lib/wdk/model/records/variantRecords.xml`, immediately after the
closing `</table>` of `PredictedEffects` and before `</recordClass>`:

```xml
      <!-- One row per strain, read live from the merged VCF. A diploid het stays on ONE
           row as an IUPAC code rather than splitting into two, which is what the legacy
           SNP record did. -->
      <table name="VariantStrains" displayName="Strains / Samples"
             queryRef="VariantTables.VariantStrains">
        <columnAttribute name="strain"  displayName="Strain"/>
        <columnAttribute name="country" displayName="Country"/>
        <columnAttribute name="genotype" displayName="GT" align="center"
                         help="Raw VCF genotype: 0 is the reference allele, 1 the first
                               alternate. 'No call' means no sequencing coverage here."/>
        <columnAttribute name="allele" displayName="Allele" align="center"
                         help="The called allele. A heterozygous call of two single-base
                               alleles is shown as its IUPAC ambiguity code."/>
        <columnAttribute name="depth" displayName="Coverage" align="center"
                         help="Depth of aligned reads at this position for this strain."/>
        <columnAttribute name="read_frequency" displayName="Read Frequency" align="center"
                         help="Percentage of reads supporting the called allele. A call
                               inferred from coverage alone shows 100."/>
        <columnAttribute name="aa_product" displayName="Amino Acid" align="center"
                         help="Amino acid(s) this strain's allele produces. More than one
                               value means the locus sits in a multi-transcript gene; see
                               Variant Products by Transcript for the per-transcript detail."/>
      </table>
```

- [ ] **Step 4: Add the ontology row**

Append to `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt` immediately after the
`VariantRecordClasses.VariantRecordClass.PredictedEffects` line (currently line 1205). The file
is **tab-separated with 14 fields**; fields 7–12 are empty:

```
VariantRecordClasses.VariantRecordClass.VariantStrains	http://edamontology.org/topic_0199	Genetic Variation	VariantRecordClasses.VariantRecordClass	table	VariantStrains							record	download
```

Verify the field count before building:

```bash
cd ~/workspaces/plasmodb
awk -F'\t' '/VariantRecordClass.VariantStrains/{print NF}' ApiCommonModel/Model/lib/wdk/ontology/individuals.txt
```

Expected: `14`

- [ ] **Step 5: Build**

`wb full` because a Java plugin changed; `wb ontology` because `individuals.txt` changed. Run
`full` first, then `ontology`.

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-build.sh plasmodb wb full
bin/veup-build.sh plasmodb wb ontology
```

Expected: both complete without error, each ending in a webapp reload.

- [ ] **Step 6: Verify the table is registered**

```bash
bin/veup-logs.sh plasmodb mark strains-check
```

Then load `https://jbrestel.plasmodb.org/a/app/record/variation/Variant_Pf3D7_01_v3_100057`
in Claude Chrome and, from that authenticated page, run:

```javascript
fetch('/a/service/record-types/variation')
  .then(r => r.json())
  .then(d => console.log(JSON.stringify(d.tables.map(t => t.name))));
```

Expected: the list contains `VariantStrains`.

Then check the logs for a clean load:

```bash
bin/veup-logs.sh plasmodb since strains-check --quiet
```

Expected: error logs reported as `silent:`.

- [ ] **Step 7: Verify the rendered rows**

On the same page, confirm the "Strains / Samples" section shows 537 rows, that at least one row
has a non-empty Country, and that no-call rows read `No call`. Cross-check one strain against
the file:

```bash
ssh cedar 'V=/var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-71/Pfalciparum3D7/dnaseq/vcf/merged.ann.vcf.gz; \
  tabix $V Pf3D7_01_v3:100057-100057 | cut -f1-10'
```

Expected: the first sample's `GT:DP` matches the first row of the rendered table.

- [ ] **Step 8: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/VariantStrainsPlugin.java
git commit -m "Add the VariantStrains WSF plugin"

cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variantTableQueries.xml \
        Model/lib/wdk/model/records/variantRecords.xml \
        Model/lib/wdk/ontology/individuals.txt
git commit -m "Add the Strains / Samples table to the Variant record

Backed by a processQuery reading the merged VCF at request time. Record-page
table queries run uncached, so this persists nothing and needs no data load."
```

---

## Task 7: `VariantLocusComposer` — country aggregation

**Files:**
- Create: `.../variants/CountryRow.java`
- Modify: `.../variants/VariantLocusComposer.java`
- Modify: `.../variants/VariantLocusComposerTest.java`

### Frequency semantics

Ploidy-weighted, per `processSequenceVariations.jl:1820`: each sample contributes **one unit per
chromosome slot**, so a diploid het adds 1 to each of two alleles and the denominator is
`Σ ploidy`, not a sample count. Formatted `%.4f`.

The denominator is **that country's own chromosomes**, so each row is independently readable.
These frequencies therefore do not match the locus-wide `snp_major_allele_frequency` in the
overview panel, by design — see spec §7.

Ranking is `(-weight, allele)`; major is rank 1, minor rank 2, other rank 3.

- [ ] **Step 1: Write the failing test**

Append to `VariantLocusComposerTest.java`:

```java
  @Test
  public void countryRowsAreWeightedByChromosomeAndSortedByCount() {
    LocusCalls l = locus(List.of(
        call("S1", "1", "C", 1, "80.00", List.of("A")),
        call("S2", "0", "T", 1, "100.00", List.of("V")),
        call("S3", "0", "T", 1, "100.00", List.of("V")),
        call("S4", "1", "C", 1, "90.00", List.of("A"))));

    List<CountryRow> rows = new VariantLocusComposer().countryRows(l,
        Map.of("S1", "Mali", "S2", "Mali", "S3", "Mali", "S4", "Gambia"));

    assertEquals(2, rows.size());
    CountryRow mali = rows.get(0);
    assertEquals("Mali", mali.country());
    assertEquals(3, mali.strainCount());
    assertEquals("T (0.6667)", mali.majorAllele());
    assertEquals("C (0.3333)", mali.minorAllele());
    assertEquals("", mali.otherAllele());
  }

  @Test
  public void countryRowsExcludeSamplesWithNoCountryAndNoCalls() {
    LocusCalls l = locus(List.of(
        call("S1", "1", "C", 1, "80.00", List.of("A")),
        call("S2", "0", "T", 1, "100.00", List.of("V")),
        noCall("S3")));

    // S2 has no country; S3 is a no-call with one.
    List<CountryRow> rows = new VariantLocusComposer().countryRows(l,
        Map.of("S1", "Mali", "S3", "Mali"));

    assertEquals(1, rows.size());
    assertEquals(1, rows.get(0).strainCount());
    assertEquals("C (1.0000)", rows.get(0).majorAllele());
  }

  @Test
  public void diploidHetContributesOneUnitToEachAllele() {
    // allele() is the IUPAC display value; chromosomeAlleles() is what aggregation uses.
    LocusCalls l = locus(List.of(
        new SampleCall("S1", "0/1", 20, "Y", "50.00", List.of(),
            List.of("T", "C"), 2, false, false)));
    List<CountryRow> rows = new VariantLocusComposer()
        .countryRows(l, Map.of("S1", "Mali"));

    assertEquals(1, rows.size());
    assertEquals(1, rows.get(0).strainCount());
    // Two chromosomes, one T and one C -> 0.5 each.
    assertEquals("C (0.5000)", rows.get(0).majorAllele());
    assertEquals("T (0.5000)", rows.get(0).minorAllele());
  }

  @Test
  public void noCountryAttributeYieldsNoRows() {
    LocusCalls l = locus(List.of(call("S1", "1", "C", 1, "80.00", List.of("A"))));
    assertEquals(List.of(), new VariantLocusComposer().countryRows(l, Map.of()));
  }
```

`SampleCall.chromosomeAlleles()` already exists from Task 3 — aggregation must use it rather
than `allele()`, which is the IUPAC display form and would count a het as a single fictional
allele `Y`.

- [ ] **Step 2: Run to verify it fails**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=VariantLocusComposerTest -DfailIfNoTests=false"'
```

Expected: compilation failure — `CountryRow` does not exist.

- [ ] **Step 3: Implement `CountryRow`**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

public record CountryRow(
    String country,
    int strainCount,
    String majorAllele,
    String minorAllele,
    String otherAllele
) {}
```

- [ ] **Step 4: Implement `countryRows`**

Add to `VariantLocusComposer`:

```java
  /**
   * One row per country, over samples that HAVE a country. Samples without one are
   * excluded entirely, as is the reference strain, which has no collection site in EDA.
   *
   * Frequencies are ploidy-weighted (one unit per chromosome slot, denominator = the
   * country's own chromosome count) per processSequenceVariations.jl's
   * aggregate_locus_alleles. They therefore do NOT match the locus-wide
   * snp_major_allele_frequency in the overview panel; that is deliberate, and the column
   * help says so.
   */
  public List<CountryRow> countryRows(LocusCalls locus, Map<String, String> countryBySample) {
    Map<String, List<SampleCall>> byCountry = new LinkedHashMap<>();
    for (SampleCall c : locus.calls()) {
      if (c.noCall()) continue;
      String country = countryBySample.get(c.sampleName());
      if (country == null || country.isEmpty()) continue;
      byCountry.computeIfAbsent(country, k -> new ArrayList<>()).add(c);
    }

    List<CountryRow> rows = new ArrayList<>();
    for (Map.Entry<String, List<SampleCall>> e : byCountry.entrySet()) {
      List<SampleCall> calls = e.getValue();

      Map<String, Integer> weights = new LinkedHashMap<>();
      int total = 0;
      for (SampleCall c : calls) {
        for (String a : c.chromosomeAlleles()) {
          weights.merge(a, 1, Integer::sum);
          total++;
        }
      }
      if (total == 0) continue;

      final int denominator = total;
      List<String> ranked = new ArrayList<>(weights.keySet());
      ranked.sort((x, y) -> {
        int byWeight = Integer.compare(weights.get(y), weights.get(x));
        return byWeight != 0 ? byWeight : x.compareTo(y);   // deterministic tie-break
      });

      rows.add(new CountryRow(
          e.getKey(),
          calls.size(),
          formatted(ranked, weights, denominator, 0),
          formatted(ranked, weights, denominator, 1),
          formatted(ranked, weights, denominator, 2)));
    }

    rows.sort((a, b) -> Integer.compare(b.strainCount(), a.strainCount()));
    return rows;
  }

  private String formatted(List<String> ranked, Map<String, Integer> weights,
                           int denominator, int rank) {
    if (rank >= ranked.size()) return "";
    String allele = ranked.get(rank);
    return String.format(Locale.ROOT, "%s (%.4f)",
        allele, weights.get(allele) / (double) denominator);
  }
```

Add the imports `java.util.LinkedHashMap` and `java.util.Locale` to `VariantLocusComposer`.

- [ ] **Step 5: Run to verify it passes**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && \
  mvn -q -pl WSFPlugin test -Dtest=VariantLocusComposerTest,MergedVcfReaderTest -DfailIfNoTests=false"'
```

Expected: PASS, all tests in both classes.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/ \
        WSFPlugin/src/test/java/org/apidb/apicomplexa/wsfplugin/variants/
git commit -m "Aggregate per-country allele frequencies from the VCF

Ploidy-weighted per processSequenceVariations.jl: one unit per chromosome
slot, so a diploid het contributes to both alleles and the denominator is the
sum of ploidies rather than a sample count. Haploid P. falciparum makes the two
coincide; TriTryp and Fungi aneuploids do not.

The denominator is each country's own chromosomes, so a row reads on its own.
Samples with no country are excluded entirely."
```

---

## Task 8: `VariantCountrySummaryPlugin` and the model wiring for table B

**Files:**
- Create: `.../variants/VariantCountrySummaryPlugin.java`
- Modify: `variantTableQueries.xml`, `variantRecords.xml`, `individuals.txt`

- [ ] **Step 1: Implement the plugin**

```java
package org.apidb.apicomplexa.wsfplugin.variants;

import org.apache.log4j.Logger;
import org.gusdb.fgputil.ArrayUtil;
import org.gusdb.fgputil.json.JsonUtil;
import org.gusdb.fgputil.runtime.InstanceManager;
import org.gusdb.wdk.model.Utilities;
import org.gusdb.wdk.model.WdkModel;
import org.gusdb.wdk.model.WdkModelException;
import org.gusdb.wsf.plugin.AbstractPlugin;
import org.gusdb.wsf.plugin.DelayedResultException;
import org.gusdb.wsf.plugin.PluginModelException;
import org.gusdb.wsf.plugin.PluginRequest;
import org.gusdb.wsf.plugin.PluginResponse;
import org.gusdb.wsf.plugin.PluginUserException;
import org.json.JSONArray;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.gusdb.wdk.model.answer.single.SingleRecordQuestionParam.PRIMARY_KEY_PARAM_NAME;
import static org.gusdb.wdk.model.record.TableField.TABLE_NAME_PARAM_NAME;

/**
 * One row per country. Empty - not an error - when the organism's dnaseq study carries no
 * country attribute; 14 of the 62 dnaseq studies do not, all of them lab lines or
 * reference assemblies.
 */
public class VariantCountrySummaryPlugin extends AbstractPlugin {

  private static final Logger LOG = Logger.getLogger(VariantCountrySummaryPlugin.class);

  static final String[] DATA_COLUMNS =
      { "country", "strain_count", "major_allele", "minor_allele", "other_allele" };

  @Override
  public String[] getRequiredParameterNames() {
    return new String[] { PRIMARY_KEY_PARAM_NAME, TABLE_NAME_PARAM_NAME };
  }

  @Override
  public String[] getColumns(PluginRequest request) throws PluginModelException {
    return ArrayUtil.concatenate(getPkColumnNames(request), DATA_COLUMNS);
  }

  @Override
  public void validateParameters(PluginRequest request) {
    // PK value has already been validated by the record service.
  }

  @Override
  protected int execute(PluginRequest request, PluginResponse response)
      throws PluginModelException, PluginUserException, DelayedResultException {

    String[] pkValues = JsonUtil.toStringArray(
        new JSONArray(request.getParams().get(PRIMARY_KEY_PARAM_NAME)));
    String sourceId = pkValues[0];

    WdkModel wdkModel = InstanceManager.getInstance(WdkModel.class, request.getProjectId());

    try {
      VariantLocusResolver resolver = new VariantLocusResolver(wdkModel);
      Optional<VariantLocusResolver.Locus> maybeLocus = resolver.resolve(sourceId);
      if (maybeLocus.isEmpty()) return 0;
      VariantLocusResolver.Locus locus = maybeLocus.get();

      Path vcf = resolver.vcfPath(locus);
      if (!Files.exists(vcf)) {
        LOG.info("No merged VCF at " + vcf + "; returning an empty country summary.");
        return 0;
      }

      Map<String, String> countries = new SampleMetadataLookup(wdkModel)
          .valuesBySample(locus.edaSuffix(), SampleMetadataLookup.COUNTRY_LABEL);
      if (countries.isEmpty()) {
        LOG.info("Study " + locus.edaSuffix() + " has no country attribute; empty summary.");
        return 0;
      }

      try (MergedVcfReader reader = new MergedVcfReader(vcf)) {
        Optional<LocusCalls> calls = reader.read(locus.sequenceId(), locus.position());
        if (calls.isEmpty()) return 0;

        List<CountryRow> rows = new VariantLocusComposer().countryRows(calls.get(), countries);
        for (CountryRow r : rows) {
          response.addRow(ArrayUtil.concatenate(pkValues, new String[] {
              r.country(), String.valueOf(r.strainCount()),
              r.majorAllele(), r.minorAllele(), r.otherAllele()
          }));
        }
      }
    }
    catch (WdkModelException e) {
      throw new PluginModelException("Could not build the country summary for " + sourceId, e);
    }
    return 0;
  }

  private String[] getPkColumnNames(PluginRequest request) {
    WdkModel wdkModel = InstanceManager.getInstance(WdkModel.class, request.getProjectId());
    String questionFullName = request.getContext().get(Utilities.CONTEXT_KEY_QUESTION_FULL_NAME);
    return wdkModel.getQuestionByFullName(questionFullName).orElseThrow()
        .getRecordClass().getPrimaryKeyDefinition().getColumnRefs();
  }
}
```

- [ ] **Step 2: Add the processQuery**

In `variantTableQueries.xml`, after the `VariantStrains` processQuery:

```xml
    <processQuery name="VariantCountrySummary"
                  processName="org.apidb.apicomplexa.wsfplugin.variants.VariantCountrySummaryPlugin">
      <wsColumn name="source_id"    width="255"/>
      <wsColumn name="project_id"   width="255"/>
      <wsColumn name="country"      width="255"/>
      <wsColumn name="strain_count" width="30"/>
      <wsColumn name="major_allele" width="255"/>
      <wsColumn name="minor_allele" width="255"/>
      <wsColumn name="other_allele" width="255"/>
    </processQuery>
```

- [ ] **Step 3: Add the table to the record**

In `variantRecords.xml`, after the `VariantStrains` table:

```xml
      <!-- Only samples that HAVE a country appear. Frequencies use each country's own
           chromosome count as the denominator, so they deliberately differ from the
           locus-wide figures in the overview panel. -->
      <table name="VariantCountrySummary" displayName="Country Summary"
             queryRef="VariantTables.VariantCountrySummary">
        <columnAttribute name="country" displayName="Country"/>
        <columnAttribute name="strain_count" displayName="Strains" align="center"
                         help="Genotyped strains from this country. Strains with no country
                               recorded are not shown here, so these counts do not sum to the
                               record's Called Strain Count; the Strains / Samples table above
                               lists every strain, with an empty Country where none is known."/>
        <columnAttribute name="major_allele" displayName="Major Allele" align="center"
                         help="Most frequent allele within this country, with its frequency.
                               The denominator is this country's own chromosomes, so these
                               frequencies differ from the locus-wide values in the Overview."/>
        <columnAttribute name="minor_allele" displayName="Minor Allele" align="center"/>
        <columnAttribute name="other_allele" displayName="Other Allele" align="center"/>
      </table>
```

- [ ] **Step 4: Add the ontology row**

Append after the `VariantStrains` row in `individuals.txt` (tab-separated, 14 fields):

```
VariantRecordClasses.VariantRecordClass.VariantCountrySummary	http://edamontology.org/topic_0199	Genetic Variation	VariantRecordClasses.VariantRecordClass	table	VariantCountrySummary							record	download
```

Verify:

```bash
cd ~/workspaces/plasmodb
awk -F'\t' '/VariantRecordClass.VariantCountrySummary/{print NF}' ApiCommonModel/Model/lib/wdk/ontology/individuals.txt
```

Expected: `14`

- [ ] **Step 5: Build**

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-build.sh plasmodb wb full
bin/veup-build.sh plasmodb wb ontology
```

- [ ] **Step 6: Verify against the database**

Load the record page, then compare the rendered Mali row against SQL. Country counts for the
whole study (not this locus) are: Thailand 181, French Guiana 169, Senegal 70, Gambia 65,
Mali 23, Uganda 11.

```bash
timeout 120 psql -h localhost -p 5433 -d genomicsdb_071n -At -F'|' -c "
SELECT av.string_value, count(DISTINCT av.sample_stable_id)
FROM eda.attributevalue_s3be28bbe14_sample av
JOIN eda.attributegraph_s3be28bbe14_sample ag ON ag.stable_id = av.attribute_stable_id
WHERE ag.provider_label = '[\"country\"]'
GROUP BY 1 ORDER BY 2 DESC;"
```

Expected: each country's rendered Strains count is ≤ its total above (a locus may have no-calls),
and the frequencies in each row sum to approximately 1.0000.

- [ ] **Step 7: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/variants/VariantCountrySummaryPlugin.java
git commit -m "Add the VariantCountrySummary WSF plugin"

cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/records/variantTableQueries.xml \
        Model/lib/wdk/model/records/variantRecords.xml \
        Model/lib/wdk/ontology/individuals.txt
git commit -m "Add the Country Summary table to the Variant record"
```

---

## Task 9: The strain filter — model pieces

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/variantParams.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/variantQueries.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/variantQuestions.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/records/variantRecords.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt`

- [ ] **Step 1: Add the filterParam**

In `variantParams.xml`, after the `cnv_sample_meta` filterParam:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Samples for the Variant RECORD PAGE strain filter -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Points at SamplesMetadataByStudy, NOT the ...WithRef variant the three search
         filters use. WithRef synthesizes a row for the reference strain because HSSS
         carries it as strain id 1; here the filter selects VCF SAMPLES, and the reference
         is not a sample column in the merged VCF (3D7_WTSI, which is present, is a real
         resequenced isolate). Offering it would be an option with no corresponding row -
         the same reasoning cnv_sample_meta records.

         Deliberately NO minSelectedCount: selecting a single strain is meaningful here,
         unlike a polymorphism search. -->
    <filterParam name="variant_strain_meta"
                 metadataQueryRef="VariantVQ.SamplesMetadataByStudy"
                 backgroundQueryRef="VariantVQ.SamplesMetadataByStudy"
                 ontologyQueryRef="VariantVQ.SampleOntologyByStudy"
                 prompt="Strains"
                 dependedParamRef="organismParams.organismSinglePick,variantParams.eda_sample_table_suffix">
      <help>
        Select strains using their sample characteristics.
      </help>
    </filterParam>
```

- [ ] **Step 2: Add the no-op query that hosts the params**

In `variantQueries.xml`, add a new querySet at the end of the file, before `</wdkModel>`:

```xml
  <!-- A filterParam must live in a question, and a record page has no question. This
       query exists ONLY to host the params so the client can render the filter; it
       deliberately returns no rows. Mirrors the legacy SnpAlignment.SnpAlignmentForm
       (geneQueries.xml:6051), which is commented out along with the rest of the snp
       block and so cannot be reused. -->
  <querySet name="VariantAlignment" queryType="id" isCacheable="false" doNotTest="true">
    <sqlQuery name="VariantAlignmentForm"
              includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">
      <paramRef ref="organismParams.organismSinglePick" visible="false"/>
      <paramRef ref="variantParams.eda_sample_table_suffix"/>
      <paramRef ref="variantParams.variant_strain_meta"/>
      <column name="project_id"/>
      <column name="source_id"/>
      <sql>
        <![CDATA[
          SELECT '' as source_id, '' as project_id WHERE 1 = 0
        ]]>
      </sql>
    </sqlQuery>
  </querySet>
```

- [ ] **Step 3: Add the question**

In `variantQuestions.xml`, inside the existing `<questionSet name="VariantQuestions" ...>`:

```xml
    <!-- Hosts the record-page strain filter. Never run as a search; the client reads its
         parameter and renders FilterParamNew directly. -->
    <question name="VariantAlignmentForm"
              displayName="Select Strains"
              recordClassRef="VariantRecordClasses.VariantRecordClass"
              queryRef="VariantAlignment.VariantAlignmentForm">
      <description>
        <![CDATA[ Internal: hosts the strain filter shown on the Variant record page. ]]>
      </description>
    </question>
```

- [ ] **Step 4: Add the render anchor to the record**

In `variantRecords.xml`, after the `record_overview` textAttribute:

```xml
      <!-- Render anchor only. The client's RecordAttributeSection override replaces this
           attribute with the strain filter; the text is the organism the filter needs. -->
      <textAttribute name="variant_strain_form" displayName="Select Strains"
                     inReportMaker="false" sortable="false">
        <text><![CDATA[ $$organism_text$$ ]]></text>
      </textAttribute>
```

- [ ] **Step 5: Add ontology rows**

Append to `individuals.txt` (tab-separated, 14 fields):

```
VariantRecordClasses.VariantRecordClass.variant_strain_form	http://edamontology.org/topic_0199	Genetic Variation	VariantRecordClasses.VariantRecordClass	attribute	variant_strain_form							record	
```

Verify:

```bash
cd ~/workspaces/plasmodb
awk -F'\t' '/VariantRecordClass.variant_strain_form/{print NF}' ApiCommonModel/Model/lib/wdk/ontology/individuals.txt
```

Expected: `14`

- [ ] **Step 6: Build and verify the model loads**

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-build.sh plasmodb wb ontology
```

Expected: no `WdkModelException`. A filterParam whose depended params are not declared on its
queries fails **at model load**, so a successful build is the check.

Then from an authenticated app page:

```javascript
fetch('/a/service/record-types/variation/searches/VariantAlignmentForm')
  .then(r => r.json())
  .then(d => console.log(JSON.stringify(d.searchData.parameters.map(p => p.name))));
```

Expected: includes `variant_strain_meta`.

- [ ] **Step 7: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/variantParams.xml \
        Model/lib/wdk/model/questions/queries/variantQueries.xml \
        Model/lib/wdk/model/questions/variantQuestions.xml \
        Model/lib/wdk/model/records/variantRecords.xml \
        Model/lib/wdk/ontology/individuals.txt
git commit -m "Add the record-page strain filter's model pieces

A filterParam has to live in a question, so VariantAlignmentForm is a query
returning no rows whose only job is to host the params - the same device the
legacy SnpAlignmentForm used, rewritten here because the snp block is
unimported dead code.

Points at SamplesMetadataByStudy rather than the WithRef variant: this filter
selects VCF sample columns, and the reference strain is not one."
```

---

## Task 10: The strain filter — client

**Files (in the `web-monorepo` checkout on cedar, branched from `main`):**
- Create: `packages/sites/genomics-site/webapp/wdkCustomization/js/client/components/common/VariantStrainFilter.jsx`
- Create: `packages/sites/genomics-site/webapp/wdkCustomization/js/client/components/records/VariantRecordClasses.VariantRecordClass.jsx`
- Modify: `packages/sites/genomics-site/webapp/wdkCustomization/js/client/storeModules/Record.js`

- [ ] **Step 1: Bring the monorepo up on the instance**

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-mono.sh status plasmodb
bin/veup-mono.sh up plasmodb variant-strain-filter
```

The monorepo reaches the remote by **git**, not mutagen, so the branch must be pushed before
`up`. Note `rebuilder` refuses to run while the overlay is active; `veup-build.sh ... rebuild`
guards against this and will tell you to run `veup-mono.sh down` first.

- [ ] **Step 2: Create the filter component**

```jsx
import React from 'react';
import { connect } from 'react-redux';
import { get, pick } from 'lodash';
import { FilterParamNew } from '@veupathdb/wdk-client/lib/Components';
import { QuestionActions } from '@veupathdb/wdk-client/lib/Actions';

const headingStyle = {
  fontSize: '1.2em',
  fontWeight: 500,
  margin: '2rem 0 1rem',
};

const enhance = connect(({ question, globalData }) =>
  Object.assign(
    {
      questionState: get(question, ['questions', 'VariantAlignmentForm'], {}),
    },
    pick(globalData.config, 'projectId')
  )
);

export const VariantStrainFilter = enhance(function VariantStrainFilter(props) {
  let {
    dispatch,
    questionState: { questionStatus, question, paramValues, paramUIState },
  } = props;

  // Renders nothing until observeVariantStrainFilter has loaded the question. If the
  // epic does not fire, this section is silently blank - there is no error anywhere.
  if (questionStatus !== 'complete') return null;

  let searchName = question.urlSegment;
  let parameter = question.parametersByName.variant_strain_meta;
  let uiState = paramUIState.variant_strain_meta;
  let value = paramValues.variant_strain_meta;

  return (
    <div>
      <div style={headingStyle}>Select strains:</div>
      <FilterParamNew
        ctx={{ searchName, parameter, paramValues }}
        parameter={parameter}
        value={value}
        uiState={uiState}
        dispatch={dispatch}
        onParamValueChange={(newValue) => {
          dispatch(
            QuestionActions.updateParamValue({
              searchName,
              parameter,
              dependentParameters: [],
              paramValues,
              paramValue: newValue,
            })
          );
        }}
      />
    </div>
  );
});
```

- [ ] **Step 3: Create the record-class override**

```jsx
import React from 'react';
import { CollapsibleSection } from '@veupathdb/wdk-client/lib/Components';
import { VariantStrainFilter } from '../common/VariantStrainFilter';

export function RecordAttributeSection(props) {
  return props.attribute.name === 'variant_strain_form' ? (
    StrainFilterSection(props)
  ) : (
    <props.DefaultComponent {...props} />
  );
}

function StrainFilterSection(props) {
  return (
    <CollapsibleSection
      id={props.attribute.name}
      headerContent={props.attribute.displayName}
      isCollapsed={props.isCollapsed}
      onCollapsedChange={props.onCollapsedChange}
    >
      <VariantStrainFilter />
    </CollapsibleSection>
  );
}
```

- [ ] **Step 4: Add the loader epic**

In `storeModules/Record.js`, next to `observeSnpsAlignment` (around line 275), add:

```javascript
/**
 * Load filterParam data for the Variant record's strain filter.
 *
 * organismSinglePick is a depended param of the filter and a record page has no organism
 * picker, so it is seeded from the record's own organism_text.
 */
function observeVariantStrainFilter(action$) {
  return action$.pipe(
    filter((action) => action.type === RecordActions.RECORD_UPDATE),
    mergeMap((action) =>
      action.payload.record.recordClassName ===
      'VariantRecordClasses.VariantRecordClass'
        ? of(action.payload.record.attributes.organism_text)
        : EMPTY
    ),
    map((organismSinglePick) =>
      QuestionActions.updateActiveQuestion({
        searchName: 'VariantAlignmentForm',
        initialParamData: {
          organismSinglePick,
          variant_strain_meta: JSON.stringify({ filters: [] }),
        },
      })
    )
  );
}
```

Register it wherever `observeSnpsAlignment` is registered in the same file — find it with:

```bash
ssh cedar 'grep -n "observeSnpsAlignment" /var/www/jbrestel.plasmodb.org/project_home/web-monorepo/packages/sites/genomics-site/webapp/wdkCustomization/js/client/storeModules/Record.js'
```

and add `observeVariantStrainFilter` to the same combined-epic array.

- [ ] **Step 5: Build the client**

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-build.sh plasmodb wb site
```

- [ ] **Step 6: Verify in the browser**

Load `https://jbrestel.plasmodb.org/a/app/record/variation/Variant_Pf3D7_01_v3_100057` and
confirm a "Select Strains" section renders a filter tree with the EDA characteristics
(country, sex, collection date, …) and a strain count.

**If the section is blank**, the epic did not fire. Check the console for the dispatched
`updateActiveQuestion`, and confirm `record.recordClassName` matches
`VariantRecordClasses.VariantRecordClass` exactly — the component returns `null` silently
otherwise.

- [ ] **Step 7: Commit and push the monorepo branch**

```bash
ssh cedar 'cd /var/www/jbrestel.plasmodb.org/project_home/web-monorepo && git add packages/sites/genomics-site/webapp/wdkCustomization/js/client && \
  git commit -m "Render the Variant record strain filter

Ports the legacy SNP record's device: a placeholder textAttribute intercepted by
a RecordAttributeSection override, backed by a question that exists only to host
the filterParam, loaded by an epic that seeds organismSinglePick from the record.

The MSA submit target is deliberately omitted - SequenceRetrievalTool wiring is
a separate change." && git push'
```

- [ ] **Step 8: Take the overlay down**

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-mono.sh down plasmodb
```

---

## Task 11: Full-instance verification

- [ ] **Step 1: Reconcile remote git refs**

Commits made locally leave the remote's index stale, since mutagen carries files but not `.git`.

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-git-sync.sh plasmodb
```

Expected: every repo reports `ok`.

- [ ] **Step 2: Run the whole plugin test suite**

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
  cd \$PROJECT_HOME/ApiCommonWebService && mvn -q -pl WSFPlugin test"'
```

Expected: BUILD SUCCESS. `HtsjdkRealFileSpikeTest` is skipped without `-Dvariants.vcf`.

- [ ] **Step 3: Full build**

```bash
cd ~/workspaces/agentic-veupath-dev
bin/veup-build.sh plasmodb wb full
bin/veup-build.sh plasmodb wb ontology
```

- [ ] **Step 4: Check the category placement**

From an authenticated app page:

```javascript
fetch('/a/service/ontologies/Categories')
  .then(r => r.json())
  .then(d => {
    const hits = [];
    (function walk(n) {
      const p = n.properties || {};
      if ((p.name || []).some(v => v.includes('VariantStrains') || v.includes('VariantCountrySummary')))
        hits.push(p);
      (n.children || []).forEach(walk);
    })(d.tree);
    console.log(JSON.stringify(hits, null, 2));
  });
```

Expected: both tables appear, siblings of `TranscriptProducts` and `PredictedEffects`.

- [ ] **Step 5: Page-load log delta**

```bash
bin/veup-logs.sh plasmodb mark final-check
# load the record page in the browser, let it settle
bin/veup-logs.sh plasmodb since final-check --quiet
```

Expected: error logs `silent:`.

- [ ] **Step 6: Check an organism with no country attribute**

*P. vinckei* has a dnaseq study with no country attribute. Find a variant on it and confirm
the Country Summary renders empty rather than erroring:

```bash
timeout 120 psql -h localhost -p 5433 -d genomicsdb_071n -At -c "
SELECT source_id FROM ApidbTuning.VariationAttributes
WHERE organism LIKE 'Plasmodium vinckei%' LIMIT 1;"
```

Load that record. Expected: the Strains table populates, the Country Summary is empty, and the
error logs stay silent.

- [ ] **Step 7: Final commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git status --short
# expect a clean tree; if the ontology or XML changed during verification, commit it
```

---

## Deferred, deliberately

Per spec §12 — user-selectable metadata columns, user-driven aggregation, per-row checkbox
selection, wiring the filter to SequenceRetrievalTool, and strain sequence reconstruction for
MSA. The layering in Task 3–5 exists so a REST-backed interactive section can consume
`VariantLocusComposer` later without a rewrite.
