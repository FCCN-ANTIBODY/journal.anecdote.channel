# COMPLAINTS — upkeep

## C1 — "I didn't change anything and my README is gone."
- status: draft
- source: observed (`bin/sync.sh`, read at `ac28e9c`; not run)

The pre-build sync overwrites `readme.md`, `index.md`, `404.md`, `license.md` at the site root
from the engine, without asking, on whatever schedule the mounter's build fires. On a
case-insensitive filesystem a differently-cased file of the site's own is in the way too.
Goal: G2.

## C2 — "It deleted my css folder."
- status: draft
- source: observed (`bin/sync.sh`; `AGENTS.md` records the near-neighbour case)

`css/`, `js/`, `fonts/`, `img/` are synced with `--delete`. The names read as the site's own;
the engine takes them as its own. A site file placed there is removed on the next build with no
message. Goal: G2.

## C3 — "It said everything passed, and there was nothing to check."
- status: draft
- source: observed (`bin/stats.sh`)

A mount path that matches no pieces prints "skipping" and exits 0. The build continues green
with no per-piece history. Goal: G1.

## C4 — "There is no one command that says the engine is fine."
- status: draft
- source: observed (`package.json`, `test/`)

Seven test files, each run by hand; no `test` script and no aggregate that fails if one could not
start. Whether each refuses to pass when its tool is missing is unmeasured. Goal: G1.

## C5 — "Someone's name is in the engine."
- status: draft
- source: observed (`AGENTS.md`, `.github/actions/widget/action.yml`)

A specific consuming site is named as example, roadmap home and arbiter of correctness. A
requirement should arrive as a shape. Goal: G3.

## C6 — "The docs say one thing and the plugin does another."
- status: draft
- source: observed (`_config.yml`, `_plugins/antibody.rb`, `AGENTS.md`)

`_config.yml` says the `publish` indirection is gone; the plugin still defaults to it. The gap is
named in the primer, but nowhere a mounter reads. Goal: G4.

## C7 — "What do I have to provide, and what will it clobber?"
- status: draft
- source: observed

No statement, where someone deciding to mount would look, of what a site must supply or which
paths the engine overwrites. Shadowing a skel file is documented as editing the engine's
`sync.sh`, which a pinned mounter cannot do. Goal: G5.
