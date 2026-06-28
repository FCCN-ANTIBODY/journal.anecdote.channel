#!/usr/bin/env bash
# NOTICE: Vibe code:

set -euo pipefail
BIN="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(git rev-parse --show-toplevel)"; cd "$repo_root"

src="${1:-}"; [ -n "$src" ] || { echo "usage: $0 <path>"; exit 2; }
MOUNT="${JOURNAL_MOUNT:-journal}"     # on-disk mount dir
BASE="${JOURNAL_BASE:-journal}"       # URL/_data namespace
DATA_ROOT="${JOURNAL_DATA_ROOT:-_data/git}"

# _data key: drop the on-disk mount prefix, prepend the URL base, comma-encode.
rel="${src#"$MOUNT"/}"
key="$BASE/${rel%.md}"

out_dir="$DATA_ROOT/paragraphs"; mkdir -p "$out_dir"
out="$out_dir/${key//\//,}.json"

bash "$BIN/stat-paragraph-log.sh" "$src" | node "$BIN/stat-paragraph.js" > "$out"
echo "$out"
