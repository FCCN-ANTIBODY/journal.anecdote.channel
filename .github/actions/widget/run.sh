#!/usr/bin/env bash
# Resolve the CALLING workspace's node identity, then render the data-filled Journal
# widget fragment into the workspace with bin/widget. Reads the node's published origin
# and journal mount from its _config.yml — the bundled bin/widget is the CODE; the node's
# _config.yml is the DATA — so any node that drops this in renders a locator to ITS OWN
# journal, never the template's.
#
# Fails closed: with no _config.yml and no explicit url it refuses rather than render the
# wrong node (mirrors tell's widget/register actions).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
widget="$here/../../../bin/widget"   # bundled CODE, location-independent of the call site
[ -f "$widget" ] || { echo "widget: bundled bin/widget not found at $widget" >&2; exit 1; }

config="${CONFIG:-_config.yml}"
url="${SITE_URL:-}"
mount="${MOUNT:-}"

# Pull a top-level scalar from a flat YAML file: take everything after the FIRST `key:`,
# strip an inline # comment, surrounding quotes, and edge whitespace. Splitting on the
# first colon only (unlike a naive FS=':') keeps `https://…` URLs intact.
yval() { # FILE KEY
  awk -v k="$2" '
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/[[:space:]]*#.*$/, "", v)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      gsub(/^["\x27]|["\x27]$/, "", v)
      print v; exit
    }
  ' "$1"
}

if [ -z "$url" ] || [ -z "$mount" ]; then
  [ -f "$config" ] || {
    echo "widget: no $config in the workspace and url not provided — refusing to render the wrong node" >&2
    exit 1
  }
  [ -z "$url" ] && url="$(yval "$config" url)"
  # `journal` is the public URL base; absent in the site config it inherits the engine
  # default, so fall back to that rather than failing.
  [ -z "$mount" ] && mount="$(yval "$config" journal)"
fi
mount="${mount:-journal}"
[ -n "$url" ] || { echo "widget: could not resolve url from $config" >&2; exit 1; }

out="${OUT:-widget/journal.html}"

bash "$widget" --url "$url" --mount "$mount" --out "$out"
echo "widget: rendered ${url%/}/${mount}/ into $out" >&2
