#!/usr/bin/env bash
set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}→${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}!${RESET} $*"; }
die()     { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

# ── paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_PORT="${CLAUDE_PROXY_PORT:-3456}"
BIN_DIR="$HOME/bin"
PROXY_BIN="$BIN_DIR/claude-proxy"
ENV_FILE="$HOME/.config/deepseek.env"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SERVICE_DIR/claude-proxy.service"
BASHRC_DIR="$HOME/.bashrc.d"
SHELL_FILE="$BASHRC_DIR/claude-providers.sh"
BASHRC="$HOME/.bashrc"
MARKER="# managed by deepseek-with-claude-code"

# ── uninstall ─────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--uninstall" ]]; then
  info "uninstalling..."
  systemctl --user stop claude-proxy 2>/dev/null || true
  systemctl --user disable claude-proxy 2>/dev/null || true
  rm -f "$SERVICE_FILE"
  systemctl --user daemon-reload 2>/dev/null || true
  rm -f "$PROXY_BIN"
  rm -f "$ENV_FILE"
  rm -f "$SHELL_FILE"
  # remove sourcing line from .bashrc
  if [[ -f "$BASHRC" ]]; then
    sed -i "/source \"\$HOME\/.bashrc.d\/claude-providers.sh\" $MARKER/d" "$BASHRC"
  fi
  success "uninstalled. open a new terminal to apply."
  exit 0
fi

# ── banner ───────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}deepseek-with-claude-code installer${RESET}"
echo -e "────────────────────────────────────"
echo

# ── checks ───────────────────────────────────────────────────────────────────
command -v node >/dev/null 2>&1 || die "node.js is required but not found. install it from https://nodejs.org"
command -v systemctl >/dev/null 2>&1 || die "systemd is required (linux only)"
command -v claude >/dev/null 2>&1 || die "claude code cli is required. install from https://claude.ai/code"

NODE_MAJOR=$(node -e "process.stdout.write(process.versions.node.split('.')[0])")
(( NODE_MAJOR >= 18 )) || die "node.js >= 18 required (found v$(node --version))"

success "node.js $(node --version) found"

# ── api key ───────────────────────────────────────────────────────────────────
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
  echo
  echo -e "get your api key at ${CYAN}https://platform.deepseek.com/api_keys${RESET}"
  echo -n "enter deepseek api key: "
  read -r -s DEEPSEEK_API_KEY
  echo
  [[ -n "$DEEPSEEK_API_KEY" ]] || die "api key cannot be empty"
fi

# ── env file ──────────────────────────────────────────────────────────────────
mkdir -p "$HOME/.config"
printf 'DEEPSEEK_API_KEY=%s\n' "$DEEPSEEK_API_KEY" > "$ENV_FILE"
chmod 600 "$ENV_FILE"
success "api key saved to $ENV_FILE"

# ── proxy binary ──────────────────────────────────────────────────────────────
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/claude-proxy" "$PROXY_BIN"
chmod +x "$PROXY_BIN"
success "proxy installed to $PROXY_BIN"

# ── systemd service ───────────────────────────────────────────────────────────
mkdir -p "$SERVICE_DIR"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Claude API proxy (routes to Anthropic or DeepSeek by model)
After=network.target

[Service]
Type=simple
EnvironmentFile=%h/.config/deepseek.env
ExecStart=%h/bin/claude-proxy
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now claude-proxy
success "systemd service enabled and started"

# ── shell function ────────────────────────────────────────────────────────────
mkdir -p "$BASHRC_DIR"
cat > "$SHELL_FILE" <<'EOF'
# managed by deepseek-with-claude-code
source "$HOME/.config/deepseek.env" 2>/dev/null || true

claude() {
  if [ "$1" = "deepseek" ]; then
    shift
    ANTHROPIC_BASE_URL="http://localhost:3456" \
    ANTHROPIC_MODEL="deepseek-v4-pro" \
    CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-pro" \
    command claude "$@"
  else
    ANTHROPIC_BASE_URL="http://localhost:3456" command claude "$@"
  fi
}

claude-ds() {
  ANTHROPIC_BASE_URL="http://localhost:3456" \
  ANTHROPIC_MODEL="deepseek-v4-pro" \
  CLAUDE_CODE_SUBAGENT_MODEL="deepseek-v4-pro" \
  command claude "$@"
}
EOF

# add sourcing line to .bashrc if not already present
SOURCE_LINE="source \"\$HOME/.bashrc.d/claude-providers.sh\" $MARKER"
if ! grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
  echo >> "$BASHRC"
  echo "$SOURCE_LINE" >> "$BASHRC"
fi
success "shell functions added"

# ── done ─────────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}done.${RESET} open a new terminal, then:"
echo
echo -e "  ${GREEN}claude deepseek${RESET}   — launch claude code with deepseek v4 pro"
echo -e "  ${GREEN}claude${RESET}            — launch claude code normally (anthropic)"
echo
