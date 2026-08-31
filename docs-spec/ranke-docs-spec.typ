// docs-spec/ranke-docs-spec.typ — the Ranke Documentation Format.
//
// A companion document to the Ranke-Graph paper series, and the artifact a
// repository FOLLOWS when it writes documentation. The papers argue the ideas
// and the specification fixes the rules an implementation obeys; this document
// fixes the rules a documentation tree obeys, so one chapter file renders
// through more than one backend.
//
// It stands to the rendering backends as spec/ranke-spec.typ stands to ranke-go:
// this document specifies, shared/vocabulary.typ and ranke-website's own file
// implement, and docs-spec/{example,html-backend,check-backends.typ} are the
// evidence. A backend that disagrees with this document is the defect.
//
//   * shared/constructs.typ is the machine-readable half of §The constructs.
//     A construct added there is added here in the same change, and
//     docs-spec/check-backends.typ fails until both backends bind it.
//   * docs-spec/examples/docs-tree/ is the reference tree §Annex points at. It is built
//     by `make example` and `make example-html`, so the tree a part repository
//     copies is one that compiles, both ways.
//   * shared/glossary.typ carries the series' vocabulary. A term this document
//     introduces, renames, or redefines is updated there in the same change.
//
// Every normative statement carries a stable id (G-DIR, G-IMPORT, …). Ids never
// change meaning: retire an id rather than repurpose it, so a build comment
// citing "G-NOLAYOUT" means the same thing forever.
//
// Compile:  typst compile --root .. ranke-docs-spec.typ

#import "/shared/typography.typ": page-setup, typography
// Selective, so fletcher's `diagram` would not be shadowed if this document
// ever grows a figure — and so the constructs this document is *about* are the
// ones it is written with. `rule`, `listing` and `item` were each written twice,
// here and in the specification, before they moved into the vocabulary.
#import "/shared/vocabulary.typ": rule, listing, item
#import "/shared/constructs.typ": common, paper, manual

#show: page-setup
#show: typography

// The tiers this document uses. A tier is free text, so each document names the
// parties its own rules bind.
#let CHAPTER = "CHAPTER"
#let BACKEND = "BACKEND"
#let BUILD   = "BUILD"

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

The Ranke ecosystem is spread across repositories, and each of them documents
the part it holds. Those documents are wanted in two places at once: as a PDF
handbook attached to a release, and as pages on the project website. This
document fixes a format in which a chapter is written once and rendered by
either.

The mechanism is one indirection. A chapter names its vocabulary and the build
decides what that name resolves to. A part repository's `make docs` puts the
print rendering there; the website puts an HTML rendering there. The chapter is
the same file, and the format is the set of rules that keeps it so.

*This document is the specification; the backends are its implementations.*
`shared/vocabulary.typ` renders these constructs for print and ranke-website
renders them for the web, and neither is a reading source: this is. Where a
backend disagrees with this document, the backend is the defect — decide it that
way and fix it, rather than letting both stand. The same holds for the reference
tree of @sec:annex, which governs by example where this document is silent and
is a defect where it conflicts.

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
`docs-spec/examples/docs-tree/`, whose chapters are `01-first.typ` and `02-second.typ`.

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
`SHARED_DIR`, and `RANKE_DOCS_OFFLINE`. A build that cannot clone MAY take
`ranke-docs.tar.gz` from the release, which the same script packs and which
unpacks to the same tree.]

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

The series has two kinds of document. A *paper* argues a position and proves
what it claims; a *manual* tells a reader how something is used. They share a
look, a glossary, and most of their constructs, and part company at the few each
kind needs alone. `shared/constructs.typ` therefore declares three groups rather
than one list:

// Printed from shared/constructs.typ rather than typed out, so this document
// cannot come to disagree with the contract it describes.
#block(below: 1.4em, table(
  columns: (4.5em, 1fr),
  stroke: none,
  inset: (x: 0pt, y: 0.35em),
  [*common*], [both kinds use these --- #common.map(raw).join(", ")],
  [*paper*],  [`shared/template.typ` adds these, for the papers --- #paper.map(raw).join(", ")],
  [*manual*], [a docs chapter adds these --- #manual.map(raw).join(", ")],
))

#rule("G-CONSTRUCTS", CHAPTER)[A chapter may use the *common* and *manual*
groups. The *paper* group — #paper.map(raw).join(", ") — belongs to the
papers. A manual that proves a theorem has mistaken its kind; state the
guarantee and cite where it is proved.]

#rule("G-BACKEND", BACKEND)[A backend MUST bind every name in common + manual,
and MUST NOT bind a construct no group names. The print backend binds the paper
group as well, since it serves both kinds; a web backend is never asked for a
proof. Adding a construct means adding it to `shared/constructs.typ`, to this
section, and to the backends its group reaches, in one change;
`docs-spec/check-backends.typ` fails until they follow.]

What each construct a chapter may use means, and what it is for.

== Common <sec:common>

#item("concept(term, body)")[
  A prose-level definition of a central idea, set apart from the text around it.
  Use it where a reader meeting the term for the first time needs the whole idea
  in one place. At most a handful per chapter; a chapter of concept boxes has
  none.
]

#item("definition(body)")[
  A formal definition, numbered. Use it for a statement the rest of the chapter
  refers back to by number.
]

#item("theorem(body)")[
  A claim that is proved, numbered.
]

#item("corollary(body)")[
  A claim that follows from one already made, numbered.
]

#item("proof(body)")[
  The argument for the preceding theorem or corollary.
]

#item("part(label)")[
  A divider between groups of chapters, carrying the group's name. It belongs in
  the root, between includes, and it leaves section numbering alone.
]

#item("diagram(path, caption, width: 100%)")[
  A captioned picture. `path` is project-absolute and names a file under
  `docs/assets/`; see `G-ASSETS`.
]

#item("dref(label)")[
  A pointer to where a subject is treated at length — a paper section, another
  chapter. It renders as a short italic aside, so a reader skipping it loses
  nothing.
]

#item("todo(body)")[
  Placeholder prose, rendered so it is visible on the page and greppable in the
  source. A release MAY carry one; what a release MUST NOT carry is a
  placeholder that reads as finished text.
]

#item("gls(key), glspl(key)")[
  A term from the series glossary, singular and plural. See `G-GLS`.
]

#item("listing(body)")[
  A code block with room around it, so a rule or a paragraph following it reads
  as its own thing rather than as its caption.
]

#item("rule(id, tier, body)")[
  A normative statement: a stable citation handle, the party it binds, and the
  statement. `tier` is free text, because what a rule binds differs by document —
  this one says CHAPTER, BACKEND or BUILD, the specification says FORCED or FREE.
  A manual uses it for guarantees it fixes itself, never to restate a rule the
  specification already owns; see `G-CITE`.
]

== Manual <sec:manual-constructs>

#item("note(body)")[
  An aside worth knowing, which the reader loses nothing by reading past.
]

#item("warning(body)")[
  Something the reader can lose or break — data, money, time.
]

#item("item(signature, body)")[
  A named thing with a signature: a command-line flag, a configuration key, an
  API field. The workhorse of reference documentation, and what this section is
  built from.
]

#item("example(body, title: none)")[
  A worked case. The title is optional, since an example following the prose it
  illustrates often needs no name.
]

There are two admonition levels and deliberately only two. A third — `caution`,
`important`, `tip` — sits between `note` and `warning` in no way an author can
decide quickly, so the choice becomes a coin toss and the levels stop carrying
information. A document that needs a third has usually found a section heading
instead.

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
it. The appendix MUST print every entry rather than only the referenced ones: an
entry's description names further terms, so a filtered appendix adds references
each layout run and a document naming few terms never settles. An HTML backend
has no such constraint: it reads the 39 entries directly and links to a glossary
page.]

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

`imageonside` sits in the paper group for the same reason. Its second argument
is arbitrary content, so a chapter using it would have to build an image itself,
which `G-NOLAYOUT` forbids. A chapter wanting a picture uses `diagram`.

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

`docs-spec/examples/html-backend/` is an example of the second party: what a
renderer implements, in plain elements and classes with no styling. It exists so
the reference tree compiles both ways in this repository's own gate, and it is
the worked example of what implementing the contract asks. Its counterpart,
`docs-spec/examples/docs-tree/`, is the example of the first party — what a
chapter author writes.

= Building <sec:building>

#rule("G-VERSION", BUILD)[The version a handbook prints comes from the build,
not the source: `--input version=v0.21.0`. Absent, a handbook says `dev`, which
is what a working copy should say.]

The targets in this repository, which a part repository mirrors:

#listing[
```
make docs-place     put the print backend where the example imports it
make example        build the example tree to PDF
make example-html   build it to HTML through the stub backend
make docs-spec      build this document
```
]

`make verify` runs all four, so a chapter that renders through one backend and
not the other stops a release rather than reaching one.

#rule("G-RELEASE", BUILD)[A part repository attaches its handbook PDF to its
release. This document is attached to the ranke-graph release beside
`ranke-spec.pdf`, since a format and the rules it serves are read together.]

= Annex — The Reference Tree <sec:annex>

`docs-spec/examples/docs-tree/` is a documentation tree written in this format: a root,
two chapters, one asset, and every construct of @sec:constructs called at least
once. Copy the directory into your repository as `docs/` and you have a
compiling tree to start from.

*The prose is placeholder text, and deliberately so.* An example filled with
real documentation is documentation that must be kept true, and this one would
have to be kept true against the papers and the specification — the very drift
`G-CITE` exists to prevent. So the prose is Typst's `lorem`, which cannot go out
of date, and what the example demonstrates is the calls: the labels, the ids,
the signatures, and the shape of the tree. Read the source rather than the page.

Two things to change on copying. Replace the prose, and update the `diagram`
paths, which are project-absolute (`G-ASSETS`) and point into
`docs-spec/examples/docs-tree/` as they stand.

It is also the fixture the gate runs. `make example` builds it through
`shared/handbook.typ`, `make example-html` builds the same files through
`docs-spec/examples/html-backend/`, and `docs-spec/check-backends.typ` compiles both
vocabularies and fails on an unbound name. A rule stated here without a tree
that exercises it is a rule nothing holds to.

#v(1em)
#text(size: 0.92em)[*Acknowledgements.* This document was prepared with the
assistance of AI tools (Claude Opus 5, Anthropic).]
