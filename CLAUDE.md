<!-- NOTE: AGENTS.md is a symlink to this file (CLAUDE.md). Editing either edits both; they are the same file. -->

# Agent onboarding

This repository is a series of papers on Ranke-Graph — a provenance-first
foundation for knowledge systems. Each numbered directory holds one paper as a
Typst source file.

## First thing to do as a new agent

Read the Typst source of **all** papers to get up to speed on the project. Read
them in order:

1. `01-ranke-graph/ranke-graph.typ` — the graph foundation
2. `02-ranke-db/ranke-db.typ` — storage / database
3. `03-ranke-workers/ranke-workers.typ` — workers
4. `04-ranke-retrieval/ranke-retrieval.typ` — retrieval
5. `05-retrieval-coordination/ranke-coordination.typ` — retrieval coordination

Shared definitions live in `shared/` — `shared/vocabulary.typ` (the constructs
a document writes with), `shared/typography.typ` (the look), `shared/template.typ`
(the paper root, which re-exports the vocabulary), `shared/handbook.typ` (the docs
root), `shared/constructs.typ` (the construct contract), `shared/sources.bib`
(bibliography), and `shared/glossary.typ` (the series' vocabulary). Read these
too, since every paper depends on them.

`shared/glossary.typ` is the single source of truth for terminology. Changing
or adding a term in a paper or in the specification means updating the matching
entry there in the same change.

## Companion documents

`spec/ranke-spec.typ` is the normative specification: the rules an implementation
follows, each with a stable id (`V-…`, `R-…`). `docs-spec/ranke-docs-spec.typ`
is the documentation format: the rules a repository's `docs/` tree follows, each
with a stable id (`G-…`), so one chapter file renders to both PDF and HTML. Read
the format before touching `docs/`, `shared/vocabulary.typ`,
`shared/constructs.typ`, or `docs-spec/examples/html-backend/`.

`docs-spec/` holds that document and the things that prove it. It stands to
`shared/vocabulary.typ` as `spec/` stands to ranke-go: this specifies, the
backends implement, and where they disagree the backend is the defect.

- `examples/docs-tree/` — an example of what a chapter author writes, with
  placeholder prose, which a part repository copies to start its own `docs/`.
- `examples/html-backend/` — an example of what a renderer implements, and the
  second backend the gate builds the tree through.
- `check-backends.typ` — fails on a construct either backend leaves unbound.

The two files the example tree imports, `vocabulary.typ` and `handbook.typ`, are
placed by `make docs-place` and gitignored. `make example` and `make
example-html` build the same chapters through the two backends; `make verify`
runs both. Neither example is released.

Only after reading the papers should you start on the task the user gives you.
