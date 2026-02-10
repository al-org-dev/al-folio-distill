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
