# Self-review: this repository, reviewed by its own tool

Before publication, the whole repository (base: empty tree) went through grok-review at ASVS L2, effort high, with extra checks for desensitisation, claims in the docs, and safety of adoption. Round 1 raised two medium findings and three notes; all were accepted and fixed. Round 2 passed with no findings. The record below is the one the tool produces (`grok-review.sh record`), after its publish scrub.

Coder rows meter the coding agent's whole session between checkpoints, so they are an upper bound.

## Grok review — Pre-publication review of the public repo · pass

Reviewer: Grok Build `grok-4.7-build/high` · rubric ASVS L2 · session `e0323935-947a-4a39-93ce-81a4f3bec234` · base `empty` (4b825dc6) · scope `.`

### Round 1 · comments · 3 notes
Reviewed `7f583a475011` on `6f0a59a` · 481584 tokens · 10m40s
Triage: D, E, F, G, J, L, X

**Reviewer findings**
- **medium** [Security] `project/.claude/skills/grok-review/grok-review.sh:79` — setv eval re-expands task, paths, session and target, so shell metacharacters in those arguments execute. _Fix:_ Assign with printf -v, never eval. · ASVS V1 / CWE-78
- **medium** [Security] `project/.claude/skills/grok-review/grok-review.sh:397` — A severity outside critical, high and medium does not block, and comments then becomes pass. _Fix:_ Treat every severity but low and info as blocking. · ASVS V2 / CWE-636
- **low** [Security] `.github/workflows/test.yml:9` — actions/checkout uses a movable v4 tag, so a retargeted release runs in CI. _Fix:_ Pin checkout to a full commit SHA. · ASVS V13 / CWE-829
- **low** [Privacy] `project/.claude/skills/grok-review/grok-review.sh:91` — If this repo has no transcript, start meters the newest Claude session from any project. _Fix:_ Skip metering when this repo has no transcript. · ASVS V14
- **info** [Code] `README.md:40` — README says 32 offline tests; tests/run.sh defines 35 checks. _Fix:_ State 35 offline tests. · ASVS V15

<details><summary>Coverage</summary>

- S-D: applied — Checked paths, scanner arguments, config parser, diff fences.
- S-E: applied — Checked nonce source, scrub list, committed files.
- S-F: applied — Checked publish scrub, samples, transcript fallback.
- S-G: applied — Checked gh approval, round timeout, scanner egress.
- S-J: applied — Checked workflow permissions and action pinning.
- S-L: applied — Checked sandbox, tools, nonce, untrusted diff framing.
- S-X: applied — Checked claims, tests, failures, and kit scope.
- n/a: S-A, S-B, S-C, S-H, S-I, S-K, S-M

</details>

**Coder response** (round 2 request)
- Accepted [Medium, setv eval]: setv assigns with printf -v, never eval; values were already stored with printf %q, and a new test proves a task name with $(…) and backticks stays inert through start, load and status.
- Accepted [Medium, unknown severity]: blocking_count treats every severity except low and info as blocking, after lowercasing and trimming; unknown or missing severities block (new test).
- Accepted [Low, CI checkout]: pinned to the v7.0.1 commit SHA.
- Accepted [Low, transcript fallback]: without CODER_TRANSCRIPT or this repo's own transcript, coder cost is not metered; another project's session is never read.
- Accepted [Info, README count]: README states 37 offline tests, the number the suite runs.
- Also: the too-large-diff stat now sits inside the nonce-tagged delimiters (a low note from the private review).

### Round 2 · pass
Reviewed `018836eb0a09` on `654bfe4` · 359965 tokens · 2m42s
Triage: D, F, J, L, X

**Reviewer findings:** none

<details><summary>Coverage</summary>

- S-D: applied — Checked setv assignment and severity blocking.
- S-F: applied — Checked transcript fallback no longer crosses projects.
- S-J: applied — Checked checkout is pinned to a commit SHA.
- S-L: applied — Checked large-diff stat stays inside delimiters.
- S-X: applied — Checked new tests and the README count.
- n/a: S-A, S-B, S-C, S-E, S-G, S-H, S-I, S-K, S-M

</details>

### Cost
| Round | Verdict | Total tokens | Calls | Turns | Wall | USD |
|---|---|---|---|---|---|---|
| 1 (coder) | coder: work before round 1 | **456089** | 1 | — | 0m8s | plan |
| 1 | comments · 3 notes | **481584** | 6 | 6 | 10m40s | 0.2533 |
| 2 (coder) | coder: work before round 2 | **3696937** | 8 | — | 12m19s | plan |
| 2 | pass | **359965** | 3 | 3 | 2m42s | 0.1485 |
| end (coder) | coder: wrap-up | **1413692** | 3 | — | 3m2s | plan |
| **total reviewer** | pass | **841549** | 9 | 9 | 13m22s | 0.4018 |
| **total coder** | pass | **5566718** | 12 | — | | plan |
| **total** | pass | **6408267** | | | | 0.4018 + plan |
