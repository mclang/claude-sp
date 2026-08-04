# Use a modern Python slim image as the foundation for Semble and MemPalace
FROM python:3.13-slim

# Prevent interactive prompts during apt installations
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Chain everything heavy into a SINGLE RUN command to minimize layer size
# - Use `--no-install-recommends` to block unnecessary suggested packages
# - Use `--no-cache-dir` so pip doesn't save raw downloads
# - Uninstall build compilers after pip is done
# - Clean up the apt cache to make layer even smaller
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        bash \
        git \
        sqlite3 \
        build-essential \
    && pip install --no-cache-dir "semble[mcp]" mempalace \
    && apt-get purge -y --auto-remove build-essential \
    && apt-get install -y --no-install-recommends libgomp1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-privileged `claude` user and group with UID and GID coming from the host machine
ARG UID=1000
ARG GID=1000
RUN groupadd -g "${GID}" claude && useradd -m -s "/bin/bash" -u "${UID}" -g "${GID}" claude

USER claude
ENV HOME="/home/claude"
ENV PATH="$HOME/.local/bin:$PATH"

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

WORKDIR /workspace

# NOTE: Change this to `cloude` when initial configuration is done
CMD ["bash"]

