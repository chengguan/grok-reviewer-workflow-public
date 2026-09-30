# {{PROJECT}}

{{ONE_LINE_WHAT_THIS_IS}}

Shipping: **{{VERSION}}** (build {{BUILD}}).

## Layout

- `{{SRC}}` — {{SRC_ROLE}}
- `docs/` — current briefing (`NOW.md`), decision index, task packets, workflow

## Hard rules

- {{RULE_1}}
- {{RULE_2}}
- {{RULE_3}}

Keep this list as product law that outlives a task. Dated choices go in `docs/decisions/`, not here.

## Context loading

1. This file.
2. `docs/NOW.md`.
3. Interactive sessions take a role (**coder** or **reviewer**) here; if the user has not already named one, ask and wait. Bots skip this step.
4. Stop.

Do not read `docs/archive/`, `docs/tasks/*.log.md`, or any `AGENT-NOTES.md` unless `docs/NOW.md` names that exact path. Durable choices live in `docs/DECISIONS.md` (index). Read one `docs/decisions/D-*.md` only when this task collides with that decision.

Do not create `CLAUDE.md` (or a second instruction file) that copies this one. Grok loads every matching name; two copies double the tokens.

## Role

Named before any implementation or review. `NOW.md` `Role next` is who to launch, not a self-assignment. Do not switch roles in this session.

Hard gates: coder does not commit the product change before `Review: pass` (or the owner's contention ruling). Reviewer does not implement the fix. Bots do not satisfy a reviewer pass; the headless grok-review reviewer is not a bot (see `docs/WORKFLOW.md`).

Procedure for the role: `docs/WORKFLOW.md`. Read it when you are about to act on `NOW.md`'s `Review:` / `Role next:` fields — writing a review request, doing the review, or resolving a dispute — not before. Do not paste it here.

## Verify before handoff

{{TEST_COMMAND}}
