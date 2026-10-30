#!/usr/bin/env bash
#
# Script for building/updating/starting devcontainer of given directory (default: current dir).
#
set -euo pipefail

TITLE="Starting"
UPDATE=0
UPDATE_ARGS=()
TARGET_DIR="."

usage() {
    echo ""
    echo "USAGE: $(basename "$0") [--rebuild|--update] [dir]"
    echo "  (none)      Start existing container as is, or build missing one using cache"
    echo "  --rebuild   Recreate container using cache, apply changes in 'devcontainer.json', 'compose.yaml', etc"
    echo "  --update    Upgrade container: pull base image and rebuild without cache, updates CSP Feature, etc"
    echo "  dir         Project directory (default: current directory)"
    echo ""
    exit "${1:-0}"
}

while (( $# )); do
    case "$1" in
        --rebuild)  TITLE="Rebuilding"; UPDATE_ARGS=(--remove-existing-container) ;;
        --update)   TITLE="Updating";   UPDATE_ARGS=(--remove-existing-container --build-no-cache); UPDATE=1 ;;
        --help|-h)  usage ;;
        -*)         echo "ERROR: Unknown option: '$1'"; usage 1 ;;
        *)          TARGET_DIR="$1" ;;
    esac
    shift
done

TARGET_DIR=$(cd "$TARGET_DIR" && pwd -P)

echo "### $TITLE Devcontainer for '$TARGET_DIR' ###"

# Plain `devcontainer up --build-no-cache` pulls the base image only for "build" type devcontainers
# that use simple Dockerfile, whereas "image" based ones like CSP's own devcontainer can be pulled
# after the image name is resolved using devcontainer CLI below.
# Compose based ones like 'examples/ansible' need manual pulling.
if (( UPDATE )); then
    echo "- Upgrading Feature versions in 'devcontainer-lock.json'"
    devcontainer upgrade --workspace-folder "$TARGET_DIR"

    IMAGE=$(devcontainer read-configuration --workspace-folder "$TARGET_DIR" | jq -r '.configuration.image // empty')
    if [[ -n "$IMAGE" ]]; then
        echo "- Pulling '$IMAGE'"
        docker pull "$IMAGE"
    else
        echo "- NOTE: No 'image' in config. Docker compose setups need their 'FROM' image pulled by hand!"
    fi
fi

echo "- Running 'devcontainer up' for '$TARGET_DIR'"
devcontainer up --workspace-folder "$TARGET_DIR" "${UPDATE_ARGS[@]}"
echo "==> DONE"
echo ""
echo "Next steps:"
echo "- Open bash:               'devcontainer-run.sh $TARGET_DIR'"
echo "- Continue Claude session: 'devcontainer-run.sh -c $TARGET_DIR'"
echo ""

