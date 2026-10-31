#!/usr/bin/env bash
# Runs on every container start (`postStartCommand`):
# - registers missing MCP servers
# - initializes MemPalace per project.
set -euo pipefail

MEMPALACE_PALACE_DIR="$HOME/.mempalace/palace"

# Reads `.claude.json` directly b/c `claude mcp list` health-checks every server (takes ~7s).
mcp_status() { jq -e --arg s "$1" '.mcpServers[$s]' "$CLAUDE_CONFIG_DIR/.claude.json" &>/dev/null; }

# NOTES:
# - Use `--scope user` so that servers work in ANY directory of the container (default `local` binds them to one path)
# - Semble `--content all` indexes also docs/config files, not just code (default `--content code`)
# - Existing registrations are NOT changed. Run `claude mcp remove <name>` and restart to start with new args
mcp_status semble    || claude mcp add --scope user semble semble -- --content all
mcp_status mempalace || claude mcp add --scope user mempalace mempalace-mcp -- --palace "$MEMPALACE_PALACE_DIR"

# Initialize MemPalace for the current project if not yet tracked.
# - `mempalace.yaml`: Lives in project dir
# - `chroma.sqlite3`: Lives in MemPalace volume
#
# NOTES:
# - A project with a stale `mempalace.yaml` file but an already-populated palace
#   (initialized for other project) skips mining for the project!
#   ==> Memory still works but starts empty and fills only through Claude's hook writes.
if [[ ! -f "$PWD/mempalace.yaml" || ! -f "${MEMPALACE_PALACE_DIR}/chroma.sqlite3" ]]; then
    mempalace init --yes --no-llm "$PWD" </dev/null
    mempalace mine "$PWD"
fi

