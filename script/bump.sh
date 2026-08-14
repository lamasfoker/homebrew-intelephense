#!/bin/bash
# Rewrites Formula/intelephense.rb in place:
#   - pins the intelephense npm tarball to the latest published version
#   - re-pins the vendored Node.js runtime (darwin-arm64 + darwin-x64) to the current LTS
#
# Usage: script/bump.sh
# Exits 0 with no changes if everything is already current; prints what changed to stdout.
set -euo pipefail

formula="Formula/intelephense.rb"
cd "$(dirname "$0")/.."

changed=0

# --- intelephense itself -----------------------------------------------------------------
latest_version=$(curl -fsSL https://registry.npmjs.org/intelephense/latest | jq -r '.version')
current_version=$(grep -m1 'intelephense-' "$formula" | sed -E 's/.*intelephense-([0-9A-Za-z.+-]+)\.tgz.*/\1/')

if [ "$latest_version" != "$current_version" ]; then
  tarball_url="https://registry.npmjs.org/intelephense/-/intelephense-${latest_version}.tgz"
  tarball_sha256=$(curl -fsSL "$tarball_url" | shasum -a 256 | awk '{print $1}')

  perl -0pi -e "s{url \"https://registry\.npmjs\.org/intelephense/-/intelephense-[^\"]+\.tgz\"}{url \"${tarball_url}\"}" "$formula"
  perl -0pi -e "s{(url \"https://registry\.npmjs\.org/intelephense/-/intelephense-${latest_version//./\\.}\.tgz\"\n  sha256 \")[^\"]+(\")}{\${1}${tarball_sha256}\${2}}" "$formula"

  echo "intelephense: ${current_version} -> ${latest_version}"
  changed=1
fi

# --- vendored Node.js LTS runtime ---------------------------------------------------------
lts_line=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version')
current_node=$(grep -m1 'node-v' "$formula" | sed -E 's/.*node-v([0-9.]+)-darwin.*/\1/')

if [ "v${current_node}" != "$lts_line" ]; then
  node_version="${lts_line#v}"
  shasums=$(curl -fsSL "https://nodejs.org/dist/${lts_line}/SHASUMS256.txt")

  for arch_pair in "arm64:on_arm" "x64:on_intel"; do
    arch="${arch_pair%%:*}"
    tarball="node-v${node_version}-darwin-${arch}.tar.gz"
    url="https://nodejs.org/dist/${lts_line}/${tarball}"
    sha=$(echo "$shasums" | grep "$tarball" | awk '{print $1}')

    perl -0pi -e "s{node-v[0-9.]+-darwin-${arch}\.tar\.gz\"\n        sha256 \"[0-9a-f]+\"}{node-v${node_version}-darwin-${arch}.tar.gz\"\n        sha256 \"${sha}\"}" "$formula"
  done

  echo "node (vendored LTS): v${current_node} -> ${lts_line}"
  changed=1
fi

if [ "$changed" -eq 0 ]; then
  echo "Already up to date."
fi

echo "changed=${changed}" >> "${GITHUB_OUTPUT:-/dev/null}"
