# NOW

Updated: 2026-09-07 22:14 by Claude
Task: ExampleApp audit-fix · in review
Role next: reviewer
HEAD: 3dd6ebf
Review: requested

Intent: Close the App Store audit-fix pass. Do not reopen Suggestion 1.

Done:
- High 1–2, Medium 1–4, Low 1–4, Bugs 1–3, zone-id strip + tests

Open:
- Reviewer pass on the zone-id change
- Terms/Privacy (BACKLOG) before submit — not this request
- App Store Connect product listing (the owner)

Do not:
- Force IPv6 on this TV
- Rewrite BUILD-PLAN MAC history
- Split ContentView in this pass

Review request:
- Scope: working tree; LANAddressPolicy.swift + tests
- What changed: strip `%zone` only before `inet_pton`; IPv4 path unchanged
- Verify: unit tests green (`fe80::1%en0` → true, `2001:4860:4860::8888%en0` → false)

Next: reviewer
Packet: docs/tasks/audit-fix.md
Log: docs/tasks/audit-fix.log.md
