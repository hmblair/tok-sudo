#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# ANSI colour tokens

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Output helpers

info() {
    echo -e "${CYAN}$1${NC}"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────

info "Uninstalling tok-sudo..."

sudo rm -f /usr/local/bin/tok-sudo /usr/local/bin/tok-sudo-exec /usr/local/bin/tok-sudo-rotate
sudo rm -f /etc/sudoers.d/tok-sudo
sudo rm -f /etc/tok-sudo-token-hash

success "tok-sudo uninstalled."
