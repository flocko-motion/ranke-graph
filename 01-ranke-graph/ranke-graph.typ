#import "../shared/template.typ": *
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge

#show: paper.with(
  title:    "Ranke-Graph: A Provenance-First Data Structure",
  author:   "Florian Metzger-Noel",
  date:     "2026-05-03",
  status:   "scaffold",
  abstract: todo[One paragraph: a small data structure from which a list of properties — provenance, immutability, verifiable history, auth-scoped visibility, distributability, open-ended vocabulary — emerges as consequence rather than as feature. Close with: reference implementations in Go and Python accompany the paper, with a binary conformance suite. To be written after the body settles.],
)

= Introduction <sec:introduction>

Consider three statements:

#block(inset: (left: 1.5em, right: 1.5em))[
  _Alice likes apples._

  _Alice wrote Bob an email saying she likes apples._

  _A file exists, attributed to Alice by its headers, that appears to be a copy of an email to Bob in which Alice claims to like apples._
]

The first is a claim about the world. The second adds an attribution. The third is an observation of existence — a file is present, with the stated bytes, metadata, and content.

Storing at the first layer is the classic goal of database design.
Schemas, integrity constraints, and transactions are built to maintain a consistent model of the world; the caller is expected to have applied sound epistemology before writing data.
When facts change, or sources disagree, the database is edited to align; its earlier states, and thus the disagreement itself, are discarded.
In database discipline this is called _destructive consolidation_ or _last-write-wins_; it is usually considered _data cleaning_, and treated as consistency rather than loss. The cleaned value is an artifact of the algorithm, not a fact about the world; the ambiguity it discarded was itself information.

This is the ordinary condition of the enterprise data store, and works so long as the caller supplies correct facts about the world.

The Ranke-Graph is designed for the opposite stance.
It stores only at the third layer: attributed claims.
Every node is an observation-of-existence: this artifact, with these bytes, this attribution, added to the graph at this moment, appearing to make the claim its content carries.
The graph does not record whether Alice likes apples, or whether she wrote the email.
It records that a file is present, its metadata is as given, and the record has not been altered since it was written.
The guarantee is narrower than a conventional database's, and therefore keepable.

#concept("Claim")[
  A *claim* in the Ranke-Graph is an attributed record — a piece of content added by a contributor at a specified moment in time. Source claims are external artifacts ingested into the graph; derived claims are built from existing claims, citing their inputs. The claim and its references are stored together as the atom of the structure: immutable once written, traceable to every input it cites down to the sources.
]

This paper defines the Ranke-Graph as an abstract data type (ADT) — the minimum contract an implementation must satisfy to preserve attributed claims.

= The Problem and the Position

== The Archival Tradition

#todo[Note: compress this section]

The Ranke-Graph is named after Leopold von Ranke (1795–1886), the historian who transformed his discipline by insisting that every historical claim must trace back to a critically examined primary source.
Ranke's famous phrase — history _"wie es eigentlich gewesen"_, "as it actually was" — has since been rightly criticised for assuming unmediated access to past reality.
The Ranke-Graph takes that criticism as foundational: the primary data point is never _"how it was"_ but the artifact of a communicative act that reports, claims, or interprets it — an email, a chat message, a voicemail, a document.
What the Ranke-Graph stores is always someone's utterance about the world, never the world itself.
What survives from Ranke's method, intact, is the discipline of attribution: nothing is asserted without its derivation, and nothing is derived without its sources.

== The CS Priority That Was Never Operationalised

#todo[Note: compress this section]

Existing systems that address this tension do so partially.
Temporal knowledge graphs (Graphiti/Zep, @rasmussen2025graphiti) preserve _when_ facts were valid but perform destructive entity-summary updates, losing derivation history.
Versioned knowledge bases (TerminusDB, @terminusdb) track _what_ changed across snapshots but not _why_ or _how_ knowledge was derived.
Immutable databases (Datomic, @hickey2012datomic; Fluree, @fluree) preserve all historical states but lack a semantic knowledge layer and do not model derivation chains.
No existing system treats the full chain of provenance — from raw source artifact through extraction, normalisation, and synthesis — as first-class, queryable knowledge.

== The Rupture: Machines Reading and Writing at Scale

#todo[Note: compress this section]

Knowledge management systems face a fundamental tension: they must serve both _current_ truth and _historical_ understanding.
Traditional knowledge graphs optimise for the former — they store what is believed to be true now, updated in place as understanding changes.
This design made sense in an era of expensive storage and limited query capacity.
It makes less sense in a regime where the ability to present a model with the full derivation history of a belief — including contradictions, revisions, and competing interpretations — may support qualitatively better reasoning than presenting a single consolidated snapshot.

For a rich treatment of what _provenance_ has meant across 180 years — from the archival principle of _respect des fonds_ through the Semantic Web to the LLM era — we refer the reader to Talisman's essay (@talisman2026provenance).
In this paper we use the term in a narrower, operational sense: the complete derivation chain of a piece of knowledge — the raw source artifact, every intermediate processing step, every tool and configuration involved, and every transformation applied.
This is compatible with W3C PROV-DM's Entity/Activity/Agent vocabulary (@moreau2013provdm) but makes a stronger commitment: in the Ranke-Graph, provenance is not metadata about knowledge — it _is_ knowledge, stored in the same graph, queryable through the same interface, subject to the same invariants.
Each node in the graph is both a statement and the record of how that statement came to be.
There is no separate "provenance layer" — the derivation chain is the knowledge, and the knowledge is the derivation chain.

== Everything Is Knowledge <sec:everything-is-knowledge>

Throughout this paper we use *provenance* for the chain of derivation back to sources and contributors, *semantics* for the relations between entities, and *knowledge* for the union of both. The Ranke-Graph carries both as structure, in one graph.

Five concepts populate the graph:

- on the provenance side: *sources* (artifacts captured from outside the graph), *contributors* (humans, programs, or LLM agents that add nodes to the graph), and *derivations* (interpretations of existing nodes, e.g. classifications, summaries, fact extractions, entity resolutions);
- on the semantic side: *entities* (identifiable things in the world) and *relations* (reified assertions about how entities stand in relation to one another).

The Ranke-Graph makes no distinction between data, metadata, and provenance.
Every claim made _about_ the graph is itself a node in the graph, with its own provenance:

- a classification ("this node belongs to the finance domain"),
- a summary ("this is a condensed version of the conversation at node X"),
- an alias ("this node refers to the same person as node Y"),
- a creation record ("this node was added by contributor X with configuration Y").

*Provenance is not an annotation on the knowledge — it _is_ the knowledge.*

== Immutability and Accumulation

*Contradiction is not a bug to resolve; it is a fact about the evidence base.
Resolving it destroys information: the consolidated graph holds strictly less knowledge than the contradictory one it replaced.*

This stance is a deliberate bet on the trajectory of language model context windows.
Systems that destructively consolidate today — merging entity summaries, deduplicating facts, compacting histories — optimise for current retrieval efficiency at the cost of inferential depth.
The Ranke-Graph is built for a future in which a model able to traverse the full derivation history of a belief as needed — contradictions, revisions, and competing interpretations — may produce better reasoning than one given only a consolidated summary.

== Provenance Is Not Consensus

#todo[Expand from the bullet sketch in #raw("notes.md") "Philosophical Grounding":]

- *Provenance* = attribution (who said what, when, on what basis). Solvable by construction.
- *Consensus* = social agreement on what to trust. A human process, not a database concern.
- The Ranke-Graph handles provenance. Consensus is downstream, built by contributors on top.

*The Ranke-Graph stores attributed claims; common truth is what contributors build on top when they want it.*

== Bounded Scope

#todo[Expand from the bullet sketch in #raw("notes.md"):]

- At bounded scale (personal to small-enterprise), trust is pre-established, ontology is finite, adversarial resistance is simple.
- The Ranke-Graph does not aim for Wikipedia-scale global consensus.

= Desiderata <sec:desiderata>

Following the motivation in @sec:introduction, we state the obligations any Ranke-Graph must satisfy. The seven items are independent — together they characterise the contract. Other useful properties — traceability, idempotency of writes, mergeability of independent replicas, verifiability of partial views — follow as consequences.

The desiderata describe what is required; the choice of how to satisfy them is open.

*D1. Provenance.* For every claim recorded in the store, there exists an explicit, queryable path from the claim to the artifacts on which it depends, through every intermediate derivation.

*D2. Semantic Relations.* Claims of the form _"these participants stand in this relation"_ are recorded as single attributable units. The structure supports binary, $n$-ary, symmetric, and fuzzy-participation cases without requiring a separate construct for each.

*D3. Immutability.* Once recorded, no claim is modified or deleted by any subsequent operation. Revisions and corrections are themselves new claims that reference what they revise.

*D4. Verifiable History.* The state of the store at any past point in time is provable to a third party without reliance on the operator.

*D5. Auth-Scoped Visibility.* Visibility of a claim to an observer is determined structurally, not by policy: an observer sees a claim only if it sees every artifact and intermediate derivation on which the claim depends. Visibility propagates from inputs to outputs without explicit administration.

*D6. Distributability.* Independent replicas of the store may evolve concurrently and converge to a common state without coordination, and without conflict resolution beyond merging the recorded claims of each replica.

*D7. Open-Ended Vocabulary.* The vocabulary admitted by the structure is unbounded; new kinds may be added without modifying the structure or migrating existing data.

= The Data Structure <sec:structure>

The Ranke-Graph is a Merkle DAG (Directed Acyclic Graph) and a semantic graph, with a single node type (@sec:nodes) and a single edge type (@sec:edges) — acyclic by the atomic creation rule (@sec:atomic), Merkle by content-addressed hashing, semantic by the direction tag on edges (@sec:relation-direction), provenance-and-knowledge by a small fixed content-class taxonomy (@sec:classes). From this definition, the structural consequences emerge (@sec:emerges).

Two general primitives are used throughout: a canonical serialization $S$ mapping any record (node or edge) to bytes, and a cryptographic hash $H$ applied to those bytes. $S$ must be deterministic (same record → same bytes), complete (every field contributes), and self-delimiting (parsing recovers the record exactly); $H$ must be collision-resistant and self-describing (the id names the hash function used). Any satisfying choice is acceptable — CBOR Deterministic (RFC 8949 §4.2) for $S$ and IPFS multihash for $H$ are well-known examples, adopted by the reference implementations. Identity is the composition: $op("id")(v) = H(S(v))$ for nodes, $op("id")(e) = H(S(e))$ for edges.

== Nodes <sec:nodes>

```
node = {
  type:         string (class/subtype, e.g. "source/conversation"),
  content_hash: hash of the content bytes,
  encoding:     string (class/subtype, e.g. "text/eml"),
  created_at:   timestamp,
  edges:        set of input edge ids,
  ...:          additional implementation-defined fields
}
```

Identity:

$ op("id")(v) := H(S(v)) $

where $S$ is the canonical serialization (@sec:structure) and $H$ the cryptographic hash. Two nodes with identical content but different provenance produce different ids.

- `type` and `encoding` follow the `class/subtype` convention (@sec:classes): the first segment is from a fixed set, the second is open vocabulary.
- `content_hash` commits to the content bytes; the bytes themselves live in implementation-defined storage, addressed by `content_hash`. `encoding` tells how to interpret them.
- `created_at` is the timestamp the claim was added to the graph — *not* the time of any external artifact the claim may represent.
- Extension fields participate in $S$ like any other field, so proofs about node identity (@sec:merkle and onward) apply uniformly to any refinement.

== Edges <sec:edges>

An edge belongs to one node — its _parent_ — recoverable as the node whose `edges` set contains the edge's id.

```
edge = {
  target:       hash_of_target_node,
  type:         string (class/subtype, e.g. "relation/family", "evidence/chunk", "contribution/worker"),
  content_hash: hash of the content bytes,
  ...:          additional implementation-defined fields
}
```

Identity:

$ op("id")(e) := H(S(e)) $

Parent is implicit by necessity: if it were a field, $S(e)$ would depend on $S(v)$, which depends on $S(e)$ through the node's `edges` set — no consistent identity would exist.

*Structural direction is universal.* Every edge runs from an older node (its `target`) to the newer node that owns it (its parent), since the atomic creation rule (@sec:atomic) only allows references to already-existing nodes. This is the forward-in-time direction used in build graphs, dependency graphs, and pipelines. We call such an edge an *input edge* of its parent. Acyclicity (@sec:acyclicity) follows directly.

As for nodes, `type` follows the `class/subtype` convention (@sec:classes); `content_hash` commits to the edge's content bytes.

- *Relation edge* (`relation/*`). Carries a `relation_direction` (@sec:relation-direction); connects a relation node (parent) to a participant (target).
- *Provenance edge.* Class `contribution/*` (target is an agent or tool — every claim has at least one, to its contributor) or `evidence/*` (target is data the parent processed). The reference by hash _is_ the provenance record; no further field is required.
- Extension fields work as for nodes (@sec:nodes).

A node carries its edges' ids in its own record, so edges are Merkle-secured through the parent (@sec:merkle).

== Atomic Claim Creation <sec:atomic>

A *claim* is a node together with all its input edges. A claim is created in a single atomic transaction comprising:

- $n$ provenance edges (to sources, prior derivations, and the contributor),
- $m$ relation edges (to relation participants, carrying `relation_direction`).

Nothing can be added to a claim after creation. The node's hash covers every edge created with it, so $op("id")(v)$ is final at creation time.

== Relation Direction <sec:relation-direction>

The structure so far is a Merkle DAG. A semantic graph is not — it admits cycles that a DAG forbids. The semantic information is therefore embedded in the DAG: the *semantic reading* (@sec:semantic-reading) of the same $V$ and $E$ reveals it as a graph that admits cycles.

Two additions enable the semantic reading:

+ *Relations are reified as nodes.* (Reification — see RDF 1.0 `rdf:Statement` (W3C, 1999) #todo[(add RDF 1.0 to sources.bib)] — is a known technique.) A semantic relation is not a single edge but a _relation node_ with relation edges (those carrying `relation_direction`) to its participants. The relation's type lives on the relation node; participants are the edges' targets.

+ *The `relation_direction` field tags each participant's role in the reading.* Carried on each relation edge, with values
  $ "relation_direction" in {"from" = +1, "peer" = 0, "to" = -1}. $
  The symbolic names map to slots in the natural-language reading; the numeric backing supports aggregation at scale.

To read a relation, gather the relation node and all its relation edges, forming the generalised triple
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
    // Labels: rdir = relation_direction, conv = conviction.
    edge((0, 3), (5, 2.5), "->", [#text(size: 0.75em)[`rdir: from`, `conv: +0.7`]]),
    edge((0, 4), (5, 2.5), "->", [#text(size: 0.75em)[`rdir: from`, `conv: −0.4`]]),
    edge((0, 5), (5, 2.5), "->", [#text(size: 0.75em)[`rdir: to`, `conv: +1.0`]]),
  ))),
  caption: [Binary relation under entity-resolution ambiguity. The plaintext claim "Bob is Alice's brother" reads `(Bob, is_brother_of, Alice)`: Bob on the from-side, Alice on the to-side. Entity resolution found two candidate Bobs; both link to the same `is_brother_of` relation node with `rdir = from`, each carrying its own conviction in $[-1, +1]$. Alice is unambiguous, `rdir = to`, conviction $+1.0$. All edges — provenance and semantic alike — flow left-to-right into the newer (relation) node, the universal structural convention from @sec:edges. Label abbreviations: `rdir` = `relation_direction`, `conv` = `conviction`.],
) <fig:relation>

The same pattern scales to $n$-ary relations without changing the edge schema: more participants, more relation edges, each with its own role tag.

A relation node of type `are_similar` with $n$ `peer`-tagged edges represents a *similarity cluster*: a set of participants asserted to be similar, with no distinguished member and per-member conviction. Consumers filter, sort, or weight by conviction; the structure is unchanged from the binary case.

Beyond `relation_direction`, edges carry per-edge information through extension fields (@sec:edges). _Conviction_ is a useful example: a real value in $[-1, +1]$ with the endpoints recording full positive and negative conviction, and $0$ recording absence of evidence. The two-sided scale separates _we don't know_ (conviction $approx 0$) from _we know it isn't_ (conviction $< 0$). Conviction lives on the edge because the uncertainty is about role assignment in _this_ relation; the candidate nodes themselves are identified. The ADT does not define `conviction`.

A consequence of reifying relations as nodes: provenance edges target only nodes, never edges (@sec:edges). This is what gives relations provenance — and what makes $N : N$ relations natural, since every relation inherits the same provenance machinery as every other node.

The reading rule above is formalized in @sec:semantic-reading as the bijection between the structural and semantic readings of the same data.

== Content Classes <sec:classes>

The five concepts of @sec:everything-is-knowledge are encoded as the five node classes — `source/*`, `contributor/*`, `derivation/*`, `entity/*`, `relation/*` — together with three edge classes:

- *`relation/*`* — relation edges of a relation node (carry `relation_direction`).
- *`contribution/*`* — provenance edges to contributors involved in the parent's creation.
- *`evidence/*`* — provenance edges to data the parent processed.

*Carrying fields.* `type` (on nodes and edges) follows the convention `class/subtype`: the first segment is from the fixed class set; the second is open vocabulary. `encoding` (on nodes only) follows the same pattern with classes from the MIME-style set (`text`, `image`, `audio`, `video`, `application`) and format-specific subtypes (e.g. `text/eml`, `image/png`).

*Few classes, many subtypes.* The class sets are fixed and small — structural infrastructure. The subtype spaces are open: applications extend them without modifying the ADT.

= What Emerges <sec:emerges>

== Acyclicity <sec:acyclicity>

Let $G = (V, E)$ be the graph. Every edge $e in E$ has a target ($op("target")(e)$, the node it points at) and an implicit parent (the node whose `edges` set contains $op("id")(e)$). Edges are created atomically with their parent node (@sec:atomic).

#theorem[$G$ is acyclic.]

#proof[
  By the atomic creation rule (@sec:atomic), every edge $e$ owned by $v$ targets a node $u$ that existed at $v$'s creation — hence created in an earlier atomic transaction than $v$. The relation "created in an earlier transaction" on $V$ is strict and partial, and admits no cycles.
]

The proof makes no use of the class taxonomy: every edge runs old → new by the atomic-creation rule, regardless of class. The whole graph $G$ — including any future class — is a DAG.

#corollary[
  Cycles can appear under the *semantic reading* (@sec:semantic-reading), where `relation/*` edges flip direction by `relation_direction`: e.g. _"Alice knows Bob"_ together with _"Bob knows Alice"_ produce reciprocal relation nodes that close a cycle. The structural reading $G$ remains a DAG.
]

#dref[D1, this section]

== Content Addressing and Merkle Integrity <sec:merkle>

Identity is $op("id")(v) = H(S(v))$ for nodes and $op("id")(e) = H(S(e))$ for edges (@sec:structure). Every id is therefore a cryptographic hash, and a node's id depends — through $S(v)$ — on the ids of every edge created with it, which in turn depend on the ids of the targets they reference.

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
  Identical claims produce identical ids:
  $ forall v_1, v_2 : S(v_1) = S(v_2) arrow.r.double op("id")(v_1) = op("id")(v_2). $
]

Identical claims are the same claim — writes are idempotent, deduplication is free.

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

#todo[Add the *anchoring composition theorem*: publishing a single snapshot hash to a tamper-evident external medium (Bitcoin transaction, NYT classifieds, Sigsum log, etc.) anchors not only that snapshot but the integrity of every node in $G$ at $t_n$, by composition with Merkle integrity (@sec:merkle). Verifiable by any third party in $O("path length")$ Merkle proofs, without trust in the operator. One ~32-byte hash anchors the whole graph state.]

#todo[One-line *compliance angle*: this is a regulatory-grade tamper-resistance guarantee — the kind that medical, financial-audit, and legal-evidence systems spend significant money to approximate (write-once optical, notary services). Falls out structurally here. Do not over-explain; one sentence.]

#dref[D4, this section]

== Boolean Composability <sec:crdt>

#todo[Section opener (1–2 sentences): the graph admits a full set algebra over its node-id sets — $union$, $inter$, $\\$, $triangle.stroked.small$ — all conflict-free by construction.]

=== Set Algebra Theorem

#todo[Theorem: for any two Ranke-Graph instances $A$, $B$, the operations $A union B$, $A inter B$, $A \\ B$, $A triangle.stroked.small B$ over their node-id sets each yield a well-formed Ranke-Graph instance in $O(|V_A| + |V_B|)$ time, with no possibility of conflict.

Proof sketch composes three structural facts:
(1) content-addressed ids (@sec:structure) make node identity decidable by hash equality (O(1));
(2) immutability (D3, @sec:atomic) means a given id corresponds to one fixed record — no version disagreement is possible;
(3) DAG-by-construction (@sec:acyclicity) means any subset of $V$ closed under the edge-target relation is itself a DAG; closure costs O(|E|).

Each set op produces a node-id subset; closing under target-references yields a well-formed instance.]

=== Cheap Forks

#todo[Corollary: forking is divergence in the node-id set; content blobs are shared via the addressed pool. Storage cost of $N$ forks of a graph $G$ is $O(|V_G|)$ in metadata plus $O(1)$ in the content pool.]

=== Coordination-Free Merge

#todo[Corollary: convergence is $union$. The Ranke-Graph satisfies the join-semilattice condition for CRDTs (@shapiro2011crdt). No coordination protocol, no conflict resolution, no merge algorithm beyond hash-set union.]

=== Operations and Composability

#todo[The Set Algebra Theorem above is the *operational definition* of the ADT's four binary operations. The proof gives the rules: each operation produces a node-id subset by hash-set algebra, then closes under target-references to form a well-formed instance. Worked example: per-project ingestion as throwaway sub-graphs. Spin up an isolated graph for project X's ingestion; on success $"main" := "main" union "project"$; on failure drop the project graph. Selective rollback uses $\\$. Cross-fork agreement uses $inter$. Disagreement diffing uses $triangle.stroked.small$. Strictly stronger guarantee than Git: no merge conflict can ever occur. (Any read or write operation on a Ranke-Graph — whether through a library, a server, or a query layer — composes from these four; the ADT does not prescribe an interface, only the operations it must support.)]

#dref[D6, this section]

== The Semantic Reading <sec:semantic-reading>

The Ranke-Graph admits two readings of the same $V$ and $E$:

- the *structural reading* $"RG" = (V, E)$ — every edge runs target $arrow.r$ parent (older $arrow.r$ newer); acyclic; Merkle-secured (@sec:acyclicity, @sec:merkle).
- the *semantic reading* $"RG"^S$ — the same $V$ and $E$, with `relation/*` edges reoriented by their `relation_direction` field. Edges of class `contribution/*` and `evidence/*` are unchanged.

For a node $v$, let $op("class")(v)$ denote the first segment of $op("type")(v)$ (@sec:classes). For an edge $e$ with $op("class")(e) = "relation"$, let $op("rdir")(e) in {+1, 0, -1}$ denote `relation_direction` (@sec:relation-direction).

*Observation.* $"RG"$ and $"RG"^S$ share the same $V$ and $E$ as record sets; as directed graphs they differ only in the orientation of `relation/*` edges. In $"RG"^S$, each `relation/*` edge $e$ (parent $r$, target $t$) is oriented:

- $t arrow.r r$ if $op("rdir")(e) = +1$,
- $r arrow.r t$ if $op("rdir")(e) = -1$,
- ${r, t}$ (undirected) if $op("rdir")(e) = 0$.

All other edges are invariant.

*Properties.*

- The two readings are bijective on $V$ and $E$, and switching is computable in $O(|E|)$.
- Provenance traversal — `contribution/*` and `evidence/*` edges — is identical in both readings; no sign logic is ever needed for it.
- $"RG"^S$ admits cycles (e.g. _"Bob knows Alice"_ together with _"Alice knows Bob"_); $"RG"$ does not.
- The structural theorems (@sec:acyclicity, @sec:merkle, @sec:crdt) hold on the underlying $V$ and $E$; both readings inherit them.

*The semantic graph as subgraph.* The semantic graph $"SG"$ — the entity-and-relation portion typically queried by knowledge-graph consumers — is the subgraph of $"RG"^S$ induced by

$ V_("SG") = {v in V : op("class")(v) in {"entity", "relation"}}, quad E_("SG") = {e in E : op("class")(e) = "relation"}. $

$"SG"$ is a subgraph of $"RG"^S$, not a separate structure or a derived view. Reified relation nodes remain as hubs, preserving $N : N$ relations, partially-specified relations, and per-participant attributes (a common pattern: RDF reification, Wikidata statements with qualifiers).

== Auth-Scoped Visibility and Verifiable Partial Views

Auth-scoped visibility (a claim derived from a confidential source is automatically confidential) is compatible with the Merkle DAG.

A user receives a verifiable subgraph: full claims with content for everything in scope.
For branches outside their scope, they see only the hash — enough to verify the integrity of their own subgraph, but no content access.

```
[hash_only] ← confidential node, user sees only hash
     ↓
[full node] ← derived, user has access
     ↓
[full node] ← user has access
```

The user can verify: "my subgraph is intact, it builds on a claim with hash $X$ whose content I don't know."
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

No existing system combines all of: (a) a content-addressable immutable source archive, (b) an append-only Provenance DAG as the primary data structure, (c) a semantic graph as a materialised view with per-edge provenance, (d) verifiable partial views under structural auth-scoping, (e) CRDT-compatible merge of independent replicas, and (f) natural-language relations with emergent ontology.
Each component has mature prior art; the architectural composition is novel.

= Conclusion

#todo[A small structure, a long list of consequences. Forward pointers to the implementation paper (working title _RankeDB_) and to subsequent work on workers, retrieval, and orchestration.]

#todo[Closing paragraph: reference implementations of the ADT in Go and Python accompany this paper. A binary conformance suite — example graphs and operations with expected hashes — accompanies them and makes conformance to the ADT decidable for any implementation.]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
