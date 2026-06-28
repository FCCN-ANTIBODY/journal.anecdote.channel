# `widget` — render this node's data-filled Journal fragment from its own identity

A composite GitHub Action that renders the **data-filled** Journal widget fragment into the
**calling node's** workspace. It is the live counterpart to the baked baseline at
[`widget/public.html`](../../../widget/public.html): that file is a static, **dataless**
shell a node picks up by bumping this submodule's pin; this action renders the **same
fragment contract** (same `anecdote-widget` classes, same dormant `anecdote:widget:`
postMessage API — a host can't tell which build it got) **from the node's on-disk identity**,
so it carries the node's own journal locator QR. The bundled `bin/widget` is the **code**;
the node's `_config.yml` is the **data** — so any node that drops this in renders a locator to
**its own** journal, never the template's.

## A first-party locator, not a hub stem

The QR this bakes is a **first-party direct locator** — and that is the whole contrast with
[`tell`'s widget](https://github.com/fccn-antibody/tell.anecdote.channel/tree/main/.github/actions/widget).
A tell is cross-jurisdictional, so its QR hands a **geo-less stem** to a **shared hub** that
fills the scanner's state and redirects. A journal is the opposite posture: it is **this
node's own public record**, self-hosted on the node's **own domain** under the `journal`
mount (CONSTITUTION / AGENTS: *first-party claims beat hearsay*). So this QR carries no hub
and no redirect — it points straight at:

```
<url>/<journal>/
```

the node's own site, where `url` is the published origin and `journal` is the URL base (both
read from the node's `_config.yml`). It resolves the same everywhere, because it is the
node standing behind its own record.

qrencode bakes the QR as **inline SVG** at build time — no runtime JS, no external request.
Without qrencode the fragment degrades to a plain text link, so a node build never breaks.

## Use it

In your node's site build (the workspace mounts this engine at `.journal-engine/`, the same
submodule-path convention as `./.journal-engine/.github/actions/build`), render the fragment
before the site build that includes it:

```yaml
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Render this node's Journal widget
        uses: ./.journal-engine/.github/actions/widget   # reads _config.yml -> widget/journal.html
      - name: Build
        uses: ./.journal-engine/.github/actions/build
```

The fragment is written as a **self-contained static file** served at `/widget/journal.html` —
it stays out of the engine-managed `_includes/`, so the node build never couples to the
engine's include resolution. A host embeds it the way the baseline is meant to be embedded:
load it in an `<iframe>` (the dormant `anecdote:widget:` postMessage API exists exactly for
that cross-frame handshake) or include the served file verbatim into a host page.

## Inputs

| input | default | meaning |
| --- | --- | --- |
| `url` | *(read from `config`)* | the node's published origin (an http(s) URL); falls back to `url:` in the config file |
| `mount` | *(read from `config`)* | the journal URL base; falls back to `journal:` in the config file, else `journal` |
| `config` | `_config.yml` | path in the calling workspace to the node's site config (provides `url` + `journal` mount) |
| `out` | `widget/journal.html` | path in the calling workspace to write the fragment to (a self-contained static file, served at that path) |
| `install-qrencode` | `true` | apt-install qrencode (set `false` if already present) |

It **fails closed**: with no config file and no explicit `url` it refuses rather than render
the wrong node — the same contract as tell's `widget` and `register` actions.
