#import "../shared/template.typ": *

#show: paper.with(
  title:    "Ranke-Graph: A Provenance-First Data Structure",
  author:   "Florian Metzger-Noel",
  date:     "2026-05-03",
  status:   "scaffold",
  abstract: todo[One paragraph: a small data structure from which a list of properties — provenance, immutability, verifiable history, auth-scoped visibility, distributability, open-ended vocabulary — emerges as consequence rather than as feature.],
)

#part[Part I — Why Provenance]

= Historical and Philosophical Background

== Leopold von Ranke and the Discipline of Attribution

#todo[Ranke (1795–1886), "wie es eigentlich gewesen," and the criticism it received. What survives intact: the discipline of attribution — nothing asserted without derivation, nothing derived without sources. Lift in compressed form from P2 §1.1.]

== The Archival Tradition

#todo[Respect des fonds, the principle that records inherit meaning from their context of creation. 180 years of practice in libraries and archives that already understood what knowledge graphs forgot. Talisman (2026) as wider treatment.]

== Knowledge as Attributed Claim

#todo[The primary data point is never "how it was" but the artifact of a communicative act about it — an email, a chat, a voicemail, a document. RankeDB stores someone's utterance about the world, never the world itself.]

== Provenance Is Not Consensus

#todo[Provenance (who said what, on what basis) is solvable by construction. Consensus (what to trust) is a human process, not a database concern. We address the first; we leave the second to consumers.]

== Bounded Scope

#todo[Personal to small-enterprise. At this scale, trust is pre-established, ontology is finite, adversarial resistance is simple. Not Wikipedia-scale global truth.]

= Desiderata

We state the obligations the data structure of #ref(<sec:structure>) is required to satisfy. The list is intended to be minimal in the sense that no item is implied by the others under the structure to follow; consequences that #emph[do] follow — traceability, idempotency of writes, mergeability of independent replicas, verifiability of partial views — are deferred to Part III, where each is derived in turn.

The desiderata are stated without reference to any implementation, and without prejudice as to how a system might satisfy them. Each is discharged by an identified section in Part III; cross-references appear at the end of the corresponding section rather than here.

*D1. Provenance.* For every claim recorded in the store, there exists an explicit, queryable path from the claim to the artifacts on which it depends, through every intermediate derivation.

*D2. Immutability.* Once recorded, no claim is modified or deleted by any subsequent operation. Revisions and corrections are themselves new claims that reference what they revise.

*D3. Verifiable History.* The state of the store at any past point in time is provable to a third party without reliance on the operator. A claim about historical state is either confirmed or refuted by inspection of the store and a small external witness.

*D4. Auth-Scoped Visibility.* Visibility of a claim to an observer is determined structurally, not by policy: an observer sees a claim only if it sees every artifact and intermediate derivation on which the claim depends. Visibility propagates from inputs to outputs without explicit administration.

*D5. Distributability.* Independent replicas of the store may evolve concurrently and converge to a common state without coordination, and without conflict resolution beyond merging the recorded claims of each replica.

*D6. Open-Ended Vocabulary.* The structure does not enumerate, in advance, the kinds of claims it admits. Vocabulary may be extended without modification of the structure or migration of existing data.

The remainder of the paper presents a single data structure (#ref(<sec:structure>)) and shows that D1–D6 follow from it as theorems rather than as separately engineered features.

#part[Part II — The Structure]

= The Data Structure <sec:structure>

#todo[Opening: "Here is the data structure. In the remaining chapters we show how every property in §2 follows from it."]

== Nodes

#todo[Common node shape. `id`, `content`, `content_hash`, `content_type`, `encoding`, `created_at`. Identity from content for roots; synthesized from inputs otherwise.]

== Edges

#todo[Edge as a tuple — parent, target, type, direction (or named type, TBD). Every edge belongs to exactly one node (its parent). No standalone edges.]

== Atomic Node Creation

#todo[A node and all its edges are created in a single transaction. Nothing can be added to a node after creation. This is the central invariant — every emergent property in Part III depends on it.]

== The Three Regions

#todo[L0 / L1 / L2 as a partition of V, by content-type category. Levels classify content, not processing order.]

== Two Subgraphs

#todo[$G_p$ (provenance, all nodes + provenance edges) and $G_s$ (semantic, L2 nodes + head/tail edges). $K G = G_p union G_s$. Every edge belongs to exactly one.]

#todo[Closing: that's it. The rest of the paper shows what emerges.]

#part[Part III — What Emerges]

= Acyclicity of Provenance

== Acyclicity Theorem

#todo[Time-order proof from notes.md §1. To be promoted to a #raw("#theorem") + #raw("#proof") block once written.]

== Circular Semantics, Acyclic Provenance

#todo[The semantic subgraph may cycle freely (A knows B, B knows A). The provenance subgraph cannot. Both coexist in the same structure.]

#dref[D1, this section]

= Content Addressing and Merkle Integrity

== Hash Function

#todo[H is any cryptographic hash function. Hash-type prefix on IDs. Algorithm-agnostic, migration-friendly.]

== Edge and Node Hashes

#todo[h(e) and h(v) definitions from notes.md §2.]

== Tampering Detectable at the Root

#todo[Inductive proof from notes.md §2.]

== Idempotency

#todo[Identical content with identical provenance produces identical node hashes. Proof from notes.md §3.]

#dref[D2, this section]

= Snapshots and Hashchains

== Snapshots

#todo[Snapshot as a special node whose inputs are all current heads plus the previous snapshot.]

== The Hashchain Property

#todo[Manipulation of any $s_i$ invalidates all $s_j$ for $j > i$.]

== External Anchoring

#todo[Snapshot hashes published to any external timestamping service give third-party proof of state at a point in time. Reference Haber and Stornetta (1991).]

#dref[D3, this section]

= Forking, Merging, and the CRDT Property

== Cheap Forks

#todo[Content-addressed storage means two graph instances can share a single content pool. Forks copy only the graph metadata, not the content.]

== Coordination-Free Merge

#todo[An add-only monotonic DAG is provably a CRDT. Independent forks can be merged into a consistent state without coordination — formal sketch.]

#dref[D5, this section]

= Auth-Scoped Visibility and Verifiable Partial Views

== Visibility Propagation

#todo[A node is visible iff all its inputs are visible. Visibility propagates through $G_p$ automatically.]

== The Verifiable Subgraph

#todo[A user receives full nodes for what they can see, hash-only stubs for the rest. Integrity is provable without transparency.]

== Compliance by Architecture

#todo[Compliance by structure, not by policy. Forward pointer to P2 for the implementation.]

#dref[D4, this section]

= Schema-Light, Open-Ended Knowledge

#todo[Content-type taxonomy as a minimal upper-ontology. Few types, many encodings. Application-extensible. Why this is enough.]

#todo[TBD whether the full L0/L1/L2 type tables live here or in P2.]

#dref[D6, this section]

#part[Part IV — Position in the Field]

= Relation to Prior Work

== Merkle Structures and Content Addressing

#todo[Merkle trees, IPFS, Trusty URIs (Kuhn 2014). What we share, what we add.]

== Immutable Databases

#todo[Datomic (Hickey 2012), Fluree, Helland (2015). Time vs. derivation.]

== Versioned Knowledge Bases

#todo[TerminusDB. What changed vs. why and how.]

== Temporal Knowledge Graphs

#todo[Graphiti / Zep (Rasmussen 2025). Closest in intent, different in commitment.]

== Nanopublications

#todo[Kuhn and Dumontier (2014). Flat vs. DAG.]

== W3C PROV-DM

#todo[Conceptual compatibility, no architectural coupling.]

== CRDTs and Distributed Provenance

#todo[The DAG-as-CRDT connection appears unexplored in the literature.]

== The Identified Gap

#todo[No existing system combines all of: content-addressable immutable source archive, append-only provenance DAG as primary structure, verifiable partial views, CRDT-compatible merge, schema-light semantic layer with emergent ontology. Each component has prior art; the composition is novel.]

= Conclusion

#todo[A small structure, a long list of consequences. Forward pointers to P2 (the implementation), P3 (workers), P4 (retrieval), P5 (orchestration).]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
