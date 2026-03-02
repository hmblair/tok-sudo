PREFIX    ?= /usr/local
BINDIR    ?= $(PREFIX)/bin
SUDOERS_D ?= /etc/sudoers.d
HASH_FILE ?= /etc/tok-sudo-token-hash
SCRIPTS   := tok-sudo tok-sudo-exec tok-sudo-rotate
CLAUDE_MD ?= $(HOME)/CLAUDE.md

.PHONY: install uninstall

install:
	@for s in $(SCRIPTS); do \
		sudo cp $$s $(BINDIR)/$$s && \
		sudo chmod 755 $(BINDIR)/$$s; \
	done
	@echo '$(shell id -un) ALL=(root) NOPASSWD: $(BINDIR)/tok-sudo-exec *' \
		| sudo EDITOR='tee' visudo -f $(SUDOERS_D)/tok-sudo > /dev/null
	@if ! grep -q 'tok-sudo:start' $(CLAUDE_MD) 2>/dev/null; then \
		cat CLAUDE.md >> $(CLAUDE_MD); \
		echo 'Added tok-sudo instructions to $(CLAUDE_MD)'; \
	fi
	@echo 'tok-sudo installed. Run "sudo tok-sudo-rotate" to set your initial token.'

uninstall:
	@for s in $(SCRIPTS); do \
		sudo rm -f $(BINDIR)/$$s; \
	done
	@sudo rm -f $(SUDOERS_D)/tok-sudo
	@sudo rm -f $(HASH_FILE)
	@if [ -f $(CLAUDE_MD) ]; then \
		sed '/tok-sudo:start/,/tok-sudo:end/d' $(CLAUDE_MD) > $(CLAUDE_MD).tmp && \
		mv $(CLAUDE_MD).tmp $(CLAUDE_MD); \
	fi
	@echo 'tok-sudo uninstalled.'
