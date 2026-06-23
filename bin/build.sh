#!/usr/bin/env bash
# NOTICE: Build the site. Run from the SITE root (engine mounted at journal/).
# Engine config is merged first so the site's _config.yml shadows it.

set -euo pipefail

eng="${JOURNAL_ENGINE:-journal}"
export BUNDLE_GEMFILE="${BUNDLE_GEMFILE:-$eng/Gemfile}"

"$eng/bin/sync.sh"
bundle exec jekyll build --config "$eng/_config.yml,_config.yml" --destination _site --trace "$@"
