---
name: report
description: Build or refresh an Evidence report end to end (BigQuery, Jupyter notebook, CSVs, Evidence build, Cloudflare deploy, PDF export). Use when a finished analysis has to become a delivered report, or when an existing report needs fresh data. Two modes - scaffold a new slug from a business question, or refresh an existing slug. Always pauses for review before deploying.
argument-hint: [business question for a new report, or an existing report slug to refresh; omit to list the reports and ask]
user-invocable: true
---

# report

The delivery phase of the analytics pipeline (step 11 of its full numbering). The analysis is
done; this turns it into the thing a stakeholder reads.

"Evidence" always means [evidence.dev](https://evidence.dev), the BI-as-code tool where markdown
pages embed SQL. Never a Google Doc, a ClickUp doc or an RTF.

The project lives at `reporting/` in this repo. Every command below is written relative to the
repo root, so export the variable once at the start of the session and the snippets run as-is:

```bash
REPORTING="$(git rev-parse --show-toplevel)/reporting"
```

Layout: `pages/<slug>/index.md` (the report), `sources/<slug>/` (CSVs the notebook writes plus
`connection.yaml`), `notebooks/<slug_snake>.py` (the Jupyter notebook that queries BigQuery),
`partials/brand.md` (all shared CSS), `evidence.config.yaml` (theme), `deploy.sh`,
`export-pdf.sh`, `exports/` (gitignored scratch output).

The repo root `CLAUDE.md` holds the data traps that make numbers wrong (auth, export freshness,
param value types, `form_submit` over-firing, dead events, spam, materialized tables). Read it
before trusting any query. This skill governs the pipeline and the report content.

Two modes:

- **Refresh** - an existing slug: re-run its notebook, rebuild, review, deploy, re-export the PDF
  (steps 1 to 8).
- **New** - a business question: scaffold a fresh slug, then run the same chain (N1 to N5).

## 0 - Pick the mode, then preflight

- `$ARGUMENTS` names an existing slug (a directory under `$REPORTING/pages/`) -> **Refresh**.
- `$ARGUMENTS` is a business question or rough notes -> **New**.
- Empty -> list the slugs (`ls $REPORTING/pages`) and ask which to refresh, or whether to start a
  new report.

Preflight runs in both modes, **before any BigQuery touch**:

- Confirm the work account. `gcloud config get-value account` must return the work account, never
  a personal one. If it does not, **stop and tell the analyst**.
- **Never modify gcloud config, ADC, or quota-project settings.** Not to "fix" an auth error, not
  temporarily. A past fix of exactly that shape broke working auth and cost hours. Report the
  failure and stop.
- The gcloud account is not enough. Notebooks authenticate through ADC, a separate credential,
  and two things go wrong:
  - The shell exports `GOOGLE_APPLICATION_CREDENTIALS` pointing at a service account key that is
    for the GA4 Data API only and has no `bigquery.jobs.create`, so if it reaches the BigQuery
    client every query 403s. Always run with the var unset.
  - The user ADC file can still hold the personal account after any re-login.
- Verify empirically with a free dry-run canary:

  ```
  cd "$REPORTING" && \
  env -u GOOGLE_APPLICATION_CREDENTIALS uv run python -c "
  from google.cloud import bigquery
  c = bigquery.Client(project='your-gcp-project')
  c.query('SELECT 1', job_config=bigquery.QueryJobConfig(dry_run=True))
  print('ADC OK')"
  ```

  A 403 on `bigquery.jobs.create` means the user ADC is the wrong account. Stop and ask the
  analyst to run `gcloud auth application-default login` themselves with the work account, then
  rerun the canary.

- The headless invocation is therefore:

  ```bash
  cd "$REPORTING" && env -u GOOGLE_APPLICATION_CREDENTIALS uv run python notebooks/<slug_snake>.py
  ```

- The BigQuery project is pinned inside the notebooks.

- No report currently reads the GA4 Data API; every one of them queries BigQuery. If a report
  ever does need numbers fresher than the export, the Data API is the route (see `docs/config/ga4.md`),
  it authenticates with a different service account, and that account's key path is not recorded
  in this repo. Read it from private memory rather than hardcoding one.

## Slug convention

One report is one slug, spelled two ways. Getting this wrong breaks the build:

- **kebab-case for directories**: `pages/<slug>/`, `sources/<slug>/`
- **snake_case for code**: `notebooks/<slug_snake>.py`, and `name: <slug_snake>` in
  `sources/<slug>/connection.yaml`

That `name:` is the schema Evidence SQL blocks query, so a block reads
`select ... from <slug_snake>.<csv_basename>`. The CSV basename is the table name.

## Brand rules

The palette is fixed and lives in one token table. Do not invent colours. Swap the placeholders
below for your own brand tokens once, then never deviate per report.

| Token | Hex | Use |
|---|---|---|
| primary | `<brand-primary>` | primary text, all headings, chart series 1. The workhorse. |
| accent | `<brand-accent>` | links, TL;DR left border, active states, chart series 2 |
| accent-2 | `<brand-accent-2>` | secondary links and accents, later chart series |
| positive | `<brand-positive>` | primary CTA, positive semantic |
| highlight | `<brand-highlight>` | ratings, highlights, warning semantic |
| secondary | `<brand-secondary>` | secondary text and secondary chart series |
| neutrals | `<brand-neutrals>` | page background, callout background, rules |

Radii and typeface come from the same token sheet. Evidence body text stays its default
`#2c2c2c`; never override it.

Mechanics:

- **Every page starts with `{@partial "brand.md"}`** directly under the frontmatter. That is how a
  page gets the aesthetic.
- **Never add a second `<style>` block to a page.** One style source, shared.
- Any new styling a report needs goes into `partials/brand.md` as `:global(...)` so every report
  inherits it. Never fork styling per report.
- Explicit chart colours come from the token table: primary the workhorse, accents second, the
  highlight token for highlights, the secondary token for secondary series. Series colours
  otherwise come from the theme block in `evidence.config.yaml`, which is already correct.
- Copy tone follows the brand voice: confident, outcome-oriented, direct.

## Content rules

These are the rules the analyst has corrected before. Apply them while writing, not after.

- **Title: three words max.** Set `title:` in the frontmatter (it drives the h1, sidebar and
  breadcrumb) and use the same label on the hub `<LinkButton>`. Drop qualifiers and slashes:
  "Bot/Spam traffic - pattern analysis" becomes "Spam Traffic Analysis". Never rename the URL
  slug to match; renaming folders breaks links.
- **`.meta` line directly under the title**, carrying **Window** and **Source**. Always both,
  always there.
- **TL;DR is one to two sentences**: the finding plus its so-what, and the one number that
  matters. It is the headline, not a summary. Mechanism, caveats and supporting figures go in the
  body sections, which already have them.
- **An Outline** (linked list of sections) after the TL;DR, unless the report is a one-pager.
- **Block-level aggregates, not per-entity breakdowns**, unless the analyst asks. For a set of
  placements, slots or cards, report the block as one unit: total impressions, interactions, CTR.
  The decision is usually about the block ("keep this section?"), not about interchangeable
  entities inside it. Per-entity numbers belong in an appendix, and only on request. The
  exception: when the decision genuinely is about one entity, that entity is the unit.
- **One stat per row in per-entity cards.** `<p><b>Label:</b> value</p>` per stat, never inline
  with `·` or `|` separators. Cards scan top-to-bottom like a small fact sheet. Do not repeat in
  a card what the DataTable, flag column or legend below already shows.
- **Do not rebuild a view another tool already has.** Before adding a section, ask whether it is
  already in Looker Studio or an existing dashboard. Build the narrow thing that adds the missing
  view, not the broad thing that recreates the picture.
- Short section headings. Plain language, no jargon. Never the word "artifact". En dashes, never
  em dashes. No emojis.

## Refresh mode

### 1 - Refresh the data

- Record the current state first, so the checkpoint can show deltas: for each CSV in
  `sources/<slug>/`, the row count and, where there is an obvious date column, its max.
- If the notebook rescans raw `events_*` rather than the materialized `analytics_reports` tables,
  dry-run the expensive queries first and report the GB estimate. Flag anything unusually large
  before burning the scan.
- Run the notebook headless from `$REPORTING` with the env-aware invocation from preflight.
- **Verify empirically. An exit code proves nothing.** Check that every expected CSV in
  `sources/<slug>/` was rewritten just now (mtime) and holds a plausible row count. A notebook
  that "ran" and wrote nothing is a failure with a root cause, not a pass.
- Known trap: a `# %%` file has no cell gating, so the headless run executes every cell top to
  bottom. Any branch that behaves differently outside VS Code makes the two runs disagree - the
  common one is `__file__`, which exists headless and is absent when cells are run interactively.
  Derive paths once, at the top, the way `example_report.py` does, and keep every query and
  `write_csv` cell unconditional. Never guard a query on interactive state; a run that exits 0
  having written nothing is the failure this rule prevents.

### 2 - Rebuild and check conformance

- `cd $REPORTING && npm run sources && npm run build`. The build is the validation gate: it
  catches broken SQL blocks, missing columns and renamed sources.
- On any error, fix the root cause in the notebook or the page and rerun. Never carry stale
  output forward.
- Then check the page against the brand and content rules above: `{@partial "brand.md"}` right
  under the frontmatter, no second `<style>` block, explicit chart colours from the palette, the
  `.meta` Window and Source line under the title, a one-to-two-sentence TL;DR, an Outline on
  anything longer than a one-pager. Flag violations at the checkpoint. Do not rewrite an
  existing report's copy on your own.

### 3 - UX and data-viz pass

Required for anything dashboard-shaped, and worth a minute on any report. Correct numbers with
weak presentation still fail the non-expert audience these are built for. Review as a senior UX
and data-viz person would:

- Every chart and table has a title and, where the metric is not self-evident, a one-line
  definition or methodology caption.
- Each chart answers its section's question. A funnel visibly shows drop-off; a trend shows the
  trend, not a wall of bars.
- Honest encoding: axes start where they should, comparable charts share scales, colour carries
  meaning rather than decoration.
- No cells that read as broken (nulls, bare `0%`), nothing floating unaligned, sensible default
  date ranges.
- Fix the high-impact items and stop. Lean beats thorough here.

### 4 - CHECKPOINT (mandatory, never deploy without it)

Present to the analyst, concisely:

- Per CSV: rows before and after, plus the data date range.
- Anything that looks off: empty files, big row swings, gaps in dates, a metric that moved more
  than the window explains. **Flag it, do not smooth it over.** An unexplained swing is the
  finding.
- `git diff --stat` scoped to `sources/<slug>` and `pages/<slug>` so the analyst sees exactly
  what changed. Some files may be untracked, in which case git shows nothing for them; for those
  the before and after row counts from step 1 are the evidence. Say which basis was used.
- **Numbers only by default. Do not auto-start a preview.** If the analyst asks to eyeball it,
  start `npm run dev` and hand over the local URL.

Then wait for an explicit go. **"Pause before deploy" is the contract of this skill.**

### 5 - Deploy

- `cd $REPORTING && ./deploy.sh`, then report the deployment URL from the wrangler output.
- Use the script, never wrangler directly: it offloads the oversized DuckDB wasm files to a CDN,
  without which Cloudflare Pages rejects the upload.
- The live site is Cloudflare-Access-locked to the analyst's email. The URL is a private
  always-current preview, **not shareable**. The PDF is the deliverable.

### 6 - Export the PDF

- `cd $REPORTING && ./export-pdf.sh <slug>` writes `exports/<slug>.pdf`. No argument exports every
  report.
- Verify the file exists and is a non-trivial size, `open exports/<slug>.pdf` for a final look, and
  report path and size.
- Never render the PDF any other way. The script builds the production site; `npm run dev` shows
  fenced SQL blocks as loading cards that do not exist in production. Print styling lives in the
  `@media print` block in `partials/brand.md`.
- `exports/` is gitignored. When the PDF is the finished deliverable, copy it to
  `docs/reports/<slug>.pdf` and commit it there. That directory is the shipped record.

### 7 - Deliver

The report is not delivered until it reaches the person who asked for it. If the work came from a
tracked task (`wip/CU-<id>/brief.md` names it), close the loop:

- Attach `docs/reports/<slug>.pdf` to the task with `clickup_attach_task_file`.
- Comment with the TL;DR, one line, plus anything that qualifies the number: a partial window, a
  known-dead event, an excluded surface. Say it here rather than letting the stakeholder find it.
- Check the definition of done in the brief item by item, and say which items are met. Where the
  brief names a decision, say what the answer means for it.

Ask before posting to the tracker. This writes to a shared workspace, so it is confirm-gated like
every other outward-facing step in this skill.

### 8 - Wrap up

Summarize: what ran, what changed in the data, the deploy URL, the PDF path, whether the tracker
was updated, and every verification actually performed. If a step was skipped or partly failed,
say so plainly.

## New mode

### N1 - Nail the question before touching anything

- Restate the business question in one sentence.
- Propose the slug (short, kebab-case), the title (**three words max**), and which BigQuery
  tables or views feed it. Prefer the materialized `analytics_reports` tables over the `v_*`
  views. Never the deprecated `analytics_seed` dataset. Every reported number excludes spam via
  `analytics_reports.v_spam_sessions`.
- Ask whether any proposed section already exists in Looker Studio or another dashboard, and cut
  it if it does.
- Confirm with the analyst before scaffolding.

### N2 - Scaffold from the example

- `notebooks/<slug_snake>.py`: copy `notebooks/example_report.py`, set `REPORT = "<slug>"`, keep
  the ADC and project boilerplate as-is.
- `sources/<slug>/connection.yaml`: `name: <slug_snake>`, `type: csv`.
- `pages/<slug>/index.md`: frontmatter (`title`, `description`, `hide_children: true`), then
  `{@partial "brand.md"}`, then in order the `.meta` Window and Source line, the TL;DR callout,
  the Outline, then the sections.
- Add a `<LinkButton url='/<slug>'>` to the hub `pages/index.md`, labelled with the same
  three-word title.

### N3 - Write the real query

Draft the SQL and sanity-check it cheaply against BigQuery (dry run or `LIMIT`) before wiring it
into the notebook. Confirm the tables exist and the columns match. Do not discover schema errors
at build time.

### N4 - Land the data, then write the full draft

- Run steps 1 and 2 to land and validate the data. There are no before counts on a first run, so
  the checkpoint shows first-run counts and date ranges instead.
- Then write the **complete narrative** in `pages/<slug>/index.md`, grounded strictly in the
  numbers that actually landed, never in what the query "should" show. The analyst edits from a
  complete draft, not a skeleton.
- Apply the brand and content rules while writing.
- Rebuild so the checkpoint reviews the real rendered report.

### N5 - Checkpoint and ship

Continue at step 3. The checkpoint now covers both the data (counts, date ranges) and the draft:
paste the TL;DR and the section list in chat so the analyst can judge the story without opening a
browser. Then steps 4 to 8 as in Refresh.

## Hard rules

- **Pause before deploy. Always.** No exceptions, not even for a trivial refresh.
- Verify claims empirically: file mtimes and row counts, not exit codes; build output, not
  assumptions. State what was checked when reporting success.
- Never modify gcloud auth, ADC or quota-project settings. Auth failure means report and stop.
- Never hand-edit a CSV in `sources/`. The notebook is the source of truth; fix the notebook and
  rerun.
- If a step fails, fix the root cause and rerun that step. Never carry stale output forward, and
  never conclude "external issue" before exhausting the causes inside the project.
- The live URL is never shared. The PDF in `docs/reports/` is the deliverable.
- En dashes, never em dashes. No emojis in any file.
