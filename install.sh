#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# ANSI colour tokens

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Output helpers

error() {
    echo -e "${RED}Error:${NC} $1" >&2
    exit 1
}

info() {
    echo -e "${CYAN}$1${NC}"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

info "Installing tok-sudo..."

# Copy scripts
sudo cp "$SCRIPT_DIR/tok-sudo" /usr/local/bin/tok-sudo
sudo cp "$SCRIPT_DIR/tok-sudo-exec" /usr/local/bin/tok-sudo-exec
sudo cp "$SCRIPT_DIR/tok-sudo-rotate" /usr/local/bin/tok-sudo-rotate

# Set permissions
sudo chmod 755 /usr/local/bin/tok-sudo
sudo chmod 755 /usr/local/bin/tok-sudo-exec
sudo chmod 755 /usr/local/bin/tok-sudo-rotate

# Set up sudoers (only tok-sudo-exec gets NOPASSWD)
info "Configuring sudoers..."
SUDOERS_LINE="$USER ALL=(root) NOPASSWD: /usr/local/bin/tok-sudo-exec *"
echo "$SUDOERS_LINE" | sudo EDITOR='tee' visudo -f /etc/sudoers.d/tok-sudo > /dev/null

success "tok-sudo installed successfully."
echo "Run 'sudo tok-sudo-rotate' to set your initial token."
