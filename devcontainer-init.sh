#!/usr/bin/env bash
#
# Script for creating minimal CSP Feature devcontainer config into given directory (default: current dir).
# Based on 'python:3.xy-slim' because MemPalace and Semble need Python.
#
set -euo pipefail

FORCE=0
IMAGE="python:3.14-slim"
TARGET_DIR="."

usage() {
    echo ""
    echo "USAGE: $(basename "$0") [--image IMG] [--force] [dir]"
    echo "  --image IMG   Base image, Debian/Ubuntu with Python 3.11 - 3.14 (default: $IMAGE)"
    echo "  --force       Overwrite existing '.devcontainer/devcontainer.json'"
    echo "  dir           Project directory (default: current directory)"
    echo ""
    exit "${1:-0}"
}

while (( $# )); do
    case "$1" in
        --force)    FORCE=1 ;;
        --image)    IMAGE="${2:?ERROR: --image needs a value!}"; shift ;;
        --help|-h)  usage ;;
        -*)         echo "ERROR: Unknown option: '$1'"; usage 1 ;;
        *)          TARGET_DIR="$1" ;;
    esac
    shift
done

TARGET_DIR=$(cd "$TARGET_DIR" && pwd -P)
CONFIG="$TARGET_DIR/.devcontainer/devcontainer.json"

echo "### Initialising Devcontainer for '$TARGET_DIR' ###"

if [[ -f "$CONFIG" ]] && (( ! FORCE )); then
    echo ""
    echo "ERROR: '$CONFIG' exists already"
    echo "- Use '--force' to overwrite"
    echo ""
    exit 1
fi

echo "- Creating '$CONFIG'"
mkdir -p "$(dirname "$CONFIG")"

# NOTES:
# - Use quoted heredoc so that Bash does not try to replace things like `${localWorkspaceFolder...}`
# - "__IMAGE__" is replaced with right value afterwards
TEMPLATE=$(cat <<'EOF'
// Minimal "Claude Sandboxed Plus" devcontainer, see:
// https://github.com/mclang/claude-sp/blob/main/src/claude-sp/NOTES.md
{
    "name": "${localWorkspaceFolderBasename}",
    "image": "__IMAGE__",
    // Extra packages need root: replace "image" with a Dockerfile, e.g:
    //   FROM __IMAGE__
    //   RUN apt-get update && apt-get install -y --no-install-recommends neovim && rm -rf /var/lib/apt/lists/*
    // "build": { "dockerfile": "Dockerfile" },
    "features": {
        "ghcr.io/mclang/claude-sp/claude-sp:0": {}
    },
    "remoteUser": "claude",
    "runArgs": ["--cap-drop=ALL", "--name=${localWorkspaceFolderBasename}"],
    "workspaceMount": "source=${localWorkspaceFolder},target=/workspace/${localWorkspaceFolderBasename},type=bind",
    "workspaceFolder": "/workspace/${localWorkspaceFolderBasename}",
    "mounts": [
        "source=${localWorkspaceFolderBasename}-claude,target=/home/claude/.claude,type=volume",
        "source=${localWorkspaceFolderBasename}-mempalace,target=/home/claude/.mempalace,type=volume",
        "source=${localEnv:HOME}/.config/git,target=/home/claude/.config/git,type=bind,readonly"
    ]
}
EOF
)

# Bash replacement instead of `sed -i`, whose syntax differs between GNU and BSD (macOS)
echo "${TEMPLATE//__IMAGE__/$IMAGE}" > "$CONFIG"

echo "==> DONE"
echo ""
echo "Next steps:"
echo "- Add 'mempalace.yaml' and 'entities.json' to '.gitignore' (will be created on first start)"
echo "- Start with: 'devcontainer-build.sh $TARGET_DIR'"
echo ""

