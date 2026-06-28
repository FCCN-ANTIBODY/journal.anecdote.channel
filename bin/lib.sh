# Shared helper for the stat-* scripts. POSIX sh compatible.
#
# resolve_owner <working-tree-path>
#   Sets OWNER_REPO (the toplevel of the git repo that actually tracks the file)
#   and OWNER_REL (the file's path relative to that repo). This is what lets the
#   stats read line history from wherever it lives: content committed directly in
#   the site repo resolves to the site repo, while content mounted via a submodule
#   (e.g. journal/<author> -> cite-autumn-ryan) resolves to the submodule, whose
#   history carries the blame/log the superproject's gitlink cannot.

resolve_owner() {
  _p="$1"
  _dir=$(CDPATH= cd -- "$(dirname -- "$_p")" && pwd)
  _abs="$_dir/$(basename -- "$_p")"
  OWNER_REPO=$(git -C "$_dir" rev-parse --show-toplevel)
  OWNER_REL=${_abs#"$OWNER_REPO"/}
}
