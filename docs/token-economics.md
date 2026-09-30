# Token economics for coding agents

A token is the unit of read, write and bill. At roughly 4 characters per token, everything in the window counts: rules, files, chat, tool schemas and skill listings. Every turn re-sends the input.

## Three bills

- **Money:** input, output, cache and tools.
- **Window:** always-on text crowds out the files the task needs.
- **Quality:** attention isn't uniform, so closed work competes with the open constraint.

## Inject a briefing, retrieve a history

| | Injected | Retrieved |
|---|---|---|
| When | Loaded before there is a job | Opened because this job collides with it |
| Examples | Product law, the current briefing, tool schemas | One decision file, one task packet, one source file |
| Cost | Paid whether needed or not | Paid once, for a reason |

**Measured case: two iOS repos, one append-only notes file each** (always-on tokens ≈ bytes ÷ 4):

| Always-on file | Tokens |
|---|---|
| Repo A notes file (4,373 lines) | ~90,800 |
| Repo A `AGENTS.md` + `NOW.md` | ~920 |
| Repo B notes file (785 lines) | ~21,700 |
| Repo B `AGENTS.md` + `NOW.md` | ~990 |

The mistake was injecting history, not taking notes. A new agent needs the **constitution** (law) and the **live handoff** (now), not the **memoir** (closed review chat). Git already keeps the memoir.

## Rules that survive a multi-year repo

- 80–120 lines of law, 40–80 lines of now, under ~3,000 always-on tokens.
- One home per fact: law, now, decision, packet, log, and what landed (git).
- **Resume** for the same thread and role. Start a **new instance** for a full window or the other role. A **child** returns a summary, not its transcript.
- Hidden taxes:
  - duplicate instruction files;
  - tool and MCP schemas you don't use;
  - "load the project" prompts;
  - launching from `$HOME`;
  - pasting reviews into law.

## Applied to review (grok-review)

- Each reviewer call has a ~15k-token floor, so round trips dominate. The reviewer gets the request and diff in **one** call, with the stable rules and rubric first (cache-friendly).
- Later rounds resume the session and get only the diff since the last round.
- Nothing is sent that the harness already loads (`AGENTS.md`).
- The reviewer has no shell, and no skills, hooks or MCP servers, so there's no schema tax and a smaller attack surface.
