#!/usr/bin/env bash
# Copy the agent-workflow files into an existing or new project directory.
# Does not copy examples/. Does not overwrite existing files unless -f.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FORCE=0
if [[ "${1:-}" == "-f" ]]; then
  FORCE=1
  shift
fi

if [[ $# -lt 1 ]]; then
  echo "usage: $0 [-f] DEST_DIR" >&2
  echo "  copies project/ into DEST_DIR (mkdir if needed)" >&2
  echo "  -f overwrites existing files" >&2
  exit 1
fi

DEST="$1"
mkdir -p "$DEST"

copied=0
skipped=0
while IFS= read -r rel; do
  src="$ROOT/project/$rel"
  dst="$DEST/$rel"
  if [[ -d "$src" ]]; then
    mkdir -p "$dst"
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
    echo "skip (exists): $rel"
    skipped=$((skipped + 1))
    continue
  fi
  cp "$src" "$dst"
  echo "copy: $rel"
  copied=$((copied + 1))
done < <(cd "$ROOT/project" && find . -print | sed 's|^\./||' | grep -v '^$')

echo
echo "copied=$copied skipped=$skipped dest=$DEST"
echo "Next: replace {{PLACEHOLDERS}} in AGENTS.md and docs/NOW.md"
echo "Do not copy $ROOT/examples/ into the repo"
echo "Launch agents from DEST, not from \$HOME"
