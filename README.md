# Ranke-Graph

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
| [ranke-go](https://github.com/flocko-motion/ranke-go) | the ADT in Go, and the tool that materialises this repository's conformance vectors |
| [ranke-ts](https://github.com/flocko-motion/ranke-ts) | the ADT in TypeScript |
| [ranke-db](https://github.com/flocko-motion/ranke-db) | the RankeDB server and the Ranke-Explorer frontend |

## Papers

| # | Paper | Status | PDF |
| --- | --- | --- | --- |
| 01 | Ranke-Graph: A Provenance-First Data Structure | draft | [download](https://github.com/flocko-motion/ranke-graph/releases/latest/download/01-ranke-graph.pdf) |
| 02 | RankeDB: Serving the Ranke-Graph | draft | [download](https://github.com/flocko-motion/ranke-graph/releases/latest/download/02-ranke-db.pdf) |
| 03 | Ranke Workers: Populating the Provenance Graph | placeholder | — |
| 04 | Ranke Retrieval: Strategies over a Provenance-First Graph | placeholder | — |
| 05 | Ranke Coordination: Orchestrating a Multi-Agent Knowledge System | placeholder | — |
| 06 | Ranke Cryptography: Attestation, Governance, and Audit | placeholder | — |

Paper 01 defines the abstract data type; paper 02 specifies the reference
database that serves it. Start with 01.

## Companion documents

- **[Normative specification](https://github.com/flocko-motion/ranke-graph/releases/latest/download/ranke-spec.pdf)**
  (`spec/`) — the rules an implementation follows, each with a stable id. An
  implementation, a schema, and a conformance suite are projections of this
  document.
- **[Glossary](https://github.com/flocko-motion/ranke-graph/releases/latest/download/ranke-glossary.pdf)**
  (`glossary/`) — the series' terminology in one place.
- **[RQL schema](https://github.com/flocko-motion/ranke-graph/releases/latest/download/rql.schema.json)**
  — the machine-readable form of the specification's query language.
- **Conformance vectors** (`01-ranke-graph/testdata/cbor/`) — claim
  serializations paired with the ids they are offered under, so an
  implementation can decide its own conformance. They belong to the
  specification: the reference archive in its annex is their source, and
  `ranke-go` materialises them from it. Also published as a
  [downloadable bundle](https://github.com/flocko-motion/ranke-graph/releases/latest/download/ranke-testdata.tar.gz)
  for implementations that would rather not clone this repository.

## Building

Sources are [Typst](https://typst.app). `make` builds every document into
`pdf/`; `make help` lists the targets.

```
make            # build every paper, the glossary, and the spec
```

## Licence

See [LICENSE](LICENSE).
