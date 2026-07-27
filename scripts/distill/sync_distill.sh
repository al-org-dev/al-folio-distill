#!/usr/bin/env bash
set -euo pipefail

# Sync vendored Distill runtime assets from a pinned upstream ref.
#
# Default upstream source:
#   https://github.com/al-org-dev/distill-template.git (branch: al-folio)
#
# Usage:
#   scripts/distill/sync_distill.sh [upstream-ref]
#
# Examples:
#   scripts/distill/sync_distill.sh
#   scripts/distill/sync_distill.sh <commit-sha>

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/al-org-dev/distill-template.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-al-folio}"
DEFAULT_UPSTREAM_REF="d907ccdb526166c615f53487ec01e92e92f28f46"
UPSTREAM_REF="${1:-${UPSTREAM_REF:-$DEFAULT_UPSTREAM_REF}}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

git clone --quiet --depth 1 --branch "${UPSTREAM_BRANCH}" "${UPSTREAM_REPO}" "${TMP_DIR}/distill-template"
pushd "${TMP_DIR}/distill-template" >/dev/null

# Ensure deterministic vendoring from an explicit ref.
git fetch --quiet --depth 1 origin "${UPSTREAM_REF}"
git checkout --quiet "${UPSTREAM_REF}"

OUT_DIR="${ROOT}/assets/js/distillpub"
mkdir -p "${OUT_DIR}"
cp dist/template.v2.js "${OUT_DIR}/template.v2.js"
cp dist/template.v2.js.map "${OUT_DIR}/template.v2.js.map"
cp dist/transforms.v2.js "${OUT_DIR}/transforms.v2.js"
cp dist/transforms.v2.js.map "${OUT_DIR}/transforms.v2.js.map"
cp dist/overrides.js "${OUT_DIR}/overrides.js"

SOURCE_COMMIT="$(git rev-parse HEAD)"
SOURCE_COMMIT_SHORT="$(git rev-parse --short HEAD)"
popd >/dev/null

TEMPLATE_SHA256="$(shasum -a 256 "${OUT_DIR}/template.v2.js" | awk '{print $1}')"
TRANSFORMS_SHA256="$(shasum -a 256 "${OUT_DIR}/transforms.v2.js" | awk '{print $1}')"
SYNCED_AT_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# The upstream Polyfills transform re-injects the Distill runtime from a
# hard-coded remote origin with no subresource integrity, which discards the
# vendored copy we just pinned. Report the real state instead of assuming it.
REMOTE_LOADER_URL="https://distill.pub/template.v2.js"
if grep -qF "${REMOTE_LOADER_URL}" "${OUT_DIR}/transforms.v2.js"; then
  REMOTE_LOADER_PATCHED="false"
else
  REMOTE_LOADER_PATCHED="true"
fi

cat > "${OUT_DIR}/provenance.json" <<JSON
{
  "upstream_repo": "${UPSTREAM_REPO}",
  "upstream_branch": "${UPSTREAM_BRANCH}",
  "upstream_ref": "${SOURCE_COMMIT}",
  "upstream_ref_short": "${SOURCE_COMMIT_SHORT}",
  "synced_at_utc": "${SYNCED_AT_UTC}",
  "toolchain": {
    "sync_mode": "copy-dist-artifacts"
  },
  "remote_loader_patched": ${REMOTE_LOADER_PATCHED},
  "local_patches": [
    "overrides.js: de-jQuery the load handler (\$(window).on('load', ...) -> window.addEventListener('load', ...)); jQuery is not loaded in al-folio v1. Port this upstream so the next sync preserves it.",
    "transforms.v2.js: the Polyfills transform re-injected the runtime from a hard-coded remote distill.pub template URL with no SRI, discarding the vendored copy. It now re-injects window.alFolioDistill.templateLoader (vendored + integrity-pinned by default), falling back to the same-origin src of the tag it removed. Port this upstream so the next sync preserves it."
  ],
  "assets": {
    "template.v2.js": "${TEMPLATE_SHA256}",
    "transforms.v2.js": "${TRANSFORMS_SHA256}",
    "overrides.js": "$(shasum -a 256 "${OUT_DIR}/overrides.js" | awk '{print $1}')"
  }
}
JSON

echo "Synced Distill runtime from ${UPSTREAM_REPO}@${SOURCE_COMMIT}"
echo "Updated assets in ${OUT_DIR}"

if [ "${REMOTE_LOADER_PATCHED}" = "false" ]; then
  cat >&2 <<MSG

ERROR: ${OUT_DIR}/transforms.v2.js still hard-codes ${REMOTE_LOADER_URL}.

The synced ref reintroduced the unpinned remote Distill loader, so Distill pages
would fetch the runtime from a third-party origin with no subresource integrity
instead of the vendored copy. Land the loader patch listed under "local_patches"
in ${UPSTREAM_REPO} (${UPSTREAM_BRANCH}) and re-sync, or re-apply it by hand and
refresh the digests in provenance.json.
MSG
  exit 1
fi
