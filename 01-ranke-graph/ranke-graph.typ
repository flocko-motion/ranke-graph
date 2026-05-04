#import "../shared/template.typ": *
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge

#show: paper.with(
  title:    "Ranke-Graph: A Provenance-First Data Structure",
  author:   "Florian Metzger-Noel",
  date:     "2026-05-03",
  status:   "scaffold",
  abstract: todo[One paragraph: a small data structure from which a list of properties — provenance, immutability, verifiable history, auth-scoped visibility, distributability, open-ended vocabulary — emerges as consequence rather than as feature. Close with: reference implementations in Go and Python accompany the paper, with a binary conformance suite. To be written after the body settles.],
)

= Introduction

Consider three statements:

#block(inset: (left: 1.5em, right: 1.5em))[
  _Alice likes apples._

  _Alice wrote Bob an email saying she likes apples._

  _A file exists, attributed to Alice by its headers, that appears to be a copy of an email to Bob in which Alice claims to like apples._
]

The first is a claim about the world. The second adds an attribution. The third is an observation of existence — a file is present, with the stated bytes, metadata, and content.

Storing at the first layer is the classic goal of database design.
Schemas, integrity constraints, and transactions are built to maintain a consistent model of the world; the caller is expected to have applied sound epistemology before writing data.
When facts change, or sources disagree, the database is edited to align; its earlier states, and the disagreement itself, are discarded.
In database discipline this is called _destructive consolidation_ or _last-write-wins_; it is usually filed under _data cleaning_, and treated as consistency rather than loss. The cleaned value is an artifact of the algorithm, not a fact about the world; the ambiguity it discarded was itself information.

This is the ordinary condition of the enterprise data store, and works so long as the caller supplies correct facts.

The Ranke-Graph is designed for the opposite stance.
It stores only at the third layer.
Every node is an observation-of-existence: this artifact, with these bytes, this attribution, added to the graph at this moment.
The graph does not record whether Alice likes apples, or whether she wrote the email.
It records that a file is present, its metadata is as given, and the record has not been altered since it was written.
The guarantee is narrower than a conventional database's, and therefore keepable.

We call what the graph stores an _attributed claim_.
A claim, in this paper, is not a proposition asserted as true; it is a preserved, attributed record of the form _"contributor X produced this content at time T, derived from these inputs."_
The claim and its attribution are stored as a single unit.
Neither is verified nor refuted by the data type itself; both are preserved as received, immutable once written, traceable to every input that contributed to them.
Derivations — extracts, summaries, conclusions — are constructed on top of the graph by its contributors, with their own stake and context.

The Ranke-Graph is not a pure graph-theoretic construction; it is a structure shaped by a purpose.
Without that purpose — preserving attributed claims without climbing the epistemic ladder — the features that follow would be arbitrary.

This paper defines the Ranke-Graph as an abstract data type (ADT) — the minimum contract an implementation must satisfy.

= The Problem and the Position

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
This is compatible with W3C PROV-DM's Entity/Activity/Agent vocabulary (@moreau2013provdm) but makes a stronger commitment: in the Ranke-Graph, provenance is not metadata about knowledge — it _is_ knowledge, stored in the same graph, queryable through the same interface, subject to the same invariants.
Each node in the graph is both a statement and the record of how that statement came to be.
There is no separate "provenance layer" — the derivation chain is the knowledge, and the knowledge is the derivation chain.

== Convergence: A Foundation, Not a Feature

The Ranke-Graph addresses this gap through a structural inversion: the provenance DAG is the system, and everything else — including the semantic knowledge graph — is a view derived from it.
It is deliberately *under-prescribed* in how it should be used: the data model preserves every level of detail in parallel — from the raw source artifact up to the semantic triplet — networked by provenance, and leaves the strategy of retrieval and reasoning to the consumer.

== Everything Is Knowledge

The Ranke-Graph makes no distinction between data, metadata, and provenance.
Every claim made _about_ the graph is itself a node in the graph, with its own provenance:

- a classification ("this node belongs to the finance domain"),
- a summary ("this is a condensed version of the conversation at node X"),
- an alias ("this node refers to the same person as node Y"),
- a creation record ("this node was added by contributor X with configuration Y").

This principle — _everything is knowledge_ — eliminates the need for separate metadata systems, tagging taxonomies, or logs of contributor activity as additional infrastructure: all of these are expressible as nodes in the graph, derived from the same sources, subject to the same provenance and immutability guarantees, and queryable through a single interface.

From this ontological flatness follows a structural claim.
If every claim is a node with provenance, then what is the _primary_ content of the system?
In conventional knowledge graphs, claims are primary and provenance is an annotation layer bolted on top — an afterthought that explains where things came from.
No such split exists in the Ranke-Graph.

*Provenance is not an annotation on the knowledge — it _is_ the knowledge.*
Every derivation, every thought, every projected fact is itself a node in the graph, linked to the inputs it was derived from.
There is no "real" layer above and a "provenance" layer below; it is one graph, and the knowledge and its derivation are stored together.

This inversion has concrete operational consequences: operations that would require complex graph surgery in a conventional system become simple view operations in the Ranke-Graph.
Reprocessing sources with better tools produces new nodes alongside old ones — no migration required.
Filtering out results from an obsolete contributor is a query parameter, not a data operation.
Evaluating competing interpretations of the same source is a traversal, not a diff between snapshots.

== Immutability and Accumulation

The Ranke-Graph is strictly append-only.
No node or edge is ever modified or deleted through runtime operations.
When new information contradicts existing knowledge, the contradiction is represented as a new node — not as an update to the old one.
Both coexist in the graph, each with full provenance.

*Contradiction is not a bug to resolve; it is a fact about the evidence base.
Resolving it destroys information: the consolidated graph holds strictly less knowledge than the contradictory one it replaced.*

This design is a deliberate bet on the trajectory of language model context windows.
Systems that destructively consolidate today — merging entity summaries, deduplicating facts, compacting histories — optimise for current retrieval efficiency at the cost of inferential depth.
The Ranke-Graph is built for a future in which a model able to traverse the full derivation history of a belief as needed — contradictions, revisions, and competing interpretations — may produce better reasoning than one given only a consolidated summary.

== Provenance Is Not Consensus

#todo[Expand from the bullet sketch in #raw("notes.md") "Philosophical Grounding":]

- *Provenance* = attribution (who said what, when, on what basis). Solvable by construction.
- *Consensus* = social agreement on what to trust. A human process, not a database concern.
- The Ranke-Graph handles provenance. Consensus is downstream, built by contributors on top.

== Bounded Scope

#todo[Expand from the bullet sketch in #raw("notes.md"):]

- At bounded scale (personal to small-enterprise), trust is pre-established, ontology is finite, adversarial resistance is simple.
- The Ranke-Graph does not aim for Wikipedia-scale global consensus.

== Thesis

*The Ranke-Graph stores attributed claims; common truth is what contributors build on top when they want it.*

= Desiderata <sec:desiderata>

We state the obligations the data structure of @sec:structure is required to satisfy. The list is intended to be minimal in the sense that no item is implied by the others under the structure to follow; consequences that #emph[do] follow — traceability, idempotency of writes, mergeability of independent replicas, verifiability of partial views — are deferred to @sec:emerges, where each is derived in turn.

The desiderata are stated without reference to any implementation, and without prejudice as to how a system might satisfy them. Each is discharged by an identified section in @sec:emerges; cross-references appear at the end of the corresponding section rather than here.

*D1. Provenance.* For every claim recorded in the store, there exists an explicit, queryable path from the claim to the artifacts on which it depends, through every intermediate derivation.

*D2. Semantic Relations.* Claims of the form _"these participants stand in this relation"_ are recorded as single attributable units. The structure supports binary, $n$-ary, symmetric, and fuzzy-participation cases without requiring a separate construct for each.

*D3. Immutability.* Once recorded, no claim is modified or deleted by any subsequent operation. Revisions and corrections are themselves new claims that reference what they revise.

*D4. Verifiable History.* The state of the store at any past point in time is provable to a third party without reliance on the operator.

*D5. Auth-Scoped Visibility.* Visibility of a claim to an observer is determined structurally, not by policy: an observer sees a claim only if it sees every artifact and intermediate derivation on which the claim depends. Visibility propagates from inputs to outputs without explicit administration.

*D6. Distributability.* Independent replicas of the store may evolve concurrently and converge to a common state without coordination, and without conflict resolution beyond merging the recorded claims of each replica.

*D7. Open-Ended Vocabulary.* The structure does not enumerate, in advance, the kinds of claims it admits. Vocabulary may be extended without modification of the structure or migration of existing data.

The remainder of the paper presents a single data structure (@sec:structure) and shows that D1–D7 follow from it as theorems rather than as separately engineered features.

= The Data Structure <sec:structure>

The Ranke-Graph is a Merkle DAG (Directed Acyclic Graph) and a semantic graph, with a single node type (@sec:nodes) and a single edge type (@sec:edges) — acyclic by the atomic creation rule (@sec:atomic), Merkle by content-addressed hashing, semantic by the direction tag on edges (@sec:semantic-direction). From this definition, properties D1–D7 follow (@sec:emerges).

Two general primitives are used throughout: a canonical serialization $S$ mapping any record (node or edge) to bytes, and a cryptographic hash $H$ applied to those bytes. $S$ must be deterministic (same record → same bytes), complete (every field contributes), and self-delimiting (parsing recovers the record exactly); $H$ must be collision-resistant and self-describing (the id names the hash function used). Any satisfying choice is acceptable — CBOR Deterministic (RFC 8949 §4.2) for $S$ and IPFS multihash for $H$ are well-known examples, adopted by the reference implementations. Identity is the composition: $op("id")(v) = H(S(v))$ for nodes, $op("id")(e) = H(S(e))$ for edges.

== Nodes <sec:nodes>

```
node = {
  type:           string,
  content:        bytes,
  created_at:     timestamp,
  contributor_id: identity of the contributor,
  edges:          set of edge ids created with the node,
  ...:            additional implementation-defined fields
}
```

Identity:

$ op("id")(v) := H(S(v)) $

where $S$ is the canonical serialization (@sec:structure) and $H$ the cryptographic hash. Two nodes with identical content but different provenance — different edges, different contributor, or different extension fields — produce different ids.

- `type` is a plain string; the ADT prescribes no vocabulary.
- `content` is opaque bytes; interpretation is unspecified.
- `contributor_id` is itself a node id.
- Extension fields participate in $S$ like any other field, so proofs about node identity (@sec:merkle and onward) apply uniformly to refinements that add named fields (e.g. a `content_hash` or `encoding` in a reference implementation).

== Edges <sec:edges>

An edge belongs to one node — its _parent_ — recoverable as the node whose `edges` set contains the edge's id.

```
edge = {
  target:      hash_of_target_node,
  class:       provenance | semantic,
  type:        kind of relation (e.g. "family", "ownership", "derivation"),
  content:     the relation itself (e.g. "is_brother_of", "are_similar"),
  ...:         additional implementation-defined fields
}
```

Identity:

$ op("id")(e) := H(S(e)) $

Parent is implicit by necessity: if it were a field, $S(e)$ would depend on $S(v)$, which depends on $S(e)$ through the node's `edges` set — no consistent identity would exist.

*Structural direction is universal.* Every edge runs from an older node (its `target`) to the newer node that owns it (its parent), since the atomic creation rule (@sec:atomic) only allows references to already-existing nodes. This is the forward-in-time direction used in build graphs, dependency graphs, and pipelines. Acyclicity (@sec:acyclicity) follows directly.

As for nodes, `type` classifies the relation's kind; `content` carries the specific assertion.

- *Provenance edge (`class = provenance`):* the parent node was derived from the target. Every node created in the graph carries multiple provenance edges — at minimum, one to its contributor and one or more to the data inputs from which it was derived. The act of referencing a target by hash _is_ the provenance record; no further field is required.
- *Semantic edge (`class = semantic`):* the parent is a _relation node_; the target is one of the relation's participants. The relation's reading — including how each participant's role is recorded — is the subject of @sec:semantic-direction.
- `fields_0..n` is a placeholder for any number of additional fields the edge can carry. As for nodes, the placeholder keeps the basic definition fixed and ensures every proof about edge identity applies uniformly to all fields, named or not.

A node carries its edges' ids in its own record, so edges are Merkle-secured through the parent (@sec:merkle).

The `class` field is a *projection hint*, not a partition of "edges that carry provenance vs edges that do not" — every edge carries provenance by virtue of referencing an older node (@sec:acyclicity). What `class = semantic` marks is *inclusion in the semantic view*; `class = provenance` marks edges whose role is purely to record where the new node came from. The naming is somewhat loose and may be revisited. #todo[Consider renaming `class` once the rest of Part II is settled — perhaps `role` or `view`.]

== Atomic Node Creation <sec:atomic>

A node and all its edges are created in a single atomic transaction:

- $n$ provenance-class edges (derivation from sources and prior derivations),
- $m$ semantic-class edges (relations asserted),
- one content payload,
- one contributor attribution.

Nothing can be added to a node after creation.
No edge can be added later.
The node's hash covers everything it will ever have.
This is what makes the Merkle property hold: $op("id")(v)$ is final at creation time.

== Hashing <sec:hash-agnosticism>

This paper uses $H(x)$ to denote a cryptographic hash function, without committing to a specific algorithm.
What the ADT requires is that the chosen mechanism — both the byte-level encoding of records and the hash function applied to those bytes — satisfies the qualities below.

*Canonical encoding.* The hash function operates over a byte encoding of each record (node or edge). The encoding must be:

- *Deterministic.* The same logical record produces the same bytes across implementations, runs, and platforms.
- *Complete.* Every field of the record contributes to the bytes; no field may be silently dropped.
- *Self-delimiting.* Parsing the bytes recovers the record exactly, with no ambiguity about field boundaries.

Without these qualities, two implementations of the ADT would produce different ids for the same logical record, and the cross-implementation guarantees of @sec:crdt would not hold.
Any encoding satisfying these qualities is acceptable; CBOR Deterministic Encoding (RFC 8949 §4.2) is one well-known example, and the reference implementations adopt it.

*Hash-id mechanism.* Every id in the system is the cryptographic hash of a canonically-encoded record, formatted so that:

- *Cryptographic strength.* The hash function is collision-resistant under standard cryptographic assumptions.
- *Self-describing.* The id carries an explicit indication of which hash function produced it, so any reader can verify a node by recomputing its hash with the named function.

These two qualities are required.
Two further capabilities follow from self-describing ids and are nice-to-have rather than mandatory:

- _Function pluralism._ Multiple hash functions may coexist within a single graph, with each node verifiable by the function its id names.
- _Migration support._ New hash functions can be introduced over time without rewriting old nodes or invalidating their ids.

Any mechanism satisfying the required qualities is acceptable; IPFS multihash, which prefixes each id with a function selector and supports the listed nice-to-have capabilities by design, is one well-known example. The reference implementations adopt multihash.

Reference: Haber and Stornetta (1991), _"How to Time-Stamp a Digital Document"_ #todo[(add bib entry)] — the foundational paper on cryptographic timestamping. They demonstrated the concept by publishing hash digests in the New York Times.

== Semantic Direction <sec:semantic-direction>

The structure so far is a Merkle DAG, but not yet a knowledge graph: it cannot express a claim like _"Bob is_brother_of Alice"_ as one attributable unit. Discharging D2 requires one addition.

The addition has two parts:

+ *Relations are reified as nodes.* (Reification — see RDF 1.0 `rdf:Statement` (W3C, 1999) #todo[(add RDF 1.0 to sources.bib)] — is a known technique.) A semantic relation is not a single edge but a _relation node_ with semantic edges (`class = semantic`) to its participants. The relation's type lives on the relation node; participants are the edges' targets.

+ *The `semantic_direction` field tags each participant's role in the reading.* Carried on each semantic edge, with values
  $ "semantic_direction" in {"from" = +1, "peer" = 0, "to" = -1}. $
  The symbolic names map to slots in the natural-language reading; the numeric backing supports aggregation at scale.

To read a relation, gather the relation node and all its semantic edges, forming the generalised triple
$ ("from_nodes", "relationship", "to_nodes"), $
where `from`-tagged edges contribute `from_nodes`, `to`-tagged edges contribute `to_nodes`, and the relation node supplies the relationship. `peer`-tagged edges express symmetric participation, with no asymmetric role to record. @fig:relation illustrates the binary case under entity-resolution ambiguity.

#figure(
  pad(x: -2.5cm, align(center, diagram(
    spacing: (4em, 1.2em),
    node-stroke: 0.5pt,
    node-shape: rect,

    // Left column: all referenced (older) nodes.
    // Provenance sources at top.
    node((0, 0), [Contributor]),
    node((0, 1), [Source]),

    // Visual gap, then participants below.
    node((0, 3), [Bob 1]),
    node((0, 4), [Bob 2]),
    node((0, 5), [Alice]),

    // Right: the relation node (newer; references everything on the left).
    // Bolder stroke distinguishes it visually; the relation type sits in its label.
    node((5, 2.5), [`is_brother_of`], stroke: 0.8pt + black),

    // Edges from Contributor and Source carry no extra fields — the
    // existence of the reference IS the provenance fact (@sec:edges / @sec:acyclicity).
    edge((0, 0), (5, 2.5), "->"),
    edge((0, 1), (5, 2.5), "->"),

    // Semantic: all flow into the relation node (universal convention, @sec:edges).
    // Labels: sdir = semantic_direction, conv = conviction.
    edge((0, 3), (5, 2.5), "->", [#text(size: 0.75em)[`sdir: from`, `conv: +0.7`]]),
    edge((0, 4), (5, 2.5), "->", [#text(size: 0.75em)[`sdir: from`, `conv: −0.4`]]),
    edge((0, 5), (5, 2.5), "->", [#text(size: 0.75em)[`sdir: to`, `conv: +1.0`]]),
  ))),
  caption: [Binary relation under entity-resolution ambiguity. The plaintext claim "Bob is Alice's brother" reads `(Bob, is_brother_of, Alice)`: Bob on the from-side, Alice on the to-side. Entity resolution found two candidate Bobs; both link to the same `is_brother_of` relation node with `sdir = from`, each carrying its own conviction in $[-1, +1]$. Alice is unambiguous, `sdir = to`, conviction $+1.0$. All edges — provenance and semantic alike — flow left-to-right into the newer (relation) node, the universal structural convention from @sec:edges. Label abbreviations: `sdir` = `semantic_direction`, `conv` = `conviction`.],
) <fig:relation>

The same pattern scales to $n$-ary relations without changing the edge schema: more participants, more semantic edges, each with its own role tag.

The `peer` value is more than a binary edge case. Consider a relation node of type `are_similar` with $n$ semantic edges, all tagged `semantic_direction = peer`, each carrying its own conviction.
Such a node represents a *similarity cluster*: a set of participants asserted to be similar, with no central or distinguished member, and per-member evidence about how strongly each belongs.
The cluster is one assertion with provenance — its relation node has provenance edges to the source(s) it was derived from — and it scales without restriction in $n$.
Consumers can filter members by conviction, sort by it, weight by it; the underlying structure is unchanged from the binary case.

Beyond `semantic_direction`, edges can carry per-edge information through `fields_0..n` (@sec:edges).
_Conviction_ is a useful application-layer field worth highlighting as an example: a real value in $[-1, +1]$, with the endpoints recording full positive and full negative conviction, and $0$ recording absence of evidence in either direction.
The two-sided scale matters — it separates _we don't know_ (conviction $approx 0$) from _we know it isn't_ (conviction $< 0$), the distinction the multi-edged relation construct depends on for expressing real ambiguity.
Conviction lives on the edge, not on the node, because the uncertainty is about which participant fills which role in _this_ relation; the candidate nodes themselves are perfectly identified.
The ADT does not define `conviction`; the example shows what kinds of expressivity the extension mechanism affords.

A consequence of reifying relations as nodes: provenance edges target only nodes, never edges (@sec:edges).
This is what allows relations to *have* provenance at all — there is no provenance-of-an-edge in this ADT, only provenance-of-a-relation-node.
$N : N$ relations are therefore natural by construction, and every relation in the graph inherits the same provenance machinery as every other node.

#dref[D2, this section]

= What Emerges <sec:emerges>

== Acyclicity <sec:acyclicity>

Let $G = (V, E)$ be the graph. Every edge $e in E$ has a target ($op("target")(e)$, the node it points at) and an implicit parent (the node whose `edges` set contains $op("id")(e)$). Edges are created atomically with their parent node (§5.3).

#theorem[$G$ is acyclic.]

#proof[
  Every node $v$ has a creation time $t(v)$. By the atomic creation rule, an edge $e$ owned by $v$ may only target a node that already exists: for every edge $e$ with parent $v$, $t(op("target")(e)) < t(v)$. This establishes a strict partial order on $V$ by creation time. A strict partial order admits no cycles.
]

The proof makes no use of the `class` field: every edge of every class points to an node older than its parent, by the same atomic-creation rule. The whole graph $G$ — provenance edges, semantic edges, and any future class — is a DAG.

#corollary[
  Cycles in semantic interpretation (A knows B, B knows A) appear only in the *semantic projection* of $G$, where two relation-node patterns may be collapsed into a cycle of direct labelled edges between participants. The underlying graph $G$ remains a DAG.
]

#dref[D1, this section]

== Content Addressing and Merkle Integrity <sec:merkle>

Every id in the system is a cryptographic hash $H$ (@sec:hash-agnosticism).

Edge hash:
$ op("id")(e) = H(op("target")(e) || op("class")(e) \
  || op("type")(e) || op("content")(e) \
  || op("fields")_0 (e) || dots.h.c || op("fields")_n (e)) $

Node hash:
$ op("id")(v) = H(op("type")(v) || op("content")(v) \
  || op("id")(e_1) || dots.h.c || op("id")(e_n) \
  || op("created_at")(v) || op("contributor_id")(v) \
  || op("fields")_0 (v) || dots.h.c || op("fields")_n (v)) $

where $e_1, dots.h.c, e_n$ are all edges (provenance- and semantic-class) created with $v$, and $op("fields")_0, dots.h.c, op("fields")_n$ are the extension fields added by any implementation that refines the ADT.

=== Tampering Detectable at the Root

#theorem[Manipulation of any node $v'$ in the ancestry of $v$ changes $op("id")(v)$.]

#proof[
  By induction on the depth of the DAG.

  _Base case._ $v' = v$. Changing any field of $v$ changes $op("id")(v)$ directly ($H$ is collision-resistant).

  _Inductive step._ $v'$ is an ancestor of $v$ in $G$. There exists a path $v' arrow.r dots.h.c arrow.r u arrow.r v$ in $G$ (following edges from $v$ back through its references). By the inductive hypothesis, manipulation of $v'$ changes $op("id")(u)$. $op("id")(u)$ is the target hash used in the computation of some edge $e$ of $v$. Changing $op("id")(u)$ changes $op("id")(e)$. Changing $op("id")(e)$ changes $op("id")(v)$ (since $op("id")(e)$ is part of $v$'s hash computation and $H$ is collision-resistant).
]

#corollary[
  Each node hash witnesses the integrity of every node it transitively depends on. Tampering anywhere in the ancestry is detectable at the root.
]

=== Idempotency

#theorem[
  Identical content with identical provenance produces identical node hashes:
  $ forall v_1, v_2 : op("fields")(v_1) = op("fields")(v_2) arrow.r.double op("id")(v_1) = op("id")(v_2). $
]

Since node id $=$ node hash, identical nodes are the same node.
Writes are idempotent by construction.
Deduplication is free.

#todo[Add a "Backup from a Hash Root" sub-property: a single root hash plus access to the content store reconstitutes the entire graph and proves its integrity. State as a corollary of Merkle integrity. Lands right after Idempotency while the structure is fresh.]

#dref[D3, this section]

== Anchoring

Snapshots are special nodes whose inputs are all current heads (nodes with no children in $G$) plus the previous snapshot:
$
  s_0 &= H(op("heads")(G, t_0)) \
  s_n &= H(op("heads")(G, t_n) || s_(n-1))
$

The snapshot sequence $(s_0, s_1, dots.h.c, s_n)$ is a hashchain.
Each snapshot witnesses the graph state _and_ all previous snapshots.
Manipulation of any $s_i$ invalidates all $s_j$ for $j > i$.

Snapshot hashes can be published to any external timestamping service — for instance, in the New York Times or on a public ledger, following the construction of Haber and Stornetta (1991) — to provide third-party proof of graph state at a given point in time.

#todo[Add the *anchoring composition theorem*: publishing a single snapshot hash to a tamper-evident external medium (Bitcoin transaction, NYT classifieds, Sigsum log, etc.) anchors not only that snapshot but the integrity of every node in $G$ at $t_n$, by composition with Merkle integrity (§5.2). Verifiable by any third party in $O("path length")$ Merkle proofs, without trust in the operator. One ~32-byte hash anchors the whole graph state.]

#todo[One-line *compliance angle*: this is a regulatory-grade tamper-resistance guarantee — the kind that medical, financial-audit, and legal-evidence systems spend significant money to approximate (write-once optical, notary services). Falls out structurally here. Do not over-explain; one sentence.]

#dref[D4, this section]

== Boolean Composability <sec:crdt>

#todo[Section opener (1–2 sentences): the graph admits a full set algebra over its node-id sets — $union$, $inter$, $\\$, $triangle.stroked.small$ — all conflict-free by construction.]

=== Set Algebra Theorem

#todo[Theorem: for any two Ranke-Graph instances $A$, $B$, the operations $A union B$, $A inter B$, $A \\ B$, $A triangle.stroked.small B$ over their node-id sets each yield a well-formed Ranke-Graph instance in $O(|V_A| + |V_B|)$ time, with no possibility of conflict.

Proof sketch composes three structural facts:
(1) content-addressed ids (§4.4) make node identity decidable by hash equality (O(1));
(2) immutability (D3, §4.3) means a given id corresponds to one fixed record — no version disagreement is possible;
(3) DAG-by-construction (§5.1) means any subset of $V$ closed under the edge-target relation is itself a DAG; closure costs O(|E|).

Each set op produces a node-id subset; closing under target-references yields a well-formed instance.]

=== Cheap Forks

#todo[Corollary: forking is divergence in the node-id set; content blobs are shared via the addressed pool. Storage cost of $N$ forks of a graph $G$ is $O(|V_G|)$ in metadata plus $O(1)$ in the content pool.]

=== Coordination-Free Merge

#todo[Corollary: convergence is $union$. The Ranke-Graph satisfies the join-semilattice condition for CRDTs (@shapiro2011crdt). No coordination protocol, no conflict resolution, no merge algorithm beyond hash-set union.]

=== Operations and Composability

#todo[The Set Algebra Theorem above is the *operational definition* of the ADT's four binary operations. The proof gives the rules: each operation produces a node-id subset by hash-set algebra, then closes under target-references to form a well-formed instance. Worked example: per-project ingestion as throwaway sub-graphs. Spin up an isolated graph for project X's ingestion; on success $"main" := "main" union "project"$; on failure drop the project graph. Selective rollback uses $\\$. Cross-fork agreement uses $inter$. Disagreement diffing uses $triangle.stroked.small$. Strictly stronger guarantee than Git: no merge conflict can ever occur. (Any read or write operation on a Ranke-Graph — whether through a library, a server, or a query layer — composes from these four; the ADT does not prescribe an interface, only the operations it must support.)]

#dref[D6, this section]

== Auth-Scoped Visibility and Verifiable Partial Views

Auth-scoped visibility (a node derived from a confidential source is automatically confidential) is compatible with the Merkle DAG.

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

=== Visibility Propagation

#todo[Formalise: a node is visible iff all its inputs are visible. Visibility propagates through $G_p$ automatically. Compliance by structure, not by policy.]

=== Compliance by Architecture

#todo[Brief paragraph: this is compliance by structure rather than by policy. The implementation in a real authentication system is the concern of a downstream paper.]

#dref[D5, this section]

== Schema-Light, Open-Ended Knowledge

#todo[Explain: the ADT prescribes no vocabulary for `type` (on nodes or edges) and no fixed schema for `content` or `fields_0..n`. A refinement may layer a content-type taxonomy on top, but the ADT itself does not commit to one. Vocabulary extension is therefore a contributor concern, not a structural change.]

#dref[D7, this section]

= Relation to Prior Work

== Temporal Knowledge Graphs: Graphiti / Zep

Graphiti (@rasmussen2025graphiti; @zep2025temporal, 2024–2025) is the closest existing system to the Ranke-Graph in the LLM context-management space.
It builds temporal, provenance-aware knowledge graphs using FalkorDB or Neo4j, with bidirectional episode indices and temporal validity windows.
Facts are invalidated rather than deleted.

However, Graphiti performs destructive entity-summary updates, has no content-addressable source archive comparable to the Ranke-Graph, and embeds provenance as annotation on the knowledge graph rather than treating it as the content itself.
The Ranke-Graph can be understood as an extension of Graphiti's philosophy — adding immutability, first-class sources, and the architectural inversion that makes provenance the substrate rather than an annotation.

== Versioned Knowledge Bases: TerminusDB

TerminusDB (@terminusdb) provides Git-like versioning (branch, merge, time-travel) over an RDF knowledge graph using append-only delta encoding.
It captures _what_ changed across versions but not _why_ — there is no derivation chain, no source archive, and no concept of contributors as provenance-tracked agents.
Its foundational structure is a versioned graph, not a provenance DAG.

== Immutable Databases: Datomic and Fluree

Datomic (@hickey2012datomic) operationalises Pat Helland's "Immutability Changes Everything" thesis (@helland2015immutability) as an append-only database of immutable datoms.
Fluree (@fluree) combines an append-only ledger with a semantic graph database.
Both capture temporal history but not _epistemic_ history — they record _when_ facts changed but not _how knowledge was derived from sources through processing chains_.

== Merkle Structures and Content Addressing

#todo[Merkle trees, IPFS, Trusty URIs (@kuhn2014trustyuris). What we share, what we add — chiefly: provenance edges become Merkle links, so the Merkle property is not over a tree of content blobs but over a DAG of derivations.]

== W3C PROV-DM

The W3C PROV Data Model (@moreau2013provdm) provides a formal vocabulary for provenance (Entity, Activity, Agent, wasGeneratedBy, wasDerivedFrom, used).
The Ranke-Graph is semantically compatible with PROV-DM — nodes map to Entities, contributor activities to Activities, contributors to Agents — but does not depend on or implement the W3C stack (RDF, SPARQL, OWL).
PROV-DM compatibility exists at the conceptual level, enabling potential export or interoperability without architectural coupling.

== Nanopublications

Nanopublications (@kuhn2014trustyuris; @nanopubs2025knowledgeprov) are immutable, content-addressable scholarly assertions with embedded provenance.
They share the Ranke-Graph's commitment to immutability and provenance-per-assertion but are a flat collection of independent assertions — they do not form a derivation DAG connecting assertions through chains of processing, and they do not support a semantic graph layer.

== CRDTs and Distributed Provenance

#todo[An add-only monotonic DAG is provably a Conflict-Free Replicated Data Type (@shapiro2011crdt) — it can be replicated across distributed nodes and always merged into a consistent state without coordination. This connection between provenance DAGs and CRDTs appears unexplored in the literature; we develop it formally in @sec:crdt and as related work here.]

== The Identified Gap

No existing system combines all of: (a) a content-addressable immutable source archive, (b) an append-only Provenance DAG as the primary data structure, (c) a semantic knowledge graph as a materialised view with per-edge provenance, (d) verifiable partial views under structural auth-scoping, (e) CRDT-compatible merge of independent replicas, and (f) natural-language relations with emergent ontology.
Each component has mature prior art; the architectural composition is novel.

= Conclusion

#todo[A small structure, a long list of consequences. Forward pointers to the implementation paper (working title _RankeDB_) and to subsequent work on workers, retrieval, and orchestration.]

#todo[Closing paragraph: reference implementations of the ADT in Go and Python accompany this paper. A binary conformance suite — example graphs and operations with expected hashes — accompanies them and makes conformance to the ADT decidable for any implementation.]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
