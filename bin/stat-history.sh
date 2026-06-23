#!/usr/bin/env sh
# NOTICE: Vibe code: make a json structure about the full file history.
# This data supports making multiple activity ranges visible to the built site.

set -eu

BIN="$(cd "$(dirname "$0")" && pwd)"
. "$BIN/lib.sh"

MOUNT="${JOURNAL_MOUNT:-publish}"     # on-disk mount dir
BASE="${JOURNAL_BASE:-journal}"       # URL/_data namespace
out_root="${JOURNAL_DATA_ROOT:-_data/git}/history"
mkdir -p "$out_root"

# Python program (reads git log from stdin, args: path repo_root)
read_only_py='
import sys, json, datetime, re
path, repo_root, sentinel = sys.argv[1], sys.argv[2], sys.argv[3]

ADD = re.compile(r"\{\+(.*?)\+\}", re.S)   # {+ … +}
DEL = re.compile(r"\[\-(.*?)\-\]", re.S)   # [- … -]
blen = lambda s: len(s.encode("utf-8"))

weeks = {}
first = {"sha": None, "date": None, "week": None}
last  = {"sha": None, "date": None, "week": None}

raw = sys.stdin.read()
for chunk in raw.split(sentinel):
    if not chunk.strip(): continue
    header, _, body = chunk.partition("\n")
    try: sha, iso, week = header.strip().split(" ", 3)
    except ValueError: continue

    adds = sum(blen(m.group(1)) for m in ADD.finditer(body))
    dels = sum(blen(m.group(1)) for m in DEL.finditer(body))

    if last["sha"] is None:
        last = {"sha": sha, "date": iso, "week": week}
    first = {"sha": sha, "date": iso, "week": week}

    b = weeks.setdefault(week, {"bytes_changes":0, "bytes_touches":0})
    b["bytes_changes"] += (adds + dels)
    b["bytes_touches"] += max(adds, dels)

hist = [{"week": w, "bytes_changes": v["bytes_changes"], "bytes_touches": v["bytes_touches"]}
        for w, v in sorted(weeks.items())]

print(json.dumps({
  "meta": {
    "path": path,
    "repo": repo_root.rsplit("/",1)[-1],
    "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")+"Z",
    "total_bytes_changes": sum(v["bytes_changes"] for v in weeks.values()),
    "total_bytes_touches": sum(v["bytes_touches"] for v in weeks.values()),
    "unique_weeks": len(hist),
    "first_commit": first,
    "last_commit":  last
  },
  "histogram": hist,
  "stats": {}
}, indent=2))
'

emit_json() {
  path="$1"
  resolve_owner "$path"   # OWNER_REPO / OWNER_REL: where this piece's history lives
  wd_regex=${WORD_DIFF_REGEX:-'\w+|[^\s\w]'}
  diff_alg=${DIFF_ALG:-histogram}
  sentinel=$'\036'

  git -C "$OWNER_REPO" \
    -c diff.wordRegex="$wd_regex" \
    -c diff.algorithm="$diff_alg" \
    log --follow -M --no-merges \
    --format="${sentinel}%H %cI %cd" --date=format:%G-W%V \
    -p -U0 --word-diff=plain --no-color --no-ext-diff --no-textconv -- "$OWNER_REL" \
  | python3 -c "$read_only_py" "$path" "$OWNER_REPO" "$sentinel"
}

while IFS= read -r f; do
  [ -n "$f" ] || continue
  rel="${f#./}"
  # _data key: drop the on-disk mount prefix, prepend the URL base, comma-encode.
  short="$BASE/${rel#"$MOUNT"/}"
  short=$(printf '%s' "$short" | tr '/' ',')
  out="$out_root/${short%.md}.json"
  mkdir -p "$(dirname "$out")"
  emit_json "$rel" >"$out"
  echo "wrote $out"
done
