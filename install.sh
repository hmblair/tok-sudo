#!/bin/bash
# Install tok-sudo scripts and configure sudoers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing tok-sudo..."

# Copy scripts
sudo cp "$SCRIPT_DIR/tok-sudo" /usr/local/bin/tok-sudo
sudo cp "$SCRIPT_DIR/tok-sudo-exec" /usr/local/bin/tok-sudo-exec
sudo cp "$SCRIPT_DIR/tok-sudo-rotate" /usr/local/bin/tok-sudo-rotate

# Set permissions
sudo chmod 755 /usr/local/bin/tok-sudo
sudo chmod 755 /usr/local/bin/tok-sudo-exec
sudo chmod 755 /usr/local/bin/tok-sudo-rotate

# Set up sudoers (only tok-sudo-exec gets NOPASSWD)
SUDOERS_LINE="$USER ALL=(root) NOPASSWD: /usr/local/bin/tok-sudo-exec *"
echo "$SUDOERS_LINE" | sudo EDITOR='tee' visudo -f /etc/sudoers.d/tok-sudo > /dev/null

echo "tok-sudo installed successfully."
echo "Run 'sudo tok-sudo-rotate' to set your initial token."
