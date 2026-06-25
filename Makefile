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
  $(PDF_DIR)/06-ranke-cryptography.pdf

.PHONY: all clean 01 02 03 04 05 06 watch-01 watch-02 watch-03 watch-04 watch-05 watch-06 verify release major minor patch breaking feature fix

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

01: $(PDF_DIR)/01-ranke-graph.pdf
02: $(PDF_DIR)/02-ranke-db.pdf
03: $(PDF_DIR)/03-ranke-workers.pdf
04: $(PDF_DIR)/04-ranke-retrieval.pdf
05: $(PDF_DIR)/05-retrieval-coordination.pdf
06: $(PDF_DIR)/06-ranke-cryptography.pdf

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

# Remove the built PDFs but keep the directory itself, so an open viewer or
# file watch holding its inode survives a clean.
clean:
	rm -f $(PDF_DIR)/*.pdf

# Pre-release gate: every paper must compile. Extend with more checks later
# (linting, link-checking, …); release depends on this passing.
verify: all
	@echo "verify: all papers compiled."

# Cut a release: verify → clean tree → merge to the default branch via PR → tag
# the merged tip → push the tag (which triggers release.yml) → return to your
# branch. Usage: make release <major|minor|patch> (aliases: breaking|feature|fix).
release: verify
	@./scripts/release.sh $(filter major minor patch breaking feature fix,$(MAKECMDGOALS))

# Absorb the positional bump word in `make release <bump>` so it isn't treated
# as a missing target.
major minor patch breaking feature fix:
	@:
