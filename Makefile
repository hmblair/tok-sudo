PREFIX    ?= /usr/local
BINDIR    ?= $(PREFIX)/bin
SUDOERS_D ?= /etc/sudoers.d
HASH_FILE ?= /etc/tok-sudo-token-hash
SCRIPTS   := tok-sudo tok-sudo-exec tok-sudo-rotate
VERSION   := $(shell git describe --tags --always 2>/dev/null || echo unknown)
CLAUDE_MD ?= $(HOME)/CLAUDE.md

.PHONY: install uninstall

install:
	@for s in $(SCRIPTS); do \
		TMPFILE=$$(mktemp) && \
		sed 's/@VERSION@/$(VERSION)/g' $$s > "$$TMPFILE" && \
		sudo mv "$$TMPFILE" $(BINDIR)/$$s && \
		sudo chmod 755 $(BINDIR)/$$s; \
	done
	@echo "$${SUDO_USER:-$(shell id -un)} ALL=(root) NOPASSWD: $(BINDIR)/tok-sudo-exec *" \
		| sudo EDITOR='tee' visudo -f $(SUDOERS_D)/tok-sudo > /dev/null
	@if grep -q 'tok-sudo:start' $(CLAUDE_MD) 2>/dev/null; then \
		sed '/tok-sudo:start/,/tok-sudo:end/d' $(CLAUDE_MD) > $(CLAUDE_MD).tmp && \
		mv $(CLAUDE_MD).tmp $(CLAUDE_MD); \
	fi
	@cat CLAUDE.md >> $(CLAUDE_MD)
	@chown $${SUDO_USER:-$(shell id -un)}:$${SUDO_USER:-$(shell id -un)} $(CLAUDE_MD)
	@echo 'Updated tok-sudo instructions in $(CLAUDE_MD)'
	@echo 'tok-sudo installed. Run "sudo tok-sudo-rotate" to set your initial token.'

uninstall:
	@for s in $(SCRIPTS); do \
		sudo rm -f $(BINDIR)/$$s; \
	done
	@sudo rm -f $(SUDOERS_D)/tok-sudo
	@sudo rm -f $(HASH_FILE)
	@if [ -f $(CLAUDE_MD) ]; then \
		sed '/tok-sudo:start/,/tok-sudo:end/d' $(CLAUDE_MD) > $(CLAUDE_MD).tmp && \
		mv $(CLAUDE_MD).tmp $(CLAUDE_MD) && \
		chown $${SUDO_USER:-$(shell id -un)}:$${SUDO_USER:-$(shell id -un)} $(CLAUDE_MD); \
	fi
	@echo 'tok-sudo uninstalled.'
