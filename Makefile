PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
DESTDIR ?=

.PHONY: all install uninstall check clean

all:
	@echo "Nothing to build. 'make install' puts pdfindex2md in $(BINDIR)."

install:
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 755 pdfindex2md "$(DESTDIR)$(BINDIR)/pdfindex2md"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/pdfindex2md"

check:
	python3 pdfindex2md --selftest

clean:
	rm -rf __pycache__ *.pyc
