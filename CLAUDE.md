> This is the real `CLAUDE.md` of a production analytics repo, sanitized: the company is "a
> startup", ids are placeholders, and event names were relabeled. The structure and the rules
> are exactly what runs. The `docs/` tree it maps stayed at work; the [README](README.md)
> explains what each part holds so you can build your own.

# analytics

Analytics knowledge base and agent harness for a startup. This repo is the work root: all
analytics work happens here.

## Map

| Need | Go to |
|---|---|
| What an event means, its params | `docs/dev/tracking-plan/` |
| Naming, `source_surface`, `form_type` | `docs/config/conventions.md` |
| Warehouse layout, table reference | `docs/config/bigquery.md` |
| GA4 / GTM / email platform setup | `docs/config/` |
| KPI definitions | `docs/business/` |
| Spam and other cross-cutting rules | `docs/custom/` |
| How the work runs, and why | `docs/sop/` |
| Who owns what, the stack, brand tokens | `docs/company/` |
| Reusable SQL, GTM API scripts | `src/` |
| Evidence reports | `reporting/` |
| Per-task scratch | `wip/` (gitignored, never commit) |

Procedures are skills: `/clarify` `/cupify` `/report` `/tracking-spec` `/capture` `/promote`.
Send heavy BigQuery exploration to the `bq-explore` agent and correctness checks to `qa`, so
schema dumps and failed queries stay out of this session. Verifying an instrumentation against a
live page is `tracking-qa`, which drives a browser.

## Traps

These return a plausible number that is wrong. Check them before trusting any result.

- **Auth.** The shell exports `GOOGLE_APPLICATION_CREDENTIALS` pointing at a GA4-Data-API
  service account with no BigQuery rights, so every Python BigQuery client 403s. Run
  `env -u GOOGLE_APPLICATION_CREDENTIALS ...`. The `bq` CLI is unaffected.
- **Freshness, and there are two floors one day apart.** There are no `events_intraday_*` tables,
  so today never exists and same-day GTM changes are invisible. Raw `events_*` reaches **D-1**
  (verified 2026-07-30: `events_20260729` complete); it can still be D-2 early in the day, so
  check rather than assume. The derived `analytics_reports.*` tables are built from it and lag a
  further day, at **D-2** (`traffic_section_daily` stopped at 2026-07-28 on 2026-07-30). A report
  on a derived table shows a date control ending yesterday while the data stops the day before, so
  the last day of the range comes back empty and the total is short a day.
- **Param value types.** A param may sit in `string_value`, `int_value` or `double_value`.
  Check all three before concluding it is missing.
- **`form_submit` over-fires ~8x.** Count distinct sessions, never raw events.
- **Zero is not absence.** Outbound / inbound / scroll / social events on one whole site section
  have been dead since 2026-06-12 (a page-type bug) and still are. Four forms were uninstrumented
  from 2026-07-03 until the fix landed on 2026-07-21, so any window spanning that gap understates
  them. Confirm an event was alive across the whole window before reporting a decline.
- **Spam.** Every reported number excludes spam. Use `analytics_reports.v_spam_sessions`;
  do not reinvent the rule.
- **`card_click.source_surface`** is mis-tagged `other` ~96% of the time. Scope card events by
  `page_path` instead.
- **Read tables, not views.** `analytics_reports.traffic_*_daily` are materialized nightly.
  The matching `v_traffic_*` views rescan `events_*` and cost far more for the same rows.
- **`analytics_seed` is deprecated and empty.** Only two UDFs survive. Any SQL still joining its
  tables is broken, not merely stale.
- **GTM lazy-loads in production** (3s timeout or first interaction), so `page_view` and
  `session_start` can be missing for fast zero-interaction bounces. Bounce and session counts
  are undercounted at the fast end.

## Rules

- BigQuery project `your-gcp-project`, EU multi-region. Confirm the work account, never
  personal, before querying. Prefer the `bq` CLI.
- Filter `events_*` on `_TABLE_SUFFIX`, never `event_date`.
- Analysis for a stakeholder belongs in `wip/`. Only durable, reusable assets reach `docs/`.
- Git: commit routine work straight to `main`; branch and open a PR when the diff should be
  reviewed in the GitHub UI. Always `pull` before branching. "Delete the repo" means the local
  clone, never the remote.
- Writing: en dashes, never em dashes. No decorative emoji. Anything a peer reads follows
  **Writing for peers** below.
- Simplest working solution.
- Never commit credentials. This repo is visible to the whole organisation.

## Writing for peers

Peers are colleagues at the startup, nearly all non-technical. They read the first line, maybe
the last, and act on that. These rules cover everything they read: report pages and PDFs, task
bodies and comments, clarifying questions, PR bodies. Skills point here rather than repeat them.

**Shape**

- Lead with the answer: the finding and the one number that matters.
- End with one next action: who does what.
- At most 5 bullets in a list. Number steps, one action each.
- No preamble, recap, closing offer or side notes.

**Words**

- Plain words. No table, column, event or parameter names, no SQL, no GA4 or GTM terms. If a
  term is unavoidable (CTR, session), define it in one line the first time.
- Flat and declarative. No hype adjectives, bold drama or dramatic adverbs. Say what happens:
  "returns 0 instead of null".

**Leave out**

- The author, a "prepared by" line, and any QA or "certified" label. QA still runs; its result
  goes to the analyst in chat, never on the page.
- Caveats beyond three. Keep only the ones that change how a reader uses the number, one plain
  sentence each, under "What this cannot tell you". The rest go to the analyst in chat.

**PR bodies:** one or two sentences on what changed and why, then at most three one-line bullets,
under 100 words. Detail a reviewer needs goes in a collapsed `<details>` block, never the body.
Keep the "Generated with Claude Code" line.

**Check before sending:** reading only the first and last lines, a non-technical reader knows the
finding and what to do next.

Progress lines ("step 3 of 5 done") and the two-minute next action are for chat with the analyst,
not for pages. A report ends on its recommendation, a ticket on its next step.
