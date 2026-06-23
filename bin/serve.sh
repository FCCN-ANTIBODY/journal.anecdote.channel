#!/usr/bin/env bash
# NOTICE: Serve the site locally. Run from the SITE root (engine at journal/).

set -euo pipefail

eng="${JOURNAL_ENGINE:-journal}"
export BUNDLE_GEMFILE="${BUNDLE_GEMFILE:-$eng/Gemfile}"

"$eng/bin/sync.sh"
bundle exec jekyll serve --config "$eng/_config.yml,_config.yml" "$@"
