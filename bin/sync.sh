#!/usr/bin/env bash
# NOTICE: Sync engine defaults into the site root before a Jekyll build.
# Run from the SITE root (the repo that mounts this engine at journal/).
#
# Engine assets (_layouts, _plugins, css, ...) and the skel/ boilerplate pages
# are gitignored in the site and refreshed here. A site SHADOWS a default by
# committing its own copy and adding it to the excludes below (the same way
# _includes/contact/ and _includes/constitution/ are preserved).

set -euo pipefail

eng="${JOURNAL_ENGINE:-journal}"   # path to the mounted engine, from the site root

# Engine include partials, minus the site-owned subtrees we never overwrite.
rsync -a --delete --exclude='contact/' --exclude='constitution/' "$eng/_includes/" _includes/
rsync -a --delete "$eng/_layouts/" _layouts/
rsync -a --delete "$eng/_plugins/" _plugins/
rsync -a --delete "$eng/css/"      css/
rsync -a --delete "$eng/js/"       js/
rsync -a --delete "$eng/fonts/"    fonts/
rsync -a --delete "$eng/img/"      img/

# Site-root boilerplate pages (no --delete: only writes the skel files).
# A site shadows one by committing its own and adding --exclude='<file>' here.
rsync -a "$eng/skel/" ./
