## Choosing a setup

For simple projects needing only one container, use plain `devcontainer.json` (image mode) like
this repo does. See minimal config below.

For larger projects that need more than one container, e.g database or server with `root`/`sudo`
access for testing things, add also `compose.yaml` and related files like `.env` that are then
used to build the whole devcontainer stack. See `examples/ansible/` in this repo, where
`test-target` lives in its own container and gets accessed over SSH with an empty password.


## Minimal project config

Image mode, plain `devcontainer.json`:

```jsonc
{
    "image": "python:3.13-slim",                    // Feature uses `apt-get` -> Debian/Ubuntu needed
    "features": {
        "ghcr.io/mclang/claude-sp/claude-sp:0": {}
    },
    "remoteUser": "claude",                         // Feature installs everything for this user
    "runArgs": ["--cap-drop=ALL"],                  // Security: Feature sets `no-new-privileges` but can't drop capabilities
    // Feature `.bashrc` guard: `claude` refuses to start outside '/workspace/<project>'
    "workspaceMount": "source=${localWorkspaceFolder},target=/workspace/${localWorkspaceFolderBasename},type=bind",
    "workspaceFolder": "/workspace/${localWorkspaceFolderBasename}",
    "mounts": [
        // Per-project state: sessions, login, MCP registrations and memory
        "source=${localWorkspaceFolderBasename}-claude,target=/home/claude/.claude,type=volume",
        "source=${localWorkspaceFolderBasename}-mempalace,target=/home/claude/.mempalace,type=volume"
    ]
}
```

Compose: same things in `compose.yaml` + `devcontainer.json`, see `examples/ansible/`.

Additional Notes:
- Add `mempalace.yaml` and `entities.json` to `.gitignore` (created on first start)
- Log in once per project with `claude auth login` or `/login` inside Claude


## Sandbox Security

Feature installs these as root-owned read-only files in `/etc/claude-code`:
- `CLAUDE.md`: Guardrails like _no file edits without user confirmation_ and general directions
- Denied commands: `git commit/push/fetch/pull`
- Hooks: MemPalace writes on Stop/SessionEnd/PreCompact, Semble reminder before any WebFetch or curl to repos

In addition Feature sets `no-new-privileges` internally but `--cap-drop=ALL` (compose: `cap_drop: [ALL]`)
must be done at project side like shown in the above example.

**NOTE:** Do NOT give devcontainer the host Docker socket to manage containers itself!

That is **sure** way to escape the sandbox and basically could give `root` access to the host!

---

