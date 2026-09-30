# Agent workflow

How Grok, Claude, and bots share a repo without loading history into every prompt.

Inject a briefing. Retrieve a history. Git, GitHub issues, and archived logs keep the years. They must not sit in the prompt.

## Roles

- **Product owner** — scope, Ready/Done, device testing, contention. Only the owner moves an item to Done.
- **coder** — interactive session. Implements from a Ready packet, a GitHub PR (this repo), or the user's instruction. Leaves a review request in `docs/NOW.md`. Answers review comments: fix or dispute. Not a bot.
- **reviewer** — interactive session. Watches `docs/NOW.md` for a review request. Senior-developer review of the working tree: code, security, privacy. Writes comments or a pass into `NOW.md`. Does not implement the fix. Not a bot.
- **Bots** (`Claude.bot`, `Grok.bot`) — automation. Headings and `(for …)` tags in task logs must use the bot names. Bot stamps are not a reviewer pass.
- **Headless reviewer** (`.claude/skills/grok-review/`) — the coder may run Grok Build headless and read-only as the **reviewer** for a task. It is not `Grok.bot`: its pass (`Review: pass` with `Reviewed: <fingerprint>`, costed in `docs/REVIEW-COSTS.md`, with a review record on the PR) counts as a reviewer pass. The coder pastes its verdict into `NOW.md` verbatim; it never writes `Reviewed:` itself. Contention still goes to the owner.

Every session takes **coder** or **reviewer** before any work. If the user did not name one, ask and wait. Do not assume from `NOW.md`. Do not switch roles in the same session — a new instance is a new role.

Rename the coder/reviewer tool lines in this file if a project swaps harnesses. Do not fork a second workflow doc.

## Artifacts (one home per fact)

| Kind | Home | Auto-loaded? | Mutate |
|---|---|---|---|
| Product law | `AGENTS.md` | yes | Edit when the **law** changes |
| Current work | `docs/NOW.md` | yes (step 2) | **Rewrite** at every handoff |
| Settled choice | `docs/decisions/D-NNN-slug.md` + one index line | no | Write once; mark superseded |
| Task intent | GitHub issue body, or `docs/tasks/<id>.md` | no | Write at Ready; update constraints |
| Review transcript | `docs/tasks/<id>.log.md` | no | Append; archive when closed |
| What landed | `git log`, issue comments | no | Commits cite `D-NNN` / issue |
| How to verify | tests + this project's test plan | no | Run, don't narrate |

`NOW.md` budget: 40–80 lines. `AGENTS.md` budget: 80–120 lines. Always-on target: under ~3,000 tokens.

## Backlog gate

GitHub issue (or equivalent) is the backlog. Status: `Backlog` → `Ready` → `In progress` → `In review` → `Done`.

An item in `Backlog` is not a start signal. Pick up only `Ready`. On pickup, move to `In progress` and write or refresh the task packet. Coder's review request moves the board to `In review`. Only the owner moves to `Done`.

## Per task

1. **Packet** (issue body, `docs/tasks/<id>.md`, or a PR in this repo): intent, why, constraints / do-not, acceptance, out of scope. Not a diary. User instruction this session is also a valid packet if the owner says so.
2. Discuss open UX questions in `docs/tasks/<id>.log.md`, tagged `(for Grok)` / `(for Claude)` / `(for Claude.bot)` / `(for Grok.bot)`. Quote the other agent when the wording is the contract. Consensus before implementation.
3. **coder** implements and runs the verify command in `AGENTS.md`. Rewrite `NOW.md` with a **review request**. Stop. Do not commit the product change yet.
4. **reviewer** reviews the working tree (code, security, privacy) and rewrites `NOW.md` with comments or a pass. Findings live in the log; `NOW.md` carries the briefing.
5. **coder** treats each comment as fix or dispute. Repeat 3–5 until `Review: pass` or contention (ask the owner).
6. New choice that must outlive the task: add `D-NNN-slug.md` and one index line. Repeating the same three laws in every stamp means they belong in `AGENTS.md` or a `D-NNN`, not in `NOW.md`.
7. After a pass (or the owner's contention ruling), coder commits. Commit messages cite issue / `D-NNN`. Working tree beats any note.

Most tasks produce **zero** new decision files.

## Coder–reviewer cycle

`NOW.md` `Review:` is `idle` | `requested` | `comments` | `disputed` | `pass` | `contention`.
`NOW.md` `Role next:` is `coder` | `reviewer` | `owner`.

### coder

Source of work, in order: this session's instruction, the Ready packet named in `NOW.md`, or the PR/branch the owner named.

1. Implement only that packet. Run the verify command in `AGENTS.md`.
2. Self-check is not a reviewer pass.
3. Rewrite `NOW.md` from scratch:
   - `Review: requested`
   - `Role next: reviewer`
   - **Review request:** scope (paths / PR / HEAD), what changed, how you verified
   - Drop comments you accepted and fixed (they can sit under Done as one line). Keep open disputes under **Coder response**
   - `Next: reviewer`
4. Stop. Do not commit the product change until `Review: pass` or the owner settles contention.
5. On `Review: comments`, take every item:
   - **Accept** — fix it, re-verify, then `Review: requested` again.
   - **Dispute** — one-line reason in **Coder response**; evidence and quotes in the task log. `Review: disputed`, `Role next: reviewer`.
6. Same items disputed twice with no new evidence → `Review: contention`, `Role next: The owner`, ask the owner. Do not loop.

### reviewer

1. If `Review` is not `requested` or `disputed`, say there is nothing to review and stop. Do not invent work.
2. Review the **working tree** (and the named PR/diff), not the write-up. Three gates, as a senior developer:
   - **Code** — correctness, tests, regressions, scope creep vs the packet
   - **Security** — authz, secrets, injection, unsafe defaults, dependency risk
   - **Privacy** — data collected, logs, third-party, user control
3. Brief items in `NOW.md` **Review comments** (one line each, tagged Code / Security / Privacy). Quotes and evidence in the task log only.
4. Rewrite `NOW.md` from scratch:
   - Clean on all three gates → `Review: pass`, `Role next: coder` (coder commits; the owner to Done)
   - Issues → `Review: comments`, `Role next: coder`
   - After **Coder response**: accept the argument (pass, or remaining comments) **or**, if you still disagree and neither side has new evidence, `Review: contention`, `Role next: The owner`, ask the owner
5. Do not implement the fix. Do not commit the product change. You may only rewrite `NOW.md` and append the task log.

### Contention

Either role asks the owner when `Review: contention`. Record the ruling in `NOW.md` (and `D-NNN` if it must outlive the task). Coder implements the ruling. That item is no longer a review dispute.

### Pass

Coder commits (cite issue / `D-NNN`). Rewrite `NOW.md` to idle or the next Ready item. Only the owner moves the board to Done.

## Decision file shape

```markdown
# D-NNN — {{one line}}
Date: YYYY-MM-DD
Status: accepted
Task: #N

Decision: …
Why: …
Rejected: …
Follow-on: …
```

## `NOW.md` shape

Always: Intent, Done, Open, Do not, Next, pointers (`HEAD`, packet path, log path), plus:

- `Role next:` who should act (`coder` | `reviewer` | `owner`)
- `Review:` `idle` | `requested` | `comments` | `disputed` | `pass` | `contention`
- `Reviewed:` the fingerprint a pass or comments were given for; only ever pasted from the reviewer's verdict

When `Review` is not `idle`, also include the blocks that exist:

- **Review request** (coder) — scope, what changed, verify
- **Review comments** (reviewer) — Code / Security / Privacy one-liners (status is the top-level `Review:` field, not repeated here)
- **Coder response** (coder, if disputing or listing what was fixed)

No quotes. One task (or two short sections). If it will not fit in 80 lines, extract a decision or archive the log. Omit empty review blocks when `Review: idle`.

## Session protocol

**Start** (every agent, including bots)

1. Be in this repo (`cd` here before launch).
2. Read `AGENTS.md` (auto) then `docs/NOW.md`.
3. Interactive sessions take **coder** or **reviewer**. If the user did not name one, ask and wait. Bots skip this step (see Roles above).
4. If `NOW.md` names a packet or `D-NNN`, read **that file only**.
5. `git status` and `git log -8 --oneline`.
6. Do not open archive, full logs, or `AGENT-NOTES.md`.

This file is not part of that briefing. Read it (once) the moment you are about to act on `NOW.md`'s Review state: writing a review request, doing the review, or resolving a dispute.

**End**

Rewrite `docs/NOW.md` from scratch. Checklist: intent, open, do-not, next, role next, review state, pointers; review request/comments/coder response if review is in flight; new durable choice? → `D-NNN`; quotes? → task log only; `AGENTS.md` unchanged unless the law changed.

Bots: same two files only — `AGENTS.md` + `docs/NOW.md`, never this file, never the coder/reviewer role. Bot prompt must say `AGENTS.md` + `docs/NOW.md`, not `AGENT-NOTES.md`. Bots still do not satisfy a reviewer pass.

## Launching a new instance

```bash
cd {{path to this repo}}
grok          # or: claude
```

Name the role in the first message so the agent does not have to ask:

```
You are the coder. Read docs/NOW.md. Then: {{the job in one sentence}}.
```

```
You are the reviewer. Read docs/NOW.md. Then: review the working tree.
```

If the first message omits the role, the agent asks and waits. Do not type “load the project” or “read AGENT-NOTES.” Do not `@` `NOW.md`’s history files. Resume the existing session when it is the same thread **and the same role**; a new instance is for a full window or the other role.

## Compaction

**Task close:** promote new law → `AGENTS.md`; surviving choice → `D-NNN`; rewrite `NOW.md` to idle or the next Ready item; drop the log from `NOW.md` (move to `docs/archive/` if you want it kept).

**Release:** `docs/releases/{{VERSION}}.md`; update the shipping line in `AGENTS.md`.

**Quarter:** mark superseded decisions; delete snapshot plans from `AGENTS.md` (they belong in a packet). Never re-merge archive into `NOW.md`.

## Existing-repo adoption

1. Copy `project/` onto the repo root (or run the kit’s `instantiate.sh`).
2. Fill `{{PLACEHOLDERS}}`. Move snapshot plans out of any old `AGENTS.md`.
3. Write `docs/NOW.md` from the **current** open task only.
4. `git mv docs/AGENT-NOTES.md docs/archive/AGENT-NOTES-{{YYYY}}-qN.md` (or equivalent).
5. Harvest repeated stamps (“do not recut”, “do not enable network”) into `AGENTS.md` or `D-NNN` files.
6. Point bots at `AGENTS.md` + `docs/NOW.md`. Interactive sessions take coder or reviewer.

Leave the archive in git. Do not summarise it into a new always-loaded file.
