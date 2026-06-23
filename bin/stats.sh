#!/usr/bin/env bash
# NOTICE: Generate the per-piece git-history _data (blame, paragraphs, history).
# Run from the SITE root. The piece glob and _data keys follow the mount config.

set -euo pipefail

eng="${JOURNAL_ENGINE:-journal}"        # mounted engine path, from the site root
export JOURNAL_MOUNT="${JOURNAL_MOUNT:-publish}"
export JOURNAL_BASE="${JOURNAL_BASE:-journal}"

# NOTE: no --recurse-submodules on purpose. git blame/log can only read line
# history for pieces tracked in THIS repo, so stats are generated for content
# committed directly under the mount dir. Pieces that live in a submodule list to
# nothing here and are skipped (their history feature stays dormant) rather than
# erroring the build.
pieces="$(git ls-files "$JOURNAL_MOUNT/**/index.md")"
if [ -z "$pieces" ]; then
  echo "stats: no pieces tracked under $JOURNAL_MOUNT/ in this repo; skipping"
  exit 0
fi

printf '%s\n' "$pieces" | "$eng/bin/batch.sh" "$eng/bin/stat-piece.sh"
printf '%s\n' "$pieces" | "$eng/bin/batch.sh" "$eng/bin/stat-paragraphs.sh"
printf '%s\n' "$pieces" | "$eng/bin/stat-history.sh"
