#!/usr/bin/env bash
# NOTICE: Generate the per-piece git-history _data (blame, paragraphs, history).
# Run from the SITE root. The piece glob and _data keys follow the mount config.

set -euo pipefail

eng="${JOURNAL_ENGINE:-journal}"        # mounted engine path, from the site root
export JOURNAL_MOUNT="${JOURNAL_MOUNT:-publish}"
export JOURNAL_BASE="${JOURNAL_BASE:-journal}"

pieces="$JOURNAL_MOUNT/**/index.md"

git ls-files --recurse-submodules "$pieces" | "$eng/bin/batch.sh" "$eng/bin/stat-piece.sh"
git ls-files --recurse-submodules "$pieces" | "$eng/bin/batch.sh" "$eng/bin/stat-paragraphs.sh"
git ls-files --recurse-submodules "$pieces" | "$eng/bin/stat-history.sh"
