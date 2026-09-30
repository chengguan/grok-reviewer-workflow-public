# Review costs

One row per Grok review round, appended by grok-review.sh when the round ends, plus one total row per review. Append-only.
Total tokens is the main unit: input (includes cached-read) + output. Calls = model calls. Turns = the reviewer's agent turns. Wall = elapsed time.
USD comes from Grok's costUsdTicks; "unreported" means no figure was returned, not zero. "shared" = a handed-off session, so an upper bound.
Rows marked "coder" meter the coding agent's own Claude Code transcript between checkpoints (tokens; "plan" = subscription, no per-token price).

| Date | Task | Session | Round | HEAD | Fingerprint | Verdict | Model/effort | Total tokens | Input | Cached | Output | Reasoning | Calls | Turns | Wall | USD |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
