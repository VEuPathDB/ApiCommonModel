# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ApiCommonModel is a VEuPathDB genomic data model repository that extends EbrcModelCommon. It defines WDK (Workbench Development Kit) model XML files for basic data types, structured searches, and records for genomic sites serving Apicomplexan and other parasitic organisms across 15+ specialized databases (PlasmoDB, ToxoDB, CryptoDB, TriTrypDB, etc.).

## Build System

This project uses both **Ant** and **Maven** for building:

### Ant Build (Primary)
```bash
# Full installation (requires GUS_HOME and PROJECT_HOME environment variables)
bld ApiCommonModel

# Verify installation
wdkXml -model $MODEL_NAME
```

The Ant build system imports dependencies from WDK, CBIL, ReFlow, and EbrcModelCommon projects. Changes to WDK model XML files require reloading the Tomcat instance.

### Maven Build
```bash
# Build all modules
mvn clean install

# Build specific module
cd Model && mvn clean install
cd Test && mvn test
```

The project has three Maven modules:
- **Model** (api-common-model-model): Core Java code and WDK model XML
- **DatasetPresenter** (api-common-model-datasetpresenter): Dataset metadata presentation
- **Test** (api-common-model-test): Integration tests

### Prerequisites
- yarn / npm / ant / maven
- WEBAPP_PROP_FILE with property: `webappTargetDir=BLAH`
- Environment variables: `GUS_HOME` and `PROJECT_HOME`
- Dependencies: WDK, CBIL, ReFlow, EbrcModelCommon

## Architecture

### Three-Layer Data Model System

1. **Static WDK XML Layer** (Model/lib/wdk/)
   - Core record definitions (genes, transcripts, organisms, pathways, SNPs)
   - Search definitions (questions) organized by data type
   - Query definitions for attributes, tables, and summaries
   - Multi-project support using `includeProjects` attributes for site-specific content

2. **Dynamic Dataset Injection Layer** (Java datasetInjector classes)
   - Reads dataset metadata from database at build time
   - Uses .dst template files (Model/lib/dst/) to generate WDK XML
   - Creates searches and parameters for experiments without code changes
   - Site-specific injectors in custom/ packages (PlasmoDB, ToxoDB, etc.)

3. **Query Optimization Layer** (Tuning Manager)
   - Pre-computes expensive joins into materialized tables
   - Creates unpartitioned copies of partitioned organism data
   - Builds specialized lookup tables with targeted indexes
   - Configuration: Model/lib/xml/tuningManager/apiTuningManager.xml

### Key Java Packages

**org.apidb.apicommon.model.datasetInjector** (70+ classes)
- Template injection system for dynamically generating WDK model XML
- Base classes: AnnotatedGenome, UnannotatedGenome, Expression, RNASeq, Proteomics
- **custom/** subdirectory: Site-specific injectors for 10+ databases
  - Each database has specialized handlers (e.g., PlasmoDB has 38 custom injectors)
- Pattern: Dataset metadata (DB) + Template (.dst) → Generated WDK XML

**org.apidb.apicommon.model.report** (10+ classes)
- Custom exporters: GenBankReporter, Gff3Reporter, Gff3Dumper
- Data export utilities: DetailTableLoader, FullRecordFileCreator
- Referenced in WDK XML `<reporter>` elements

**org.apidb.apicommon.model.userdataset** (5 classes)
- Type handlers for user-uploaded datasets
- BigwigFilesTypeHandler, VCFFilesTypeHandler, GeneListTypeHandler, RnaSeqTypeHandler
- Integrates user data into search and JBrowse

### WDK Model Structure (Model/lib/wdk/)

**apiCommonModel.xml** (root, ~560 lines)
- Imports all subordinate XML files
- Defines project-specific constants (release dates, default genes/genomes)
- Configures column tool bundles

**model/records/** (~23,400 lines total)
- Core record definitions with associated queries:
  - geneRecord.xml, transcriptRecord.xml
  - genomicRecords.xml, organismRecords.xml
  - pathwayRecord.xml, compoundRecord.xml, snpRecords.xml
- Each record has: *AttributeQueries.xml, *TableQueries.xml, *SummaryQueries.xml

**model/questions/** (~11,786 lines total)
- Search definitions by data type
- **queries/** subdirectory: SQL query definitions
- **params/** subdirectory: Search parameter definitions
- categories.xml: User-facing search organization

### Data Partitioning

Database tables are partitioned by organism for performance (PostgreSQL partitioning):
- Gene/transcript attributes partitioned tables: GeneAttributes_p, TranscriptAttributes_p
- Webready schema scripts: Model/lib/psql/webready/
- Tuning manager creates unpartitioned copies for cross-organism queries

### Scripting Languages

**Perl** (primary, 21+ scripts in Model/bin/)
- Tuning table builders: buildPubmedTT, buildGbrowseImageUrlTT, buildSpliceSitesTT, buildStringdbTT
- Data validation: checkBlastFiles.pl, checkMicroarraySamples.pl, checkRNASeqSamples.pl
- JBrowse configuration: Model/lib/perl/JBrowseUtil.pm, JBrowseTrackConfig/*.pm
- Dataset utilities: Model/lib/perl/DataSourceAttributions.pm

**Python** (User Dataset Dashboard - Model/ud_dashboard/)
- Administrative dashboard for monitoring user-uploaded datasets
- Modules: dashboard.py, dataset.py, user.py, workspace.py, event.py
- Database interfaces: appdb.py, oracle.py

**Bash**
- apiModelSpellCheck: WDK model XML validation
- convert2webready: Database schema conversion utilities

### JBrowse Configuration (Model/lib/jbrowse/)

- **common/**: Shared track configurations
- **50+ organism directories**: Each contains tracks.conf (e.g., pfal3D7/, tgonME49/)
- Generated dynamically by Perl scripts using database queries
- Query definitions: Model/lib/xml/jbrowse/genomeQueries.xml (~157KB), proteinQueries.xml

## Common Development Workflows

### Validating WDK Model XML
```bash
apiModelSpellCheck
wdkXml -model $MODEL_NAME
```

### Working with Dataset Injectors

When adding support for a new dataset type:
1. Create/modify .dst template in Model/lib/dst/
2. Create Java class in org.apidb.apicommon.model.datasetInjector
3. For site-specific behavior, extend in custom/<project>/ package
4. Dataset metadata should be in database (study schema)
5. Rebuild project: `bld ApiCommonModel`

### Modifying WDK Queries

- SQL queries are embedded in XML with `<sql>` blocks
- Partitioned table references use _p suffix (e.g., GeneAttributes_p)
- Use @MACRO_NAME@ for tuning manager substitutions
- Test queries: `wdkQuery -model $MODEL_NAME -query QueryName`

### Tuning Table Management

Tuning tables are defined in Model/lib/xml/tuningManager/apiTuningManager.xml:
- External dependencies: reference webready partitioned tables
- Internal dependencies: derived tables built from external ones
- SQL snippets use `&1` placeholder for instance-specific table naming
- tablePruning.txt specifies which tables to drop/rebuild

### Multi-Project Development

This single codebase supports 15+ databases:
- Use `includeProjects="PlasmoDB,ToxoDB,..."` attributes in XML
- Site-specific code goes in custom/<project>/ packages
- Test across multiple projects before committing

## Testing

```bash
# Run all tests
mvn test

# Run specific test
cd Test
mvn test -Dtest=DiscoverableDatasetInjectorTest
```

Primary test: Test/src/main/java/org/apidb/apicommon/test/datasetPresenter/DiscoverableDatasetInjectorTest.java

## Important Notes

- **WDK Model Reload**: After XML changes, Tomcat instance must be reloaded
- **Partitioned Tables**: Always use _p suffix when referencing organism-specific data
- **Dataset Injection**: Datasets are database-driven, not code-driven
- **Multi-Project Support**: Test XML changes with includeProjects to ensure compatibility
- **Performance**: Expensive queries should be materialized in tuning manager configuration
