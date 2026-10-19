# POSITION — upkeep (2026-10-19, at `a1acc43`)

Range `ac28e9c..a1acc43`: one merge (#42), which makes `build-intermediates` carry a piece's
engine tags (`{% include cite.html %}` etc.) instead of refusing it. Everything below is from
reading; **nothing was run**, including the new test.

| Goal | Standing | Basis |
|------|----------|-------|
| G1 green means checked | **partly met, unmeasured end to end** | Each test file exits 1 on failure and says so. But there is no single entry point (`package.json` has no `test`), and `bin/stats.sh` exits 0 with "skipping" when its piece glob finds nothing, so a wrong mount path builds green with no history data. Whether any test silently skips a missing interpreter/tool: unmeasured. |
| G2 sync never destroys site files | **not met by reading** | `bin/sync.sh` runs `rsync --delete` on `css/ js/ fonts/ img/ _layouts/ _plugins/` at the site root, and the `skel/` copy (`index.md`, `readme.md`, `404.md`, `license.md`, …) overwrites without `--ignore-existing`. On a case-insensitive filesystem a skel `readme.md` meets a site's `README.md`. Not exercised; reasoned from the script. |
| G3 no consumer named | **not met** | `AGENTS.md` names a specific consuming site repeatedly (as the example, as the home of the roadmap and open questions, as "the consumer defines correctness"); `.github/actions/widget/action.yml` names it too. Test fixtures carry a real city hostname as example data — noted, not counted. |
| G4 half-finished migration named once or finished | **named, not finished; one new contradiction** | #42 left `AGENTS.md` saying intermediates are "INERT — … no template syntax" (~l.105) and, a paragraph later, that carried pieces keep their tags. The tool's header agrees with the new behaviour; the primer does not. Separately, `AGENTS.md` names the `publish` → `journal` mount migration as half-done; `_plugins/antibody.rb` still defaults to `"publish"` while `_config.yml` says the indirection is gone. One place names it, but it is the agent primer, not where a mounter looks. |
| G5 supply/overwrite stated where a mounter looks | **not met; one new requirement unstated** | Since #42, whoever renders an intermediate must supply the engine's `_includes/` (cite, figure…) or the tags are raw or blank; that is stated only in a tool header and the primer. No README (deliberate, per `AGENTS.md`). The overwrite list lives in a comment in `sync.sh`; what a site must supply is scattered across `AGENTS.md` and comments. The documented way to shadow a skel file is to edit the engine's own `sync.sh`, which a pinned mounter cannot do. |

## What it costs the person who pinned this

The cheapest-looking failure is the sync: it runs before every build, on the mounter's schedule,
and its default is to delete. The engine's own primer already records one case where a node's
`.gitignore` swallowed site files because of engine directory names; the same directory names are
the `--delete` targets.

The `build` action's last-known-good fallback is honest by design (it writes a notice and reports
the SHA it built). Whether a mounter sees that notice when they are not looking is unmeasured.

## Unmeasured

- What a consumer without the engine's includes sees from a carried piece. The inertness guard now excludes pieces on purpose, so nothing in the tool catches it.
- Whether any test skips rather than fails when ruby/node/ffmpeg is absent.
- Whether the LKG notice reaches a reader who is not watching CI.
- Actual behaviour of the sync on a case-insensitive filesystem (reasoned, not run).
