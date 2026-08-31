<img src="website/assets/logo.png" alt="Ranke-Graph" width="560">

**Everything is Knowledge — Knowledge is Everything.**

A provenance-first foundation for knowledge systems. This repository holds the
paper series and the normative specification; the implementations live in their
own repositories, listed below.

The Ranke-Graph is a Merkle DAG of *claims*: each a node attributed to a named
author at a stated time, with edges citing the earlier claims it draws on. Where
a conventional database consolidates its sources into one current state, a
Ranke-Graph keeps every claim, contradictions intact, each independently
verifiable.

## Implementations

| Repository | What it holds |
| --- | --- |
| [ranke-go](https://github.com/rankegraph/ranke-go) | the ADT in Go, and the tool that materialises this repository's conformance vectors |
| [ranke-ts](https://github.com/flocko-motion/ranke-ts) | the ADT in TypeScript |
| [ranke-db](https://github.com/flocko-motion/ranke-db) | the RankeDB server and the Ranke-Explorer frontend |

## Papers


| # | Paper | State | PDF |
| --- | --- | --- | ---  |
| 01 | Ranke-Graph: A Provenance-First Data Structure | draft | [download](https://github.com/rankegraph/ranke-graph/releases/latest/download/01-ranke-graph.pdf) |
| 02 | RankeDB: Serving the Ranke-Graph | draft | [download](https://github.com/rankegraph/ranke-graph/releases/latest/download/02-ranke-db.pdf) |

There is three follow up papers sketched out. Thus directories `03` to `05` hold a title and some working notes each. 
They mark subjects the series might take up.

## Companion documents

- **[Normative specification](https://github.com/rankegraph/ranke-graph/releases/latest/download/ranke-spec.pdf)**
  (`spec/`) — the rules an implementation follows, each with a stable id. An
  implementation, a schema, and a conformance suite are projections of this
  document.
- **[Glossary](https://github.com/rankegraph/ranke-graph/releases/latest/download/ranke-glossary.pdf)**
  (`glossary/`) — the series' terminology in one place.
- **[RQL schema](https://github.com/rankegraph/ranke-graph/releases/latest/download/rql.schema.json)**
  — the machine-readable form of the specification's query language.
- **[Documentation format](https://github.com/rankegraph/ranke-graph/releases/latest/download/ranke-docs-format.pdf)**
  (`docs-format/`) — the rules a repository's `docs/` tree follows, each with a
  stable id, so one chapter file renders to both PDF and HTML.
- **[Foundation handbook](https://github.com/rankegraph/ranke-graph/releases/latest/download/ranke-handbook.pdf)**
  (`docs/`) — documentation for the foundation part, and the reference tree a
  part repository copies to start its own. Every construct the format offers is
  used in it at least once.
- **Conformance vectors** (`01-ranke-graph/testdata/cbor/`) — claim
  serializations paired with the ids they are offered under, so an
  implementation can decide its own conformance. They belong to the
  specification: the reference archive in its annex is their source, and
  `ranke-go` materialises them from it. Also published as a
  [downloadable bundle](https://github.com/rankegraph/ranke-graph/releases/latest/download/ranke-testdata.tar.gz)
  for implementations that would rather not clone this repository.
- **[Changelog](CHANGELOG.md)** — what each release changed in the rules, the
  papers, the vocabulary, and the vectors. A release cannot be cut without an
  entry naming it.

## Building

Sources are [Typst](https://typst.app). `make` builds every document into
`pdf/`; `make help` lists the targets.

```
make                # build every document
make handbook       # the docs/ tree, to PDF
make handbook-html  # the same chapters, to HTML through the stub backend
make verify         # the gate: every document compiles, both docs backends render
```

## For repositories that read these documents

`scripts/fetch-ranke-docs.sh` is the shared fetcher. It copies the papers, the
spec, the glossary, and the docs vocabulary into a consumer repository, stamps
the commit they came from, and with `--if-moved` re-fetches only when the ref
has moved. Download it rather than vendoring it, so every consumer runs the same
one; its header documents `RANKE_GRAPH_REF`, `PAPERS_DIR`, `DOCS_DIR`,
`SHARED_DIR`, and `RANKE_DOCS_OFFLINE`, and carries the Makefile recipe.

For a build that cannot clone, the same documents are published as
[`ranke-docs.tar.gz`](https://github.com/rankegraph/ranke-graph/releases/latest/download/ranke-docs.tar.gz)
— 120 KB, the papers, the spec, the glossary and `shared/`, stamped with the
commit they came from. It unpacks to the tree the fetcher would have written;
the fetcher packs it, so the two cannot drift. What the tarball lacks is the
cheap freshness question: `--if-moved` costs one 40-byte `git ls-remote`, while
a tarball's currency is a matter of which release you took.

## Licence

See [LICENSE](LICENSE).
