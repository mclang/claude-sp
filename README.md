# Claude Sandboxed Plus

Dockerized Claude Code with two pre-wired MCP servers:
- [Semble](https://github.com/MinishLab/semble) — semantic code search (embedding model baked into the image)
- [MemPalace](https://github.com/mempalace/mempalace) — persistent AI memory

One shared image, no per-project configuration: login once, then any project works
with `./run.sh <project-dir>`.

Created with the help of coffee, 8-bit gaming music, and Claude.


## Requirements

- Docker
- Bash 4+
- Git config in `~/.config/git/` (mounted read-only into the container)


## Repo layout

| File | Purpose |
|---|---|
| `Dockerfile` | Image: Python slim, Claude Code, semble + mempalace |
| `run.sh` | Build/run/clean wrapper; defines all volumes and mounts |
| `assets/entrypoint.sh` | Container startup: registers MCP servers, auto-initializes MemPalace per project |
| `assets/CLAUDE-container-user.md` | Seeded user-level `CLAUDE.md`: when Claude should reach for semble/mempalace |
| `assets/claude-settings.json` | Seeded permissions: semble/mempalace tools run without prompts |


## First-time setup

Build and start container:
```bash
chmod +x run.sh
./run.sh --build <path-to-project>
```

Inside the container, authenticate once:

```bash
claude login
```

Login tokens and Claude config (incl. MCP registrations) persist in host side mount that is
shared across all projects and survive `./run.sh --clean`.


## Daily use

```bash
./run.sh <path-to-project>  # → bash shell in /workspace/<project-name>; run `claude` there
```

Options:
- `--build`/`-b`: force-rebuilds the image
- `--clean`/`-c`: deletes image and volumes.

Sessions persist per project until named volumes are deleted with `--clean`.
Use `claude --continue` inside the container to resume the latest session, or use session hash.

Each project auto-initializes MemPalace on its first container start. This drops `mempalace.yaml`
and `entities.json` into the project directory. Both should be added to the project's `.gitignore`

**NOTE:** a leftover `mempalace.yaml` from an earlier palace skips the auto-mine! Memory still works
but starts empty. Delete the file or run `mempalace mine` inside the container to re-mine project files.


## What persists (named volumes)

| Volume | Path in container | Contents |
|---|---|---|
| `claude-sp_claude-data` | `~/.claude` | Settings + permissions, session transcripts, global `CLAUDE.md`, `semble-search` sub-agent, MCP-configured marker |
| `claude-sp_mempalace-data` | `~/.mempalace` | MemPalace memory palace |
| `claude-sp_chroma-data` | `~/.cache/chroma` | ChromaDB vector store |
| `claude-sp_semble-cache` | `~/.cache/semble` | Semble code-search indexes |
| `claude-sp_hf-cache` | `~/.cache/huggingface` | HuggingFace model cache |


## Security

- Runs as a non-privileged user (`claude`, UID from host; GID = UID as a private group)
- `--cap-drop ALL` + `--security-opt no-new-privileges`
- Bash wrapper allows `claude` to run only from a project root directly under `/workspace/`.
  This is just a convenience guard against accidental misplacement, NOT a security boundary.
- Git config is mounted read-only, no SSH keys enter the container

**NOTE:** MemPalace memory, semble indexes, and login are shared across ALL projects!


## Clean/Reset/Troubleshooting

```bash
./run.sh --clean
./run.sh --build <path-to-project>
```

**NOTE:**
- Full reset needs also `rm -rf ~/.local/share/claude-sp/`, which deletes claude login and MCP registrations
- To reset ONLY MCP registrations, run `claude mcp remove <name>` inside the container
- Edits to the seeded `~/.claude` files reach an existing `claude-data` volume only via `--clean` or a manual copy


## Verify

Inside Claude Code:
- `/mcp` — `semble` and `mempalace` show as connected
- Ask *"use semble to find where MCP servers are registered"* — expect `file:line` results, no downloads
- Ask *"check mempalace status"* — expect drawer counts, no errors

