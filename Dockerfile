# Use a modern Python slim image as the foundation for Semble and MemPalace
FROM python:3.13-slim

# Prevent interactive prompts during initial apt installations
ARG DEBIAN_FRONTEND=noninteractive

# Chain everything heavy into a SINGLE RUN command to minimize layer size
# - Use `--no-install-recommends` to block unnecessary suggested packages
# - Use `--no-cache-dir` so pip doesn't save raw downloads
# - Uninstall build compilers after pip is done
# - Clean up the apt cache to make layer even smaller
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        curl \
        git \
        jq \
        procps \
        ripgrep \
        sqlite3 \
        build-essential \
    && pip install --no-cache-dir "semble[mcp]" mempalace \
    && apt-get purge -y --auto-remove build-essential \
    && apt-get install -y --no-install-recommends libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-privileged `claude` group and user.
# Defaults (1000) are overridden by `run.sh` via `--build-arg` to match the host user's UID,
# which ensures that the files created on the mounted volumes are owned by the correct host user.
ARG UID=1000
ARG GID=1000
RUN groupadd -g "${GID}" claude && useradd -m -s "/bin/bash" -u "${UID}" -g "${GID}" claude

# Create root-owned 'Managed Claude Code' policy directory for global 'CLAUDE.md' and deny
# permissions which CANNOT be changed inside the container by ANY user.
RUN mkdir -p "/etc/claude-code"

# NOTE: changing `HOME` here requires also `ENTRYPOINT` change!
ENV HOME="/home/claude"
ENV PATH="$HOME/.local/bin:$PATH"
ENV PYTHONUNBUFFERED=1
USER claude


### Claude Code and related setup
# Using `https://claude.ai/install.sh` installs native binary in `$HOME/.local/bin`:
RUN curl -fsSL https://claude.ai/install.sh | bash

# claude-statusline with default config
# https://github.com/felipeelias/claude-statusline
ARG STATUSLINE_PKG_URL="https://github.com/felipeelias/claude-statusline/releases/download"
RUN curl -fsSL "${STATUSLINE_PKG_URL}/v0.9.0/claude-statusline_0.9.0_linux_$(dpkg --print-architecture).tar.gz" | tar -xz -C "$HOME/.local/bin" claude-statusline


### Extra Bash configuration for the container user:
RUN cat <<'EOF' >> "$HOME/.bashrc"

# Restrict Claude to immediate subdirectories of `/workspace`.
# Needed to prevent information leakage in case `.claude` gets created somewhere else than what is sandboxed
function claude() {
    if [[ "$(dirname "$PWD")" != "/workspace" ]]; then
        echo ""
        echo "ERROR: Claude execution blocked."
        echo "Claude must be run from a project root."
        echo "Valid locations: /workspace/<any-project-dir>"
        return 1
    fi
    command claude "$@"
}

alias la='ls -A  -F --color=auto --group-directories-first'
alias ll='ls -ho -F --color=auto --group-directories-first'
alias mount='mount | grep -Ev "^(overlay|tmpfs|proc|sysfs|devtmpfs|devpts|cgroup|mqueue|shm)"'

# Notify user if Headroom Proxy is available.
# Enable "Output token reduction" with 10% holdout control group to get better 'headroom output-savings' estimations.
# NOTES:
# - Using "Output Shaper" and/or(?) "Compress-Cache-Retrieve" (CCR) might start producing errors like
#   "API Error: API returned an empty or malformed response (HTTP 200) — check for a proxy or gateway intercepting the request"
#   when session context grows big enough and native Claude compression kicks in.
# - Using 'headroom wrap' bypasses above 'claude' function restriction !!!
if command -v headroom &>/dev/null; then
    alias hrc='headroom wrap -- claude'
    # export HEADROOM_NO_CCR=1
    export HEADROOM_OUTPUT_SHAPER=1
    export HEADROOM_OUTPUT_HOLDOUT=0.1
    echo "NOTE: This container includes 'Headroom Proxy' (https://github.com/headroomlabs-ai/headroom)"
    echo "- Use it by starting claude session with 'headroom wrap -- claude <parameters>' (alias: 'hrc')"
    echo "- Run 'headroom learn --verbosity --all --apply' ONCE after using headroom for a while to set verbosity baseline for output shaper"
    echo "- Check performance and savings using 'headroom perf', 'headroom savings --days 30' and 'headroom output-savings'"
    echo ""
fi
EOF


# Pre-create CONTAINER side volume mount points so Docker initializes named volumes using right owner.
# NOTE: Keep these in line with what is used in `entrypoint.sh` and `run.sh` scripts!
RUN mkdir -p "$HOME/.claude" "$HOME/.config" "$HOME/.mempalace" "$HOME/.cache/chroma" "$HOME/.cache/semble" "$HOME/.cache/huggingface" "$HOME/.headroom"


### Extra one-time Semble setup
# NOTE: Keep expensive RUNs above the COPY lines — editing a copied file invalidates the cache of every layer below it!

# Bake semble's embedding model into the image to fix corrupted downloads during first run.
# This works with mounted data volumes because fresh (empty) named volumes are seeded
# by Docker with the image content at the mount path, so the model is shared between
# projects and survives `--clean`.
RUN python3 -c "from semble.utils import resolve_model_name; from model2vec import StaticModel; StaticModel.from_pretrained(resolve_model_name())"

# Generate semble's search sub-agent (`~/.claude/agents/semble-search.md`).
# Note that the MCP registration stays in `entrypoint.sh` where also mempalace is registered.
RUN semble install --agent claude --type subagent --yes


### Install Headroom Proxy
# - Opt-in by building the image with `./run.sh --build|-b --with-headroom|-H`
# - Start claude via `headroom wrap -- claude [options]`
ARG INSTALL_HEADROOM=0
RUN if [ "$INSTALL_HEADROOM" = "1" ]; then pip install --user --no-cache-dir "headroom-ai[proxy,mcp]"; fi


### Extra one-time Claude setup

# User-level permissions initialized so that semble/mempalace/... MCP tools and CLI commands run without annoying prompts.
# NOTE: Mutable by the 'claude' user by design so that Claude Code can write runtime prefs here, e.g. `/model`.
COPY --chown=claude:claude assets/home_dot-claude_settings.json "$HOME/.claude/settings.json"

# Managed policy files
# NOTES:
# - root-owned and 444, thus outside of 'claude' users write capability
# - Allow/Deny precedence: Managed > CLI args > Local > Project > User
# - A managed 'deny' cannot be overridden by any lower tier
COPY --chown=root:root --chmod=444 assets/etc_claude-code_CLAUDE.md             /etc/claude-code/CLAUDE.md
COPY --chown=root:root --chmod=444 assets/etc_claude-code_managed-settings.json /etc/claude-code/managed-settings.json


### Finishing touches

COPY --chown=claude:claude --chmod=755 assets/entrypoint.sh "$HOME/entrypoint.sh"

WORKDIR /workspace

ENTRYPOINT ["/home/claude/entrypoint.sh"]

CMD ["bash"]

