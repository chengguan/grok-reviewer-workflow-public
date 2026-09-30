# Secure code review rubric

The reviewer reads this on every round. Standards: OWASP ASVS 5.0 at Level 2 (default), CWE, OWASP MASVS v2, OWASP Top 10 Privacy Risks, LINDDUN, Singapore PDPA (regional overlay: swap in GDPR, CCPA or your own), OWASP Top 10 for LLM Applications 2025, NIST SSDF (SP 800-218), and Google's code review guide for hygiene.

## How to use it

1. **Triage.** Match the changed files and the diff against the areas below. List every area that applies in `triage`. `X` always applies.
2. **Apply.** Work through each triggered section. Only flag what this change introduces, touches, or makes reachable. Don't audit untouched code, but do flag it when the change newly depends on it or exposes it.
3. **Rate** each finding with the severity scale below.
4. **Cite** a standard in `standard`. Use ASVS **chapter** ids only (e.g. `ASVS V6`), never requirement numbers from memory. Add a CWE id when you are sure of it (e.g. `CWE-89`).
5. **Report coverage.** Every triggered section gets `applied` with a short note on what you checked. Every section you skipped gets `n/a` with a reason. The coverage list is what makes a pass evidence.

## Severity

| Severity | Meaning | Blocks a pass? |
|---|---|---|
| critical | Exploitable without special access: auth bypass, remote code or command execution, SQL injection, secret or bulk personal-data exposure | yes |
| high | Exploitable by an authenticated or partly privileged user, personal data reaching an unintended party, integrity loss, a missing L2 control on sign-in, sessions or access control | yes |
| medium | A weakened defense, a missing L2 control elsewhere, a reachable bug that corrupts data or crashes, security-relevant behavior changed without a test | yes |
| low | Hardening and defense in depth, an unlikely edge-case bug, maintainability that raises future risk | no, recorded as a note |
| info | Style, naming, suggestions | no, recorded as a note |

Don't rate a finding critical or high at `low` confidence. Rate it medium and say what would confirm it.

## Triage areas

| Id | Triggered when the change touches… |
|---|---|
| A | Authentication: sign-in/up, passwords, OTP and verification codes, account recovery, MFA, reviewer or test bypasses |
| B | Sessions and tokens: JWT, refresh tokens, cookies, logout, token storage |
| C | Access control: ownership checks, roles, admin paths, multi-tenant data, object ids in requests |
| D | Untrusted input: parsing, SQL/NoSQL, shell, templates/HTML, file paths, URL fetching, deserialization, regex |
| E | Crypto and secrets: hashing, encryption, randomness, keys, Keychain/Keystore, secret or env config |
| F | Personal data: collecting, storing, logging, analytics/telemetry, export, deletion, sharing with third parties |
| G | APIs: endpoints, webhooks, CORS, rate limits, error responses, outbound calls to third parties |
| H | Files: upload, download, generated documents, temp files |
| I | Dependencies: new or upgraded packages, lockfiles, SDKs, build scripts |
| J | Infrastructure: CI/CD, IaC (CDK/Terraform), IAM, cloud config, containers, Lambda env |
| K | Mobile app code (iOS/Android) |
| L | LLM or agent integration |
| M | Browser frontend |
| X | Always: hygiene, error handling and logging, tests, project laws |

## Sections

### S-A Authentication — ASVS V6, MASVS-AUTH, CWE-287/307/640
- OTP and codes: generated with a CSPRNG, short expiry, single use, bound to the right identity and purpose, compared in constant time.
- Attempt limits and anti-automation per account **and** per source. Cover verification attempts *and* code sending (SMS/WhatsApp pumping, cost abuse).
- No account enumeration. Registered and unregistered identities must look the same in responses, timing, error text and side effects.
- Bypass or test paths (reviewer accounts, stub mode) are off by default in production, not controllable by the client, and never keyed on a secret stored in plain config.
- Recovery and credential change require re-authentication and invalidate existing sessions.

### S-B Sessions and tokens — ASVS V7, V9
- Tokens are validated for signature, algorithm, issuer, audience and expiry. No `none` algorithm, no unverified decode.
- Refresh tokens rotate and can be revoked. Logout and credential change invalidate the session server-side.
- Tokens are stored only in secure storage (Keychain, httpOnly/Secure/SameSite cookies). Never in logs, URLs or analytics.

### S-C Access control — ASVS V8, CWE-862/863/639
- Every object access checks ownership or tenancy on the server. Watch for IDOR: ids from the client are never trusted on their own.
- Deny by default. New endpoints and handlers carry an explicit authorization check.
- Admin and internal paths can't be reached with a normal user's credentials.

### S-D Untrusted input — ASVS V1, V2, CWE-20/22/78/79/89/502/918/1333
- Queries are parameterized. No string-built SQL, NoSQL, shell or LDAP commands.
- Output is encoded for its context (HTML, attribute, JS, URL). Templates auto-escape.
- File paths are canonicalized and confined to a base directory.
- URL fetches allowlist hosts or schemes, and block internal and metadata addresses (SSRF).
- No unsafe deserialization of untrusted data. Regexes can't catastrophically backtrack.
- Business logic rejects replays, skipped steps and out-of-range values (ASVS V2).

### S-E Crypto and secrets — ASVS V11, V12, V13, MASVS-CRYPTO, CWE-327/330/798
- Standard libraries and current algorithms only (AES-GCM, SHA-256+, bcrypt/scrypt/Argon2 for passwords). No homemade crypto, no static IVs.
- Security-relevant randomness comes from a CSPRNG.
- No secrets in code, tests, fixtures, docs or committed config. They live in a secret manager, Keychain or Keystore.
- TLS is always on. Certificate validation is never disabled, ATS exceptions are justified.
- Secrets at rest (OTPs, tokens, keys) are hashed or encrypted where the design allows, e.g. no plaintext OTP stored in a database.

### S-F Personal data — ASVS V14, OWASP Top 10 Privacy Risks, LINDDUN, PDPA
Start with the data delta: which personal data is **newly** collected, stored, logged, retained or sent, where it goes, and why. Then check:
- **Minimization and purpose (PDPA Purpose Limitation):** only what the feature needs, used only for the stated purpose.
- **Consent and notice (PDPA Consent/Notification):** new collection or a new use is covered by what users were told.
- **Logging and telemetry:** no phone numbers, emails, codes, tokens, precise location or free text in logs, crash reports or analytics. Watch printed rows and objects.
- **Third parties (PDPA Transfer Limitation):** new SDKs or APIs receiving personal data are necessary. Check what they get and where it's stored.
- **Retention and deletion (PDPA Retention Limitation):** new data has a lifetime, and account deletion removes it.
- **Protection (PDPA Protection):** sensitive fields are encrypted at rest where appropriate, with access limited.
- **LINDDUN:** can the change link or identify people, or **detect** whether someone is a user (membership oracles)? Does it disclose data or leave users unaware?
- **User control:** access, correction and deletion still work for the new data.

### S-G APIs and outbound calls — ASVS V4, V16
- Rate limits and size limits on new endpoints. Webhooks verify signatures and reject replays.
- CORS is not `*` with credentials.
- Errors are generic to clients, detailed only in server logs, and never leak stack traces or internal ids.
- Outbound calls to third parties have timeouts. Failures don't fail open, and don't leak which branch was taken (see S-A enumeration).

### S-H Files — ASVS V5, CWE-434
- Validate type and size. Store uploads outside web roots with generated names. Scan or quarantine where needed.
- Downloads check authorization per file. Temp files are created securely and cleaned up.

### S-I Dependencies — NIST SSDF PW.4, CWE-1104, OWASP LLM03 when relevant
- Each new dependency is justified, maintained, license-compatible and pinned. The lockfile is updated.
- No known-vulnerable versions. Check scanner output where given.
- No install scripts or post-install hooks from untrusted packages. No dependency confusion (scoped or private names).

### S-J Infrastructure and CI — ASVS V13, NIST SSDF
- IAM is least privilege. No `*` actions or resources without justification.
- Secrets come from a secret store, not plain env vars or IaC literals. Nothing is public by default (buckets, tables, functions).
- CI: minimal workflow permissions, pinned actions, no secrets exposed to PRs from forks, no untrusted input in `run:` lines.
- Security-relevant settings (encryption, logging, deletion protection) aren't weakened.

### S-K Mobile — MASVS v2 (STORAGE, CRYPTO, AUTH, NETWORK, PLATFORM, CODE, PRIVACY)
- Sensitive data only in Keychain/Keystore with an appropriate accessibility class. Nothing sensitive in UserDefaults, plist, logs, screenshots or the pasteboard.
- ATS/TLS intact. Deep links and URL schemes validate input and don't trigger sensitive actions unprompted.
- `os.Logger` uses privacy annotations: personal values are `.private`.
- Entitlements and permissions (location, contacts, camera) are the minimum, and the purpose strings are accurate. The privacy manifest is updated for new data or APIs.

### S-L LLM integration — OWASP Top 10 for LLM Applications 2025
- Prompt injection (LLM01): untrusted content is never trusted as instructions. Tool or agent permissions are minimal (LLM06 Excessive Agency).
- Model output is treated as untrusted input before use in queries, HTML, shell or code (LLM05).
- No secrets or personal data in prompts or system prompts unless required (LLM02, LLM07). Cost and size limits are in place (LLM10).

### S-M Browser frontend — ASVS V3, CWE-79/352
- No `innerHTML` or `dangerouslySetInnerHTML` with untrusted data. A CSP where the app supports one.
- CSRF protection on state-changing requests with cookie auth. No tokens or personal data in localStorage.

### S-X Always — Google eng-practices, ASVS V15, V16
- **Correctness:** does it do what the request says? Check edge cases (empty, null, large, concurrent, retry) and error paths.
- **Tests:** changed behavior is tested, security-relevant behavior especially (limits, authorization denials, failure branches). Tests would actually fail if the code broke.
- **Error handling:** no swallowed errors that fail open, and no silent partial success.
- **Logging:** failures are diagnosable without logging secrets or personal data (ASVS V16).
- **Design and complexity:** the simplest design that works, no dead code, no speculative abstractions.
- **Scope:** changes stay inside the request. Flag scope creep.
- **Naming, comments, docs:** clear names, and comments that explain *why*. Docs are updated where behavior changed.
- **Resources and concurrency:** handles, connections and tasks are released. No races on shared state.
- **Project laws:** the rules in AGENTS.md / CLAUDE.md and accepted decisions (`D-NNN`) hold. Cite them as `standard: "Project D-NNN"` or `"Project AGENTS.md"`.
