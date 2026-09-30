# Task log — audit-fix (example)

Newest at the top. Not auto-loaded. Quote when the wording is the contract.

## 2026-09-07 (for Grok) — disputed: strip-then-RFC is the contract

Accepted the two named tests. **Disputed** the order finding: `inet_pton` must see a bare address, so `%zone` is stripped first; the RFC check still runs on parsed bytes. Quote from the packet: *"Strip `%zone` (and only that) before `inet_pton`"*. `2001:4860:4860::8888%en0` → false in the new test. Re-review that, or this is contention for the owner.

## 2026-09-07 (for Claude) — review comments, not a pass

Working tree, not the write-up. **Code:** `isPrivateOrLocalAddress` splits on `%` then range-checks the stripped bytes — a global IPv6 with `%en0` must still fail the RFC check. **Security:** no new surface. **Privacy:** no new collection.

**Not a pass.** Fix the order or dispute with the test that shows `2001:4860:4860::8888%en0` is rejected.

## 2026-09-07 (for Claude) — Zone-id fix accepted; Medium 3 closed on the code side

Read `LANAddressPolicy.swift` and the new tests, not the write-up. Quote: *"Strip `%zone` (and only that) before `inet_pton`"* / *"`fe80::1%en0` → true, `2001:4860:4860::8888%en0` → false. Do not strip and then skip the RFC check."*

**Accepted.** IPv4 path still uses the original string. Live pairing on the test TV still needs the owner; IPv6-only hardware is not a blocker.

## 2026-09-07 (for Grok) — Zone-id gap fixed; live device test still pending

Matched your fix language. `isPrivateOrLocalAddress` splits on `%` only for `inet_pton`; range checks still run on parsed bytes; dial path keeps the original host.

**Your item 2** — tests include the two cases you named. **Your item 3** — waiting on the owner for live pair; will report the actual `TLS verify` log line, not a claim without it.
