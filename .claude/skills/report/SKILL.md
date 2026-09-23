---
name: report
description: Build or refresh an Evidence report end to end (BigQuery, Jupyter notebook, CSVs, Evidence build, Cloudflare deploy, PDF export). Use when a finished analysis has to become a delivered report, or when an existing report needs fresh data. Two modes - scaffold a new slug from a business question, or refresh an existing slug. Always pauses for review before deploying.
argument-hint: [business question for a new report, or an existing report slug to refresh; omit to list the reports and ask]
user-invocable: true
---

# report

Turns a finished analysis into the report a stakeholder reads. "Evidence" means
[evidence.dev](https://evidence.dev) (markdown pages with embedded SQL), never a Google Doc,
ClickUp doc or RTF. The data traps are in the repo `CLAUDE.md`; the copy rules are its
**Writing for peers** section.

```bash
REPORTING="$(git rev-parse --show-toplevel)/reporting"
```

Layout under `$REPORTING`: `pages/<slug>/index.md` (the report), `sources/<slug>/` (notebook CSVs
plus `connection.yaml`), `notebooks/<slug_snake>.py`, `partials/brand.md` (all shared CSS),
`evidence.config.yaml` (theme), `deploy.sh`, `export-pdf.sh`, `exports/` (gitignored).

## 0 - Mode and preflight

- `$ARGUMENTS` is an existing slug under `pages/` -> **Refresh** (steps 1 to 8).
- `$ARGUMENTS` is a business question -> **New** (N1 to N5).
- Empty -> list the slugs and ask.

Before any BigQuery touch, in both modes:

1. `gcloud config get-value account` must return the work account, never a personal one. If not,
   stop and tell the analyst.
2. Never modify gcloud config, ADC or quota-project settings, not even temporarily. A past "fix"
   of that shape broke working auth for hours. On an auth failure, report and stop.
3. Notebooks authenticate through ADC, which can hold the personal account after a re-login.
   Run the free dry-run canary:

   ```bash
   cd "$REPORTING" && env -u GOOGLE_APPLICATION_CREDENTIALS uv run python -c "
   from google.cloud import bigquery
   c = bigquery.Client(project='your-gcp-project')
   c.query('SELECT 1', job_config=bigquery.QueryJobConfig(dry_run=True))
   print('ADC OK')"
   ```

   A 403 on `bigquery.jobs.create` means the wrong ADC account. Ask the analyst to run
   `gcloud auth application-default login` with the work account, then rerun the canary.

Run notebooks headless with:

```bash
cd "$REPORTING" && env -u GOOGLE_APPLICATION_CREDENTIALS uv run python notebooks/<slug_snake>.py
```

Every report reads BigQuery. If one ever needs numbers fresher than the export, the GA4 Data API
is the route (`docs/config/ga4.md`); its key path is in private memory, never hardcoded.

## Slug

One slug, two spellings. Mixing them breaks the build.

- kebab-case for directories: `pages/<slug>/`, `sources/<slug>/`
- snake_case for code: `notebooks/<slug_snake>.py` and `name: <slug_snake>` in
  `connection.yaml`, so SQL blocks read `from <slug_snake>.<csv_basename>`

## Brand

The palette is fixed. Swap the placeholders for your own brand tokens once, then never invent
colours.

| Token | Hex | Use |
|---|---|---|
| primary | `<brand-primary>` | text, headings, chart series 1 |
| accent | `<brand-accent>` | links, takeaway border, active states, chart series 2 |
| accent-2 | `<brand-accent-2>` | secondary accents, later chart series |
| positive | `<brand-positive>` | CTA, positive |
| highlight | `<brand-highlight>` | highlights, warning |
| secondary | `<brand-secondary>` | secondary text, secondary chart series |
| neutrals | `<brand-neutrals>` | page background, callout background, rules |

Radii and typeface come from the same token sheet. Body text stays Evidence's default `#2c2c2c`.

- Every page starts with `{@partial "brand.md"}` directly under the frontmatter.
- Never add a `<style>` block to a page. New styling goes into `partials/brand.md` as
  `:global(...)` so every report inherits it.
- Explicit chart colours come from the table. Otherwise the theme in `evidence.config.yaml`
  already sets them.

## Page rules

The analyst has corrected each of these before. Apply them while writing.

- **Title: three words max**, set in frontmatter `title:` and reused on the hub `<LinkButton>`.
  Never rename the slug to match.
- **`.meta` line under the title: Window and Source, nothing else.** No author, no build date,
  no QA or "certified" label.
- **Takeaway: one or two sentences.** The finding, the one number that matters, and where the
  effect lands. The "Takeaway" eyebrow is drawn by CSS; never type it.
- **Chart a finding when it compares, trends or splits a whole** (A against B, change over time,
  part of a total). A single number, a definition or a list of exact values stays text or a
  table. Never add a chart just to have one.
- **Outline** after the takeaway, unless the report is a one-pager.
- **Sections answer the reader's questions, not the data's cuts.** Headings name what the reader
  wants to know ("What we give up", "Who feels it"), not the breakdown ("Traffic by referrer").
- **Each section runs point, why, what it means.** Open with the point in bold: one sentence and
  its number. Give the evidence in two to four sentences. Where a number could be misread (a
  ceiling, a proxy, a partial window), add a bold "Why ..." paragraph on how it was reached. Close
  on one **What it means:** line, then the chart. A one-sentence section reads as shallow.
- **Rule out the tempting wrong reading.** When readers would likely blame the change for
  something (a decline, a spike), give that its own section: what the change did not cause, and why.
- **Close on "Conclusion"**, after "Limitations": two or three sentences
  with the finding, where it lands, and the recommendation if there is one. Never end on caveats.
  A four-section report runs about 600 words.
- **Caveats: three at most**, per Writing for peers, under "Limitations".
- **Report the block, not its parts.** For a set of placements or cards, report total
  impressions, interactions and CTR for the block. Per-entity numbers go in an appendix, on
  request, unless the decision is about one entity.
- **Per-entity cards: one stat per row** (`<p><b>Label:</b> value</p>`), never joined with `·`
  or `|`, and nothing the table below already shows.
- **Do not rebuild a view Looker Studio or a dashboard already has.** Build only the missing view.
- Short headings. Never the word "artifact".

## Refresh mode

### 1 - Refresh the data

1. Record each CSV's row count and max date, so the checkpoint can show deltas.
2. If the notebook scans raw `events_*`, dry-run the expensive queries first and report the GB.
   Flag anything unusually large before running.
3. Run the notebook headless.
4. Check every expected CSV was rewritten just now (mtime) with a plausible row count. An exit
   code proves nothing; a run that wrote nothing is a failure to root-cause.

A `# %%` file runs every cell top to bottom headless, so any branch on interactive state (the
usual one is `__file__`) makes the two runs disagree. Derive paths once at the top, as
`example_report.py` does, and keep every query and `write_csv` cell unconditional.

### 2 - Build and check conformance

1. `cd "$REPORTING" && npm run sources && npm run build`. The build catches broken SQL, missing
   columns and renamed sources. On an error, fix the root cause and rerun.
2. Check the page against the Brand and Page rules. Flag violations at the checkpoint; do not
   rewrite an existing report's copy without asking.

### 3 - UX and data-viz pass

Required for anything dashboard-shaped. Fix the high-impact items and stop.

- Every chart and table has a title, and a one-line definition where the metric is not obvious.
- Each chart answers its section's question: a funnel shows drop-off, a trend shows the trend.
- Honest encoding: sensible axis starts, shared scales for comparable charts, colour with meaning.
- No cells that read as broken (nulls, bare `0%`), nothing misaligned, sensible default dates.

### 4 - CHECKPOINT (mandatory)

Show the analyst, in chat:

- Per CSV: rows before and after, and the data date range.
- Anything off: empty files, big row swings, date gaps, a metric that moved more than the window
  explains. Flag it; an unexplained swing is the finding.
- `git diff --stat` for `sources/<slug>` and `pages/<slug>`. For untracked files, the row counts
  from step 1 are the evidence; say which basis you used.
- The QA result, if one ran. It stays in chat.

Numbers only. Start `npm run dev` only if the analyst asks to see it. **Then wait for an explicit
go.**

### 5 - Deploy

`cd "$REPORTING" && ./deploy.sh`, then report the URL. Never call wrangler directly: the script
moves the oversized DuckDB wasm files to a CDN, without which Cloudflare Pages rejects the upload.
The site is locked to the analyst's email, so the URL is a private preview and is never shared.

### 6 - Export the PDF

1. `cd "$REPORTING" && ./export-pdf.sh <slug>` writes `exports/<slug>.pdf`. Never render it any
   other way: `npm run dev` shows SQL blocks as loading cards that production does not have.
   Print styling lives in the `@media print` block of `partials/brand.md`.
2. Check the file exists and is a non-trivial size, `open` it, and report path and size.
3. When it is the final deliverable, copy it to `docs/reports/<slug>.pdf` and commit.

### 7 - Deliver (ask before posting)

If the work came from a tracked task (`wip/CU-<id>/brief.md` names it), and after the analyst
confirms:

1. Attach `docs/reports/<slug>.pdf` with `clickup_attach_task_file`.
2. Comment the takeaway, plus any caveat that changes how to use the number (a partial
   window, a dead event, an excluded surface).
3. Check the brief's definition of done item by item and say which are met. Where the brief
   names a decision, say what the answer means for it.

### 8 - Wrap up

Tell the analyst what ran, what changed in the data, the deploy URL, the PDF path, whether the
tracker was updated, and which checks actually ran. Name any step skipped or partly failed.

## New mode

### N1 - Nail the question

1. Restate the business question in one sentence.
2. Propose the slug, a three-word title, and the tables. Prefer materialized `analytics_reports`
   tables over `v_*` views, never `analytics_seed`, and exclude spam via
   `analytics_reports.v_spam_sessions`.
3. Ask whether any proposed section already exists in Looker Studio or a dashboard; cut it if so.
4. Confirm with the analyst before scaffolding.

### N2 - Scaffold

- `notebooks/<slug_snake>.py`: copy `example_report.py`, set `REPORT = "<slug>"`, keep the ADC
  and project boilerplate.
- `sources/<slug>/connection.yaml`: `name: <slug_snake>`, `type: csv`.
- `pages/<slug>/index.md`: frontmatter (`title`, `description`, `hide_children: true`),
  `{@partial "brand.md"}`, then the `.meta` line, takeaway, Outline, sections, Limitations and Conclusion.
- A `<LinkButton url='/<slug>'>` on the hub `pages/index.md` with the same title.

### N3 - Test the query

Dry-run or `LIMIT` the SQL against BigQuery before wiring it in, so schema errors surface now,
not at build time.

### N4 - Land the data, write the draft

1. Run steps 1 and 2. With no before counts, the checkpoint shows first-run counts and dates.
2. Write the complete narrative from the numbers that landed, never from what the query should
   show. The analyst edits a full draft, not a skeleton.
3. Rebuild so the checkpoint reviews the rendered page.

### N5 - Checkpoint and ship

Continue at step 3. At the checkpoint, also paste the takeaway and section list in chat. Then steps
4 to 8.

## Hard rules

- **Pause before deploy, always**, even for a trivial refresh.
- Never hand-edit a CSV in `sources/`. Fix the notebook and rerun.
- Verify with mtimes, row counts and build output, and say what was checked.
- On a failure, fix the root cause inside the project before calling it external.
