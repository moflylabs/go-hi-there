include .env

## Makefile
#COMMIT = $(shell git log --pretty=format:'%H' -n 1)
COMMIT = 1

#VERSION    = $(shell git describe --tags --always)
VERSION = 0.0.0
BUILD_DATE = $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS   = -ldflags "\
 -X $(PROJECT)/internal/constants.Commit=$(COMMIT) \
 -X $(PROJECT)/internal/constants.Version=$(VERSION)\
 -X $(PROJECT)/internal/constants.BuildDate=$(BUILD_DATE)"

# Go
GO  = GOFLAGS=-mod=vendor go
GOBUILD  = CGO_ENABLED=1 $(GO) build $(LDFLAGS)

all: clean fmt lint test dist

.PHONY: clean
clean:  ## Clean this project
	rm -fR build pkg test dist

install:
	$(GO) install;

.PHONY: build
build:
	$(GOBUILD) -o build/$(PROJECT) $(PROJECT)/cmd/$(PROJECT)

.PHONY: build-all
build-all: ## Crosscompiling to linux, darwin and windows
	rm -rf build
	GOARCH=amd64 GOOS=linux $(GOBUILD) -o build/$(PROJECT).linux $(PROJECT)/cmd/$(PROJECT)
	CC=o64-clang CXX=o64-clang++ GOARCH=amd64 GOOS=darwin \
	  $(GOBUILD) -o build/$(PROJECT).darwin $(PROJECT)/cmd/$(PROJECT)
	CC=x86_64-w64-mingw32-gcc-posix CXX=x86_64-w64-mingw32-g++-posix \
	  GOARCH=amd64 GOOS=windows $(GOBUILD) -o build/$(PROJECT).exe $(PROJECT)/cmd/$(PROJECT)

.PHONY: fmt
fmt: ; @ ## Formatter
	for pkg in $(shell $(GO) list -f '{{.Dir}}' ./... | grep -v /vendor/ ); do \
		$(GO) run -mod=vendor golang.org/x/tools/cmd/goimports -l -w -e $$pkg/*.go; \
	done

.PHONY: lint
lint: ; @ ##  Code analysis
	$(GO) run -mod=vendor github.com/golangci/golangci-lint/cmd/golangci-lint run --verbose

.PHONY: test
test: ; @ ## Run unit tests
	mkdir -p test_report
	$(GO) test -p=1  $(shell $(GO) list -f '{{ if or .TestGoFiles .XTestGoFiles }}{{.ImportPath}}{{ end }}' ./... | grep -v test ) -v -timeout 100s -short -cover| tee test_report/$(PROJECT)-test.output;
	status=$$?;
	$(GO) run -mod=vendor github.com/tebeka/go2xunit -fail -input test_report/$(PROJECT)-test.output -output test_report/$(PROJECT)-test.xml;
	exit $$status;

.PHONY: deps
deps: ; @ ## Download project dependencies
	go mod tidy; go mod vendor;

TMPDIR := $(shell mktemp -d)
.PHONY: dist
dist: build-all ; @ ## Run Create tar that contains the executables
	rm -rf dist
	cp -a build $(TMPDIR)
	mkdir -p dist
	tar -zcvf dist/$(PROJECT)-$(VERSION).tar.gz -C $(TMPDIR)/* .

.PHONY: run
run: ; @ ## Run this project
ifeq ($(config),)
	$(GO) run cmd/$(PROJECT)/main.go;
else
	$(GO) run cmd/$(PROJECT)/main.go -config=$(config);
endif

.PHONY: changelog
changelog: ; @ ## Generate changelog
	docker run -v $(shell pwd):/changelog pruizpar/changelog-generator:master -path=/changelog -repo=bitbucket

CROSSCOMPILE_TARGETS=docker-build-all docker-dist docker-all
$(CROSSCOMPILE_TARGETS): docker-%:
	docker run --rm --workdir /app \
      -v $$HOME/.ssh:/root/.ssh -v $(CURDIR):/app \
      --entrypoint "" karalabe/xgo-$(GOLANG_VERSION) make $*

docker-%:
	docker run --rm --workdir /app -v $$HOME/.ssh:/root/.ssh -v $(CURDIR):/app golang:$(GOLANG_VERSION) make $*

help:
	@egrep '^(.+)\:(\w|\ )+##\ (.+)' ${MAKEFILE_LIST} | column -t -c 2 -s ':#'
