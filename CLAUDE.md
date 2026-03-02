<!-- tok-sudo:start -->
# sudo access

Do NOT run sudo commands directly. Use `tok-sudo` instead.

If a task requires sudo:
1. Ask the user for the current tok-sudo token
2. Run commands with: `TOK_SUDO_TOKEN=<token> tok-sudo <command...>`
3. Do not store or reuse the token across sessions. Never write the token to any file

If the token is rejected, ask the user to provide a new one. Do not retry with the same token.
<!-- tok-sudo:end -->
