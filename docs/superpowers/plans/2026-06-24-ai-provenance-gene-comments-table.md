# AI Provenance in Gene-Page User Comments Table — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show, in the gene-page User Comments table, which comments were AI-assisted and whether the reviewer edited the AI text or published it as-is — plus surface the AI source PMID in the existing PubMed column.

**Architecture:** Pure WDK-model change in one repo (`ApiCommonModel`). Extend the `GeneComments` SQL query to join the two AI sidecar tables, emit a styled-pill "display" copy of the `user_name_org` column alongside a plain-text copy, and `UNION` the AI run-row PMID into the PubMed aggregate. Wire the two copies into `geneRecord.xml` so the on-screen table shows the pill while downloads/sorting use clean text.

**Tech Stack:** WDK model XML, PostgreSQL SQL (the comment DB), Maven build.

## Global Constraints

- **Scope: gene page only.** Modify only `CommentTables.GeneComments` and the `UserComments` table in `geneRecord.xml`. Do **not** touch `CommunityComments`, `GenomeComments`, `PopsetComments`, or their record tables.
- **Single repo.** All edits are in `ApiCommonModel`. No web-monorepo / front-end change (pill styling is inline CSS).
- **Sidecar tables, exact names** (in the comment schema, reached via the `@REMOTE_COMMENT_SCHEMA@` macro):
  - `comment_ai_provenance` — columns used: `comment_id`, `run_job_id`, `is_edited`.
  - `comment_ai_run` — columns used: `job_id`, `source_kind`, `pubmed_id`.
- **Join keys:** `comment_ai_provenance.comment_id = MappedComment.comment_id`; `comment_ai_provenance.run_job_id = comment_ai_run.job_id`. `comment_ai_provenance` is 1 row per `comment_id` (PK), so the join cannot multiply comment rows.
- **Pill style (inline CSS, verbatim):** `display:inline-block;margin-left:6px;padding:1px 6px;border-radius:8px;background-color:#0a7c8a;color:#fff;font-size:0.85em;font-weight:500;white-space:nowrap;`
- **Pill text:** `AI-assisted &middot; edited` or `AI-assisted &middot; as-is`. **Plain-text suffix** (download column): ` · AI-assisted (edited)` or ` · AI-assisted (as-is)`.
- **Build prerequisite** (per project `CLAUDE.md`): `install/` and `WDK/` must already be built into `~/.m2` before building this module.

---

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `Model/lib/wdk/model/records/commentTableQueries.xml` | `GeneComments` SQL: joins, split `user_name_org`/`user_name_org_display` columns, PMID union | Modify |
| `Model/lib/wdk/model/records/geneRecord.xml` | `UserComments` table: present the two "Made by" columns | Modify |

There are no automated unit tests for WDK model SQL/XML in this repo. The per-change gates are **(1) XML well-formedness** (`xmllint --noout`) and **(2) the Maven build**. Full validation is a **manual step on a deployed instance** (and an optional direct-SQL smoke test against the dev comment DB) — see the Manual Verification section at the end.

---

## Task 1: Extend the `GeneComments` SQL query

**Files:**
- Modify: `Model/lib/wdk/model/records/commentTableQueries.xml` (the `GeneComments` `<sqlQuery>`, lines ~40–162)

**Interfaces:**
- Produces (for Task 2): SQL output columns `user_name_org` (plain text incl. provenance suffix) and `user_name_org_display` (name + inline-styled pill HTML).
- Produces: `pmids` aggregate now also contains AI run-row PMIDs.

All four edits below are in the same `GeneComments` query block. Apply them, then run the single verification at the end of the task.

- [ ] **Step 1: Add the `user_name_org_display` column declaration**

In the `<column .../>` list for `GeneComments` (currently `commentTableQueries.xml:66`), add the new column right after the existing `user_name_org` declaration.

Find:
```xml
      <column name="user_name_org"/>
      <column name="comment_date"/>
```
Replace with:
```xml
      <column name="user_name_org"/>
      <column name="user_name_org_display"/>
      <column name="comment_date"/>
```

- [ ] **Step 2: Split the `user_name_org` SELECT expression into plain + display**

Find the final SELECT item (currently `commentTableQueries.xml:96-97`):
```sql
            &&selectReviewed&&
            CONCAT(u.first_name , ' ' , u.last_name , ', ' , u.organization ) as user_name_org
          FROM
```
Replace with:
```sql
            &&selectReviewed&&
            CONCAT(u.first_name , ' ' , u.last_name , ', ' , u.organization ,
              CASE
                WHEN aiprov.comment_id IS NULL THEN ''
                WHEN aiprov.is_edited        THEN ' · AI-assisted (edited)'
                ELSE                              ' · AI-assisted (as-is)'
              END) as user_name_org,
            CASE
              WHEN aiprov.comment_id IS NULL
                THEN CONCAT(u.first_name , ' ' , u.last_name , ', ' , u.organization )
              ELSE CONCAT(u.first_name , ' ' , u.last_name , ', ' , u.organization ,
                '<span style="display:inline-block;margin-left:6px;padding:1px 6px;border-radius:8px;background-color:#0a7c8a;color:#fff;font-size:0.85em;font-weight:500;white-space:nowrap;">AI-assisted &middot; ',
                CASE WHEN aiprov.is_edited THEN 'edited' ELSE 'as-is' END,
                '</span>')
            END as user_name_org_display
          FROM
```
(The ` · ` separator in the plain column is a literal middot UTF-8 character; the file is UTF-8. The display column uses the `&middot;` HTML entity, which the record-table renderer renders as `·`.)

- [ ] **Step 3: Add the `comment_ai_provenance` LEFT JOIN**

Find the `gene_counts` LEFT JOIN block (currently ends at `commentTableQueries.xml:119`):
```sql
            ) gene_counts ON c.comment_id = gene_counts.comment_id
            LEFT JOIN (
              SELECT dr.primary_identifier AS comment_id , ta.gene_source_id
```
Replace with (insert the new join between `gene_counts` and `integrated_comments`):
```sql
            ) gene_counts ON c.comment_id = gene_counts.comment_id
            LEFT JOIN @REMOTE_COMMENT_SCHEMA@comment_ai_provenance aiprov
              ON c.comment_id = aiprov.comment_id
            LEFT JOIN (
              SELECT dr.primary_identifier AS comment_id , ta.gene_source_id
```
(Only `comment_ai_provenance` is joined here — that is all the `user_name_org` columns need. The run table is joined inside the PMID subquery in the next step.)

- [ ] **Step 4: Union the AI run-row PMID into the `refs` subquery**

Find the `refs` subquery (currently `commentTableQueries.xml:108-113`):
```sql
            LEFT JOIN (
              SELECT comment_id, string_agg(source_id,',') as pmids
              FROM @REMOTE_COMMENT_SCHEMA@CommentReference
              WHERE database_name='pubmed'
              GROUP BY comment_id
            ) refs ON c.comment_id = refs.comment_id
```
Replace with:
```sql
            LEFT JOIN (
              SELECT comment_id, string_agg(source_id,',') as pmids
              FROM (
                SELECT comment_id, source_id
                FROM @REMOTE_COMMENT_SCHEMA@CommentReference
                WHERE database_name='pubmed'
                UNION
                SELECT cap.comment_id, car.pubmed_id AS source_id
                FROM @REMOTE_COMMENT_SCHEMA@comment_ai_provenance cap
                JOIN @REMOTE_COMMENT_SCHEMA@comment_ai_run car ON cap.run_job_id = car.job_id
                WHERE car.source_kind = 'pubmed' AND car.pubmed_id IS NOT NULL
              ) merged
              GROUP BY comment_id
            ) refs ON c.comment_id = refs.comment_id
```
(`UNION` (not `UNION ALL`) dedupes a PMID that is present both as a manual `CommentReference` and as the AI source. The downstream `pmids_link` CASE is unchanged.)

- [ ] **Step 5: Verify XML well-formedness**

Run:
```bash
cd /home/maccallr/work/ai-wdk/project_home/ApiCommonModel
xmllint --noout Model/lib/wdk/model/records/commentTableQueries.xml && echo WELL_FORMED
```
Expected: prints `WELL_FORMED` with no parser errors. (Catches a missing quote/paren/tag from the SQL edits.)

- [ ] **Step 6: Commit**

```bash
cd /home/maccallr/work/ai-wdk/project_home/ApiCommonModel
git add Model/lib/wdk/model/records/commentTableQueries.xml
git commit -m "feat: AI provenance + source PMID in GeneComments query

Join comment_ai_provenance for the Made-by pill, emit a plain
user_name_org (downloads/sort) plus a styled user_name_org_display
column, and union the AI run-row PMID into the PubMed aggregate.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: Present the two "Made by" columns in `geneRecord.xml`

**Files:**
- Modify: `Model/lib/wdk/model/records/geneRecord.xml` (the `UserComments` table, line ~1713)

**Interfaces:**
- Consumes (from Task 1): SQL columns `user_name_org` and `user_name_org_display`.

- [ ] **Step 1: Replace the single Made-by columnAttribute with two**

Find (currently `geneRecord.xml:1713`):
```xml
        <columnAttribute name="user_name_org" displayName="Made by"/>
```
Replace with:
```xml
        <!-- plain text: hidden on screen, used by report maker / downloads + sorting -->
        <columnAttribute name="user_name_org" displayName="Made by" internal="true"/>
        <!-- name + styled AI-assisted pill: shown on screen as "Made by", excluded from downloads -->
        <columnAttribute name="user_name_org_display" displayName="Made by" inReportMaker="false"/>
```
(`FieldScope` treats `internal` and `inReportMaker` independently: on screen the `NON_INTERNAL` scope hides `user_name_org` and shows `user_name_org_display`; in report maker the `REPORT_MAKER` scope excludes `user_name_org_display` and includes the plain `user_name_org`.)

- [ ] **Step 2: Verify XML well-formedness**

Run:
```bash
cd /home/maccallr/work/ai-wdk/project_home/ApiCommonModel
xmllint --noout Model/lib/wdk/model/records/geneRecord.xml && echo WELL_FORMED
```
Expected: prints `WELL_FORMED`.

- [ ] **Step 3: Build the model module**

Run (per project `CLAUDE.md` — assumes `install/` and `WDK/` already built into `~/.m2`):
```bash
cd /home/maccallr/work/ai-wdk/project_home/ApiCommonModel
mvn -q clean install
```
Expected: `BUILD SUCCESS`. This confirms both modified files assemble into the model artifact. (Build failure here most likely means a typo in a column name or malformed XML.)

- [ ] **Step 4: Commit**

```bash
cd /home/maccallr/work/ai-wdk/project_home/ApiCommonModel
git add Model/lib/wdk/model/records/geneRecord.xml
git commit -m "feat: show AI-assisted pill in gene-page User Comments Made-by column

Split the Made-by attribute into a plain internal column (downloads/sort)
and a display column carrying the inline-styled AI-assisted pill.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Manual Verification (deployed instance)

These cannot be automated in this repo (no DB/model-runtime in the build). Run them on a deployed dev instance whose comment DB has the two sidecar tables exposed under `@REMOTE_COMMENT_SCHEMA@`. They mirror the spec's verification checklist.

- [ ] **Coordination precheck:** confirm `comment_ai_run` and `comment_ai_provenance` are reachable under the schema that `@REMOTE_COMMENT_SCHEMA@` resolves to (the same place `CommentReference` lives). If not yet mapped, the query errors — escalate before deploying.
- [ ] **Optional direct-SQL smoke test:** run the edited `GeneComments` SQL against the dev comment DB (substitute the real schema for `@REMOTE_COMMENT_SCHEMA@`, a real `org_abbrev`/`source_id`) for a gene known to have (a) a human comment, (b) an edited AI comment, (c) an as-is AI comment. Confirm `user_name_org`, `user_name_org_display`, and `pmids` come back as expected and the row count is unchanged vs the pre-change query (the provenance join must not multiply rows).
- [ ] **Human comment (regression):** gene page shows "Made by" = name+org, **no pill**; PubMed column unchanged.
- [ ] **AI comment, edited:** shows the teal `AI-assisted · edited` pill; its source PMID appears (linked) in the PubMed column even with no `CommentReference` row.
- [ ] **AI comment, as-is:** shows `AI-assisted · as-is`.
- [ ] **Upload-source AI comment:** shows the pill; PubMed column empty (no PMID).
- [ ] **Download:** add the User Comments table to a report → "Made by" column is plain text `Name, Org · AI-assisted (edited)` with **no `<span>` markup**; no separate display column appears.
- [ ] **PMID dedupe:** an AI comment whose source PMID is also a manual `CommentReference` shows that PMID once.

---

## Self-Review

- **Spec coverage:** join (Task 1 Step 3) ✓; two-column split (Task 1 Step 2, Task 2 Step 1) ✓; inline-CSS pill (Task 1 Step 2, constraint) ✓; clean-download split via `internal`/`inReportMaker` (Task 2 Step 1) ✓; PMID union (Task 1 Step 4) ✓; gene-only scope (Global Constraints) ✓; coordination note + verification (Manual Verification) ✓.
- **Placeholder scan:** none — every step shows exact find/replace content and exact commands.
- **Type/name consistency:** SQL columns `user_name_org` / `user_name_org_display` are produced in Task 1 and consumed by the same names in Task 2; join aliases `aiprov` (top level) and `cap`/`car` (subquery) are self-contained per scope.
