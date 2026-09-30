# NOW

Updated: 2026-09-07 23:40 by Claude
Task: ExampleApp audit-fix · in review
Role next: reviewer
HEAD: 3dd6ebf
Review: disputed

Intent: Close the App Store audit-fix pass. Do not reopen Suggestion 1.

Done:
- High 1–2, Medium 1–4, Low 1–4, Bugs 1–3
- Zone-id strip: tests cover both named cases

Open:
- Reviewer re-check of zone-id vs RFC order
- Live Discover→pair on the test TV (the owner)

Do not:
- Force IPv6 on this TV
- Rewrite BUILD-PLAN MAC history
- Split ContentView in this pass

Coder response:
- Accepted: added the two named tests
- Disputed: strip-then-RFC is required so `inet_pton` sees a bare address; RFC check still runs on parsed bytes, not the stripped string

Next: reviewer
Packet: docs/tasks/audit-fix.md
Log: docs/tasks/audit-fix.log.md
