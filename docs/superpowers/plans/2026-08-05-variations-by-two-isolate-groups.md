# `VariationsByTwoIsolateGroups` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the fifth and last ported snp search — find loci whose major allele differs between two user-chosen groups of samples — completing the `snp` to `variation` migration.

**Architecture:** Two constants renamed in `ApiCommonWebService`; in `ApiCommonModel`, two new filter params (sharing the existing EDA queries — **no new SQL**), four new threshold params, one `processQuery`, one question, one ontology row. The design is `docs/superpowers/specs/2026-08-05-variations-by-two-isolate-groups-design.md` — read it; this plan implements it and does not restate its reasoning.

**Tech Stack:** WDK model XML; Java (two string constants); the `agentic-veupath-dev` control plane for remote builds on `cedar`; Claude in Chrome for verification.

---

## Orientation

**Repos**, both on branch **`dnaseq-merge-experiments`**, never `main`:

| | |
|---|---|
| `~/workspaces/plasmodb/ApiCommonWebService` | Task 1 only |
| `~/workspaces/plasmodb/ApiCommonModel` | Tasks 2–4 |
| `~/workspaces/agentic-veupath-dev` | control plane — run `bin/veup-*.sh` from **here** |

Local edits reach `cedar` through a running `mutagen` sync. Builds run remotely.

**There is no unit-test framework for WDK model XML.** Verification is a structural XML check, a remote build (proves references resolve), `wdkXml` (proves presence in the *assembled* model), and the browser.

**Six traps, every one of which has already cost time on this feature:**

1. **Flags go BEFORE the profile name.** `bin/veup-build.sh plasmodb wb model --dry-run` silently drops the flag **and runs for real**. Commands below are complete; add nothing.
2. **XML forbids `--` inside `<!-- -->`.** All comments below are checked; keep double hyphens out if you reword. `<![CDATA[ ]]>` is exempt.
3. **`wdkXml` prints attributes single-quoted** (`name='x'`). A double-quoted grep pattern matches nothing regardless of model content.
4. **`dynamicAttributes` is mandatory** for any `wsColumn` named in `attributesList`. Ten of them here. Omitting the block fails the build with `Summary attribute field [...] is invalid`.
5. **Jar entries are compressed** — `grep` over `WEB-INF/lib` finds nothing whether or not a string is present. Unzip the class (Task 1 Step 6).
6. **A remote grep for a `$`-containing pattern** gets expanded by the remote shell unless single-quoted on the remote side: `ssh host "... '\$foo' ..."`.

**This search's own trap:** `uniq-value-params` (Task 3 Step 3) forbids Set A = Set B. Its absence **cannot be detected by any build or service check** — only by noticing in the browser that the form accepts A = B. Do not drop it, and do verify it in Task 5.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `ApiCommonWebService/.../FindMajorAllelesPlugin.java:20,24` | Modify 2 lines | the two filter param name contracts (Task 1) |
| `ApiCommonModel/.../params/variationParams.xml` | Add 2 filterParams + 4 threshold params | the doubled params (Task 2) |
| `ApiCommonModel/.../queries/variationQueries.xml` | Add 1 `processQuery` | plugin binding, 12 `wsColumn`s (Task 3) |
| `ApiCommonModel/.../variationQuestions.xml` | Add 1 question | 13 summary columns, 10 dynamic attributes, `uniq-value-params` (Task 3) |
| `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt` | Append 1 row | category placement (Task 4) |

No file gains new SQL. Both new filter params reuse `VariationVQ.SamplesMetadataByStudy` and
`SampleOntologyByStudy`.

---

### Task 1: Rename the two filter param constants

**Files:**
- Modify: `WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindMajorAllelesPlugin.java:20` and `:24`

- [ ] **Step 1: Confirm the two lines and that nothing else references the old names**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git branch --show-current
grep -rn "ngsSnp_strain_meta" WSFPlugin/src/main/java/
```

Expected: branch `dnaseq-merge-experiments`, and exactly two hits, both in `FindMajorAllelesPlugin.java`:

```
:20:  public static final String PARAM_STRAIN_FILTER_A = "ngsSnp_strain_meta_a";
:24:  public static final String PARAM_STRAIN_FILTER_B = "ngsSnp_strain_meta_m";
```

If any other Java file references those strings, stop and report — the blast radius would be larger than the design assumed.

- [ ] **Step 2: Make both changes**

```java
  public static final String PARAM_STRAIN_FILTER_A = "variation_sample_meta_a";
```
```java
  public static final String PARAM_STRAIN_FILTER_B = "variation_sample_meta_b";
```

Note `_m` becomes `_b`, not `_m`. Change nothing else in the file — in particular leave the
Set B strains handling alone, including the missing null check the design records as
deliberately out of scope.

- [ ] **Step 3: Verify the diff is two lines and the old names are gone**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService && git diff --stat && git diff
grep -rc "ngsSnp_strain_meta" WSFPlugin/src/main/java/ 2>/dev/null | grep -v ':0' || echo "old names gone"
```

Expected: `1 file changed, 2 insertions(+), 2 deletions(-)`, and `old names gone`.

- [ ] **Step 4: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
git add WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindMajorAllelesPlugin.java
git commit -m "Rename the two sample-group param contracts for variation searches

FindMajorAllelesPlugin serves VariationsByTwoIsolateGroups now. It extends
HighSpeedSnpSearchAbstractPlugin directly rather than FindPolymorphismsPlugin,
so these two names are its own constants and were not covered by the earlier
strain-filter rename.

The odd _m becomes _b: nothing in the plugin distinguishes it beyond being the
second group, and its prompts already read Set B. With this, no snp-era param
name survives in any variation search."
```

- [ ] **Step 5: Build and install**

```bash
cd ~/workspaces/agentic-veupath-dev && \
  ssh -o LogLevel=ERROR "$(python3 bin/resolve.py --profile profiles/plasmodb.yml --field host)" \
  "bash -lc 'source /var/www/jbrestel.plasmodb.org/etc/setenv && bld ApiCommonWebService'"
```

Expected: `BUILD SUCCESSFUL`, 1–2 minutes.

- [ ] **Step 6: Reload and verify the installed jar**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb reload
```

Expected: `OK - Reloaded application at context path [/plasmo.jbrestel]`.

```bash
ssh cedar "bash -lc 'J=/var/www/PlasmoDB/plasmo.jbrestel/webapp/WEB-INF/lib/api-common-websvc-wsfplugin-1.0.0.jar; \
  C=org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindMajorAllelesPlugin.class; \
  for s in variation_sample_meta_a variation_sample_meta_b ngsSnp_strain_meta_a ngsSnp_strain_meta_m; do \
    echo -n \"\$s=\"; unzip -p \$J \$C | strings | grep -c \$s; done'"
```

Expected: `variation_sample_meta_a=1`, `variation_sample_meta_b=1`, and **both old names `=0`**.
Remember jar entries are compressed, so `grep` over the lib directory would find nothing either
way — read the class out, as here.

**A pass here is what makes Task 5 meaningful.** With an old string installed, the search fails
as a missing required parameter and the model looks wrong when it is fine.

---

### Task 2: The two filter params and four threshold params

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/params/variationParams.xml`

- [ ] **Step 1: Confirm the EDA queries you are about to share already exist**

No new SQL is written in this task; both filters point at the queries the one-group search uses.

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && python3 -c "
import xml.etree.ElementTree as T
r=T.parse('Model/lib/wdk/model/questions/params/variationParams.xml').getroot()
for qs in r.findall('querySet'):
    print(qs.get('name'), [q.get('name') for q in qs.findall('sqlQuery')])
"
```

Expected: `VariationVQ ['EdaSampleTableSuffix', 'SamplesMetadataByStudy', 'SampleOntologyByStudy', 'ChromosomeForVariations']`.

- [ ] **Step 2: Add the two filter params**

Inside the `variationParams` paramSet, after `chromosomeOptionalForVariations`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Sample groups A and B (two-group comparison) -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Both names are CONTRACTS with the Java plugin:
         FindMajorAllelesPlugin.PARAM_STRAIN_FILTER_A and _B return exactly these
         strings and list them among the plugin's required params.

         Both reuse the one-group search's EDA queries. WDK clones a dependent
         param's queries and sets the context param per param, so three filter
         params sharing two query definitions get three independent instances. The
         snp original shared one query between its two groups the same way.

         Deliberately NO minSelectedCount, unlike variation_sample_meta which
         requires 2. Polymorphism within a group of one is undefined, which is why
         the one-group search needs a minimum. Comparing the major allele BETWEEN
         two groups of one is a meaningful strain-versus-strain comparison, and the
         snp original set no minimum on either group. See the design doc, 4.2. -->
    <filterParam name="variation_sample_meta_a"
                 metadataQueryRef="VariationVQ.SamplesMetadataByStudy"
                 backgroundQueryRef="VariationVQ.SamplesMetadataByStudy"
                 ontologyQueryRef="VariationVQ.SampleOntologyByStudy"
                 prompt="Set A Samples"
                 dependedParamRef="organismParams.organismSinglePick,variationParams.eda_sample_table_suffix">
      <help>
        Select the first group of samples to compare. Use the sample characteristics
        to narrow the group, or accept all samples for the organism you chose.
      </help>
    </filterParam>

    <filterParam name="variation_sample_meta_b"
                 metadataQueryRef="VariationVQ.SamplesMetadataByStudy"
                 backgroundQueryRef="VariationVQ.SamplesMetadataByStudy"
                 ontologyQueryRef="VariationVQ.SampleOntologyByStudy"
                 prompt="Set B Samples"
                 dependedParamRef="organismParams.organismSinglePick,variationParams.eda_sample_table_suffix">
      <help>
        Select the second group of samples to compare. It must differ from Set A;
        comparing a group against itself returns nothing useful.
      </help>
    </filterParam>
```

- [ ] **Step 3: Add the four threshold params**

After the two filter params:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Two-group thresholds -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Copied from snpParams.xml, which is imported inside a commented-out block
         and so is absent from the assembled model; a paramRef to it fails model
         load. See the design doc, section 5.

         Only Set B gets "Two" variants. Set A's read frequency and percent-called
         params are the unsuffixed ones the one-group search already defines, because
         those are the plugin's own Set A constants. -->

    <stringParam name="MinPercentMajorAlleles"
                 prompt="Major allele frequency &gt;= "
                 number="true">
      <help>
        This parameter applies to the Set A aligned sample sequences. When a Set A
        locus has a major allele frequency greater than or equal to this value, it
        will be compared to the equivalent locus in Set B samples. Note that 100% is
        permissible and is the most stringent setting, since the search first
        identifies an allele in this set and then compares it with the allele in
        Set B. See the Description below the Get Answer button for more.
      </help>
      <suggest default="80"/>
      <regex>\d\d?|100</regex>
    </stringParam>

    <stringParam name="MinPercentMajorAllelesTwo"
                 prompt="Major allele frequency &gt;= "
                 number="true">
      <help>
        This parameter applies to the aligned sample sequences of Set B. When a Set B
        locus has a major allele frequency greater than or equal to this value, it
        will be compared to the equivalent locus in Set A samples. Note that 100% is
        permissible, since the search first identifies loci from Set A and then
        compares them with loci from Set B. See the Description below the Get Answer
        button for more.
      </help>
      <suggest default="80"/>
      <regex>\d\d?|100</regex>
    </stringParam>

    <stringParam name="MinPercentIsolateCallsTwo"
                 prompt="Percent samples with a base call &gt;= "
                 number="true">
      <help>
        This parameter applies to the Set B aligned sample sequences. At any given
        nucleotide position, some samples in Set B may not have data supporting a
        call because the Read Frequency Threshold was not met. This defines the
        fraction of Set B samples that must have a base call before a locus is
        returned for that position, based on the remaining samples that do have data.
        See the Description below for more information.
      </help>
      <suggest default="20"/>
      <regex>\d\d?|100</regex>
    </stringParam>

    <!-- One definition, unlike snpParams which declares this twice
         (excludeProjects/includeProjects ToxoDB) differing only in help text. The
         four internals must match the readFreq* directory names exactly. -->
    <enumParam name="ReadFrequencyPercentTwo"
               prompt="Read frequency threshold" quote="false">
      <help>
        This parameter applies to the sequencing reads of individual samples in Set B
        and defines a stringency for data supporting a variant call between a sample
        and the reference genome (Organism). Each nucleotide position of each sample
        is compared to the reference genome and a call is made if the portion of the
        sample's aligned reads that support the variant is above the Read Frequency
        Threshold (RFT). Find high quality haploid variants with 80% RFT or
        heterozygous diploid/aneuploid variants with 40%. See the Description below
        for more.
      </help>
      <enumList>
        <enumValue default="true">
          <term>80%</term>
          <internal>80</internal>
        </enumValue>
        <enumValue>
          <term>60%</term>
          <internal>60</internal>
        </enumValue>
        <enumValue>
          <term>40%</term>
          <internal>40</internal>
        </enumValue>
        <enumValue>
          <term>20%</term>
          <internal>20</internal>
        </enumValue>
      </enumList>
    </enumParam>
```

Note `MinPercentIsolateCallsTwo`'s prompt has been harmonised with `MinPercentIsolateCalls`'
wording ("Percent samples with a base call >= ") rather than kept as the original's terser "Min
percent isolates with calls >= ". The design flagged this as the implementer's call; the two
prompts sit side by side in one form, so matching them is the kinder choice. **The param name is
unchanged** — only the prompt.

- [ ] **Step 4: Verify the XML parses, the regexes survived, and nothing shares a name**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && python3 - <<'PY'
import xml.etree.ElementTree as T, collections
r = T.parse('Model/lib/wdk/model/questions/params/variationParams.xml').getroot()
ps = r.find('paramSet')
names = [c.get('name') for c in ps]
print('params:', names)
dupes = [n for n,c in collections.Counter(names).items() if c > 1]
print('duplicate names:', dupes or 'none')
for sp in ps.iter('stringParam'):
    rx = sp.find('regex')
    print(sp.get('name'), '->', repr(rx.text if rx is not None else None))
for e in ps.iter('enumParam'):
    print(e.get('name'), 'internals:', [i.find('internal').text for i in e.iter('enumValue')])
PY
```

Expected: **fourteen** params (the eight already there plus your six), **no duplicates**, the
three new `MinPercent*` regexes printing
`'\\d\\d?|100'` (and the pre-existing `MinPercentMinorAlleles` printing `'\\d\\d?'`), and both
enum params listing internals `['80', '60', '40', '20']`. A duplicate name here would mean you
redefined a param the one-group search already provides.

- [ ] **Step 5: Build to prove the model still loads**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: completes with no `WdkModelException`. Unreferenced params are legal, so this only
proves the definitions resolve — Task 3 is what exercises them.

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"' \
  | grep -E "name='(variation_sample_meta_a|variation_sample_meta_b|MinPercentMajorAlleles|MinPercentMajorAllelesTwo|MinPercentIsolateCallsTwo|ReadFrequencyPercentTwo)'"
```

Expected: six matching lines, one per new param, each prefixed with its Java class
(`FilterParamNew`, `StringParam`, `EnumParam`). Note the **single** quotes.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/variationParams.xml
git commit -m "Add the two-group sample filters and four thresholds

Both filters reuse the one-group search's EDA queries; no new SQL. WDK clones a
dependent param's queries per param, which is how the snp original ran two
groups off one query definition.

No minSelectedCount on either group, deliberately: comparing major alleles
between two groups of one is meaningful, unlike polymorphism within one, and
the snp original set no minimum.

Only Set B gets 'Two' threshold variants. Set A reuses the unsuffixed
ReadFrequencyPercent and MinPercentIsolateCalls because those are the plugin's
own Set A constants."
```

---

### Task 3: The query and the question

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/queries/variationQueries.xml`
- Modify: `ApiCommonModel/Model/lib/wdk/model/questions/variationQuestions.xml`

- [ ] **Step 1: Confirm the plugin's ten required params and twelve columns**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
sed -n '18,60p' WSFPlugin/src/main/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindMajorAllelesPlugin.java
```

Expected: `PARAM_STRAIN_FILTER_A`/`_B` now reading `variation_sample_meta_a`/`_b` (Task 1), the
Set A constants naming the **unsuffixed** `ReadFrequencyPercent` and `MinPercentIsolateCalls`,
`getRequiredParameterNames()` listing ten, and `getColumns()` listing twelve. If Set A's
constants name suffixed params, stop — the plan's param wiring would be wrong.

- [ ] **Step 2: Add the process query**

In `variationQueries.xml`, inside the `VariationsBy` querySet, after `VariationsByGeneIds`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations distinguishing two groups of samples -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- A different question from the other three HSSS searches: find the major
         allele in each of two groups and return the loci where they disagree.

         FindMajorAllelesPlugin extends HighSpeedSnpSearchAbstractPlugin directly,
         not FindPolymorphismsPlugin, so it declares all ten required params itself.
         Set A uses the unsuffixed ReadFrequencyPercent and MinPercentIsolateCalls
         because those are the plugin's own Set A constants; only Set B has Two
         variants. The prompt overrides are needed: without them the form shows two
         identical Read frequency threshold fields.

         The wsColumn set is fixed by the plugin, which throws unless its results
         file has exactly 11 columns; project_id is supplied by the plugin. -->
    <processQuery name="VariationsByTwoIsolateGroups"
                  processName="org.apidb.apicomplexa.wsfplugin.highspeedsnpsearch.FindMajorAllelesPlugin">

      <paramRef ref="organismParams.organismSinglePick" prompt="Organism"
                displayType="treeBox" quote="false"
                queryRef="organismVQ.withVariationsTree">
        <help>The Organism defines the species identity of the samples and the genome
        against which each sample's variants were called.</help>
      </paramRef>
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <paramRef ref="variationParams.WebServicesPath"/>

      <paramRef ref="variationParams.variation_sample_meta_a"   prompt="Set A Samples"/>
      <paramRef ref="variationParams.ReadFrequencyPercent"      prompt="Set A read frequency threshold &gt;= "/>
      <paramRef ref="variationParams.MinPercentMajorAlleles"    prompt="Set A major allele frequency &gt;= "/>
      <paramRef ref="variationParams.MinPercentIsolateCalls"    prompt="Set A percent samples with base call &gt;= "/>

      <paramRef ref="variationParams.variation_sample_meta_b"   prompt="Set B Samples"/>
      <paramRef ref="variationParams.ReadFrequencyPercentTwo"   prompt="Set B read frequency threshold &gt;= "/>
      <paramRef ref="variationParams.MinPercentMajorAllelesTwo" prompt="Set B major allele frequency &gt;= "/>
      <paramRef ref="variationParams.MinPercentIsolateCallsTwo" prompt="Set B percent samples with base call &gt;= "/>

      <wsColumn name="source_id" width="60" wsName="SourceId"/>
      <wsColumn name="project_id" width="20" wsName="ProjectId"/>
      <wsColumn name="MajorAlleleA" width="3"/>
      <!-- width 8 so the display keeps xx.x precision -->
      <wsColumn name="MajorAllelePctA" width="8" columnType="float"/>
      <wsColumn name="IsTriallelicA" width="3"/>
      <wsColumn name="MajorProductA" width="3"/>
      <wsColumn name="MajorProductIsVariableA" width="3"/>
      <wsColumn name="MajorAlleleB" width="3"/>
      <wsColumn name="MajorAllelePctB" width="8" columnType="float"/>
      <wsColumn name="IsTriallelicB" width="3"/>
      <wsColumn name="MajorProductB" width="3"/>
      <wsColumn name="MajorProductIsVariableB" width="3"/>
    </processQuery>
```

- [ ] **Step 3: Add the question**

In `variationQuestions.xml`, after `VariationsByGeneIds`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations distinguishing two groups of samples -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <question name="VariationsByTwoIsolateGroups"
              displayName="Differences Between Two Groups of Samples"
              shortDisplayName="Two Groups"
              queryRef="VariationsBy.VariationsByTwoIsolateGroups"
              recordClassRef="VariationRecordClasses.VariationRecordClass">

      <!-- Thirteen columns is a lot and is the original's choice reproduced: the
           side-by-side comparison is the whole point, and dropping either set's
           columns would hide half the answer. -->
      <attributesList
        summary="variation_location,gene_ids,variant_type,MajorAlleleA,MajorAllelePctA,IsTriallelicA,MajorProductA,MajorProductIsVariableA,MajorAlleleB,MajorAllelePctB,IsTriallelicB,MajorProductB,MajorProductIsVariableB"/>

      <summary>
        <![CDATA[
          Find variants that distinguish two groups of samples, based on the major
          allele threshold you supply for each group.
        ]]>
      </summary>

      <description>
        <![CDATA[
          This search compares whole genome sequencing data from two groups of samples
          to find variants that differ between the two groups.<br><br>

          Each sample's sequencing reads are aligned to the reference genome (Organism)
          and variants are recorded for each sample based on the Read Frequency
          Threshold. Then, scanning locations across the samples in Set A and Set B
          separately, the major allele of each set is recorded where it meets that
          set's major allele frequency and percent samples with a base call. A location
          is returned when the two sets' major alleles differ.

          <p><b>Choosing the two groups:</b> Set A and Set B must differ. Use the
          sample characteristics to define each group, for example samples from two
          different countries, or two different host phenotypes.</p>

          <p><b>Major allele frequency:</b> Among the qualifying calls at a location
          within one set, the major allele frequency is the percent carrying the most
          common allele. Unlike the within-group searches, 100% is permissible here and
          is the most stringent setting: the search identifies each set's major allele
          first and then compares the two, so demanding unanimity within a set is a
          sharper test rather than an impossible one. Lower the threshold to return
          more locations.</p>

          <p><b>Read frequency threshold:</b> An allele is called for a sample at a
          location if that fraction of the sample's aligned reads support it. Each set
          has its own threshold.</p>

          <p><b>Percent samples with a base call:</b> A location is only considered
          within a set if this fraction of that set's samples have a qualifying call
          there.</p>
        ]]>
      </description>

      <!-- REQUIRED: attributesList cannot name a processQuery's wsColumns until they
           are declared here. sortable="false" throughout, as in the original: the
           plugin emits these as strings, so a lexical sort on a percentage would
           mis-order. -->
      <dynamicAttributes>
        <columnAttribute name="MajorAlleleA" displayName="Set A Major Allele" align="center" sortable="false"/>
        <columnAttribute name="MajorAllelePctA" displayName="Set A Major Allele Pct" align="center" sortable="false"/>
        <columnAttribute name="IsTriallelicA" displayName="Set A Is Triallelic" align="center" sortable="false"/>
        <columnAttribute name="MajorProductA" displayName="Set A Major Product" align="center" sortable="false"/>
        <columnAttribute name="MajorProductIsVariableA" displayName="Set A Mjr Prod Is Variable" align="center" sortable="false"/>
        <columnAttribute name="MajorAlleleB" displayName="Set B Major Allele" align="center" sortable="false"/>
        <columnAttribute name="MajorAllelePctB" displayName="Set B Major Allele Pct" align="center" sortable="false"/>
        <columnAttribute name="IsTriallelicB" displayName="Set B Is Triallelic" align="center" sortable="false"/>
        <columnAttribute name="MajorProductB" displayName="Set B Major Product" align="center" sortable="false"/>
        <columnAttribute name="MajorProductIsVariableB" displayName="Set B Mjr Prod Is Variable" align="center" sortable="false"/>
      </dynamicAttributes>

      <!-- Forbids Set A = Set B. NOT snp cruft: geneQuestions.xml uses this same
           property four times for fold-change reference-versus-comparison sample
           pairs. Enforcement is client-side in web-monorepo, so its absence cannot
           be caught by any build or service check. Do not drop it. -->
      <propertyList name="uniq-value-params">
        <value>variation_sample_meta_a</value>
        <value>variation_sample_meta_b</value>
      </propertyList>

    </question>
```

- [ ] **Step 4: Verify both files parse and the question carries all three required blocks**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && python3 - <<'PY'
import xml.etree.ElementTree as T
r = T.parse('Model/lib/wdk/model/questions/queries/variationQueries.xml').getroot()
s = r.find('querySet'); print('queries:', [c.get('name') for c in s])
pq = [c for c in s if c.get('name') == 'VariationsByTwoIsolateGroups'][0]
print('paramRefs:', len(pq.findall('paramRef')), 'wsColumns:', len(pq.findall('wsColumn')))
r2 = T.parse('Model/lib/wdk/model/questions/variationQuestions.xml').getroot()
print('questions:', [q.get('name') for q in r2.find('questionSet')])
q = [x for x in r2.iter('question') if x.get('name') == 'VariationsByTwoIsolateGroups'][0]
print('dynAttrs:', len(list(q.iter('columnAttribute'))))
print('summary cols:', len(q.find('attributesList').get('summary').split(',')))
pl = [p for p in q.findall('propertyList') if p.get('name') == 'uniq-value-params']
print('uniq-value-params:', [v.text for v in pl[0]] if pl else 'MISSING')
PY
```

Expected: five queries and five questions; **11 paramRefs** (organism, suffix, wsPath, plus
four per set) and **12 wsColumns**; **10** dynamic attributes; **13** summary columns; and
`uniq-value-params: ['variation_sample_meta_a', 'variation_sample_meta_b']`. `MISSING` there is
the failure this whole task is most likely to produce.

- [ ] **Step 5: Build and confirm all five searches are in the assembled model**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: completes with no `WdkModelException`.

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"' \
  | grep -oE "VariationsBy\.[A-Za-z]+:" | sort -u
```

Expected exactly five: `VariationBySourceId`, `VariationsByGeneIds`, `VariationsByIsolateGroup`,
`VariationsByLocation`, `VariationsByTwoIsolateGroups`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/variationQueries.xml \
        Model/lib/wdk/model/questions/variationQuestions.xml
git commit -m "Add the VariationsByTwoIsolateGroups search

Twelve wsColumns and an 11-column results file, both dictated by
FindMajorAllelesPlugin. Params ordered organism, then Set A, then Set B, with
prompt overrides so the two sets' thresholds are distinguishable in the form.

Carries the uniq-value-params propertyList forbidding Set A = Set B. Its
enforcement is client-side, so no build or service check can detect its
absence; only the rendered form can."
```

---

### Task 4: Category ontology row

**Files:**
- Modify: `ApiCommonModel/Model/lib/wdk/ontology/individuals.txt`

- [ ] **Step 1: Append the row by substitution**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
grep "VariationQuestions.VariationBySourceId" Model/lib/wdk/ontology/individuals.txt \
  | sed "s/VariationBySourceId/VariationsByTwoIsolateGroups/g" \
  >> Model/lib/wdk/ontology/individuals.txt
```

- [ ] **Step 2: Verify field counts match across all five rows**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
awk -F'\t' '/VariationQuestions.Variation/ {print NF" fields  "$6}' Model/lib/wdk/ontology/individuals.txt
```

Expected: five lines, all `14 fields`, the fifth naming
`VariationQuestions.VariationsByTwoIsolateGroups`. A differing count means a shifted column and
a silently misfiled search — stop rather than patching by hand.

- [ ] **Step 3: Build with `wb ontology`, NOT `wb model`**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb ontology
```

Expected: completes, reporting `categories_merged.owl` saved. `wb model` here leaves the OWL
stale and the search uncategorized, **with no error anywhere**.

- [ ] **Step 4: Prove the OWL has it under the right parent**

```bash
ssh cedar 'grep -A3 "individuals.owl#VariationRecordClasses.VariationRecordClass.VariationQuestions.VariationsByTwoIsolateGroups\"" \
  /var/www/jbrestel.plasmodb.org/gus_home/lib/wdk/ontology/categories_merged.owl | grep -c topic_0199'
```

Expected: `1`.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "Categorize VariationsByTwoIsolateGroups

Same placement as the other four variation searches: parent topic_0199,
targetType search, menu + webservice scopes. Completes the five-search port."
```

---

### Task 5: Browser verification

**Files:** none.

- [ ] **Step 1: Mark the logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark twogroups
```

- [ ] **Step 2: Open the app and confirm the origin**

Load `https://jbrestel.plasmodb.org/a/app` (it redirects to the webapp context), then:

```javascript
({origin: window.location.origin, base: window.location.pathname.split('/')[1]})
```

Expected: origin `https://jbrestel.plasmodb.org`, base `plasmo.jbrestel`. If origin reads
`https://veupathdb.org`, **stop** — the tab bounced to autologin and relative fetches answer for
production. Build all paths from the base you actually got.

`computer:screenshot` fails on this instance (`Script injection timed out`), including on
known-good pages. Use `javascript_tool` and the service endpoints.

- [ ] **Step 3: Confirm all five searches are registered**

```javascript
const b = window.location.pathname.split('/')[1];
fetch(`/${b}/service/record-types/variation`).then(r=>r.json())
  .then(d=>d.searches.map(s=>s.fullName).filter(n=>n.startsWith('VariationQuestions')))
```

Expected: all five, including `VariationQuestions.VariationsByTwoIsolateGroups`.

- [ ] **Step 4: Confirm the form's shape and both filters populate**

```javascript
const b = window.location.pathname.split('/')[1];
const q = await fetch(`/${b}/service/record-types/variation/searches/VariationsByTwoIsolateGroups?expandParams=true`).then(r=>r.json());
const ps = q.searchData.parameters;
JSON.stringify({
  names: ps.map(p=>p.name),
  prompts: ps.map(p=>p.displayName),
  filters: ps.filter(p=>p.type==='filter').map(p=>({name:p.name, nodes:p.ontology.length, min:p.minSelectedCount}))
}, null, 1)
```

Expected: eleven params; the two filters are `variation_sample_meta_a` and
`variation_sample_meta_b`, each with **27** ontology nodes and **no** `minSelectedCount`; and
the Set A / Set B prompts are distinct (not two identical "Read frequency threshold" labels).

- [ ] **Step 5: The disjoint-groups run — the search's definition**

`country` splits the Pf samples cleanly: 147 French Guiana, 69 Senegal. Run with Set A =
Senegal, Set B = French Guiana, thresholds at their defaults (80% RFT, 80 major allele, 20
percent called). The `country` ontology term is `VAR_8e68b3e5`; a filter value looks like:

```javascript
JSON.stringify({filters:[{field:"VAR_8e68b3e5", type:"string", isRange:false,
                          value:["Senegal"], includeUnknown:false}]})
```

Submit via `/reports/standard` requesting attributes
`["primary_key","MajorAlleleA","MajorAlleleB"]`, then assert:

```javascript
const bad = records.filter(r => r.attributes.MajorAlleleA === r.attributes.MajorAlleleB);
({total: meta.totalCount, sampled: records.length, violations: bad.length})
```

Expected: a non-empty result set and **`violations: 0`**. `MajorAlleleA != MajorAlleleB` *is*
the search's definition, so a single violation means the comparison is broken — this is a
stronger assertion than any row count.

- [ ] **Step 6: The symmetry check**

Swap the groups: Set A = French Guiana, Set B = Senegal. Expect an **identical `totalCount`**,
because "the two major alleles disagree" is symmetric. A differing count means Set B's
thresholds are not applied the way Set A's are — exactly the copy-paste asymmetry that doubled
params invite.

Caveat to record in the report: this tests the *threshold* plumbing. It would also pass
trivially if both sets read the same `readFreq` files, which on this haploid site they do.

- [ ] **Step 7: The `uniq-value-params` check — browser only**

In the rendered form, set both groups to the same value (Senegal in each). The form should
refuse to submit. If it submits, the property did not take effect; report it rather than working
around it, since nothing else can detect this.

- [ ] **Step 8: Confirm an ID resolves**

Take one returned ID (form `Variant_<sequence>_<location>`), navigate to
`/<base>/app/record/variation/<id>`, and confirm the record page renders without error.

- [ ] **Step 9: Category tree**

```javascript
const b = window.location.pathname.split('/')[1];
const c = await fetch(`/${b}/service/ontologies/Categories`).then(r=>r.json());
const out=[];
(function walk(n,parent){const p=n.properties||{};const nm=(p.name||[])[0];
  if(nm && nm.startsWith('VariationQuestions')) out.push({name:nm.replace('VariationQuestions.',''), parent});
  (n.children||[]).forEach(ch=>walk(ch,(p['EuPathDB alternative term']||p.label||[])[0]||parent));
})(c.tree,'ROOT');
JSON.stringify(out,null,1)
```

Expected: all five searches, each with parent `"Genetic variation"`.

- [ ] **Step 10: Logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since twogroups --quiet
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since twogroups 2>&1 \
  | grep -oE "hsssGenerate[A-Za-z]+|findMajorAlleles" | sort | uniq -c
```

Expected: error logs `silent:`, and `hsssGenerateMajorAllelesScript` appearing once per run.

**Any ERROR lines caused by your own malformed service requests must be reported as
self-inflicted, not as "the logs were clean."**

- [ ] **Step 11: Report**

Report: the five registered searches; the eleven params with their prompts and the two filters'
node counts; for both runs the total count and the violation count; whether the form refused
A = B; one ID that resolved; the category-tree parents; and the log verdict distinguishing
self-inflicted errors from real ones.

---

## Out of scope

- **`NgsSnpsByTwoIsolateGroupsWiz`** — a sixth search (PlasmoDB/UniDB only) driven by the
  `*_wiz` params, which sit in the same commented-out region as the params this plan replaces.
  Whether the wizard flow is still wanted is a product question. **With this plan the
  five-search port is complete.**
- **Deleting the dead snp XML.** After this, `snpParams.xml` and the commented-out snp regions
  of `sharedParams.xml` have no remaining consumer, but removal has its own blast radius
  (`recordParams.xml`, `spanQuestions.xml`, `SnpsBySpanLogic`).
- **The Set B null-check asymmetry** in `FindMajorAllelesPlugin`.
- **`ReadFrequencyPercent` as a functional parameter.** All four `readFreq*` directories hold
  identical data on haploid organisms; both read-frequency params select their directory
  correctly, and changing either will not change results. Not a defect in this search.
