#!/usr/bin/env bash
# Registers MCP servers via Claude Code CLI on first run, then execs the container command.
set -euo pipefail

# Bump version to force re-configuration on existing containers (e.g. when adding a new MCP server).
# NOTE: Bumping version does not help if CHANGING existing registrations!
# ==> delete `.claude.json` or run `claude mcp remove <name>` to start fresh.
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
# - `mempalace.yaml`: Lives in project dir, survives `--clean`
# - `chroma.sqlite3`: Lives in MemPalace data volume and gets thus deleted when `--clean` is run
#
# NOTE:
# - A project with a stale `mempalace.yaml` + an already-populated palace skips mining!
# - Memory still works but starts empty and fills only through Claude's own writes.
[[ -f "$PWD/mempalace.yaml" && -f "${MEMPALACE_PALACE_DIR}/chroma.sqlite3" ]] || mempalace init --yes --auto-mine --no-llm "$PWD"

exec "$@"

