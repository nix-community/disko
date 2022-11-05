PREFIX ?= /usr/local
SHARE ?= $(PREFIX)/share/disko

all:

SOURCES = disko cli.nix default.nix types.nix

install:
	mkdir -p $(PREFIX)/bin $(SHARE)
	sed \
		-e "s|libexec_dir=\".*\"|libexec_dir=\"$(SHARE)\"|" \
		-e "s|#!/usr/bin/env.*|#!/usr/bin/env bash|" \
		disko > $(PREFIX)/bin/disko
	chmod 755 $(PREFIX)/bin/disko
	cp -r $(SOURCES) $(SHARE)
