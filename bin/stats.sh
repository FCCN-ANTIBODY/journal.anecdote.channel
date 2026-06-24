#!/usr/bin/env bash
# NOTICE: Generate the per-piece git-history _data (blame, paragraphs, history).
# Run from the SITE root. The piece glob and _data keys follow the mount config.

set -euo pipefail

eng="${JOURNAL_ENGINE:-journal}"        # mounted engine path, from the site root
export JOURNAL_MOUNT="${JOURNAL_MOUNT:-publish}"
export JOURNAL_BASE="${JOURNAL_BASE:-journal}"

# Enumerate pieces on disk (not via git ls-files): a mounted submodule's files
# don't show in the superproject index, but each piece's history is resolved in
# its owning repo by the stat-* scripts (see bin/lib.sh resolve_owner).
pieces="$(find "$JOURNAL_MOUNT" -name .git -prune -o -type f -name index.md -print 2>/dev/null | sort)"
if [ -z "$pieces" ]; then
  echo "stats: no pieces found under $JOURNAL_MOUNT/; skipping"
  exit 0
fi

printf '%s\n' "$pieces" | "$eng/bin/batch.sh" "$eng/bin/stat-piece.sh"
printf '%s\n' "$pieces" | "$eng/bin/batch.sh" "$eng/bin/stat-paragraphs.sh"
printf '%s\n' "$pieces" | "$eng/bin/stat-history.sh"
