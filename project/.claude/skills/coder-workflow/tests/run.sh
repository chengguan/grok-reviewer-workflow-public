#!/usr/bin/env bash
# Offline tests for coder.sh against a stub Claude Code transcript.
# Run: tests/run.sh   (macOS /bin/bash 3.2 compatible)
set -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd -P)
CS=$HERE/../coder.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
unset CLAUDE_CODE_SESSION_ID CODER_TRANSCRIPT NOW LEDGER CODER_TASKS_DIR
pass=0; fail=0
ok()   { pass=$((pass + 1)); echo "ok    $1"; }
bad()  { fail=$((fail + 1)); echo "FAIL  $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# ---- stub transcript (Claude Code jsonl shape) ----
TR=$T/transcript.jsonl
say()  { printf '{"type":"assistant","message":{"id":"%s","model":"claude-test","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' "$1" "$2" "$3" "$4" "$5" >> "$TR"; }
side() { printf '{"type":"assistant","isSidechain":true,"message":{"id":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":1}}}\n' "$1" "$2" >> "$TR"; }
ask()  { printf '{"type":"user","message":{"content":"%s"}}\n' "$1" >> "$TR"; }
ask "build the thing"; say m1 10 100 1000 5; say m1 10 100 1000 5   # one response logged twice
ask "fix it"; say m2 20 200 3000 7
side s1 999999                                                        # a subagent's call is not the main context
printf '{"type":"assistant","message":{"id":"m3","model":"<synthetic>","usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}\n' >> "$TR"

# ---- a scratch repo whose transcript is found by path, as Claude Code names it ----
R=$T/my.repo; mkdir -p "$R/docs" && cd "$R" && git init -q
R=$(pwd -P); SLUG=$(printf '%s' "$R" | tr '/.' '--')
mkdir -p "$T/home/.claude/projects/$SLUG" && cp "$TR" "$T/home/.claude/projects/$SLUG/s.jsonl"

# 1. context
CODER_TRANSCRIPT=$TR "$CS" context > "$T/c1.out"; rc=$?
check "context is the last main-thread response: input + cache writes + cache reads" 'grep -q "^context: 3220 tokens (2% of CODER_CONTEXT_MAX=150000)" "$T/c1.out"'
check "context under the limit exits 0" '[ "$rc" = 0 ]'
CODER_CONTEXT_MAX=3000 CODER_TRANSCRIPT=$TR "$CS" context > "$T/c2.out"; rc=$?
check "context over CODER_CONTEXT_MAX exits 10 with a hand-off hint" '[ "$rc" = 10 ] && grep -q "coder.sh handoff" "$T/c2.out"'
CODER_CONTEXT_MAX='$(touch PWN)' CODER_TRANSCRIPT=$TR "$CS" context > "$T/c3.out"
check "a non-numeric CODER_CONTEXT_MAX falls back to the default" 'grep -q "CODER_CONTEXT_MAX=150000" "$T/c3.out" && [ ! -e PWN ]'
HOME=$T/home "$CS" context > "$T/c4.out"
check "without CODER_TRANSCRIPT, this repo's transcript is found (/ and . become -)" 'grep -q "^context: 3220 tokens" "$T/c4.out"'
HOME=$T/nohome "$CS" context >/dev/null 2>&1; rc=$?
check "no transcript: fails with exit 6" '[ "$rc" = 6 ]'
"$CS" context "$TR" | grep -q "^context: 3220" && ok "an explicit transcript argument wins" || bad "an explicit transcript argument wins"

# 2. handoff
"$CS" handoff > "$T/h1.out"
check "handoff without NOW.md gives a placeholder job" 'grep -qx "You are the coder. Read docs/NOW.md. Then: <one sentence>" "$T/h1.out"'
check "handoff lists rewrite NOW.md, evidence to the task log, new session" 'grep -q "Rewrite docs/NOW.md from scratch" "$T/h1.out" && grep -q "docs/tasks/<id>.log.md" "$T/h1.out" && grep -q "Start a new one" "$T/h1.out"'
printf '# NOW\nTask: t\n**Next:** fix the parser bug in app.py\nLog: docs/tasks/42.log.md\n' > docs/NOW.md
"$CS" handoff > "$T/h2.out"
check "handoff takes the job from NOW.md's Next: line" 'grep -qx "You are the coder. Read docs/NOW.md. Then: fix the parser bug in app.py" "$T/h2.out"'
check "handoff names the task log from NOW.md's Log: line" 'grep -q "docs/tasks/42.log.md" "$T/h2.out"'
printf '# NOW\nNext: reviewer\n' > docs/NOW.md
check "a role-only Next: line is not a job" '"$CS" handoff | grep -q "Then: <one sentence>"'

# 3. costs (grok-review.sh coder-costs)
CODER_TRANSCRIPT=$TR "$CS" costs > "$T/k.out"
check "costs: duplicate message ids count once" 'grep -q "| 1 | build the thing | 1 | 1110 | 1000 | 5 | 1115 |" "$T/k.out"'
check "costs: one row per request" 'grep -q "| 2 | fix it | " "$T/k.out"'

# 4. per-task cost across two sessions with a review in between
GR=$HERE/../../grok-review/grok-review.sh
mkdir -p "$T/stub" && sed -n '/^cat > "$T\/stub\/grok" <<.EOF.$/,/^EOF$/p' "$HERE/../../grok-review/tests/run.sh" | sed '1d;$d' > "$T/stub/grok" && chmod +x "$T/stub/grok"
export GROK=$T/stub/grok STUB_DIR=$T/stub SCAN_CMDS=true MAX_GROK=99   # other sessions' Grok processes must not block the stub round
echo 'x = 1' > app.py; printf '# NOW\nReview: idle\n' > docs/NOW.md
git add -A && git -c user.email=t@t -c user.name=t commit -qm base
TA=$T/sA.jsonl; TB=$T/sB.jsonl
tsay() { printf '{"type":"assistant","message":{"id":"%s","model":"claude-test","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' "$2" "$3" "$4" "$5" >> "$1"; }
tsay "$TA" a1 100 0 10
CODER_TRANSCRIPT=$TA "$CS" task start 34 >/dev/null; rc=$?
check "task start opens a segment and the ledger" '[ "$rc" = 0 ] && [ -f docs/tasks/34.cost.md ] && [ -f "$(git rev-parse --absolute-git-dir)/coder-workflow/task" ]'
check "the task ledger is merge=union" 'grep -qx "docs/tasks/\*.cost.md merge=union" .gitattributes'
CODER_TRANSCRIPT=$TA "$CS" task start 34 >/dev/null 2>&1; check "start of an open task in the same session is a no-op" '[ $? = 0 ]'
CODER_TRANSCRIPT=$TA "$CS" task start 35 >/dev/null 2>&1; check "a second task in the same session must pause the first" '[ $? = 6 ]'
check "handoff tells the next session to resume the task" 'CODER_TRANSCRIPT=$TA "$CS" handoff | grep -q "Read docs/NOW.md. Run .claude/skills/coder-workflow/coder.sh task resume 34. Then:"'
"$GR" init >/dev/null 2>&1; CODER_TRANSCRIPT=$TA "$GR" start --task "t" >"$T/gs.out" 2>&1
check "grok-review start takes the active coder task id" 'grep -q "docs/tasks/34.cost.md" "$T/gs.out"'
tsay "$TA" a2 200 800 20; tsay "$TA" a2 200 800 20                   # one response logged twice
echo 'x = 2' > app.py; printf '# NOW\nReview: requested\n' > docs/NOW.md
CODER_TRANSCRIPT=$TA STUB_VERDICT=pass "$GR" round >"$T/gr.out" 2>&1
check "the review's own coder row (1020) is in REVIEW-COSTS.md" 'grep -q "| 1 (coder) |.*\*\*1020\*\*" docs/REVIEW-COSTS.md'
check "the reviewer round goes to the task ledger; the review's coder row does not" 'grep -q "| reviewer | round 1: pass | \*\*1000\*\*" docs/tasks/34.cost.md && ! grep -q "(coder)" docs/tasks/34.cost.md'
tsay "$TA" a3 50 0 5; CODER_TRANSCRIPT=$TA "$GR" finish --outcome pass >/dev/null 2>&1
CODER_TRANSCRIPT=$TA "$CS" task pause > "$T/p.out"
check "pause writes session A's segment: everything after start, duplicates once (1075)" 'grep -q "| sA | coder | pause | \*\*1075\*\* | 1050 | 800 | 25 | 2 |" docs/tasks/34.cost.md'
"$CS" task pause >/dev/null 2>&1; check "pause with no open segment fails" '[ $? = 6 ]'
CODER_TRANSCRIPT=$TB "$CS" task start 34 >/dev/null 2>&1; check "start of a task with a ledger says use resume" '[ $? = 6 ]'
tsay "$TB" b1 10 0 1
CODER_TRANSCRIPT=$TB "$CS" task resume 34 >/dev/null; tsay "$TB" b2 300 0 30
CODER_TRANSCRIPT=$TB "$CS" task report 34 > "$T/open.out"
check "report shows the open segment outside the total" 'grep -q "open segment (not in the total yet): 330 tokens" "$T/open.out"'
CODER_TRANSCRIPT=$TB "$CS" task done >/dev/null
"$CS" task report 34 > "$T/rep.out"
check "report: coder = sum of session segments (1075 + 330)" 'grep -q "^coder:    1405 tokens in 2 segment(s)" "$T/rep.out"'
check "report: reviewer tokens and USD per round" 'grep -q "^reviewer: 1000 tokens in 1 round(s), \$0.0010$" "$T/rep.out"'
check "report: task total = coder segments + reviewer rounds, no (coder) rows double-counted" 'grep -q "^task total: 2405 tokens" "$T/rep.out"'
# a crashed session: its segment is closed ("reaped") when the next session resumes
TC=$T/sC.jsonl; TD=$T/sD.jsonl; tsay "$TC" c1 1 0 1
CODER_TRANSCRIPT=$TC "$CS" task resume 34 >/dev/null; tsay "$TC" c2 40 0 2
tsay "$TD" d1 1 0 1; CODER_TRANSCRIPT=$TD "$CS" task resume 34 > "$T/reap.out"
check "resume after a crash reaps the other session's open segment" 'grep -q "| sC | coder | reaped | \*\*42\*\*" docs/tasks/34.cost.md && grep -q "unclosed segment" "$T/reap.out"'
CODER_TRANSCRIPT=$TD "$CS" task done >/dev/null
CODER_TRANSCRIPT=$TA "$CS" task start '../x' >/dev/null 2>&1; check "a task id with a path is refused" '[ $? = 6 ] && [ ! -e "$T/x.cost.md" ]'

CODER_TRANSCRIPT=$TA "$CS" task start "$(printf 'ok\n../x')" >/dev/null 2>&1; check "a task id with a newline is refused" '[ $? = 6 ]'
ln -s "$T" docs/tasks/ln.cost.md; CODER_TRANSCRIPT=$TA "$CS" task start ln >/dev/null 2>&1; check "a symlinked ledger is refused" '[ $? = 6 ] && [ ! -e "$T/ln.cost.md" ]'
printf '# NOW\nLog: ../../etc/x.log.md\n' > docs/NOW.md; check "handoff names only a docs/tasks log" '"$CS" handoff | grep -q "docs/tasks/<id>.log.md" && ! "$CS" handoff | grep -q etc'
CODER_TRANSCRIPT=$TA "$CS" task start 36 >/dev/null; chmod 444 docs/tasks/36.cost.md
CODER_TRANSCRIPT=$TA "$CS" task pause >/dev/null 2>&1; rc=$?; chmod 644 docs/tasks/36.cost.md
check "a failed ledger append keeps the segment open" '[ "$rc" = 6 ] && CODER_TRANSCRIPT=$TA "$CS" task pause >/dev/null && grep -q "| coder | pause" docs/tasks/36.cost.md'

echo; echo "passed $pass, failed $fail"
[ "$fail" = 0 ]
