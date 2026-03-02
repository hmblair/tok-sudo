# tok-sudo

Token-gated sudo wrapper. Grants sudo access only when the caller provides a valid token, designed for giving AI agents (like Claude Code) revocable sudo access without exposing passwords.

## How it works

- A random token is generated and its SHA-256 hash is stored in a root-only file (`/etc/tok-sudo-token-hash`)
- The caller must provide the token via environment variable to run commands as root
- Rotating the token immediately revokes access for anyone holding the old token
- The token is passed via environment variable and the hash via stdin, so neither is visible in `ps` output

## Install

```bash
make install
```

This copies the scripts to `/usr/local/bin/`, creates a sudoers entry allowing passwordless execution of `tok-sudo-exec` for the current user, and appends Claude Code instructions to `~/CLAUDE.md`.

## Setup

Generate an initial token:

```bash
sudo tok-sudo-rotate
```

This prints the new token. Store it somewhere safe.

## Usage

```bash
TOK_SUDO_TOKEN=<token> tok-sudo <command...>
```

For example:

```bash
TOK_SUDO_TOKEN=abc123 tok-sudo apt install htop
```

## Rotating / revoking

```bash
sudo tok-sudo-rotate
```

Generates a new random token and invalidates the old one immediately.

## Security model

| Property | Detail |
|---|---|
| Token storage | SHA-256 hash in `/etc/tok-sudo-token-hash`, mode `0600`, owned by root |
| Token transport | Via `TOK_SUDO_TOKEN` env var (not visible in `ps`) |
| Hash transport | Via stdin to `tok-sudo-exec` (not visible in `ps`) |
| Hash comparison | Timing-safe — both hashes are re-hashed with a random nonce before comparison |
| Ownership check | Hash file must be owned by root (UID 0) or execution is refused |
| Sudoers scope | `NOPASSWD` only for `tok-sudo-exec`, not general sudo |
| Empty token | Rejected — an empty or cleared hash file means no access |
| Token entropy | 32 alphanumeric characters (~190 bits) |

## Files

| File | Location | Purpose |
|---|---|---|
| `tok-sudo` | `/usr/local/bin/tok-sudo` | User-facing wrapper. Reads token from env, hashes it, pipes to `tok-sudo-exec` |
| `tok-sudo-exec` | `/usr/local/bin/tok-sudo-exec` | Runs as root via sudoers. Validates hash, executes command |
| `tok-sudo-rotate` | `/usr/local/bin/tok-sudo-rotate` | Generates new token, stores hash. Must be run with `sudo` |
| `CLAUDE.md` | `~/CLAUDE.md` | Claude Code instructions for using tok-sudo |
| `Makefile` | (repo only) | Installs/uninstalls scripts and configures sudoers |

## Uninstall

```bash
make uninstall
```

## License

MIT
