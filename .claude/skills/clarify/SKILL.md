---
name: clarify
description: Draft the clarifying questions for an incoming analytics request, grounded in what the data can actually answer. Use when a stakeholder ask arrives free-form or through the intake form and is not yet precise enough to execute. Produces a short list of questions for the analyst to approve and send, plus the assumptions it would use if no answer comes back.
argument-hint: [the request as it arrived - paste, task URL, or a description; omit to use the latest assistant response]
user-invocable: true
---

# clarify

Find the few ambiguities that would change the answer, ask only those, and state what you would
assume otherwise so the work can start without waiting. The questions go to a non-technical
stakeholder, so they follow **Writing for peers** in the repo `CLAUDE.md`.

## 1 - Read the request

Take it from `$ARGUMENTS`, a task read from the tracker, or the latest assistant response.
Restate it in one sentence. If the restatement is already precise, say so and stop; do not
invent questions.

## 2 - Check what the data can answer

Do this before asking anything; it is what makes the questions specific.

1. Read the events' pages in `docs/dev/tracking-plan/`: params, surfaces, launch date.
2. Map the stakeholder's words onto `docs/config/conventions.md`. "Category pages" may mean
   `source_surface = 'category'`, a path prefix, or both.
3. Check the events were alive and the data exists across the window (the Traps in `CLAUDE.md`;
   the session-start freshness line gives the newest shard). A dead event or missing history is a
   finding to lead with, not a question.

## 3 - Draft two to four questions

More than four means the request needs a conversation, not a form. Ask only what changes the work:

- **The decision.** What changes based on the answer. Ask this almost always; it often settles
  the rest.
- **Metric.** People, visits or clicks? Pin it for anything form-shaped (`form_submit`
  over-fires).
- **Scope.** Which pages, forms or surfaces. Offer your mapping in their words.
- **Comparison.** Against the previous period, last year, or a launch date?

Decide yourself: output format, spam exclusion (always on), which table, the breakdown the
request implies.

Each question answers in one sentence and offers the likely options ("A or B?"). No preamble.

## 4 - Fallback assumptions

For every question, the assumption you will use if no answer comes back, in one line:

```
If I don't hear back I'll assume: distinct visits, the last 8 complete weeks against the 8 before,
spam excluded, contact forms only.
```

## 5 - Output

Print, in order:

1. **The request**, in one sentence.
2. **What I already know**: anything that reframes the ask, such as a dead event or missing
   history. Lead with it when it makes the questions moot.
3. **Questions**, numbered, ready to send as-is.
4. **Fallback assumptions**, the block above.

Copy the questions to the clipboard with `pbcopy`. Then stop. **Do not send anything.** The
analyst approves and sends.
