---
name: tracking-spec
description: Run the GTM/GA4 tracking pipeline - define, spec, build, QA, ship. Five modes, because a tracking request is written once, built by two teams, and verified twice, days apart. Produces the tracking-plan event page and the dev handoff spec, fills in real GTM ids read-only, emits the staging and production QA checklists, and closes out with the BigQuery verification query. Use for any request to measure a new interaction, instrument a redesign, or fix an event that stopped firing.
argument-hint: '[mode + subject, e.g. define newsletter popup on /pricing | spec card_click | build | qa staging form_submit | ship abc123; omit the mode to infer it from the input]'
user-invocable: true
---

# tracking-spec

The tracking pipeline, end to end: **define, spec, build, QA, ship**. It is the executable form of
`docs/sop/tracking-implementation.md`.

Two facts shape everything below. First, the container runs a clean **dataLayer event model**: the
legacy DOM/click-listener tags were deleted in the dataLayer migration, so every custom event now
depends on a real frontend push. A missing push means **zero events, not degraded events**, and
there is no scraping shortcut to recover them. Second, **analytics and the dev team own different
halves** of the implementation, and they finish days apart. Hence five modes rather than one
script.

## 0 - Pick the mode

| Mode | Runs when | Produces |
|---|---|---|
| `define` | a request arrives, or a redesign needs instrumentation | the reuse verdict, candidate KPI rows, a stop at the KPI gate |
| `spec` | the gate is passed and the event set is agreed | two documents: the tracking-plan page and the dev handoff spec |
| `build` | the spec is signed off and container work is due | real trigger/tag/variable ids, plus the container checklist |
| `qa` | dev has deployed to staging, or the build has reached prod | a `tracking-qa` run against the live surface, and its PASS/FAIL verdict |
| `ship` | staging QA passed and prod is deployed | publish checklist, BigQuery verification query, closeout, doc updates |

Default to the mode the input implies:

- A stakeholder ask, a Figma link, a redesign task, "can we measure X" goes to **define**.
- An agreed event name and a surface, or "write the spec", goes to **spec**.
- "What are the trigger ids", "build the container side", a workspace question goes to **build**.
- A staging URL, "it's on staging", "verify the push", "did it land in prod" goes to **qa**.
- "It passed", a merge notification, "publish", a closeout request goes to **ship**.

State the mode you picked in one line before doing anything. If the input spans two modes, run the
earlier one and say what the next one needs.

## Read these first, in every mode

| Source | What it settles |
|---|---|
| `docs/config/conventions.md` | naming rules, `source_surface`, DOM hooks, the state-reset push |
| `docs/dev/tracking-plan/README.md` | the live custom events and the auto-collected ones |
| `docs/dev/tracking-plan/<event>.md` | the canonical contract for any event already in play |
| `docs/business/key-performance-indicators.md` | what the KPI gate resolves against |
| `docs/config/gtm.md` | container facts, API access, versioning |
| `docs/config/ga4.md` | custom-dimension slots and what is registered |

---

# define mode

## D1 - Restate the request

One sentence: which interaction, on which surface, and what the requester wants to learn from it.
If the restatement is already vague, that is the finding. Send it to `/clarify` rather than
guessing.

## D2 - Reuse check, before anything else

**Run this first, every time.** Very often the frontend only needs to push an existing event on a
new surface, and **no GTM change is needed at all** - a promo banner reused `banner_impression` /
`banner_click` with zero container work.

```bash
cd "$(git rev-parse --show-toplevel)"
grep -ril "<interaction keyword>" docs/dev/tracking-plan/
grep -n "<candidate cta_id>"      docs/dev/tracking-plan/cta_click.md      # the CTA catalog
grep -n "<candidate form>"        docs/dev/tracking-plan/form_submit.md    # the forms inventory
```

Three outcomes, in order of preference:

1. **Reuse as-is.** An existing event and an existing id already cover it. Dev pushes it on the new
   surface. No GTM change, no new custom dimension, straight to QA.
2. **Reuse with a new id or a scope extension.** `cta_click` with a new `cta_id`, or an existing
   event whose surface exclusion is lifted. Still no new trigger or tag: the `cta_click` Custom
   Event trigger already fires for any `data-gtm-cta`.
3. **New event.** Nothing covers it. Full build: trigger, tag, variables, custom dimensions.

Also run the interaction against the **Exclusions** table in `cta_click.md` and report which event
already owns it. `cta_click` is the residual CTA event and must never overlap another:

| Action | Owned by |
|---|---|
| "Visit website" links on a card | `card_website_click` |
| View profile, logo, reviews on a card | `card_click` |
| Any form submission | `form_submit` |
| In-text internal / external links on article pages | `inbound_link_click` / `outbound_link_click` |
| Share buttons | `social_share` |
| Mid-page promo banner buttons | `banner_click` |

A button that **opens** a form flow is a `cta_click`; the eventual submission is `form_submit`. Two
actions at two different times, not a conflict.

The verdict carries downstream. **State it in bold at the top of the spec**, because it tells the
dev team whether they are blocked on analytics or free to ship immediately.

## D3 - Surface the candidate KPI rows

Read `docs/business/key-performance-indicators.md` and list every row the proposed event could
feed, saying for each whether the event would be the **numerator** or the **denominator**.

```
Candidate KPI rows for `card_click`:
- E - Discovery / card-to-profile rate - would be a new numerator alongside
  `profile_view (source_surface=category)`; the denominator `card_impression
  (source_surface=category)` already exists.
- No existing row measures card engagement directly.
```

If nothing matches, **say so plainly**. "No KPI row in the catalog covers this" is a legitimate and
useful output. Do not manufacture a row to make the request pass.

## D4 - Stop at the KPI gate

> **The KPI gate:** a metric must answer a question tied to a KPI or a decision that will be made;
> if it does not, it goes back to the requester to sharpen or drop.

This skill **surfaces** the candidate rows and states when none match. **It must not decide.** End
define mode with a recommendation and a stop:

```
Reuse verdict: reuse with a new cta_id (no GTM change).
KPI rows matched: none directly; nearest is H - CTA click rate by surface.
Recommendation: sharpen or drop - the requester has not named a decision this would change.
Waiting on the analyst.
```

Then stop. Do not proceed to spec mode in the same run unless the gate is explicitly cleared.

## D5 - Draft the event and parameters

Only once the gate is cleared. A `snake_case` event name and a **flat** parameter set, every value
inside a controlled vocabulary. Flag which params need to be sliceable in GA4 - those become custom
dimensions in build mode. Params that are not registered land in BigQuery but stay invisible in GA4
reports.

Then run the [Validation](#validation-run-this-on-every-draft) checks before writing anything.

---

# spec mode

Spec mode generates **both** documents. They serve different readers and neither substitutes for
the other.

| Document | Path | Reader | Life |
|---|---|---|---|
| Tracking-plan event page | `docs/dev/tracking-plan/<event_name>.md` | anyone querying the event, forever | evergreen, one per event |
| Dev handoff spec | `docs/dev/specs/<domain>/<subject>.md` | the dev team, for this build | dated, one per project |

`<domain>` is an existing folder where one fits: `forms`, `homepage-redesign`, `cards`,
`display-ads`. A new domain folder is a deliberate choice, not a default.

## S1 - The tracking-plan event page

Follow the anatomy of the existing sibling pages (`cta_click.md`, `card_impression.md`,
`form_submit.md`). **The body is the spec.** Unknown values are the literal string `TBD`, never a
guess.

```markdown
# <event_name>

**Status:** Active / Spec'd, not built / Broken
                 (copy the status glyph convention from a sibling page in `docs/dev/tracking-plan/`)

**dataLayer migration:** <one line on where the tag fires from and what was deleted>

<What fires it, in one paragraph: the exact user action, the push, the dedup rule, and what it is
deliberately distinct from.>

## Known issues
## Exclusions            <- when the event could overlap another
## Screenshot
## Trigger               <- table: Trigger ID, name, type, filter, tag
## DataLayer push        <- the reset push, then the event push, then a reference implementation
## Parameters            <- table: Parameter, Type, Source, Notes
## Valid values          <- per-param enums, linking to conventions.md for shared ones
## Dimensions & metrics mapping   <- table: Parameter, GA4 dimension, Scope, CD slot, Notes
## BigQuery notes        <- how to query and dedup it
## Implementation notes  <- checkbox list, the dev-facing summary
```

Two things the page must always carry:

- The **state-reset push** at the head of every code block (see [Validation](#validation-run-this-on-every-draft)).
- The counting rule, when raw events overstate reality. `form_submit` over-fires roughly 8x on a
  contact overlay, so its page mandates `COUNT(DISTINCT CONCAT(user_pseudo_id, '-',
  CAST(ga_session_id AS STRING)))`. Any event with a similar re-fire pattern needs the same note.

## S2 - The dev handoff spec

Two shapes exist in the repo. Pick by scope.

**Lean** - a small, well-bounded change to an existing event. Model:
`docs/dev/specs/forms/form-submit-instrumentation-spec.md`.

```markdown
# <subject> (dev spec)

**Task:** [<task-id>](<task-url>)
**Owner:** analytics · **Implementer:** dev team
**Status:** <where it is right now>

**<The reuse verdict, in bold.>** e.g. "No GTM changes needed - the live
`Custom Event - form_submit` trigger picks the pushes up as soon as the frontend fires them."

Canonical event contract: [`tracking-plan/<event>.md`](../../tracking-plan/<event>.md).

## The pattern (already live elsewhere)   <- point at a working reference implementation
## Push payload                           <- one fenced block, copy-pasteable
## Forms / surfaces to instrument          <- table, priority order, every param value filled in
## Rules                                   <- the invariants, one line each
```

**Rich** - a redesign or a multi-interaction surface. Model: the richest redesign handoff in
`docs/dev/specs/`.

```markdown
# <surface> - analytics handoff (`<path>`)

<Intro: what is being built, links to the redesign task and Figma, and a sentence saying this
supersedes any provisional event names in the design doc.>

## Page-level facts        <- table: URL, source_surface, page_type, reset push
## Interaction → event map (the contract)
   <- table: Section | Element | Action | Event | Key id / params, one row per tracked interaction
## What's new vs. reused
   <- four buckets: new custom event / new ids / scope change to an existing event / reused as-is
---
## Section detail
### N. <section> → <event>
   <screenshot>, markup contract table, the html hooks, the reset push + event push, params table
## Markup contract summary  <- every data-gtm-* hook the page must carry
## Action items             <- checkbox list, each prefixed **dev** or **gtm-admin**
```

The section detail is what the dev team builds from: a screenshot per tracked element, the exact
`data-gtm-*` hooks, and a dedup rule wherever two elements could fire on one click ("the card-click
handler must ignore clicks that originate on the outbound link").

## S3 - Ownership, written into every spec

Non-negotiable, and stated explicitly so nobody waits on the wrong team:

| Owner | Owns |
|---|---|
| **analytics** (`gtm-admin`) | the GTM container: workspace, `Custom Event` trigger, `GA4 - <Event>` tag, `DLV - *` variables. Plus GA4 custom-dimension registration. |
| **dev team** | the `dataLayer`: the `data-gtm-*` markup hooks and every `dataLayer.push`. |

Say **"dev team"**, never "engineering". In action-item lists the two owners are written **dev** and
**gtm-admin**, one prefix per checkbox. Dev works on a `CU-<task-id>` branch.

The markup hooks and the push **are part of the template**: they must survive any redesign or
refactor. That is what the `gtm-` prefix signals.

## S4 - Validate, then write

Run every check in [Validation](#validation-run-this-on-every-draft). Fix or flag each failure
before the file is written. Then write both documents into `docs/` - they are durable and
team-facing (see [Where things are written](#where-things-are-written)).

---

# build mode

Build mode is **read-only against the shared production container**. It reads the live state so the
spec can carry real ids, and it emits the checklist of container work. **It never writes.**

## B1 - Read the container

Scripts are in `src/gtm-api/`, driven by Python and `google-auth` directly (the community GTM MCP
servers accept only Desktop OAuth, not a service account). Read scope is `tagmanager.readonly`.

```bash
cd "$(git rev-parse --show-toplevel)"
python3 src/gtm-api/list_ga4_tags.py      # every gaawe tag: eventName, paused state, triggers
python3 src/gtm-api/inspect_container.py  # all triggers, tags, variables for a workspace
python3 src/gtm-api/list_workspaces.py    # workspaces, and whether the live version has an entity
python3 src/gtm-api/dump_tags.py          # full config for tags by id
```

Only these four. The write scripts in the same directory are out of scope here.

Fill into the spec: the real **Trigger ID**, trigger name, tag name and **tagId**, and the `DLV - *`
variable names each param reads from. Replace every `TBD` you can resolve; leave the rest as `TBD`.

API gotchas, so a read does not mislead: returned `path` values are relative (prefix
`https://tagmanager.googleapis.com/tagmanager/v2/`); GA4 event tags carry their params in an
`eventSettingsTable` list of `{parameter, parameterValue}` maps, not as top-level fields.

## B2 - Emit the container checklist

The work itself is a **human decision and a human action** (see
[What stays a human decision](#what-stays-a-human-decision)). Emit it as a checklist for the
analyst to execute in the GTM UI, not as commands to run:

```markdown
- [ ] **gtm-admin**: create a fresh workspace named `<yyyy-mm-dd> <subject>`.
- [ ] **gtm-admin**: create trigger `Custom Event - <event_name>`, type Custom Event,
      filter `{{_event}}` equals `<event_name>`.
- [ ] **gtm-admin**: create the `DLV - <param>` variables. Params inside `event_data` read
      `event_data.<param>` (Data Layer Version 2, dot notation). Top-level page context reads the
      bare key - that is the `DLV - page_type` vs `DLV - page_type (event)` split.
- [ ] **gtm-admin**: create tag `GA4 - <Event Name>` (type GA4 Event), event name `<event_name>`,
      params from the `DLV - *` variables, firing on the trigger above.
- [ ] **gtm-admin**: register `<param>` as a GA4 custom dimension (Admin → Custom definitions).
      Unregistered params land in BigQuery but stay invisible in GA4 reports.
- [ ] **dev**: markup hooks and the `dataLayer.push` on a `CU-<task-id>` branch, then staging.
```

GTM naming, from `conventions.md`, is not optional:

| Object | Format | Example |
|---|---|---|
| Tag | `[Type] - [Description]` | `GA4 - Form Submit` |
| Trigger | `[Event/Type] - [Description]` | `Custom Event - form_submit` |
| Variable | `[Type] - [Description]` | `DLV - source_surface` |

Two constraints to state every time: a numeric param lands in `value.int_value`, not
`value.string_value`, in the BigQuery export; and publishing a workspace **consumes** it against the
free-tier three-workspace cap, so create a fresh workspace per publish.

## B3 - Reuse path

If the reuse check said "reuse as-is" or "reuse with a new id", build mode's whole output is one
line: **no container work; the existing trigger already fires**. Skip to qa mode. Say it in bold so
nobody opens a workspace out of habit.

---

# qa mode

Two checklists. They are **different**, not the same list run twice. Build each one from the spec's
own contract rows - one check per tracked interaction, per param, per enum value - so the checklist
is as specific as the spec.

## Staging QA

**Delegate the run to the `tracking-qa` agent.** It drives a real browser through every surface in
the spec's per-instance table, reads the `dataLayer` and the emitted GA4 hits directly, and returns
a PASS or FAIL per surface. Give it the spec path, the URLs, and **an explicitly named browser** -
it will refuse to guess between the work and personal Chrome profiles, by design. Your job in this
mode is to hand it the contract and act on its verdict, not to click through the site yourself.

The staging hosts sit behind **HTTP basic auth**. Authenticate that browser profile by hand before
the run. **Never inline those credentials** into a spec, a QA file, a command in the transcript, or
anything under `docs/`.

**Two mechanical traps.** Both produce a false "not firing" verdict:

1. **gtag batches post-load events and flushes on unload.** Click and scroll events are queued, not
   sent immediately, and are **not visible before navigation**. Never conclude "not firing" from a
   missing live hit on a click that navigated away.
2. **The browser network tool redacts any URL containing a query string**, which hides all GA4/GTM
   traffic, since every collect hit is query-string-encoded. Read hits from the resource timing API
   instead and parse `en=` for the event name:

```js
performance.getEntriesByType('resource')
  .filter(r => r.name.includes('/g/collect'))
  .map(r => new URLSearchParams(r.name.split('?')[1]).get('en'));
```

Or use Tag Assistant, which is not subject to the redaction. A batched POST to `/g/collect`
carries its event names in the body, not the URL, so an `en=` parse that comes up empty is
inconclusive for post-load events - confirm from the `dataLayer` or Tag Assistant.

The checklist:

```markdown
- [ ] Fires on the correct interaction, and on **no other**.
- [ ] Fires **before** any cross-domain redirect or navigation.
- [ ] The state-reset push precedes every event push.
- [ ] The event carries **exactly** the spec'd params - no missing ones, and **no extras**.
      Extras drift into inconsistency and are as much a failure as a missing param.
- [ ] Every value is inside its controlled vocabulary (`source_surface`, `form_type`, `cta_id`).
- [ ] Fires exactly once per action. No double-count where two elements overlap.
- [ ] For forms: fires on server-confirmed success only, never on validation error or a 4xx/5xx.
      QA with a real-domain address at human speed - the endpoint rejects bad-MX domains (422) and
      honeypot / too-fast submits (400), and the push correctly does not fire on either.
- [ ] Per interaction row in the spec's contract table: <one line each>
```

**The gate:** anything failing loops back to the dev team, not forward. Only a clean pass ships.

## Production QA

### Step 0, mandatory: confirm the build actually reached production

Before checking anything else, confirm the QA'd build is deployed. Check the merge and the release,
or diff the live markup for the `data-gtm-*` hooks the spec requires.

This is not ceremony. A real incident: live banners emitted the wrong id and produced zero tracking
for weeks, because a staging-green build was never deployed. Every downstream check would have read
as "ingestion problem" and sent the investigation the wrong way.

### Then the ingestion ladder, by latency

| Layer | Latency | What it proves |
|---|---|---|
| GA4 DebugView / Realtime | about 5 minutes | the tag fires and the hit reaches GA4 |
| GA4 standard reports | 24 to 48 hours | the params resolve as registered dimensions |
| BigQuery `events_*` (finalized) | one to two days | the full payload, queryable |

**There is no `events_intraday_*` table.** The newest finalized shard trails by a day or two -
the session-start freshness line prints the real boundary - so a same-day change is invisible
until its date exports. If the SOP or an older spec
says `events_intraday_*`, **the SOP is stale** - flag it for the evergreen doc update in ship mode.

A **503 on `/g/collect`** during automated prod QA is most likely bot-flagging of the automated
browser, not an ingestion failure. Confirm with a manual hit before escalating.

---

# ship mode

## P1 - Publish checklist

Publishing is a human action in the GTM UI. The API service account has **Edit, not Publish**; a
version-create or publish call returns 403.

```markdown
- [ ] **dev**: merge the `CU-<task-id>` branch to production and deploy.
- [ ] **gtm-admin**: publish the workspace in the GTM UI as the owner account,
      version-named `YYYY-MM-DD - <subject>`.
- [ ] **gtm-admin**: run production QA (step 0 first).
```

Order matters. Publishing a tag before the pushes are live produces a tag that fires on nothing;
deploying pushes before the tag exists produces events GA4 drops.

## P2 - BigQuery verification

Run at D-2 or later. Four things this query does that a naive one does not:

- filters on **`_TABLE_SUFFIX`**, never `event_date`;
- reports param **presence rate per day**, not mere presence, so partial coverage is visible (a
  `form_name` regression sat at 4.2% and read as "present");
- coalesces **`string_value`, `int_value` and `double_value`** before concluding a param is missing;
- applies the **standing spam exclusion** via the canonical view, with **`NOT EXISTS`, never
  `NOT IN`** - a single NULL session id on either side of a `NOT IN` empties the result or leaks
  rows with no error, and during post-ship verification an empty result reads exactly like "the
  event never fired".

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

Read it as: `events` should match the expected volume, `param_presence_rate` should be at or near
1.000 on every day (not just in total), and `distinct_values` should equal the vocabulary size with
no strays. For any event that over-fires, report **sessions**, never raw events.

Run it with the `bq` CLI. Confirm the work account before querying, never personal.

## P3 - Closeout

Write the closeout to `docs/dev/feedback-loop/GTM-<Subject>-Closeout-<task-id>.md`:

```markdown
# <subject> - closeout (<task-id>)

**Shipped:** <date>  ·  **Rounds of QA:** <n>  ·  **Container version:** v<nnn>

## What shipped
## What was found in QA, and what was changed
## Known defects accepted as-is, and why
## Verification
   <the BigQuery numbers, the dates they cover, and what they confirm>
## Still open
```

Accepted defects belong here explicitly. `form_submit` thank-you-page pushes re-firing on refresh
was accepted as-is on 2026-07-22, and the closeout is why anyone reading the numbers a year later
knows that.

## P4 - Evergreen docs to update

Nothing ships that is not written down. Work through this list and say which ones changed:

| Doc | Update when |
|---|---|
| `docs/dev/tracking-plan/<event>.md` | always. Status, real trigger/tag ids, known issues, verified param coverage |
| `docs/dev/tracking-plan/README.md` | a new custom event joins the table, or an event's status changes |
| `docs/config/conventions.md` | a vocabulary was extended, or a new `data-gtm-*` hook was added |
| `docs/config/ga4.md` | a param was registered as a custom dimension; record the slot index |
| `docs/config/gtm.md` | container version, new tag/trigger inventory |
| `docs/business/key-performance-indicators.md` | the event feeds a KPI row, or unblocks a blocked one |
| `docs/dev/specs/<domain>/<subject>.md` | status line: shipped, QA'd, prod-verified |
| the Validation section of this skill | a controlled vocabulary was extended; its "exactly these N" lists are snapshots |

Two known drifts worth checking on any form work: `conventions.md` still lists fewer `form_type`
values than `tracking-plan/form_submit.md` carries (the newer file is right); and the SOP still
references `events_intraday_*`, which does not exist.

---

# Validation, run this on every draft

Mechanical checks. Run them on any draft, in any mode, before a file is written. Each failure is a
reject with the specific reason, not a warning.

## Vocabularies

**`source_surface` - exactly these 8 values.** Anything else is a reject.

`homepage` · `category` · `article` · `profile` · `search_results` · `dashboard` · `pricing` ·
`footer`

The granular values (`article_snippet`, `category_sub`, `search`, …) were **deliberately
collapsed** into these and are retired. The collapse is one-way: they must not come back in docs,
dashboards, KPIs or BigQuery predicates.

**`form_type` - exactly these 8.** Off-enum values are a reject; `form_type` drives every form KPI.

`contact` · `inquiry` · `newsletter` · `signup` · `demo_request` · `advertise` · `review` ·
`sponsorship`

**`cta_id` - must be globally unique across `cta_click` and `card_click`.** Never reuse a value.
Grep the catalog in `cta_click.md` before proposing one. Naming is lowercase kebab-case,
`{action}` or `{context}-{action}` when disambiguation is needed; the human label rides in
`cta_text`, never baked into the id.

## Names

- Event names: `snake_case`, lowercase, **max 40 characters**, verb-noun shape.
- Reserved GA4 names, never redefine: `page_view`, `session_start`, `user_engagement`,
  `first_visit`, `scroll`, `file_download`.
- Param names: `snake_case`. Booleans are `is_*` / `has_*`. Ids are `*_id`. Free text is a bare
  noun (`card_name`, `cta_text`).

## GA4 value length limits

Any param value exceeding its limit is truncated, and an invalid `page_location` produces an empty
dimension rather than a truncated one.

| Parameter | Max length |
|---|---|
| `page_location` | 1,000 (and must be a valid URL path) |
| `page_referrer` | 420 |
| `page_title` | 300 |
| every other event parameter | 100 |

## The state-reset push

**Every generated code block emits it.** No exceptions.

```js
dataLayer.push({ event_data: undefined, items: undefined, item_list_name: undefined });
dataLayer.push({ event: '<event_name>', event_data: { /* params */ } });
```

Without it a `card_impression` followed by a `form_submit` leaks the card context into the form
event. The rule is enforced across the site bundles and every inline push.

## Overlap

Run the proposed interaction against the **Exclusions** table in `cta_click.md` (reproduced in
[D2](#d2---reuse-check-before-anything-else)) and report which existing event already owns it. Where
two elements sit inside one another, the spec must state the dedup rule explicitly.

---

# What stays a human decision

This skill prepares, validates and reports. It does not decide any of the following. Surface the
options, state the trade-off, and stop.

- **The KPI gate itself.** The skill surfaces candidate rows and says when none match. The analyst
  decides whether the metric earns its place.
- **The leanness call** - whether an interaction is too granular to track at all. Pagination, FAQ
  accordions, gallery opens and sort/filter minutiae are **not tracked unless asked**. Propose the
  omission; do not spec it in on your own initiative.
- **Extending a controlled vocabulary.** `source_surface` was deliberately collapsed once and must
  not drift back open. A ninth value is a deliberate decision, never a variant of an existing one.
  Same for `form_type` and the `cta_id` catalog.
- **New event versus extending an existing one**, when genuinely ambiguous. Lay out both readings.
- **Accepting a known defect as-is.** Report it, quantify it, let the analyst decide.
- **Every write to the shared production GTM container, and the publish itself.** The service
  account has Edit but not Publish, so publishing happens in the GTM UI as the owner account,
  version-named. Build mode reads; a human writes.
- **Both QA sign-offs**, staging and production.
- **Anything touching credentials.** Read them from private memory when a task genuinely needs them;
  never inline, echo, or commit them.

---

# Where things are written

| What | Where | Committed |
|---|---|---|
| Tracking-plan event page | `docs/dev/tracking-plan/<event>.md` | yes |
| Dev handoff spec | `docs/dev/specs/<domain>/<subject>.md` | yes |
| Closeout | `docs/dev/feedback-loop/GTM-<Subject>-Closeout-<task-id>.md` | yes |
| Screenshots for a spec | `docs/dev/specs/<domain>/img/<subject>/` | yes |
| Per-round QA exchange, findings lists, dev back-and-forth | `wip/CU-<task-id>/` | **never** |
| Scratch queries, intermediate CSVs, container dumps | `wip/CU-<task-id>/` | **never** |

The rule, explicitly: **the tracking-plan page and the dev spec are durable and team-facing, so they
go straight into `docs/`.** Per-round QA exchange files are scratch and belong in `wip/`, which is
gitignored and never committed. A QA round is a conversation, not a record; the closeout is the
record.

Commit screenshots rather than pasting GitHub attachment URLs - `github.com/user-attachments/...`
URLs need an authenticated session and render broken in a committed markdown file. Download with
`curl -L -H "Authorization: Bearer $(gh auth token)" <url>`, confirm the real type with
`file --mime-type` (attachments arrive extensionless and are often JPEG), save under `img/`, and
reference it relatively.
