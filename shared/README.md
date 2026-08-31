# `shared/`

The files every Ranke document draws on: the typography, the constructs a
document writes with, the series' vocabulary, and the two document roots. This
is internal machinery. What a reader downloads is described in the top-level
[README](../README.md); the rules a documentation tree follows are stated in
`docs-spec/ranke-docs-spec.typ`, and this file describes the pieces rather
than restating those rules.

## The files

| File | What it holds |
| --- | --- |
| `typography.typ` | `page-setup` and `typography`, the two show-rule functions that give a Ranke document its look |
| `constructs.typ` | `constructs`, the list of names a rendering backend must bind, and `unbound()`, which checks a backend against it |
| `vocabulary.typ` | the print rendering of every construct — `concept`, `definition`, `theorem`, `corollary`, `proof`, `part`, `diagram`, `dref`, `todo`, `gls`, `glspl`, and `imageonside` |
| `glossary.typ` | the 39 canonical terms, and the `glossarium` adapter that renders them |
| `template.typ` | `paper`, the root a paper applies |
| `handbook.typ` | `handbook`, the root a documentation tree applies |
| `sources.bib` | the bibliography the papers cite |

They import in one direction, so a change reaches its dependents and never
loops back:

```
constructs.typ ─┐
                ├─→ vocabulary.typ ─┬─→ template.typ   (papers)
glossary.typ ───┘                   └─→ handbook.typ   (docs trees)
                                    ↗
typography.typ ─────────────────────┘
```

## Using it from a paper

One import, which brings the root and every construct:

```typst
#import "../shared/template.typ": *
#show: paper.with(
  title:  "…",
  author: "…",
  date:   "2026-05-03",
  status: "draft",
  abstract: [ … ],
)
```

`template.typ` re-exports `vocabulary.typ`, so `#definition[…]` and the rest are
in scope without a second import.

## Using it from a documentation tree

A chapter imports a sibling `vocabulary.typ`, and the build decides which
rendering lives at that name — this repository's `docs/` tree resolves to the
files here, ranke-website resolves to an HTML rendering of its own:

```typst
#import "vocabulary.typ": *
```

`scripts/fetch-ranke-docs.sh` writes that file. In this repository,
`make docs-place` runs it in its no-network mode against `docs-spec/examples/docs-tree/`;
in a part repository,
`make docs` fetches this directory and points the file at the copy. A build
that cannot clone takes `ranke-docs.tar.gz` from the release instead, which
carries this directory among the rest. The authoring guide states the rest.

## Rules of thumb

**`vocabulary.typ` sets up no page.** Sheet geometry, front matter, and the
glossary appendix belong to a root. A construct that needs one of those is a
construct a second backend cannot render, which is the coupling the split
removes.

**A construct is a contract, not a convenience.** Adding one means adding it to
`constructs.typ`, to `vocabulary.typ`, to the HTML backend under
`docs-spec/examples/html-backend/`, and to the guide's construct section, in one
change. `make constructs` fails until the backends agree, and `make verify`
runs it.

**`glossary.typ` is the single source of truth for terminology.** A term a
paper or the specification introduces, renames, or redefines is updated there
in the same change. The entry data and the `glossarium` adapter are held apart
on purpose: a version of the package that renames a function is fixed in the
adapter block alone.

**`#gls()` needs a printed glossary.** `glossarium` creates a term's label
where the glossary is printed, so a document that names a term and prints no
glossary fails to compile. `handbook.typ` prints one after the body, and prints
every entry rather than the referenced ones — an entry's description names
further terms, so a filtered appendix grows each layout run and a document
naming few terms never settles.

**Changing typography changes both roots.** `typography.typ` is what keeps a
handbook looking like a paper. Compare page renders rather than PDF bytes when
checking that a refactor changed nothing:

```
typst compile --root . --format png --ppi 72 01-ranke-graph/ranke-graph.typ 'out/{p}.png'
```

A PDF carries a build timestamp, so its hash differs on every run; the rendered
pages do not.
