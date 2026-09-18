---
name: capture
description: Distil what this session learned into memory, before the task is considered done. Use at the end of any piece of analytics work, or when something non-obvious was discovered that would cost time to rediscover. Enforces the tier rule so memory stays small - durable facts get routed to docs/ instead of inflating the always-on index.
argument-hint: [optional focus, e.g. "just the BigQuery gotchas"; omit to review the whole session]
user-invocable: true
---

# capture

Turns what this session learned into something the next session starts from, and keeps memory
small while doing it. The memory index loads into every session, so each entry costs context
forever. Most of what feels worth remembering is documentation and belongs in `docs/`.

## 1 - Harvest

Keep only what was **discovered, not looked up**, and would cost real time to rediscover:

- A query returned nothing for a non-obvious reason.
- A number disagreed with another source, and the cause was found.
- A platform behaved differently from its documentation.
- A decision now constrains future work, with its reason.
- The analyst corrected an approach, and the correction generalizes.

Skip anything already in `docs/`, `CLAUDE.md` or a skill (check first), the analysis result
itself, how-tos the docs already cover, and anything false within a month that does not matter
until then.

## 2 - Route each fact

Exactly one destination per fact:

| Destination | When | Action |
|---|---|---|
| `docs/` | durable, team-relevant, slow to change | Note it for `/promote`. Not in memory. |
| `CLAUDE.md` | it produces wrong answers without warning, on nearly every task | Propose the one-line edit to the analyst. Rare. |
| a skill | it is a procedure, or a rule inside one | Propose the edit to that skill. |
| memory | volatile private state: a live outage, an in-flight decision, a preference | Write it (step 3). |
| nothing | already recorded, or will not matter again | Say so and drop it. |

Default to `docs/`. If you cannot say what would make a fact obsolete, it is documentation, not
memory.

## 3 - Write memory entries

First **check for an existing entry on the subject and update it** instead; two entries on one
subject is the failure this skill prevents. Otherwise, one fact per kebab-case file in this
project's memory directory:

```markdown
---
name: <short-kebab-case-slug>
description: <one line; recall matches on it, so make it specific>
metadata:
  type: project | feedback | reference | user
---

<The fact. Absolute dates: "since 2026-07-03", never "since last week".>

**Why:** <what made this true, and when it was established>

**How to apply:** <what a future session should do differently>

Related: [[other-memory-name]]
```

Then add one line to `MEMORY.md` under the right heading: `- [Title](file.md) – hook`. **Never
put content in `MEMORY.md`**; it is an index that loads every session.

## 4 - Prune

Delete index entries that are now:

- **Wrong:** the code, path or platform changed.
- **Superseded:** a newer entry covers it. Merge, then delete the old one.
- **Graduated:** `/promote` moved it to `docs/`. Two copies drift; the team reads the docs one.
- **Dead-pathed:** it names a file, folder or repo that no longer exists. Verify, then delete.

## 5 - Report

1. What was written to memory, and why each entry is volatile rather than durable.
2. What was routed to `docs/` for `/promote`.
3. What was pruned.
4. The index count before and after. If it grew, justify it.

Never write credentials, tokens, key paths or passwords into anything bound for the repo. They
stay in private memory; the repo is company-visible.
