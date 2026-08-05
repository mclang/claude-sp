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

# Create non-privileged `claude` user and group.
# Defaults (1000) are overridden by `run.sh` via --build-arg to match the host user's UID,
# ensuring files created on mounted volumes are owned by the correct host user.
ARG UID=1000
ARG GID=1000
RUN groupadd -g "${GID}" claude && useradd -m -s "/bin/bash" -u "${UID}" -g "${GID}" claude

# NOTE: changing `HOME` here requires also `ENTRYPOINT` change!
ENV HOME="/home/claude"
ENV PATH="$HOME/.local/bin:$PATH"
ENV PYTHONUNBUFFERED=1
USER claude

# Using `https://claude.ai/install.sh` installs native binary in `$HOME/.local/bin`:
RUN curl -fsSL https://claude.ai/install.sh | bash


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
EOF

# Bake semble's embedding model into the image to fix corrupted downloads during first run.
# This works with mounted data volumes because fresh (empty) named volumes are seeded
# by Docker with the image content at the mount path, so the model is shared between
# projects and survives `--clean`.
RUN python3 -c "from semble.utils import resolve_model_name; from model2vec import StaticModel; StaticModel.from_pretrained(resolve_model_name())"

# Pre-create volume mount points so Docker initializes named volumes with right owner (claude)
# Keep these in line with what is used in `entrypoint.sh` and `run.sh` scripts!
RUN mkdir -p "$HOME/.claude" "$HOME/.config" "$HOME/.mempalace" "$HOME/.cache/chroma" "$HOME/.cache/semble" "$HOME/.cache/huggingface"

COPY --chown=claude:claude --chmod=755 assets/entrypoint.sh "$HOME/entrypoint.sh"

# User-level guidance for using semble/mempalace; seeds fresh `claude-data` volumes.
# Loaded by Claude Code in EVERY project alongside the project's own CLAUDE.md.
COPY --chown=claude:claude assets/CLAUDE-container-user.md "$HOME/.claude/CLAUDE.md"

WORKDIR /workspace

ENTRYPOINT ["/home/claude/entrypoint.sh"]
CMD ["bash"]

