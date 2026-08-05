#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$BASH_SOURCE")")
CONTAINER_PREFIX="Claude-SP"
DOCKER_IMAGE="claude-sp"
CLAUDE_STATE_DIR="$HOME/.local/share/$DOCKER_IMAGE"
CLAUDE_CONF_FILE="$CLAUDE_STATE_DIR/.claude.json"       # Shared config/state incl. user-scoped MCP registrations
CLAUDE_CRED_FILE="$CLAUDE_STATE_DIR/.credentials.json"  # Shared OAuth tokens written by `claude login`
GIT_XDG_CONF_DIR="${HOME}/.config/git"
TARGET_PROJECT_DIR=""

if (( "${BASH_VERSINFO[0]}" < 4 )); then
    echo "ERROR: bash 4+ required (current: $BASH_VERSION)"
    exit 1
fi

declare -A DOCKER_VOLUMES=(
    ["${DOCKER_IMAGE}_claude-data"]="/home/claude/.claude"          # Claude Code state: settings, MCP config, session transcripts
    ["${DOCKER_IMAGE}_mempalace-data"]="/home/claude/.mempalace"    # MemPalace memory palace (persistent AI memory)
    ["${DOCKER_IMAGE}_chroma-data"]="/home/claude/.cache/chroma"    # ChromaDB vector store used by MemPalace
    ["${DOCKER_IMAGE}_semble-cache"]="/home/claude/.cache/semble"   # Semble code-search indexes (keyed by repo path)
    ["${DOCKER_IMAGE}_hf-cache"]="/home/claude/.cache/huggingface"  # HuggingFace model cache (semble embedding model ~60-80MB)
)


claude_sp_build() {
    echo ""
    echo "BUILDING 'Claude Sandboxed Plus' (image name: '$DOCKER_IMAGE') ..."
    docker build \
        --build-arg UID="$(id -u)" \
        --build-arg GID="$(id -u)" \
        -t "$DOCKER_IMAGE" \
        "$SCRIPT_DIR"
    echo "==> DONE"
    echo ""
}

claude_sp_clean() {
    echo ""
    echo "DELETING 'Claude Sandboxed Plus' image and related volume mounts..."
    docker image rm "$DOCKER_IMAGE" || true
    for vol_name in "${!DOCKER_VOLUMES[@]}"; do
        docker volume rm "$vol_name" || true
    done
    echo "==> DONE"
    echo "Run 'rm -rf $CLAUDE_STATE_DIR' manually to delete also Claude config and login"
    echo ""
    exit 0
}

claude_sp_usage() {
    echo ""
    echo "USAGE: $(basename "$0") [--build|--clean] <project-dir>"
    echo ""
    echo "  --build, -b   Force rebuild of the Docker image"
    echo "  --clean, -c   Delete Docker image and mount volumes"
    echo "  <project-dir> Directory to mount as the Claude Code project"
    echo ""
    exit 0
}


for arg in "$@"; do
    case "$arg" in
        --build|-b) claude_sp_build ;;
        --clean|-c) claude_sp_clean ;;
        --help|-h)  claude_sp_usage ;;
        -*)
            echo "ERROR: Unknown option: '$arg'"
            claude_sp_usage
            ;;
        *)
            if [[ -n "$TARGET_PROJECT_DIR" ]]; then
                echo "ERROR: only one project directory allowed"
                claude_sp_usage
            fi
            TARGET_PROJECT_DIR="$arg"
            ;;
    esac
done

[[ -z "$TARGET_PROJECT_DIR" ]] && { claude_sp_usage; }
[[ -d "$TARGET_PROJECT_DIR" ]] || { echo "ERROR: '$TARGET_PROJECT_DIR' is not a directory"; exit 1; }

# Resolve absolute project directory path and Docker-safe container/mount name using `tr`.
# Strip trailing `-` from the name that `tr` makes from `basename`'s trailing newline.
TARGET_PROJECT_DIR=$(realpath "$TARGET_PROJECT_DIR")
TARGET_PROJECT_NAME=$(basename "$TARGET_PROJECT_DIR" | tr -cs 'a-zA-Z0-9_.-' '-')
TARGET_PROJECT_NAME="${TARGET_PROJECT_NAME%-}"

# Build Docker image if it does not exist already (needs to be below above project dir checks!):
docker image inspect "$DOCKER_IMAGE" &>/dev/null || claude_sp_build

# Initialize Claude state files.
# They MUST exist BEFORE `docker run`, otherwise Docker creates them as directories.
# Restrictive permissions because both hold sensitive data.
mkdir -p "$CLAUDE_STATE_DIR"
for FL in "$CLAUDE_CONF_FILE" "$CLAUDE_CRED_FILE"; do
    [[ -f "$FL" ]] || echo '{}' > "$FL"
    chmod 600 "$FL"
done

NAMED_VOLUME_ARGS=()
for VNAME in "${!DOCKER_VOLUMES[@]}"; do
    NAMED_VOLUME_ARGS+=(-v "${VNAME}:${DOCKER_VOLUMES[$VNAME]}")
done

exec docker run --rm -it \
    --name "${CONTAINER_PREFIX}-${TARGET_PROJECT_NAME}" \
    --cap-drop ALL \
    --security-opt no-new-privileges:true \
    -v "${CLAUDE_CONF_FILE}:/home/claude/.claude.json" \
    -v "${CLAUDE_CRED_FILE}:/home/claude/.claude/.credentials.json" \
    -v "${GIT_XDG_CONF_DIR}:/home/claude/.config/git:ro" \
    "${NAMED_VOLUME_ARGS[@]}" \
    -v "${TARGET_PROJECT_DIR}:/workspace/${TARGET_PROJECT_NAME}" \
    -w "/workspace/${TARGET_PROJECT_NAME}" \
    "$DOCKER_IMAGE"

