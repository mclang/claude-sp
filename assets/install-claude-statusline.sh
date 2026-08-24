#!/usr/bin/env bash
# Script for installing and configuring 'claude-statusline':
# https://github.com/felipeelias/claude-statusline
set -euo pipefail

# Get the checksums for 'VERSION' from:
# https://github.com/felipeelias/claude-statusline/releases
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64) SHA256="d8310cb9dbd60f87daa9407a9017fab973d8651dffb4eb7b9c2a695a69b118dd" ;;
    arm64) SHA256="7df87185e42340a6f7f4cf776718890bb5d8ec5ccaaccb62121e734507570175" ;;
    *) echo "ERROR: unsupported architecture '$ARCH'!" >&2; exit 1 ;;
esac
VERSION="0.9.0"
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

[usage]
disabled = false
format = '{{.BlockBar}} {{printf "%.0f" .BlockPct}}% ({{.BlockResets}})'
TOML

echo "==> DONE"

