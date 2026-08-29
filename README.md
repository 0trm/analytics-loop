# analytics-loop

One person runs the whole analytics function of a startup: intake, tracking, warehouse, QA,
delivered reports. This repo is the harness that makes that workable - AI does the work, the human
sets direction and holds the bar.

## The objective

**Minimize the time from raw data to a trusted insight, on the question that matters most right
now.** Two bounds come before speed:

- **Direction.** Humans decide what is worth working on. Speed in the wrong direction is waste.
- **Accuracy.** A constraint, not a trade-off. Fast but wrong is not ok.

Inside those bounds, maximize speed. The metric is median time from request to delivery, guarded by
rework iterations per task; the task tracker supplies both, since every request enters it at intake
and leaves at delivery. Rework climbing means the work is pointed wrong or the bar is being missed,
and either one makes a faster median meaningless.

### The pipeline

Every request runs through five phases. Trivial asks are handled on the spot but still logged;
everything else is structured and reviewed against the goal before it ships:

![The analytics pipeline: five phases across stakeholder, analyst and agent lanes, with four feedback loops](assets/pipeline.png)

Four dashed loops, each cheaper than the one after it:

1. **Sharpen the ask, at intake.** [`/clarify`](.claude/skills/clarify/SKILL.md) checks what the
   data can actually answer and drafts the questions - including the one that collapses the rest:
   what decision will the answer change. A correction here is free.
2. **A QA FAIL returns to the session.** The [`qa`](.claude/agents/qa.md) agent re-derives every
   result from the brief by its own route before a human sees it; two routes agreeing is evidence,
   one route re-read twice is not. For instrumentation,
   [`tracking-qa`](.claude/agents/tracking-qa.md) drives a real browser against the spec instead. A
   FAIL costs a session iteration, not a delivery.
3. **Human review reframes, last.** It lands on work that already passed QA, so it is a direction
   and framing check, not a correctness hunt.
4. **Rework after delivery.** A stakeholder bouncing a delivered answer costs the whole task. The
   three loops above exist to starve it.

Between the loops, work runs against a written definition of done
([`/cupify`](.claude/skills/cupify/SKILL.md) produces it, carrying the decision the answer serves),
with schema hunts delegated to the [`bq-explore`](.claude/agents/bq-explore.md) agent so
exploration noise never crowds out reasoning. Delivery runs through
[`/report`](.claude/skills/report/SKILL.md). Tracking runs its own define-spec-build-QA-ship flow
through [`/tracking-spec`](.claude/skills/tracking-spec/SKILL.md), which stops at a KPI gate: a
proposed metric must feed a KPI row or a named decision, or it goes back to be sharpened or
dropped.

### The compounding loop

The fifth phase serves the next request instead of the current one:

![The memory loop: capture into private memory, weekly promote into team docs](assets/memory-loop.png)

[`/capture`](.claude/skills/capture/SKILL.md) runs before a task closes and routes what the session
*discovered* by tier: durable facts toward `docs/`, procedure corrections into the relevant skill,
and only volatile state into private memory - which loads every session, so it stays small.
[`/promote`](.claude/skills/promote/SKILL.md) runs weekly and headless: it verifies each candidate
fact still holds, folds it into `docs/`, and opens a PR. After the merge the memory copy is
deleted; two copies of one fact drift. The PR is also the privacy boundary, the only route from one
person's private memory into the shared repo, and it passes human review.

Each week's sessions start from a richer baseline than the last. That is the compounding.

---

MIT licensed. Built with [Claude Code](https://claude.com/claude-code); the pattern transfers to
any harness with files, tools and subagents.
