#!/usr/bin/env bash
# Runs on every container start (`postStartCommand`):
# - registers MCP servers once
# - initializes MemPalace per project.
set -euo pipefail

# Bump version to force re-configuration on existing containers (e.g. when adding a new MCP server).
# NOTE: Bumping version does NOT help if CHANGING EXISTING registrations!
# Registrations (`$CLAUDE_CONFIG_DIR/.claude.json`) and marker are both on the claude volume.
CLAUDE_MCP_CONFIGURED="$HOME/.claude/.mcp-configured-v1"

MEMPALACE_PALACE_DIR="$HOME/.mempalace/palace"

configure_mcp() {
    # NOTE: declared separately because `local x=$(cmd)` would mask cmd's exit status (shellcheck SC2155)
    local mcp_servers
    mcp_servers=$(claude mcp list)
    # `--scope user` registers the servers for ALL projects; default `local` scope would be per-project only.
    # Semble `--content all` indexes also docs/config files, not just code (default `--content code`).
    echo "$mcp_servers" | grep -q "^semble:"    || claude mcp add --scope user semble semble -- --content all
    echo "$mcp_servers" | grep -q "^mempalace:" || claude mcp add --scope user mempalace mempalace-mcp -- --palace "$MEMPALACE_PALACE_DIR"
    touch "$CLAUDE_MCP_CONFIGURED"
}

[[ -f "$CLAUDE_MCP_CONFIGURED" ]] || configure_mcp

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

