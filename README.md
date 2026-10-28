# Claude Sandboxed Plus

Dockerized Claude Code with following pre-wired MCP servers:
- [Semble](https://github.com/MinishLab/semble) - semantic code search
- [MemPalace](https://github.com/mempalace/mempalace) - persistent AI memory
- [Headroom](https://github.com/headroomlabs-ai/headroom) - token-compression proxy (**optional**, see run flags)

One shared image, no per-project configuration: login once, then any project works
with `./run.sh <project-dir>`.

Also packaged as a [dev container Feature](https://containers.dev/implementors/features/) with
per-project state, see below. `run.sh` will be rewritten on top of it.

Created with the help of coffee, 8-bit gaming music, and Claude.


## Requirements

- Docker
- Bash 4+
- Git config in `~/.config/git/` (mounted read-only into the container)
- [Dev Container CLI](https://github.com/devcontainers/cli) (`devcontainer`) for the Feature


## Repo layout

| File                                                         | Purpose                                                                          |
|--------------------------------------------------------------|----------------------------------------------------------------------------------|
| `Dockerfile`                                                 | Image: Python slim, Claude Code, semble + mempalace                              |
| `run.sh`                                                     | Build/run/clean wrapper: Defines all volumes and mounts                          |
| `.devcontainer/`                                             | CSP's own dev container: develops the Feature straight from `src/claude-sp/`     |
| `.github/workflows/publish.yaml`                             | Publishes `src/claude-sp/` to ghcr on merge to `main` (new versions only)        |
| `src/claude-sp/`                                             | Dev container Feature: `devcontainer-feature.json` + `install.sh`                |
| `src/claude-sp/assets/entrypoint.sh`                         | Container startup: Registers MCP servers, auto-initializes MemPalace per project |
| `src/claude-sp/assets/etc_claude-code_CLAUDE.md`             | Managed guidance (immutable): semble/mempalace/memory discipline                 |
| `src/claude-sp/assets/etc_claude-code_managed-settings.json` | Managed policy (immutable): deny list + MemPalace/Semble discipline hooks        |
| `src/claude-sp/assets/home_dot-claude_settings.json`         | User-tier permissions (mutable): semble/mempalace tools run without prompts      |
| `src/claude-sp/assets/install-claude-statusline.sh`          | Build-time helper that installs [claude-statusline](https://github.com/felipeelias/claude-statusline) |
| `src/claude-sp/assets/hooks/semble-enforce.sh`               | PreToolUse hook (immutable): soft-warns before curl/WebFetch to external repos   |
| `examples/ansible/`                                          | Example Feature setup: compose with Claude sandbox + disposable Ubuntu target    |


## Dev container Feature

`src/claude-sp/` packages the same setup as a dev container Feature, so each project picks its own
base image and tools. Usage and required project config: `src/claude-sp/NOTES.md`.

Differences to `run.sh`:
- State per project: `<project>-claude` (sessions, settings, login, MCP registrations) + `<project>-mempalace`
- Login once per project with `claude auth login`, no host-side files
- Semble + MemPalace models baked into the image, indexes container-local (rebuilt in seconds)
- No Headroom (`run.sh --with-headroom` only)

CSP itself:
```bash
devcontainer up --workspace-folder .        # + --remove-existing-container after config changes
devcontainer exec --workspace-folder . bash
```

Updating claude/semble/mempalace needs an uncached rebuild:
```bash
$ docker pull python:3.14-slim && devcontainer up --workspace-folder . --remove-existing-container --build-no-cache
```

Other projects use the published Feature (example: `examples/ansible/`):
```jsonc
"features": { "ghcr.io/mclang/claude-sp/claude-sp:0": {} }
```

Releasing: bump `version` in `src/claude-sp/devcontainer-feature.json` in the PR. Merging to `main`
publishes it; an unchanged version is skipped.


## run.sh (shared state)

### First-time setup

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


### Daily use

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
- `--with-headroom`/`-H`: include Headroom proxy in the build
    - The choice is remembered in a `.with-headroom` marker so that Docker-reclaimed image rebuilds the same way
    - Auto-enables Output Shaper (10% holdout) via `.bashrc`
    - Use with `--build`, otherwise no-op!
- `--clean`/`-c`: deletes image and **all** named volumes

Sessions persist _per project_ until named volumes are deleted with `--clean`.
When inside container, use either normal `claude --continue` or `hrc --continue`
if using Headroom to resume the latest session.

Each project auto-initializes MemPalace on its first container start. This creates
two files, `entities.json` and `mempalace.yaml`, into the project directory, both
of which should be added either to global or the project's own `.gitignore`.

**NOTE:** a leftover `mempalace.yaml` from an earlier palace skips the auto-mine **if** MemPalace
data volume also exists already! MemPalace still works though but memory starts empty. Delete the
file or run `mempalace mine` by hand inside the container to re-mine all the project files.


### What persists (named volumes)

| Volume                    | Path in container     | Contents |
|---------------------------|-----------------------|----------|
| `claude-sp_claude-data`   | `~/.claude`           | Settings + permissions, session transcripts, `semble-search` sub-agent, MCP-configured marker |
| `claude-sp_mempalace-data`| `~/.mempalace`        | MemPalace memory palace (persistent AI memory) |
| `claude-sp_chroma-data`   | `~/.cache/chroma`     | ChromaDB's ONNX embedding-model cache (vector store itself lives in mempalace-data) |
| `claude-sp_semble-cache`  | `~/.cache/semble`     | Semble code-search indexes |
| `claude-sp_hf-cache`      | `~/.cache/huggingface`| HuggingFace model cache |
| `claude-sp_headroom-data` | `~/.headroom`         | Headroom savings ledger + proxy logs (only populated when built with `--with-headroom`) |


### Clean/Reset/Troubleshooting

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


## Security

- Runs as a non-privileged user `claude` (`run.sh`: host UID; Feature: next free UID, remapped to host's on Linux)
- `--cap-drop ALL` + `no-new-privileges` (Feature sets only the latter, projects add `cap-drop` themselves)
- Bash wrapper allows `claude` to run only from a project root directly under `/workspace/`
    - **NOTE:** This is just a convenience guard against accidental misplacement, **NOT a security boundary**!
- Git config is mounted read-only, no SSH keys enter the container
- Managed policy in `/etc/claude-code/` (root-owned, 444) that denies e.g `git commit/push/fetch/pull`
- Same directory has `CLAUDE.md` that is not editable or overridable by `claude`

**NOTE:** With `run.sh`, MemPalace memory, semble indexes, and login are shared across ALL projects!


## Verify

Inside Container Bash shell:
- Both `semble savings` and `mempalace status` show information
- Same for `headroom savings` if installed

Inside Claude Code:
- `/mcp` - `semble` and `mempalace` show as connected
- Ask *"use semble to find where MCP servers are registered"* - expect `file:line` results, no downloads
- Ask *"check mempalace status"* - expect drawer counts, no errors

---

