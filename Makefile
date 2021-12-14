.PHONY: all

VERSION ?= 4.2.0
RELEASE ?= 1

SRC ?= main

VERSION_FULL ?= $(shell test -e .git && git describe --tags --long --first-parent --always)
ifeq ($(VERSION_FULL),)
VERSION_FULL := $(VERSION)
endif

WWROOT ?= /var/lib
# warewulf subdir automatcally added to TFTPROOT
TFTPROOT ?= /var/lib/tftpboot
# SUSE: TFTPROOT ?= /srv/tftpboot
# Ubuntu: TFTPROOT ?= /srv/tftp
FIREWALLDIR ?= /usr/lib/firewalld/services
OVERLAYDIR ?= $(WWROOT)/warewulf/overlays

# auto installed tooling
TOOLS_DIR := .tools
TOOLS_BIN := $(TOOLS_DIR)/bin
CONFIG := $(shell pwd)

# tools
GO_TOOLS_BIN := $(addprefix $(TOOLS_BIN)/, $(notdir $(GO_TOOLS)))
GO_TOOLS_VENDOR := $(addprefix vendor/, $(GO_TOOLS))
GOLANGCI_LINT := $(TOOLS_BIN)/golangci-lint
GOLANGCI_LINT_VERSION := v1.31.0

# use GOPROXY for older git clients and speed up downloads
GOPROXY ?= https://proxy.golang.org
export GOPROXY

# built tags needed for wwbuild binary
WW_BUILD_GO_BUILD_TAGS := containers_image_openpgp containers_image_ostree

all: config vendor wwctl wwclient bash_completion.d man_pages

build: lint test-it vet all

# set the go tools into the tools bin.
setup_tools: $(GO_TOOLS_BIN) $(GOLANGCI_LINT)

# install go tools into TOOLS_BIN
$(GO_TOOLS_BIN):
	@GOBIN="$(PWD)/$(TOOLS_BIN)" go install -mod=vendor $(GO_TOOLS)

# install golangci-lint into TOOLS_BIN
$(GOLANGCI_LINT):
	@curl -qq -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(TOOLS_BIN) $(GOLANGCI_LINT_VERSION)


setup: vendor $(TOOLS_DIR) setup_tools config

# vendor
vendor:
	go mod tidy -v
	go mod vendor

$(TOOLS_DIR):
	@mkdir -p $@

# Pre-build steps for source, such as "go generate"
config:
	sed -e 's,@WWROOT@,$(WWROOT),g; s,@VERSION@,$(VERSION),g; s,@RELEASE@,$(RELEASE),g' warewulf.spec.in > warewulf.spec
	sed -e 's,@WWROOT@,$(WWROOT),g; s,@TFTPROOT@,$(TFTPROOT),g' etc/warewulf.conf.in > etc/warewulf.conf

# Lint
lint: setup_tools config
	@echo Running golangci-lint...
	@$(GOLANGCI_LINT) run --build-tags "$(WW_BUILD_GO_BUILD_TAGS)" --skip-dirs internal/pkg/staticfiles ./...

vet:
	go vet ./...

test-it:
	go test -v ./...

# Generate test coverage
test-cover:     ## Run test coverage and generate html report
	rm -fr coverage
	mkdir coverage
	go list -f '{{if gt (len .TestGoFiles) 0}}"go test -covermode count -coverprofile {{.Name}}.coverprofile -coverpkg ./... {{.ImportPath}}"{{end}}' ./... | xargs -I {} bash -c {}
	echo "mode: count" > coverage/cover.out
	grep -h -v "^mode:" *.coverprofile >> "coverage/cover.out"
	rm *.coverprofile
	go tool cover -html=coverage/cover.out -o=coverage/cover.html

debian: all 

files: all
	install -d -m 0755 $(DESTDIR)/usr/bin/
	install -d -m 0755 $(DESTDIR)$(WWROOT)/warewulf/
	install -d -m 0755 $(DESTDIR)$(WWROOT)/warewulf/chroots
	install -d -m 0755 $(DESTDIR)$(WWROOT)/warewulf/provision
	install -d -m 0755 $(DESTDIR)/etc/warewulf/
	install -d -m 0755 $(DESTDIR)/etc/warewulf/ipxe
	install -d -m 0755 $(DESTDIR)$(TFTPROOT)/warewulf/ipxe/
	install -d -m 0755 $(DESTDIR)/etc/bash_completion.d/
	install -d -m 0755 $(DESTDIR)/usr/share/man/man1
	test -f $(DESTDIR)/etc/warewulf/warewulf.conf || install -m 644 etc/warewulf.conf $(DESTDIR)/etc/warewulf/
	test -f $(DESTDIR)/etc/warewulf/hosts.tmpl || install -m 644 etc/hosts.tmpl $(DESTDIR)/etc/warewulf/
	test -f $(DESTDIR)/etc/warewulf/nodes.conf || install -m 644 etc/nodes.conf $(DESTDIR)/etc/warewulf/
	cp -r etc/dhcp $(DESTDIR)/etc/warewulf/
	cp -r etc/ipxe $(DESTDIR)/etc/warewulf/
	cp -r overlays $(DESTDIR)/var/warewulf/
	mkdir -p $(DESTDIR)$(OVERLAYIR)/wwinit/bin/
	mkdir -p $(DESTDIR)$(OVERLAYIR)/wwinit/warewulf/bin/
	chmod +x $(DESTDIR)$(OVERLAYIR)/wwinit/init
	chmod 600 $(DESTDIR)$(OVERLAYIR)/wwinit/etc/ssh/ssh*
	chmod 644 $(DESTDIR)$(OVERLAYIR)/wwinit/etc/ssh/ssh*.pub.ww
	mkdir -p $(DESTDIR)$(OVERLAYIR)/wwinit/warewulf/bin/
	install -m 0755 wwctl $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/usr/lib/firewalld/services
	install -c -m 0644 include/firewalld/warewulf.xml $(DESTDIR)/usr/lib/firewalld/services
	cp -r overlays $(DESTDIR)$(WWROOT)/warewulf/
	mkdir -p $(DESTDIR)$(OVERLAYIR)/wwinit/bin/
	mkdir -p $(DESTDIR)$(OVERLAYIR)/wwinit/warewulf/bin/
	chmod +x $(DESTDIR)$(OVERLAYIR)/wwinit/init
	chmod 600 $(DESTDIR)$(OVERLAYIR)/wwinit/etc/ssh/ssh*
	chmod 644 $(DESTDIR)$(OVERLAYIR)/wwinit/etc/ssh/ssh*.pub.ww
	mkdir -p $(DESTDIR)$(OVERLAYIR)/wwinit/warewulf/bin/
	install -m 0755 wwctl $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)$(FIREWALLDIR)
	install -c -m 0644 include/firewalld/warewulf.xml $(DESTDIR)$(FIREWALLDIR)
	mkdir -p $(DESTDIR)/usr/lib/systemd/system
	install -c -m 0644 include/systemd/warewulfd.service $(DESTDIR)/usr/lib/systemd/system
	cp bash_completion.d/warewulf $(DESTDIR)/etc/bash_completion.d/
	cp man_pages/* $(DESTDIR)/usr/share/man/man1/

init:
	systemctl daemon-reload
	cp -r tftpboot/* $(TFTPROOT)/warewulf/ipxe/
	restorecon -r $(TFTPROOT)/warewulf

debfiles: debian
	chmod +x $(DESTDIR)$(WWROOT)/warewulf/overlays/system/debian/init
	chmod 600 $(DESTDIR)$(WWROOT)/warewulf/overlays/system/debian/etc/ssh/ssh*
	chmod 644 $(DESTDIR)$(WWROOT)/warewulf/overlays/system/debian/etc/ssh/ssh*.pub.ww
	mkdir -p $(DESTDIR)$(WWROOT)/warewulf/overlays/system/debian/warewulf/bin/
	cp wwclient $(DESTDIR)$(WWROOT)/warewulf/overlays/system/debian/warewulf/bin/

wwctl:
	cd cmd/wwctl; GOOS=linux go build -ldflags="-X 'github.com/hpcng/warewulf/internal/pkg/version.Version=$(VERSION_FULL)'" -mod vendor -tags "$(WW_BUILD_GO_BUILD_TAGS)" -o ../../wwctl

wwclient:
	cd cmd/wwclient; CGO_ENABLED=0 GOOS=linux go build -mod vendor -a -ldflags '-extldflags -static' -o ../../wwclient

install_wwclient: wwclient
	install -m 0755 wwclient $(DESSTDIR)/var/warewulf/overlays/wwinit/bin/wwclient

bash_completion:
	cd cmd/bash_completion && go build -ldflags="-X 'github.com/hpcng/warewulf/internal/pkg/warewulfconf.ConfigFile=$(CONFIG)/etc/warewulf.conf'\
	 -X 'github.com/hpcng/warewulf/internal/pkg/node.ConfigFile=$(CONFIG)/etc/nodes.conf'"\
	 -mod vendor -tags "$(WW_BUILD_GO_BUILD_TAGS)" -o ../../bash_completion

bash_completion.d: bash_completion
	install -d -m 0755 bash_completion.d
	./bash_completion  bash_completion.d/warewulf

man_page:
	cd cmd/man_page && go build -ldflags="-X 'github.com/hpcng/warewulf/internal/pkg/warewulfconf.ConfigFile=$(CONFIG)/etc/warewulf.conf'\
	 -X 'github.com/hpcng/warewulf/internal/pkg/node.ConfigFile=$(CONFIG)/etc/nodes.conf'"\
	 -mod vendor -tags "$(WW_BUILD_GO_BUILD_TAGS)" -o ../../man_page

man_pages: man_page
	install -d man_pages
	./man_page ./man_pages
	cd man_pages; for i in wwctl*1; do echo "Compressing manpage: $$i"; gzip --force $$i; done

config_defaults:
	cd cmd/config_defaults && go build -ldflags="-X 'github.com/hpcng/warewulf/internal/pkg/warewulfconf.ConfigFile=$(CONFIG)/etc/warewulf.conf'\
	 -X 'github.com/hpcng/warewulf/internal/pkg/node.ConfigFile=$(CONFIG)/etc/nodes.conf'"\
	 -mod vendor -tags "$(WW_BUILD_GO_BUILD_TAGS)" -o ../../config_defaults

dist: vendor
	rm -rf _dist/warewulf-$(VERSION)
	mkdir -p _dist/warewulf-$(VERSION)
	git archive --format=tar $(SRC) | tar -xf - -C _dist/warewulf-$(VERSION)
	cp -r vendor _dist/warewulf-$(VERSION)/
	cp warewulf.spec _dist/warewulf-$(VERSION)/
	cd _dist; tar -czf ../warewulf-$(VERSION).tar.gz warewulf-$(VERSION)

clean:
	rm -f wwclient
	rm -f wwctl
	rm -rf _dist
	rm -f warewulf-$(VERSION).tar.gz
	rm -f bash_completion
	rm -rf bash_completion.d
	rm -f man_page
	rm -rf man_pages
	rm -rf vendor
	rm -f config_defaults

install: files install_wwclient

debinstall: files debfiles

