# al-folio-distill

Distill runtime/plugin extraction for al-folio v1.x.

## What it provides

- Distill layout renderer tag: `{% al_folio_distill_render %}`
- Distill templates/includes used by `layout: distill`
- Packaged Distill JS runtime under `/assets/js/distillpub/*`
- Packaged Distill stylesheet at `/assets/css/al-folio-distill.css`

## Usage

Add the gem and plugin:

```ruby
gem 'al_folio_distill'
```

```yml
plugins:
  - al_folio_distill
al_folio:
  features:
    distill:
      enabled: true
```

`al_folio_core` delegates `layout: distill` rendering to this plugin.

## Vendored Distill runtime policy

This gem ships prebuilt Distill runtime assets for end users (no npm step at gem install time).

- Source of truth: `alshedivat/distillpub-template` (`al-folio` branch)
- Sync script: `scripts/distill/sync_distill.sh`
- Provenance metadata: `assets/js/distillpub/provenance.json`
- Runtime parity policy: vendored runtime hashes are pinned to match `al-folio` `main`
  snapshots carried by the upstream `al-folio` branch

Refresh vendored assets:

```bash
./scripts/distill/sync_distill.sh
# or pin a specific ref
./scripts/distill/sync_distill.sh <commit-sha>
```
