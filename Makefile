PREFIX    ?= /usr
DESTDIR   ?=
SHARE     := $(DESTDIR)$(PREFIX)/share/flamenco-greeter
BIN       := $(DESTDIR)$(PREFIX)/bin

# Flamenco Shell's QML tree. The greeter links its Commons/, Widgets/, assets/
# and Services/Time.qml so the login screen uses the shell's exact theme code.
SHELL_DIR ?= $(PREFIX)/share/flamenco-shell/shell
# For `make dev`: a flamenco-shell checkout next to this one.
DEV_SHELL ?= $(abspath ../flamenco-shell/shell)

SHARED    := Commons Widgets assets

.PHONY: dev unlink install uninstall preview check

# Link the shell's components into ./greeter so it runs from this checkout.
dev:
	@test -f $(DEV_SHELL)/Commons/Theme.qml || { echo "No Flamenco Shell at $(DEV_SHELL); pass DEV_SHELL=/path/to/flamenco-shell/shell"; exit 1; }
	@for d in $(SHARED); do ln -sfn $(DEV_SHELL)/$$d greeter/$$d; done
	@ln -sf $(DEV_SHELL)/Services/Time.qml greeter/Services/Time.qml
	@echo "Linked greeter/{$(shell echo $(SHARED) | tr ' ' ,)} and Services/Time.qml -> $(DEV_SHELL)"

unlink:
	rm -f $(addprefix greeter/,$(SHARED)) greeter/Services/Time.qml

preview: dev
	./bin/flamenco-greeter preview

check:
	python3 -m py_compile bin/flamenco-greeter
	@rm -rf bin/__pycache__

install:
	install -d $(SHARE)/greeter
	cp -r --no-preserve=ownership greeter/shell.qml greeter/Modules greeter/Services $(SHARE)/greeter/
	rm -f $(SHARE)/greeter/Services/Time.qml
	@for d in $(SHARED); do rm -rf $(SHARE)/greeter/$$d; ln -s $(SHELL_DIR)/$$d $(SHARE)/greeter/$$d; done
	ln -s $(SHELL_DIR)/Services/Time.qml $(SHARE)/greeter/Services/Time.qml
	find $(SHARE) -type f -exec chmod 644 {} +
	find $(SHARE) -type d -exec chmod 755 {} +
	install -Dm755 bin/flamenco-greeter $(BIN)/flamenco-greeter
	install -Dm644 data/sysusers.conf $(DESTDIR)$(PREFIX)/lib/sysusers.d/flamenco-greeter.conf
	install -Dm644 data/tmpfiles.conf $(DESTDIR)$(PREFIX)/lib/tmpfiles.d/flamenco-greeter.conf
	install -Dm644 data/systemd/flamenco-greeter-sync.service $(DESTDIR)$(PREFIX)/lib/systemd/user/flamenco-greeter-sync.service
	install -Dm644 data/systemd/flamenco-greeter-sync.path $(DESTDIR)$(PREFIX)/lib/systemd/user/flamenco-greeter-sync.path
	install -Dm644 examples/config.toml $(SHARE)/examples/config.toml
	install -Dm644 examples/flamenco-niri.kdl $(SHARE)/examples/flamenco-niri.kdl

uninstall:
	rm -rf $(SHARE)
	rm -f $(BIN)/flamenco-greeter \
	      $(DESTDIR)$(PREFIX)/lib/sysusers.d/flamenco-greeter.conf \
	      $(DESTDIR)$(PREFIX)/lib/tmpfiles.d/flamenco-greeter.conf \
	      $(DESTDIR)$(PREFIX)/lib/systemd/user/flamenco-greeter-sync.service \
	      $(DESTDIR)$(PREFIX)/lib/systemd/user/flamenco-greeter-sync.path
