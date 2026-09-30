# Case study: building grok-review with two agents

One working session: Claude Code as the coder, Grok Build as the reviewer. Measured from the Claude Code transcript and `grok usage`, without estimates.

## Totals

| Agent | Calls | Tokens | of which cached reads |
|---|---|---|---|
| Coder (Claude, design + build + tests) | 115 | 26.0M | 98.7% |
| Reviewer (Grok, probes + tests + two real reviews) | 49 | 1.8M | — |

## Same review, two designs

| Review | Before | After | Change |
|---|---|---|---|
| Scratch repo, effort low, round 1 | 80k tokens · 4 calls | 13k tokens · 1 call | −84% |
| Scratch repo, effort low, round 2 | 100k tokens · 4 calls | 14k tokens · 1 call | −86% |
| Real repo, effort high, round 1 | 889k tokens · 14 calls · $0.30 | 270k tokens · 4 calls · $0.18 | −70% |

**Before:** the reviewer read files, listed folders and grepped. **After:** the diff and rubric are injected up front, and later rounds resume the session and get only the delta.

## What the reviewer caught in its own tool

- **High:** the "read-only" reviewer inherited the project's agent allow rules (deploy and cloud CLI commands). Fixed by removing the shell tool and running under `--sandbox strict`.
- **Medium:** the settings file was executed as shell. It's now parsed as allowlisted data.
- **Medium:** the pre-publish scrub was incomplete and failed open. It now fails closed.
- **Medium:** filenames reached scanners through a bash 5.2 replacement quirk. They now arrive as positional args.
- **Medium:** a crafted diff could forge a passing verdict. A per-round nonce now makes pre-written verdicts invalid.
- **Medium:** a `Log:` path could escape `docs/tasks`, and findings reached the task log unscrubbed.

## Lessons

1. **The coder, not the reviewer, becomes the cost centre.** A long coder session re-reads its whole context on every call. Start a fresh coder session per task, from the briefing.
2. **Round trips, not rubric size, drive reviewer cost.** Inject what the job collides with; retrieve the rest.
3. **Check what a "read-only" agent can actually reach.** Harness compatibility layers can import permissions from other tools.
4. **Cost every round, including failures,** or you optimise the wrong thing.
