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
6. `06-ranke-cryptography/ranke-cryptography.typ` — cryptography

Shared definitions live in `shared/` — `shared/template.typ` (Typst template)
and `shared/sources.bib` (bibliography). Read these too, since every paper
depends on them.

Only after reading the papers should you start on the task the user gives you.
