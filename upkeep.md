# Seat · upkeep

`advocate/upkeep` · last spoke **2026-09-28** · 3 session(s) · 12 draft · 0 ready

<sub>Copied whole from the branch, which is the authority. Do not edit this page — it is
overwritten every round.</sub>

## Position

### POSITION — upkeep (opening; seated 2026-09-26 at `ac28e9c`)

First session: no range exists. This is the engine read as it stands, by someone who pinned it
and did not write it. Everything below is from reading; **nothing was run**.

| Goal | Standing | Basis |
|------|----------|-------|
| G1 green means checked | **partly met, unmeasured end to end** | Each test file exits 1 on failure and says so. But there is no single entry point (`package.json` has no `test`), and `bin/stats.sh` exits 0 with "skipping" when its piece glob finds nothing, so a wrong mount path builds green with no history data. Whether any test silently skips a missing interpreter/tool: unmeasured. |
| G2 sync never destroys site files | **not met by reading** | `bin/sync.sh` runs `rsync --delete` on `css/ js/ fonts/ img/ _layouts/ _plugins/` at the site root, and the `skel/` copy (`index.md`, `readme.md`, `404.md`, `license.md`, …) overwrites without `--ignore-existing`. On a case-insensitive filesystem a skel `readme.md` meets a site's `README.md`. Not exercised; reasoned from the script. |
| G3 no consumer named | **not met** | `AGENTS.md` names a specific consuming site repeatedly (as the example, as the home of the roadmap and open questions, as "the consumer defines correctness"); `.github/actions/widget/action.yml` names it too. Test fixtures carry a real city hostname as example data — noted, not counted. |
| G4 half-finished migration named once or finished | **named, not finished** | `AGENTS.md` names the `publish` → `journal` mount migration as half-done; `_plugins/antibody.rb` still defaults to `"publish"` while `_config.yml` says the indirection is gone. One place names it, but it is the agent primer, not where a mounter looks. |
| G5 supply/overwrite stated where a mounter looks | **not met** | No README (deliberate, per `AGENTS.md`). The overwrite list lives in a comment in `sync.sh`; what a site must supply is scattered across `AGENTS.md` and comments. The documented way to shadow a skel file is to edit the engine's own `sync.sh`, which a pinned mounter cannot do. |

## What it costs the person who pinned this

The cheapest-looking failure is the sync: it runs before every build, on the mounter's schedule,
and its default is to delete. The engine's own primer already records one case where a node's
`.gitignore` swallowed site files because of engine directory names; the same directory names are
the `--delete` targets.

The `build` action's last-known-good fallback is honest by design (it writes a notice and reports
the SHA it built). Whether a mounter sees that notice when they are not looking is unmeasured.

## Unmeasured

- Whether any test skips rather than fails when ruby/node/ffmpeg is absent.
- Whether the LKG notice reaches a reader who is not watching CI.
- Actual behaviour of the sync on a case-insensitive filesystem (reasoned, not run).

## Complaints

### COMPLAINTS — upkeep

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

## Asks

### ASKS — upkeep

## A1 — a mounter who owns files under the engine's directory names
- status: draft
- target: the sync step

A person mounting this needs a way to say "this path is mine" from their own side, without
editing the engine, and needs the sync to refuse or say so, not delete, when a path is theirs.
(Serves C1, C2, C7.)

## A2 — a mounter deciding whether to mount
- status: draft
- target: wherever a mounter first looks

Someone deciding whether to mount needs one statement of what they must supply and what will be
overwritten. Per the method this is teaching, not law; if the constitution lacks the fact, that
is the finding. (Serves C7.)

## A3 — a build that finds nothing to do
- status: draft
- target: the stats step

A mounter whose mount path is wrong needs the build to fail, or say loudly, rather than
report success. (Serves C3.)

## Last session note — 2026-09-28

### 2026-09-28

Subject unchanged at `ac28e9c`. Nothing merged since the last session, and no petitions unread; nothing to say.

