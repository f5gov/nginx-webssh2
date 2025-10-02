#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/fetch-webssh2-release.sh <version> [destination]

Downloads the published WebSSH2 release artifact and extracts it into the
local workspace. The script expects releases to follow the tag pattern
"webssh2-server-v<version>" and to expose assets named
"webssh2-<version>.tar.gz" with a matching ".sha256" checksum file.

Arguments:
  <version>     WebSSH2 semantic version (e.g., 2.4.0)
  [destination] Optional extraction directory (default: vendor/webssh2)
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "error: version is required" >&2
  usage
  exit 1
fi

VERSION="$1"
DEST_DIR="${2:-vendor/webssh2}"
REPO="${WEBSSH2_REPO:-billchurch/webssh2}"
TAG="${WEBSSH2_TAG:-webssh2-server-v${VERSION}}"
ASSET_NAME="webssh2-${VERSION}.tar.gz"
ASSET_URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET_NAME}"
CHECKSUM_URL="${ASSET_URL}.sha256"
TOKEN="${GITHUB_TOKEN:-}" # optional auth

WORK_DIR="$(pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CURL_ARGS=("-fL")
if [[ -n "${TOKEN}" ]]; then
  CURL_ARGS+=("-H" "Authorization: Bearer ${TOKEN}")
  CURL_ARGS+=("-H" "Accept: application/octet-stream")
fi

printf 'Fetching WebSSH2 %s from %s\n' "${VERSION}" "${REPO}"

printf 'Downloading %s ... ' "${ASSET_URL}"

curl "${CURL_ARGS[@]}" -o "${TMP_DIR}/${ASSET_NAME}" "${ASSET_URL}"
curl "${CURL_ARGS[@]}" -o "${TMP_DIR}/${ASSET_NAME}.sha256" "${CHECKSUM_URL}"

if command -v sha256sum >/dev/null 2>&1; then
  (cd "${TMP_DIR}" && sha256sum --check "${ASSET_NAME}.sha256")
elif command -v shasum >/dev/null 2>&1; then
  (cd "${TMP_DIR}" && shasum -a 256 -c "${ASSET_NAME}.sha256")
else
  echo "warning: no sha256sum or shasum available; skipping checksum verification" >&2
fi

rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"
tar -xzf "${TMP_DIR}/${ASSET_NAME}" -C "${DEST_DIR}" --strip-components=0

printf 'WebSSH2 %s extracted to %s\n' "${VERSION}" "${DEST_DIR}"
