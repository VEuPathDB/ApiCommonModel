# `VariationsByIsolateGroup` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `VariationsByIsolateGroup` — an HSSS `processQuery` search on the `variation` record that finds loci polymorphic within a user-chosen group of samples — plus the reusable EDA-driven param machinery the three remaining HSSS variation searches will share.

**Architecture:** Declarative WDK model XML only, in `ApiCommonModel`. Three new vocabulary queries (one organism tree, one hidden EDA-suffix lookup, two EDA filter queries), four params copied out of the dead `snpParams.xml`, one `processQuery` bound to `FindPolymorphismsPlugin`, one question, one category-ontology row. The Java side (`ApiCommonWebService`) is already done and is *consumed* here, not modified. The design is `docs/superpowers/specs/2026-08-05-variations-by-isolate-group-design.md` — read it; this plan implements it and does not restate its reasoning.

**Tech Stack:** WDK model XML; PostgreSQL (`unidb_shu_a`); the `agentic-veupath-dev` control plane (`bin/veup-build.sh`, `bin/veup-logs.sh`) for remote builds on `cedar`; Claude in Chrome for browser verification.

---

## Orientation for someone with no context

Read this section before Task 1. It is the minimum you need to not waste an hour.

**Where you are working.** Two directories matter:

| | |
|---|---|
| `~/workspaces/plasmodb/ApiCommonModel` | the repo you edit. Branch **`dnaseq-merge-experiments`**. Never `main`. |
| `~/workspaces/agentic-veupath-dev` | the control plane. Run `bin/veup-*.sh` from **here**, not from the model repo. |

Your local edits reach the webserver (`cedar`) through a `mutagen` one-way sync that is already running. You do not scp anything. You do not build locally. Builds run on cedar via `bin/veup-build.sh`.

**There are no unit tests for WDK model XML.** Do not go looking for a test framework; there isn't one that covers this. TDD still applies, but the "test" is one of three concrete things, and every task below names which one it uses:

1. **`psql`** — for a task that adds SQL. Run the SQL against the real database *before* putting it in XML. This is the strongest check available and it is fast.
2. **`wb ontology`** (remote build) — proves the model *loads*: every `paramRef`, `queryRef`, and `recordClassRef` resolves, and the category OWL regenerates. A model error here is a hard failure with a stack trace.
3. **`wdkXml -model PlasmoDB`** — dumps the *assembled* model. This is how you prove a param or question is actually present for this project, as opposed to present in a file.

**Database access.** Read-only. Every query in this plan is a `SELECT`.

```bash
psql -h localhost -p 5432 -d unidb_shu_a
```

> **Never** `INSERT`, `UPDATE`, `DELETE`, `ALTER`, or index anything in any schema other than `jbrestel`. Every step in this plan is a `SELECT`; if you find yourself wanting to write, stop and ask.

**Remote commands.** Two forms you will use repeatedly:

```bash
# from ~/workspaces/agentic-veupath-dev — build on cedar (flags BEFORE the name, always)
bin/veup-build.sh plasmodb wb ontology

# from anywhere — dump the assembled model
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"'
```

> **Flags come before the profile name.** `bin/veup-build.sh plasmodb wb model --dry-run` silently drops the flag **and runs for real**. A real dry run prints `DRYRUN:`-prefixed lines. If you don't see them, it executed.

**The `$$param$$` syntax.** This codebase interpolates params into SQL as `$$paramName$$` (double dollar), not `$paramName$`. Check `variationQueries.xml` if you doubt it. Getting this wrong produces SQL that runs but ignores the param.

**Two things that will bite you if you skip them:**

- **`wb ontology`, never `wb model`, once Task 8 lands.** A categorization change leaves the OWL stale with **no error anywhere** — the search exists in the model and is invisible or misfiled in the menu. `wb ontology` is a superset of `wb model`; run it alone.
- **The autologin trap.** An unauthenticated dev tab bounces to `veupathdb.org` and *stays there*, so a relative `fetch('/service/...')` answers for **production** and returns confident wrong answers. Before trusting any browser fetch, check `window.location.origin` is `https://jbrestel.plasmodb.org`. The app lives under `/a/` — `/a/app`, `/a/service`.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `Model/lib/wdk/apiCommonModel.xml` | Modify line 28 | `buildNumber` 70 → 71 (Task 1, own commit) |
| `Model/lib/wdk/model/questions/params/organismParams.xml` | Add one `sqlQuery` to the existing `organismVQ` querySet (after line 589) | the organism tree vocabulary, filtered to organisms with dnaseq isolate data (Task 2) |
| `Model/lib/wdk/model/questions/params/variationParams.xml` | Add a new `querySet VariationVQ` + five params to the existing `variationParams` paramSet | all variation-search params and their vocabulary queries (Tasks 3–5) |
| `Model/lib/wdk/model/questions/queries/variationQueries.xml` | Add one `processQuery` to the existing `VariationsBy` querySet | the HSSS plugin binding (Task 6) |
| `Model/lib/wdk/model/questions/variationQuestions.xml` | Add one `question` to the existing `VariationQuestions` questionSet | the user-facing search (Task 7) |
| `Model/lib/wdk/ontology/individuals.txt` | Append one row | category-tree placement (Task 8) |

Vocabulary queries live in the **params** file, not the queries file — that is this codebase's convention (`SnpVQ` is in `snpParams.xml`, `organismVQ` is in `organismParams.xml`). Follow it.

---

### Task 1: Bump `buildNumber` 70 → 71

The HSSS variation files exist only under `build-71`. `WebServicesPath` (Task 5) resolves to a path containing `%%buildNumber%%`. This is a constant shared by 14 projects and referenced 43 times, so it gets **its own commit** — see design §6.

**Files:**
- Modify: `Model/lib/wdk/apiCommonModel.xml:28`

- [ ] **Step 1: Confirm the files you are pointing at exist, and the ones you are pointing away from still do**

```bash
ssh cedar 'ls -d /var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-71/Pfalciparum3D7/dnaseq \
                 /var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-70/Pfalciparum3D7/dnaseq 2>&1'
```

Expected: `build-71/...` listed; `build-70/...` reports `No such file or directory`. That asymmetry *is* the reason for this task. If `build-71` is missing, stop — nothing downstream can work.

- [ ] **Step 2: Make the change**

`Model/lib/wdk/apiCommonModel.xml` line 28, change the value from `70` to `71`:

```xml
  <constant name="buildNumber" includeProjects="AmoebaDB,CryptoDB,GiardiaDB,HostDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,ToxoDB,TrichDB,TriTrypDB,VectorBase,EuPathDB,UniDB">71</constant>
```

Leave the `InitDB` constant on the next line at `0`. Leave every `releaseDate` alone.

- [ ] **Step 3: Verify exactly one line changed**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && git diff --stat && git diff Model/lib/wdk/apiCommonModel.xml
```

Expected: `1 file changed, 1 insertion(+), 1 deletion(-)`, and the diff shows only `>70<` → `>71<` on the `buildNumber` constant.

- [ ] **Step 4: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/apiCommonModel.xml
git commit -m "Point buildNumber at build-71 webservices files

The HSSS variation files (<org>/dnaseq/readFreq{20,40,60,80}) exist only
under build-71; build-70 has no dnaseq directory at all. buildNumber is a
model-wide constant feeding every webservices path, so this is its own
commit: anyone bisecting a webservices-path problem needs to see it.

Checked rather than assumed: build-71 is a superset of build-70 (1545
organism directories vs 1527) and is present for every ApiCommon project,
so the searches already reading these files do not lose their inputs.
Same motivation as 8ff801f03, which moved 68 -> 69."
```

---

### Task 2: `organismVQ.withVariationsTree` — the organism vocabulary

The existing `organismVQ.withNgsSNPsTree` reads `apidbtuning.snpstrains`, **which does not exist in this build**. So this is a rewrite, not a copy. Design §4.1.

**Files:**
- Modify: `Model/lib/wdk/model/questions/params/organismParams.xml` (insert after line 589, the close of `withNgsSNPsTree`)

- [ ] **Step 1: Run the SQL against the database first — this is the test**

The model substitutes `@PROJECT_ID@` at load time. Run it with the substitution done by hand, as PlasmoDB:

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
WITH FilterQuery AS (
  SELECT DISTINCT tn.name AS organism
  FROM apidb.datasource ds
  JOIN apidb.organism o  ON o.taxon_id = ds.taxon_id
  JOIN sres.taxonname tn ON tn.taxon_id = o.taxon_id AND tn.name_class = 'scientific name'
  WHERE ds.type = 'isolates' AND ds.subtype = 'Dna_Seq'
)
SELECT DISTINCT ot.term, ot.parentterm,
       CASE WHEN ot.term = ot.organism THEN ot.term ELSE '-1' END AS internal
FROM apidbtuning.organismtree ot
JOIN FilterQuery fq ON fq.organism = ot.organism
WHERE (ot.project_id = 'PlasmoDB' OR 'UniDB' = 'PlasmoDB')
ORDER BY ot.parentterm, ot.term"
```

Expected: **7 rows** — exactly one with `internal = 'Plasmodium falciparum 3D7'` (the selectable leaf) and six with `internal = '-1'` (branch nodes). If the leaf is absent, the dropdown will be unusable and nothing downstream works; stop and investigate before writing XML.

- [ ] **Step 2: Confirm the filter predicate is the right one**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
SELECT type, subtype, count(*) FROM apidb.datasource
WHERE lower(name) LIKE '%dnaseq%' GROUP BY type, subtype"
```

Expected: one row, `isolates | Dna_Seq | 10`. This is why the query filters on the declared `type`/`subtype` rather than on `lower(name) LIKE '%dnaseq%'` — a declared category beats a string convention, and here they agree exactly.

- [ ] **Step 3: Add the query**

Insert into `organismParams.xml` immediately after the closing `</sqlQuery>` of `withNgsSNPsTree` (line 589), inside the `organismVQ` querySet:

```xml
    <!--============================-->
    <!-- with Variations (dnaseq)   -->
    <!--============================-->

    <!-- Replaces withNgsSNPsTree for the variation searches. Not a copy: the snp
         original reads apidbtuning.snpstrains, which does not exist in this build.
         Filters on apidb.datasource's declared type/subtype rather than on a name
         string convention; apidbtuning.datasetdatasource.category is NULL for all
         10 dnaseq datasets, so the category idiom used elsewhere is unavailable.
         internal is the taxon name for selectable leaves and -1 for branch nodes,
         per the OrganismTree convention. The taxon name is load-bearing:
         HighSpeedSnpSearchAbstractPlugin looks it up in sres.TaxonName to derive
         apidb.organism.name_for_filenames, which is the HSSS path's directory
         segment. See the design doc, sections 2 and 4.1. -->
    <sqlQuery name="withVariationsTree">
      <column name="internal"/>
      <column name="term"/>
      <column name="parentTerm"/>
      <sql>
        <![CDATA[
          WITH FilterQuery AS (
            SELECT DISTINCT tn.name AS organism
            FROM apidb.datasource ds
            JOIN apidb.organism o  ON o.taxon_id = ds.taxon_id
            JOIN sres.taxonname tn ON tn.taxon_id = o.taxon_id
                                  AND tn.name_class = 'scientific name'
            WHERE ds.type = 'isolates' AND ds.subtype = 'Dna_Seq'
          )
          SELECT DISTINCT ot.term, ot.parentterm,
                 CASE WHEN ot.term = ot.organism THEN ot.term ELSE '-1' END AS internal
          FROM apidbtuning.organismtree ot
          JOIN FilterQuery fq ON fq.organism = ot.organism
          WHERE (ot.project_id = '@PROJECT_ID@' OR 'UniDB' = '@PROJECT_ID@')
          ORDER BY ot.parentterm, ot.term
        ]]>
      </sql>
    </sqlQuery>
```

Note the column element is `parentTerm` (camel case) — that is what `withNgsSNPsTree` declares, and WDK matches it case-insensitively to the SQL's `parentterm`.

- [ ] **Step 4: Verify the XML still parses**

```bash
python3 -c "import xml.etree.ElementTree as T; T.parse('$HOME/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/params/organismParams.xml'); print('parses')"
```

Expected: `parses`. (This catches an unbalanced tag in seconds instead of at the end of a five-minute remote build.)

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/organismParams.xml
git commit -m "Add organismVQ.withVariationsTree for the variation searches

The snp original (withNgsSNPsTree) reads apidbtuning.snpstrains, which does
not exist in this build, so this is a rewrite. Filters on apidb.datasource's
declared type='isolates'/subtype='Dna_Seq' -- the 10 dnaseq experiment
datasets -- rather than a name string convention.

internal is the taxon name, not an abbreviation: the HSSS plugin resolves it
through sres.TaxonName to get name_for_filenames for the webservices path."
```

---

### Task 3: `eda_sample_table_suffix` — the hidden dependent param

The one non-obvious piece of the design. The organism param's internal value **must** be the taxon name (the plugin needs it); the EDA queries need the study+entity abbreviation to build table names. Two identities, one dropdown — resolved with a hidden param that carries the second identity. Design §2 and §4.2.

**Files:**
- Modify: `Model/lib/wdk/model/questions/params/variationParams.xml` (new `querySet VariationVQ` + one param)

- [ ] **Step 1: Run the vocabulary SQL — it must return exactly one row**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
SELECT DISTINCT
  s.internal_abbrev || '_' || lower(e.internal_abbrev) AS internal,
  s.internal_abbrev || '_' || lower(e.internal_abbrev) AS term
FROM apidb.datasource ds
JOIN apidb.organism o  ON o.taxon_id = ds.taxon_id
JOIN sres.taxonname tn ON tn.taxon_id = o.taxon_id AND tn.name_class = 'scientific name'
JOIN sres.externaldatabase ed ON ed.name = ds.name
JOIN sres.externaldatabaserelease edr ON edr.external_database_id = ed.external_database_id
JOIN eda.studyexternaldatabaserelease sedr ON sedr.external_database_release_id = edr.external_database_release_id
JOIN eda.study s ON s.study_id = sedr.study_id
JOIN eda.entitytypegraph e ON e.study_id = s.study_id
WHERE ds.type = 'isolates' AND ds.subtype = 'Dna_Seq'
  AND tn.name = 'Plasmodium falciparum 3D7'
  AND s.internal_abbrev IS NOT NULL"
```

Expected: exactly **one row**, `s3be28bbe14_sample`. More than one row means the tables interpolated downstream would be ambiguous — stop; the joins need narrowing before anything else is written.

- [ ] **Step 2: Confirm the tables that name implies actually exist**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -tAc "
SELECT to_regclass('eda.attributevalue_s3be28bbe14_sample'),
       to_regclass('eda.attributegraph_s3be28bbe14_sample')"
```

Expected: both non-null. This is the check that a *looked-up* abbreviation buys you and a recomputed hash does not — see design §3.

- [ ] **Step 3: Add the `VariationVQ` querySet with this one query**

In `variationParams.xml`, after the closing `</paramSet>` and before `</wdkModel>`:

```xml
  <!-- Vocabulary queries for the variation searches. Lives in the params file,
       following this codebase's convention (organismVQ is in organismParams.xml,
       SnpVQ was in snpParams.xml). -->
  <querySet name="VariationVQ" queryType="vocab" isCacheable="true">

    <!-- Returns exactly one row: the <studyAbbrev>_<entityAbbrev> suffix for the
         chosen organism's dnaseq EDA study. One param rather than two because the
         two abbreviations are only ever used concatenated, so there is one
         interpolation point to get wrong instead of two.

         The abbreviation is LOOKED UP, not recomputed. eda.study.internal_abbrev
         is a reproducible SHA-1 digest, but hardcoding that convention into model
         XML fails invisibly: a changed convention yields a well-formed abbreviation
         for a study that does not exist, surfacing much later as
         'relation "eda.attributevalue_s<hash>_sample" does not exist'. A lookup
         yields zero rows, so the organism dropdown is visibly empty instead.
         apiTuningManager.xml:3846-3863 builds these same names the same way. -->
    <sqlQuery name="EdaSampleTableSuffix">
      <paramRef ref="organismParams.organismSinglePick" noTranslation="true"/>
      <column name="internal"/>
      <column name="term"/>
      <sql>
        <![CDATA[
          SELECT DISTINCT
            s.internal_abbrev || '_' || lower(e.internal_abbrev) AS internal,
            s.internal_abbrev || '_' || lower(e.internal_abbrev) AS term
          FROM apidb.datasource ds
          JOIN apidb.organism o  ON o.taxon_id = ds.taxon_id
          JOIN sres.taxonname tn ON tn.taxon_id = o.taxon_id
                                AND tn.name_class = 'scientific name'
          JOIN sres.externaldatabase ed
               ON ed.name = ds.name
          JOIN sres.externaldatabaserelease edr
               ON edr.external_database_id = ed.external_database_id
          JOIN eda.studyexternaldatabaserelease sedr
               ON sedr.external_database_release_id = edr.external_database_release_id
          JOIN eda.study s
               ON s.study_id = sedr.study_id
          JOIN eda.entitytypegraph e
               ON e.study_id = s.study_id
          WHERE ds.type = 'isolates' AND ds.subtype = 'Dna_Seq'
            AND tn.name = '$$organismSinglePick$$'
            AND s.internal_abbrev IS NOT NULL
        ]]>
      </sql>
    </sqlQuery>

  </querySet>
```

`noTranslation="true"` on the organism `paramRef` makes WDK pass the param's **term** rather than its internal — for a selected leaf these are the same taxon name, and it is what `SnpVQ` did. The SQL supplies the quotes, so the param must not also be quoted.

- [ ] **Step 4: Add the param itself**

Inside the existing `variationParams` paramSet, after the `variation_id` `datasetParam`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- EDA sample table suffix (hidden, derived) -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Carries <studyAbbrev>_<entityAbbrev> so the EDA filter queries can name
         eda.attributevalue_<suffix> / eda.attributegraph_<suffix>. SQL cannot
         parameterize a table name from a subquery result, so the value has to
         arrive as a param and be interpolated textually.

         quote="false" because it is interpolated into an identifier, not compared
         as a string. visible="false" because it is derived from the organism, not
         chosen. The interpolation is safe: the value can only ever be one of the
         rows VariationVQ.EdaSampleTableSuffix returns, never free user text. -->
    <flatVocabParam name="eda_sample_table_suffix"
                    queryRef="VariationVQ.EdaSampleTableSuffix"
                    prompt="EDA sample table suffix"
                    quote="false"
                    visible="false"
                    dependedParamRef="organismParams.organismSinglePick">
      <help>Derived from the selected organism. Not user-visible.</help>
    </flatVocabParam>
```

- [ ] **Step 5: Verify the XML parses**

```bash
python3 -c "import xml.etree.ElementTree as T; T.parse('$HOME/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/params/variationParams.xml'); print('parses')"
```

Expected: `parses`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/variationParams.xml
git commit -m "Add hidden eda_sample_table_suffix param and VariationVQ querySet

The organism param's internal value must be the taxon name -- the HSSS plugin
resolves it through sres.TaxonName to build the webservices path. The EDA
filter queries need the study+entity abbreviation to name per-study tables.
Two identities for one dropdown, so the second travels in a hidden dependent
param and gets interpolated into the table name.

Looked up rather than recomputed from the SHA-1 convention: a lookup fails
visibly (empty dropdown), a stale hash fails invisibly (missing relation,
much later, from inside a filterParam)."
```

---

### Task 4: `variation_sample_meta` — the EDA-driven samples filter

**Files:**
- Modify: `Model/lib/wdk/model/questions/params/variationParams.xml` (two queries into `VariationVQ`, one `filterParam`)

> **The param name `variation_sample_meta` is a contract, not a style choice.**
> `FindPolymorphismsPlugin.getStrainFilterParamName()` returns exactly this string and
> `FindPolymorphismsAbstractPlugin` lists it among the plugin's **required** params. Any
> other spelling is rejected at run time as a missing required parameter. Do not "improve" it.

- [ ] **Step 1: Run the metadata SQL**

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
SELECT count(*) AS rows,
       count(DISTINCT av.sample_stable_id) AS samples,
       count(DISTINCT av.attribute_stable_id) AS attributes,
       count(av.string_value) AS strings,
       count(av.number_value) AS numbers,
       count(av.date_value) AS dates
FROM eda.attributevalue_s3be28bbe14_sample av"
```

Expected: `3771 | 216 | 20 | 2013 | 1758 | 0`. Zero dates is fine — no date-typed filters will appear, which is this dataset, not a defect.

- [ ] **Step 2: Run the ontology SQL and check WDK's two throw conditions**

WDK's `OntologyItemNewFetcher.validateOntologyItems` throws if (a) any node names a parent that is not itself a node, or (b) any node with a NULL type has no children. Check both before writing XML:

```bash
psql -h localhost -p 5432 -d unidb_shu_a -c "
WITH t AS (
  SELECT ag.stable_id AS ontology_term_name,
         CASE WHEN ag.parent_stable_id IN
                   (SELECT stable_id FROM eda.attributegraph_s3be28bbe14_sample)
              THEN ag.parent_stable_id
         END AS parent_ontology_term_name,
         CASE ag.data_type
           WHEN 'string'  THEN 'string'
           WHEN 'number'  THEN 'number'
           WHEN 'integer' THEN 'number'
         END AS type
  FROM eda.attributegraph_s3be28bbe14_sample ag
)
SELECT (SELECT count(*) FROM t)                                        AS nodes,
       (SELECT count(*) FROM t WHERE parent_ontology_term_name IS NULL) AS roots,
       (SELECT count(*) FROM t WHERE parent_ontology_term_name IS NOT NULL
          AND parent_ontology_term_name NOT IN (SELECT ontology_term_name FROM t)) AS dangling,
       (SELECT count(*) FROM t WHERE type IS NULL AND ontology_term_name NOT IN
          (SELECT parent_ontology_term_name FROM t WHERE parent_ontology_term_name IS NOT NULL)) AS childless_branches,
       (SELECT count(*) FROM t WHERE type IS NOT NULL)                 AS typed_leaves"
```

Expected: `27 | 7 | 0 | 0 | 20`.

**`dangling` and `childless_branches` must both be 0.** They are what the `CASE` on the parent is for: EDA's attribute graph has **no row for the entity itself**, so seven category nodes declare `parent_stable_id = 'sample'` and nothing has `stable_id = 'sample'`. Mapping unresolvable parents to NULL makes WDK adopt them under its own synthetic master root.

- [ ] **Step 3: Prove the naive version would in fact fail**

Worth ten seconds, because the `CASE` looks like noise until you see this:

```bash
psql -h localhost -p 5432 -d unidb_shu_a -tAc "
SELECT count(*) FROM eda.attributegraph_s3be28bbe14_sample ag
WHERE ag.parent_stable_id IS NOT NULL
  AND ag.parent_stable_id NOT IN (SELECT stable_id FROM eda.attributegraph_s3be28bbe14_sample)"
```

Expected: `7`. Those are seven guaranteed `WdkModelException`s if you write `ag.parent_stable_id` unguarded.

- [ ] **Step 4: Confirm the filter's internal values are usable by HSSS**

The filter hands sample stable IDs to the plugin, which writes them to a strains file with `strains_are_names = 1`. They must be names HSSS knows:

```bash
psql -h localhost -p 5432 -d unidb_shu_a -tAc "
SELECT count(DISTINCT sample_stable_id) FROM eda.attributevalue_s3be28bbe14_sample" \
&& ssh cedar "cut -f2 /var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-71/Pfalciparum3D7/dnaseq/readFreq20/strainIdToName.dat | sort -u | wc -l"
```

Expected: `216` and `538`. EDA covers a subset of the strains HSSS knows, which is the safe direction: the filter cannot offer a strain HSSS has never heard of. (The strict-subset relation was verified when the design was written; the counts here are the cheap re-check.)

- [ ] **Step 5: Add both queries to `VariationVQ`**

After `EdaSampleTableSuffix`, inside the `VariationVQ` querySet:

```xml
    <!-- Metadata and background for the samples filterParam. WDK's contract is
         internal / ontology_term_name / string_value / number_value / date_value,
         which EDA's attributevalue table supplies almost verbatim.

         The same query serves metadataQueryRef and backgroundQueryRef, as the snp
         original did: the background distribution is over all samples in the study,
         which is exactly what this returns. -->
    <sqlQuery name="SamplesMetadataByStudy" doNotTest="1">
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <column name="internal"/>
      <column name="ontology_term_name"/>
      <column name="string_value"/>
      <column name="number_value"/>
      <column name="date_value"/>
      <sql>
        <![CDATA[
          SELECT av.sample_stable_id    AS internal,
                 av.attribute_stable_id AS ontology_term_name,
                 av.string_value,
                 av.number_value,
                 av.date_value
          FROM eda.attributevalue_$$eda_sample_table_suffix$$ av
        ]]>
      </sql>
    </sqlQuery>

    <!-- The filter tree. Two things here are load-bearing:

         1. The CASE on the parent. EDA's attribute graph has no row for the entity
            itself, so seven category nodes point at parent 'sample' and no node has
            stable_id 'sample'. WDK's validateOntologyItems throws
            "Parent ontology ID 'sample' ... cannot be found" on exactly that.
            Mapping unresolvable parents to NULL makes WDK adopt them under its
            synthetic master root. Written as a membership test rather than
            = 'sample' so it stays correct if the entity abbreviation differs -
            and it is already dynamic in the table name.

         2. The type mapping is pinned to WDK's OntologyItemType enum, which accepts
            exactly string / number / date / multiFilter, and treats NULL as a BRANCH
            node. EDA's category rows have no data_type, so they map to NULL, which is
            what makes them the tree's internal nodes. 'integer' folds into 'number'
            because WDK has no integer type. -->
    <sqlQuery name="SampleOntologyByStudy" doNotTest="1">
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
      <column name="ontology_term_name"/>
      <column name="parent_ontology_term_name"/>
      <column name="display_name"/>
      <column name="description"/>
      <column name="type"/>
      <column name="units"/>
      <column name="precision"/>
      <column name="is_range"/>
      <sql>
        <![CDATA[
          SELECT ag.stable_id AS ontology_term_name,
                 CASE WHEN ag.parent_stable_id IN
                           (SELECT stable_id FROM eda.attributegraph_$$eda_sample_table_suffix$$)
                      THEN ag.parent_stable_id
                 END AS parent_ontology_term_name,
                 ag.display_name,
                 ag.definition AS description,
                 CASE ag.data_type
                   WHEN 'string'  THEN 'string'
                   WHEN 'number'  THEN 'number'
                   WHEN 'integer' THEN 'number'
                 END AS type,
                 ag.unit AS units,
                 ag.precision,
                 CASE WHEN ag.data_shape = 'continuous' THEN 1 ELSE 0 END AS is_range
          FROM eda.attributegraph_$$eda_sample_table_suffix$$ ag
        ]]>
      </sql>
    </sqlQuery>
```

- [ ] **Step 6: Add the `filterParam`**

Inside `variationParams`, after `eda_sample_table_suffix`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Samples (EDA-driven filter) -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- The name variation_sample_meta is a CONTRACT with the Java plugin:
         FindPolymorphismsPlugin.getStrainFilterParamName() returns exactly this
         string and FindPolymorphismsAbstractPlugin lists it among its required
         params. Renaming it breaks the search at run time, not at build time.

         Internal values are EDA sample stable IDs, which are a strict subset of the
         strain names in HSSS's strainIdToName.dat - no mapping layer needed. The
         plugin writes them to a strains file and passes strains_are_names = 1.

         minSelectedCount=2 as the snp original: polymorphism within a group of one
         is meaningless.

         organismSinglePick is declared as a depended param even though neither
         query reads it: WDK validates only that every query param is declared, not
         the converse, and declaring it keeps the filter visibly downstream of the
         organism choice it is in fact scoped by. -->
    <filterParam name="variation_sample_meta"
                 metadataQueryRef="VariationVQ.SamplesMetadataByStudy"
                 backgroundQueryRef="VariationVQ.SamplesMetadataByStudy"
                 ontologyQueryRef="VariationVQ.SampleOntologyByStudy"
                 prompt="Samples"
                 minSelectedCount="2"
                 dependedParamRef="organismParams.organismSinglePick,variationParams.eda_sample_table_suffix">
      <help>
        Select a set of samples whose genomic sequences will be compared. Use the
        sample characteristics to narrow the group, or accept all samples for the
        organism you chose.
      </help>
    </filterParam>
```

- [ ] **Step 7: Verify the XML parses**

```bash
python3 -c "import xml.etree.ElementTree as T; T.parse('$HOME/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/params/variationParams.xml'); print('parses')"
```

Expected: `parses`.

- [ ] **Step 8: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/variationParams.xml
git commit -m "Add EDA-driven variation_sample_meta filterParam and its two queries

The samples filter moves from apidbTuning.Metadata to EDA's per-study tables,
named by interpolating the hidden suffix param.

The CASE on parent_stable_id is load-bearing, not defensive: EDA's attribute
graph has no row for the entity itself, so seven category nodes point at a
parent 'sample' that does not exist as a node, and WDK's validateOntologyItems
throws on precisely that. Mapping unresolvable parents to NULL hands them to
WDK's synthetic master root. Verified 27 nodes -> 7 roots, 0 dangling, 0
childless branches, 20 typed leaves.

The param name is the plugin's required-parameter contract; do not rename it."
```

---

### Task 5: The four HSSS path and threshold params

Copied out of `snpParams.xml`, **not** referenced there. Design §4.4: `snpParams.xml` is imported inside the commented-out snp block, so the `snpParams` paramSet is absent from the assembled model and every `paramRef` to it would fail model load. Uncommenting is not the fix either — that file references `SnpRecordClasses.SnpRecordClass`, also commented out.

**Files:**
- Modify: `Model/lib/wdk/model/questions/params/variationParams.xml`

- [ ] **Step 1: Confirm for yourself that `snpParams` is not in the assembled model**

Do not take the plan's word for it, and do not use `grep` on `apiCommonModel.xml` — grep cannot tell a live import from a commented-out one:

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"' \
  | grep -c "paramSet name=\"snpParams\""
```

Expected: `0`. That zero is the whole justification for copying rather than referencing.

- [ ] **Step 2: Confirm the four read-frequency directories exist, since the internals must match them**

```bash
ssh cedar 'ls /var/www/Common/apiSiteFilesMirror/webServices/PlasmoDB/build-71/Pfalciparum3D7/dnaseq/'
```

Expected: `readFreq20 readFreq40 readFreq60 readFreq80` (plus `bigwig` and `vcf`, which are out of scope). The four `ReadFrequencyPercent` internals below must be exactly `20`/`40`/`60`/`80`.

- [ ] **Step 3: Add the four params**

Inside `variationParams`, after `variation_sample_meta`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- HSSS path and thresholds -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- These four are copied from snpParams.xml rather than referenced there.
         snpParams.xml is imported INSIDE the commented-out snp block in
         apiCommonModel.xml, so the snpParams paramSet is absent from the assembled
         model (wdkXml lists it nowhere) and every paramRef to it would fail model
         load. Uncommenting that one import fails too: the file references
         SnpRecordClasses.SnpRecordClass, also commented out. The originals are
         unimported dead code, so this is migration, not duplication.
         See the design doc, section 4.4. -->

    <!-- The plugin substitutes PROJECT_GOES_HERE itself. %%buildNumber%% is
         model-wide; the dnaseq files exist only under build-71. -->
    <enumParam name="WebServicesPath"
               prompt="wsPath" quote="false" visible="false">
      <enumList>
        <enumValue default="true">
          <term>dflt</term>
          <internal>@WEBSERVICEMIRROR@/PROJECT_GOES_HERE/build-%%buildNumber%%</internal>
        </enumValue>
      </enumList>
    </enumParam>

    <!-- One definition, unlike snpParams which declares this twice
         (excludeProjects/includeProjects ToxoDB) differing only in help text, the
         ToxoDB copy phrased for the two-group search. That distinction does not
         apply to a single-group search. The four internals must match the
         readFreq* directory names exactly. -->
    <enumParam name="ReadFrequencyPercent"
               prompt="Read frequency threshold" quote="false">
      <help>
        This parameter applies to the sequencing reads of individual samples and
        defines a stringency for data supporting a variant call between a sample and
        the reference genome (Organism). Each nucleotide position of each sample is
        compared to the reference genome and a call is made if the portion of the
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

    <stringParam name="MinPercentMinorAlleles"
                 prompt="Minor allele frequency &gt;= "
                 number="true">
      <help>
        This parameter applies to your group of samples. A variant can occur in any
        number of samples in your group and the least frequent call across all
        samples is the Minor Allele Frequency. A variant will be returned by the
        search if the frequency of the minor allele is equal to or greater than your
        Minor Allele Frequency. See the Description below the Get Answer button for
        more.
      </help>
      <suggest default="0"/>
      <regex>\d\d?</regex>
    </stringParam>

    <stringParam name="MinPercentIsolateCalls"
                 prompt="Percent samples with a base call &gt;= "
                 number="true">
      <help>
        This parameter applies to the selected set of aligned sample sequences. At
        any given nucleotide position, some samples in your group may not have data
        supporting a base call because the Read Frequency Threshold was not met or
        fewer than our minimum of 5 reads aligned. 'Percent samples with a base call'
        defines the fraction of the selected samples that must have a base call
        before a variant is returned for that nucleotide position, based on the
        remaining samples that do have data. See the Description below for more
        information.
      </help>
      <suggest default="20"/>
      <regex>\d\d?|100</regex>
    </stringParam>
```

The param **names** stay as the originals (including `MinPercentIsolateCalls`) — the plugin reads them by name. Only prompts and help text move from "isolates" to "samples".

- [ ] **Step 4: Verify the XML parses and the regexes survived escaping**

```bash
python3 - <<'PY'
import xml.etree.ElementTree as T, os
p = os.path.expanduser('~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/params/variationParams.xml')
r = T.parse(p).getroot()
for sp in r.iter('stringParam'):
    rx = sp.find('regex')
    print(sp.get('name'), '->', repr(rx.text if rx is not None else None))
PY
```

Expected exactly:
```
MinPercentMinorAlleles -> '\\d\\d?'
MinPercentIsolateCalls -> '\\d\\d?|100'
```
(Python shows a literal backslash as `\\`. If you see `\\\\d`, the backslashes got doubled — fix it; the regex would reject every input.)

- [ ] **Step 5: Build, and prove the model loads with all five new params**

This is the first remote build. It takes a few minutes.

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: completes without a `WdkModelException`. If it fails, the message names the unresolved reference — that is the whole value of this step.

Then prove the params are in the *assembled* model, not merely in a file:

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"' \
  | grep -E "name=\"(eda_sample_table_suffix|variation_sample_meta|WebServicesPath|ReadFrequencyPercent|MinPercentMinorAlleles|MinPercentIsolateCalls)\""
```

Expected: one matching line per name, six in all. `wb model` is correct here — nothing has touched categorization yet; Task 8 is what forces `wb ontology`.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/variationParams.xml
git commit -m "Copy the four HSSS path and threshold params into variationParams

Not referenced from snpParams: that file is imported inside the commented-out
snp block, so the snpParams paramSet is absent from the assembled model
(wdkXml finds it nowhere) and every paramRef to it would fail model load.
Uncommenting the one import fails too -- the file references
SnpRecordClasses.SnpRecordClass, also commented out. The originals are
unimported dead code, so this is migration out of a dead file.

Two deliberate departures: one ReadFrequencyPercent rather than the original's
two (they differed only in help text phrased for the two-group search), and
help text saying 'samples' to match the EDA vocabulary the filter is built
from. Param names are unchanged -- the plugin reads them by name."
```

---

### Task 6: The `processQuery`

**Files:**
- Modify: `Model/lib/wdk/model/questions/queries/variationQueries.xml`

- [ ] **Step 1: Confirm the plugin class and its required params before wiring to them**

```bash
cd ~/workspaces/plasmodb/ApiCommonWebService
grep -rn "getStrainFilterParamName\|PARAM_ORGANISM\|REQUIRED" \
  WSFPlugin/lib/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindPolymorphismsPlugin.java \
  WSFPlugin/lib/java/org/apidb/apicomplexa/wsfplugin/highspeedsnpsearch/FindPolymorphismsAbstractPlugin.java \
  | head -20
```

Expected: `FindPolymorphismsPlugin` returns `"variation_sample_meta"` from `getStrainFilterParamName()`, and the abstract plugin lists that name among its required params. If the returned string is anything else, **stop** — Task 4's param name must match it, and the plan is stale.

- [ ] **Step 2: Add the query**

In `variationQueries.xml`, inside the `VariationsBy` querySet, after the `VariationBySourceId` `sqlQuery`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations within one group of samples -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- HSSS (HighSpeedSnpSearch) process query. The plugin reads precomputed
         files under <wsPath>/<name_for_filenames>/dnaseq/readFreq<N>/ and returns
         a tab-separated results file.

         quote="false" on the organism param is required for the dependent-param
         query to work; the plugin strips quotes for its own use.

         The wsColumn set is fixed by the plugin, not chosen:
         FindPolymorphismsAbstractPlugin throws unless the results file has exactly
         four tab-separated columns, and maps them to SourceId, PercentOfKnowns
         (-> PercentIsolateCalls), PercentOfPolymorphisms (-> PercentMinorAlleles)
         and Phenotype. project_id is supplied by the plugin, not the file. -->
    <processQuery name="VariationsByIsolateGroup"
                  processName="org.apidb.apicomplexa.wsfplugin.highspeedsnpsearch.FindPolymorphismsPlugin">

      <paramRef ref="organismParams.organismSinglePick" prompt="Organism"
                displayType="treeBox" quote="false"
                queryRef="organismVQ.withVariationsTree">
        <help>The Organism defines the species identity of the samples and the genome
        against which each sample's variants were called. After choosing an Organism,
        the set of samples available for forming groups is limited to samples aligned
        to your chosen Organism's genome.</help>
        <visibleHelp>The organism you choose determines the genome to which the
        variants have been mapped. It also restricts the set of samples you may
        choose, since variants are identified by aligning that sample's reads to this
        genome.</visibleHelp>
      </paramRef>
      <paramRef ref="variationParams.eda_sample_table_suffix"/>
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

- [ ] **Step 3: Verify the XML parses**

```bash
python3 -c "import xml.etree.ElementTree as T; T.parse('$HOME/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/queries/variationQueries.xml'); print('parses')"
```

Expected: `parses`.

- [ ] **Step 4: Commit** (no build yet — Task 7's question is what makes this query reachable, and one build covers both)

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/queries/variationQueries.xml
git commit -m "Add VariationsByIsolateGroup process query

Binds FindPolymorphismsPlugin to the new variation params. The wsColumn set is
dictated by the plugin, which throws unless its results file has exactly four
tab-separated columns; project_id comes from the plugin rather than the file.
organism quote=false is required for the dependent-param query."
```

---

### Task 7: The question

**Files:**
- Modify: `Model/lib/wdk/model/questions/variationQuestions.xml`

- [ ] **Step 1: Confirm the summary attributes exist on the record**

An `attributesList` naming an attribute the record does not have fails model load:

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
grep -cE 'name="(variation_location|gene_ids|variant_type)"' Model/lib/wdk/model/records/variationRecords.xml
```

Expected: `3`. The other three summary columns (`PercentMinorAlleles`, `PercentIsolateCalls`, `Phenotype`) are the query's dynamic `wsColumn`s from Task 6 and will not appear in the record file — that is correct.

- [ ] **Step 2: Add the question**

In `variationQuestions.xml`, inside the `VariationQuestions` questionSet, after `VariationBySourceId`:

```xml
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variations within one group of samples -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- This question DOES override attributesList, unlike VariationBySourceId
         which inherits the record default. The plugin's dynamic columns (minor
         allele frequency and percent of samples with a call, for the chosen group)
         are the entire point of the search and are not in the record's default
         summary.

         displayName says Samples, not the snp original's Isolates: EDA calls them
         samples throughout and the filter is built from EDA. The internal search
         name stays VariationsByIsolateGroup.

         No searchCategory: it groups searches within a set, and with two variation
         searches there is nothing to group. It arrives with ByLocation/ByGeneIds.

         noSummaryOnSingleRecord is deliberately NOT set: unlike an ID lookup, a
         one-hit analytical result is a finding the user wants to see in context. -->
    <question name="VariationsByIsolateGroup"
              displayName="Differences Within a Group of Samples"
              shortDisplayName="One Group"
              queryRef="VariationsBy.VariationsByIsolateGroup"
              recordClassRef="VariationRecordClasses.VariationRecordClass">

      <attributesList
        summary="variation_location,gene_ids,variant_type,PercentMinorAlleles,PercentIsolateCalls,Phenotype"/>

      <summary>
        <![CDATA[
          Find variants that differ within a group of samples, with an option to
          specify minor allele frequency.
        ]]>
      </summary>

      <description>
        <![CDATA[
          This search analyzes whole genome sequencing data from a group of samples
          to find variants associated with the group.<br><br>

          Each sample's sequencing reads are aligned to the reference genome
          (Organism) and variants are recorded for each sample based on the Read
          Frequency Threshold. Then, scanning variant locations across the group of
          samples, variants are returned by the search if the Minor Allele Frequency
          and the Percent samples with a base call are met.

          <p><b>Organism:</b> The Organism parameter defines the species of the
          samples and the genome in which the variants are determined. Choosing an
          Organism focuses the Samples parameter to the samples of that organism,
          changing the subset available when forming your group.</p>

          <p><b>Samples:</b> Sample sequences are accompanied by characteristics of
          the sample -- where it was collected, the host, alignment statistics. By
          default the group includes all samples from the Organism you chose; you may
          narrow the group using those characteristics. At least two samples are
          required, since polymorphism within a group of one is undefined.</p>

          <p><b>Read frequency threshold:</b> An allele is called for a sample at a
          location if that fraction of the sample's aligned reads support it. For
          example, a sample with 10 reads at a location -- 6 A and 4 C -- is called A
          at a threshold of 60% or less, and not called at 80%. This matters most for
          diploid or aneuploid organisms, where heterozygous positions are expected
          near 50%.</p>

          <p><b>Minor allele frequency:</b> Among the qualifying calls at a location,
          the minor allele frequency is the percent that are not the major allele. A
          location is returned if that is at or above the value you specify. Use 0 to
          find every variant location within the group.</p>

          <p><b>Percent samples with a base call:</b> A location is only considered if
          this fraction of your selected samples have a qualifying call there. With 20
          samples and a threshold of 75%, a location with fewer than 15 called samples
          is ignored.</p>
        ]]>
      </description>

    </question>
```

- [ ] **Step 3: Verify the XML parses**

```bash
python3 -c "import xml.etree.ElementTree as T; T.parse('$HOME/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model/questions/variationQuestions.xml'); print('parses')"
```

Expected: `parses`.

- [ ] **Step 4: Build and prove the question is in the assembled model**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: completes without a `WdkModelException`.

```bash
ssh cedar 'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && wdkXml -model PlasmoDB"' \
  | grep -c "VariationsByIsolateGroup"
```

Expected: a non-zero count. Zero means the question is in the file but not in the model for PlasmoDB — check `includeProjects` on the enclosing questionSet.

- [ ] **Step 5: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/variationQuestions.xml
git commit -m "Add the VariationsByIsolateGroup question

Overrides attributesList, unlike VariationBySourceId: the plugin's dynamic
minor-allele-frequency and percent-called columns are the point of the search
and are not in the record's default summary.

displayName says Samples rather than the snp original's Isolates, matching the
EDA vocabulary the filter is built from. noSummaryOnSingleRecord deliberately
unset -- a one-hit analytical result wants its context."
```

---

### Task 8: Category ontology placement

**Files:**
- Modify: `Model/lib/wdk/ontology/individuals.txt`

`individuals.txt` is tab-delimited with 14 columns **and load-bearing empty fields**, including a trailing tab. Do not hand-type the row — derive it from the `VariationBySourceId` row so the whitespace is exact.

- [ ] **Step 1: Look at the row you are copying**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
grep -n "VariationQuestions.VariationBySourceId" Model/lib/wdk/ontology/individuals.txt | cat -A
```

Expected: one match (line ~1158) showing `^I` between every field, `topic_0199` as the parent, `search` as the target type, `menu` and `webservice` at the end, and a trailing `^I` before `$`.

- [ ] **Step 2: Append the new row by substitution, not by typing**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
grep "VariationQuestions.VariationBySourceId" Model/lib/wdk/ontology/individuals.txt \
  | sed 's/VariationBySourceId/VariationsByIsolateGroup/g' \
  >> Model/lib/wdk/ontology/individuals.txt
```

- [ ] **Step 3: Verify field count and content**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
tail -n 1 Model/lib/wdk/ontology/individuals.txt | cat -A
tail -n 1 Model/lib/wdk/ontology/individuals.txt | awk -F'\t' '{print NF" fields"}'
grep -c "VariationQuestions.VariationsByIsolateGroup" Model/lib/wdk/ontology/individuals.txt
```

Expected: the new row with `VariationsByIsolateGroup` in columns 1 and 6 and everything else identical to the `VariationBySourceId` row; the same field count that row has (compare with `grep VariationBySourceId ... | awk -F'\t' '{print NF}'` — they must match); and `1`.

- [ ] **Step 4: Build with `wb ontology` — NOT `wb model`**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb ontology
```

Expected: completes. `wb ontology` regenerates `individuals.owl` → `categories_merged.owl`, which is what the app actually reads, and does the model build too. Run `wb model` here instead and the site keeps serving the previous tree with **no error anywhere** — the search exists in the model but is uncategorized and absent from the menu.

- [ ] **Step 5: Prove the OWL actually contains it**

```bash
ssh cedar 'grep -c "VariationsByIsolateGroup" /var/www/jbrestel.plasmodb.org/gus_home/lib/wdk/ontology/categories_merged.owl'
```

Expected: non-zero. This is the server-side answer to "is it categorized where I intended" and needs no browser.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "Categorize VariationsByIsolateGroup under Genetic Variation

Same placement as VariationBySourceId: parent topic_0199, targetType search,
menu + webservice scopes. Requires wb ontology, not wb model -- a stale OWL
leaves the search uncategorized with no error anywhere."
```

---

### Task 9: End-to-end verification in the browser

Everything in the params and queries is already verified by execution against the database. What only a live run can establish is the chain: hidden param → EDA queries → filter tree → plugin → results → record pages. **This is also the first real exercise of the `ApiCommonWebService` plumbing** (`/dnaseq` in the search dir, and the `variation_sample_meta` param name), which that repo's spec could not verify on its own.

**Files:** none — this task changes nothing.

- [ ] **Step 1: Mark the logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark vbig
```

- [ ] **Step 2: Open the site and confirm which site you are on**

Load `https://jbrestel.plasmodb.org/a/app` in Chrome and authenticate past the pre-release gate if prompted. Then, before trusting anything:

```javascript
window.location.origin
```

Expected: `"https://jbrestel.plasmodb.org"`. If it reads `https://veupathdb.org`, **stop** — the tab bounced to autologin and every relative fetch from here answers for production. Authenticate and reload.

- [ ] **Step 3: Confirm the search is registered for this site**

From that authenticated page:

```javascript
fetch('/a/service/record-types/variation')
  .then(r => r.json())
  .then(d => d.searches.map(s => s.fullName).filter(n => n.includes('Variation')))
```

Expected: includes `VariationQuestions.VariationsByIsolateGroup`. `/record-types` is project-filtered, so this — not the category tree — is the source of truth for whether this site has the search.

If that 404s, the record type's URL segment is not `variation`; get the real one from `fetch('/a/service/record-types').then(r=>r.json()).then(d=>d.map(t=>t.urlSegment))` and retry.

- [ ] **Step 4: Reach the search page and record its real URL**

Navigate through the site's Searches menu (Genetic Variation → Differences Within a Group of Samples) rather than guessing a URL. **Record the URL you land on** in your report; later tasks and the other three searches will want it.

- [ ] **Step 5: The organism param**

Expected: a treeBox offering `Plasmodium falciparum 3D7` as the only selectable leaf, under branch nodes. If the tree is empty, the vocabulary query returned nothing for this project — re-run Task 2 Step 1.

- [ ] **Step 6: The samples filter — the first proof the hidden param works**

Select `Plasmodium falciparum 3D7`. Expected: the Samples filter populates with **216 samples** under a **7-category** tree (Provenance and identity, Organism under investigation, Specimen and culture, Collection event, Host, Collection location, Alignment statistics), with 20 leaf variables among them.

This step exercises the hidden suffix param and both EDA queries end to end. Failure modes and what they mean:

| symptom | cause |
|---|---|
| filter empty, no error | the suffix vocabulary returned zero rows — Task 3 Step 1 |
| `relation "eda.attributevalue_..." does not exist` | the suffix is wrong or the table is absent — Task 3 Step 2 |
| `Parent ontology ID 'sample' ... cannot be found` | the `CASE` on the parent is missing or wrong — Task 4 Step 2 |
| `The following ontology items have no children ... null item type` | the type mapping dropped a leaf's type — Task 4 Step 2 |

- [ ] **Step 7: Run the search — the first exercise of the Java plumbing**

Select at least two samples (accepting all 216 is fine), leave the thresholds at their defaults (80% RFT, minor allele frequency 0, percent called 20), and submit.

Expected: a result page with rows, showing the `PercentMinorAlleles` and `PercentIsolateCalls` columns.

| symptom | cause |
|---|---|
| `Organism dir does not exist` | the HSSS path — `buildNumber` (Task 1) or the plumbing's `/dnaseq` search dir |
| missing required parameter | the filterParam name does not match `getStrainFilterParamName()` (Task 4/6 Step 1) |
| `expected 4 columns` | the plugin's results-file contract — a plumbing problem, not a model one |

Selecting exactly two samples is also worth one run: with `minSelectedCount="2"`, one sample must be rejected client-side.

- [ ] **Step 8: Confirm the IDs resolve**

Expected: IDs of the form `Variant_<sequence>_<location>` (e.g. `Variant_Pf3D7_01_v3_100057`). Click one through to its record page and confirm it renders. This is the proof that the plumbing spec's ID-construction work holds through a real search — the plugin's `idPrefix` and `hsssReconstructSnpId` join must agree with what `VariationAttributes.source_id` actually contains.

- [ ] **Step 9: Read the logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since vbig --quiet
```

Expected: the error logs report `silent:`. A healthy page load leaves them silent, so anything there is worth reading even if the page looked fine.

- [ ] **Step 10: Report**

Report to John: the search page URL, the sample and category counts you actually saw, the row count returned, one example variation ID that resolved to a record page, and the log verdict. If any step failed, report the symptom and the diagnosis from the tables above rather than guessing at a fix.

---

## What this plan does not do

Named so nobody thinks they were forgotten:

- **The other three HSSS searches** — `ByLocation`, `ByGeneIds`, `ByTwoIsolateGroups`. Each reuses everything built in Tasks 2–5.
- **`FindMajorAllelesPlugin`'s param rename.** It hardcodes `ngsSnp_strain_meta_a` / `_m` as its own required-param contract. Deferred to the `ByTwoIsolateGroups` spec, which **must not forget it**.
- **Deleting the dead `snpParams.xml`** and the rest of the commented-out snp block. Once Task 5 copies the four params out, it has no remaining reason to exist — but removal has its own blast radius (`recordParams.xml`, `spanQuestions.xml`, `SnpsBySpanLogic`).
- **`snpParams.MinPercentMajorAlleles`, the `*Two` variants, and the wizard params** — used only by the two-group searches, so they migrate with `ByTwoIsolateGroups`.
- **Per-strain / VCF data.** `build-71/.../dnaseq/` also holds `vcf` and `bigwig` — inputs for the deferred strain tables on the variation record.
- **Reviving the HSSS test harnesses.** Both are broken (see the plumbing spec §4); this search's verification is the browser.
