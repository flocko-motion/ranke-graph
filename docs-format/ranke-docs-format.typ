// docs-format/ranke-docs-format.typ — the Ranke Documentation Format.
//
// A companion document to the Ranke-Graph paper series, and the artifact a
// repository FOLLOWS when it writes documentation. The papers argue the ideas
// and the specification fixes the rules an implementation obeys; this document
// fixes the rules a documentation tree obeys, so one chapter file renders
// through more than one backend.
//
//   * shared/constructs.typ is the machine-readable half of §The constructs.
//     A construct added there is added here in the same change, and
//     docs-format/check-backends.typ fails until both backends bind it.
//   * docs/ in this repository is the reference tree §Annex points at. It is
//     built by `make handbook` and `make handbook-html`, so the example a part
//     repo copies is one that compiles.
//   * shared/glossary.typ carries the series' vocabulary. A term this document
//     introduces, renames, or redefines is updated there in the same change.
//
// Every normative statement carries a stable id (G-DIR, G-IMPORT, …). Ids never
// change meaning: retire an id rather than repurpose it, so a build comment
// citing "G-NOLAYOUT" means the same thing forever.
//
// Compile:  typst compile --root .. ranke-docs-format.typ

#import "/shared/typography.typ": page-setup, typography

#show: page-setup
#show: typography

// A normative rule, rendered as the specification renders one: a hanging label
// carrying the citation handle and the party it binds.
#let rule(id, tier, body) = block(above: 0.6em, below: 0.6em, inset: (left: 0.2em))[
  #grid(columns: (8.5em, 1fr), column-gutter: 0.6em,
    [#text(weight: "bold")[#id] \ #text(size: 0.78em, fill: rgb("#666"))[#tier]],
    [#body])
]
#let CHAPTER = "CHAPTER"
#let BACKEND = "BACKEND"
#let BUILD   = "BUILD"

// A code listing. The space beneath keeps a following #rule from reading as the
// listing's caption.
#let listing(body) = block(below: 1.4em)[
  #show raw: set text(size: 0.85em)
  #body
]

#let construct(signature, body) = block(above: 0.7em, below: 0.7em)[
  #raw(signature, lang: "typc") \
  #block(inset: (left: 1.2em), body)
]

#align(center)[
  #text(size: 1.55em, weight: "bold")[Ranke — The Documentation Format] \
  #v(0.3em)
  #text(size: 0.95em, style: "italic")[How a part repository writes documentation
    that renders to more than one medium] \
  #v(0.2em)
  #text(size: 0.85em, style: "italic")[Companion to the Ranke-Graph paper series — draft]
]
#v(1.2em)

= Purpose and Status <sec:purpose>

The Ranke ecosystem spans several repositories, and each of them documents the
part it holds. Those documents are wanted in two places at once: as a PDF
handbook attached to a release, and as pages on the project website. This
document fixes a format in which a chapter is written once and rendered by
either.

The mechanism is one indirection. A chapter names its vocabulary and the build
decides what that name resolves to. A part repository's `make docs` puts the
print rendering there; the website puts an HTML rendering there. The chapter is
the same file, and the format is the set of rules that keeps it so.

Where this document is silent, the reference tree in @sec:annex governs by
example, and where the two disagree the tree is a defect: fix it rather than
letting both stand.

= How to Read This <sec:conventions>

*Normative keywords.* *MUST*, *MUST NOT*, *SHOULD*, *SHOULD NOT*, and *MAY* are
used as in RFC 2119. A *MUST* is a conformance condition: a tree that violates
it renders through one backend and fails through the other, which is the failure
this format exists to prevent.

*Rule ids and tiers.* Each rule carries a stable id and names the party it
binds:

#rule("G-…", CHAPTER)[Binds the *author of a chapter*. Breaking one of these
produces a document that renders in the medium it was written against and fails
in the other.]

#rule("G-…", BACKEND)[Binds a *rendering backend* — `shared/vocabulary.typ` for
print, the website's own file for HTML. Breaking one of these breaks every
chapter at once.]

#rule("G-…", BUILD)[Binds the *build* that assembles a tree: a `make docs`
target, or the website's page pipeline.]

*Examples.* Every example is stated against the reference tree of @sec:annex,
whose chapters are `docs/01-claims.typ` and `docs/02-archives.typ`.

= The docs Tree <sec:layout>

#rule("G-DIR", CHAPTER)[Documentation lives under `docs/` at the repository
root. Chapters are files directly in it; pictures live in `docs/assets/`. The
fetched copy of the ranke-graph documents lands in `docs/papers/`, which is
gitignored.]

#rule("G-ROOT", CHAPTER)[A tree has one root document, `docs/index.typ`. It
applies the `handbook` show rule, states the title, and includes the chapters in
reading order. Prose that introduces the whole document belongs here; prose
about a subject belongs in a chapter.]

#rule("G-CHAPTER", CHAPTER)[A chapter is one file, opening with
`#import "vocabulary.typ": *` and a level-one heading carrying a label. It is
included by the root and MUST NOT include another chapter.]

The tree the rules describe:

#listing[
```
docs/
  index.typ          authored   the root: title, front prose, includes
  01-claims.typ      authored   a chapter
  02-archives.typ    authored   a chapter
  assets/            authored   pictures a diagram() names
  vocabulary.typ     supplied   the constructs, in one rendering
  handbook.typ       supplied   the document root, in one rendering
  papers/            supplied   the fetched ranke-graph documents
```
]

#rule("G-SUPPLIED", BUILD)[`docs/vocabulary.typ`, `docs/handbook.typ`, and
`docs/papers/` are written by the build and MUST be gitignored. Committing one
of them pins a repository to a rendering, which is the coupling the format
removes. The three lines a part repository adds to `.gitignore`:

#listing[
```
docs/papers/
docs/vocabulary.typ
docs/handbook.typ
```
]
]

#rule("G-FETCH", BUILD)[A build obtains the supplied files with
`scripts/fetch-ranke-docs.sh` from ranke-graph, run with `DOCS_DIR=docs`. The
script is downloaded rather than vendored, so four consumers cannot drift apart;
its own header documents `RANKE_GRAPH_REF`, `PAPERS_DIR`, `DOCS_DIR`,
`SHARED_DIR`, and `RANKE_DOCS_OFFLINE`.]

= The Import-Path Contract <sec:imports>

#rule("G-IMPORT", CHAPTER)[A chapter imports `vocabulary.typ`, by that name,
relative to itself, and imports nothing else. The root imports `handbook.typ`
the same way, and MAY also import `vocabulary.typ`.]

The name is the whole contract. A chapter never learns which rendering answers
it, and a backend never learns which chapter is asking. Both are then free: a
backend is swapped by replacing one file, and the website vendors a chapter
without rewriting a line of it.

#rule("G-CLOSURE", CHAPTER)[A chapter's dependencies MUST lie inside its own
`docs/` tree or the fetched `docs/papers/`. Reaching into a sibling directory of
the repository, or into a second repository, makes the chapter unrenderable
anywhere but where it was written.]

#rule("G-COMPILE", BUILD)[A tree is compiled with `--root` at the repository
root. The supplied files use project-absolute paths, which resolve against that
root and against nothing else.]

= The Constructs <sec:constructs>

#rule("G-CONSTRUCTS", BACKEND)[The construct contract is the list in
`shared/constructs.typ`. A backend MUST bind every name in it. Adding a
construct means adding it to that list, to this section, and to both backends,
in one change; `docs-format/check-backends.typ` fails until the backends
follow.]

What each construct means, and what it is for:

#construct("concept(term, body)")[
  A prose-level definition of a central idea, set apart from the text around it.
  Use it where a reader meeting the term for the first time needs the whole idea
  in one place. At most a handful per chapter; a chapter of concept boxes has
  none.
]

#construct("definition(body)")[
  A formal definition, numbered. Use it for a statement the rest of the chapter
  refers back to by number.
]

#construct("theorem(body)")[
  A claim that is proved, numbered.
]

#construct("corollary(body)")[
  A claim that follows from one already made, numbered.
]

#construct("proof(body)")[
  The argument for the preceding theorem or corollary.
]

#construct("part(label)")[
  A divider between groups of chapters, carrying the group's name. It belongs in
  the root, between includes, and it leaves section numbering alone.
]

#construct("diagram(path, caption, width: 100%)")[
  A captioned picture. `path` is project-absolute and names a file under
  `docs/assets/`; see `G-ASSETS`.
]

#construct("dref(label)")[
  A pointer to where a subject is treated at length — a paper section, another
  chapter. It renders as a short italic aside, so a reader skipping it loses
  nothing.
]

#construct("todo(body)")[
  Placeholder prose, rendered so it is visible on the page and greppable in the
  source. A release MAY carry one; what a release MUST NOT carry is a
  placeholder that reads as finished text.
]

#construct("gls(key), glspl(key)")[
  A term from the series glossary, singular and plural. See `G-GLS`.
]

#rule("G-ASSETS", CHAPTER)[A `diagram` path MUST be project-absolute, beginning
with `/`, and MUST name a file under the tree's `assets/` directory:
`#diagram("/docs/assets/claim.svg", [ … ])`. Typst resolves a relative path
against the file holding the `image()` call, which is the backend's, so a
relative path sends the print backend looking beside `vocabulary.typ`. The
backends assert the leading slash.]

#rule("G-XREF", CHAPTER)[A heading or diagram a chapter cites carries a label:
`<ch:claims>`, `<sec:identity>`, `<fig:claim>`. References use `@` and resolve
within the assembled document, so a chapter MUST NOT cite a label another
chapter owns unless that chapter is in the same tree.]

#rule("G-XREF-B", BACKEND)[A backend MUST number headings and MUST build
`diagram` on Typst's `figure`, so `@sec:…` and `@fig:…` resolve. An HTML backend
replaces `image()` inside the figure and keeps the figure, since a bare
`html.elem` cannot be referenced.]

= Terminology <sec:terminology>

#rule("G-GLS", CHAPTER)[A term from the series vocabulary is written
`#gls("claim")`, never as plain text on first use. The keys are those in
`shared/glossary.typ`, which is the single source of truth; a chapter that needs
a term the glossary lacks adds it there in the same change.]

#rule("G-GLOSSARY", BACKEND)[A print backend's root MUST print a glossary
appendix. The `glossarium` package creates a term's label where the glossary is
printed, so an appendix is what makes `#gls("claim")` resolve rather than fail;
`shared/handbook.typ` prints one after the body and offers no way to suppress
it. An HTML backend has no such constraint: it reads the 39 entries directly and
links to a glossary page.]

#rule("G-CITE", CHAPTER)[Where a rule of the normative specification governs, a
chapter cites its id — `V-ID`, `R-CEIL` — rather than restating the rule.
Restating it creates a second wording that will drift from the first.]

= What a Chapter May Not Do <sec:nolayout>

#rule("G-NOLAYOUT", CHAPTER)[A chapter MUST NOT call `set page`, `align`, `v`,
`h`, `pagebreak`, `image`, `columns`, or `place`, and MUST NOT set document-level
`text` or `par` rules. These are the functions HTML export ignores or mangles, so
a chapter using one renders correctly in print and silently differently on the
web.]

The rule reads as a restriction and works as a division of labour. Sheet
geometry, front matter, and the glossary appendix belong to the root; the look
of a construct belongs to the backend; what the chapter owns is the prose and
which construct carries it. A chapter that wants a picture beside its text is
asking for a construct the format does not yet have, and the answer is to add
one under `G-CONSTRUCTS`, not to reach past the vocabulary.

Ordinary Typst markup stays available: headings, lists, tables, `raw` blocks,
`emph`, `strong`, footnotes, and mathematics all export to both media. So does
`figure`, though a picture goes through `diagram`.

`imageonside` is deliberately outside the contract. Its second argument is
arbitrary content, so a chapter using it would have to build an image itself,
which `G-NOLAYOUT` forbids. It remains available to the papers, which are print
documents and say so.

= The Two Backends <sec:backends>

A backend is a `vocabulary.typ` binding every construct, and a `handbook.typ`
binding a `handbook` show rule. Two differences separate the print backend from
a web one, and they are the whole of what a second backend has to think about.

*Pictures.* Under HTML export `image()` inlines the file as a base64 data URI,
which carries the bytes of every picture into the page. An HTML `diagram`
therefore emits an `img` element naming the path, inside the same `figure` the
print backend uses.

*Terms.* `glossarium` builds its labels where a glossary is printed. A web page
has nowhere to print one, so an HTML `gls` reads `entries` from
`shared/glossary.typ` — 39 terms, importable on its own — and links to a
glossary page.

#rule("G-BACKEND", BACKEND)[A backend MUST bind every name in
`shared/constructs.typ` and MUST NOT bind a construct the list omits. A chapter
written against a construct one backend invented fails everywhere else.]

`docs-format/html-backend/` holds a stub HTML backend: plain elements, classes,
no styling. It exists so the reference tree compiles both ways in this
repository's own gate, and it doubles as the worked example of what implementing
the contract asks.

= Building <sec:building>

#rule("G-VERSION", BUILD)[The version a handbook prints comes from the build,
not the source: `--input version=v0.21.0`. Absent, a handbook says `dev`, which
is what a working copy should say.]

The targets in this repository, which a part repository mirrors:

#listing[
```
make docs-place     put the print backend into docs/
make handbook       build docs/ to PDF
make handbook-html  build docs/ to HTML through the stub backend
make docs-format    build this document
```
]

`make verify` runs all four, so a chapter that renders through one backend and
not the other stops a release rather than reaching one.

#rule("G-RELEASE", BUILD)[A part repository attaches its handbook PDF to its
release. This document is attached to the ranke-graph release beside
`ranke-spec.pdf`, since a format and the rules it serves are read together.]

= Annex — The Reference Tree <sec:annex>

`docs/` in this repository is a documentation tree in this format, covering the
foundation part. It is the tree a part repository copies: two chapters, a root,
one asset, and every construct in @sec:constructs used at least once. Copy it,
delete the prose, and what remains is a compiling tree.

It is also the fixture the gate runs. `make handbook` builds it through
`shared/handbook.typ`, `make handbook-html` builds the same files through
`docs-format/html-backend/`, and `docs-format/check-backends.typ` compiles both
vocabularies and fails on an unbound name. A rule stated here without a tree
that exercises it is a rule nothing holds to.

#v(1em)
#text(size: 0.92em)[*Acknowledgements.* This document was prepared with the
assistance of AI tools (Claude Opus 5, Anthropic).]
