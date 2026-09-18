---
name: promote
description: Weekly ritual that graduates durable facts out of private memory into the team-visible docs/, as a reviewable pull request. Use once a week, or when memory has accumulated facts that teammates would benefit from. This is the boundary gate between private state and shared knowledge.
argument-hint: [optional scope, e.g. "bigquery only"; omit to review all of memory]
user-invocable: true
---

# promote

The only route from private memory into team-visible `docs/`, as a reviewable pull request. Run
it weekly.

## 1 - Survey memory

Read the memory index, then every candidate entry in full; the index line is a hook, not the fact.
Promote an entry only when **all four** hold:

- **Durable.** Still true in six months. Live outages and in-flight decisions are not.
- **Team-relevant.** A teammate on the same surface would need it. Personal preferences never
  promote.
- **Verified.** It has held up against reality, not been asserted once. Verify it now or leave it.
- **Safe.** No credentials, tokens, key paths, passwords or personal detail. The repo is
  company-visible; when in doubt it stays in memory.

## 2 - Verify each candidate

A stale fact in `docs/` does more harm than one in memory, because the team trusts it.

- A file or path: confirm it exists.
- Data behaviour: one cheap BigQuery query.
- Platform config: confirm in GTM or GA4.

A candidate that fails is **corrected or deleted**, never promoted.

## 3 - Find its home

Fold into an existing file; a new file is a last resort.

| Kind of fact | Home |
|---|---|
| Warehouse layout, table behaviour, query gotcha | `docs/config/bigquery.md` |
| Event naming, controlled vocabulary, DOM hooks | `docs/config/conventions.md` |
| GA4 property config, custom dimensions | `docs/config/ga4.md` |
| GTM container, tags, triggers | `docs/config/gtm.md` |
| What an event means and which params it carries | `docs/dev/tracking-plan/<event>.md` |
| A metric definition | `docs/business/key-performance-indicators.md` |
| A cross-cutting rule such as spam | `docs/custom/` |
| How a dashboard is built and read | `docs/dashboards/` |
| How work flows end to end | `docs/sop/` |

Match the file's heading depth, table conventions and tone, so the fact reads like the text
around it. Rewrite the memory phrasing: memory is written for one reader, docs for the team.

## 4 - Open the pull request

```bash
git -C . pull --ff-only origin main        # always pull before branching
git checkout -b promote/<yyyy-mm-dd>
# apply the edits
git add docs/
git commit
gh pr create
```

Pull `main` first, every time; it avoids conflicts and resurrecting files deleted on `main`.

The PR body follows the PR rule in **Writing for peers** (repo `CLAUDE.md`). The visible part says,
in plain words, what the team now knows, with one bullet per file. The per-fact detail goes in a
collapsed `<details>` block: where each fact came from and how step 2 verified it, so a reviewer
can check it without rerunning the work.

Keep it small. A week is a handful of facts; a fifty-file PR is a migration and will not be
reviewed properly.

## 5 - Delete the memory copies

**Only after the PR merges**, remove each promoted entry and its index line. This is not
optional: two unsynced copies of one fact mean whichever is edited makes the other wrong. The
`docs/` copy is now the source of truth.

## 6 - Report

1. What was promoted, and into which file.
2. How each fact was verified.
3. What was held back, and why: not durable, not team-relevant, unverifiable, or sensitive.
4. What was deleted from memory outright.
5. The memory index count before and after.
