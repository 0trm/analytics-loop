---
name: cupify
description: Shape work into the team task template (title, TL;DR, Context, Deliverables, Next steps) and write it to ClickUp via MCP, then drop a local brief in wip/ for the session that will do the work. Two modes - create a new task from rough notes, or reshape an existing task in place. Copies the body to the clipboard and pushes only on explicit confirmation.
argument-hint: [rough notes for a new task OR a ClickUp task URL/ID to reshape; omit to use the latest assistant response]
user-invocable: true
---

# cupify

Turn a request into a structured task. This is the structure phase of the analytics pipeline
(step 5 of its full numbering): it converts a semi-structured ask into a ClickUp task with a
definition of done, and lands a local brief that the execution session reads.

Never invent scope. Two modes:

- **Create** - rough notes to a brand-new task (steps 1-6).
- **Reshape** - an existing ClickUp task to a restructured title and description, in place
  (step R). Never create a second task; never touch status, assignee, due date or custom fields.

### 0 - Pick the mode

- **Rough notes**, no task referenced, goes to Create mode.
- **An existing task** (URL, ID, or "reshape this" pointing at one) goes to Reshape mode. Read it
  first with `clickup_get_task`, `detail_level: "detailed"`.
- **A task sitting in the intake list** (`<intake-list-id>`) is a special case of Reshape.
  Stakeholder requests land there through the intake forms. Once the task is picked up it belongs
  where the work is tracked, so **move it to the team list** with `clickup_move_task` (`list_id`
  `<team-list-id>`) and then apply the full Create-mode template to it. Do not triage it in
  place, and do not leave it in the intake queue. The task keeps its ID and URL; its status
  resets to the destination list's default. Keep the assignee as the analyst.

---

## Create mode

### 1 - Get the input

The rough notes are in `$ARGUMENTS`. If empty, use the most recent assistant response in this
conversation as the source.

### 2 - Build the title

- Run `date +%Y-%m`. Map the month to a quarter: Jan-Mar `Q1`, Apr-Jun `Q2`, Jul-Sep `Q3`,
  Oct-Dec `Q4`.
- Prefix is `Q{q} {YYYY} {Owner} – ` (en dash, not a hyphen).
- Derive a short, specific `{Title}` from the notes. **Title case: capitalize every principal
  word**, not just the first. Keep literal tokens as-is (URL paths like `/pricing`, code
  identifiers, acronyms). So `March /pricing Traffic Spike`, not `March /pricing traffic spike`.
- Final title is prefix + `{Title}`, e.g. `Q3 2026 Ana – BigQuery Storage Cost Projection`.
- If the user already supplied a title in that form, keep it verbatim.

### 3 - Format the description

Exactly this structure, in this order:

```
**TL;DR:** {one-line summary}

**Context**
{background prose explaining why this task exists}

**Deliverables**
1. {concrete deliverable}
2. {concrete deliverable}

**Next steps**
- {actionable step}
- {actionable step}

**Useful links** _(only if the source has links; otherwise omit entirely)_
- [{label}]({url})
```

Rules:

- Preserve the user's facts. Do not invent deliverables, context or scope.
- `TL;DR` is a single line.
- `Deliverables` is numbered, `Next steps` is bulleted. Use native markdown markers so ClickUp
  renders real lists.
- **No em dashes** anywhere. Use en dashes, commas or colons. Convert any in the source.
- **At most one `~` per paragraph.** ClickUp's markdown roundtrip sometimes reads two tildes in
  one paragraph as a strikethrough pair and swallows everything between them, so "~9.6 GiB" and
  "~$1/month" in the same paragraph can strike out the text between. The parser is inconsistent,
  so it will not always bite. Write "about" or use a single tilde, and re-read the task after
  pushing if the body had more than one.
- **Preserve every link.** Collect all URLs from the description, custom fields and related tasks
  into **Useful links**, placed last. A dropped link is a bug.
- Omit **Useful links** entirely when there are none. No empty heading.
- If a section has no source material, write `_TODO: add context_` rather than fabricating.

### 4 - Copy and print

Copy only the description body to the clipboard:

```
pbcopy <<'EOF'
{description body}
EOF
```

Then print the title on its own line with the body below, so the two ClickUp fields can be pasted
separately.

### 5 - Create the task

Ask whether to push. Act only on **explicit confirmation**; never auto-push.

`mcp__clickup__clickup_create_task` with:

- `name` - the title from step 2
- `markdown_description` - the body from step 3
- `list_id` - `<team-list-id>` (the team task list, the default)
- `assignees` - `["<member-id>"]`

**Assignee is always the analyst**, by numeric ID. Do not use `["me"]`: this MCP ignores it on
create and leaves the task unassigned, with no error. Never assign by name if the name carries an
accent, it breaks lookup. After creating, verify the assignee took; if empty, re-apply with
`clickup_update_task`, which resolves reliably.

For a different list, resolve it via `clickup_get_list` or `clickup_get_workspace_hierarchy`.

If the `clickup` MCP is not connected, skip the push and say the body is on the clipboard.

### 6 - Land the local brief

Once the task exists, write `wip/CU-<task-id>/brief.md`:

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
- [ ] {the next one}

## Known constraints
{anything already established: date window, the specific forms or surfaces, dead events to
avoid, prior work to build on. Leave empty rather than guessing.}
```

`wip/` is gitignored. This brief is what the execution session and the `qa` agent both read, so
the definition of done has to be checkable, not aspirational. "Analyze form performance" is not a
definition of done; "a table of submits per form per week for Q2, spam excluded, sessions not
events" is.

---

## Reshape mode - step R

Restructure an existing task's title and description into the template. Rewrite those two fields
and nothing else. **Never create a second task.**

### R1 - Read

Resolve the task ID (`clickup_get_task`, `detail_level: "detailed"`). Pull substance from the
`description` **and** any populated custom fields (Requirements, Purpose) - these often hold the
real content while the description is thin.

### R2 - Build

- **Title:** rewrite into a short, specific, title-cased summary. Replace vague titles ("Minor
  Change in Looker Studio") with concrete ones ("Swap Session Source for Total Users in Looker
  Report"). Then apply the `Q{q} {YYYY} {Owner} – ` prefix from step 2. If the prefix is already
  there, keep it and rewrite only the title part.
- **Body:** same template and rules as step 3. Fold existing facts in; do not invent scope. If
  folding would drop a fact, carry it across. A lost fact is a bug.

### R3 - Update in place

Copy to clipboard and print as in step 4, then ask before pushing. On confirmation,
`clickup_update_task` with the same `task_id`, the new `name` and `markdown_description`.

**Keep status, assignee, due date and all custom fields exactly as they are.** Reshaping touches
the title and description only.

Optionally land the brief (step 6) if the task is about to be worked on.
