#!/usr/bin/env bash
# coder.sh — measure the coder's context and hand off to a fresh session. SKILL.md holds the rules.
#
#   context [transcript]   current context size (last response's input + cache reads/writes); exit 10 over CODER_CONTEXT_MAX
#   handoff                the hand-off checklist and the first message for the next session
#   costs [transcript]     tokens per user request (grok-review.sh coder-costs)
#   task start|resume ID   open a coder segment of task ID in this session (resume reaps a crashed session's segment)
#   task pause|done        close the segment: one row in docs/tasks/ID.cost.md
#   task report [ID]       coder segments + reviewer rounds + totals for a task
#   update [--check]       sync this copy from the canonical one in grok-reviewer-workflow-public
#   version                print the installed version
#
# Transcript: CODER_TRANSCRIPT, else this session's (CLAUDE_CODE_SESSION_ID), else this repo's newest.
# Written for macOS /bin/bash 3.2.

set -o pipefail
CODER_VERSION=2026.09.30.1   # canonical copy: grok-reviewer-workflow-public/project/.claude/skills/coder-workflow
HERE=$(cd "$(dirname "$0")" && pwd -P)
CODER_CONTEXT_MAX=${CODER_CONTEXT_MAX:-150000}
case "$CODER_CONTEXT_MAX" in ''|*[!0-9]*) CODER_CONTEXT_MAX=150000;; esac

die() { echo "coder: $1" >&2; exit "${2:-6}"; }
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd); ROOT=$(cd "$ROOT" && pwd -P)

transcript() {  # [path] -> a transcript path, or nothing
  [ -n "${1:-}" ] && { echo "$1"; return 0; }
  [ -n "${CODER_TRANSCRIPT:-}" ] && { echo "$CODER_TRANSCRIPT"; return 0; }
  case "${CLAUDE_CODE_SESSION_ID:-}" in *[!0-9a-f-]*|'') ;; *)
    local f; f=$(ls "$HOME/.claude/projects"/*/"$CLAUDE_CODE_SESSION_ID.jsonl" 2>/dev/null | head -1)
    [ -n "$f" ] && { echo "$f"; return 0; };; esac
  ls -t "$HOME/.claude/projects/$(printf '%s' "$ROOT" | tr '/.' '--')"/*.jsonl 2>/dev/null | head -1
}
# The last main-thread response's prompt size: what the next call re-sends. Only the tail is parsed.
context_tokens() {
  grep '"type":"assistant"' "$1" 2>/dev/null | tail -200 | jq -rs '
    [.[] | select(.type == "assistant" and (.isSidechain | not) and .message.usage != null) | .message.usage
      | .input_tokens + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) | select(. > 0)]
    | last // 0' 2>/dev/null || echo 0
}

cmd_context() {
  local t tok; t=$(transcript "${1:-}"); [ -f "$t" ] || die "no transcript for $ROOT (set CODER_TRANSCRIPT)"
  tok=$(context_tokens "$t")
  echo "context: $tok tokens ($((tok * 100 / CODER_CONTEXT_MAX))% of CODER_CONTEXT_MAX=$CODER_CONTEXT_MAX)"
  [ "$tok" -gt "$CODER_CONTEXT_MAX" ] || return 0
  echo "over the limit: hand off now (coder.sh handoff), then start a fresh session"; exit 10
}

now_file() {
  if [ -n "${NOW:-}" ]; then echo "$NOW"; elif [ -f "$ROOT/NOW.md" ]; then echo "$ROOT/NOW.md"; else echo "$ROOT/docs/NOW.md"; fi
}
now_field() {  # key -> first "Key: value" in NOW.md (markdown emphasis and list dashes tolerated)
  sed -n "s/^[*_[:space:]-]*$1:[*_[:space:]]*//p" "$(now_file)" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//'
}
# NOW.md is written by whatever coder session ran before this one — cooperative, not adversarial,
# but still a prior agent's output, not the owner's. cmd_handoff prints it as the literal first
# message for the *next* session, so a stray line that reads like a second instruction (or that
# imitates this function's own "suggested message" framing) should not be able to pass as one.
defuse() {  # neutralise a NOW.md field before it's echoed as a suggested prompt
  printf '%s' "$1" | sed -e 's/^You are the /You_are_the /' -e 's/^---*$/--/'
}

cmd_handoff() {
  local job log id="" resume=""; job=$(now_field Next); log=$(now_field Log)
  [ -f "$STATE/task" ] && id=$(cat "$STATE/task") && resume="Run .claude/skills/coder-workflow/coder.sh task resume $id. "
  local pause=""; [ -n "$id" ] && pause="Run: coder.sh task pause (closes the cost segment of task $id). "
  case "$job" in ''|—|-|coder|reviewer|none) job='<one sentence>';; esac
  case "$log" in docs/tasks/*.log.md) case "$log" in *..*|*[!A-Za-z0-9._/-]*) log='docs/tasks/<id>.log.md';; esac;; *) log='docs/tasks/<id>.log.md';; esac
  job=$(defuse "$job"); log=$(defuse "$log")
  cat <<EOF
Hand-off checklist:
1. Rewrite $(now_file | sed "s|^$ROOT/||") from scratch: state, decisions, open questions, and a Next: line with the job.
2. Put evidence (test output, review findings, commands run) in $log, not in NOW.md.
3. ${pause}Stop this session. Start a new one with (read from NOW.md's own Next: line — review it, it is not this script's instruction):

You are the coder. Read docs/NOW.md. ${resume}Then: $job
EOF
}

cmd_costs() {
  local t; t=$(transcript "${1:-}"); [ -f "$t" ] || die "no transcript for $ROOT (set CODER_TRANSCRIPT)"
  CODER_TRANSCRIPT=$t "$HERE/../grok-review/grok-review.sh" coder-costs "$t"
}

# ---------- per-task cost: one row per coder session segment, across sessions ----------
# State is never committed. The ledger is committed, append-only, merge=union. grok-review.sh adds the
# task's reviewer rows to the same ledger; its "(coder)" rows stay in REVIEW-COSTS.md, so nothing counts twice.
TASKS_DIR=${CODER_TASKS_DIR:-$ROOT/docs/tasks}
STATE=$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null)/coder-workflow
usage() {  # transcript -> {"session":{...}}; one entry per model response (deduped by id), as grok-review.sh meters it
  [ -f "${1:-}" ] || { echo '{"session":{}}'; return 0; }
  jq -cs '[.[] | select(.type == "assistant" and .message.usage != null) | .message] | unique_by(.id) as $m
    | {session: {
        inputTokens: ($m | map(.usage.input_tokens + (.usage.cache_creation_input_tokens // 0) + (.usage.cache_read_input_tokens // 0)) | add // 0),
        cachedReadTokens: ($m | map(.usage.cache_read_input_tokens // 0) | add // 0),
        outputTokens: ($m | map(.usage.output_tokens // 0) | add // 0), modelCalls: ($m | length)}}
    | .session.totalTokens = .session.inputTokens + .session.outputTokens' "$1" 2>/dev/null || echo '{"session":{}}'
}
valid_id() { case "$1" in ''|[!A-Za-z0-9]*|*[!A-Za-z0-9._-]*|*..*) return 1;; esac; [ ${#1} -le 64 ]; }   # no grep: a newline must not pass
safe_ledger() {  # id — refuse a symlinked tasks dir or ledger: a planted link must not redirect the write
  [ -L "$TASKS_DIR" ] || [ -L "$(ledger "$1")" ] && die "refusing a symlinked $(ledger "$1" | sed "s|^$ROOT/||")"; return 0; }
ledger() { echo "$TASKS_DIR/$1.cost.md"; }
ledger_init() {  # id
  local f; f=$(ledger "$1"); safe_ledger "$1"; mkdir -p "$TASKS_DIR"
  printf '# Task cost: %s\n\nAppend-only. One row per coder session segment (coder.sh task pause/done) and per review round (grok-review.sh).\nTokens = input (incl. cached) + output. Report: coder.sh task report %s\n\n| Date | Session | Kind | Segment | Total tokens | Input | Cached | Output | Calls | Wall | USD |\n|---|---|---|---|---|---|---|---|---|---|---|\n' "$1" "$1" > "$f"
  local ga=$ROOT/.gitattributes line; line="${TASKS_DIR#$ROOT/}/*.cost.md merge=union"
  grep -qxF "$line" "$ga" 2>/dev/null || echo "$line" >> "$ga"
}
seg_open() { [ -f "$STATE/task" ] && [ -f "$STATE/seg.json" ]; }
seg_begin() {  # id transcript
  mkdir -p "$STATE"; usage "$2" > "$STATE/seg.json"
  printf '%s\n' "$1" > "$STATE/task"; printf '%s\n' "$2" > "$STATE/transcript"; date +%s > "$STATE/start"
  echo "task $1: coder segment open (session $(basename "$2" .jsonl | cut -c1-8))"
}
seg_close() {  # label — one ledger row for the open segment, then clear the state
  local id t now secs; id=$(cat "$STATE/task"); t=$(cat "$STATE/transcript"); now=$(mktemp); usage "$t" > "$now"
  secs=$(( $(date +%s) - $(cat "$STATE/start") )); safe_ledger "$id"; [ -f "$(ledger "$id")" ] || ledger_init "$id"
  d() { jq -rn --slurpfile a "$STATE/seg.json" --slurpfile b "$now" --arg k "$1" '(($b[0].session[$k] // 0) - ($a[0].session[$k] // 0))'; }
  printf '| %s | %s | coder | %s | **%s** | %s | %s | %s | %s | %s | plan |\n' "$(date +%F)" "$(basename "$t" .jsonl | cut -c1-8)" "$1" \
    "$(d totalTokens)" "$(d inputTokens)" "$(d cachedReadTokens)" "$(d outputTokens)" "$(d modelCalls)" "$((secs / 60))m$((secs % 60))s" | tee -a "$(ledger "$id")" || { rm -f "$now"; die "could not append to $(ledger "$id"); the segment stays open"; }
  rm -f "$now" "$STATE/task" "$STATE/transcript" "$STATE/start" "$STATE/seg.json"
}
cmd_task() {
  local sub=${1:-} id=${2:-} t; [ -n "${STATE%/coder-workflow}" ] || die "task: not inside a git repository"
  command -v jq >/dev/null || die "missing dependency: jq"
  case "$sub" in
    start|resume)
      valid_id "$id" || die "task $sub: give a task id like 34 or audit-fix"
      t=$(transcript); [ -f "$t" ] || die "no transcript for $ROOT (set CODER_TRANSCRIPT)"
      if seg_open; then
        if [ "$(cat "$STATE/transcript")" = "$t" ]; then
          [ "$(cat "$STATE/task")" = "$id" ] && { echo "task $id is already open in this session"; return 0; }
          die "task $(cat "$STATE/task") is open in this session: task pause or task done first"
        fi
        echo "closing an unclosed segment from another session:"; seg_close reaped
      fi
      if [ "$sub" = start ]; then [ -f "$(ledger "$id")" ] && die "$(ledger "$id" | sed "s|^$ROOT/||") exists: use task resume $id"; ledger_init "$id"
      else [ -f "$(ledger "$id")" ] || die "no ledger for task $id: use task start $id"; fi
      seg_begin "$id" "$t";;
    pause|done) seg_open || die "no open task segment"; seg_close "$sub";;
    report) cmd_report "$id";;
    *) die "task start|resume ID · task pause|done · task report [ID]";;
  esac
}
cmd_report() {  # [id] — the ledger rows, then totals. Only coder segment and reviewer round rows count.
  local id=${1:-}; [ -n "$id" ] || id=$(cat "$STATE/task" 2>/dev/null); valid_id "$id" || die "task report: give a task id"
  local f; f=$(ledger "$id"); [ -f "$f" ] || die "no ledger for task $id"
  grep -E '^\| [^|]+ \| [^|]+ \| (coder|reviewer) \|' "$f" | tr -d '*' | awk -F'|' -v id="$id" '
    { k = $4; gsub(/ /, "", k); tok[k] += $6; n[k]++; u = $12; gsub(/ /, "", u); if (u ~ /^[0-9]/) usd += u + 0; else if (k == "reviewer") unrep = 1
      print "| " k " |" $5 "|" $6 "|" $11 "|" $12 "|" }
    BEGIN { print "task " id; print "| Kind | Segment | Tokens | Wall | USD |"; print "|---|---|---|---|---|" }
    END { printf "coder:    %d tokens in %d segment(s)\n", tok["coder"], n["coder"]
          printf "reviewer: %d tokens in %d round(s), $%.4f%s\n", tok["reviewer"], n["reviewer"], usd, (unrep ? " + unreported" : "")
          printf "task total: %d tokens\n", tok["coder"] + tok["reviewer"] }'
  if seg_open && [ "$(cat "$STATE/task")" = "$id" ]; then
    local now; now=$(mktemp); usage "$(cat "$STATE/transcript")" > "$now"
    echo "open segment (not in the total yet): $(jq -rn --slurpfile a "$STATE/seg.json" --slurpfile b "$now" '($b[0].session.totalTokens // 0) - ($a[0].session.totalTokens // 0)') tokens"; rm -f "$now"
  fi
}

CANON=${CODER_WORKFLOW_CANON:-$HOME/src/grok-reviewer-workflow-public/project/.claude/skills/coder-workflow}
cmd_update() {  # [--check] — sync this copy from the canonical one in grok-reviewer-workflow-public
  [ -f "$CANON/coder.sh" ] || die "canonical copy not found at $CANON (set CODER_WORKFLOW_CANON)"
  [ "$HERE" = "$(cd "$CANON" && pwd -P)" ] && { echo "this is the canonical copy ($CODER_VERSION)"; return 0; }
  local cv; cv=$(sed -n 's/^CODER_VERSION=\([^ ]*\).*/\1/p' "$CANON/coder.sh")
  if diff -rq "$CANON" "$HERE" >/dev/null; then echo "up to date ($CODER_VERSION)"; return 0; fi
  echo "installed $CODER_VERSION, canonical $cv:"; diff -rq "$CANON" "$HERE" | sed 's/^/  /'
  [ "${1:-}" = --check ] && exit 10
  seg_open && die "a task segment is open (coder.sh task pause first): update between segments"
  # Write each file under a temporary name and rename it: bash is still reading this very script,
  # and an in-place overwrite would make it resume reading the new file at the old offset.
  (cd "$CANON" && find . -type f) | while IFS= read -r f; do
    mkdir -p "$HERE/$(dirname "$f")" && cp "$CANON/$f" "$HERE/$f.new.$$" && mv -f "$HERE/$f.new.$$" "$HERE/$f"
  done
  echo "updated to $cv"
}

cmd=${1:-}; [ $# -gt 0 ] && shift
case "$cmd" in
  context) cmd_context "$@";; handoff) cmd_handoff;; costs) cmd_costs "$@";; task) cmd_task "$@";;
  update) cmd_update "$@";; version) echo "coder-workflow $CODER_VERSION";;
  *) sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; exit 6;;
esac
