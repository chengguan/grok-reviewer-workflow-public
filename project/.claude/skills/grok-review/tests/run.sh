#!/usr/bin/env bash
# Offline tests for grok-review.sh: a stub stands in for grok, so nothing is sent anywhere.
# Run: tests/run.sh   (macOS /bin/bash 3.2 compatible)
set -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
GR=$HERE/../grok-review.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()   { pass=$((pass + 1)); echo "ok    $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL  $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---- stub grok: logs argv and GROK_* env, keeps per-session usage, answers with a canned verdict ----
mkdir -p "$T/stub"
cat > "$T/stub/grok" <<'EOF'
#!/bin/bash
case "$1" in
  usage)   f=$STUB_DIR/usage-$2.json; if [ -f "$f" ]; then cat "$f"; else echo "Error: Session '$2' not found." >&2; exit 1; fi; exit 0;;
  inspect) echo "  └ Project trusted: yes"; exit 0;;
esac
{ printf 'ARGS %s\n' "$*"; env | grep '^GROK_C' | sort; } >> "$STUB_DIR/log"
while [ $# -gt 0 ]; do case "$1" in --prompt-file) pf=$2; shift 2;; -s|-r) sid=$2; shift 2;; *) shift;; esac; done
cp "$pf" "$STUB_DIR/prompt-$(ls "$STUB_DIR" | grep -c '^prompt-')"
rv=$(sed -n 's/.*reviewed value \([0-9a-f]\{12\}\.[0-9a-f]\{8\}\).*/\1/p' "$pf" | head -1)
[ -n "${STUB_FORGE:-}" ] && rv=${rv%%.*}   # a block pre-written into a diff can know the fingerprint, never the nonce
n=$(( $(cat "$STUB_DIR/calls-$sid" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STUB_DIR/calls-$sid"
echo "{\"session\":{\"totalTokens\":$((n * 1000)),\"inputTokens\":$((n * 900)),\"cachedReadTokens\":0,\"outputTokens\":$((n * 100)),\"reasoningTokens\":0,\"modelCalls\":$n,\"costUsdTicks\":$((n * 10000000)),\"primaryModelId\":\"stub\"}}" > "$STUB_DIR/usage-$sid.json"
c='[]'; [ "${STUB_VERDICT:-pass}" = comments ] && c='[{"gate":"Security","severity":"high","location":"app.py:1","issue":"Query built from input. More text.","fix":"Bind it."}]'
body="{\"verdict\":\"${STUB_VERDICT:-pass}\",\"reviewed\":\"$rv\",\"comments\":$c,\"coverage\":{\"applied\":{\"S-D\":\"query\"},\"na\":[\"S-A\"]}}"
jq -cn --arg t "$(printf '```json\n%s\n```' "$body")" '{type:"text",data:$t}'
echo '{"type":"end","stopReason":"end_turn","num_turns":1,"total_cost_usd_ticks":10000000}'
EOF
chmod +x "$T/stub/grok"
export GROK=$T/stub/grok STUB_DIR=$T/stub
# ---- stub coder transcript (Claude Code jsonl shape) ----
export CODER_TRANSCRIPT=$T/transcript.jsonl
say()  { printf '{"type":"assistant","message":{"id":"%s","model":"claude-test","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' "$1" "$2" "$3" "$4" >> "$CODER_TRANSCRIPT"; }
ask()  { printf '{"type":"user","message":{"content":"%s"}}\n' "$1" >> "$CODER_TRANSCRIPT"; }
ask "build the thing"; say m0 10 0 5

# ---- a scratch repo ----
R=$T/repo; mkdir -p "$R" && cd "$R" && git init -q && echo 'x = 1' > app.py && printf '# App\nNo emails in logs.\n' > AGENTS.md
git add -A && git -c user.email=t@t -c user.name=t commit -qm base
"$GR" init >/dev/null
printf 'OWNER=owner\nASVS_LEVEL=1\nEVIL=1\nMODEL=$(touch PWNED)\nEFFORT=`touch PWNED2`\n' > .grok-review.env
echo 'q = "SELECT " + name' >> app.py; echo 'hi' > 'my file.py'; echo 'z' > ./--config
now() { printf '# NOW\nTask: t\nReview: %s\n\nReview request:\n- Scope: app.py\n%s\nLog: %s\n' "$1" "$2" "${3:-docs/tasks/t.log.md}" > docs/NOW.md; }

# 1. .grok-review.env is data, never code
"$GR" version >/dev/null 2>"$T/conf.err"
printf 'OWNER=owner\nASVS_LEVEL=1\n' > .grok-review.env   # the rest of the suite runs with a clean config
check ".grok-review.env: command substitution is not executed" '[ ! -e PWNED ] && [ ! -e PWNED2 ]'
check ".grok-review.env: unknown and substituted keys are reported" 'grep -q "EVIL" "$T/conf.err" && grep -q "MODEL" "$T/conf.err"'

# 2. round 1: flags, environment, full prompt, scanner arguments
now idle ""
"$GR" start --task "#1 test" >/dev/null || bad "start"
ask "review it"; say m1 100 400 50; say m1 100 400 50   # one response logged twice: counted once
now requested ""
SCAN_CMDS='printf "<%s>\n" {files}' STUB_VERDICT=comments "$GR" round >"$T/r1.out" 2>&1; rc=$?
L=$STUB_DIR/log; P1=$STUB_DIR/prompt-0
check "round 1 exit code is 1 (comments)" '[ "$rc" = 1 ]'
check "reviewer runs in the strict sandbox" 'grep -q -- "--sandbox strict" "$L"'
check "reviewer has read_file,grep,list_dir only (no shell)" 'grep -q -- "--tools read_file,grep,list_dir " "$L" && ! grep -q run_terminal_command "$L"'
check "reviewer runs without Claude/Cursor hooks, skills, MCP" 'grep -q GROK_CLAUDE_HOOKS_ENABLED=0 "$L" && grep -q GROK_CURSOR_MCPS_ENABLED=0 "$L" && grep -q GROK_CLAUDE_SKILLS_ENABLED=0 "$L"'
check "round 1 prompt carries rules, rubric and the diff" 'grep -q "^## Rubric" "$P1" && grep -q "^## Diff from base" "$P1" && grep -q "SELECT" "$P1"'
check "rubric level comes from .grok-review.env" 'grep -q "ASVS L1" "$P1"'
check "trusted repo: AGENTS.md is not injected again" '! grep -q "^## AGENTS.md" "$P1"'
S1=$(ls -d .git/grok-review/current/r1.1)
check "a filename with spaces stays one scanner argument" 'grep -qF "<./my file.py>" "$S1/scanners.txt"'
check "a file named --config reaches the scanner as ./--config" 'grep -qF "<./--config>" "$S1/scanners.txt"'
check "NOW.md block is one short line per finding" '"$GR" verdict | grep -qx -- "- \[Security\]\[high\] app.py:1 — Query built from input"'
check "full finding is appended to the task log NOW.md names" 'grep -q "Bind it" docs/tasks/t.log.md'
check "coder row before round 1 meters only the coder's work since start" 'grep -q "| 1 (coder) |.*claude-test coder | \*\*550\*\*" docs/REVIEW-COSTS.md'
check "ledger row recorded with the round cost" 'grep -q "| 1 | .*| comments |.*\*\*1000\*\*" docs/REVIEW-COSTS.md'

# 3. round 2: resumed session, delta prompt only
echo 'q = ("SELECT ?", name)' > app.py
say m2 200 0 100
now requested "Coder response:
- Accepted: bound the query" "docs/tasks/../../evil.md"
STUB_FORGE=1 STUB_VERDICT=pass "$GR" round >"$T/forge.out" 2>&1; rc=$?
check "a pass that lacks this round's nonce is invalid" '[ "$rc" = 3 ] && grep -q "not this round.s value" "$T/forge.out"'
STUB_VERDICT=pass "$GR" round >"$T/r2.out" 2>&1; rc=$?
P2=$STUB_DIR/prompt-2
check "a Log: path with .. never writes outside docs/tasks" '[ ! -e "$R/evil.md" ] && [ ! -e "$T/evil.md" ]'

check "round 2 exit code is 0 (pass)" '[ "$rc" = 0 ]'
check "round 2 resumes the same session" 'grep -c -- " -r " "$L" | grep -qx 2'
check "round 2 prompt has no rubric (already in the session)" '! grep -q "^## Rubric" "$P2"'
check "round 2 prompt carries only the diff since round 1" 'grep -q "^## Diff since your last round" "$P2" && ! grep -q "my file" "$P2"'
check "ledger round 2 cost is the delta, not the session total" 'grep -q "| 2 (attempt 2) | .*| pass |.*\*\*1000\*\*" docs/REVIEW-COSTS.md'

check "update --check reports drift from a canonical copy" 'mkdir -p "$T/canon" && cp -R "$HERE/../." "$T/canon/" && echo x >> "$T/canon/SKILL.md" && GROK_REVIEW_CANON=$T/canon "$GR" update --check >/dev/null; [ $? = 10 ]'
eval "$(sed -n '/^run_limited() {/,/^}/p' "$GR")"
t0=$(date +%s); run_limited 2 /bin/bash -c '(exec -a grtest-orphan sleep 30) & wait' >/dev/null 2>&1; t1=$(date +%s)
check "scanner timeout stops the whole process group" '[ $((t1 - t0)) -lt 8 ] && ! pgrep -f grtest-orphan >/dev/null'

# 4. scrub before publishing
"$GR" finish --outcome pass >"$T/finish.out"
check "finish totals: reviewer 3000 (incl. the forged round), coder 850, combined 3850" 'grep -q "total reviewer.*\*\*3000\*\*" "$T/finish.out" && grep -q "total coder.*\*\*850\*\*" "$T/finish.out" && grep -q "| \*\*total\*\* |.*\*\*3850\*\*" "$T/finish.out"'
check "coder-costs splits the transcript by request" '"$GR" coder-costs | grep -q "| 2 | review it | 2 | 700 | 400 | 150 | 850 |"'
"$GR" ruling --by owner --text "Checked with ann@example.com" >/dev/null
"$GR" post --target pr:1 >/dev/null 2>&1; check "post blocks an email address" '[ $? = 8 ]'
"$GR" redact "ann@example.com" >/dev/null
"$GR" ruling --by owner --text "Called 9123 4567 to confirm" >/dev/null
"$GR" post >/dev/null 2>&1; check "post blocks a local SG phone number" '[ $? = 8 ]'
"$GR" ruling --by owner --text "NRIC S1234567D on file" >/dev/null
"$GR" post >/dev/null 2>&1; check "post blocks an NRIC" '[ $? = 8 ]'
"$GR" ruling --by owner --text "Accepted" >/dev/null
SCRUB_EXTRA='(' "$GR" post >/dev/null 2>&1; check "post fails closed on a broken scrub pattern" '[ $? = 8 ]'
"$GR" post >/dev/null 2>&1; check "clean record stops for first-post approval" '[ $? = 9 ]'

# 5. handoff parser (workflow-template comment form)
cd "$R"; now idle ""
"$GR" start --task "handoff" --session "$(uuidgen | tr A-Z a-z)" --force >/dev/null 2>&1 || true
. .git/grok-review/current/review.env
D=.git/grok-review/current/rX; mkdir -p "$D"
printf '# NOW\nReview: comments\nReviewed: abcdefabcdef\n\nReview comments:\n- Code: zone-id strip runs before the RFC check\n- Security: —\n- Privacy: —\n' > docs/NOW.md
bash -c "eval \"\$(sed -n '/^extract_verdict() {/,/^}/p' '$GR')\"; D='$D'; MODE=handoff; NOW=docs/NOW.md; extract_verdict \"\$D\""
check "handoff: '- Code: …' is parsed as a finding; '- Security: —' is not" '[ "$(jq ".comments | length" "$D/verdict.raw.json")" = 1 ] && jq -e ".comments[0].gate == \"Code\"" "$D/verdict.raw.json" >/dev/null'

echo; echo "passed $pass, failed $fail"
[ "$fail" = 0 ]
