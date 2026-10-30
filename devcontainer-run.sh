#!/usr/bin/env bash
#
# Script for opening bash or Claude in already started devcontainer of given directory (default: current dir).
#
set -euo pipefail

CMD=(bash)
TARGET_DIR="."

usage() {
    echo ""
    echo "USAGE: $(basename "$0") [--continue] [dir]"
    echo "  (none)          Open bash"
    echo "  --continue, -c  Continue latest Claude session"
    echo "  dir             Project directory (default: current directory)"
    echo ""
    exit "${1:-0}"
}

while (( $# )); do
    case "$1" in
        --continue|-c)  CMD=(claude --continue) ;;
        --help|-h)      usage ;;
        -*)             echo "ERROR: Unknown option: '$1'"; usage 1 ;;
        *)              TARGET_DIR="$1" ;;
    esac
    shift
done

TARGET_DIR=$(cd "$TARGET_DIR" && pwd -P)

# Check that devcontainer is running
# devcontainer CLI labels its containers with the host folder
if [[ -z "$(docker ps -q --filter "label=devcontainer.local_folder=$TARGET_DIR")" ]]; then
    echo ""
    echo "ERROR: No running devcontainer for '$TARGET_DIR'"
    echo "- Start it with: 'devcontainer-build.sh $TARGET_DIR'"
    echo ""
    exit 1
fi

exec devcontainer exec --workspace-folder "$TARGET_DIR" "${CMD[@]}"

