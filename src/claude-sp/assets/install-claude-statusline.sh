#!/usr/bin/env bash
# Script for installing and configuring 'claude-statusline':
# https://github.com/felipeelias/claude-statusline
set -euo pipefail

# Get the checksums for 'VERSION' from:
# https://github.com/felipeelias/claude-statusline/releases
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64) SHA256="162bca5336cc0e92faf4fec7722166348554930345b28a2eed858c9dfe54865e" ;;
    arm64) SHA256="f27bf4352e9a4487856792e29dca6f1815ca80d34df666a85293186925a93888" ;;
    *) echo "ERROR: unsupported architecture '$ARCH'!" >&2; exit 1 ;;
esac
VERSION="0.10.1"
PACKAGE_NAME="claude-statusline_${VERSION}_linux_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/felipeelias/claude-statusline/releases/download/v${VERSION}/${PACKAGE_NAME}"
DOWNLOAD_TMP=$(mktemp)


echo "### Installing 'claude-statusline' v${VERSION} (${ARCH}) ###"
curl -fsSL -o "$DOWNLOAD_TMP" "$DOWNLOAD_URL"

ACTUAL_SHA256=$(sha256sum "$DOWNLOAD_TMP" | cut -d ' ' -f1)
if [[ "$ACTUAL_SHA256" != "$SHA256" ]]; then
    echo "ERROR: checksum mismatch for '$PACKAGE_NAME'!" >&2
    echo "==> expected: $SHA256" >&2
    echo "==> actual:   $ACTUAL_SHA256" >&2
    rm -f "$DOWNLOAD_TMP"
    exit 1
fi

tar -xzf "$DOWNLOAD_TMP" -C "$HOME/.local/bin" claude-statusline
rm -f "$DOWNLOAD_TMP"

# Create configuration (default + usage):
mkdir -p "$HOME/.config/claude-statusline"
cat >    "$HOME/.config/claude-statusline/config.toml" <<'TOML'
format = '$directory | $git_branch | $model | $cost | context: $context | block: $usage'

[context]
bar_markers = []

[usage]
disabled = false
format = '{{.BlockBar}} {{printf "%.0f" .BlockPct}}% ({{.BlockResets}})'
TOML

echo "==> DONE"

