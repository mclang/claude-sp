---
name: validate-docs
description: Cross-check Dockerfile, run.sh, and assets/* against README.md and TODO.md for drift. Use before committing, or after adding/renaming a flag, volume, or asset.
---

Read `Dockerfile`, `run.sh`, `README.md`, `TODO.md`, and all COMMITTED files in `assets/`
directory (`git ls-files assets/`). Skip reading files already read fresh during this session.

Validate documentation against actual behavior before calling it a match.
Fix found drift issues only after the user agrees to the proposed changes.
Keep documentation and comments short, simple and to the point.


## run.sh ↔ README.md
- Every `claude_sp_usage()` flag → in README "Options" list.
- Every `--build`-only "modifier" flag → in BOTH the pre-scan loop AND main-loop no-op case.
- `DOCKER_VOLUMES` (name, path, description) → matches "What persists" table.
- `CLAUDE_STATE_DIR` marker files (e.g. `.with-headroom`) → mentioned in README where relevant.

## Dockerfile ↔ README.md
- Every `COPY`'d `assets/*` file → a "Repo layout" row, with correct mutable/immutable label.
- `--with-headroom` behavior → matches README (opt-in, build-time, needs `--build`).
- User-facing `.bashrc` env vars (`HEADROOM_*`) → reflected in README if README claims that behavior.

## Dockerfile ↔ run.sh ↔ README.md
- `mkdir -p` mount points (Dockerfile) → cover every `DOCKER_VOLUMES` path (run.sh), character-for-character.

## assets/entrypoint.sh ↔ README.md
- MCP marker path (`.mcp-configured-vN`) → matches Troubleshooting section.
- mempalace stale-yaml skip behavior → matches README's NOTE.
- `configure_mcp()` server list → matches README's volume table + Verify section.

## Dockerfile ↔ assets/entrypoint.sh
- `HOME`-relative paths entrypoint.sh touches → pre-created by Dockerfile's `mkdir -p`.

## Any assets/*install-*.sh ↔ the settings file it configures
- Its `statusLine.command` (or equivalent) → matches what the install script actually installs.
- Version/checksum pins → one checksum per architecture the script handles.

## Any other assets/* file
- Referenced somewhere (Dockerfile `COPY` or another asset) + has a "Repo layout" row.

## TODO.md
- Any item now implemented in a COMMITTED file (even an untested sketch) → status updated, not left stale.
- Uncommitted/untracked files don't count because they are invisible to anyone else using this repo.

## Output

Group by pair. State match/drift/missing per claim. Skip padding — if a pair's clean, say so in one line.

