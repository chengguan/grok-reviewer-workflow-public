# How to start work

For you (the owner). Agents follow `AGENTS.md` + `docs/NOW.md` in the product repo, then take **coder** or **reviewer**. Do not paste this file into a prompt.

## 1. New project

```bash
mkdir -p ~/src/{{name}}
~/src/grok-reviewer-workflow-public/instantiate.sh ~/src/{{name}}
cd ~/src/{{name}}
```

Fill `{{PLACEHOLDERS}}` in `AGENTS.md` (one-line product, layout, hard rules, verify command) and leave `docs/NOW.md` idle until there is a first task. Leave `docs/WORKFLOW.md` unless the coder/reviewer cycle itself differs.

```bash
git init
git add AGENTS.md docs
git commit -m "Add agent workflow (NOW.md briefing, archived history)."
```

Then start the first task below. Spec (`docs/SCOPE.md` or equivalent) is a packet, not `AGENTS.md`.

## 2. Feature, bug, or task in an existing project

Same sequence every time. The only difference is the packet.

| Kind | Packet | Extra |
|---|---|---|
| Feature | GitHub issue (Ready), or `docs/tasks/<id>.md` | `Ready` → `In progress` on pickup; `In review` on the review request |
| Bug | GitHub issue labeled `bug` | Brief it in chat first; do not let an agent open a bug issue on its own |
| Small leftover | `docs/BACKLOG.md` one-liner, or a 20-line `docs/tasks/<id>.md` | Skip a board if the project does not have one |

Then:

1. **Rewrite `docs/NOW.md`** (or tell the agent to, as the first act). Intent, Open, Do not, Next, Role next, Review, pointer to the packet. Overwrite, do not append.
2. **Launch inside the repo**, not from `$HOME`:

```bash
cd ~/src/{{name}}    # your-app
grok                      # or claude
```

3. **First message** — name the role, then the job. Not “load the project”:

```
You are the coder. Read docs/NOW.md. Then: {{one sentence}}.
```

```
You are the reviewer. Read docs/NOW.md. Then: review the working tree.
```

If you omit the role, the agent asks (coder or reviewer) and waits. Examples:

```
You are the coder. Read docs/NOW.md. Then: pick up issue #21 (Ready) and discuss the open UX questions before coding.
```

```
You are the coder. Read docs/NOW.md. Then: implement the Terms/Privacy pages from docs/BACKLOG.md. Do not reopen the audit-fix.
```

```
You are the reviewer. Read docs/NOW.md. Then: review the working tree for the review request.
```

Coder leaves a review request in `NOW.md` and stops (no product commit yet). For a headless, costed review instead of a second interactive session, the coder follows `.claude/skills/grok-review/SKILL.md`. Reviewer watches `NOW.md`, writes comments or a pass, and does not implement. Coder fixes or disputes. Repeat until a pass, or until contention — then you decide.

Resume the existing session if it is the same thread **and the same role**. A new instance is for a full context window or the other role.

## 3. What not to do

- Do not launch from `~` and say “load ExampleApp.”
- Do not `@` `AGENT-NOTES`, `BUILD-PLAN`, or the archive.
- Do not type “get familiar with the repo.”
- Do not start work that is still `Backlog`. Ready is the gate.
- Do not put the diary in `NOW.md`. Quotes and evidence go in `docs/tasks/<id>.log.md`.
- Do not let a bot session count as the reviewer pass.
- Do not have the reviewer implement the fix, or the coder commit before `Review: pass` (or your contention ruling).

## 4. When the task ends

The coder commits only after `Review: pass` (or your contention ruling). The agent rewrites `NOW.md` (idle, or the next Ready item). A choice that must outlive the task becomes one `docs/decisions/D-NNN-slug.md` plus one index line. You move the board to Done.

Filled samples: `examples/` in this kit. In-repo protocol: `docs/WORKFLOW.md`.
