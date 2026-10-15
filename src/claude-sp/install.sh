#!/usr/bin/env bash
# Installation script for "Claude Sandboxed Plus" feature.
#
# NOTES:
# - Runs as 'root' when the image is built.
# - Options arrive as uppercase env vars.
#
set -euo pipefail

FEATURE_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
ASSETS="$FEATURE_DIR/assets"
USERNAME="claude"
USER_HOME="/home/$USERNAME"
VENV="/opt/claude-sp"
HEADROOM="${HEADROOM:-false}"
export DEBIAN_FRONTEND=noninteractive

run_as_user() {
    su "$USERNAME" -s /bin/bash -c "export PATH=\"\$HOME/.local/bin:$VENV/bin:\$PATH\"; $1"
}

echo "### Installing 'claude-sp' feature ###"

PKGS=(bash ca-certificates curl git jq procps ripgrep sqlite3 libgomp1 build-essential)
python3 -c 'import ensurepip' &>/dev/null || PKGS+=(python3 python3-venv)
apt-get update
apt-get install -y --no-install-recommends "${PKGS[@]}"

# Linux hosts: devcontainer CLI remaps UID to host's
id "$USERNAME" &>/dev/null || useradd -m -U -s /bin/bash "$USERNAME"

# Root-owned 'venv' -> the agent can run these tools but not modify them.
python3 -m venv "$VENV"
"$VENV/bin/pip" install --no-cache-dir "semble[mcp]" mempalace
[[ "$HEADROOM" == "true" ]] && "$VENV/bin/pip" install --no-cache-dir "headroom-ai[proxy,mcp]"
for BIN in semble mempalace mempalace-mcp headroom; do
    [[ -x "$VENV/bin/$BIN" ]] && ln -sf "$VENV/bin/$BIN" "/usr/local/bin/$BIN"
done

apt-get purge -y --auto-remove build-essential
apt-get clean
rm -rf /var/lib/apt/lists/*

# Managed 'root' owned files which cannot be edited or overwritten by 'claude' user:
install -D -o root -g root -m 444 "$ASSETS/etc_claude-code_CLAUDE.md"             /etc/claude-code/CLAUDE.md
install -D -o root -g root -m 444 "$ASSETS/etc_claude-code_managed-settings.json" /etc/claude-code/managed-settings.json
install -D -o root -g root -m 555 "$ASSETS/hooks/semble-enforce.sh"               /etc/claude-code/hooks/semble-enforce.sh
install -D -o root -g root -m 755 "$ASSETS/entrypoint.sh"                         /usr/local/share/claude-sp/entrypoint.sh

# Pre-create volume mount points so that named volumes get right owner.
run_as_user 'mkdir -p ~/.claude ~/.config ~/.local/bin ~/.mempalace ~/.cache/chroma ~/.cache/semble ~/.cache/huggingface ~/.headroom'

# Same path as run.sh image, where its headroom MCP registration points.
if [[ "$HEADROOM" == "true" ]]; then
    ln -sf "$VENV/bin/headroom" "$USER_HOME/.local/bin/headroom"
fi

run_as_user 'curl -fsSL https://claude.ai/install.sh | bash'
install -o "$USERNAME" -g "$USERNAME" -m 755 "$ASSETS/install-claude-statusline.sh" /tmp/install-claude-statusline.sh
run_as_user '/tmp/install-claude-statusline.sh'
rm /tmp/install-claude-statusline.sh

# User level config must be editable so that Claude can write e.g runtime preferences
install -o "$USERNAME" -g "$USERNAME" -m 644 "$ASSETS/home_dot-claude_settings.json" "$USER_HOME/.claude/settings.json"

# Add Semble's embedding model and generate its search sub-agent.
run_as_user 'python -c "from semble.utils import resolve_model_name; from model2vec import StaticModel; StaticModel.from_pretrained(resolve_model_name())"'
run_as_user 'semble install --agent claude --type subagent --yes'

cat <<'EOF' >> "$USER_HOME/.bashrc"

# Restrict Claude to immediate subdirectories of `/workspace`.
function claude() {
    if [[ "$(dirname "$PWD")" != "/workspace" ]]; then
        echo "ERROR: Claude must be run from a project root: /workspace/<project>"
        return 1
    fi
    command claude "$@"
}

alias la='ls -A  -F --color=auto --group-directories-first'
alias ll='ls -ho -F --color=auto --group-directories-first'
alias mount='mount | grep -Ev "^(overlay|tmpfs|proc|sysfs|devtmpfs|devpts|cgroup|mqueue|shm)"'

if command -v headroom &>/dev/null; then
    alias hrc='headroom wrap -- claude'
    export HEADROOM_OUTPUT_SHAPER=1
    export HEADROOM_OUTPUT_HOLDOUT=0.1
fi
EOF

echo "==> DONE"
