# EDA All-Data Tables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `EdaPhenotypeDataTable` and `EdaCellularLocalizationDataTable` WDK data tables to the gene record page, exposing all EDA variable/value data for each category across all datasets (not just graph-backed ones), with a linked dataset name, attribution, variable, and value columns.

**Architecture:** Two new TEMPLATE_ANCHOR-backed WDK sqlQuery elements in `geneTableQueries.xml` drive the data; two new `.dst` templates generate per-dataset UNION SQL; two new table definitions in `geneRecord.xml` expose the data with a `linkAttribute` for the dataset name; ontology entries in `individuals.txt` categorize the tables; and two Java dataset injector classes are updated to wire the templates and model references.

**Tech Stack:** WDK XML config, PostgreSQL SQL, Java (dataset injectors), tab-delimited ontology file.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Model/lib/dst/phenotype.dst` | Modify | Add `phenotypeAllDataGeneTableSql` template |
| `Model/lib/dst/cellularLocalization.dst` | Modify | Add `cellularLocalizationAllDataGeneTableSql` template |
| `Model/lib/wdk/model/records/geneTableQueries.xml` | Modify | Add `EdaPhenotypeDataTable` and `EdaCellularLocalizationDataTable` sqlQuery elements |
| `Model/lib/wdk/model/records/geneRecord.xml` | Modify | Add table definitions with `linkAttribute` for both new tables |
| `Model/lib/wdk/ontology/individuals.txt` | Modify | Add ontology entries for both new tables (`record` + `download` scope) |
| `EbrcModelCommon/Model/src/main/java/org/apidb/apicommon/model/datasetInjector/PhenotypeEDAStudy.java` | Modify | Inject `phenotypeAllDataGeneTableSql` + add model reference |
| `EbrcModelCommon/Model/src/main/java/org/apidb/apicommon/model/datasetInjector/CellularLocalizationEDAStudy.java` | Modify | Inject `cellularLocalizationAllDataGeneTableSql` + add model reference |

> **Note:** Tasks 1–7 are in the `ApiCommonModel` worktree at:
> `/home/jbrestel/workspaces/dataLoad/project_home/ApiCommonModel/.claude/worktrees/eda-data-tables`
>
> Tasks 8–9 are in the separate `EbrcModelCommon` repo at:
> `/home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon`
> These should be done on a feature branch in that repo.

---

### Task 1: Add `phenotypeAllDataGeneTableSql` template to phenotype.dst

**Files:**
- Modify: `Model/lib/dst/phenotype.dst` (after line 110, after `phenotypeDataTableGeneTableSql` templateTextEnd)

- [ ] **Step 1: Insert the new template block**

In `Model/lib/dst/phenotype.dst`, find the exact text after the `phenotypeDataTableGeneTableSql` template ends:

```
  AND av.attribute_stable_id != 'VEUPATHDB_GENE_ID'
>templateTextEnd<


[templateStart]
name=phenotypeEdaAttributeQueriesNumeric
```

Replace with:

```
  AND av.attribute_stable_id != 'VEUPATHDB_GENE_ID'
>templateTextEnd<


[templateStart]
name=phenotypeAllDataGeneTableSql
anchorFile=ApiCommonModel/Model/lib/wdk/model/records/geneTableQueries.xml
prop=datasetName
prop=edaStudyStableId
prop=edaEntityAbbrev
prop=datasetDisplayName
prop=shortAttribution
>templateTextStart<
UNION
SELECT genes.string_value AS gene,
       '${datasetName}' AS dataset_presenter_id,
       '${datasetDisplayName}' AS dataset_presenter_display_name,
       '${shortAttribution}' AS short_attribution,
       ag.display_name AS variable,
       coalesce(av.string_value, coalesce(round(av.number_value::numeric, 4)::text, av.date_value::text)) AS value
FROM eda.attributevalue_${edaStudyStableId}_${edaEntityAbbrev} av,
     eda.attributegraph_${edaStudyStableId}_${edaEntityAbbrev} ag,
     (SELECT av.${edaEntityAbbrev}_stable_id, MIN(gi.gene) as string_value
      FROM eda.attributevalue_${edaStudyStableId}_${edaEntityAbbrev} av
      JOIN apidbtuning.GeneId gi ON gi.id = av.string_value
      WHERE av.attribute_stable_id = 'VEUPATHDB_GENE_ID'
      GROUP BY av.${edaEntityAbbrev}_stable_id) genes
WHERE av.attribute_stable_id = ag.stable_id
  AND av.${edaEntityAbbrev}_stable_id = genes.${edaEntityAbbrev}_stable_id
  AND av.attribute_stable_id != 'VEUPATHDB_GENE_ID'
>templateTextEnd<


[templateStart]
name=phenotypeEdaAttributeQueriesNumeric
```

- [ ] **Step 2: Verify the file is structurally intact**

```bash
grep -c "templateStart" Model/lib/dst/phenotype.dst
```

Expected: one more `templateStart` than before the edit (count was 8 before, now 9).

```bash
grep -n "phenotypeAllDataGeneTableSql" Model/lib/dst/phenotype.dst
```

Expected: two lines — one with `name=` and one with `anchorFile=`.

- [ ] **Step 3: Commit**

```bash
git add Model/lib/dst/phenotype.dst
git commit -m "feat: add phenotypeAllDataGeneTableSql template to phenotype.dst"
```

---

### Task 2: Add `cellularLocalizationAllDataGeneTableSql` template to cellularLocalization.dst

**Files:**
- Modify: `Model/lib/dst/cellularLocalization.dst` (after line 125, after `cellularLocalizationDataTableGeneTableSql` templateTextEnd)

- [ ] **Step 1: Insert the new template block**

In `Model/lib/dst/cellularLocalization.dst`, find:

```
  AND av.attribute_stable_id != 'VEUPATHDB_GENE_ID'
>templateTextEnd<


[templateStart]
name=cellularLocalizationEdaAttributeQueriesNumeric
```

Replace with:

```
  AND av.attribute_stable_id != 'VEUPATHDB_GENE_ID'
>templateTextEnd<


[templateStart]
name=cellularLocalizationAllDataGeneTableSql
anchorFile=ApiCommonModel/Model/lib/wdk/model/records/geneTableQueries.xml
prop=datasetName
prop=edaStudyStableId
prop=edaEntityAbbrev
prop=datasetDisplayName
prop=shortAttribution
>templateTextStart<
UNION
SELECT genes.string_value AS gene,
       '${datasetName}' AS dataset_presenter_id,
       '${datasetDisplayName}' AS dataset_presenter_display_name,
       '${shortAttribution}' AS short_attribution,
       ag.display_name AS variable,
       coalesce(av.string_value, coalesce(round(av.number_value::numeric, 4)::text, av.date_value::text)) AS value
FROM eda.attributevalue_${edaStudyStableId}_${edaEntityAbbrev} av,
     eda.attributegraph_${edaStudyStableId}_${edaEntityAbbrev} ag,
     (SELECT av.${edaEntityAbbrev}_stable_id, MIN(gi.gene) as string_value
      FROM eda.attributevalue_${edaStudyStableId}_${edaEntityAbbrev} av
      JOIN apidbtuning.GeneId gi ON gi.id = av.string_value
      WHERE av.attribute_stable_id = 'VEUPATHDB_GENE_ID'
      GROUP BY av.${edaEntityAbbrev}_stable_id) genes
WHERE av.attribute_stable_id = ag.stable_id
  AND av.${edaEntityAbbrev}_stable_id = genes.${edaEntityAbbrev}_stable_id
  AND av.attribute_stable_id != 'VEUPATHDB_GENE_ID'
>templateTextEnd<


[templateStart]
name=cellularLocalizationEdaAttributeQueriesNumeric
```

- [ ] **Step 2: Verify the file is structurally intact**

```bash
grep -c "templateStart" Model/lib/dst/cellularLocalization.dst
```

Expected: one more than before (was 8, now 9).

```bash
grep -n "cellularLocalizationAllDataGeneTableSql" Model/lib/dst/cellularLocalization.dst
```

Expected: two lines.

- [ ] **Step 3: Commit**

```bash
git add Model/lib/dst/cellularLocalization.dst
git commit -m "feat: add cellularLocalizationAllDataGeneTableSql template to cellularLocalization.dst"
```

---

### Task 3: Add `EdaPhenotypeDataTable` sqlQuery to geneTableQueries.xml

**Files:**
- Modify: `Model/lib/wdk/model/records/geneTableQueries.xml` (after line 4599, after `EdaCellularLocalizationGraphsDataTable` query)

- [ ] **Step 1: Insert the new sqlQuery element**

In `Model/lib/wdk/model/records/geneTableQueries.xml`, find the closing tag of `EdaCellularLocalizationGraphsDataTable` (around line 4599):

```xml
          <sqlQuery name="EdaCellularLocalizationGraphsDataTable" isCacheable="false" includeProjects="ToxoDB,TriTrypDB,UniDB">
```

Find the text immediately after that query ends:

```xml
     AND ga.org_abbrev IN (%%PARTITION_KEYS%%)
        ]]>
      </sql>
    </sqlQuery>


    <sqlQuery name="PhenotypeScoreGraphsDataTable"
```

Replace with:

```xml
     AND ga.org_abbrev IN (%%PARTITION_KEYS%%)
        ]]>
      </sql>
    </sqlQuery>


          <sqlQuery name="EdaPhenotypeDataTable" isCacheable="false"
                    includeProjects="ToxoDB,PlasmoDB,TriTrypDB,FungiDB,AmoebaDB,UniDB">
            <column name="source_id"/>
            <column name="project_id"/>
            <column name="dataset_presenter_id"/>
            <column name="dataset_presenter_display_name"/>
            <column name="short_attribution"/>
            <column name="variable"/>
            <column name="value"/>
            <sql>
            <![CDATA[
SELECT ga.source_id, ga.project_id, gd.dataset_presenter_id,
       gd.dataset_presenter_display_name, gd.short_attribution,
       gd.variable, gd.value
FROM webready.GeneAttributes_p ga, (
   WITH raw_data AS (
       SELECT '' AS gene,
              '' AS dataset_presenter_id,
              '' AS dataset_presenter_display_name,
              '' AS short_attribution,
              '' AS variable,
              '' AS value
       -- TEMPLATE_ANCHOR phenotypeAllDataGeneTableSql
   )
   SELECT rsog.ref_source_id AS gene, rd.dataset_presenter_id,
          rd.dataset_presenter_display_name, rd.short_attribution,
          rd.variable, rd.value
   FROM webready.RefSynOrthologousGenes_P rsog, raw_data rd
   WHERE rsog.source_id = rd.gene
     AND rsog.org_abbrev IN ('tgonGT1')
   UNION
   SELECT rd.gene, rd.dataset_presenter_id, rd.dataset_presenter_display_name,
          rd.short_attribution, rd.variable, rd.value
   FROM raw_data rd
) gd
WHERE ga.source_id = gd.gene
  AND ga.org_abbrev IN (%%PARTITION_KEYS%%)
ORDER BY gd.dataset_presenter_display_name, gd.variable, gd.value
        ]]>
      </sql>
    </sqlQuery>


    <sqlQuery name="PhenotypeScoreGraphsDataTable"
```

- [ ] **Step 2: Validate XML is well-formed**

```bash
xmllint --noout Model/lib/wdk/model/records/geneTableQueries.xml 2>&1
```

Expected: no output (no errors).

- [ ] **Step 3: Verify the new query is present**

```bash
grep -n "EdaPhenotypeDataTable\|phenotypeAllDataGeneTableSql" Model/lib/wdk/model/records/geneTableQueries.xml
```

Expected: lines showing the new `sqlQuery name` and the `TEMPLATE_ANCHOR` comment.

- [ ] **Step 4: Commit**

```bash
git add Model/lib/wdk/model/records/geneTableQueries.xml
git commit -m "feat: add EdaPhenotypeDataTable sqlQuery to geneTableQueries.xml"
```

---

### Task 4: Add `EdaCellularLocalizationDataTable` sqlQuery to geneTableQueries.xml

**Files:**
- Modify: `Model/lib/wdk/model/records/geneTableQueries.xml` (immediately after the `EdaPhenotypeDataTable` query added in Task 3)

- [ ] **Step 1: Insert the new sqlQuery element**

In `Model/lib/wdk/model/records/geneTableQueries.xml`, find the closing of `EdaPhenotypeDataTable` (the text added in Task 3):

```xml
ORDER BY gd.dataset_presenter_display_name, gd.variable, gd.value
        ]]>
      </sql>
    </sqlQuery>


    <sqlQuery name="PhenotypeScoreGraphsDataTable"
```

Replace with:

```xml
ORDER BY gd.dataset_presenter_display_name, gd.variable, gd.value
        ]]>
      </sql>
    </sqlQuery>


          <sqlQuery name="EdaCellularLocalizationDataTable" isCacheable="false"
                    includeProjects="ToxoDB,TriTrypDB,UniDB">
            <column name="source_id"/>
            <column name="project_id"/>
            <column name="dataset_presenter_id"/>
            <column name="dataset_presenter_display_name"/>
            <column name="short_attribution"/>
            <column name="variable"/>
            <column name="value"/>
            <sql>
            <![CDATA[
SELECT ga.source_id, ga.project_id, gd.dataset_presenter_id,
       gd.dataset_presenter_display_name, gd.short_attribution,
       gd.variable, gd.value
FROM webready.GeneAttributes_p ga, (
   SELECT '' AS gene,
          '' AS dataset_presenter_id,
          '' AS dataset_presenter_display_name,
          '' AS short_attribution,
          '' AS variable,
          '' AS value
   -- TEMPLATE_ANCHOR cellularLocalizationAllDataGeneTableSql
   ) gd
WHERE ga.source_id = gd.gene
  AND ga.org_abbrev IN (%%PARTITION_KEYS%%)
ORDER BY gd.dataset_presenter_display_name, gd.variable, gd.value
        ]]>
      </sql>
    </sqlQuery>


    <sqlQuery name="PhenotypeScoreGraphsDataTable"
```

- [ ] **Step 2: Validate XML is well-formed**

```bash
xmllint --noout Model/lib/wdk/model/records/geneTableQueries.xml 2>&1
```

Expected: no output.

- [ ] **Step 3: Verify both new queries are present**

```bash
grep -n "EdaPhenotypeDataTable\|EdaCellularLocalizationDataTable" Model/lib/wdk/model/records/geneTableQueries.xml
```

Expected: 4 lines total — one `sqlQuery name` and one `TEMPLATE_ANCHOR` for each.

- [ ] **Step 4: Commit**

```bash
git add Model/lib/wdk/model/records/geneTableQueries.xml
git commit -m "feat: add EdaCellularLocalizationDataTable sqlQuery to geneTableQueries.xml"
```

---

### Task 5: Add `EdaPhenotypeDataTable` table definition to geneRecord.xml

**Files:**
- Modify: `Model/lib/wdk/model/records/geneRecord.xml` (after line 813, after `EdaCellularLocalizationGraphsDataTable` table)

- [ ] **Step 1: Insert the new table definition**

In `Model/lib/wdk/model/records/geneRecord.xml`, find the closing of `EdaCellularLocalizationGraphsDataTable`:

```xml
         <table name="EdaCellularLocalizationGraphsDataTable"
               inReportMaker="false"
                displayName="Cellular Localization Graphs Data Table"
                includeProjects="ToxoDB,TriTrypDB,UniDB"
                queryRef="GeneTables.EdaCellularLocalizationGraphsDataTable" >
            <columnAttribute name="dataset_id" displayName="Dataset" internal="true" />
            <columnAttribute name="variable" displayName="Variable"/>
            <columnAttribute name="value" displayName="Value"/>
          </table>


         <table name="PhenotypeScoreGraphsDataTable"
```

Replace with:

```xml
         <table name="EdaCellularLocalizationGraphsDataTable"
               inReportMaker="false"
                displayName="Cellular Localization Graphs Data Table"
                includeProjects="ToxoDB,TriTrypDB,UniDB"
                queryRef="GeneTables.EdaCellularLocalizationGraphsDataTable" >
            <columnAttribute name="dataset_id" displayName="Dataset" internal="true" />
            <columnAttribute name="variable" displayName="Variable"/>
            <columnAttribute name="value" displayName="Value"/>
          </table>


         <table name="EdaPhenotypeDataTable"
                displayName="Phenotype Data"
                inReportMaker="false"
                includeProjects="ToxoDB,PlasmoDB,TriTrypDB,FungiDB,AmoebaDB,UniDB"
                queryRef="GeneTables.EdaPhenotypeDataTable">
            <columnAttribute name="dataset_presenter_id" displayName="Dataset ID" internal="true"/>
            <columnAttribute name="dataset_presenter_display_name" displayName="Dataset" internal="true"/>
            <columnAttribute name="short_attribution" displayName="Attribution"/>
            <columnAttribute name="variable" displayName="Variable"/>
            <columnAttribute name="value" displayName="Value"/>
            <linkAttribute displayName="Dataset" name="presenter_link" internal="false">
              <displayText>
                <![CDATA[$$dataset_presenter_display_name$$]]>
              </displayText>
              <url>
                <![CDATA[@LEGACY_WEBAPP_BASE_URL@/app/record/dataset/$$dataset_presenter_id$$]]>
              </url>
            </linkAttribute>
          </table>


         <table name="PhenotypeScoreGraphsDataTable"
```

- [ ] **Step 2: Validate XML**

```bash
xmllint --noout Model/lib/wdk/model/records/geneRecord.xml 2>&1
```

Expected: no output.

- [ ] **Step 3: Verify the table is present**

```bash
grep -n "EdaPhenotypeDataTable" Model/lib/wdk/model/records/geneRecord.xml
```

Expected: lines for `table name`, `queryRef`, and column/link attributes.

- [ ] **Step 4: Commit**

```bash
git add Model/lib/wdk/model/records/geneRecord.xml
git commit -m "feat: add EdaPhenotypeDataTable table definition to geneRecord.xml"
```

---

### Task 6: Add `EdaCellularLocalizationDataTable` table definition to geneRecord.xml

**Files:**
- Modify: `Model/lib/wdk/model/records/geneRecord.xml` (immediately after `EdaPhenotypeDataTable` added in Task 5)

- [ ] **Step 1: Insert the new table definition**

In `Model/lib/wdk/model/records/geneRecord.xml`, find the closing of `EdaPhenotypeDataTable` (added in Task 5):

```xml
            </linkAttribute>
          </table>


         <table name="PhenotypeScoreGraphsDataTable"
```

Replace with:

```xml
            </linkAttribute>
          </table>


         <table name="EdaCellularLocalizationDataTable"
                displayName="Cellular Localization Data"
                inReportMaker="false"
                includeProjects="ToxoDB,TriTrypDB,UniDB"
                queryRef="GeneTables.EdaCellularLocalizationDataTable">
            <columnAttribute name="dataset_presenter_id" displayName="Dataset ID" internal="true"/>
            <columnAttribute name="dataset_presenter_display_name" displayName="Dataset" internal="true"/>
            <columnAttribute name="short_attribution" displayName="Attribution"/>
            <columnAttribute name="variable" displayName="Variable"/>
            <columnAttribute name="value" displayName="Value"/>
            <linkAttribute displayName="Dataset" name="presenter_link" internal="false">
              <displayText>
                <![CDATA[$$dataset_presenter_display_name$$]]>
              </displayText>
              <url>
                <![CDATA[@LEGACY_WEBAPP_BASE_URL@/app/record/dataset/$$dataset_presenter_id$$]]>
              </url>
            </linkAttribute>
          </table>


         <table name="PhenotypeScoreGraphsDataTable"
```

- [ ] **Step 2: Validate XML**

```bash
xmllint --noout Model/lib/wdk/model/records/geneRecord.xml 2>&1
```

Expected: no output.

- [ ] **Step 3: Verify both new tables are present**

```bash
grep -n "EdaPhenotypeDataTable\|EdaCellularLocalizationDataTable" Model/lib/wdk/model/records/geneRecord.xml
```

Expected: multiple lines for each — `table name`, `queryRef`, `linkAttribute`.

- [ ] **Step 4: Commit**

```bash
git add Model/lib/wdk/model/records/geneRecord.xml
git commit -m "feat: add EdaCellularLocalizationDataTable table definition to geneRecord.xml"
```

---

### Task 7: Add ontology entries to individuals.txt

**Files:**
- Modify: `Model/lib/wdk/ontology/individuals.txt`

The file uses tab-separated columns. The column layout is:
```
<full-id>  <ontology-url>  <category>  <record-class>  <type>  <table-name>  <empty>  <empty>  <empty>  gene  <empty>  <scope1>  [<scope2>]
```

- [ ] **Step 1: Add the cellular localization entry after line 224**

In `Model/lib/wdk/ontology/individuals.txt`, find the line for `EdaCellularLocalizationGraphsDataTable` (line 224):

```
GeneRecordClasses.GeneRecordClass.EdaCellularLocalizationGraphsDataTable	http://edamontology.org/topic_0140	Protein targeting and localization	GeneRecordClasses.GeneRecordClass	table	EdaCellularLocalizationGraphsDataTable				gene		record-internal	download
```

Replace with (adding the new entry immediately after):

```
GeneRecordClasses.GeneRecordClass.EdaCellularLocalizationGraphsDataTable	http://edamontology.org/topic_0140	Protein targeting and localization	GeneRecordClasses.GeneRecordClass	table	EdaCellularLocalizationGraphsDataTable				gene		record-internal	download
GeneRecordClasses.GeneRecordClass.EdaCellularLocalizationDataTable	http://edamontology.org/topic_0140	Protein targeting and localization	GeneRecordClasses.GeneRecordClass	table	EdaCellularLocalizationDataTable				gene		record	download
```

**Important:** The separator between columns is a literal tab character (`\t`), not spaces. Use your editor's tab insertion, not spaces.

- [ ] **Step 2: Add the phenotype entry after the `EdaPhenotypeGraphsDataTable` line**

In `Model/lib/wdk/ontology/individuals.txt`, find the line for `EdaPhenotypeGraphsDataTable` (now around line 265 after the previous insert):

```
GeneRecordClasses.GeneRecordClass.EdaPhenotypeGraphsDataTable	http://edamontology.org/topic_3298	phenotype	GeneRecordClasses.GeneRecordClass	table	EdaPhenotypeGraphsDataTable				gene		record-internal	download
```

Replace with:

```
GeneRecordClasses.GeneRecordClass.EdaPhenotypeGraphsDataTable	http://edamontology.org/topic_3298	phenotype	GeneRecordClasses.GeneRecordClass	table	EdaPhenotypeGraphsDataTable				gene		record-internal	download
GeneRecordClasses.GeneRecordClass.EdaPhenotypeDataTable	http://edamontology.org/topic_3298	phenotype	GeneRecordClasses.GeneRecordClass	table	EdaPhenotypeDataTable				gene		record	download
```

- [ ] **Step 3: Verify both entries are present and use tabs**

```bash
grep "EdaPhenotypeDataTable\|EdaCellularLocalizationDataTable" Model/lib/wdk/ontology/individuals.txt | cat -A | head -5
```

Expected: both lines appear, each column separated by `^I` (tab character), ending with `record^Idownload$`.

- [ ] **Step 4: Commit**

```bash
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "feat: add ontology entries for EdaPhenotypeDataTable and EdaCellularLocalizationDataTable"
```

---

### Task 8: Update `PhenotypeEDAStudy.java` in EbrcModelCommon

**Files:**
- Modify: `EbrcModelCommon/Model/src/main/java/org/apidb/apicommon/model/datasetInjector/PhenotypeEDAStudy.java`

Full path: `/home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon/Model/src/main/java/org/apidb/apicommon/model/datasetInjector/PhenotypeEDAStudy.java`

> **Note:** This file is in a different repo (`EbrcModelCommon`). Create a feature branch before editing:
> ```bash
> cd /home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon
> git checkout -b eda-all-data-tables
> ```

- [ ] **Step 1: Add template injection in `injectTemplates()`**

Find:

```java
        injectTemplate("phenotypeDataTableGeneTableSql");
        injectTemplate("phenotypeEdaAttributeQueriesNumeric");
```

Replace with:

```java
        injectTemplate("phenotypeDataTableGeneTableSql");
        injectTemplate("phenotypeAllDataGeneTableSql");
        injectTemplate("phenotypeEdaAttributeQueriesNumeric");
```

- [ ] **Step 2: Add model reference in `addModelReferences()`**

Find:

```java
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaPhenotypeGraphsDataTable");
    }
```

Replace with:

```java
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaPhenotypeGraphsDataTable");
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaPhenotypeDataTable");
    }
```

- [ ] **Step 3: Verify the file compiles**

```bash
cd /home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon
mvn compile -pl Model -am -q 2>&1 | tail -20
```

Expected: `BUILD SUCCESS` with no errors.

- [ ] **Step 4: Commit in EbrcModelCommon**

```bash
cd /home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon
git add Model/src/main/java/org/apidb/apicommon/model/datasetInjector/PhenotypeEDAStudy.java
git commit -m "feat: inject phenotypeAllDataGeneTableSql and add EdaPhenotypeDataTable model reference"
```

---

### Task 9: Update `CellularLocalizationEDAStudy.java` in EbrcModelCommon

**Files:**
- Modify: `EbrcModelCommon/Model/src/main/java/org/apidb/apicommon/model/datasetInjector/CellularLocalizationEDAStudy.java`

Full path: `/home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon/Model/src/main/java/org/apidb/apicommon/model/datasetInjector/CellularLocalizationEDAStudy.java`

> **Note:** Should be on the `eda-all-data-tables` branch created in Task 8.

- [ ] **Step 1: Add template injection in `injectTemplates()`**

Find:

```java
        injectTemplate("cellularLocalizationDataTableGeneTableSql");
        injectTemplate("cellularLocalizationEdaAttributeQueriesNumeric");
```

Replace with:

```java
        injectTemplate("cellularLocalizationDataTableGeneTableSql");
        injectTemplate("cellularLocalizationAllDataGeneTableSql");
        injectTemplate("cellularLocalizationEdaAttributeQueriesNumeric");
```

- [ ] **Step 2: Add model reference in `addModelReferences()`**

Find:

```java
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaCellularLocalizationGraphsDataTable");
    }
```

Replace with:

```java
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaCellularLocalizationGraphsDataTable");
        addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaCellularLocalizationDataTable");
    }
```

- [ ] **Step 3: Verify the file compiles**

```bash
cd /home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon
mvn compile -pl Model -am -q 2>&1 | tail -20
```

Expected: `BUILD SUCCESS` with no errors.

- [ ] **Step 4: Commit in EbrcModelCommon**

```bash
cd /home/jbrestel/workspaces/dataLoad/project_home/EbrcModelCommon
git add Model/src/main/java/org/apidb/apicommon/model/datasetInjector/CellularLocalizationEDAStudy.java
git commit -m "feat: inject cellularLocalizationAllDataGeneTableSql and add EdaCellularLocalizationDataTable model reference"
```

---

## Functional Testing (post-deploy)

After deploying both repos to a dev instance:

1. Navigate to a gene record page in ToxoDB for a gene known to have phenotype data (e.g., TGGT1_248070 in T. gondii GT1).
2. Verify the **Phenotype Data** table appears in the Phenotype section of the gene record.
3. Confirm rows show: a clickable dataset name (linking to the dataset page), attribution, variable, and value.
4. Confirm rows are sorted by dataset name → variable → value.
5. Repeat for a TriTrypDB gene with LOPIT data to verify **Cellular Localization Data** table.
6. Verify the tables appear in gene downloads (check download tool for both tables).
7. Spot-check that existing **Phenotype Graphs Data Table** and **Cellular Localization Graphs Data Table** are unaffected.
