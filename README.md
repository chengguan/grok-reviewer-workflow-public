# grok-reviewer-workflow-public

A multi-agent coding workflow that keeps agents cheap and honest, plus a costed security review loop:

- **Workflow kit (`project/`).** A thin always-loaded briefing (`AGENTS.md` + `docs/NOW.md`), with the history retrieved from git rather than injected into every prompt. There's a coder/reviewer cycle: request → comments → fix or dispute → pass, or contention that the owner rules on.
- **grok-review (`project/.claude/skills/grok-review/`).** The coder (e.g. Claude Code) runs Grok Build as a headless, sandboxed, read-only reviewer. It scores the change against an OWASP ASVS L2 / privacy / hygiene rubric and loops until a clean pass or contention.
  - Every round's cost goes to a ledger, **coder and reviewer both**.
  - The round-by-round record can be posted to the PR as evidence.
- **coder-workflow (`project/.claude/skills/coder-workflow/`).** Keeps the coder's own session cheap: context-size checks, a hand-off checklist when a session gets heavy, and per-task cost. `coder.sh task start|resume|pause|done` tracks one session segment at a time in `.git/coder-workflow/` (never committed); `task report` adds the task's grok-review rounds on top, so `docs/tasks/<id>.cost.md` is the whole task's cost, coder and reviewer, with nothing double-counted.

Why it exists, with measurements: [docs/token-economics.md](docs/token-economics.md) and [docs/case-study.md](docs/case-study.md).

The whole workflow on one page: [docs/grok-review-workflow.drawio](docs/grok-review-workflow.drawio) (open in draw.io or app.diagrams.net). This repository's own review before publication, round by round with its cost: [docs/self-review.md](docs/self-review.md).

## Quick start

```bash
git clone https://github.com/chengguan/grok-reviewer-workflow-public.git ~/src/grok-reviewer-workflow-public
~/src/grok-reviewer-workflow-public/instantiate.sh ~/src/my-app        # copies project/ into your repo (skips existing files)
cd ~/src/my-app && .claude/skills/grok-review/grok-review.sh init
```

Fill the `{{PLACEHOLDERS}}` in `AGENTS.md`. Then follow [HOWTO.md](HOWTO.md) for day-to-day work, and [SKILL.md](project/.claude/skills/grok-review/SKILL.md) for a review.

**Requirements:** `git`, `jq`, `perl`, `uuidgen`; [Grok Build](https://x.ai) (`grok`, logged in) for the reviewer; `gh` to post records. Optional: `gitleaks`, `semgrep`, `osv-scanner`.

## Layout

```
AGENTS.md, HOWTO.md, instantiate.sh     the kit itself
project/                                copy this onto a repo root
  AGENTS.md                             durable law + load protocol
  docs/NOW.md, WORKFLOW.md, DECISIONS.md, REVIEW-COSTS.md
  .claude/skills/grok-review/           SKILL.md, CHECKLIST.md (rubric), grok-review.sh, tests/run.sh
  .claude/skills/coder-workflow/        SKILL.md, coder.sh, tests/run.sh
examples/                               density samples; do not copy into a repo
docs/                                   the reasoning and the numbers
```

## Status and coupling

- **Reviewer:** Grok-specific. It relies on Grok Build's headless flags, `--sandbox strict` and `grok usage`.
- **Coder metering:** reads Claude Code transcripts. Both could sit behind adapters, but contributions are welcome.
- **Tested:** `tests/run.sh` has 37 offline tests with a stub `grok`. They pass on macOS `/bin/bash` 3.2. CI also runs them on bash 5.
- **Linux:** not yet verified.
- **Rubric:** the privacy section includes a Singapore (PDPA/NRIC) overlay. Swap in your own jurisdiction.

MIT licensed.
