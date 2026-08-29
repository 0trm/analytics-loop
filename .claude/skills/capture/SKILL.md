---
name: capture
description: Distil what this session learned into memory, before the task is considered done. Use at the end of any piece of analytics work, or when something non-obvious was discovered that would cost time to rediscover. Enforces the tier rule so memory stays small - durable facts get routed to docs/ instead of inflating the always-on index.
argument-hint: [optional focus, e.g. "just the BigQuery gotchas"; omit to review the whole session]
user-invocable: true
---

# capture

The first half of the pipeline's compounding phase (step 12 of its full numbering). Convert
what this session learned into something the next session starts from.

This skill exists as much to **keep memory small** as to write to it. The memory index loads into
every session, so every entry is a permanent tax. Most of what feels worth remembering is not
memory-shaped: it is documentation, and belongs in `docs/` where the team can read it.

## 1 - Harvest

Review the session for things that were **discovered, not looked up**. A fact qualifies only if
rediscovering it would cost real time.

Good candidates:

- A query returned nothing and the reason was non-obvious.
- A number disagreed with another source, and the cause was found.
- A platform behaved differently from its documentation.
- A decision was made that constrains future work, along with why.
- The analyst corrected an approach, and the correction generalizes.

Not candidates:

- Anything already in `docs/`, `CLAUDE.md`, or a skill. Check before writing.
- The result of the analysis itself. That is the deliverable, not a learning.
- How you did something the docs already explain.
- Anything that will be false in a month and does not matter until then.

## 2 - Route each fact

**This is the step that matters.** For each harvested fact, pick exactly one destination.

| Destination | When | Action |
|---|---|---|
| `docs/` | Durable platform truth, team-relevant, slow to change | Note it for `/promote`. Do not write it to memory. |
| `CLAUDE.md` | It produces wrong answers with no error, and applies to nearly every task | Propose the one-line edit to the analyst. Rare. |
| a skill | It is a procedure, or a rule governing one | Propose the edit to that skill. |
| memory | Volatile private state: a live outage, an in-flight decision, a personal preference | Write it, per step 3. |
| nothing | It is already recorded, or will not matter again | Say so and drop it. |

Default to `docs/`. Memory is for things that go stale within months. If you cannot say what would
make a fact obsolete, it is not memory, it is documentation.

## 3 - Write the memory entries

One fact per file, kebab-case name, in the memory directory for this project.

```markdown
---
name: <short-kebab-case-slug>
description: <one line - this is what recall matches on, so make it specific>
metadata:
  type: project | feedback | reference | user
---

<The fact, stated plainly. Convert relative dates to absolute: "since 2026-07-03", never
"since last week".>

**Why:** <what made this true, and when it was established>

**How to apply:** <what a future session should do differently because of it>

Related: [[other-memory-name]]
```

Before writing, **check for an existing entry that already covers it** and update that file
instead. Two entries on one subject is the failure mode this whole exercise is fixing.

Then add exactly one line to `MEMORY.md` under the right heading:
`- [Title](file.md) – hook`

**Never put content in `MEMORY.md`.** It is an index. It loads every session.

## 4 - Prune while you are here

Capture is also when memory shrinks. Scan the index for entries that are now:

- **Wrong** - the code, path or platform changed. Delete.
- **Superseded** - a newer entry covers it. Merge and delete the old one.
- **Graduated** - the fact reached `docs/` via `/promote`. Delete the memory copy; two copies
  drift, and the docs copy is the one the team reads.
- **Dead-pathed** - it names a file, folder or repo that no longer exists. Verify, then delete.

Deleting an entry is as valuable as adding one. Report what you removed.

## 5 - Report

State plainly:

- What was written to memory, and why each entry is volatile rather than durable.
- What was routed to `docs/` for `/promote` to pick up.
- What was pruned.
- The index count before and after. If it grew, justify it.

Never write credentials, tokens, key paths or passwords into anything destined for the repo.
Those stay in private memory only. This repo is company-visible.
