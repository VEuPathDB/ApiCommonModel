# `VariationsByLocation` + `VariationsByGeneIds` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two region-restricted HSSS variation searches — by genomic location and by gene list — reusing the param machinery already built for `VariationsByIsolateGroup`.

**Architecture:** One constant renamed in `ApiCommonWebService`; in `ApiCommonModel`, one new chromosome param plus its vocabulary query, two `processQuery`s, two questions, two category-ontology rows. Everything else is reused verbatim. The design is `docs/superpowers/specs/2026-08-05-variations-by-location-and-gene-ids-design.md` — read it; this plan implements it and does not restate its reasoning.

**Tech Stack:** WDK model XML; Java (one string constant); PostgreSQL (`unidb_shu_a`); the `agentic-veupath-dev` control plane for remote builds on `cedar`; Claude in Chrome for verification.

---

## Orientation

Read this before Task 1 even if you implemented the previous search — two items are new.

**Repos.** This work spans two, both on branch **`dnaseq-merge-experiments`**, never `main`:

| | |
|---|---|
| `~/workspaces/plasmodb/ApiCommonWebService` | Task 1 only (one Java constant) |
| `~/workspaces/plasmodb/ApiCommonModel` | Tasks 2–5 |
| `~/workspaces/agentic-veupath-dev` | control plane — run `bin/veup-*.sh` from **here** |

Local edits reach `cedar` through a running `mutagen` sync. You never copy files. Builds run remotely.

**There is no unit-test framework for WDK model XML.** Don't look for one. Verification is `psql` for SQL, a one-second `ElementTree` parse for well-formedness, a remote build for reference resolution, and `wdkXml` to prove presence in the *assembled* model rather than in a file.

```bash
psql -h localhost -p 5432 -d unidb_shu_a          # read-only; every query here is a SELECT
```

> **Never** `INSERT`/`UPDATE`/`DELETE`/`ALTER` or touch an index in any schema but `jbrestel`.

**Five traps, all of which have already cost time on this feature:**

1. **Flags go BEFORE the profile name.** `bin/veup-build.sh plasmodb wb model --dry-run` silently drops the flag **and runs for real**. A real dry run prints `DRYRUN:`-prefixed lines.
2. **XML forbids `--` inside `<!-- -->`.** Every comment below is checked. If you reword one, keep double hyphens out or the file will not parse. Text inside `<![CDATA[ ]]>` is exempt.
3. **`wdkXml` prints attributes single-quoted** (`name='x'`). A double-quoted grep pattern matches nothing regardless of what the model contains.
4. **`dynamicAttributes` is mandatory** on any question whose `attributesList` names a `processQuery`'s `wsColumn`s. Both questions here need one. Omitting it fails the build with `Summary attribute field [PercentMinorAlleles] ... is invalid`.
5. **A remote grep for a `$`-containing pattern gets expanded by the remote shell** unless single-quoted on the remote side. Use `ssh host "... '\$foo' ..."`.

**Do not "fix" the `No Match` guard.** `FindPolymorphismsWithSeqFilterPlugin` contains `if (seq.contains("No Match")) seq = chromosome;`, which looks like dead code. It is live: `sharedParams.sequenceId` has twelve per-project `<suggest>` children each carrying `allowEmpty="true" emptyValue="No Match"`, and WDK substitutes that literal for an empty box. Design §4.3. Leave it exactly as it is.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `ApiCommonWebService/.../FindPolymorphismsWithSeqFilterPlugin.java:17` | Modify | the chromosome param name contract (Task 1) |
| `ApiCommonModel/Model/lib/wdk/model/questions/params/variationParams.xml` | Add 1 query to `VariationVQ`, 1 param to `variationParams` | the chromosome param (Task 2) |
| `ApiCommonModel/Model/lib/wdk/model/questions/queries/variationQueries.xml` | Add 2 `processQuery`s | plugin bindings (Tasks 3, 4) |
| `ApiCommonModel/Model/lib/wdk/model/questions/variationQuestions.xml` | Add 2 questions | the user-facing searches (Tasks 3, 4) |
| `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt` | Append 2 rows | category placement (Task 5) |

---

### Task 1: Rename the chromosome param constant in `ApiCommonWebService`

**Files:**
- Modify: `WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindPolymorphismsWithSeqFilterPlugin.java:17`

- [ ] **Step 1: Confirm you are changing exactly one of the two `PARAM_CHROMOSOME` declarations**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git branch --show-current
grep -rn "PARAM_CHROMOSOME =" WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/
```

Expected: branch `dnaseq-merge-experiments`, and exactly two declarations:

```
FindChipPolymorphismsWithSeqFilterPlugin.java:20:  ... PARAM_CHROMOSOME = "chromosomeOptional";
FindPolymorphismsWithSeqFilterPlugin.java:17:     ... PARAM_CHROMOSOME = "chromosomeOptionalForNgsSnps";
```

**Only the second changes.** The chip plugin uses `chromosomeOptional`, a different param serving live chip-snp searches; touching it would break them.

- [ ] **Step 2: Make the change**

`FindPolymorphismsWithSeqFilterPlugin.java` line 17:

```java
  public static final String PARAM_CHROMOSOME = "chromosomeOptionalForVariations";
```

Change nothing else in the file. In particular leave line 44's
`if (seq.contains("No Match")) seq = chromosome;` untouched — see Orientation.

- [ ] **Step 3: Verify the diff is one line**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService && git diff --stat && git diff
```

Expected: `1 file changed, 1 insertion(+), 1 deletion(-)`, showing only the string literal change.

- [ ] **Step 4: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindPolymorphismsWithSeqFilterPlugin.java
git commit -m "Rename the chromosome param contract for variation searches

FindPolymorphismsWithSeqFilterPlugin serves VariationsByLocation now. Its
sibling contract, the strain filter, was already renamed to
variation_sample_meta; leaving this one as chromosomeOptionalForNgsSnps would
give a single processQuery two differently-named eras of the same plugin and
invite the next reader to re-derive that the snp name is meaningless.

The chip plugin's own PARAM_CHROMOSOME (chromosomeOptional) is untouched: it
serves live chip-snp searches."
```

- [ ] **Step 5: Build and install**

```bash
cd ~/workspaces/agentic-veupath-dev && \
  ssh -o LogLevel=ERROR "$(python3 bin/resolve.py --profile profiles/plasmodb.yml --field host)" \
  "bash -lc 'source /var/www/jbrestel.plasmodb.org/etc/setenv && bld ApiCommonWebService'"
```

Expected: `BUILD SUCCESSFUL` (roughly 1–2 minutes). `Test-Installation` is not in the default
depends list, so the non-compiling JUnit module is not built.

- [ ] **Step 6: Reload, and confirm the new name reached the installed jar**

WSF plugins are loaded by the webapp; the constant does not take effect until a reload.

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb reload
```

Expected: `OK - Reloaded application at context path [/plasmo.jbrestel]`.

```bash
ssh cedar "bash -lc 'cd /var/www/PlasmoDB/plasmo.jbrestel/webapp/WEB-INF/lib && \
  for j in *.jar; do unzip -p \$j org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindPolymorphismsWithSeqFilterPlugin.class 2>/dev/null | \
  strings | grep -l chromosomeOptionalForVariations >/dev/null && echo \$j; done'" 2>/dev/null
```

Expected: at least one jar name printed. If nothing prints, try the simpler form below; the
point is to confirm the *installed* class carries the new string, not just the source tree.

```bash
ssh cedar "bash -lc 'grep -rl chromosomeOptionalForVariations /var/www/PlasmoDB/plasmo.jbrestel/webapp/WEB-INF/lib/ 2>/dev/null | head'"
```

Expected: one or more jar paths. **A pass here is what makes Task 6 meaningful** — with the old
string installed, the search fails at run time with a missing-required-parameter error and the
model looks wrong when it is not.

---

### Task 2: The chromosome param and its vocabulary

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/variationParams.xml`

- [ ] **Step 1: Run the vocabulary SQL — this is the test**

The model substitutes the organism param at run time; run it with the value inlined:

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
SELECT * FROM (
    SELECT DISTINCT s.chromosome AS term,
                    s.source_id  AS internal,
                    s.chromosome_order_num
    FROM webready.GenomicSeqAttributes_p s
    WHERE s.organism = 'Plasmodium falciparum 3D7'
      AND s.chromosome IS NOT NULL
  UNION
    SELECT 'Choose chromosome' AS term, 'choose' AS internal, -1 AS chromosome_order_num
) t
ORDER BY chromosome_order_num"
```

Expected: **15 rows** — the sentinel first (`chromosome_order_num = -1`), then `01` through `14`
with internals `Pf3D7_01_v3` … `Pf3D7_14_v3`.

The `internal` values are the load-bearing part: `Pf3D7_01_v3` is exactly the sequence
identifier the HSSS files carry (the live `ByIsolateGroup` run returned
`Variant_Pf3D7_01_v3_1`), so the value feeds the position filter with no mapping.

- [ ] **Step 2: Confirm why the predicate is `organism` and not `org_abbrev`**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
SELECT count(*) FROM webready.GenomicSeqAttributes_p
WHERE org_abbrev = 'Plasmodium falciparum 3D7'"
```

Expected: `0`. The snp original keyed on `org_abbrev`, but our organism param carries the
**taxon name** because the HSSS plugin resolves it through `sres.TaxonName` to build the
webservices path. That zero is why the column changed.

- [ ] **Step 3: Add the vocabulary query**

In `variationParams.xml`, inside the existing `VariationVQ` querySet, after
`SampleOntologyByStudy`:

```xml
    <!-- Chromosome vocabulary for the by-location search. Rewritten rather than
         reused: the snp original (SharedVQ.ChromosomeForNgsSnps) overrides the
         organism param to organismVQ.withNgsSNPs, which reads apidbtuning.snpstrains
         and does not exist in this build, and its SQL keys on org_abbrev while our
         organism param carries the taxon name (see the design doc, sections 3 and
         4.2). Keying on organism forfeits partition pruning on this LIST-partitioned
         table; measured at 26ms, which is well inside what a vocabulary needs.

         internal is the sequence source_id, which is what the HSSS files use, so the
         chosen chromosome feeds the position filter directly.

         The 'Choose chromosome' sentinel is deliberate: it gives "no chromosome
         picked" a real value rather than an empty param. -->
    <sqlQuery name="ChromosomeForVariations" doNotTest="1">
      <paramRef ref="organismParams.organismSinglePick" noTranslation="true"/>
      <column name="internal"/>
      <column name="term"/>
      <sql>
        <![CDATA[
          SELECT * FROM (
              SELECT DISTINCT s.chromosome AS term,
                              s.source_id  AS internal,
                              s.chromosome_order_num
              FROM webready.GenomicSeqAttributes_p s
              WHERE s.organism = '$$organismSinglePick$$'
                AND s.chromosome IS NOT NULL
            UNION
              SELECT 'Choose chromosome' AS term, 'choose' AS internal, -1 AS chromosome_order_num
          ) t
          ORDER BY chromosome_order_num
        ]]>
      </sql>
    </sqlQuery>
```

`noTranslation="true"` passes the organism param's **term** rather than its internal, matching
`EdaSampleTableSuffix` and the snp-era precedent. The SQL supplies the quotes.

Note the query declares only `internal` and `term` as columns even though the SQL selects
`chromosome_order_num` — that third column exists solely to drive `ORDER BY`, and the snp
original did the same.

- [ ] **Step 4: Add the param**

Inside the `variationParams` paramSet, after `MinPercentIsolateCalls`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Chromosome (by-location search) -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- The name is a CONTRACT with the Java plugin:
         FindPolymorphismsWithSeqFilterPlugin.PARAM_CHROMOSOME returns exactly this
         string and lists it among the plugin's required params. It lives here rather
         than in sharedParams because only variation searches use it.

         This is the fallback when the user leaves the Genomic sequence ID box empty.
         That handoff is not obvious from either side: sharedParams.sequenceId carries
         allowEmpty plus emptyValue="No Match" on each of its twelve per-project
         suggest elements, and the plugin tests seq.contains("No Match"). Do not
         "simplify" either half. See the design doc, section 4.3. -->
    <flatVocabParam name="chromosomeOptionalForVariations"
                    queryRef="VariationVQ.ChromosomeForVariations"
                    prompt="Chromosome"
                    multiPick="false"
                    quote="true"
                    dependedParamRef="organismParams.organismSinglePick">
      <help>
        <![CDATA[
          Select a chromosome. Used when you leave the Genomic sequence ID box empty;
          a sequence ID you type takes precedence.
        ]]>
      </help>
    </flatVocabParam>
```

- [ ] **Step 5: Verify the XML parses and the pieces landed in the right containers**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && python3 - <<'PY'
import xml.etree.ElementTree as T
r = T.parse('Model/lib/wdk/model/questions/params/variationParams.xml').getroot()
for ps in r.findall('paramSet'):
    print('paramSet', ps.get('name'), [(c.tag, c.get('name')) for c in ps])
for qs in r.findall('querySet'):
    print('querySet', qs.get('name'), [q.get('name') for q in qs.findall('sqlQuery')])
PY
```

Expected: `variationParams` now lists `variation_id`, `eda_sample_table_suffix`,
`variation_sample_meta`, `WebServicesPath`, `ReadFrequencyPercent`, `MinPercentMinorAlleles`,
`MinPercentIsolateCalls`, `chromosomeOptionalForVariations`; and `VariationVQ` lists
`EdaSampleTableSuffix`, `SamplesMetadataByStudy`, `SampleOntologyByStudy`,
`ChromosomeForVariations`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/variationParams.xml
git commit -m "Add chromosomeOptionalForVariations param and its vocabulary

Rewritten, not reused. The snp original's vocabulary reaches
organismVQ.withNgsSNPs, which reads the nonexistent apidbtuning.snpstrains,
and keys on org_abbrev while our organism param carries the taxon name (0 rows
if you try it). Keyed on organism instead: 15 rows in 26ms.

internal is the sequence source_id (chromosome 01 gives Pf3D7_01_v3), which is
the identifier the HSSS files use, so the value feeds the position filter with
no mapping layer."
```

---

### Task 3: `VariationsByLocation` — query, question, build

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/variationQueries.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/variationQuestions.xml`

- [ ] **Step 1: Confirm the plugin's required params before wiring to them**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
sed -n '15,35p' WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindPolymorphismsWithSeqFilterPlugin.java
```

Expected: `PARAM_CHROMOSOME = "chromosomeOptionalForVariations"` (Task 1's change), and
`getExtraParamNames()` returning all four of chromosome, sequence, start point, end point.
All four are **required** — none may be omitted from the `processQuery`.

- [ ] **Step 2: Add the process query**

In `variationQueries.xml`, inside the `VariationsBy` querySet, after
`VariationsByIsolateGroup`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations in a genomic region, within a group of samples -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Same computation as VariationsByIsolateGroup, restricted to a region. The
         plugin appends sequence, start and end to the generated bash script's args.

         All four of chromosome, sequenceId, start_point and end_point are required
         by the plugin. sequenceId wins when non-empty; the chromosome dropdown is the
         fallback, reached because sequenceId's suggest elements set
         emptyValue="No Match" and the plugin tests for that literal. end_point of 0
         means "to the end of the sequence"; the plugin maps it to 1000000000.

         The wsColumn set is fixed by the plugin, not chosen. -->
    <processQuery name="VariationsByLocation"
                  processName="org.apidb.apicomplexa.wsfplugin.highspeedsnpsearch.FindPolymorphismsWithSeqFilterPlugin">

      <paramRef ref="organismParams.organismSinglePick" prompt="Organism"
                displayType="treeBox" quote="false"
                queryRef="organismVQ.withVariationsTree">
        <help>The Organism defines the species identity of the samples and the genome
        against which each sample's variants were called.</help>
      </paramRef>
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <paramRef ref="variationParams.chromosomeOptionalForVariations" multiPick="false"/>
      <paramRef ref="sharedParams.sequenceId"/>
      <paramRef ref="sharedParams.start_point"/>
      <paramRef ref="sharedParams.end_point"/>
      <paramRef ref="variationParams.variation_sample_meta" prompt="Samples"/>
      <paramRef ref="variationParams.WebServicesPath"/>
      <paramRef ref="variationParams.ReadFrequencyPercent"/>
      <paramRef ref="variationParams.MinPercentMinorAlleles"/>
      <paramRef ref="variationParams.MinPercentIsolateCalls"/>

      <wsColumn name="source_id" width="60" wsName="SourceId"/>
      <wsColumn name="project_id" width="20" wsName="ProjectId"/>
      <!-- width 8 so the display keeps xx.x precision -->
      <wsColumn name="PercentMinorAlleles" width="8" columnType="float"/>
      <wsColumn name="PercentIsolateCalls" width="8" columnType="float"/>
      <wsColumn name="Phenotype" width="15"/>
    </processQuery>
```

- [ ] **Step 3: Add the question**

In `variationQuestions.xml`, inside the `VariationQuestions` questionSet, after
`VariationsByIsolateGroup`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations in a genomic region -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <question name="VariationsByLocation"
              displayName="Genomic Location"
              shortDisplayName="Location"
              queryRef="VariationsBy.VariationsByLocation"
              recordClassRef="VariationRecordClasses.VariationRecordClass">

      <attributesList
        summary="variation_location,gene_ids,variant_type,PercentMinorAlleles,PercentIsolateCalls,Phenotype"/>

      <summary>
        <![CDATA[
          Find variants in a specified genomic region that differ within a group of
          samples, with an option to specify minor allele frequency.
        ]]>
      </summary>

      <description>
        <![CDATA[
          This search analyzes whole genome sequencing data from a group of samples to
          find variants associated with the group, and returns only those contained in
          the genomic region you specify.<br><br>

          Each sample's sequencing reads are aligned to the reference genome (Organism)
          and variants are recorded for each sample based on the Read Frequency
          Threshold. Then, scanning variant locations within your region across the
          group of samples, variants are returned if the Minor Allele Frequency and the
          Percent samples with a base call are met.

          <p><b>Defining the region:</b> Either choose a Chromosome, or enter a Genomic
          sequence ID. A sequence ID you enter takes precedence; the Chromosome menu is
          used when you leave the sequence box empty. Start and End restrict the region
          further, and an End of 0 means "to the end of the sequence".</p>

          <p><b>Organism:</b> The Organism parameter defines the species of the samples
          and the genome in which the variants are determined. Choosing an Organism
          focuses the Samples parameter to the samples of that organism.</p>

          <p><b>Samples:</b> By default the group includes all samples from the Organism
          you chose; you may narrow it using the sample characteristics. At least two
          samples are required, since polymorphism within a group of one is undefined.</p>

          <p><b>Read frequency threshold:</b> An allele is called for a sample at a
          location if that fraction of the sample's aligned reads support it. This
          matters most for diploid or aneuploid organisms, where heterozygous positions
          are expected near 50%.</p>

          <p><b>Minor allele frequency:</b> Among the qualifying calls at a location,
          the minor allele frequency is the percent that are not the major allele. Use 0
          to find every variant location within the group.</p>

          <p><b>Percent samples with a base call:</b> A location is only considered if
          this fraction of your selected samples have a qualifying call there.</p>
        ]]>
      </description>

      <!-- REQUIRED: attributesList cannot name a processQuery's wsColumns until they
           are declared here. Without this block the build fails with "Summary
           attribute field [PercentMinorAlleles] ... is invalid". -->
      <dynamicAttributes>
        <columnAttribute name="PercentMinorAlleles" displayName="% Minor Alleles" align="center"
          help="Percent of minor alleles for this group of samples at this variant location (where 'minor allele' means any allele that is not the major allele).">
          <reporter name="histogram" displayName="Histogram" scopes=""
            implementation="org.gusdb.wdk.model.report.reporter.HistogramAttributeReporter">
            <description>Display the histogram of the values of this attribute</description>
            <property name="type">int</property>
          </reporter>
        </columnAttribute>
        <columnAttribute name="PercentIsolateCalls" displayName="% Calls" align="center"
          help="Percent of the samples at this variant location from the specified group that have read calls (over the threshold specified in the search)">
          <reporter name="histogram" displayName="Histogram" scopes=""
            implementation="org.gusdb.wdk.model.report.reporter.HistogramAttributeReporter">
            <description>Display the histogram of the values of this attribute</description>
            <property name="type">int</property>
          </reporter>
        </columnAttribute>
        <columnAttribute name="Phenotype" align="center"
          help="1 = this variant is within a gene and there is at least one sample in this set that has an allele with product that is non-synonymous with the most popular allele"/>
      </dynamicAttributes>

    </question>
```

- [ ] **Step 4: Verify both files parse**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && for f in \
  Model/lib/wdk/model/questions/queries/variationQueries.xml \
  Model/lib/wdk/model/questions/variationQuestions.xml; do
  python3 -c "import xml.etree.ElementTree as T,sys; T.parse('$f'); print('$f parses')"
done
```

Expected: both print `parses`.

- [ ] **Step 5: Build and confirm the search is in the assembled model**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: completes with no `WdkModelException`.

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"' \
  | grep -E "VariationsBy.VariationsByLocation:"
```

Expected: one line listing the query's params and columns — `organismSinglePick`,
`eda_sample_table_suffix`, `chromosomeOptionalForVariations`, `sequenceId`, `start_point`,
`end_point`, `variation_sample_meta`, `WebServicesPath`, `ReadFrequencyPercent`,
`MinPercentMinorAlleles`, `MinPercentIsolateCalls`, and columns `source_id, project_id,
PercentMinorAlleles, PercentIsolateCalls, Phenotype`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/variationQueries.xml \
        Model/lib/wdk/model/questions/variationQuestions.xml
git commit -m "Add the VariationsByLocation search

Reuses every param from VariationsByIsolateGroup and adds the region
restriction: chromosome (fallback), sequenceId (takes precedence), start and
end. All four are required by FindPolymorphismsWithSeqFilterPlugin.

The chromosome fallback works through sequenceId's emptyValue='No Match',
which the plugin tests for by literal; documented in the query comment because
it reads as dead code from either side alone."
```

---

### Task 4: `VariationsByGeneIds` — query, question, build

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/variationQueries.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/variationQuestions.xml`

- [ ] **Step 1: Confirm the plugin's gene-resolution SQL still works against this build**

The plugin resolves your gene list to genomic intervals itself. Check the table it uses, and
record the interval you will assert against in Task 6:

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
SELECT source_id, sequence_id, start_min, end_max
FROM webready.GeneAttributes_p WHERE source_id = 'PF3D7_1133400'"
```

Expected: `PF3D7_1133400 | Pf3D7_11_v3 | 1292966 | 1296696`. If `webready.geneattributes_p`
did not exist, this search could not work at all and the plan would need revisiting.

- [ ] **Step 2: Add the process query**

In `variationQueries.xml`, inside the `VariationsBy` querySet, after `VariationsByLocation`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations in a set of genes, within a group of samples -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- No gene-to-variation join is needed in the model. The plugin resolves the
         gene list to genomic intervals itself, via webready.GeneAttributes_p, writes
         them to genomicLocations.txt, and HSSS filters variant positions by interval
         using hsssGenomicLocationsFilter. The relationship is positional;
         apidb.VariationTranscriptProduct plays no part. See the design doc, 6.2.

         The plugin overrides the generate script to
         hsssGenerateGenomicLocationsScript and appends the locations filename to the
         command. The wsColumn set is fixed by the plugin. -->
    <processQuery name="VariationsByGeneIds"
                  processName="org.apidb.apicomplexa.wsfplugin.highspeedsnpsearch.FindSnpsByGeneIdsPlugin">

      <paramRef ref="organismParams.organismSinglePick" prompt="Organism"
                displayType="treeBox" quote="false"
                queryRef="organismVQ.withVariationsTree">
        <help>The Organism defines the species identity of the samples and the genome
        against which each sample's variants were called.</help>
      </paramRef>
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <!-- Defaults only for the projects with variation data loaded today; the rest
           owe one when their data lands, omitted rather than invented. -->
      <paramRef ref="sharedParams.ds_gene_ids" default="PF3D7_1133400"  includeProjects="PlasmoDB,UniDB"/>
      <paramRef ref="sharedParams.ds_gene_ids" default="TcCLB.403869.10" includeProjects="TriTrypDB"/>
      <paramRef ref="sharedParams.ds_gene_ids" default="Afu2g00910"      includeProjects="FungiDB"/>
      <paramRef ref="variationParams.variation_sample_meta" prompt="Samples"/>
      <paramRef ref="variationParams.WebServicesPath"/>
      <paramRef ref="variationParams.ReadFrequencyPercent"/>
      <paramRef ref="variationParams.MinPercentMinorAlleles"/>
      <paramRef ref="variationParams.MinPercentIsolateCalls"/>

      <wsColumn name="source_id" width="60" wsName="SourceId"/>
      <wsColumn name="project_id" width="20" wsName="ProjectId"/>
      <wsColumn name="PercentMinorAlleles" width="8" columnType="float"/>
      <wsColumn name="PercentIsolateCalls" width="8" columnType="float"/>
      <wsColumn name="Phenotype" width="15"/>
    </processQuery>
```

- [ ] **Step 3: Add the question**

In `variationQuestions.xml`, after `VariationsByLocation`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations in a set of genes -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <question name="VariationsByGeneIds"
              displayName="Gene ID(s)"
              shortDisplayName="Gene IDs"
              queryRef="VariationsBy.VariationsByGeneIds"
              recordClassRef="VariationRecordClasses.VariationRecordClass">

      <attributesList
        summary="variation_location,gene_ids,variant_type,PercentMinorAlleles,PercentIsolateCalls,Phenotype"/>

      <summary>
        <![CDATA[
          Find variants located in a set of genes that differ within a group of samples,
          with an option to specify minor allele frequency.
        ]]>
      </summary>

      <description>
        <![CDATA[
          This search analyzes whole genome sequencing data from a group of samples to
          find variants associated with the group, and returns only those falling within
          the genes you specify.<br><br>

          Each sample's sequencing reads are aligned to the reference genome (Organism)
          and variants are recorded for each sample based on the Read Frequency
          Threshold. Then, scanning variant locations within your genes across the group
          of samples, variants are returned if the Minor Allele Frequency and the Percent
          samples with a base call are met.

          <p><b>Genes:</b> Your gene IDs are resolved to each gene's genomic span, and
          variants are returned by position within those spans. A variant in an intron or
          UTR of one of your genes is therefore returned, since the span covers the whole
          gene rather than only its coding sequence.</p>

          <p><b>Organism:</b> The Organism parameter defines the species of the samples
          and the genome in which the variants are determined. Choose the organism your
          genes belong to.</p>

          <p><b>Samples:</b> By default the group includes all samples from the Organism
          you chose; you may narrow it using the sample characteristics. At least two
          samples are required, since polymorphism within a group of one is undefined.</p>

          <p><b>Read frequency threshold:</b> An allele is called for a sample at a
          location if that fraction of the sample's aligned reads support it. This
          matters most for diploid or aneuploid organisms, where heterozygous positions
          are expected near 50%.</p>

          <p><b>Minor allele frequency:</b> Among the qualifying calls at a location, the
          minor allele frequency is the percent that are not the major allele. Use 0 to
          find every variant location within the group.</p>

          <p><b>Percent samples with a base call:</b> A location is only considered if
          this fraction of your selected samples have a qualifying call there.</p>
        ]]>
      </description>

      <!-- REQUIRED, as on the sibling searches. -->
      <dynamicAttributes>
        <columnAttribute name="PercentMinorAlleles" displayName="% Minor Alleles" align="center"
          help="Percent of minor alleles for this group of samples at this variant location (where 'minor allele' means any allele that is not the major allele).">
          <reporter name="histogram" displayName="Histogram" scopes=""
            implementation="org.gusdb.wdk.model.report.reporter.HistogramAttributeReporter">
            <description>Display the histogram of the values of this attribute</description>
            <property name="type">int</property>
          </reporter>
        </columnAttribute>
        <columnAttribute name="PercentIsolateCalls" displayName="% Calls" align="center"
          help="Percent of the samples at this variant location from the specified group that have read calls (over the threshold specified in the search)">
          <reporter name="histogram" displayName="Histogram" scopes=""
            implementation="org.gusdb.wdk.model.report.reporter.HistogramAttributeReporter">
            <description>Display the histogram of the values of this attribute</description>
            <property name="type">int</property>
          </reporter>
        </columnAttribute>
        <columnAttribute name="Phenotype" align="center"
          help="1 = this variant is within a gene and there is at least one sample in this set that has an allele with product that is non-synonymous with the most popular allele"/>
      </dynamicAttributes>

    </question>
```

- [ ] **Step 4: Verify both files parse**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && for f in \
  Model/lib/wdk/model/questions/queries/variationQueries.xml \
  Model/lib/wdk/model/questions/variationQuestions.xml; do
  python3 -c "import xml.etree.ElementTree as T,sys; T.parse('$f'); print('$f parses')"
done
```

Expected: both print `parses`.

- [ ] **Step 5: Build and confirm all four searches are in the assembled model**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: completes with no `WdkModelException`.

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"' \
  | grep -oE "VariationsBy\.[A-Za-z]+:" | sort -u
```

Expected exactly four: `VariationsBy.VariationBySourceId:`,
`VariationsBy.VariationsByGeneIds:`, `VariationsBy.VariationsByIsolateGroup:`,
`VariationsBy.VariationsByLocation:`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/variationQueries.xml \
        Model/lib/wdk/model/questions/variationQuestions.xml
git commit -m "Add the VariationsByGeneIds search

No gene-to-variation join in the model: FindSnpsByGeneIdsPlugin resolves the
gene list to genomic intervals through webready.GeneAttributes_p and HSSS
filters variant positions by interval, so the relationship is positional and
apidb.VariationTranscriptProduct plays no part.

Per-project gene defaults only for the three projects with variation data
loaded; the rest owe one when their data lands."
```

---

### Task 5: Category ontology rows

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt`

The file is tab-delimited with load-bearing empty fields and a trailing tab. Derive each row by
substitution from the `VariationBySourceId` row; do not type them.

- [ ] **Step 1: Look at the row you are copying**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
grep -n "VariationQuestions.VariationBySourceId" Model/lib/wdk/ontology/individuals.txt | cat -A
```

Expected: one match showing `^I` between fields, `topic_0199` as parent, `search` as target
type, `menu` and `webservice` at the end, and a trailing `^I` before `$`.

- [ ] **Step 2: Append both rows by substitution**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
for s in VariationsByLocation VariationsByGeneIds; do
  grep "VariationQuestions.VariationBySourceId" Model/lib/wdk/ontology/individuals.txt \
    | sed "s/VariationBySourceId/$s/g" >> Model/lib/wdk/ontology/individuals.txt
done
```

- [ ] **Step 3: Verify field counts match the source row**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
awk -F'\t' '/VariationQuestions.Variation/ {print NF" fields  "$6}' Model/lib/wdk/ontology/individuals.txt
```

Expected: four lines, all with the **same** field count, naming
`VariationQuestions.VariationBySourceId`, `...VariationsByIsolateGroup`,
`...VariationsByLocation`, `...VariationsByGeneIds`. A differing count means a shifted column
and a silently misfiled search — stop rather than patching by hand.

- [ ] **Step 4: Build with `wb ontology`, NOT `wb model`**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb ontology
```

Expected: completes, with a line reporting `categories_merged.owl` saved. `wb model` here would
leave the OWL stale and both searches uncategorized, **with no error anywhere**.

- [ ] **Step 5: Prove the OWL contains both, under the right parent**

```bash
ssh cedar 'for s in VariationsByLocation VariationsByGeneIds; do echo -n "$s "; \
  grep -A3 "individuals.owl#VariationRecordClasses.VariationRecordClass.VariationQuestions.$s\"" \
  /var/www/jbrestel.plasmodb.org/gus_home/lib/wdk/ontology/categories_merged.owl \
  | grep -c "topic_0199"; done'
```

Expected: each prints `1` — the class exists and is `subClassOf topic_0199`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "Categorize VariationsByLocation and VariationsByGeneIds

Same placement as the two existing variation searches: parent topic_0199,
targetType search, menu + webservice scopes. No searchCategory on either
question: it appears zero times in the assembled model, so menu grouping comes
from this file alone."
```

---

### Task 6: Browser verification

Everything in Task 2 is verified by execution against the database. What only a live run can
establish is the two chains no test covers: the `emptyValue` to chromosome fallback, and gene
IDs through interval filtering to HSSS.

**Files:** none.

- [ ] **Step 1: Mark the logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark loc-gene
```

- [ ] **Step 2: Open the app and confirm which site you are on**

Load `https://jbrestel.plasmodb.org/a/app` in Chrome. It **redirects** to the webapp context.
Then, before trusting anything:

```javascript
({origin: window.location.origin, base: window.location.pathname.split('/')[1]})
```

Expected: `origin` is `https://jbrestel.plasmodb.org` and `base` is `plasmo.jbrestel`. If
origin reads `https://veupathdb.org`, **stop** — the tab bounced to autologin and every
relative fetch from here answers for production. Build all paths below from the `base` you
actually got, not from `/a/`.

Note: `computer:screenshot` fails on this instance with `Script injection timed out`, including
on known-good pages. Use `javascript_tool` and the service endpoints; do not spend attempts on
screenshots.

- [ ] **Step 3: Confirm both searches are registered**

```javascript
const b = window.location.pathname.split('/')[1];
fetch(`/${b}/service/record-types/variation`).then(r=>r.json())
  .then(d=>d.searches.map(s=>s.fullName).filter(n=>n.startsWith('VariationQuestions')))
```

Expected: all four — `VariationBySourceId`, `VariationsByIsolateGroup`, `VariationsByLocation`,
`VariationsByGeneIds`. `/record-types` is project-filtered, so this is the source of truth.

- [ ] **Step 4: `VariationsByLocation` — the chromosome vocabulary**

```javascript
const b = window.location.pathname.split('/')[1];
const q = await fetch(`/${b}/service/record-types/variation/searches/VariationsByLocation?expandParams=true`).then(r=>r.json());
const chr = q.searchData.parameters.find(p=>p.name==='chromosomeOptionalForVariations');
JSON.stringify({count: chr.vocabulary.length, terms: chr.vocabulary.map(v=>v[0])})
```

Expected: 15 entries — `Choose chromosome` plus `01` through `14`.

- [ ] **Step 5: `VariationsByLocation` — run it with the sequence box EMPTY**

This is the step that exercises the `emptyValue` to `No Match` to chromosome-fallback chain.
Submit with `chromosomeOptionalForVariations` = the internal for chromosome 01
(`Pf3D7_01_v3`), `sequenceId` left empty, `start_point` `0`, `end_point` `0`, all samples,
thresholds at 80% / 0 / 20.

Expected: rows returned, and **every** returned ID begins `Variant_Pf3D7_01_v3_`. Check the
first page of IDs explicitly — a mixture of sequences would mean the region filter was ignored.

| symptom | cause |
|---|---|
| zero results | the fallback did not fire; check `sequenceId`'s `emptyValue` reached the plugin |
| IDs from other chromosomes | the sequence argument never reached the bash script |
| missing required parameter | Task 1's rename is not installed — re-run Task 1 Steps 5 and 6 |

- [ ] **Step 6: `VariationsByLocation` — run it with an explicit sequence and window**

Submit `sequenceId` = `Pf3D7_11_v3`, `start_point` `1292966`, `end_point` `1296696`.

Expected: fewer rows than Step 5, all with IDs of the form `Variant_Pf3D7_11_v3_<n>` where
`1292966 <= n <= 1296696`. Extract `n` from the IDs and check the min and max against the
bounds rather than eyeballing.

- [ ] **Step 7: `VariationsByGeneIds` — the first real exercise of `hsssGenomicLocationsFilter`**

Submit with the PlasmoDB default gene `PF3D7_1133400`, all samples, thresholds as above.

Expected: a non-empty result set, every ID of the form `Variant_Pf3D7_11_v3_<n>` with
`1292966 <= n <= 1296696` — the same window as Step 6, because that is this gene's span.

**A wrong ID form here surfaces as zero results with no error**, which is exactly why a
non-empty set is the assertion. The installed `hsssGenomicLocationsFilter` was confirmed to
carry the underscore ID join; if this returns nothing, re-check it with the pattern
single-quoted on the remote side:

```bash
ssh cedar "grep -cF '\${contigSourceId}_\${location}' /var/www/jbrestel.plasmodb.org/gus_home/bin/hsssGenomicLocationsFilter"
```

Expected: `2`. (Without the escaping, the remote shell expands the variables and you count `_`.)

- [ ] **Step 8: Confirm an ID resolves to a record page**

Navigate to `/<base>/app/record/variation/<one of the returned IDs>` and confirm it renders
with its Genomic Location / Genetic variation / DNA polymorphism sections and no error.

- [ ] **Step 9: Confirm both searches are in the category tree**

```javascript
const b = window.location.pathname.split('/')[1];
const c = await fetch(`/${b}/service/ontologies/Categories`).then(r=>r.json());
const out=[];
(function walk(n,parent){const p=n.properties||{};const nm=(p.name||[])[0];
  if(nm && nm.startsWith('VariationQuestions')) out.push({name:nm, parent});
  (n.children||[]).forEach(ch=>walk(ch,(p['EuPathDB alternative term']||p.label||[])[0]||parent));
})(c.tree,'ROOT');
JSON.stringify(out,null,1)
```

Expected: all four searches, each with `parent` `"Genetic variation"`.

- [ ] **Step 10: Read the logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since loc-gene --quiet
```

Expected: the error logs report `silent:`. Also confirm the plugin used the paths you expect:

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since loc-gene 2>&1 \
  | grep -oE "dnaseq/readFreq[0-9]+|hsssGenerate[A-Za-z]+" | sort | uniq -c
```

Expected: `hsssGeneratePolymorphismScript` for the two by-location runs and
`hsssGenerateGenomicLocationsScript` for the by-gene run.

**Any ERROR lines you cause yourself by hand-rolling malformed service requests must be
reported as such, not as "the logs were silent."** That happened on the previous search.

- [ ] **Step 11: Report**

Report: the four registered searches; the chromosome vocabulary count; for each of the three
runs, the row count and the observed min/max location against the expected window; one ID that
resolved to a record page; the category-tree parents; the log verdict, distinguishing
self-inflicted errors from real ones. If a step failed, give the symptom and the diagnosis from
the tables above rather than guessing at a fix.

---

## Out of scope

- **`VariationsByTwoIsolateGroups`** — its own spec and plan. Different plugin
  (`FindMajorAllelesPlugin`), 11 `wsColumn`s, five doubled threshold params, and **two new
  EDA-driven filter params**, because `sharedParams.ngsSnp_strain_meta_a`/`_m` sit inside a
  commented-out region and are not in the model. That spec must not forget the plugin's
  hardcoded `_a`/`_m` names.
- **`NgsSnpsByTwoIsolateGroupsWiz`** — a sixth search using the `*_wiz` params; decide whether
  to port it at all alongside `ByTwoIsolateGroups`.
- **Per-gene coding consequences** from `apidb.VariationTranscriptProduct`. A feature, not a port.
- **Deleting the dead `snpParams.xml`** and the commented-out snp regions of `sharedParams.xml`.
- **`ReadFrequencyPercent` as a functional parameter.** On haploid organisms all four
  `readFreq*` directories hold identical data, because the upstream caller runs
  `freebayes --min-alternate-fraction 0.8`. The param selects its directory correctly. Do not
  attempt to verify that changing it changes results; it will not, and that is not a bug in
  these searches. Design §9.
