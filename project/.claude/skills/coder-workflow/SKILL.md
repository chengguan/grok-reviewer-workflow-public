---
name: coder-workflow
description: Keep the coder role cheap and effective. Covers session hygiene (a fresh session per task or review round), a small per-call floor, few calls, small tool output, delegation, model choice, and measuring coder cost. Use at the start of any coding task, and whenever a session feels long.
---

# Coder workflow

The coder's cost is **context size × calls**. Every call re-sends the whole conversation, so a session's price grows with its length, whatever the work is. Measured on one long session: 98.7% of 26M coder tokens were cached re-reads, and output was under 1%. The reviewer (grok-review) was only about 7% of the total.

Workflow-template's rule applies here: *inject a briefing, retrieve a history*. Resume a session for the same thread and role. Start a new instance for a full window or another role.

## Rules

1. **Start a fresh session per task, and per review round.** The briefing is `AGENTS.md` + `docs/NOW.md` (+ this skill). The first message names the role and the job: `You are the coder. Read docs/NOW.md. Then: <one sentence>.`
2. **Hand off before the window is heavy.** Once the context passes `CODER_CONTEXT_MAX` (default 150k tokens), rewrite `NOW.md`, put evidence in the task log, and start a new session. Don't wait for auto-compaction.
3. **Keep the per-call floor small.** Tool and MCP schemas and skill listings are re-sent on every call. Turn off servers and connectors a coding session doesn't use.
4. **Use few calls.** Batch edits into one patch and one test run. Run independent commands in parallel. Don't re-read a file you just wrote.
5. **Keep tool output small.** Everything a tool returns stays in context for the rest of the session. Filter with `tail`, `grep` or `jq`, and have scripts print summaries. Never paste large blobs (encoded URLs, whole logs) into the conversation.
6. **Delegate self-contained work to a subagent**, which returns a summary rather than a transcript. Don't delegate work that needs the main conversation's context.
7. **Match the model to the work.** Use the strongest model for design and judgment, and a cheaper one for routine fix-and-request rounds. The reviewer's severity rule keeps the quality bar.
8. **Measure.** `grok-review.sh` writes a coder row per round to `docs/REVIEW-COSTS.md`, and `coder-costs` splits a session by request. A healthy fix round is well under 1M coder tokens.

## Tooling

Status: **built**. Scripts sit next to this file; tests in `tests/run.sh`.

- `coder.sh context`: current context size (the last response's input + cache tokens). Exit 10 above `CODER_CONTEXT_MAX` (150k): hand off.
- `coder.sh handoff`: the checklist and the next session's first message, job taken from `NOW.md`'s `Next:` line.
- `coder.sh costs`: tokens per request in this session.
- `coder.sh task start|resume <id>` at a session's start, `task pause` before a hand-off, `task done` at the end: one row per session segment in `docs/tasks/<id>.cost.md`. `task report <id>`: coder segments + reviewer rounds = the task's cost.
- `grok-review.sh round` / `finish` print the round's coder tokens and the context, and warn above `CODER_ROUND_WARN` (1M).
