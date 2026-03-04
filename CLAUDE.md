<!-- tok-sudo:start -->
# sudo access

Do NOT run sudo commands directly. Use `tok-sudo` instead.

tok-sudo is for interactive use only. Never write tok-sudo commands into scripts, Makefiles, or automation — those should use sudo directly.

If a task requires sudo:
1. Ask the user for the current tok-sudo token
2. Run commands with: `TOK_SUDO_TOKEN=<token> tok-sudo <command...>`
3. To pipe content into a command: `echo "content" | TOK_SUDO_TOKEN=<token> tok-sudo tee /etc/file`
4. Do not store or reuse the token across sessions. Never write the token to any file

If the token is rejected, ask the user to provide a new one. Do not retry with the same token.

Do not attempt to rotate the token yourself. Token rotation requires direct sudo access.
<!-- tok-sudo:end -->
