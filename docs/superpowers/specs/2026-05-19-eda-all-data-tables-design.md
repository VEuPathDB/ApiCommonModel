# EDA All-Data Tables: EdaPhenotypeDataTable & EdaCellularLocalizationDataTable

## Overview

Add two new WDK data tables to the gene record page — one for all phenotype EDA variable/value data and one for all cellular localization EDA variable/value data. These tables cover all datasets in their respective categories, including datasets that lack graph configuration. They are intentionally redundant with the existing `EdaPhenotypeGraphsDataTable` and `EdaCellularLocalizationGraphsDataTable` sub-tables, which back graph rendering and are untouched.

Each table exposes: a linked dataset name (to the dataset record page), short attribution, variable, and value. Rows are sorted by dataset display name → variable → value.

## Motivation

Additional EDA datasets exist for both phenotype and cellular localization that have variable/value data but are not suitable for graphs. The existing graph data sub-tables only cover graph-backed datasets. A single unified "all data" table per category is preferred over a separate table per dataset (the Rodent Malaria anti-pattern).

## Files Changed (7 total)

| File | Change |
|---|---|
| `Model/lib/dst/phenotype.dst` | Add `phenotypeAllDataGeneTableSql` template |
| `Model/lib/dst/cellularLocalization.dst` | Add `cellularLocalizationAllDataGeneTableSql` template |
| `Model/lib/wdk/model/records/geneTableQueries.xml` | Add `EdaPhenotypeDataTable` and `EdaCellularLocalizationDataTable` sqlQuery elements |
| `Model/lib/wdk/model/records/geneRecord.xml` | Add `EdaPhenotypeDataTable` and `EdaCellularLocalizationDataTable` table definitions with linkAttribute |
| `Model/lib/wdk/ontology/individuals.txt` | Add ontology entries for both new tables with `record` and `download` scope |
| `EbrcModelCommon/Model/src/main/java/.../PhenotypeEDAStudy.java` | Inject new template + add model reference |
| `EbrcModelCommon/Model/src/main/java/.../CellularLocalizationEDAStudy.java` | Inject new template + add model reference |

## Template SQL (.dst files)

Both templates mirror the existing `phenotypeDataTableGeneTableSql` / `cellularLocalizationDataTableGeneTableSql` but add `dataset_presenter_id`, `dataset_presenter_display_name`, and `short_attribution` as literal columns from template props. The `value` coalesce is applied in the template (not the outer query) so the raw string/number/date columns are not exposed.

### phenotype.dst — new template

```
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

Note: no ORDER BY in the template — it belongs on the outer query in geneTableQueries.xml.
```

### cellularLocalization.dst — new template

Identical to above with name `cellularLocalizationAllDataGeneTableSql`.

## WDK Queries (geneTableQueries.xml)

### EdaPhenotypeDataTable

- `includeProjects="ToxoDB,PlasmoDB,TriTrypDB,FungiDB,AmoebaDB,UniDB"`
- Includes the ME49 gene remapping CTE via `RefSynOrthologousGenes_P` (same as existing phenotype graph data table)
- TEMPLATE_ANCHOR: `phenotypeAllDataGeneTableSql`
- Columns: `source_id`, `project_id`, `dataset_presenter_id`, `dataset_presenter_display_name`, `short_attribution`, `variable`, `value`
- Stub row uses empty strings / sentinel values (matching existing pattern)

```xml
<sqlQuery name="EdaPhenotypeDataTable" isCacheable="false"
          includeProjects="ToxoDB,PlasmoDB,TriTrypDB,FungiDB,AmoebaDB,UniDB">
  <column name="source_id"/>
  <column name="project_id"/>
  <column name="dataset_presenter_id"/>
  <column name="dataset_presenter_display_name"/>
  <column name="short_attribution"/>
  <column name="variable"/>
  <column name="value"/>
  <sql><![CDATA[
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
   WHERE rsog.source_id = rd.gene AND rsog.org_abbrev IN ('tgonGT1')
   UNION
   SELECT rd.gene, rd.dataset_presenter_id, rd.dataset_presenter_display_name,
          rd.short_attribution, rd.variable, rd.value
   FROM raw_data rd
) gd
WHERE ga.source_id = gd.gene
  AND ga.org_abbrev IN (%%PARTITION_KEYS%%)
ORDER BY gd.dataset_presenter_display_name, gd.variable, gd.value
  ]]></sql>
</sqlQuery>
```

### EdaCellularLocalizationDataTable

- `includeProjects="ToxoDB,TriTrypDB,UniDB"`
- No ME49 remapping CTE (matching existing cellular localization graph data table)
- TEMPLATE_ANCHOR: `cellularLocalizationAllDataGeneTableSql`
- Same columns as phenotype table

## WDK Table Definitions (geneRecord.xml)

### EdaPhenotypeDataTable

```xml
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
    <displayText><![CDATA[$$dataset_presenter_display_name$$]]></displayText>
    <url><![CDATA[@LEGACY_WEBAPP_BASE_URL@/app/record/dataset/$$dataset_presenter_id$$]]></url>
  </linkAttribute>
</table>
```

### EdaCellularLocalizationDataTable

Identical structure with `includeProjects="ToxoDB,TriTrypDB,UniDB"` and `displayName="Cellular Localization Data"`.

## Ontology (individuals.txt)

Two new tab-delimited entries, placed near their existing counterparts (lines ~224 and ~264):

```
GeneRecordClasses.GeneRecordClass.EdaPhenotypeDataTable	http://edamontology.org/topic_3298	phenotype	GeneRecordClasses.GeneRecordClass	table	EdaPhenotypeDataTable				gene		record	download

GeneRecordClasses.GeneRecordClass.EdaCellularLocalizationDataTable	http://edamontology.org/topic_0140	Protein targeting and localization	GeneRecordClasses.GeneRecordClass	table	EdaCellularLocalizationDataTable				gene		record	download
```

## Injector Changes

### PhenotypeEDAStudy.java

In `injectTemplates()`, add after the existing `phenotypeDataTableGeneTableSql` inject:
```java
injectTemplate("phenotypeAllDataGeneTableSql");
```

In `addModelReferences()`, add:
```java
addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaPhenotypeDataTable");
```

### CellularLocalizationEDAStudy.java

In `injectTemplates()`, add after the existing `cellularLocalizationDataTableGeneTableSql` inject:
```java
injectTemplate("cellularLocalizationAllDataGeneTableSql");
```

In `addModelReferences()`, add:
```java
addWdkReference("GeneRecordClasses.GeneRecordClass", "table", "EdaCellularLocalizationDataTable");
```

## Data Source

Datasets are identified via `apidb.datasource.type IN ('phenotype', 'cellularLocalization')`. The TEMPLATE_ANCHOR mechanism drives per-dataset SQL generation — the injectors are called for each dataset presenter that uses `PhenotypeEDAStudy` or `CellularLocalizationEDAStudy`, so only datasets wired to those injectors will contribute rows.

## Sorting

Sorting (dataset display name → variable → value) is applied via `ORDER BY` at the end of the outer `sqlQuery` SQL in `geneTableQueries.xml`. ORDER BY cannot appear inside a UNION piece, so it is not in the template.
