# Claude Sandboxed Plus

Dockerized Claude Code with following pre-wired MCP servers:
- [Semble](https://github.com/MinishLab/semble) — semantic code search
- [MemPalace](https://github.com/mempalace/mempalace) — persistent AI memory
- [Headroom](https://github.com/headroomlabs-ai/headroom) — token-compression proxy (**optional**, see run flags)

One shared image, no per-project configuration: login once, then any project works
with `./run.sh <project-dir>`.

Created with the help of coffee, 8-bit gaming music, and Claude.


## Requirements

- Docker
- Bash 4+
- Git config in `~/.config/git/` (mounted read-only into the container)


## Repo layout

| File                              | Purpose                                                                          |
|-----------------------------------|----------------------------------------------------------------------------------|
| `Dockerfile`                      | Image: Python slim, Claude Code, semble + mempalace                              |
| `run.sh`                          | Build/run/clean wrapper: Defines all volumes and mounts                          |
| `assets/entrypoint.sh`            | Container startup: Registers MCP servers, auto-initializes MemPalace per project |
| `assets/CLAUDE-container-user.md` | Seeds user-level `CLAUDE.md`: When Claude should reach for semble/mempalace, etc |
| `assets/claude-settings.json`     | Seeds permissions: Allow Semble/Mempalace tools run without prompts, git limits  |


## First-time setup

Build and start container:
```bash
chmod +x run.sh
./run.sh --build [--no-cache] [--with-headroom] <path-to-project>
```

Inside the container, authenticate once:

```bash
claude login
```

Login tokens and other Claude configuration (incl. MCP registrations) persist in _host side mount_
(`~/.local/share/claude-sp/`) that is shared across all projects and survive `./run.sh --clean`.


## Daily use

```bash
./run.sh <path-to-project>
...
claude@<container-id>:/workspace/<project>$ claude [--continue]
```

Options:
- `--build`/`-b`: force-rebuilds the image
- `--no-cache`: rebuild from scratch (`--no-cache --pull`)
    - Refreshes **all** unpinned packages (claude, semble, mempalace, headroom) and the base image
    - Re-initializes Semble model, so extra slow
    - Use with `--build`, otherwise no-op!
- `--with-headroom`/`-H`: include Headroom proxy in the build. Use with `--build`, otherwise no-op!
- `--clean`/`-c`: deletes image and **all** named volumes

Sessions persist per project until named volumes are deleted with `--clean`.
Use `claude --continue` inside the container to resume the latest session, or use session hash.

Each project auto-initializes MemPalace on its first container start. This drops `mempalace.yaml` and
`entities.json` into the project directory, both of which should be added to the project's `.gitignore`.

**NOTE:** a leftover `mempalace.yaml` from an earlier palace skips the auto-mine! Memory still works
but starts empty. Delete the file or run `mempalace mine` inside the container to re-mine project files.


## What persists (named volumes)

| Volume                    | Path in container     | Contents |
|---------------------------|-----------------------|---|
| `claude-sp_claude-data`   | `~/.claude`           | Settings + permissions, session transcripts, global `CLAUDE.md`, `semble-search` sub-agent, MCP-configured marker |
| `claude-sp_mempalace-data`| `~/.mempalace`        | MemPalace memory palace |
| `claude-sp_chroma-data`   | `~/.cache/chroma`     | ChromaDB vector store |
| `claude-sp_semble-cache`  | `~/.cache/semble`     | Semble code-search indexes |
| `claude-sp_hf-cache`      | `~/.cache/huggingface`| HuggingFace model cache |
| `claude-sp_headroom-data` | `~/.headroom`         | Headroom savings ledger + proxy logs (only populated when built with `--with-headroom`) |


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
- Full reset needs also `rm -rf ~/.local/share/claude-sp/`, which deletes claude login. This does **NOT**
  reset MCP registrations by itself — see below.
- The MCP servers are registered only once per `claude-data` volume, gated by a marker
  (`~/.claude/.mcp-configured-v1`) on that volume — a **different** location from `.claude.json`
  (`~/.local/share/claude-sp/`, deleted above). Deleting `.claude.json` alone leaves the marker in place,
  so the entrypoint skips re-registration and `/mcp` shows nothing connected. Delete the marker too
  (or run `--clean`, which wipes the whole `claude-data` volume) to force re-registration.
- To drop and re-register ONE server, run `claude mcp remove <name>` inside the container, then also
  delete the marker so the entrypoint re-adds it on the next start.
- Edits to the seeded `~/.claude` files reach an existing `claude-data` volume only via `--clean` or a manual copy


## Verify

Inside Container Bash shell:
- Both `semble savings` and `mempalace status` show information
- Same for `headroom savings` if installed

Inside Claude Code:
- `/mcp` — `semble` and `mempalace` show as connected
- Ask *"use semble to find where MCP servers are registered"* — expect `file:line` results, no downloads
- Ask *"check mempalace status"* — expect drawer counts, no errors

---

