#!/usr/bin/env bash
# Registers MCP servers via Claude Code CLI on first run, then execs the container command.
set -euo pipefail

# Bump version to force re-configuration on existing containers (e.g. when adding a new MCP server).
# NOTE: Bumping version does not help if CHANGING existing registrations!
# ==> delete `.claude.json` or run `claude mcp remove <name>` to start fresh.
MCP_CONFIGURED_MARKER="$HOME/.claude/.mcp-configured-v1"

MEMPALACE_SHARED="$HOME/.mempalace/palace"

configure_mcp() {
    # NOTE: declared separately because `local x=$(cmd)` would mask cmd's exit status (shellcheck SC2155)
    local mcp_servers
    mcp_servers=$(claude mcp list)
    # `--scope user` registers the servers for ALL projects; default `local` scope would be per-project only
    echo "$mcp_servers" | grep -q "^semble:"    || claude mcp add --scope user semble semble
    echo "$mcp_servers" | grep -q "^mempalace:" || claude mcp add --scope user mempalace mempalace-mcp -- --palace "$MEMPALACE_SHARED"
    touch "$MCP_CONFIGURED_MARKER"
}

[[ -f "$MCP_CONFIGURED_MARKER" ]] || configure_mcp

# Initialize MemPalace for the current project if not yet tracked (`mempalace init` creates `mempalace.yaml`).
# - `mempalace.yaml`: Lives in project dir, survives `--clean`
# - `chroma.sqlite3`: Lives in MemPalace data volume, deleted when `--clean` is run.
# ==> Run `mempalace init` if EITHER file is missing
[[ -f "$PWD/mempalace.yaml" && -f "${MEMPALACE_SHARED}/chroma.sqlite3" ]] || mempalace init --yes --auto-mine --no-llm "$PWD"

exec "$@"

