---
name: cupify
description: Shape work into the team task template (title, TL;DR, Context, Deliverables, Next steps) and write it to ClickUp via MCP, then drop a local brief in wip/ for the session that will do the work. Two modes - create a new task from rough notes, or reshape an existing task in place. Copies the body to the clipboard and pushes only on explicit confirmation.
argument-hint: [rough notes for a new task OR a ClickUp task URL/ID to reshape; omit to use the latest assistant response]
user-invocable: true
---

# cupify

Turns a request into a ClickUp task with a checkable definition of done, plus a local brief for
the session that does the work. Never invent scope.

## 0 - Pick the mode

- **Rough notes**, no task referenced -> **Create** (steps 1 to 6).
- **An existing task** (URL, ID, "reshape this") -> **Reshape** (R1 to R3). Read it first with
  `clickup_get_task`, `detail_level: "detailed"`.
- **A task in the intake list** (`<intake-list-id>`): move it to the team list with
  `clickup_move_task` (`list_id` `<team-list-id>`), then apply the full Create template to it.
  Do not triage it in place. It keeps its ID and URL; status resets to the list default; the
  assignee stays the analyst.

## Create mode

### 1 - Input

Rough notes from `$ARGUMENTS`, else the most recent assistant response.

### 2 - Title

1. Run `date +%Y-%m` and map the month to a quarter (Jan-Mar `Q1` ... Oct-Dec `Q4`).
2. Title is `Q{q} {YYYY} {Owner} – {Title}`, with an en dash. `{Title}` is short, specific and in
   title case (every principal word capitalized). Keep literal tokens as they are: `March
   /pricing Traffic Spike`. Example: `Q3 2026 Ana – BigQuery Storage Cost Projection`.
3. A title already in that form is kept verbatim.

### 3 - Description

Exactly this structure:

```
**TL;DR:** {one-line summary}

**Context**
{why this task exists}

**Deliverables**
1. {concrete deliverable}

**Next steps**
- {actionable step}

**Useful links** _(only if the source has links; otherwise omit entirely)_
- [{label}]({url})
```

**Words.** Follow **Writing for peers** in the repo `CLAUDE.md`. Stakeholders and the manager
read the TL;DR and Context, so those two stay in plain words: the TL;DR leads with the outcome,
and Context runs as short as the facts allow, ideally two or three sentences. Table, dataset and
view names belong only in Next steps, where the person doing the work needs them.

**Template.** These hold even where the peer rules differ:

- The markers ship literally, asterisks included, each heading on its own line. ClickUp returns
  `**` unchanged, so a body that comes back without them was written without them.
- Deliverables numbered, Next steps bulleted, with native markdown markers.
- Every item stays. If Deliverables or Next steps pass five, tell the analyst in chat; they
  decide whether to split the task. Never cut an item or fold a section into prose.
- Preserve every fact and every link. Collect all URLs (description, custom fields, related
  tasks) into Useful links, placed last. A dropped fact or link is a bug. No links, no heading.
- A section with no source material gets `_TODO: add context_`, never invented content.

**ClickUp formatting traps**

- At most one `~` per paragraph. Two can be read as a strikethrough pair and swallow the text
  between them. Write "about" instead, and re-read the task after pushing if the body had more
  than one.
- No em dashes. Convert any in the source.

### 4 - Copy and print

Copy only the body with `pbcopy <<'EOF' ... EOF`. Print the title on its own line with the body
below, so the two fields paste separately.

### 5 - Create (ask first)

Push only on **explicit confirmation**; never auto-push. `clickup_create_task` with:

- `name`: the title
- `markdown_description`: the body
- `list_id`: `<team-list-id>` (the team task list, the default). Resolve any other list with
  `clickup_get_list` or `clickup_get_workspace_hierarchy`.
- `assignees`: `["<member-id>"]` (the analyst). Never `["me"]`, which this MCP ignores on create
  without an error, and never by a name with an accent, which breaks lookup. After creating,
  check the assignee took; if empty, re-apply with `clickup_update_task`.

If the `clickup` MCP is not connected, skip the push and say the body is on the clipboard.

### 6 - Local brief

Once the task exists, write `wip/CU-<task-id>/brief.md` (gitignored):

```markdown
# {title without the Q{q} {YYYY} {Owner} – prefix}

ClickUp: {task url}
Opened: {date +%Y-%m-%d}

## Question
{the actual question, one or two sentences}

## Decision
{what will change based on the answer, carried over from /clarify. Write
_TODO: no decision named_ rather than inventing one.}

## Definition of done
- [ ] {the concrete deliverable}

## Known constraints
{date window, forms or surfaces, dead events to avoid, prior work. Empty rather than guessed.}
```

The execution session and the `qa` agent both read it, so the definition of done must be
checkable. "Analyze form performance" is not; "submits per form per week for Q2, spam excluded,
sessions not events" is.

## Reshape mode

Rewrites an existing task's title and description, nothing else. **Never create a second task.**

### R1 - Read

Pull substance from the description **and** populated custom fields (Requirements, Purpose),
which often hold the real content.

### R2 - Build

- **Title:** short, specific, title case, with the step 2 prefix. Replace vague titles ("Minor
  Change in Looker Studio") with concrete ones ("Swap Session Source for Total Users in Looker
  Report"). If the prefix is there, rewrite only the part after it.
- **Body:** step 3 template and rules. Carry every existing fact across.

### R3 - Update in place

1. Copy and print as in step 4, then ask before pushing.
2. On confirmation, `clickup_update_task` with the same `task_id`, new `name` and
   `markdown_description`. **Status, assignee, due date and custom fields stay exactly as they
   are.**
3. Optionally land the step 6 brief if the task is about to be worked on.
