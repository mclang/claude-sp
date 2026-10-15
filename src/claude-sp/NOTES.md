## Choosing a setup

For simple projects needing only one container, use plain `devcontainer.json` (image mode) like
this repo does. See this repo's `.devcontainer/` for bare bones example.

For larger projects that need more than one container, e.g database or server with `root`/`sudo`
access for testing things, add also `compose.yaml` and related files like `.env` that are then
used to build the whole devcontainer stack. See `examples/ansible/` in this repo, where
`test-target` lives in its own container and gets accessed over SSH with an empty password.

**NOTE:** Do NOT give devcontainer the host Docker socket to manage containers itself!
That is sure way to escape the sandbox and basically could give `root` access to the host!

## Required project config

- `"remoteUser": "claude"`
- Two volumes for Claude state and memory, e.g:
  - `<project>-claude`    -> `/home/claude/.claude`
  - `<project>-mempalace` -> `/home/claude/.mempalace`
- Host login files bind-mounted to `~/.claude.json` and `~/.claude/.credentials.json`
  (see `.devcontainer/devcontainer.json` in this repo)

