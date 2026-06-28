#!/usr/bin/env bash
# NOTICE: Vibe code: streams git logs on a range of lines that markdown uses as
# one paragraph.

set -euo pipefail
BIN="$(cd "$(dirname "$0")" && pwd)"
. "$BIN/lib.sh"

file="$1"  # site-root-relative path to the piece (e.g. journal/<author>/<piece>/index.md)
resolve_owner "$file"   # OWNER_REPO / OWNER_REL: where the line history lives
head_sha="$(git -C "$OWNER_REPO" rev-parse HEAD)"
printf '{"file":"%s","head":"%s"}\n' "$file" "$head_sha"

while read -r para start end; do
  printf '{"para":%d,"range":[%d,%d]}\n' "$para" "$start" "$end"
  git -C "$OWNER_REPO" -c core.quotepath=off log --no-color --no-decorate \
  --format='%H%x00%aN <%aE>%x00%aI%x00%s' -p -L "$start,$end:$OWNER_REL" \
  | perl -0777 -ne 'print'  # pass through as one blob
  printf '\n---ENDPARA---\n'
done < <("$BIN/stat-paragraphs-ranges.sh" "$file")
