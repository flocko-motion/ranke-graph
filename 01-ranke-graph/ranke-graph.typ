#import "../shared/template.typ": *

#show: paper.with(
  title:    "Ranke-Graph: A Provenance-First Data Structure",
  author:   "Florian Metzger-Noel",
  date:     "2026-05-03",
  status:   "scaffold",
  abstract: todo[One paragraph: a small data structure from which a list of properties — provenance, immutability, verifiable history, auth-scoped visibility, distributability, open-ended vocabulary — emerges as consequence rather than as feature. To be written after the body settles.],
)

#part[Part I — Why Provenance]

= The Problem: Knowledge Without Provenance

== The Archival Tradition

The Ranke-Graph is named after Leopold von Ranke (1795–1886), the historian who transformed his discipline by insisting that every historical claim must trace back to a critically examined primary source.
Ranke's famous phrase — history _"wie es eigentlich gewesen"_, "as it actually was" — has since been rightly criticised for assuming unmediated access to past reality.
The Ranke-Graph takes that criticism as foundational: the primary data point is never _"how it was"_ but the artifact of a communicative act that reports, claims, or interprets it — an email, a chat message, a voicemail, a document.
What the Ranke-Graph stores is always someone's utterance about the world, never the world itself.
What survives from Ranke's method, intact, is the discipline of attribution: nothing is asserted without its derivation, and nothing is derived without its sources.

== The CS Priority That Was Never Operationalised

Existing systems that address this tension do so partially.
Temporal knowledge graphs (Graphiti/Zep, @rasmussen2025graphiti) preserve _when_ facts were valid but perform destructive entity-summary updates, losing derivation history.
Versioned knowledge bases (TerminusDB, @terminusdb) track _what_ changed across snapshots but not _why_ or _how_ knowledge was derived.
Immutable databases (Datomic, @hickey2012datomic; Fluree, @fluree) preserve all historical states but lack a semantic knowledge layer and do not model derivation chains.
No existing system treats the full chain of provenance — from raw source artifact through extraction, normalisation, and synthesis — as first-class, queryable knowledge.

== The Rupture: Machines Reading and Writing at Scale

Knowledge management systems face a fundamental tension: they must serve both _current_ truth and _historical_ understanding.
Traditional knowledge graphs optimise for the former — they store what is believed to be true now, updated in place as understanding changes.
This design made sense in an era of expensive storage and limited query capacity.
It makes less sense in a regime where the ability to present a model with the full derivation history of a belief — including contradictions, revisions, and competing interpretations — may support qualitatively better reasoning than presenting a single consolidated snapshot.

For a rich treatment of what _provenance_ has meant across 180 years — from the archival principle of _respect des fonds_ through the Semantic Web to the LLM era — we refer the reader to Talisman's essay (@talisman2026provenance).
In this paper we use the term in a narrower, operational sense: the complete derivation chain of a piece of knowledge — the raw source artifact, every intermediate processing step, every tool and configuration involved, and every transformation applied.
This is compatible with W3C PROV-DM's Entity/Activity/Agent vocabulary (@moreau2013provdm) but makes a stronger commitment: in the Ranke-Graph, provenance is not metadata about knowledge — it _is_ knowledge, stored in the same graph, queryable through the same API, subject to the same invariants.
Each node in the graph is both a statement and the record of how that statement came to be.
There is no separate "provenance layer" — the derivation chain is the knowledge, and the knowledge is the derivation chain.

== Convergence: A Foundation, Not a Feature

The Ranke-Graph addresses this gap through a structural inversion: the provenance DAG is the system, and everything else — including the semantic knowledge graph — is a view derived from it.
It is deliberately *under-prescribed* in how it should be used: the data model preserves every level of detail in parallel — from the raw source artifact up to the semantic triplet — networked by provenance, and leaves the strategy of retrieval and reasoning to the consumer.
The follow-up papers will be the first generation of application on that foundation; the present paper describes the data structure they will be built against.

== Provenance Is Not Consensus

#todo[Expand from the bullet sketch in #raw("notes.md") "Philosophical Grounding":]

- *Provenance* = attribution (who said what, when, on what basis). Solvable by construction.
- *Consensus* = social agreement on what to trust. A human process, not a database concern.
- The Ranke-Graph handles provenance. Consensus is downstream, built by consumers on top.

*Thesis.* The Ranke-Graph stores attributed claims; common truth is what consumers build on top when they want it.

== Bounded Scope

#todo[Expand from the bullet sketch in #raw("notes.md"):]

- At bounded scale (personal to small-enterprise), trust is pre-established, ontology is finite, adversarial resistance is simple.
- The Ranke-Graph does not aim for Wikipedia-scale global consensus.

= Desiderata <sec:desiderata>

We state the obligations the data structure of @sec:structure is required to satisfy. The list is intended to be minimal in the sense that no item is implied by the others under the structure to follow; consequences that #emph[do] follow — traceability, idempotency of writes, mergeability of independent replicas, verifiability of partial views — are deferred to Part III, where each is derived in turn.

The desiderata are stated without reference to any implementation, and without prejudice as to how a system might satisfy them. Each is discharged by an identified section in Part III; cross-references appear at the end of the corresponding section rather than here.

*D1. Provenance.* For every claim recorded in the store, there exists an explicit, queryable path from the claim to the artifacts on which it depends, through every intermediate derivation.

*D2. Immutability.* Once recorded, no claim is modified or deleted by any subsequent operation. Revisions and corrections are themselves new claims that reference what they revise.

*D3. Verifiable History.* The state of the store at any past point in time is provable to a third party without reliance on the operator. A claim about historical state is either confirmed or refuted by inspection of the store and a small external witness.

*D4. Auth-Scoped Visibility.* Visibility of a claim to an observer is determined structurally, not by policy: an observer sees a claim only if it sees every artifact and intermediate derivation on which the claim depends. Visibility propagates from inputs to outputs without explicit administration.

*D5. Distributability.* Independent replicas of the store may evolve concurrently and converge to a common state without coordination, and without conflict resolution beyond merging the recorded claims of each replica.

*D6. Open-Ended Vocabulary.* The structure does not enumerate, in advance, the kinds of claims it admits. Vocabulary may be extended without modification of the structure or migration of existing data.

The remainder of the paper presents a single data structure (@sec:structure) and shows that D1–D6 follow from it as theorems rather than as separately engineered features.

#part[Part II — The Structure]

= The Data Structure <sec:structure>

#todo[Opening paragraph: "Here is the data structure. In the remaining chapters we show how every property in §2 follows from it."]

== Nodes

#todo[Common node shape. `id`, `content`, `content_hash`, `content_type`, `encoding`, `created_at`. Identity from content for roots; synthesized from inputs otherwise. Draw from #raw("rankedb.md") §3.1 (Common Fields) for prose.]

== Edges

Every edge belongs to exactly one node: the node that created it (its parent).

```
edge = {
  parent:    hash_of_creating_node,
  target:    hash_of_target_node,
  type:      relation_type,
  direction: in | out
}
```

- *Input edge (in):* parent is the new node, target is an older node that contributed to the parent's creation. Provenance direction.
- *Output edge (out):* parent is the new node, target is an older node that the parent asserts something about. Semantic direction.

The direction flag is what separates the provenance subgraph (acyclic, Merkle-secured) from the semantic layer (potentially cyclic, expressive).
Both coexist in the same graph.
Both are immutable once created.
Both are hashed into the parent node's id.

== Atomic Node Creation

A node and all its edges are created in a single atomic transaction:

- $n$ input edges (provenance: sources and derivations)
- $m$ output edges (semantics: relations asserted)
- one content blob (the payload, stored separately, referenced by `content_hash`)
- one worker attribution

Nothing can be added to a node after creation.
No edge can be added later.
The node's hash covers everything it will ever have.
This is what makes the Merkle property hold: $h(v)$ is final at creation time.

== The Three Regions

#todo[$L_0 / L_1 / L_2$ as a partition of $V$, by content-type category. Levels classify content, not processing order. Lift from #raw("rankedb.md") §3, condensed.]

== Two Subgraphs

#todo[$G_p$ (provenance, all nodes + provenance edges) and $G_s$ (semantic, $L_2$ nodes + head/tail edges). $K G = G_p union G_s$. Every edge belongs to exactly one. Prose from #raw("rankedb.md") §3 opening.]

#todo[Closing: that's it. The rest of the paper shows what emerges.]

#part[Part III — What Emerges]

= Acyclicity of Provenance

Let $G = (V, E_"in" union E_"out")$ be the graph.
Every edge $e$ has a parent (the node that created it) and a target (the node it points to).
Edges are created atomically with their parent node.

Define the provenance subgraph $G_p = (V, E_"in")$.

#theorem[$G_p$ is acyclic.]

#proof[
  Every node $v$ has a creation time $t(v)$. Input edges can only target nodes that existed before $v$ was created: for every edge $(u, v) in E_"in"$ where $v$ is the parent, $t("target"(e)) < t(v)$. This establishes a strict partial order on $V$ by creation time. A strict partial order admits no cycles.
]

Output edges are not subject to this constraint — they can target any existing node, including "older" neighbours.
Therefore $G$ may contain cycles (through output edges), but $G_p$ cannot.

#corollary[
  The provenance subgraph $G_p$ is always a DAG, regardless of the semantic richness of output edges. Circular semantics (A knows B, B knows A) are modelled by two separate relation nodes, each with output edges, but the provenance subgraph (input edges only) remains acyclic.
]

#dref[D1, this section]

= Content Addressing and Merkle Integrity

== Hash Function

Every id in the system is a cryptographic hash $H$.
$H$ is treated as a parameter of the architecture rather than a fixed algorithm: the reference implementation specifies the concrete choice (e.g.\ SHA-256), but the structure permits a hash-type prefix on ids (`sha256:a3f2b7c…`), coexistence of different hash functions during migration, and a future migration path to post-quantum hash functions.

== Edge and Node Hashes

Edge hash:
$ h(e) = H("parent"(e) || "target"(e) || "type"(e) || "direction"(e)) $

Node hash:
$ h(v) = H("content_hash"(v) || "content_type"(v) || "encoding"(v) || h(e_1) || dots.h.c || h(e_n) || "created_at"(v) || "worker_id"(v)) $

where $e_1 dots.h.c e_n$ are all edges (input and output) created with $v$.

== Tampering Detectable at the Root

#theorem[Manipulation of any node $v'$ in the provenance subgraph of $v$ changes $h(v)$.]

#proof[
  By induction on the depth of the DAG.

  _Base case._ $v' = v$. Changing any field of $v$ changes $h(v)$ directly ($H$ is collision-resistant).

  _Inductive step._ $v'$ is an ancestor of $v$ in $G_p$. There exists a path $v' arrow.r dots.h.c arrow.r u arrow.r v$ in $G_p$ (following input edges). By the inductive hypothesis, manipulation of $v'$ changes $h(u)$. $h(u)$ is the target hash used in the computation of some input edge $e$ of $v$. Changing $h(u)$ changes $h(e)$. Changing $h(e)$ changes $h(v)$ (since $h(e)$ is part of $v$'s hash computation and $H$ is collision-resistant).
]

#corollary[
  Each node hash witnesses the integrity of its entire provenance subgraph. Tampering anywhere below is detectable at the root.
]

== Idempotency

#theorem[
  Identical content with identical provenance produces identical node hashes:
  $ forall v_1, v_2 : "fields"(v_1) = "fields"(v_2) arrow.r.double h(v_1) = h(v_2). $
]

Since node id $=$ node hash, identical nodes are the same node.
Writes are idempotent by construction.
Deduplication is free.

#dref[D2, this section]

= Snapshots and Hashchains

Snapshots are special nodes whose inputs are all current heads (nodes with no children in $G_p$) plus the previous snapshot:
$
  s_0 &= H("heads"(G_p, t_0)) \
  s_n &= H("heads"(G_p, t_n) || s_(n-1))
$

The snapshot sequence $(s_0, s_1, dots.h.c, s_n)$ is a hashchain.
Each snapshot witnesses the graph state _and_ all previous snapshots.
Manipulation of any $s_i$ invalidates all $s_j$ for $j > i$.

Snapshot hashes can be published to any external timestamping service — for instance, in the New York Times or on a public ledger, following the construction of Haber and Stornetta (1991) #todo[(add bib entry)] — to provide third-party proof of graph state at a given point in time.

#dref[D3, this section]

= Forking, Merging, and the CRDT Property

== Cheap Forks

#todo[Content-addressed storage means two graph instances can share a single content pool. Forks copy only the graph metadata, not the content. Lift from #raw("rankedb.md") §4.1.4 (Forking and backups), philosophical part only.]

== Coordination-Free Merge

#todo[An add-only monotonic DAG is provably a CRDT. Independent forks can be merged into a consistent state without coordination — formal sketch. Reference @shapiro2011crdt for the CRDT definition; argue that the Ranke-Graph satisfies the join-semilattice condition trivially because addition is the only operation and node ids are content-addressed (so merge is set union).]

#dref[D5, this section]

= Auth-Scoped Visibility and Verifiable Partial Views

Auth-scoped visibility (a node derived from a confidential source is automatically confidential) is compatible with the Merkle-DAG.

A user receives a verifiable subgraph: full nodes with content for everything in scope.
For branches outside their scope, they see only the hash — enough to verify the integrity of their own subgraph, but no content access.

```
[hash_only] ← confidential node, user sees only hash
     ↓
[full node] ← derived, user has access
     ↓
[full node] ← user has access
```

The user can verify: "my subgraph is intact, it builds on a node with hash $X$ whose content I don't know."
Integrity is provable without transparency.
Only the server sees everything.

Merkle structure is what _enables_ verifiable partial views.
Auth scoping and Merkle integrity are complementary.

== Visibility Propagation

#todo[Formalise: a node is visible iff all its inputs are visible. Visibility propagates through $G_p$ automatically. Compliance by structure, not by policy.]

== Compliance by Architecture

#todo[Brief paragraph: this is compliance by structure rather than by policy. Forward pointer to P2 (RankeDB) for the implementation in a real authentication system.]

#dref[D4, this section]

= Schema-Light, Open-Ended Knowledge

#todo[Content-type taxonomy as a minimal upper-ontology. Two-part identifier: `content_type = category/type`, `encoding = class/format`. Ranke-Graph-defined categories, application-extendable types. Few types, many encodings. Why this is enough.]

#todo[The full $L_0 / L_1 / L_2$ type tables likely live in P2 (#raw("rankedb.md") §3.1.1–§3.1.3); P1 references the partition principle without enumerating types.]

#dref[D6, this section]

#part[Part IV — Position in the Field]

= Relation to Prior Work

== Temporal Knowledge Graphs: Graphiti / Zep

Graphiti (@rasmussen2025graphiti; @zep2025temporal, 2024–2025) is the closest existing system to the Ranke-Graph in the LLM context-management space.
It builds temporal, provenance-aware knowledge graphs using FalkorDB or Neo4j, with bidirectional episode indices and temporal validity windows.
Facts are invalidated rather than deleted.

However, Graphiti performs destructive entity-summary updates, has no content-addressable source region comparable to the Ranke-Graph's $L_0$, and embeds provenance as annotation on the knowledge graph rather than treating it as the content itself.
The Ranke-Graph can be understood as an extension of Graphiti's philosophy — adding immutability, first-class sources, and the architectural inversion that makes provenance the substrate rather than an annotation.

== Versioned Knowledge Bases: TerminusDB

TerminusDB (@terminusdb) provides Git-like versioning (branch, merge, time-travel) over an RDF knowledge graph using append-only delta encoding.
It captures _what_ changed across versions but not _why_ — there is no derivation chain, no source archive, and no concept of workers as provenance-tracked processors.
Its foundational structure is a versioned graph, not a provenance DAG.

== Immutable Databases: Datomic and Fluree

Datomic (@hickey2012datomic) operationalises Pat Helland's "Immutability Changes Everything" thesis (@helland2015immutability) as an append-only database of immutable datoms.
Fluree (@fluree) combines an append-only ledger with a semantic graph database.
Both capture temporal history but not _epistemic_ history — they record _when_ facts changed but not _how knowledge was derived from sources through processing chains_.

== Merkle Structures and Content Addressing

#todo[Merkle trees, IPFS, Trusty URIs (@kuhn2014trustyuris). What we share, what we add — chiefly: provenance edges become Merkle links, so the Merkle property is not over a tree of content blobs but over a DAG of derivations.]

== W3C PROV-DM

The W3C PROV Data Model (@moreau2013provdm) provides a formal vocabulary for provenance (Entity, Activity, Agent, wasGeneratedBy, wasDerivedFrom, used).
The Ranke-Graph is semantically compatible with PROV-DM — nodes map to Entities, worker runs to Activities, tools to Agents — but does not depend on or implement the W3C stack (RDF, SPARQL, OWL).
PROV-DM compatibility exists at the conceptual level, enabling potential export or interoperability without architectural coupling.

== Nanopublications

Nanopublications (@kuhn2014trustyuris; @nanopubs2025knowledgeprov) are immutable, content-addressable scholarly assertions with embedded provenance.
They share the Ranke-Graph's commitment to immutability and provenance-per-assertion but are a flat collection of independent assertions — they do not form a derivation DAG connecting assertions through chains of processing, and they do not support a semantic graph layer.

== CRDTs and Distributed Provenance

#todo[An add-only monotonic DAG is provably a Conflict-Free Replicated Data Type (@shapiro2011crdt) — it can be replicated across distributed nodes and always merged into a consistent state without coordination. This connection between provenance DAGs and CRDTs appears unexplored in the literature; we develop it formally in §7 and as related work here.]

== The Identified Gap

No existing system combines all of: (a) a content-addressable immutable source archive, (b) an append-only Provenance DAG as the primary data structure, (c) a semantic knowledge graph as a materialised view with per-edge provenance, (d) verifiable partial views under structural auth-scoping, (e) CRDT-compatible merge of independent replicas, and (f) natural-language relations with emergent ontology.
Each component has mature prior art; the architectural composition is novel.

= Conclusion

#todo[A small structure, a long list of consequences. Forward pointers to P2 (the implementation), P3 (workers), P4 (retrieval), P5 (orchestration).]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
