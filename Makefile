# Build the Ranke papers with Typst.
#
# Usage:
#   make             # build all papers
#   make 01          # build paper 01 only
#   make watch-01    # rebuild paper 01 on every save
#   make clean       # remove built PDFs
#
# Sources live per paper under NN-*/.  Shared assets (template, bibliography)
# live under shared/.  All built PDFs land in pdf/, named after the paper
# directory (pdf/01-ranke-graph.pdf, pdf/02-ranke-db.pdf, ...).

TYPST   := typst
SHARED  := shared/template.typ shared/sources.bib
PDF_DIR := pdf

PDFS := \
  $(PDF_DIR)/01-ranke-graph.pdf \
  $(PDF_DIR)/02-ranke-db.pdf \
  $(PDF_DIR)/03-ranke-workers.pdf \
  $(PDF_DIR)/04-ranke-retrieval.pdf \
  $(PDF_DIR)/05-retrieval-coordination.pdf \
  $(PDF_DIR)/06-ranke-cryptography.pdf \
  $(PDF_DIR)/ranke-glossary.pdf \
  $(PDF_DIR)/ranke-spec.pdf

.PHONY: all clean 01 02 03 04 05 06 glossary spec watch-01 watch-02 watch-03 watch-04 watch-05 watch-06 watch-glossary watch-spec verify update-testdata testdata-bundle release major minor patch breaking feature fix

all: $(PDFS)

$(PDF_DIR):
	mkdir -p $(PDF_DIR)

$(PDF_DIR)/01-ranke-graph.pdf: 01-ranke-graph/ranke-graph.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/02-ranke-db.pdf: 02-ranke-db/ranke-db.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/03-ranke-workers.pdf: 03-ranke-workers/ranke-workers.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/04-ranke-retrieval.pdf: 04-ranke-retrieval/ranke-retrieval.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/05-retrieval-coordination.pdf: 05-retrieval-coordination/ranke-coordination.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

$(PDF_DIR)/06-ranke-cryptography.pdf: 06-ranke-cryptography/ranke-cryptography.typ $(SHARED) | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

# Series-wide terminology glossary — single-sourced from shared/glossary.typ.
$(PDF_DIR)/ranke-glossary.pdf: glossary/ranke-glossary.typ shared/glossary.typ | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

# Normative specification — the rules an implementation follows (companion doc).
$(PDF_DIR)/ranke-spec.pdf: spec/ranke-spec.typ | $(PDF_DIR)
	$(TYPST) compile --root . $< $@

01: $(PDF_DIR)/01-ranke-graph.pdf
02: $(PDF_DIR)/02-ranke-db.pdf
03: $(PDF_DIR)/03-ranke-workers.pdf
04: $(PDF_DIR)/04-ranke-retrieval.pdf
05: $(PDF_DIR)/05-retrieval-coordination.pdf
06: $(PDF_DIR)/06-ranke-cryptography.pdf
glossary: $(PDF_DIR)/ranke-glossary.pdf
spec: $(PDF_DIR)/ranke-spec.pdf

watch-01:
	$(TYPST) watch --root . 01-ranke-graph/ranke-graph.typ $(PDF_DIR)/01-ranke-graph.pdf
watch-02:
	$(TYPST) watch --root . 02-ranke-db/ranke-db.typ $(PDF_DIR)/02-ranke-db.pdf
watch-03:
	$(TYPST) watch --root . 03-ranke-workers/ranke-workers.typ $(PDF_DIR)/03-ranke-workers.pdf
watch-04:
	$(TYPST) watch --root . 04-ranke-retrieval/ranke-retrieval.typ $(PDF_DIR)/04-ranke-retrieval.pdf
watch-05:
	$(TYPST) watch --root . 05-retrieval-coordination/ranke-coordination.typ $(PDF_DIR)/05-retrieval-coordination.pdf
watch-06:
	$(TYPST) watch --root . 06-ranke-cryptography/ranke-cryptography.typ $(PDF_DIR)/06-ranke-cryptography.pdf
watch-glossary:
	$(TYPST) watch --root . glossary/ranke-glossary.typ $(PDF_DIR)/ranke-glossary.pdf
watch-spec:
	$(TYPST) watch --root . spec/ranke-spec.typ $(PDF_DIR)/ranke-spec.pdf

# Remove the built PDFs but keep the directory itself, so an open viewer or
# file watch holding its inode survives a clean.
clean:
	rm -f $(PDF_DIR)/*.pdf

# Pre-release gate: every paper must compile. Extend with more checks later
# (linting, link-checking, …); release depends on this passing.
verify: all
	@echo "verify: all papers compiled."

# Regenerate the conformance artifacts under 01-ranke-graph/testdata/cbor.
#
# The generator is fetched from a RELEASED ranke-go, never a working copy, so the
# artifacts trace to a version rather than to whatever someone had checked out.
# The manifest records that version and the date. Override the release with:
#   make update-testdata RANKE_GO_VERSION=v0.5.1
#
# Implementations fetch the latest of these files, so a regeneration reaches all
# of them at once. Hence the confirmation.
RANKE_GO         ?= github.com/flocko-motion/ranke-go
RANKE_GO_VERSION ?= latest
TESTDATA_DIR     := 01-ranke-graph/testdata/cbor

update-testdata:
	@command -v go > /dev/null || { echo "go toolchain not found"; exit 1; }
	@echo ""; \
	echo "  ##########################################################"; \
	echo "  ##                                                      ##"; \
	echo "  ##       OVERWRITING THE CONFORMANCE ARTIFACTS          ##"; \
	echo "  ##                                                      ##"; \
	echo "  ##########################################################"; \
	echo ""; \
	echo "  target    : $(TESTDATA_DIR)"; \
	echo "  generator : $(RANKE_GO)/cmd/vectors@$(RANKE_GO_VERSION)"; \
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
	go run -v $(RANKE_GO)/cmd/vectors@$(RANKE_GO_VERSION) -out $(TESTDATA_DIR) || exit 1; \
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

testdata-bundle:
	@[ -d $(TESTDATA_DIR) ] || { echo "no artifacts at $(TESTDATA_DIR) — run 'make update-testdata'"; exit 1; }
	@mkdir -p dist
	@work=$$(mktemp -d); \
	mkdir -p "$$work/ranke-testdata"; \
	cp -r $(TESTDATA_DIR)/. "$$work/ranke-testdata/"; \
	tar -C "$$work" -czf $(TESTDATA_BUNDLE) ranke-testdata; \
	rm -rf "$$work"; \
	echo "wrote $(TESTDATA_BUNDLE) — $$(find $(TESTDATA_DIR) -type f | wc -l | tr -d ' ') file(s), generated by $$(sed -n 's/.*"version": "\(.*\)".*/\1/p' $(TESTDATA_DIR)/manifest.json)"

# Cut a release: verify → clean tree → merge to the default branch via PR → tag
# the merged tip → push the tag (which triggers release.yml) → return to your
# branch. Usage: make release <major|minor|patch> (aliases: breaking|feature|fix).
release: verify
	@./scripts/release.sh $(filter major minor patch breaking feature fix,$(MAKECMDGOALS))

# Absorb the positional bump word in `make release <bump>` so it isn't treated
# as a missing target.
major minor patch breaking feature fix:
	@:
