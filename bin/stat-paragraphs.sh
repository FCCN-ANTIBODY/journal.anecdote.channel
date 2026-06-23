#!/usr/bin/env bash
# NOTICE: Vibe code:

set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"; cd "$repo_root"

src="${1:-}"; [ -n "$src" ] || { echo "usage: $0 <path>"; exit 2; }
MOUNT="${JOURNAL_MOUNT:-publish}"     # on-disk mount dir
BASE="${JOURNAL_BASE:-journal}"       # URL/_data namespace
DATA_ROOT="${JOURNAL_DATA_ROOT:-_data/git}"

# _data key: drop the on-disk mount prefix, prepend the URL base, comma-encode.
rel="${src#"$MOUNT"/}"
key="$BASE/${rel%.md}"

out_dir="$DATA_ROOT/paragraphs"; mkdir -p "$out_dir"
out="$out_dir/${key//\//,}.json"

bash bin/stat-paragraph-log.sh "$src" | node bin/stat-paragraph.js > "$out"
echo "$out"
