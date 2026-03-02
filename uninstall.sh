#!/bin/bash
# Uninstall tok-sudo
set -euo pipefail

echo "Uninstalling tok-sudo..."

sudo rm -f /usr/local/bin/tok-sudo /usr/local/bin/tok-sudo-exec /usr/local/bin/tok-sudo-rotate
sudo rm -f /etc/sudoers.d/tok-sudo
sudo rm -f /etc/tok-sudo-token-hash

echo "tok-sudo uninstalled."
