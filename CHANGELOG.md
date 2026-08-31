# Changelog

What each release changed in the artifacts a reader depends on: the rules an
implementation follows, the papers' claims, the series' vocabulary, and the
conformance vectors. A change earns an entry when it alters what a document
requires, defines, or removes; rewording does not.

## Unreleased

**Documentation format.** A new companion document,
`docs-format/ranke-docs-format.typ`, released as `ranke-docs-format.pdf`
alongside the specification. It fixes the rules a repository's `docs/` tree
follows so one chapter file renders to both PDF and HTML: the tree layout
(`G-DIR`, `G-ROOT`, `G-CHAPTER`), the import-path contract (`G-IMPORT`,
`G-CLOSURE`, `G-COMPILE`), what each construct means (`G-CONSTRUCTS`), the
rule that a chapter may not reach past the vocabulary into raw layout
(`G-NOLAYOUT`), assets and cross-references (`G-ASSETS`, `G-XREF`,
`G-XREF-B`), terminology (`G-GLS`, `G-GLOSSARY`, `G-CITE`), what a backend
owes (`G-BACKEND`), and the build (`G-SUPPLIED`, `G-FETCH`, `G-VERSION`,
`G-RELEASE`).

**Vocabulary split.** The constructs a document writes with move from
`shared/template.typ` into `shared/vocabulary.typ`, which carries no
page-level layout, so a second renderer can bind the same names.
`shared/typography.typ` holds the look both roots draw on, and
`shared/template.typ` re-exports everything, leaving the papers unchanged —
they render identically. `shared/constructs.typ` names the contract in one
place, and `docs-format/check-backends.typ` fails the build on a name either
backend leaves unbound.

**New constructs.** `diagram(path, caption)`, a captioned picture named by a
project-absolute path; it is the branch point an HTML backend needs, since
`image()` under HTML export inlines a base64 data URI.

**Handbook root.** `shared/handbook.typ`, the docs root: paper typography, its
own front matter, a version from `--input version=`, and a glossary appendix
after the body. The appendix is what makes `#gls()` resolve, since glossarium
creates a term's label where the glossary is printed.

**Reference tree.** `docs/` holds a documentation tree in the format, covering
the foundation part, released as `ranke-handbook.pdf`. Every construct appears
in it at least once, and `make verify` builds it through both backends.

**Documents bundle.** `ranke-docs.tar.gz`, a new release asset at a stable URL:
the papers, the spec, the glossary and `shared/`, stamped with the commit they
came from, for a build that cannot clone. The fetcher packs it and the fetcher
clones, from one definition of what a document is, so the tarball and the clone
give the same tree.

**Smaller fetched copy.** Figure sources, working notes and built PDFs are no
longer copied into a consumer: no gate read them, and `02-ranke-db/drawio`
alone was 968 KB of the 976 KB a full copy carried. The set is now 120 KB.

**Shared fetcher.** `scripts/fetch-ranke-docs.sh` — the fetcher ranke-go carried
as `scripts/fetch-papers.sh`, moved here so four consumers run one script. It
keeps the stamp and `--if-moved`, gains a `--place` mode and a `DOCS_DIR` that
puts the vocabulary where a chapter's import resolves, and documents its
interface: `RANKE_GRAPH_REPO`, `RANKE_GRAPH_REF`, `PAPERS_DIR`, `DOCS_DIR`,
`SHARED_DIR`, `RANKE_DOCS_OFFLINE`.

## v0.20.3 — 2026-08-28

Generated new testdata using latest ranke-go v0.26.0

## v0.20.2 — 2026-08-28

Moved the website to it's own repo at github.com/rankegraph/ranke-website

## v0.20.1 — 2026-08-27

**Conformance vectors.** Regenerated from ranke-go v0.25.0-rc.1: a
`rejected-dated-form` case, so `V-DATED` has a case rather than sitting
uncovered.

**Website.** An early draft under `website/`: index, papers, build and use
pages.

## v0.20.0 — 2026-08-27

**Papers.** 01: archival practice dates an artifact twice, the day it entered
the archive and the time it is held to stem from (§Provenance). A node may
carry `dated`, and §Nodes now states which fields every node carries.

**Specification.** `V-DATED` added: an optional `dated` holding a valid EDTF
value at Level 1, outside `V-TIME` and unconstrained by `V-MONO`. Level 1
covers intervals, uncertainty, unspecified digits, and open bounds; Level 2's
sets and exponential years are not part of the language, so every
implementation accepts the same one. `R-QTEMPORAL` added: `compare: temporal`
orders by a span's midpoint in milliseconds, one value per claim that a layer
can store and sort on natively, with equal midpoints falling to `R-QSORT`'s
tie-break. `R-QSORT` gains `temporal`; @tbl:keys gains key 14.

**Schema.** `compare` accepts `temporal`.

## v0.19.1 — 2026-08-25

**Papers.** 01 §Primitives: the envelope is a triplet of scheme, signature and
serialized claim, stated as a verification relation rather than a construction.
`Sign` no longer needs to be self-describing, the scheme having a field of its
own.

**Specification.** `V-ENV` pins the envelope's headers: `alg` alone in the
protected header, the unprotected header empty. Anything further would give one
claim two ids across implementations.

## v0.19.0 — 2026-08-25

**Papers.** 01 §Universe and 02 §Universe: the Universe holds envelopes under
ids and content under hashes, one keyspace, where both said "serialized claims".

**Conformance vectors.** Regenerated from ranke-go v0.22.0 for the envelope, so
every id changes. New refusal cases for edge order, timestamp form, both content
slots at once, and a claim stored without an envelope.

## v0.18.3 — 2026-08-25

**Papers.** 01 §Universe: the Universe contains envelopes, not serialized claims.

## v0.18.2 — 2026-08-25

**Vocabulary.** "Serialized claim" replaces "claim record" throughout the
specification. The glossary gains `envelope` and `serialized claim`; its `id`
entry carried the retired `Sign(H(S(v)))`, and its `universe` entry claimed ids
and hashes never collide, which one keyspace makes moot.

**Convention.** Papers 01 and 02, the specification and CLAUDE.md now each state
that a term introduced, renamed or redefined is updated in the glossary in the
same change.

## v0.18.1 — 2026-08-25

**Specification.** `V-EORDER` added: a node's edges serialize ascending by
`id(e)`, an order nothing previously fixed although it is part of every claim
id. `detail: envelope` added, returning the stored bytes a client can hash
against an id; `R-QCANON` had promised that of `S(v)`, which the envelope made
false. `R-QDETAIL`, `R-QENCODING` and `R-QSTREAM` follow.

**Schema.** `detail` accepts `envelope`.

## v0.18.0 — 2026-08-25

A claim's id is now `H(S(env(v)))`, the hash of a stored envelope, where it was
`Sign(H(S(v)))`, a signature. Every id in every archive changes. Recomputing an
id now takes the bytes and a hash function alone, so any store can check what it
holds; establishing authorship is a second, separate step.

**Papers.** 01: the envelope enters §Primitives, §Verifiability separates
integrity from authenticity, and the identity signature is retired, so every
contributor carries a key. §Relations scopes reification to relations between
entities, which readers had taken to mean every edge. 06 Ranke Cryptography is
removed: its material is covered by 01, 02 and the specification.

**Specification.** `V-ENV` added. `V-ID`, `V-SIG`, `V-SIGN` and `V-SER` follow
the envelope; the identity signature option is retired.

**Build.** A quality gate runs `make verify` in a fresh checkout; `make help`
lists the targets.
