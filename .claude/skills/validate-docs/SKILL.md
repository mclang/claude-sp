---
name: validate-docs
description: Cross-check the Feature (src/claude-sp/), devcontainer-*.sh scripts and examples against README.md and NOTES.md for drift. Use before committing, or after adding/renaming an option, volume, asset or example.
---

Read `README.md`, `devcontainer-*.sh` and all COMMITTED files in `src/claude-sp/`, `examples/`, `.devcontainer/`
and `.github/workflows/` directories. Skip reading files already read fresh during this session.

Validate documentation against actual behavior before calling it a match.
Fix found drift issues only after the user agrees to the proposed changes.
Keep documentation and comments short, simple and to the point.


## Repo layout (README)
- Every script, top-level directory, example and workflow -> a row, descriptions still true.
- Every asset -> referenced by `install.sh` or another asset; `etc_*`/`home_*` names match their install path
  (`etc_claude-code_X` -> `/etc/claude-code/X`, `home_dot-claude_X` -> `~/.claude/X`).

## install.sh <-> README.md + NOTES.md
- Claims about what is baked into the image or updated by `--update` (tools, models) -> match `install.sh`.
- Version pins (pip packages, image digest, download checksums) -> one per architecture handled, and
  README update instructions still true.

## devcontainer-feature.json <-> README.md + NOTES.md
- `containerEnv`, `securityOpt`, `postStartCommand` -> match README "Security" and NOTES claims.
- Options (if any) -> documented with defaults.

## Volumes (README "What persists" + NOTES minimal config)
- Mount points -> pre-created by `install.sh`'s `mkdir -p` so that volumes get `claude` owner.
- NOTES example `mounts` -> same volumes and paths as README table.

## entrypoint.sh <-> README.md
- Troubleshooting claims (MCP registration, seeded files, stale `mempalace.yaml`) -> match actual logic.
- Registered MCP servers -> match README volume table + Verify section.
- `HOME`-relative paths it touches -> pre-created by `install.sh` or created by the tools themselves.

## Managed policy <-> registered tools
- Tool names in managed `CLAUDE.md`, `settings.json` allow list and hooks -> exist in registered MCP servers / installed CLIs.
- Settings files' commands (e.g. `statusLine.command`) -> installed by `install.sh` or its helpers.

## devcontainer-*.sh <-> README.md
- Every `usage()` flag and default -> matches README "Usage" script block.
- Required host tools (e.g. `jq`, Bash version features) -> in README "Requirements".

## Feature version
- Any committed change under `src/claude-sp/` since the last `feature_claude-sp_*` tag -> `version` bumped,
  otherwise the publish workflow skips it.

## examples/ + .devcontainer/ <-> NOTES.md
- Required project config (`remoteUser`, `--cap-drop=ALL`, `/workspace/<project>`, volumes) -> present.

## Output

Group by pair. State match/drift/missing per claim. Skip padding - if a pair's clean, say so in one line.

