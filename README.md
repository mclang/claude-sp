# Claude Sandboxed Plus

Sandboxed Claude Code as a [dev container Feature](https://containers.dev/implementors/features/)
with following pre-wired MCP servers:
- [Semble](https://github.com/MinishLab/semble) - semantic code search
- [MemPalace](https://github.com/mempalace/mempalace) - persistent AI memory

Each project picks its own base image and tools, and gets its own state: sessions, login and memory.

Created with the help of coffee, 8-bit gaming music, and Claude.


## Requirements

- Docker
- [Dev Container CLI](https://github.com/devcontainers/cli) (`devcontainer`)
- Bash 4.4+ and `jq` for the helper scripts
- Git config in `~/.config/git/` (mounted read-only into the container)


## Repo layout

| Path                    | Purpose                                                                          |
|-------------------------|----------------------------------------------------------------------------------|
| `devcontainer-init.sh`  | Creates minimal CSP Feature devcontainer config for a project                    |
| `devcontainer-build.sh` | Starts/rebuilds/updates a project's devcontainer                                 |
| `devcontainer-run.sh`   | Opens bash (or continues Claude) in a project's running devcontainer             |
| `src/claude-sp/`        | Feature: `install.sh`, `NOTES.md`, `assets/entrypoint.sh` (MCP + MemPalace init) |
| `src/claude-sp/assets/` | Files installed into the image, e.g. `etc_claude-code_X` -> `/etc/claude-code/X` |
| `examples/`             | Example setups, e.g. `ansible`: compose with Claude sandbox + Ubuntu test target |
| `.devcontainer/`        | CSP's own dev container: develops the Feature straight from `src/claude-sp/`     |
| `.claude/skills/`       | Project skills for Claude, e.g. `validate-docs`                                  |
| `.github/workflows/`    | Publishes the Feature to ghcr on merge to `main` (new versions only)             |


## Usage

Projects can use the published Feature through devcontainer features.
See `src/claude-sp/NOTES.md` for the required config and `examples/ansible/` for a compose setup:
```jsonc
"features": { "ghcr.io/mclang/claude-sp/claude-sp:0": {} }
```

Helper scripts, all take project `[dir]` as last argument (default: current directory):
```bash
./devcontainer-init.sh <path-to-project>    # Initialise minimal devcontainer config
./devcontainer-build.sh                     # Start container. Use `--rebuild` after config changes or `--update` for updating all
./devcontainer-run.sh                       # Exec bash. Use `--continue` for latest Claude session
```

Log in once per project with `claude auth login` or `/login` inside claude.

Each project auto-initializes MemPalace on its first container start. This creates `entities.json`
and `mempalace.yaml` into the project directory, which both should be added into `.gitignore`.

Releasing new CSP Feature version:

Bump `version` in `src/claude-sp/devcontainer-feature.json` and make a PR. Merging it to `main`
publishes the Feature that devcontainers can pull. An unchanged version is skipped.


### What persists (named volumes)

| Volume                | Path in container | Contents                                                                      |
|-----------------------|-------------------|-------------------------------------------------------------------------------|
| `<project>-claude`    | `~/.claude`       | Settings, login, session transcripts, MCP registrations, `semble-search` sub-agent |
| `<project>-mempalace` | `~/.mempalace`    | MemPalace memory palace                                                       |

Semble + MemPalace models are baked into the image, indexes are container-local (rebuilt in seconds).


### Troubleshooting

- Missing MCP servers are registered on every container start. To re-register one, e.g. with changed
  arguments, run `claude mcp remove <name>` and restart the container.
- Seeded `settings.json` and `semble-search` sub-agent reach the claude volume only when it is created.
  Managed policy (`/etc/claude-code/`) is not in a volume, `--rebuild` (CSP) or `devcontainer-build.sh --update` (published Feature) updates it.
- A leftover `mempalace.yaml` skips the auto-mine **if** the MemPalace volume exists already: memory
  starts empty. Delete the file or run `mempalace mine .` by hand.


## Security

- Runs as a non-privileged user `claude` (next free UID, remapped to host's on Linux)
- `no-new-privileges` set by the Feature, projects add `--cap-drop=ALL` themselves
- Bash wrapper allows `claude` to run only from a project root directly under `/workspace/`
    - **NOTE:** This is just a convenience guard against accidental misplacement, **NOT a security boundary**!
- Git config is mounted read-only, no SSH keys enter the container
- Managed policy in `/etc/claude-code/` (root-owned, 444) that denies e.g `git commit/push/fetch/pull`
- Same directory has `CLAUDE.md` that is not editable or overridable by `claude`


## Verify

Inside container Bash shell:
- Both `semble savings` and `mempalace status` show information

Inside Claude Code:
- `/mcp` - `semble` and `mempalace` show as connected
- Ask *"use semble to find where MCP servers are registered"* - expect `file:line` results, no downloads
- Ask *"check mempalace status"* - expect drawer counts, no errors

---

