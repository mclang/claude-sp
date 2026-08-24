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

| File                                          | Purpose                                                                          |
|-----------------------------------------------|----------------------------------------------------------------------------------|
| `Dockerfile`                                  | Image: Python slim, Claude Code, semble + mempalace                              |
| `run.sh`                                      | Build/run/clean wrapper: Defines all volumes and mounts                          |
| `assets/entrypoint.sh`                        | Container startup: Registers MCP servers, auto-initializes MemPalace per project |
| `assets/etc_claude-code_CLAUDE.md`            | Managed guidance (immutable): semble/mempalace/memory discipline                 |
| `assets/etc_claude-code_managed-settings.json`| Managed deny list (immutable): blocks `git commit/push/fetch/pull`               |
| `assets/home_dot-claude_settings.json`        | User-tier permissions (mutable): semble/mempalace tools run without prompts      |
| `assets/install-claude-statusline.sh`         | Build-time helper that installs [claude-statusline](https://github.com/felipeelias/claude-statusline) |


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
|---------------------------|-----------------------|----------|
| `claude-sp_claude-data`   | `~/.claude`           | Settings + permissions, session transcripts, `semble-search` sub-agent, MCP-configured marker |
| `claude-sp_mempalace-data`| `~/.mempalace`        | MemPalace memory palace |
| `claude-sp_chroma-data`   | `~/.cache/chroma`     | ChromaDB vector store |
| `claude-sp_semble-cache`  | `~/.cache/semble`     | Semble code-search indexes |
| `claude-sp_hf-cache`      | `~/.cache/huggingface`| HuggingFace model cache |
| `claude-sp_headroom-data` | `~/.headroom`         | Headroom savings ledger + proxy logs (only populated when built with `--with-headroom`) |


## Security

- Runs as a non-privileged user (`claude`, UID from host; GID = UID as a private group)
- `--cap-drop ALL` + `--security-opt no-new-privileges`
- Bash wrapper allows `claude` to run only from a project root directly under `/workspace/`
    - **NOTE:** This is just a convenience guard against accidental misplacement, **NOT a security boundary**!
- Git config is mounted read-only, no SSH keys enter the container
- Managed policy in `/etc/claude-code/` (root-owned, 444) that denies e.g `git commit/push/fetch/pull`
- Same directory has `CLAUDE.md` that is not editable or overridable by `claude`

**NOTE:** MemPalace memory, semble indexes, and login are shared across ALL projects!


## Clean/Reset/Troubleshooting

```bash
./run.sh --clean
./run.sh --build <path-to-project>
```

**NOTES:**
- Full reset needs also `rm -rf ~/.local/share/claude-sp/`, which deletes claude login but still
  does **NOT** reset MCP registrations by itself (see below).
- The MCP servers are registered only once per `claude-data` volume, gated by a marker (`~/.claude/.mcp-configured-v1`)
  on that volume, which is a **different** location than `.claude.json` (`~/.local/share/claude-sp/`, deleted above).
  Deleting `.claude.json` alone leaves the marker in place, so the entrypoint skips re-registration
  and `/mcp` shows nothing connected. Delete the marker too (or run `--clean`) to force re-registration.
- To drop and re-register ONE server, run `claude mcp remove <name>` inside the container and
  delete the marker so that the entrypoint re-adds it on the next start.
- Edits to the seeded `settings.json` reach an existing `claude-data` volume only via `--clean` or a manual copy.
  Managed policy (`/etc/claude-code/`) isn't volume-seeded at all, it always needs a complete rebuild.
- Headroom's _Output Shaper_ + _CCR_ can produce `API Error: API returned an empty or malformed response (HTTP 200)`
  once a session grows large enough to hit Claude Code's own auto-compaction. Most
  straightforward solution is to either start a new session or disable functionality.


## Verify

Inside Container Bash shell:
- Both `semble savings` and `mempalace status` show information
- Same for `headroom savings` if installed

Inside Claude Code:
- `/mcp` — `semble` and `mempalace` show as connected
- Ask *"use semble to find where MCP servers are registered"* — expect `file:line` results, no downloads
- Ask *"check mempalace status"* — expect drawer counts, no errors

---

