# Variation Searches Implementation Plan (scaffolding + `VariationBySourceId`)

> **Executed and complete, 2026-08-05.** See "Execution outcome" at the end for what was
> verified, what was substituted, and the two checks that remain unrun. The step
> checkboxes below were not ticked individually; the outcome section is the record.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the `variation` record its first search — `VariationBySourceId` — along with
the `paramSet`/`querySet`/`questionSet` scaffolding and model imports that every later
variation search will extend.

**Architecture:** Three new WDK model XML files under
`ApiCommonModel/Model/lib/wdk/model/questions/`, three `<import>` lines in
`apiCommonModel.xml`, and one row in `individuals.txt` to place the search in the
category tree. The search is a `sqlQuery` over `ApidbTuning.VariationAttributes` driven
by a `datasetParam`. No Java, no SQL DDL, no client code.

**Tech Stack:** WDK model XML; `wb` build wrapper on the remote webserver (invoked via
`bin/veup-build.sh` from the `agentic-veupath-dev` control plane); `xmllint` for local XML
checks; the WDK REST service and Claude in Chrome for verification.

**Spec:** `docs/superpowers/specs/2026-08-05-variation-searches-design.md`. Section
references below prefixed `spec §` point there; `record §` points to
`2026-07-30-variation-record-design.md`.

---

## Why there are no unit tests in this plan

This change is entirely declarative model XML. `ApiCommonModel` has no test harness for
it, and the sanity model (`Model/lib/wdk/apiCommonModel-sanity.xml`) is dead — it imports
a directory that does not exist. **Do not create or extend a sanity file** (spec §7.3).

The verification ladder that replaces tests, cheapest first, is used throughout:

1. `xmllint --noout` — is the XML well-formed?
2. `wb model` / `wb ontology` — does the model load and does the reference resolve?
3. `/service/record-types/variation` — is the search registered for this site?
4. `/service/ontologies/Categories` — is it in the right place in the tree?
5. Browser + `veup-logs.sh` — does it actually work, and did anything break?

Each task below stops at the cheapest rung that can fail, so a broken step is caught in
seconds rather than after a multi-minute build.

## Prerequisites (do these once, before Task 1)

- [ ] **Confirm the working branch**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && git rev-parse --abbrev-ref HEAD
```

Expected: `dnaseq-merge-experiments`. **If it prints `main`, stop** — this work does not
go on `main`.

- [ ] **Confirm mutagen sync is carrying local edits to the webserver**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-sync-up.sh plasmodb
```

This is idempotent — safe to run just to ask. Expected: the `plasmodb` row in the printed
roster reads `up`. Every build in this plan runs on the *remote*, so an edit that has not
synced will silently build the old file.

## File Structure

| file | responsibility |
|---|---|
| `Model/lib/wdk/model/questions/params/variationParams.xml` (**create**) | `paramSet variationParams` — the ID `datasetParam` and, later, every other variation search param |
| `Model/lib/wdk/model/questions/queries/variationQueries.xml` (**create**) | `querySet VariationsBy` — the SQL/process queries backing variation searches |
| `Model/lib/wdk/model/questions/variationQuestions.xml` (**create**) | `questionSet VariationQuestions` — the user-facing searches |
| `Model/lib/wdk/apiCommonModel.xml` (**modify**, after line 416) | three `<import>` lines in the existing "Variations" block |
| `Model/lib/wdk/ontology/individuals.txt` (**modify**, append after line 1157) | one `search` row placing the question under "Genetic Variation" |

Three files rather than one because it is the convention every other record in the model
follows, and because the four deferred HSSS searches (spec §8.1) then land without a
reshuffle. Rationale and the rejected alternatives are in spec §3.

---

### Task 1: Create the three model XML files

All three land in one commit: the question references the query, which references the
param, so any two of them alone is an unresolvable model. There is nothing to verify
between them.

**Files:**
- Create: `Model/lib/wdk/model/questions/params/variationParams.xml`
- Create: `Model/lib/wdk/model/questions/queries/variationQueries.xml`
- Create: `Model/lib/wdk/model/questions/variationQuestions.xml`

- [ ] **Step 1: Create the paramSet file**

Write `Model/lib/wdk/model/questions/params/variationParams.xml`:

```xml
<wdkModel>

  <paramSet name="variationParams"
            includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variation ID -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Matches source_id exactly. source_id has the form
         Variant_<sequence_source_id>_<location>. If tolerance for a coordinate-style
         input is ever wanted, extend VariationAttributes.VariationAlias rather than any
         search's SQL, so every entry point benefits. See spec section 5.1. -->
    <datasetParam name="variation_id"
                  recordClassRef="VariationRecordClasses.VariationRecordClass"
                  prompt="Variation ID input set">
      <help>Input a comma delimited set of Variation IDs, or upload a file</help>
      <suggest includeProjects="PlasmoDB"  default="Variant_Pf3D7_01_v3_100057"/>
      <suggest includeProjects="TriTrypDB" default="Variant_11L3_v3_26886"/>
      <suggest includeProjects="FungiDB"   default="Variant_Chr1_A_fumigatus_Af293_1000005"/>
      <suggest includeProjects="UniDB"     default="Variant_Pf3D7_01_v3_100057"/>
      <!-- AmoebaDB, CryptoDB, MicrosporidiaDB, PiroplasmaDB and ToxoDB owe a suggest
           default once their variation data loads. Omitted rather than invented. -->
    </datasetParam>

  </paramSet>

</wdkModel>
```

- [ ] **Step 2: Create the querySet file**

Write `Model/lib/wdk/model/questions/queries/variationQueries.xml`:

```xml
<wdkModel>

  <querySet name="VariationsBy" queryType="id" isCacheable="true"
            includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variation by Variation ID -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- ApidbTuning.VariationAttributes, not apidb.VariationFeature: the query must
         return both primary-key columns, and project_id is a derived taxon-to-project
         mapping that by the record spec's sourcing invariant (record section 3.1) lives
         only in the tuning table. VariationFeature has no project_id. -->
    <sqlQuery name="VariationBySourceId" doNotTest="true">
      <paramRef ref="variationParams.variation_id"/>
      <column name="source_id"/>
      <column name="project_id"/>
      <sql>
        <![CDATA[
          SELECT DISTINCT va.source_id, va.project_id
          FROM ApidbTuning.VariationAttributes va, ($$variation_id$$) ds
          WHERE va.source_id = ds.source_id
        ]]>
      </sql>
    </sqlQuery>

  </querySet>

</wdkModel>
```

- [ ] **Step 3: Create the questionSet file**

Write `Model/lib/wdk/model/questions/variationQuestions.xml`:

```xml
<wdkModel>

  <questionSet name="VariationQuestions" displayName="Search for Variations"
               includeProjects="AmoebaDB,CryptoDB,FungiDB,MicrosporidiaDB,PiroplasmaDB,PlasmoDB,TriTrypDB,ToxoDB,UniDB">

    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- Variation by Variation ID -->
    <!--++++++++++++++++++++++++++++++++++++++++++++++++-->
    <!-- No attributesList: the question inherits the record's default summary columns
         so one place defines what a variation result looks like. No searchCategory:
         that groups searches within a set, and there is only one. -->
    <question name="VariationBySourceId"
              displayName="Variation ID(s)"
              shortDisplayName="Variation ID(s)"
              queryRef="VariationsBy.VariationBySourceId"
              recordClassRef="VariationRecordClasses.VariationRecordClass"
              noSummaryOnSingleRecord="true">

      <summary>
        Find variations by ID.
      </summary>

      <description>
        <![CDATA[
          Find variations by Variation ID. <br><br>

          Either enter the ID list manually, or upload a file that contains the list.
          IDs can be delimited by a comma, a semi colon, or any white spaces.
        ]]>
      </description>

    </question>

  </questionSet>

</wdkModel>
```

- [ ] **Step 4: Verify all three files are well-formed XML**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model && \
  xmllint --noout questions/params/variationParams.xml \
                  questions/queries/variationQueries.xml \
                  questions/variationQuestions.xml && echo "XML OK"
```

Expected: `XML OK` and nothing else. Any `parser error` output means a typo — fix it
before continuing; the remote build takes minutes and will only tell you the same thing.

- [ ] **Step 5: Verify the files reference only things that exist**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model && \
  grep -c 'name="VariationRecordClass"' records/variationRecords.xml && \
  grep -c 'name="VariationAlias"' records/variationAttributeQueries.xml
```

Expected: `1` and `1`. This confirms `recordClassRef="VariationRecordClasses.VariationRecordClass"`
resolves and that the record class this search targets is the one the record spec built.

- [ ] **Step 6: Verify no personal identifiers leaked in**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/model && \
  grep -n 'jbrestel' questions/params/variationParams.xml \
                     questions/queries/variationQueries.xml \
                     questions/variationQuestions.xml ; echo "exit: $?"
```

Expected: no matches, `exit: 1`. **Any match is a blocker for merge** — the same gate the
record plan used, because a hand-written stub schema name is easy to leave behind.

- [ ] **Step 7: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/model/questions/params/variationParams.xml \
        Model/lib/wdk/model/questions/queries/variationQueries.xml \
        Model/lib/wdk/model/questions/variationQuestions.xml
git commit -m "Add variation search scaffolding and the VariationBySourceId search

Three new files -- a variationParams paramSet holding the ID datasetParam,
a VariationsBy querySet, and a VariationQuestions questionSet -- giving the
variation record its first search, ported from the deprecated snp record's
NgsSnpBySourceId.

Not yet imported into apiCommonModel.xml, so this commit changes nothing
that builds.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Import the files and confirm the model loads

**Files:**
- Modify: `Model/lib/wdk/apiCommonModel.xml` (the "Variations" block, currently lines
  413–416)

- [ ] **Step 1: Read the current import block to confirm the insertion point**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk && \
  grep -n 'variation' apiCommonModel.xml
```

Expected: exactly three matches, the record-side imports —
`model/records/variationAttributeQueries.xml`, `model/records/variationTableQueries.xml`,
`model/records/variationRecords.xml` — at lines 414, 415, 416. If the line numbers differ,
use the ones grep reports; insert after the `variationRecords.xml` line either way.

- [ ] **Step 2: Add the three imports**

In `Model/lib/wdk/apiCommonModel.xml`, replace:

```xml
  <!-- Variations (replaces the deprecated SNP record above) -->
  <import file="model/records/variationAttributeQueries.xml"/>
  <import file="model/records/variationTableQueries.xml"/>
  <import file="model/records/variationRecords.xml"/>
```

with:

```xml
  <!-- Variations (replaces the deprecated SNP record above) -->
  <import file="model/records/variationAttributeQueries.xml"/>
  <import file="model/records/variationTableQueries.xml"/>
  <import file="model/records/variationRecords.xml"/>
  <import file="model/questions/params/variationParams.xml"/>
  <import file="model/questions/queries/variationQueries.xml"/>
  <import file="model/questions/variationQuestions.xml"/>
```

Params before queries before questions — the order every other record's block uses
(compare the `spanParams`/`spanQueries`/`spanQuestions` trio just above).

- [ ] **Step 3: Verify the edit is well-formed and complete**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk && \
  xmllint --noout apiCommonModel.xml && grep -c 'variation' apiCommonModel.xml
```

Expected: no xmllint output, then `6`.

- [ ] **Step 4: Build the model on the remote**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb model
```

Expected: the build runs to completion and reloads the webapp. `wb model` (not
`ontology`) deliberately — this step proves the *model* references resolve, isolating an
XML mistake from an ontology mistake. The ontology row comes in Task 3.

If it fails, the useful signal is in the model-load stack trace: an unresolved
`queryRef`/`paramRef`/`recordClassRef` names the exact broken reference. Fix and re-run
before going on.

- [ ] **Step 5: Confirm the search is registered for this site**

Open an already-authenticated page on `https://jbrestel.plasmodb.org` (any app page —
the session cookie is what makes this work; a raw `curl` 307-redirects to autologin),
then via Claude in Chrome `javascript_tool`:

```javascript
fetch('/service/record-types/variation')
  .then(r => r.json())
  .then(d => console.log(JSON.stringify(d.searches.map(s => s.fullName), null, 2)))
```

Expected: the array contains `VariationQuestions.VariationBySourceId`.

This endpoint **is** project-filtered, which is why it is the source of truth for "does
this site have the search" — unlike the category tree checked in Task 3.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/apiCommonModel.xml
git commit -m "Import the variation question, query, and param files

Wires the new variation search files into the model. wb model succeeds and
/service/record-types/variation now lists
VariationQuestions.VariationBySourceId.

The search is not yet categorized, so it will not appear in the searches
menu until the individuals.txt row lands.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Place the search in the category ontology

Until this lands the search exists in the model but appears nowhere in the UI's search
menu, because the menu is built from the OWL.

**Files:**
- Modify: `Model/lib/wdk/ontology/individuals.txt` (append after line 1157)

- [ ] **Step 1: Confirm the file's column layout and the variation block's end**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/ontology && \
  head -1 individuals.txt | tr '\t' '\n' | cat -n && \
  tail -1 individuals.txt && wc -l individuals.txt
```

Expected: 14 columns —
1 (blank, the subject id), 2 (blank, parent IRI), 3 (blank, parent label),
4 `recordClassName`, 5 `targetType`, 6 `name`, 7 `displayName`, 8 `shortDisplayName`,
9 `description`, 10 `geneOrTranscript`, 11 `displayOrder`, 12–14 `scope`.
The last line is `...VariationRecordClass.PredictedEffects`, and the count is `1157`. The
variation block runs 1104–1157 and ends the file, so the new row is appended.

- [ ] **Step 2: Append the search row**

This file is **tab-delimited** and the empty columns matter, so append it with a command
rather than by hand — a mistyped run of spaces silently shifts `menu` into the
`displayOrder` column:

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/ontology && \
printf '%s\t%s\t%s\t%s\t%s\t%s\t\t\t\t\t\t%s\t%s\t\n' \
  'VariationRecordClasses.VariationRecordClass.VariationQuestions.VariationBySourceId' \
  'http://edamontology.org/topic_0199' \
  'Genetic Variation' \
  'VariationRecordClasses.VariationRecordClass' \
  'search' \
  'VariationQuestions.VariationBySourceId' \
  'menu' \
  'webservice' \
  >> individuals.txt
```

Parent node `topic_0199` / "Genetic Variation" and the `menu` + `webservice` scope pair
are what `PopsetQuestions.PopsetByPopsetId` uses, and `topic_0199` is already the parent
of the record's gene-linkage and effect-rollup attributes (record §8).

- [ ] **Step 3: Verify the row has the right shape**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel/Model/lib/wdk/ontology && \
  tail -1 individuals.txt | awk -F'\t' '{print NF" fields"; print "5="$5; print "6="$6; print "12="$12; print "13="$13}'
```

Expected exactly:

```
14 fields
5=search
6=VariationQuestions.VariationBySourceId
12=menu
13=webservice
```

A field count other than 14, or `menu` landing anywhere but column 12, means the `printf`
was edited — redo Step 2 verbatim.

- [ ] **Step 4: Rebuild the ontology**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-build.sh plasmodb wb ontology
```

Expected: completes and reloads the webapp. **`wb ontology`, not `wb model`** — this is a
categorization change, and `wb model` would leave the OWL stale with no error anywhere.
`wb ontology` is a superset of `wb model`, so it is the only build needed here.

- [ ] **Step 5: Confirm placement in the assembled tree**

From an authenticated app page, via `javascript_tool`:

```javascript
fetch('/service/ontologies/Categories')
  .then(r => r.json())
  .then(d => {
    const hits = [];
    (function walk(node, parent) {
      const p = node.properties || {};
      if ((p.name || []).includes('VariationQuestions.VariationBySourceId')) {
        const pp = (parent && parent.properties) || {};
        hits.push({
          parentLabel: pp.label,
          parentTerm: pp['EuPathDB alternative term'],
          targetType: p.targetType
        });
      }
      (node.children || []).forEach(c => walk(c, node));
    })(d.tree, null);
    console.log(JSON.stringify(hits, null, 2));
  })
```

Expected: exactly one hit, with `targetType` `["search"]` and the parent's
`EuPathDB alternative term` reading `Genetic Variation`.

Remember this endpoint is **not** project-filtered — use it for placement only. Presence
for this site was already established in Task 2 Step 5.

- [ ] **Step 6: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add Model/lib/wdk/ontology/individuals.txt
git commit -m "Categorize the VariationBySourceId search under Genetic Variation

Places the search under edamontology topic_0199 with menu and webservice
scopes, matching the Popset ID search and the parent already used by the
variation record's gene-linkage and effect-rollup attributes.

Verified via /service/ontologies/Categories after wb ontology.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Verify the search actually works

No code changes — this is the rung of the ladder that catches what the model and service
cannot: whether the SQL returns the right rows and the page renders. Do not skip it on the
grounds that the build passed.

**Files:** none.

- [ ] **Step 1: Mark the logs**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb mark variation-search-qa
```

- [ ] **Step 2: Render the assembled SQL and the param list**

```bash
cd ~/workspaces/agentic-veupath-dev && \
ssh "$(python3 bin/resolve.py --profile profiles/plasmodb.yml --field host)" \
  'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
   wdkQuery -model PlasmoDB -query VariationsBy.VariationBySourceId -showParams"'
```

Expected: reports the single param `variation_id`.

Then attempt the SQL render:

```bash
cd ~/workspaces/agentic-veupath-dev && \
ssh "$(python3 bin/resolve.py --profile profiles/plasmodb.yml --field host)" \
  'bash -lc "source /var/www/jbrestel.plasmodb.org/etc/setenv && \
   wdkQuery -model PlasmoDB -query VariationsBy.VariationBySourceId -showQuery"'
```

**This one is allowed to fail, and a failure is not a defect.** `$$variation_id$$` is a
`datasetParam` macro that expands to a subquery against the user-dataset tables, which
needs a dataset ID that only exists once a user has actually submitted the form — there
is nothing for the CLI to substitute. If it errors on the missing param value, record
that in the task notes and move on; Steps 3–5 are the real test of the SQL. If it *does*
render, read the SQL and confirm it selects `source_id`/`project_id` from
`ApidbTuning.VariationAttributes`.

(Both commands need the concrete docroot. `/var/www/jbrestel.plasmodb.org` above assumes
`user: jbrestel`; get it for the current identity with
`python3 bin/resolve.py --profile profiles/plasmodb.yml --field docroot`.)

- [ ] **Step 3: Find the search in the site's search menu and open it**

In Claude in Chrome, load `https://jbrestel.plasmodb.org`, open the searches menu, and
find **"Variation ID(s)"** under the Variation record type. This is the user-visible
payoff of Task 3 and the one thing none of the service checks prove — so navigate here
rather than deep-linking.

(The direct URL is roughly
`<base>/<context>/app/search/variation/VariationBySourceId`, but the context path segment
is site-specific and is not recorded in this instance's `docs/app.md`. Read the real URL
off the address bar once the menu gets you there, and note it in `docs/app.md` under "Key
pages" so the next session can deep-link.)

Expected: the form renders with an ID input box prefilled from the `suggest` default
(`Variant_Pf3D7_01_v3_100057`), labelled "Variation ID input set", with manual-entry and
file-upload options.

Submit it. Expected: lands **directly on the record page** for
`Variant_Pf3D7_01_v3_100057` with no intervening result page — that is
`noSummaryOnSingleRecord="true"` working.

- [ ] **Step 4: Multi-ID search shows the record's default columns, and tolerates a bad ID**

Go back to the search and submit these four IDs, comma-delimited — three real, one
deliberately bogus:

```
Variant_Pf3D7_01_v3_100057, Variant_Pf3D7_01_v3_29514, Variant_Pf3D7_01_v3_12, Variant_Nonexistent_9999
```

Expected: a result page with **3 rows**, not 4. An unmatched ID is silently absent, which
is the `datasetParam` norm; no error is shown.

Confirm the columns are the record's defaults (record §6.9), i.e. that no
`attributesList` override crept in: Location, Gene ID(s), Variant Type, the collapsed
allele and collapsed minor allele frequency, both `most_severe_impact_*` columns, and
strain count.

`Variant_Pf3D7_01_v3_12` is the `MIXED` locus documented in record §2, so its collapsed
allele should show both classes joined with `; ` (e.g. `A>C; A>AC`) — a free check that
the search feeds the record's attribute layer correctly rather than a stripped-down one.

- [ ] **Step 5: Confirm nothing broke**

```bash
cd ~/workspaces/agentic-veupath-dev && bin/veup-logs.sh plasmodb since variation-search-qa --quiet
```

Expected: the error logs (`svc-error`, `wdk`, `error`, `catalina`) report `silent:`. Page
views and service access lines for the searches are expected and fine.

- [ ] **Step 6: Record the results in the plan**

Tick the boxes above and note the Step 2 `-showQuery` outcome (rendered vs. failed on the
`datasetParam` macro) inline, so the next person does not re-litigate it.

---

### Task 5: Update the spec's status and close out

**Files:**
- Modify: `docs/superpowers/specs/2026-08-05-variation-searches-design.md` (the `Status:`
  line)
- Modify: `docs/superpowers/plans/2026-08-05-variation-searches.md` (this file, checkboxes)

- [ ] **Step 1: Confirm the whole change set is exactly what was intended**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel && \
  git diff --stat HEAD~3 && grep -rn 'jbrestel' Model/lib/wdk/ ; echo "grep exit: $?"
```

Expected: five files touched — the three new question-side files, `apiCommonModel.xml`,
and `ontology/individuals.txt` — and **no `jbrestel` matches** (`grep exit: 1`). A match
in `Model/lib/wdk/` is a merge blocker.

- [ ] **Step 2: Mark the spec implemented**

In `docs/superpowers/specs/2026-08-05-variation-searches-design.md`, change:

```markdown
**Status:** approved
```

to:

```markdown
**Status:** implemented 2026-08-05 (scaffolding + `VariationBySourceId`; the four searches in §8.1 remain unstarted)
```

- [ ] **Step 3: Commit**

```bash
cd ~/workspaces/plasmodb/ApiCommonModel
git add docs/superpowers/specs/2026-08-05-variation-searches-design.md \
        docs/superpowers/plans/2026-08-05-variation-searches.md
git commit -m "Mark the variation searches spec implemented

Scaffolding and VariationBySourceId are built and verified on the plasmodb
dev instance. The four HSSS-backed searches remain out of scope pending the
per-strain seam.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Execution outcome (2026-08-05)

Commits, in order: `6130ef92f` (three files), `ff563a570` (comment fix from review),
`cf87f9d99` (imports), `eaa4757b8` (ontology row). Final change set is exactly the five
files this plan names — 95 insertions, no deletions — and `grep -rn 'jbrestel'
Model/lib/wdk/` is clean.

### Verified

- `wb model` passed in 54s. The assembled PlasmoDB model contains `Question:
  name='VariationBySourceId'` with `query='VariationsBy.VariationBySourceId'` and
  `columns{source_id, project_id}` — which also settles the open question of whether
  `ApidbTuning.VariationAttributes` exposes `project_id`. It does.
- `wb ontology` passed in 1m4s and regenerated `individuals.owl` →
  `categories_merged.owl`. The merged OWL holds exactly one `owl:Class` for the search,
  with `subClassOf topic_0199`, `targetType search`, and both `menu` and `webservice`
  scopes — downstream proof the tab-delimited row parsed into the right columns.
- The search appears in the site's searches menu.
- Single ID → straight to the record page, confirming `noSummaryOnSingleRecord`.
- Multi-ID → the record's **default** summary columns, confirming that inheriting rather
  than overriding `attributesList` took effect.
- No error-log activity: `errors-retained.log`, `errors-client-retained.log`, and the
  httpd `error_log` were all last written days-to-months before this work.

### Substituted

- **`/service/record-types/variation` and `/service/ontologies/Categories` were not
  fetched.** The Chrome profile sat behind the `veupathdb.org/auth/bin/autologin`
  pre-release gate for most of the session. Server-side equivalents were used instead:
  `wdkXml -model PlasmoDB` for registration (project-filtered, so it answers the same
  question) and a grep of the built `categories_merged.owl` for placement.

  Worth recording as a trap: once a tab is bounced to the autologin gate, relative-path
  `fetch` calls hit **veupathdb.org production**, not the dev instance, and return
  confident wrong answers — one agent nearly reported the search missing on that basis.
  Always check `window.location.origin` before trusting a relative fetch.
- **The log check was not a delta.** The `mark` step was skipped, so the error logs were
  read directly by mtime rather than by byte offset. Equivalent here only because the
  logs were entirely untouched.

### Not run

- **`wdkQuery -showQuery`** on the search. As this plan anticipated, `$$variation_id$$`
  is a `datasetParam` macro with nothing for the CLI to substitute; it fails with
  `ValidObjectWrappingException: {"keyedErrors":{"variation_id":["Cannot be empty."]}}`
  after reaching `WDK Model construction complete`. A `wdkQuery` limitation, not a model
  defect. Do not re-litigate it — for this search the browser is the only path that
  executes the SQL.
- **The empty-project case** (form renders, 0 rows, no error). Unrunnable from the
  plasmodb instance, which has data. Still owed whenever one of the five projects in
  §4.1 is next stood up.

### Incidental findings

- The app is served under `/a/` — `/a/app`, service at `/a/service`.
- `individuals.txt` column 3 reads "Genetic Variation", matching the neighbouring
  variation rows and the Popset search, but the edam parent's actual display term in the
  merged OWL is "Genetic variation" (lowercase v). Column 3 is a human-readable
  convenience — parenting is by the `topic_0199` IRI — so nothing is broken and nothing
  was changed. Noted because it makes the plan's expected-string check look like a
  mismatch.
- Local commits leave the remote's git index stale, so `cedar` reports phantom
  modifications on `apiCommonModel.xml` and `individuals.txt`. `veup-git-sync.sh` cannot
  reconcile it while `dnaseq-merge-experiments` is unpushed (it reports `UNPUSHED` and
  skips). Harmless for building; push the branch first if the noise matters.

## Deliberately not in this plan

- **The four remaining snp searches** — `NgsSnpsByIsolateGroup`, `NgsSnpsByLocation`,
  `NgsSnpsByGeneIds`, `NgsSnpsByTwoIsolateGroups`(`Wiz`). Spec §8.1: they are HSSS
  `processQuery` searches over per-strain data, which is the seam record §9 deferred.
  Their spec's first question is what replaces HSSS, not what the XML looks like.
- **ID tolerance for coordinate-style input** — spec §5.1. If it is ever wanted, it goes
  in `VariationAttributes.VariationAlias`, not in a search's SQL.
- **`<suggest>` defaults for AmoebaDB, CryptoDB, MicrosporidiaDB, PiroplasmaDB, ToxoDB** —
  spec §4.1. They need loaded data first; do not invent IDs.
- **Narrowing `includeProjects` to the three projects with loaded data.** Spec §2: all
  nine are expected to have variation data in the full database. The empty ones are an
  artifact of the subset dev appDb.
- **Verifying the empty-project case** (form renders, 0 rows, no error). Spec §7.3 step 7
  — it cannot be checked from the plasmodb instance, which has data. Run it when one of
  those five sites is next stood up.
- **A sanity-test file.** `apiCommonModel-sanity.xml` imports a directory that does not
  exist; the whole sanity model is dead. Do not extend it.
- **Uncommenting the dead snp block** to compare behavior. It references
  `apidbtuning.SnpAttributes`, which does not exist in this build; the model would fail to
  load. Spec §1.1.
- **Deleting the dead snp model XML.** Record §10: its own blast radius
  (`recordParams.xml`, `spanQuestions.xml`, `SnpsBySpanLogic`).
