#!/usr/bin/env bash
# NOTICE: Vibe code: streams git logs on a range of lines that markdown uses as
# one paragraph.

set -euo pipefail
file="docs/$1"

_submodule_root() {
  local dir; dir="$(dirname "$1")"
  while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
    [ -f "$dir/.git" ] && { echo "$dir"; return; }
    dir="$(dirname "$dir")"
  done
}

sm_dir="$(_submodule_root "$file")"
if [ -n "$sm_dir" ]; then
  _sm_rel="${file#${sm_dir}/}"
  head_sha="$(git -C "$sm_dir" rev-parse HEAD)"
  _log_path="$_sm_rel"
  _git_log() { git -C "$sm_dir" -c core.quotepath=off log "$@"; }
else
  head_sha="$(git rev-parse HEAD)"
  _log_path="$file"
  _git_log() { git -c core.quotepath=off log "$@"; }
fi

printf '{"file":"%s","head":"%s"}\n' "$file" "$head_sha"

while read -r para start end; do
  printf '{"para":%d,"range":[%d,%d]}\n' "$para" "$start" "$end"
  _git_log --no-color --no-decorate \
  --format='%H%x00%aN <%aE>%x00%aI%x00%s' -p -L "$start,$end:$_log_path" \
  | perl -0777 -ne 'print'  # pass through as one blob
  printf '\n---ENDPARA---\n'
done < <("$(dirname "$0")/stat-paragraphs-ranges.sh" "$file")
