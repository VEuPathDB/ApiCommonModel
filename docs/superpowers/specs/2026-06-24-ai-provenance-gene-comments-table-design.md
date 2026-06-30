# Design: AI-assisted provenance in the gene-page User Comments table

**Date:** 2026-06-24
**Repo:** `ApiCommonModel`
**Status:** Approved for implementation planning

## Context

VEuPathDB has added a new kind of user comment — an AI-assisted gene-publication
summary. The comment-generation, review, and publish flow is complete: publishing
an AI-assisted comment creates an ordinary `comments` row plus two sidecar rows in
the comment schema:

- `comment_ai_provenance` (per published comment): `comment_id`, `run_job_id`,
  `is_edited` (true iff the published text differs from the AI original),
  `created_at`.
- `comment_ai_run` (shared LLM-output cache, keyed by `job_id`): source kind
  (`pubmed` | `upload`), `pubmed_id`, `external_url`, `external_title`,
  `pdf_content_sha256`, the AI original headline/content, etc.

See `ApiCommonWebsite/Service/CLAUDE-ai-user-comments.md` for the full back-end
design and `GetCommentAiProvenanceQuery.java` for the canonical join pattern
(`comment_ai_provenance p JOIN comment_ai_run r ON p.run_job_id = r.job_id`).

This spec covers **one thing only**: showing users which rows in the gene-page
User Comments table were AI-assisted, and whether the human reviewer edited the
AI text or published it unedited.

## Goal

In the gene-page **User Comments** table (`CommentTables.GeneComments` →
`UserComments` table in `geneRecord.xml`), each comment row should communicate:

1. **Whether the comment was AI-assisted** (a `comment_ai_provenance` row exists).
2. **If AI-assisted, whether it was edited or published unedited** (`is_edited`).

An AI-assisted comment is still published by a real, logged-in user who reviewed
it — so the framing is "made by Dr So-and-so, **AI-assisted**", never "made by AI".

## Decisions (all approved)

| # | Decision | Choice |
|---|----------|--------|
| 1 | What to show | AI-assisted yes/no **+** edited-vs-unedited |
| 2 | Placement | Fold into the existing **"Made by"** column (no new column) |
| 3 | Visual treatment | A small **styled teal pill** after the name (matches the FE "Beta" badge) |
| 4 | Pill styling mechanism | **Inline CSS** in the SQL string (self-contained, single repo, matches `snp_context` precedent) |
| 5 | Downloads / sort | Two-column split so downloads are **HTML-free plain text** carrying ` · AI-assisted (edited\|unedited)`, and sort keys off the plain name |
| 6 | Source paper | Fold `comment_ai_run.pubmed_id` into the **existing PubMed column** via a `UNION` in the `refs` subquery |
| 7 | Records/scope | **Gene page only** (`GeneComments`); other comment tables untouched |

## Technical findings (verified)

- **Reachability:** `GeneComments` already `LEFT JOIN`s sibling tables in the
  comment schema (`CommentFile`, `CommentReference`). `comment_ai_provenance` and
  `comment_ai_run` live in that same schema, so they are reachable with the
  identical `@REMOTE_COMMENT_SCHEMA@` prefix.
- **HTML rendering:** the record-table renderer renders a cell value as HTML when
  it looks like HTML (`RecordTable.jsx`, `MesaUtils.isHtml(val)`) — this is how
  the existing `pmids_link` `<a>` renders. So an inline-styled `<span>` pill in a
  column value will render.
- **`internal` vs `inReportMaker` are independent scopes** (`FieldScope.java`):
  the report-maker scope only excludes `inReportMaker=false` fields (internal
  fields still flow into reports); the on-screen scope excludes `internal=true`.
  Both flags are settable per `columnAttribute` (`wdkModel.rng:1468-1473`). This
  is what makes the two-column split work cleanly.
- **No HTML stripping** in the tabular reporter — a column's value is dumped
  verbatim, which is exactly why the *display* (pill) column must be excluded from
  reports and a *plain* column provided for download.

## Changes

### 1. `Model/lib/wdk/model/records/commentTableQueries.xml` — `GeneComments` query

**a. Add the provenance joins** (same pattern as the existing `files` / `refs`
joins):

```sql
LEFT JOIN @REMOTE_COMMENT_SCHEMA@comment_ai_provenance p
       ON c.comment_id = p.comment_id
LEFT JOIN @REMOTE_COMMENT_SCHEMA@comment_ai_run r
       ON p.run_job_id = r.job_id
```

`p.comment_id IS NOT NULL` ⇒ AI-assisted. `p.is_edited` ⇒ edited vs unedited.

**b. Replace the single `user_name_org` SELECT expression with two columns.**
The current expression is:

```sql
CONCAT(u.first_name , ' ' , u.last_name , ', ' , u.organization ) as user_name_org
```

Becomes a base name expression plus two derived columns:

```sql
-- plain text: download- and sort-safe; carries a plain provenance suffix
CONCAT(
  u.first_name, ' ', u.last_name, ', ', u.organization,
  CASE
    WHEN p.comment_id IS NULL THEN ''
    WHEN p.is_edited        THEN ' · AI-assisted (edited)'
    ELSE                          ' · AI-assisted (unedited)'
  END
) AS user_name_org,

-- display: name + inline-styled teal pill (rendered as HTML on screen)
CONCAT(
  u.first_name, ' ', u.last_name, ', ', u.organization,
  CASE
    WHEN p.comment_id IS NULL THEN ''
    WHEN p.is_edited THEN
      ' <span style="display:inline-block;margin-left:6px;padding:1px 6px;'
      || 'border-radius:8px;background-color:#0a7c8a;color:#fff;'
      || 'font-size:0.85em;font-weight:500;white-space:nowrap;">'
      || 'AI-assisted · edited</span>'
    ELSE
      ' <span style="display:inline-block;margin-left:6px;padding:1px 6px;'
      || 'border-radius:8px;background-color:#0a7c8a;color:#fff;'
      || 'font-size:0.85em;font-weight:500;white-space:nowrap;">'
      || 'AI-assisted · unedited</span>'
  END
) AS user_name_org_display
```

Notes:
- Postgres string concatenation uses `||`; the existing query already mixes
  `CONCAT(...)` and `||` styles — match whichever the surrounding file prefers at
  implementation time (the `pmids_link` CASE uses `CONCAT`).
- Both `edited` and `unedited` use the **same** teal (`#0a7c8a`); only the text
  differs. (Hex finalisable at implementation; chosen to read as a "Beta"-style
  teal pill.)
- Add the new `<column name="user_name_org_display"/>` declaration to the
  `GeneComments` `<sqlQuery>` column list (alongside the existing
  `<column name="user_name_org"/>`).

**c. Fold the AI source PMID into the existing PubMed column.** Replace the
current `refs` subquery:

```sql
LEFT JOIN (
  SELECT comment_id, string_agg(source_id,',') as pmids
  FROM @REMOTE_COMMENT_SCHEMA@CommentReference
  WHERE database_name='pubmed'
  GROUP BY comment_id
) refs ON c.comment_id = refs.comment_id
```

with a `UNION` that adds the run-row PMID for AI comments:

```sql
LEFT JOIN (
  SELECT comment_id, string_agg(source_id, ',') AS pmids
  FROM (
    SELECT comment_id, source_id
    FROM @REMOTE_COMMENT_SCHEMA@CommentReference
    WHERE database_name = 'pubmed'
    UNION                       -- UNION (not ALL) dedupes a PMID present in both
    SELECT p.comment_id, r.pubmed_id AS source_id
    FROM @REMOTE_COMMENT_SCHEMA@comment_ai_provenance p
    JOIN @REMOTE_COMMENT_SCHEMA@comment_ai_run r ON p.run_job_id = r.job_id
    WHERE r.source_kind = 'pubmed' AND r.pubmed_id IS NOT NULL
  ) merged
  GROUP BY comment_id
) refs ON c.comment_id = refs.comment_id
```

The downstream `pmids_link` CASE (which builds the `<a>` link from `refs.pmids`)
is unchanged and keeps working. Upload-source AI comments have no PMID
(`external_url` instead) and correctly do not appear in the PubMed column.

### 2. `Model/lib/wdk/model/records/geneRecord.xml` — `UserComments` table

Currently:

```xml
<columnAttribute name="user_name_org" displayName="Made by"/>
```

Becomes two `columnAttribute`s:

```xml
<!-- plain text: hidden on screen, used by report maker / downloads + sorting -->
<columnAttribute name="user_name_org" displayName="Made by" internal="true"/>
<!-- styled pill: shown on screen as "Made by", excluded from downloads -->
<columnAttribute name="user_name_org_display" displayName="Made by" inReportMaker="false"/>
```

Result:
- **On screen** (`NON_INTERNAL` scope): `user_name_org` is hidden; `user_name_org_display`
  renders as "Made by" with the pill.
- **Report maker / download** (`REPORT_MAKER` scope): `user_name_org_display` is
  excluded; `user_name_org` is included as "Made by", clean plain text.
- **Sort / search**: operate on the plain `user_name_org`.

## Coordination / deployment note (not a code change here)

The `comment_ai_run` and `comment_ai_provenance` tables must be reachable under
`@REMOTE_COMMENT_SCHEMA@` (the website's mapped/FDW view of the comment DB), the
same way `CommentReference` and `CommentFile` already are. Confirm with whoever
provisions the comment-DB replication/mapping that the two new sidecar tables are
exposed there before this query ships. If they are not yet mapped, the joins will
fail at query time.

## Out of scope

- Sorting *by AI-assisted status* as a first-class field (the plain
  `user_name_org` suffix is incidentally sortable; no dedicated sort field).
- De-duplication warnings.
- `/user-comments/show` page changes (separate follow-up).
- Other comment tables (`CommunityComments`, `GenomeComments`, `PopsetComments`).
- Making the pill themeable from the front-end (rejected in favour of inline CSS;
  would require a shared CSS class and web-monorepo coordination).

## Verification

1. **Build:** the model builds cleanly (`mvn clean install` per project
   `CLAUDE.md` build order: `install/` → `WDK/` → target module).
2. **Human comment (regression):** a gene with an ordinary user comment shows
   "Made by" with name+org and **no pill**; PubMed column unchanged.
3. **AI comment, edited:** a published AI comment with `is_edited=true` shows the
   teal `AI-assisted · edited` pill after the name; its source PMID appears in the
   PubMed column (as a link) even though no `CommentReference` row exists.
4. **AI comment, unedited:** `is_edited=false` shows `AI-assisted · unedited`.
5. **Upload-source AI comment:** shows the pill; PubMed column empty (no PMID).
6. **Download:** add the User Comments table to a report/download → "Made by"
   column contains plain text `Name, Org · AI-assisted (edited)` with **no HTML
   markup**; no `user_name_org_display` column appears.
7. **PMID dedupe:** an AI comment whose source PMID is also present as a manual
   `CommentReference` shows that PMID **once** (UNION dedupe).
