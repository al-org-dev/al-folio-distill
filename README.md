# al-folio-distill

`al_folio_distill` provides Distill support for `al-folio` v1.x.

## What it provides

- Distill layout renderer tag: `{% al_folio_distill_render %}`
- Distill templates/includes for `layout: distill`
- Distill runtime assets under `/assets/js/distillpub/*`
- Distill stylesheet at `/assets/css/al-folio-distill.css`

## Installation

```ruby
gem 'al_folio_distill'
```

```yaml
plugins:
  - al_folio_distill
al_folio:
  features:
    distill:
      enabled: true
```

`al_folio_core` delegates Distill rendering to this plugin.

## Vendored runtime policy

This gem ships prebuilt Distill runtime assets for end users (no npm at gem-install time).

- Source of truth: `al-org-dev/distill-template` (`al-folio` branch)
- Sync script: `scripts/distill/sync_distill.sh`
- Provenance metadata: `assets/js/distillpub/provenance.json`

Refresh assets:

```bash
./scripts/distill/sync_distill.sh
# or pin a specific ref
./scripts/distill/sync_distill.sh <commit-sha>
```

The sync script records the real digests in `provenance.json` and fails if the
synced ref reintroduces the hard-coded remote Distill loader (see below).

## Runtime loading policy

Distill pages load the runtime from the vendored copy under
`/assets/js/distillpub/`, with `integrity` pinned to the SHA-256 digests
committed in `provenance.json`. Upstream's `Polyfills` transform removes the
page's template tag and re-adds it; the vendored copy is patched so it re-adds
the vendored URL rather than a hard-coded `distill.pub` one.

Loading the runtime from a third-party origin is opt-in:

```yaml
al_folio:
  distill:
    engine: distillpub-template
    source: al-org-dev/distill-template#al-folio
    # Default false. When false, the runtime is only ever loaded from the
    # vendored, integrity-pinned copy.
    allow_remote_loader: false
    # Only used when allow_remote_loader is true.
    remote_loader_url: https://distill.pub/template.v2.js
    # Optional SRI for remote_loader_url. When set, the injected tag carries
    # integrity + crossorigin="anonymous". The build warns when it is missing.
    remote_loader_integrity: sha256-...
```

Keep `allow_remote_loader: false` unless you control the remote origin: whoever
serves `remote_loader_url` executes arbitrary JavaScript on every Distill page.

## Contributing

Distill runtime/template behavior belongs here. Starter-only docs/demo changes belong in `al-folio`.
