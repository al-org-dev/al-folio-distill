#!/usr/bin/env bash
set -euo pipefail

# Rebuild vendored Distill runtime assets from a pinned upstream ref.
#
# Default upstream source:
#   https://github.com/alshedivat/distillpub-template.git (branch: al-folio)
#
# Usage:
#   scripts/distill/sync_distill.sh [upstream-ref]
#
# Examples:
#   scripts/distill/sync_distill.sh
#   scripts/distill/sync_distill.sh a59ea36e4776ebc4cd1ce159b82cd0ec391b0ec3

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/alshedivat/distillpub-template.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-al-folio}"
DEFAULT_UPSTREAM_REF="a59ea36e4776ebc4cd1ce159b82cd0ec391b0ec3"
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

npm ci --silent
npm run build --silent

OUT_DIR="${ROOT}/assets/js/distillpub"
mkdir -p "${OUT_DIR}"
cp dist/template.v2.js "${OUT_DIR}/template.v2.js"
cp dist/template.v2.js.map "${OUT_DIR}/template.v2.js.map"
cp dist/transforms.v2.js "${OUT_DIR}/transforms.v2.js"
cp dist/transforms.v2.js.map "${OUT_DIR}/transforms.v2.js.map"

# Enforce self-contained runtime; no remote distill loader at runtime.
perl -0pi -e "s#https://distill\\.pub/template\\.v2\\.js#/assets/js/distillpub/template.v2.js#g" "${OUT_DIR}/transforms.v2.js"

SOURCE_COMMIT="$(git rev-parse HEAD)"
SOURCE_COMMIT_SHORT="$(git rev-parse --short HEAD)"
popd >/dev/null

TEMPLATE_SHA256="$(shasum -a 256 "${OUT_DIR}/template.v2.js" | awk '{print $1}')"
TRANSFORMS_SHA256="$(shasum -a 256 "${OUT_DIR}/transforms.v2.js" | awk '{print $1}')"
SYNCED_AT_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
NODE_VERSION="$(node --version)"
NPM_VERSION="$(npm --version)"

cat > "${OUT_DIR}/provenance.json" <<JSON
{
  "upstream_repo": "${UPSTREAM_REPO}",
  "upstream_branch": "${UPSTREAM_BRANCH}",
  "upstream_ref": "${SOURCE_COMMIT}",
  "upstream_ref_short": "${SOURCE_COMMIT_SHORT}",
  "synced_at_utc": "${SYNCED_AT_UTC}",
  "toolchain": {
    "node": "${NODE_VERSION}",
    "npm": "${NPM_VERSION}"
  },
  "remote_loader_patched": true,
  "assets": {
    "template.v2.js": "${TEMPLATE_SHA256}",
    "transforms.v2.js": "${TRANSFORMS_SHA256}"
  }
}
JSON

echo "Synced Distill runtime from ${UPSTREAM_REPO}@${SOURCE_COMMIT}"
echo "Updated assets in ${OUT_DIR}"
