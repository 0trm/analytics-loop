---
name: tracking-spec
description: Run the GTM/GA4 tracking pipeline - define, spec, build, QA, ship. Five modes, because a tracking request is written once, built by two teams, and verified twice, days apart. Produces the tracking-plan event page and the dev handoff spec, fills in real GTM ids read-only, emits the staging and production QA checklists, and closes out with the BigQuery verification query. Use for any request to measure a new interaction, instrument a redesign, or fix an event that stopped firing.
argument-hint: '[mode + subject, e.g. define newsletter popup on /pricing | spec card_click | build | qa staging form_submit | ship abc123; omit the mode to infer it from the input]'
user-invocable: true
---

# tracking-spec

The executable form of `docs/sop/tracking-implementation.md`: **define, spec, build, QA, ship**.

Two facts shape it. The container runs a pure **dataLayer event model** (the DOM listener tags
were deleted in the dataLayer migration), so a missing frontend push means **zero events**, with
no scraping fallback. And **analytics and the dev team own different halves**, finishing days
apart, hence five modes.

## 0 - Pick the mode

| Mode | Runs when | Produces |
|---|---|---|
| `define` | a request or redesign arrives | reuse verdict, candidate KPI rows, a stop at the KPI gate |
| `spec` | the gate is passed, the event set agreed | the tracking-plan page and the dev handoff spec |
| `build` | the spec is signed off | real trigger/tag/variable ids, the container checklist |
| `qa` | dev deployed to staging, or the build reached prod | a `tracking-qa` run and its PASS/FAIL |
| `ship` | staging QA passed, prod deployed | publish checklist, BigQuery check, closeout, doc updates |

Infer it from the input: a stakeholder ask or Figma link -> define; an agreed event name, "write
the spec" -> spec; trigger ids, "build the container side" -> build; a staging URL, "did it land
in prod" -> qa; "it passed", "publish", a closeout -> ship.

State the mode in one line before doing anything. If the input spans two, run the earlier one
and say what the next needs.

## Read first, every mode

| Source | Settles |
|---|---|
| `docs/config/conventions.md` | naming, the controlled vocabularies, DOM hooks, the state-reset push |
| `docs/dev/tracking-plan/README.md` | the live custom and auto-collected events |
| `docs/dev/tracking-plan/<event>.md` | the contract for any event already in play |
| `docs/business/key-performance-indicators.md` | what the KPI gate resolves against |
| `docs/config/gtm.md` | container facts, API access, versioning |
| `docs/config/ga4.md` | custom-dimension slots and what is registered |

## Who reads what

Specs, tracking-plan pages and closeouts are for developers and analysts, so they stay technical.
One exception: **the first line of every spec and closeout is plain words** for a non-technical
reader, saying what is tracked and whether the dev team is blocked (**Writing for peers** in the
repo `CLAUDE.md`). Anything sent back to a requester, such as a KPI-gate "sharpen or drop", follows
the same section.

---

# define mode

## D1 - Restate the request

One sentence: which interaction, on which surface, and what the requester wants to learn. If the
restatement is vague, send it to `/clarify` rather than guessing.

## D2 - Reuse check, first, every time

Often the frontend only needs to push an existing event on a new surface, with **no GTM change**
(a promo banner reused `banner_impression` / `banner_click` with zero container work).

```bash
cd "$(git rev-parse --show-toplevel)"
grep -ril "<interaction keyword>" docs/dev/tracking-plan/
grep -n "<candidate cta_id>"      docs/dev/tracking-plan/cta_click.md      # the CTA catalog
grep -n "<candidate form>"        docs/dev/tracking-plan/form_submit.md    # the forms inventory
```

Three outcomes, in order of preference:

1. **Reuse as-is.** An existing event and id cover it. Dev pushes it on the new surface; straight
   to QA.
2. **Reuse with a new id or scope extension.** `cta_click` with a new `cta_id`, or a lifted
   surface exclusion. No new trigger or tag: the `cta_click` trigger fires for any `data-gtm-cta`.
3. **New event.** Full build: trigger, tag, variables, custom dimensions.

Check the interaction against the **Exclusions** table in `cta_click.md` and name the event that
already owns it. `cta_click` is the residual event and never overlaps another. A button that
**opens** a form is a `cta_click`; the submission is `form_submit`. That is two actions, not a
conflict.

**State the verdict in bold at the top of the spec.** It tells the dev team whether they are
blocked on analytics.

## D3 - Candidate KPI rows

List every row in `key-performance-indicators.md` the event could feed, and whether it is the
**numerator** or **denominator**:

```
Candidate KPI rows for `card_click`:
- E - Discovery / card-to-profile rate: a new numerator alongside
  `profile_view (source_surface=category)`; the denominator `card_impression
  (source_surface=category)` already exists.
- No existing row measures card engagement directly.
```

If nothing matches, say so. Never manufacture a row.

## D4 - Stop at the KPI gate

> A metric must answer a question tied to a KPI or a decision that will be made; otherwise it
> goes back to the requester to sharpen or drop.

The skill **surfaces**; it does not decide. End with a recommendation and a stop:

```
Reuse verdict: reuse with a new cta_id (no GTM change).
KPI rows matched: none directly; nearest is H - CTA click rate by surface.
Recommendation: sharpen or drop. The requester has not named a decision this would change.
Waiting on the analyst.
```

Do not continue to spec mode in the same run unless the gate is explicitly cleared.

## D5 - Draft the event

Only after the gate clears. A `snake_case` name and a **flat** param set, every value inside a
controlled vocabulary. Flag params that must be sliceable in GA4; they become custom dimensions
in build mode (unregistered params reach BigQuery but not GA4 reports). Then run
[Validation](#validation-every-draft).

---

# spec mode

Two documents, different readers; neither substitutes for the other.

| Document | Path | Reader | Life |
|---|---|---|---|
| Tracking-plan page | `docs/dev/tracking-plan/<event_name>.md` | anyone querying the event | evergreen, one per event |
| Dev handoff spec | `docs/dev/specs/<domain>/<subject>.md` | the dev team, this build | dated, one per project |

`<domain>` is an existing folder where one fits (`forms`, `homepage-redesign`, `cards`,
`display-ads`). A new folder is a deliberate choice.

## S1 - Tracking-plan page

Follow the anatomy of `cta_click.md`, `card_impression.md` and `form_submit.md`. Unknown values
are the literal `TBD`, never a guess.

```markdown
# <event_name>

**Status:** Active / Spec'd, not built / Broken
                 (copy the status glyph convention from a sibling page)

**dataLayer migration:** <one line: where the tag fires from, what was deleted>

<One paragraph: the user action, the push, the dedup rule, and what it is distinct from.>

## Known issues
## Exclusions            <- when the event could overlap another
## Screenshot
## Trigger               <- table: Trigger ID, name, type, filter, tag
## DataLayer push        <- the reset push, the event push, a reference implementation
## Parameters            <- table: Parameter, Type, Source, Notes
## Valid values          <- per-param enums, linking to conventions.md for shared ones
## Dimensions & metrics mapping   <- table: Parameter, GA4 dimension, Scope, CD slot, Notes
## BigQuery notes        <- how to query and dedup it
## Implementation notes  <- checkbox list, the dev-facing summary
```

Always carry the **state-reset push** at the head of every code block, and the counting rule when
raw events overstate reality. `form_submit` over-fires about 8x on a contact overlay, so its page
mandates `COUNT(DISTINCT CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)))`; any event
that re-fires the same way needs the same note.

## S2 - Dev handoff spec

Pick the shape by scope.

**Lean**, for a small change to an existing event. Model:
`docs/dev/specs/forms/form-submit-instrumentation-spec.md`.

```markdown
# <subject> (dev spec)

<Plain-words line: what is tracked, and whether the dev team is blocked.>

**Task:** [<task-id>](<task-url>)
**Owner:** analytics · **Implementer:** dev team
**Status:** <where it is right now>

**<The reuse verdict, in bold.>** e.g. "No GTM changes needed: the live
`Custom Event - form_submit` trigger picks the pushes up as soon as the frontend fires them."

Canonical event contract: [`tracking-plan/<event>.md`](../../tracking-plan/<event>.md).

## The pattern (already live elsewhere)   <- a working reference implementation
## Push payload                           <- one fenced block, copy-pasteable
## Forms / surfaces to instrument          <- table, priority order, every param filled in
## Rules                                   <- the invariants, one line each
```

**Rich**, for a redesign or multi-interaction surface. Model: the richest redesign handoff in
`docs/dev/specs/`.

```markdown
# <surface> - analytics handoff (`<path>`)

<Plain-words line, then: what is being built, links to the redesign task and Figma, and a
sentence saying this supersedes any provisional event names in the design doc.>

## Page-level facts        <- table: URL, source_surface, page_type, reset push
## Interaction → event map (the contract)
   <- table: Section | Element | Action | Event | Key id / params, one row per interaction
## What's new vs. reused
   <- new custom event / new ids / scope change to an existing event / reused as-is
---
## Section detail
### N. <section> → <event>
   <screenshot>, markup contract table, the html hooks, reset push + event push, params table
## Markup contract summary  <- every data-gtm-* hook the page must carry
## Action items             <- checkbox list, each prefixed **dev** or **gtm-admin**
```

Section detail needs a screenshot per tracked element, the exact `data-gtm-*` hooks, and a dedup
rule wherever two elements could fire on one click ("the card-click handler must ignore clicks
that originate on the outbound link").

## S3 - Ownership, in every spec

| Owner | Owns |
|---|---|
| **analytics** (`gtm-admin`) | the GTM container (workspace, `Custom Event` trigger, `GA4 - <Event>` tag, `DLV - *` variables) and GA4 custom-dimension registration |
| **dev team** | the `dataLayer`: the `data-gtm-*` hooks and every `dataLayer.push` |

Say "dev team", never "engineering". Action items carry one prefix each, **dev** or
**gtm-admin**. Dev works on a `CU-<task-id>` branch. The hooks and the push are part of the
template and must survive any redesign; that is what the `gtm-` prefix signals.

## S4 - Validate, then write

Run [Validation](#validation-every-draft), fix or flag each failure, then write both documents
into `docs/`.

---

# build mode

**Read-only against the shared production container. It never writes.**

## B1 - Read the container

Python and `google-auth` directly, scope `tagmanager.readonly` (the community GTM MCP servers
accept only Desktop OAuth, not a service account).

```bash
cd "$(git rev-parse --show-toplevel)"
python3 src/gtm-api/list_ga4_tags.py      # every gaawe tag: eventName, paused state, triggers
python3 src/gtm-api/inspect_container.py  # all triggers, tags, variables for a workspace
python3 src/gtm-api/list_workspaces.py    # workspaces, and whether the live version has an entity
python3 src/gtm-api/dump_tags.py          # full config for tags by id
```

Only these four. The write scripts in the same directory are out of scope.

Fill into the spec the real **Trigger ID**, trigger name, tag name, **tagId**, and the `DLV - *`
variable each param reads. Replace every `TBD` you can; leave the rest.

API gotchas: returned `path` values are relative (prefix
`https://tagmanager.googleapis.com/tagmanager/v2/`), and GA4 event tags keep params in an
`eventSettingsTable` list of `{parameter, parameterValue}` maps, not top-level fields.

## B2 - Container checklist

A checklist for the analyst to execute in the GTM UI, not commands to run:

```markdown
- [ ] **gtm-admin**: create a fresh workspace named `<yyyy-mm-dd> <subject>`.
- [ ] **gtm-admin**: create trigger `Custom Event - <event_name>`, type Custom Event,
      filter `{{_event}}` equals `<event_name>`.
- [ ] **gtm-admin**: create the `DLV - <param>` variables. Params inside `event_data` read
      `event_data.<param>` (Data Layer Version 2, dot notation). Top-level page context reads the
      bare key: that is the `DLV - page_type` vs `DLV - page_type (event)` split.
- [ ] **gtm-admin**: create tag `GA4 - <Event Name>` (GA4 Event), event name `<event_name>`,
      params from the `DLV - *` variables, firing on the trigger above.
- [ ] **gtm-admin**: register `<param>` as a GA4 custom dimension (Admin → Custom definitions).
- [ ] **dev**: markup hooks and the `dataLayer.push` on a `CU-<task-id>` branch, then staging.
```

GTM naming (from `conventions.md`): Tag `GA4 - Form Submit`, Trigger `Custom Event - form_submit`,
Variable `DLV - source_surface`, each `[Type] - [Description]`.

State both every time: a numeric param lands in `value.int_value`, not `value.string_value`; and
publishing **consumes** a workspace against the free-tier cap of three, so create a fresh one per
publish.

## B3 - Reuse path

If D2 said reuse, build mode's whole output is one bold line: **no container work; the existing
trigger already fires.** Skip to qa.

---

# qa mode

Staging and production get different checklists, each built from the spec's contract rows: one
check per interaction, param and enum value.

## Staging QA

**Delegate to the `tracking-qa` agent** with the spec path, the URLs, and **an explicitly named
browser** (it refuses to guess between the work and personal Chrome). Hand it the contract and act
on its verdict; do not click through the site yourself.

The staging hosts sit behind HTTP basic auth. Authenticate the browser by hand first. **Never
inline those credentials** in a spec, QA file, transcript command or anything under `docs/`.

Two traps that produce a false "not firing", for reading its report:

1. **gtag batches post-load events and flushes on unload.** Clicks and scrolls are not visible
   before navigation; confirm from the `dataLayer` push instead.
2. **The browser network tool redacts URLs with a query string**, which hides every GA4/GTM hit.
   Read hits from resource timing, or use Tag Assistant:

```js
performance.getEntriesByType('resource')
  .filter(r => r.name.includes('/g/collect'))
  .map(r => new URLSearchParams(r.name.split('?')[1]).get('en'));
```

A batched POST to `/g/collect` carries its event names in the body, not the URL, so an empty
`en=` parse is inconclusive for post-load events; confirm from the `dataLayer` or Tag Assistant.

The checklist:

```markdown
- [ ] Fires on the correct interaction, and on **no other**.
- [ ] Fires **before** any cross-domain redirect or navigation.
- [ ] The state-reset push precedes every event push.
- [ ] Carries **exactly** the spec'd params: none missing, **no extras** (extras are a failure
      too, because they drift).
- [ ] Every value is inside its controlled vocabulary (`source_surface`, `form_type`, `cta_id`).
- [ ] Fires exactly once per action; no double-count where elements overlap.
- [ ] Forms: fires on server-confirmed success only, never on validation error or 4xx/5xx. QA
      with a real-domain address at human speed: the endpoint rejects bad-MX domains (422) and
      honeypot or too-fast submits (400), and the push correctly skips both.
- [ ] Per interaction row in the spec's contract table: <one line each>
```

**Gate:** any failure loops back to the dev team. Only a clean pass ships.

## Production QA

**Step 0, mandatory: confirm the QA'd build reached production.** Check the merge and release, or
diff the live markup for the required `data-gtm-*` hooks. Live banners once emitted the wrong id
for weeks because a staging-green build was never deployed, and every later check read as an
ingestion problem.

Then the ingestion ladder:

| Layer | Latency | Proves |
|---|---|---|
| GA4 DebugView / Realtime | about 5 minutes | the tag fires and the hit reaches GA4 |
| GA4 standard reports | 24 to 48 hours | params resolve as registered dimensions |
| BigQuery `events_*` | D-1, sometimes D-2 (the session-start freshness line has the real boundary) | the full payload, queryable |

There is no `events_intraday_*` table, so a same-day change is invisible in BigQuery until that
date exports. If the SOP or an older spec says `events_intraday_*`, it is stale; flag it for P4.
A **503 on `/g/collect`** during automated QA is most likely bot-flagging of the automated
browser; confirm with a manual hit before escalating.

---

# ship mode

## P1 - Publish checklist

Publishing is a human action in the GTM UI; the service account has Edit, not Publish (403).

```markdown
- [ ] **dev**: merge the `CU-<task-id>` branch to production and deploy.
- [ ] **gtm-admin**: publish the workspace in the GTM UI as the owner account,
      version-named `YYYY-MM-DD - <subject>`.
- [ ] **gtm-admin**: run production QA (step 0 first).
```

Order matters: a tag published before the pushes fires on nothing, and pushes deployed before the
tag produce events GA4 drops.

## P2 - BigQuery verification

Run once the date's shard exists. The query filters on `_TABLE_SUFFIX`, reports param **presence
rate per day** (a `form_name` regression sat at 4.2% and read as "present"), coalesces all three
value types, and excludes spam with **`NOT EXISTS`, never `NOT IN`**: one NULL session id in a
`NOT IN` empties the result, which reads exactly like "the event never fired".

```sql
WITH ev AS (
  SELECT
    PARSE_DATE('%Y%m%d', _TABLE_SUFFIX) AS d,
    CONCAT(user_pseudo_id, '-', CAST(
      (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS STRING
    )) AS session_id,
    (SELECT COALESCE(
        value.string_value,
        CAST(value.int_value AS STRING),
        CAST(value.double_value AS STRING))
     FROM UNNEST(event_params) WHERE key = '<param>') AS param_value
  FROM `your-gcp-project.analytics_XXXXXXXXX.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '<yyyymmdd>' AND '<yyyymmdd>'
    AND event_name = '<event_name>'
)
SELECT
  d,
  COUNT(*)                       AS events,
  COUNT(DISTINCT session_id)     AS sessions,
  ROUND(COUNTIF(param_value IS NOT NULL AND param_value != '') / COUNT(*), 3)
                                 AS param_presence_rate,
  COUNT(DISTINCT param_value)    AS distinct_values
FROM ev
WHERE NOT EXISTS (
  SELECT 1 FROM `your-gcp-project.analytics_reports.v_spam_sessions` spam
  WHERE spam.session_id = ev.session_id
)
GROUP BY d
ORDER BY d;
```

Pass means: `events` near the expected volume, `param_presence_rate` at or near 1.000 **on every
day**, and `distinct_values` equal to the vocabulary size with no strays. For any event that
over-fires, report sessions. Run with the `bq` CLI on the work account.

## P3 - Closeout

Write `docs/dev/feedback-loop/GTM-<Subject>-Closeout-<task-id>.md`:

```markdown
# <subject> - closeout (<task-id>)

<Plain-words line: what now works, and anything accepted as broken.>

**Shipped:** <date>  ·  **Rounds of QA:** <n>  ·  **Container version:** v<nnn>

## What shipped
## What was found in QA, and what was changed
## Known defects accepted as-is, and why
## Verification
   <the BigQuery numbers, the dates they cover, what they confirm>
## Still open
```

Accepted defects go here explicitly. The `form_submit` thank-you-page re-fire on refresh was
accepted on 2026-07-22, and the closeout is how a reader a year later knows it.

## P4 - Evergreen docs

Work through the list and say which changed:

| Doc | Update when |
|---|---|
| `docs/dev/tracking-plan/<event>.md` | always: status, real ids, known issues, verified param coverage |
| `docs/dev/tracking-plan/README.md` | a new event joins, or a status changes |
| `docs/config/conventions.md` | a vocabulary grew, or a new `data-gtm-*` hook was added |
| `docs/config/ga4.md` | a param was registered; record the slot index |
| `docs/config/gtm.md` | container version, tag/trigger inventory |
| `docs/business/key-performance-indicators.md` | the event feeds or unblocks a KPI row |
| `docs/dev/specs/<domain>/<subject>.md` | status line: shipped, QA'd, prod-verified |

Two known drifts on any form work: `conventions.md` lists fewer `form_type` values than
`tracking-plan/form_submit.md` (the newer file is right), and the SOP still references
`events_intraday_*`.

---

# Validation, every draft

Run on any draft, in any mode, before a file is written. Each failure is a reject with its
reason, not a warning.

**Vocabularies.** `source_surface` and `form_type` accept exactly the values in the docs; read
them there, never from memory. `source_surface` comes from `conventions.md`; `form_type` from
`tracking-plan/form_submit.md`, which is ahead of `conventions.md`. The retired granular surfaces
(`article_snippet`, `category_sub`, `search`, …) must not return in docs, dashboards, KPIs or
BigQuery predicates.

**`cta_id`** is unique across `cta_click` and `card_click`. Grep the catalog in `cta_click.md`
first. Lowercase kebab-case, `{action}` or `{context}-{action}`; the human label goes in
`cta_text`, never in the id.

**Names.** Events are `snake_case`, max 40 characters, verb-noun. Never redefine `page_view`,
`session_start`, `user_engagement`, `first_visit`, `scroll`, `file_download`. Params are
`snake_case`; booleans `is_*` / `has_*`, ids `*_id`, free text a bare noun (`card_name`).

**Length limits.** Over-limit values are truncated; an invalid `page_location` yields an empty
dimension. `page_location` 1,000 (a valid URL path), `page_referrer` 420, `page_title` 300, every
other param 100.

**State-reset push, in every generated code block:**

```js
dataLayer.push({ event_data: undefined, items: undefined, item_list_name: undefined });
dataLayer.push({ event: '<event_name>', event_data: { /* params */ } });
```

Without it a `card_impression` followed by a `form_submit` leaks card context into the form
event. Enforced across the site bundles and every inline push.

**Overlap.** Check the Exclusions table in `cta_click.md` and name the owning event. Where two
elements nest, the spec states the dedup rule.

---

# What stays a human decision

The skill prepares, validates and reports. For each of these, surface the options and the
trade-off, then stop:

- **The KPI gate.** The analyst decides whether the metric earns its place.
- **Leanness.** Pagination, FAQ accordions, gallery opens and sort/filter minutiae are not
  tracked unless asked. Propose the omission; never spec them in unasked.
- **Extending a vocabulary.** A new `source_surface`, `form_type` or `cta_id` catalog value is a
  deliberate decision, never a variant of an existing one.
- **New event vs extending one**, when genuinely ambiguous. Lay out both.
- **Accepting a known defect.** Report and quantify it; the analyst decides.
- **Every write to the production GTM container, and the publish.** Build mode reads; a human
  writes and publishes in the GTM UI.
- **Both QA sign-offs.**
- **Credentials.** Read from private memory when needed; never inline, echo or commit them.

---

# Where things are written

| What | Where | Committed |
|---|---|---|
| Tracking-plan page | `docs/dev/tracking-plan/<event>.md` | yes |
| Dev handoff spec | `docs/dev/specs/<domain>/<subject>.md` | yes |
| Closeout | `docs/dev/feedback-loop/GTM-<Subject>-Closeout-<task-id>.md` | yes |
| Spec screenshots | `docs/dev/specs/<domain>/img/<subject>/` | yes |
| QA rounds, findings, dev back-and-forth, scratch queries, dumps | `wip/CU-<task-id>/` | **never** |

A QA round is a conversation; the closeout is the record.

Commit screenshots rather than pasting `github.com/user-attachments/...` URLs, which need an
authenticated session and render broken. Download with
`curl -L -H "Authorization: Bearer $(gh auth token)" <url>`, check the real type with
`file --mime-type` (attachments arrive extensionless, often JPEG), save under `img/`, and link it
relatively.
