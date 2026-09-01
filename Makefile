# Build the Ranke papers with Typst.
#
# Usage:
#   make             # build all papers
#   make help        # list every target with a one-line description
#   make 01          # build paper 01 only
#   make watch-01    # rebuild paper 01 on every save
#   make clean       # remove built PDFs
#   make example     # build the example docs tree to PDF
#
# `make help` reads this file: a target followed by `## text` is listed under
# the nearest `##@ heading` above it. A target with no `##` stays unlisted, so
# the variants (02…06, watch-02…) are named in the text of their first sibling
# rather than filling the listing.
#
# Sources live per paper under NN-*/.  Shared assets (template, bibliography)
# live under shared/.  All built PDFs land in pdf/, named after the paper
# directory (pdf/01-ranke-graph.pdf, pdf/02-ranke-db.pdf, ...).
#
# docs-spec/ specifies how a repository writes documentation. It stands to
# shared/vocabulary.typ as spec/ stands to ranke-go: the rules, then the
# implementations, then the evidence — the same shape as spec/ (spec + schema)
# or 01-ranke-graph/ (paper + vectors).
#
#   ranke-docs-spec.typ    the rules
#   check-backends.typ       the check
#   examples/docs-tree/      an example of what an author writes
#   examples/html-backend/   an example of what a renderer implements
#
# Both examples are fixtures rather than documentation: the gate compiles the
# tree through each backend, and neither is released.

# The one file every build, script, and workflow reads the pinned Typst
# version from (G-TYPST, docs-spec): `scripts/check.sh` and
# .github/workflows/release.yml both read it too, so the pin lives in one
# place rather than three that can drift apart.
TYPST_VERSION := $(shell cat TYPST_VERSION)
TYPST         := typst
SHARED  := shared/template.typ shared/vocabulary.typ shared/typography.typ \
           shared/constructs.typ shared/sources.bib
PDF_DIR := pdf

# The print backend a docs tree compiles through, and the two one-line shims the
# chapters actually import. `--place` writes the shims and touches nothing else.
DOCS_BACKEND := shared/vocabulary.typ shared/handbook.typ shared/typography.typ \
                shared/constructs.typ shared/glossary.typ
EXAMPLE_DIR   := docs-spec/examples/docs-tree
HTML_BACKEND  := docs-spec/examples/html-backend
DOCS_SHIMS    := $(EXAMPLE_DIR)/vocabulary.typ $(EXAMPLE_DIR)/handbook.typ
DOCS_CHAPTERS := $(filter-out $(DOCS_SHIMS),$(wildcard $(EXAMPLE_DIR)/*.typ))
DOCS_ASSETS   := $(wildcard $(EXAMPLE_DIR)/assets/*)

# What a handbook prints as its version. A working copy says what git says; the
# release workflow passes the tag.
DOCS_VERSION ?= $(shell git describe --tags --always 2>/dev/null || echo dev)

# Where `example-html` assembles its tree: the committed chapters with the stub
# HTML backend dropped in at the two names they import. This is what
# ranke-website does to a vendored copy, done here so the gate catches a chapter
# that only print can render.
HTML_DIR := build/html

PDFS := \
  $(PDF_DIR)/01-ranke-graph.pdf \
  $(PDF_DIR)/02-ranke-db.pdf \
  $(PDF_DIR)/03-ranke-workers.pdf \
  $(PDF_DIR)/04-ranke-retrieval.pdf \
  $(PDF_DIR)/05-retrieval-coordination.pdf \
  $(PDF_DIR)/ranke-glossary.pdf \
  $(PDF_DIR)/ranke-spec.pdf \
  $(PDF_DIR)/ranke-docs-spec.pdf

.PHONY: help all clean 01 02 03 04 05 glossary spec docs-spec example example-html docs-place docs-clean docs-bundle upgrade constructs schema watch-01 watch-02 watch-03 watch-04 watch-05 watch-glossary watch-spec watch-example verify update-testdata testdata-bundle check-clean-tree check-release-bump release major minor patch breaking feature fix

##@ Documents

all: $(PDFS) ## build every paper, the glossary, and the two specifications

$(PDF_DIR):
	mkdir -p $(PDF_DIR)

$(PDF_DIR)/01-ranke-graph.pdf: 01-ranke-graph/ranke-graph.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/02-ranke-db.pdf: 02-ranke-db/ranke-db.typ $(SHARED) 02-ranke-db/drawio/architecture.svg 02-ranke-db/drawio/architecture-storage\ stack.drawio.png | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/03-ranke-workers.pdf: 03-ranke-workers/ranke-workers.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/04-ranke-retrieval.pdf: 04-ranke-retrieval/ranke-retrieval.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/05-retrieval-coordination.pdf: 05-retrieval-coordination/ranke-coordination.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

# Series-wide terminology glossary — single-sourced from shared/glossary.typ.
$(PDF_DIR)/ranke-glossary.pdf: glossary/ranke-glossary.typ shared/glossary.typ | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

# Normative specification — the rules an implementation follows (companion doc).
$(PDF_DIR)/ranke-spec.pdf: spec/ranke-spec.typ shared/vocabulary.typ shared/constructs.typ | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

# The documentation format — the rules a part repo's docs/ tree follows, each
# with a stable id, released beside the specification.
$(PDF_DIR)/ranke-docs-spec.pdf: docs-spec/ranke-docs-spec.typ $(DOCS_BACKEND) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

# The example tree, built through the print backend. Not in PDFS and not
# released: it is a fixture, and what it proves is that it compiles. The shims
# are a prerequisite — without them a chapter's `#import "vocabulary.typ"` has
# nothing to resolve to.
$(PDF_DIR)/ranke-docs-example.pdf: $(DOCS_CHAPTERS) $(DOCS_ASSETS) $(DOCS_SHIMS) $(DOCS_BACKEND) | $(PDF_DIR)
	$(TYPST) compile --root . --input version=$(DOCS_VERSION) $(EXAMPLE_DIR)/index.typ $@

# Generated, gitignored, and rewritten whenever the fetcher changes — the same
# script four consumer repositories run, in its no-network mode.
$(DOCS_SHIMS) &: scripts/fetch-ranke-docs.sh
	@SHARED_DIR=shared DOCS_DIR=$(EXAMPLE_DIR) ./scripts/fetch-ranke-docs.sh --place

01: $(PDF_DIR)/01-ranke-graph.pdf ## build one paper by its number — likewise 02 … 05
02: $(PDF_DIR)/02-ranke-db.pdf
03: $(PDF_DIR)/03-ranke-workers.pdf
04: $(PDF_DIR)/04-ranke-retrieval.pdf
05: $(PDF_DIR)/05-retrieval-coordination.pdf
glossary: $(PDF_DIR)/ranke-glossary.pdf ## build the series-wide glossary
spec: $(PDF_DIR)/ranke-spec.pdf ## build the normative specification
docs-spec: $(PDF_DIR)/ranke-docs-spec.pdf ## build the documentation-format specification
example: $(PDF_DIR)/ranke-docs-example.pdf ## build the example docs tree to PDF
docs-place: $(DOCS_SHIMS) ## put the print backend where the example's chapters import it

# The same chapters, the other backend. A construct print can render and HTML
# cannot fails here, in this repository, rather than in ranke-website.
example-html: $(DOCS_CHAPTERS) $(DOCS_ASSETS) ## build the example docs tree to HTML through the stub backend
	@rm -rf $(HTML_DIR) && mkdir -p $(HTML_DIR)
	@cp $(DOCS_CHAPTERS) $(HTML_DIR)/
	@cp -r $(EXAMPLE_DIR)/assets $(HTML_DIR)/
	@cp $(HTML_BACKEND)/vocabulary.typ $(HTML_BACKEND)/handbook.typ $(HTML_DIR)/
	$(TYPST) compile --root . --features html --format html \
		--input version=$(DOCS_VERSION) $(HTML_DIR)/index.typ $(HTML_DIR)/index.html
	@echo "wrote $(HTML_DIR)/index.html"

# The documents packed for download, so a build that cannot clone still gets
# them: 120 KB against the 976 KB a full copy used to carry, since figure
# sources, working notes and built PDFs are left out. The asset name carries no
# version, so the release attaches it at a stable URL:
# releases/latest/download/ranke-docs.tar.gz. Which commit it came from is
# stamped inside, where it cannot drift from the files.
#
# The fetcher packs it, rather than a recipe of its own, so the tarball and the
# clone are the same selection — verified by unpacking one over the other.
DOCS_BUNDLE := dist/ranke-docs.tar.gz

docs-bundle: ## pack the documents as dist/ranke-docs.tar.gz for release
	@./scripts/fetch-ranke-docs.sh --bundle $(DOCS_BUNDLE)
	@mkdir -p dist
	@cp TYPST_VERSION dist/TYPST_VERSION

upgrade: ## check TYPST_VERSION against Typst's latest release
	@docs-spec/scripts/check-typst-upgrade.sh

docs-clean: ## remove the generated docs backend shims and the HTML build tree
	rm -f $(DOCS_SHIMS)
	rm -rf build

watch-01: ## rebuild paper 01 on every save — likewise watch-02 … watch-05, watch-glossary, watch-spec
	$(TYPST) watch --root . 01-ranke-graph/ranke-graph.typ $(PDF_DIR)/01-ranke-graph.pdf
watch-02:
	$(TYPST) watch --root . 02-ranke-db/ranke-db.typ $(PDF_DIR)/02-ranke-db.pdf
watch-03:
	$(TYPST) watch --root . 03-ranke-workers/ranke-workers.typ $(PDF_DIR)/03-ranke-workers.pdf
watch-04:
	$(TYPST) watch --root . 04-ranke-retrieval/ranke-retrieval.typ $(PDF_DIR)/04-ranke-retrieval.pdf
watch-05:
	$(TYPST) watch --root . 05-retrieval-coordination/ranke-coordination.typ $(PDF_DIR)/05-retrieval-coordination.pdf
watch-glossary:
	$(TYPST) watch --root . glossary/ranke-glossary.typ $(PDF_DIR)/ranke-glossary.pdf
watch-spec:
	$(TYPST) watch --root . spec/ranke-spec.typ $(PDF_DIR)/ranke-spec.pdf
watch-example: $(DOCS_SHIMS)
	$(TYPST) watch --root . $(EXAMPLE_DIR)/index.typ $(PDF_DIR)/ranke-docs-example.pdf

# Remove the built PDFs but keep the directory itself, so an open viewer or
# file watch holding its inode survives a clean.
clean: ## remove the built PDFs, keeping pdf/ itself
	rm -f $(PDF_DIR)/*.pdf
	rm -rf build

##@ Checks

# The RQL schema — the machine-readable form of the specification's RankeQL
# chapter, released as its own asset so every implementation downloads the same
# document. Two checks: the schema itself against the 2020-12 metaschema, and
# each of its `examples` against the schema, so a released schema never carries
# an example it would reject.
# shared/constructs.typ names what a rendering backend owes. This compiles both
# backends and fails on a name either leaves unbound, so the two cannot drift
# apart silently — a construct added to the list stops the build until both
# implement it.
constructs: ## check both rendering backends against the construct contract
	@mkdir -p build
	@$(TYPST) compile --root . docs-spec/check-backends.typ build/check-backends.pdf
	@echo "constructs: both backends bind the contract."

RQL_SCHEMA := spec/rql.schema.json

schema: ## validate the RQL schema against the metaschema, and its examples against itself
	@command -v jq > /dev/null || { echo "jq not found"; exit 1; }
	@command -v npx > /dev/null || { echo "npx not found — the schema check runs ajv-cli through it"; exit 1; }
	@npx --yes ajv-cli@5 compile --spec=draft2020 -s $(RQL_SCHEMA)
	@n=$$(jq '.examples | length // 0' $(RQL_SCHEMA)); \
	[ "$$n" -gt 0 ] || { echo "$(RQL_SCHEMA) carries no examples — nothing to check them against"; exit 1; }; \
	work=$$(mktemp -d); \
	i=0; while [ $$i -lt $$n ]; do \
		jq -c ".examples[$$i]" $(RQL_SCHEMA) > "$$work/example-$$i.json"; \
		i=$$((i + 1)); \
	done; \
	npx --yes ajv-cli@5 validate --spec=draft2020 -s $(RQL_SCHEMA) -d "$$work/*.json"; \
	status=$$?; \
	rm -rf "$$work"; \
	exit $$status

# Pre-release gate: every paper must compile and the schema must hold. Extend
# with more checks later (linting, link-checking, …); release depends on this
# passing.
verify: all schema constructs example example-html ## the pre-release gate: every document compiles, the schema holds, both docs backends render
	@echo "verify: all documents compiled, schema valid, both docs backends render."

##@ Conformance artifacts

# Regenerate the conformance artifacts under 01-ranke-graph/testdata/cbor.
#
# The generator is fetched from a RELEASED ranke-go, never a working copy, so the
# artifacts trace to a version rather than to whatever someone had checked out.
# The manifest records that version and the date. Pass a version to skip the
# prompt (scripting, CI):
#   make update-testdata RANKE_GO_VERSION=v0.5.1
#
# Left unset, it ASKS which version — go's module proxy resolves `@latest` to the
# newest non-prerelease tag only, so a run right after cutting an -rc silently
# fetched the release before it. The prompt lists recent tags, prereleases
# included, so that mistake is visible rather than made by default.
#
# Implementations fetch the latest of these files, so a regeneration reaches all
# of them at once. Hence the confirmation.
RANKE_GO         ?= github.com/rankegraph/ranke-go
RANKE_GO_VERSION ?=
TESTDATA_DIR     := 01-ranke-graph/testdata/cbor

update-testdata: ## regenerate 01-ranke-graph/testdata/cbor from a released ranke-go (asks first)
	@command -v go > /dev/null || { echo "go toolchain not found"; exit 1; }
	@version="$(RANKE_GO_VERSION)"; \
	if [ -z "$$version" ]; then \
		echo ""; \
		echo "  Recent $(RANKE_GO) versions (module proxy, oldest first):"; \
		tags="$$(curl -fsS "https://proxy.golang.org/$(RANKE_GO)/@v/list" 2>/dev/null | sort -V | tail -10)"; \
		if [ -n "$$tags" ]; then echo "$$tags" | sed 's/^/    /'; \
		else echo "    (proxy unreachable — type a version you know)"; fi; \
		echo ""; \
		printf "  Which version? [latest]: "; \
		read -r typed; \
		version="$${typed:-latest}"; \
	fi; \
	echo ""; \
	echo "  ##########################################################"; \
	echo "  ##                                                      ##"; \
	echo "  ##       OVERWRITING THE CONFORMANCE ARTIFACTS          ##"; \
	echo "  ##                                                      ##"; \
	echo "  ##########################################################"; \
	echo ""; \
	echo "  target    : $(TESTDATA_DIR)"; \
	echo "  generator : $(RANKE_GO)/cmd/vectors@$$version"; \
	echo ""; \
	echo "  Every implementation fetches the latest of these files, so"; \
	echo "  replacing them changes what conformance MEANS for all of"; \
	echo "  them, at once — no pin shields anyone from this."; \
	echo ""; \
	echo "  The directory is DELETED and rewritten. Nothing is"; \
	echo "  committed; review the diff, then commit by hand."; \
	echo ""; \
	printf "  Type YES to proceed: "; \
	read -r ans; \
	[ "$$ans" = "YES" ] || { echo ""; echo "  aborted — nothing was touched."; exit 1; }; \
	echo ""; \
	echo "  Fetching and compiling the generator. The first run builds the"; \
	echo "  whole library and its dependencies and takes a minute or two;"; \
	echo "  later runs are cached and quick. Package names below are it"; \
	echo "  working, not errors."; \
	echo ""; \
	rm -rf $(TESTDATA_DIR); \
	go run -v $(RANKE_GO)/cmd/vectors@$$version -out $(TESTDATA_DIR) || exit 1; \
	echo ""; \
	echo "  wrote $$(find $(TESTDATA_DIR) -type f | wc -l | tr -d ' ') file(s) to $(TESTDATA_DIR)"; \
	echo "  generated by $$(sed -n 's/.*"version": "\(.*\)".*/\1/p' $(TESTDATA_DIR)/manifest.json)"; \
	echo ""; \
	git status --short $(TESTDATA_DIR)

# Bundle the conformance artifacts for download, so another repo takes them without
# cloning. The asset name carries no version, so the release attaches it at a stable
# URL: releases/latest/download/ranke-testdata.tar.gz. Which version generated the
# set is inside the manifest, where it cannot drift from the files.
TESTDATA_BUNDLE := dist/ranke-testdata.tar.gz

testdata-bundle: ## pack those artifacts as dist/ranke-testdata.tar.gz for release
	@[ -d $(TESTDATA_DIR) ] || { echo "no artifacts at $(TESTDATA_DIR) — run 'make update-testdata'"; exit 1; }
	@mkdir -p dist
	@work=$$(mktemp -d); \
	mkdir -p "$$work/ranke-testdata"; \
	cp -r $(TESTDATA_DIR)/. "$$work/ranke-testdata/"; \
	tar -C "$$work" -czf $(TESTDATA_BUNDLE) ranke-testdata; \
	rm -rf "$$work"; \
	echo "wrote $(TESTDATA_BUNDLE) — $$(find $(TESTDATA_DIR) -type f | wc -l | tr -d ' ') file(s), generated by $$(sed -n 's/.*"version": "\(.*\)".*/\1/p' $(TESTDATA_DIR)/manifest.json)"

##@ Release

# Cut a release: clean tree → verify → merge to the default branch via PR → tag
# the merged tip → push the tag (which triggers release.yml) → return to your
# branch. Usage: make release <major|minor|patch> (aliases: breaking|feature|fix).
#
# check-clean-tree first, ahead of verify: a dirty tree is a free, instant check,
# and verify is not — failing on it should not cost a build first.
check-clean-tree:
	@[ -z "$$(git status --porcelain)" ] || { echo "working tree is dirty — commit or stash before releasing" >&2; exit 1; }

# Same reasoning as check-clean-tree: a missing or misspelled bump word is a free,
# instant check, and verify is not — scripts/release-cycle.sh's own case statement
# still validates it too, but only after verify already ran.
check-release-bump:
	@[ -n "$(filter major minor patch breaking feature fix,$(MAKECMDGOALS))" ] || \
		{ echo "usage: make release <major|breaking | minor|feature | patch|fix>" >&2; exit 1; }

release: check-clean-tree check-release-bump verify ## make release <major|minor|patch> — verify, merge to the default branch, tag, push
	@./scripts/release-cycle.sh $(filter major minor patch breaking feature fix,$(MAKECMDGOALS))

# Absorb the positional bump word in `make release <bump>` so it isn't treated
# as a missing target.
major minor patch breaking feature fix:
	@:

##@ Help

# Reads this file rather than a written list, so a target and its description
# travel together and the listing cannot drift from the rules.
help: ## list these targets
	@awk 'BEGIN { FS = ":.*##" } \
	     /^##@/               { printf "\n%s\n", substr($$0, 5); next } \
	     /^[a-z0-9_.-]+:.*##/ { printf "  %-16s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
