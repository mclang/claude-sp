#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$BASH_SOURCE")")

IMAGE="claude-sp"
CONTAINER_PREFIX="Claude-SP"

usage() {
    echo "Usage: $(basename "$0") [--build] <project-dir>"
    echo ""
    echo "  --build, -b   Force rebuild of the Docker image"
    echo "  <project-dir> Directory to mount as the Claude Code project"
    exit 1
}

BUILD=0
PROJECT_DIR=""

for arg in "$@"; do
    case "$arg" in
        --build|-b) BUILD=1 ;;
        -h|--help) usage ;;
        -*)
            echo "Unknown option: $arg"
            usage
            ;;
        *)
            if [[ -n "$PROJECT_DIR" ]]; then
                echo "Error: only one project directory allowed"
                usage
            fi
            PROJECT_DIR="$arg"
            ;;
    esac
done

[[ -z "$PROJECT_DIR" ]] && { usage; }
[[ -d "$PROJECT_DIR" ]] || { echo "Error: '$PROJECT_DIR' is not a directory"; exit 1; }

PROJECT_DIR=$(realpath "$PROJECT_DIR")
PROJECT_NAME=$(basename "$PROJECT_DIR" | tr -cs 'a-zA-Z0-9_.-' '-')

if [[ "$BUILD" -eq 1 ]] || ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Building '$IMAGE' ..."
    docker build \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -g)" \
        -t "$IMAGE" \
        "$SCRIPT_DIR"
fi

# Auth file lives on the host, shared across all projects
CLAUDE_AUTH="$HOME/.local/share/$IMAGE/.claude.json"
mkdir -p "$(dirname "$CLAUDE_AUTH")"
[[ -f "$CLAUDE_AUTH" ]] || touch "$CLAUDE_AUTH"

exec docker run --rm -it \
    --name "${CONTAINER_PREFIX}-${PROJECT_NAME}" \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    -v "${PROJECT_DIR}:/workspace/${PROJECT_NAME}" \
    -v "${CLAUDE_AUTH}:/home/claude/.claude.json" \
    -v "${IMAGE}-claude-data:/home/claude/.claude" \
    -v "${IMAGE}-mempalace:/home/claude/.mempalace" \
    -v "${IMAGE}-chroma:/home/claude/.cache/chroma" \
    -w "/workspace/${PROJECT_NAME}" \
    "$IMAGE"

