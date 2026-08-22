# Orientation

This repository is the **Journal engine**: the shared, content-less Jekyll machinery a civic node
mounts at `.journal-engine/` to render its own self-hosted public record. It ships layouts,
includes, plugins, assets, `skel/` boilerplate, and `bin/` build scripts — never articles. A
mounting site supplies content under `journal/`, where disk path == URL path, and the engine
enriches each piece with per-paragraph git history generated into `_data/`. It carries no role in
the federation lifecycle — it is how a node *publishes*, not how it federates.

## Where the truth is, in reading order

1. **Demos before docs.** The constellation's capability index is the demo shelf in
   [`anecdote.channel`](https://github.com/FCCN-ANTIBODY/anecdote.channel) (`composer/*-demo.html`,
   `viewer/`, `git-enough/`, `reducer/demo.mjs` — its `AGENTS.md` carries the table). This engine
   has no standalone demo: it is exercised by building a mounting site (`bin/serve.sh` /
   `bin/build.sh` from a site root, e.g. civic-node). `widget/public.html` is the one
   self-contained viewable fragment — the baked, dormant baseline widget.
2. **Open issues are urgent** — a live problem with the current implementation, ahead of the
   deferred backlog. Roadmapping lives in the documents (civic-node `VISION.md`), not in issues.
3. **The deferred half lives in one place** — civic-node
   [`OPEN-QUESTIONS.md`](https://github.com/FCCN-ANTIBODY/civic-node/blob/main/OPEN-QUESTIONS.md).
4. **The consumer defines correctness.** civic-node's `AGENTS.md` ("engines are hidden; content is
   canonical") is the other half of this file: site-specific assets are *synced in from here* at
   build time — change the engine, never the synced copies downstream.

## The offline origin is the destination

Capability is migrating off GitHub and down to the operator's device (the anecdote.channel PWA —
which even carries `jekyll-enough/`, a vendorless in-browser counterpart to this build). The
composite actions here (`build`, `build-intermediates`, `advance-engine`, `advance-submodules`,
`widget`) are being
**kept as a declarative definition of the publish pipeline** — a configuration input an operator
or the offline origin can read and mirror — not as the presumed runtime. Support them; don't
deepen reliance on them.

## Where intuition goes wrong here

- **This is an engine, not a site.** There is no `.github/workflows/` here on purpose — mounting
  nodes `uses:` the composite actions. There is also no README; the excludes in `_config.yml`
  anticipate a mounting site's files.
- **Config layering is the contract.** A site's `_config.yml` layers over the engine's
  (`--config eng/_config.yml,_config.yml`); the `journal` key is simultaneously the content dir,
  the URL base, and the `_data`/git namespace.
- **The `publish` → `journal` mount migration is half-done.** `_config.yml` says the old
  `publish` indirection is gone, but `_plugins/antibody.rb` still reads and defaults to
  `"publish"`. Don't take either side as settled without checking the consumer; finishing the
  migration means fixing the plugin *and* the doc-comments together.
- **The widget convention is bake-time.** `widget/public.html` is the static dataless baseline a
  node embeds by bumping this submodule's pin; the data-filled fragment is rendered by
  `.github/actions/widget` in the *node's* build — never live-fetched.

## Built here — reuse, don't rebuild

`bin/build.sh` / `bin/serve.sh` / `bin/sync.sh` (engine-asset sync into a site root),
`bin/stats.sh` + `bin/stat-*` (per-piece git-history `_data` generation), `_plugins/antibody.rb`
(internal-url data keys, soft link-downgrade), `_plugins/piece-citation.rb` (`{% raw_include %}`),
`bin/build-intermediates` (the portable form of what a journal has cut — arrangement and
recorded pins, never prose), and the composite actions `build` (with `try_latest` +
last-known-good fallback), `build-intermediates`, `advance-engine`, `advance-submodules`,
`widget`.

`build-intermediates` is the clearest example of the glove: the action writes into the
repository wearing it, never into this one, and what it emits is INERT — front matter plus
plain markdown, no template syntax — so a consumer needs to trust nothing to render it.
It carries the cited pieces as well as the arrangement, because the tier above bakes the
issues and has to see the letters. A carried piece is reduced: the keys that DESCRIBE it
travel (title, author, date, tags) and the claims on a URL SPACE do not (permalink,
redirect_from, redirect_to), because those belong to whichever site first published it and
nothing was ever moved. The layout goes too — a piece must not have to know who is
publishing it.

A carried piece may contain NO template syntax, and `build-intermediates` refuses rather than
warns. This is not about portability. A mounting site evaluates what it is handed, so a
piece's `{% include %}` would run in THAT site's build, against ITS includes, ITS plugins and
ITS filesystem, before anything is served — which puts it out of reach of any content policy,
because no browser is involved. A contributor writes the letter; they do not get to run a step
in the newsroom's build. Refusing at ejection is the gate doing its job: an editor is present
in the author's own repository, and nobody is present at the tier above.
