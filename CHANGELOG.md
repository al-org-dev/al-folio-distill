# Changelog

## 1.0.3 - 2026-07-27

- Security: removed the unpinned remote Distill runtime loader. The vendored `assets/js/distillpub/transforms.v2.js` shipped upstream's `Polyfills` transform, which strips the page's `template.v2.js` tag and re-injects it from a hard-coded `https://distill.pub/template.v2.js` with no subresource integrity — discarding the vendored, hash-pinned copy this gem exists to ship and handing arbitrary JS execution on every Distill page to whoever controls that origin. The transform now re-injects `window.alFolioDistill.templateLoader`, falling back to the same-origin `src` of the tag it just removed, and never falls back to a remote origin. Recorded under `local_patches` and flipped `remote_loader_patched` to `true` (port it to the upstream distill-template so a future re-sync preserves it).
- `templates/distill/render.liquid` now emits the runtime via the new `{% al_folio_distill_runtime_scripts %}` tag, which serves `template.v2.js`/`transforms.v2.js` from the vendored copy with `integrity` pinned to the SHA-256 digests committed in `provenance.json`.
- Remote loading is now explicit opt-in via `al_folio.distill.allow_remote_loader` (default `false`), with `al_folio.distill.remote_loader_url` and `al_folio.distill.remote_loader_integrity`. When an SRI hash is configured the injected tag carries `integrity` + `crossorigin="anonymous"`; the build warns when opting in without one.
- Added a build-time check that the vendored runtime on disk matches the digests pinned in `provenance.json`, so drift is reported at build time instead of failing subresource integrity in visitors' browsers.
- `scripts/distill/sync_distill.sh` now derives `remote_loader_patched` from the synced bytes instead of hard-coding `false`, preserves `local_patches`, and exits non-zero if a re-sync reintroduces the remote loader.

## 1.0.2 - 2026-06-01

- De-jQueried the vendored `assets/js/distillpub/overrides.js`. Its top-level `$(window).on("load", ...)` threw `ReferenceError: $ is not defined` on every distill page (jQuery was removed in al-folio v1), so the footnote/citation dark-theme overrides never applied and the page logged a console error. Switched to `window.addEventListener("load", ...)`; the handler body was already vanilla. Updated the pinned SHA-256 in `provenance.json` and the runtime contract test, and recorded the change under `local_patches` (port it to the upstream distill-template so a future re-sync preserves it).

## 1.0.1 - 2026-02-17

- Updated Distill scripts template to use `tabs.js` (non-minified path) instead of removed `tabs.min.js`.
- Switched back-to-top loading to the shared CDN contract (`third_party_libraries['vanilla-back-to-top']`) to avoid missing local asset lookups.

## 1.0.0

- Initial Distill extraction from `al_folio_core`.
