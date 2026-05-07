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
  A _claim_ in the Ranke-Graph is an attributed record — a piece of content added by a contributor at a specified moment in time. Source claims are external artifacts ingested into the graph; derived claims are built from existing claims, citing their references. The claim and its references are stored together as the atom of the structure: immutable once written, traceable to every claim it references down to the sources.
]

This paper defines the Ranke-Graph as an abstract data type (ADT) — the minimum contract an implementation must satisfy to preserve a graph of attributed claims.

#todo[Disambiguation pending: throughout the paper, "the Ranke-Graph" is used both for *the structure* (the ADT) and for *an instance* (a hash-rooted subgraph). Once §4 introduces the substrate $cal(U)$ and the hash-rooted instance $"RG"_h$, sweep prose accordingly. Keep "the Ranke-Graph" only for the ADT itself; switch to $"RG"_h$ for instances and $cal(U)$ for the substrate.]

= The Problem and the Position

== Knowledge Systems: Machines Reading and Writing at Scale

Classical knowledge stores — wikis, knowledge graphs, structured databases, plain-text notes — consolidate sources into _current truth_, updating in place or creating new versions as understanding evolves; creating and maintaining this highly structured information causing permanent effort. Large language models consolidate sources statistically into model weights, with no record of where claims originated or whether they were ever made — producing fuzziness and hallucinations.

Merging the two approaches is an active research area, with many designs proposed. To understand what such a merge should preserve, we turn to the disciplines that have studied knowledge creation and preservation longest: historical science, archival theory, librarianship.

== Provenance: The Archival Tradition

The historian Leopold von Ranke (1795–1886) insisted that every historical claim must trace back to a primary source. His phrase — history _"wie es eigentlich gewesen"_, "as it actually was" — has been criticised for assuming unmediated access to past reality, but the underlying discipline survives: every claim has its derivation, every derivation has its sources. The archival principle _respect des fonds_ (1841) reached the same conclusion independently: records must be kept in the order and context of their origin. Suzanne Briet's 1951 _Qu'est-ce que la documentation?_ added a third angle: attribution is what transforms raw existence into evidence — an antelope in the wild is not a document; an antelope captured, classified, and recorded becomes one.

Across these traditions, three conclusions converge: contradictions in the evidence base are themselves evidence; provenance is not a layer above the knowledge but the knowledge itself; consensus — what to ultimately believe — is downstream from attribution, left to readers and time.

For a rich treatment of provenance across 180 years — from _respect des fonds_ through the Semantic Web to the LLM era — we refer the reader to Talisman's essay (@talisman2026provenance). Following its framing, a modern interpretation treats artifacts — messages, documents, recordings — as sources of subjective views, and derives knowledge by correlation across them.

Throughout this paper we use *provenance* for the chain of derivation back to sources and contributors, *semantics* for the relations between entities, and *knowledge* for the union of both.

== The Ranke Graph

The Ranke-Graph is the data structure for this discipline: a graph of _claims_ (as defined above), each carrying its full derivation chain. Each node is both a statement and the record of how that statement came to be.

=== Everything Is Knowledge <sec:everything-is-knowledge>

The Ranke-Graph makes no distinction between data, metadata, and provenance.
Every claim made _about_ the graph is itself a node in the graph, with its own provenance:

- a classification ("this node belongs to domain X"),
- a summary ("this is a condensed version of the conversation at node X"),
- an alias ("this node refers to the same person as node Y"),
- a creation record ("this node was added by contributor X with configuration Y").

The first three describe meaning; the last records creation. All are claims, all are nodes, all carry their own provenance.

*Provenance is not an annotation on the knowledge — it _is_ knowledge.*

This is compatible with W3C PROV-DM's Entity/Activity/Agent vocabulary (@moreau2013provdm), with the stronger commitment that provenance is stored in the same graph as content, queryable through the same interface, and subject to the same invariants.

=== Provenance and Consensus

The Ranke-Graph handles provenance — who said what, when, on what basis. Consensus — resolving contradictions into a single statement — is built downstream from the claims the graph preserves.

=== Immutability and Accumulation

The Ranke-Graph is append-only: claims accumulate; existing ones are never modified or deleted, since they represent historical artifacts which by the nature of time do not change. A knowledge extraction system — for example an LLM-based agent — thus has a richer basis: it can traverse the full derivation history of a belief, including contradictions, revisions, and competing interpretations. This richer basis should yield better reasoning than a consolidated summary that lacks provenance and uncertainty.

=== Levels of Distillation

This richness can overwhelm an extraction algorithm — flooding it with contradicting claims and long provenance traces. The Ranke-Graph supports _levels of detail_, realised through a class taxonomy (@sec:classes): summary nodes that condense complex clusters, up to a semantic abstraction layer that expresses the distilled claims extracted from sources. The full provenance trace back to the source remains available on request.

Levels of distillation are what make the Ranke-Graph tractable for any agent or user operating under finite context — every agent has bounded context, every human reader has bounded attention. The pattern is iterative: fetch at high abstraction (just the relation types, say), narrow to the interesting candidates, request more detail on those (conviction values, reasoning content, then provenance edges, then source content), repeat. Each round is bounded; the full graph is reachable but never demanded all at once. A short answer at a coarse level is not _incomplete_ — it is the right slice for a query that doesn't need finer grain. The agent or user decides when to descend.

=== Taxonomy

Five concepts populate the graph. On the provenance side: *sources* (artifacts captured from outside the graph), *contributors* (humans, programs, or LLM agents that add nodes), and *derivations* (interpretations of existing nodes — classifications, summaries, fact extractions, entity resolutions). On the semantic side: *entities* (identifiable things in the world) and *relations* (reified assertions about how entities stand in relation to one another).


== A Vision

The Ranke-Graph is a substrate for systems just becoming possible — AI assistants whose answers trace to source records, agents that revisit and revise their reasoning chains, archives that survive external scrutiny. The ADT defined here is the foundation for such systems: deliberately _under-prescribed_, preserving claims with their full derivation while leaving retrieval, reasoning, and synthesis to systems built on top.

Such systems can evolve on the same data: selecting views that fit, contributing new derivations, marking, criticising or disproving earlier contributions. The graph accumulates; the history is complete, but filterable and queryable. Retrieval systems select what they deem most useful.

= Desiderata <sec:desiderata>

Following the motivation in @sec:introduction, we state the obligations any Ranke-Graph must satisfy. The seven items are independent — together they characterise the contract. Other useful properties — traceability, idempotency of writes, mergeability of independent replicas, verifiability of partial views — follow as consequences.

The desiderata describe what is required; the choice of how to satisfy them is open.

*D1. Provenance.* For every claim recorded in the store, there exists an explicit, queryable path from the claim to the artifacts on which it depends, through every intermediate derivation.

*D2. Semantic Relations.* Claims of the form _"these entities stand in this relation"_ are recorded as single attributable units. The structure supports binary, $n$-ary, symmetric, and fuzzy-relation cases without requiring a separate construct for each.

*D3. Immutability.* Once recorded, no claim is modified or deleted by any subsequent operation. Revisions and corrections are themselves new claims that reference what they revise.

*D4. Verifiable History.* The state of the store at past points in time is provable to a third party without reliance on the operator.

*D5. Scoped Visibility.* Visibility of a claim follows from the visibility of the claims it references, and can be scoped as required.

*D6. Distributability.* Independent replicas of the store may evolve concurrently and converge to a common state without coordination, and without conflict resolution beyond merging the recorded claims of each replica.

*D7. Open-Ended Vocabulary.* The vocabulary admitted by the structure is unbounded; new kinds may be added without modifying the structure or migrating existing data.

= The Data Structure <sec:structure>

The Ranke-Graph is a Merkle DAG (Directed Acyclic Graph) and a semantic graph, with a single node type (@sec:nodes) and a single edge type (@sec:edges) — acyclic by the atomic creation rule (@sec:atomic), Merkle by content-addressed hashing, semantic by the direction tag on edges (@sec:relation-direction), provenance-and-knowledge by a small fixed content-class taxonomy (@sec:classes). From this definition, the structural consequences emerge (@sec:emerges).

Two general primitives are used throughout: a canonical serialization $S$ mapping any record (node or edge) to bytes, and a cryptographic hash $H$ applied to those bytes. $S$ must be deterministic (same record → same bytes), complete (every field contributes), and self-delimiting (parsing recovers the record exactly); $H$ must be collision-resistant and self-describing (the id names the hash function used). Any satisfying choice is acceptable — CBOR Deterministic (RFC 8949 §4.2) for $S$ and IPFS multihash for $H$ are well-known examples, adopted by the reference implementations. Identity is the composition: $op("id")(v) = H(S(v))$ for nodes, $op("id")(e) = H(S(e))$ for edges.

== Nodes <sec:nodes>

```
node = {
  type:         string (class/subtype, e.g. "source/conversation"),
  content_hash: H(content),
  encoding:     string (class/subtype, e.g. "text/eml"),
  created_at:   timestamp (UTC),
  edges:        set of edge ids,
  ...:          additional implementation-defined fields
}
```

Two nodes with identical content but different provenance produce different ids.

- `type` and `encoding` follow the `class/subtype` convention (@sec:classes): the first segment is from a fixed set, the second is open vocabulary.
- `content_hash` commits to the content bytes; the bytes themselves live in implementation-defined storage, addressed by `content_hash`. `encoding` tells how to interpret them.
- `created_at` is the UTC timestamp the claim was added to the graph — *not* the time of any external artifact the claim may represent.
- Extension fields participate in $S$ like any other field, so proofs about node identity (@sec:merkle and onward) apply uniformly to any refinement.

== Edges <sec:edges>

Each edge is part of exactly one claim, recoverable as the claim whose node lists the edge's id in its `edges` set.

```
edge = {
  reference:    id of referenced claim,
  type:         string (class/subtype, e.g. "relation/family", "derivation/chunk", "contribution/worker"),
  content_hash: H(content),
  ...:          additional implementation-defined fields
}
```

The owning claim's id cannot be stored on the edge: that would make $S(e)$ depend, via the claim's `edges` set, on $S(e)$ itself.

*Structural direction is universal.* Every edge runs from an older claim (its `reference`) to the newer claim that owns it, since the atomic creation rule (@sec:atomic) only allows references to already-existing claims. This is the forward-in-time direction used in build graphs, dependency graphs, and pipelines. Acyclicity (@sec:acyclicity) follows directly.

As for nodes, `type` follows the `class/subtype` convention (@sec:classes), and `content_hash` commits to the edge's content bytes. Edge content is application-defined — any comment on the creation or nature of this specific reference (e.g.\ "extracted lines 100–149" on a `derivation/chunk` edge; "based on same family name" on a `relation/*` edge to a candidate entity). Extension fields participate in $S$ like any other field.

A node carries its edges' ids in its own record, so edges are Merkle-secured through the claim that owns them (@sec:merkle).

== Atomic Claim Creation <sec:atomic>

A *claim* is a node together with the edges in its `edges` set. A claim is created in a single atomic transaction; nothing can be added afterward. The node's hash covers every edge created with it, so $op("id")(v)$ is final at creation time.

== The Universe of Claims <sec:universe>

$cal(U)$ — the *universe of claims* — is the set of all claims that have ever been created. A *Ranke-Graph instance* $"RG"$ is a subset of $cal(U)$:
$ "RG" subset.eq cal(U). $
References across instances are not transfers: a hash addresses the same claim in $cal(U)$ regardless of which instance first carried it. By immutability (D3), $cal(U)$ grows monotonically — claims are added but never modified or removed.

== Hash-Rooted Instances <sec:head>

Given $cal(U)$ and a hash $h$ that roots a tree, the instance $"RG"_h$ is the transitive closure of claims reachable from $h$ by following each edge to its reference. The hash alone suffices to recover it.

Concurrent writes naturally produce multiple open heads, breaking the tree property: no single hash can name a multi-headed state, since no claim sits above all of them.

To make such an instance addressable, we give it *a head*: a new `contribution/head` claim whose `contribution/head` edges name every currently-open head. The new claim unifies them under a single root — itself the unique open head — and its hash names the whole tree. A *branch* $B_x$ resolves to its current head, so the tree invariant is preserved. Earlier heads remain in $cal(U)$ (immutability) but the branch advances past them; only the latest head is the active handle.

#todo[Implementations may handle concurrent writes via sequencing, head consolidation, or auto-reference at commit time — details belong to rankedb.]

== Relation Direction <sec:relation-direction>

Provenance requires acyclicity — hash recursion has no fixed point in a graph with cycles. But knowledge typically lives in a *semantic graph*, where cycles are common: Alice knows Bob; Bob knows Alice. The Ranke-Graph carries both readings on the same $V$ and $E$: the *structural reading* is a strict DAG (used by every proof in @sec:emerges); the *semantic reading* (@sec:semantic-reading) admits cycles. Two additions to the structure enable the semantic reading:

+ *Relations are reified as nodes.*#footnote[Reification — expressing a relation as a node with edges to each entity, rather than as a single edge between them — is a known technique; see RDF 1.0's `rdf:Statement` (@lassila1999rdf).] A semantic relation is not a single edge but a _relation node_ with relation edges (those carrying `relation_direction`) to its entities. The relation's type lives on the relation node; entities are the edges' references.

+ *A `relation_direction` field tags each entity's role in the reading.* Carried on each relation edge, with values
  $ "relation_direction" in {"from" = +1, "to" = -1}. $
  The symbolic names map to slots in the natural-language reading; the numeric backing supports aggregation at scale.

To read a relation, gather the relation node and all its relation edges, forming the triplet
$ ("from_nodes", "relationship", "to_nodes"), $
where `from`-tagged edges contribute `from_nodes`, `to`-tagged edges contribute `to_nodes`, and the relation node supplies the relationship. A relation with one slot empty places all entities in the same role — either all on the from-side (each on the action side: _we're all learning from each other_) or all on the to-side (each on the receiving side: _we're all supporting each other_). @fig:relation illustrates the binary case under entity-resolution ambiguity.

#figure(
  pad(x: -2.5cm, align(center, diagram(
    spacing: (4em, 1.2em),
    node-stroke: 0.5pt,
    node-shape: rect,

    // Left column: all referenced (older) nodes.
    // Provenance sources at top.
    node((0, 0), [Contributor]),
    node((0, 1), [Source]),

    // Visual gap, then entities below.
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

The same pattern scales to $n$-ary relations without changing the edge schema: more entities, more relation edges, each with its own role tag.

A relation node of type `are_similar` with all $n$ entities on one side of the triplet represents a *similarity cluster*: a set of entities asserted to be similar, with no distinguished member and per-member conviction. Consumers filter, sort, or weight by conviction; the structure is unchanged from the binary case.

Beyond `relation_direction`, edges carry per-edge information through extension fields (@sec:edges). _Conviction_ is a useful example: a real value in $[-1, +1]$ with the endpoints recording full positive and negative conviction, and $0$ recording absence of evidence. The two-sided scale separates _we don't know_ (conviction $approx 0$) from _we know it isn't_ (conviction $< 0$). Conviction lives on the edge because the uncertainty is about role assignment in _this_ relation; the candidate nodes themselves are identified. The complementary edge `content` can carry the reasoning behind a given conviction (e.g.\ on the edge to Bob 1: "based on same family name; but not certain — common name"). This is _levels of distillation_ (§2) operating within a single relation: relation type → conviction → reasoning → source provenance, each layer optional. The agent or user reads down only as deep as needed. The ADT does not define `conviction`.

A consequence of reifying relations as nodes: provenance edges have only claims as references, never edges (@sec:edges). This is what gives relations provenance — and what makes $N : N$ relations natural, since every relation inherits the same provenance machinery as every other claim.

The reading rule above is formalized in @sec:semantic-reading as the bijection between the structural and semantic readings of the same data.

== Content Classes <sec:classes>

The five concepts of @sec:everything-is-knowledge are encoded as the five node classes — `source/*`, `contribution/*`, `derivation/*`, `entity/*`, `relation/*` — together with three edge classes:

- *`relation/*`* — relation edges of a relation node (carry `relation_direction`).
- *`derivation/*`* — provenance edges that cite the inputs a claim was derived from.
- *`contribution/*`* — claims about the work on the graph: contributor identity, policies, configs, pubkeys, signatures, structural acts (`contribution/head`), and view-modifying acts (`contribution/prune`).

All three edge classes also appear as node classes. The pattern is uniform: at the node level the class names a *thing* (a relation, a derivation, a contribution), at the edge level it names the *act* binding the owning claim to that thing (asserting the relation, deriving from an input, recording a contribution).

#todo[Edge taxonomy expansion:

- *`relation/*`* — semantic relation edges (carry `relation_direction`).
- *`derivation/*`* — citations to the inputs a claim was derived from. Subtype names the kind of derivation: `derivation/chunk` for an extraction, `derivation/transcription` for a transcribed source, etc.
- *`contribution/*`* — claims about the work on the graph. Open-vocabulary subtypes include:
  - identity and governance: `contribution/agent`, `contribution/policy`, `contribution/signature`, `contribution/pubkey`, `contribution/config`
  - structural: *`contribution/head`* — consolidates currently-open heads under a single root, making the instance addressable by one hash (see @sec:head)
  - view-modifying: *`contribution/prune`* — a `contribution/prune` edge in claim $c$ with reference $t$ means "exclude $t$ from any view that contains $c$". Per-edge content carries the reason (legal takedown, redaction, boolean difference, etc.).

The three classes share the uniform `class/subtype` convention; subtype is open vocabulary across all classes.]

*Carrying fields.* `type` (on nodes and edges) follows the convention `class/subtype`: the first segment is from the fixed class set; the second is open vocabulary. `encoding` (on nodes only) follows the same pattern with classes from the MIME-style set (`text`, `image`, `audio`, `video`, `application`) and format-specific subtypes (e.g. `text/eml`, `image/png`).

*Few classes, many subtypes.* The class sets are fixed and small — structural infrastructure. The subtype spaces are open: applications extend them without modifying the ADT.

#todo[Add §4.6 *Instances, Substrate, and Branches*: define foundational notions at the math level.

(1) $cal(U)$ — *the substrate*: the union of all claims that have ever been created. Monotone (only ever extended). Not held by any single party in the math; implementations choose where it lives.

(2) $"RG"_h$ — *a hash-rooted Ranke-Graph*: the closure-set of claims reachable from $h$ (via all edge classes — `relation/*`, `derivation/*`, `contribution/*`) within $cal(U)$. Every $"RG"_h$ is a finite subgraph of $cal(U)$, identified by its root hash. The bijection theorem (§5.5), set-algebra theorem (§5.4), and visibility theorem (§5.6) all take $"RG"_h$ as their referent.

(3) *Single-head invariant.* Every $"RG"_h$ has a single root $h$ — guaranteed by construction (@sec:head): branches resolve to a head, so $B_x$ is always single-rooted. Multi-head intermediate states may exist transiently in $cal(U)$ during concurrent writes; head consolidation resolves them.

(4) $B_x$ — *the branch named $x$*: at any moment, $B_x$ denotes the current graph at branch $x$ — equivalently, $"RG"_h$ where $h$ is the head currently bound to $x$. So $B_x subset.eq cal(U)$ at any frozen moment; mutability lives at the *name-binding* layer (the binding $x arrow.r.bar h$ may be updated as the graph grows). The hash is internal; the user-facing handle is $B_x$. A pure-pointer abstraction at heart; how branches are stored or synchronised is implementation choice (rankedb).

Subsequent sections use $"RG"_h$, $cal(U)$, and $B$ freely as defined here.]

= What Emerges <sec:emerges>

== Acyclicity <sec:acyclicity>

Let $G = (V, E)$ be the graph. Every edge $e in E$ has a reference ($op("reference")(e)$, the claim it points at) and an implicit owning claim (whose node lists $op("id")(e)$ in its `edges` set). Edges are created atomically with their claim (@sec:atomic).

#theorem[$G$ is acyclic.]

#proof[
  By the atomic creation rule (@sec:atomic), every edge $e$ owned by node $v$ has reference $u$ that existed at $v$'s creation — hence created in an earlier atomic transaction than $v$. The relation "created in an earlier transaction" on $V$ is strict and partial, and admits no cycles.
]

The proof makes no use of the class taxonomy: every edge runs old → new by the atomic-creation rule, regardless of class. The whole graph $G$ — including any future class — is a DAG.

#corollary[
  Cycles can appear under the *semantic reading* (@sec:semantic-reading), where `relation/*` edges flip direction by `relation_direction`: e.g. _"Alice knows Bob"_ together with _"Bob knows Alice"_ produce reciprocal relation nodes that close a cycle. The structural reading $G$ remains a DAG.
]

#dref[D1, this section]

== Content Addressing and Merkle Integrity <sec:merkle>

Identity is $op("id")(v) = H(S(v))$ for nodes and $op("id")(e) = H(S(e))$ for edges (@sec:structure). Every id is therefore a cryptographic hash, and a node's id depends — through $S(v)$ — on the ids of every edge created with it, which in turn depend on the ids of the claims they reference.

=== Tampering Detectable at the Root

#theorem[Manipulation of any node $v'$ in the ancestry of $v$ changes $op("id")(v)$.]

#proof[
  By induction on the depth of the DAG.

  _Base case._ $v' = v$. Changing any field of $v$ changes $op("id")(v)$ directly ($H$ is collision-resistant).

  _Inductive step._ $v'$ is an ancestor of $v$ in $G$. There exists a path $v' arrow.r dots.h.c arrow.r u arrow.r v$ in $G$ (following edges from $v$ back through its references). By the inductive hypothesis, manipulation of $v'$ changes $op("id")(u)$. $op("id")(u)$ is the reference hash used in the computation of some edge $e$ of $v$. Changing $op("id")(u)$ changes $op("id")(e)$. Changing $op("id")(e)$ changes $op("id")(v)$ (since $op("id")(e)$ is part of $v$'s hash computation and $H$ is collision-resistant).
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

== Anchoring <sec:anchoring>

#todo[Anchoring is *grounded* on the single-head invariant (revised 2026-05-07). The structural foundation is: every branch advance produces a head, every head is single-rooted, every head's hash witnesses everything reachable from it via the closure of its `contribution/head` edges. So at any moment, a single hash anchors the entire visible state of the branch.

External anchoring (publishing a hash to a tamper-evident medium for third-party proof) is unchanged — pick any head hash, publish it; it anchors everything in its closure. Hashchain emerges from the head sequence: head $h_n$ has `contribution/head` edges to the heads it consolidates, which transitively reach $h_(n-1)$ (since $h_(n-1)$ was an open head when $h_n$ was created), so $h_n$ witnesses $h_(n-1)$.

Restate §5.3 around heads-as-handles: anchoring is not occasional, it is constant; pick any head in your history and you have a tamper-evident witness of everything reachable from it.]

Heads are `contribution/head` claims whose `contribution/head` edges name all currently-open heads of $G$ plus the previous head:
$
  h_0 &= H(op("open-heads")(G, t_0)) \
  h_n &= H(op("open-heads")(G, t_n) || h_(n-1))
$

The head sequence $(h_0, h_1, dots.h.c, h_n)$ is a hashchain.
Each head witnesses the graph state _and_ all previous heads.
Manipulation of any $h_i$ invalidates all $h_j$ for $j > i$.

Head hashes can be published to any external timestamping service — for instance, in the New York Times or on a public ledger, following the construction of Haber and Stornetta (1991) — to provide third-party proof of graph state at a given point in time.

#todo[Add the *anchoring composition theorem*: publishing a single head hash to a tamper-evident external medium (Bitcoin transaction, NYT classifieds, Sigsum log, etc.) anchors not only that head but the integrity of every node in $G$ at $t_n$, by composition with Merkle integrity (@sec:merkle). Verifiable by any third party in $O("path length")$ Merkle proofs, without trust in the operator. One ~32-byte hash anchors the whole graph state.]

#todo[One-line *compliance angle*: this is a regulatory-grade tamper-resistance guarantee — the kind that medical, financial-audit, and legal-evidence systems spend significant money to approximate (write-once optical, notary services). Falls out structurally here. Do not over-explain; one sentence.]

#dref[D4, this section]

== Cryptographic Attestation <sec:attestation>

#todo[*Emergent capability, not a discharger of any D-item.* Keep this section *short* — point at the possibilities and move on. The deep treatment is the subject of a companion paper (working title _Ranke Cryptography_, see #raw("06-ranke-cryptography/notes.md") for the full development).

*The structure of this paper's mention.* One paragraph stating that the claim machinery enables a complete trust posture as application-layer patterns:

- *Signatures as claims* — `pubkey` in `contribution/*` content; signed-by claims reference hashes via `contribution/signature` edges. Multi-sig, web of trust, key rotation all fall out as patterns over normal claims.
- *Policies as claims* — admission rules live in the graph itself. A graph's governance is determined by the policy claims reachable from its head.
- *Validity is a function of a graph* — `valid(G, policy)`. Invalid graphs are well-formed; merge is structural composition; validation is a separate operation any party can run at any time.
- *Full historical auditability* — anyone can replay the validity check against the graph. Violations are recognized via additional claims; self-healing through accumulation, not editing.

Closing trifecta-plus table (one short paragraph + table):

#table(
  columns: 2,
  align: (left, left),
  [*Property*], [*Mechanism*],
  [Integrity], [hashes + Merkle DAG (§5.2)],
  [Temporal], [head hashchain + external anchoring (§5.3)],
  [Authenticity], [signatures as claims],
  [Governance], [policies as claims],
  [Enforcement verifiability], [validity as a function; replay against the graph],
)

The operator collapses to commodity storage + commodity gatekeeper. The trust posture is structural, not procedural.

*Length when written:* half a page maximum. The full design (signing schemes, policy DSLs, audit cadence, deployment workflow, regulatory mapping) is out of scope for this paper.]

== Boolean Composability <sec:crdt>

#todo[Section opener (1–2 sentences): the graph admits a full set algebra over its node-id sets — $union$, $inter$, $\\$, $triangle.stroked.small$ — all conflict-free by construction.]

=== Set Algebra Theorem

#todo[Disambiguate: $A$, $B$ here are $"RG"_(h_A)$, $"RG"_(h_B)$ — hash-rooted instances over $cal(U)$. Operations produce a new node-id subset and a new root (a head); the result is $"RG"_(h_("op"))$. Re-state once §4.6 lands.]

#todo[Result of a boolean operation is a *single hash* — a head whose `contribution/head` edges name the heads of the operand graphs that are part of the result and whose `contribution/prune` edges name what was excluded by the operation (e.g. set difference). No distinguished node class needed; the result is a normal head under the head mechanism of @sec:head. The earlier "(true_result, handle)" tuple framing dissolves: one hash $h_("op")$ fully describes $"RG"_(h_("op"))$.]

#todo[Theorem: for any two Ranke-Graph instances $A$, $B$, the operations $A union B$, $A inter B$, $A \\ B$, $A triangle.stroked.small B$ over their node-id sets each yield a well-formed Ranke-Graph instance in $O(|V_A| + |V_B|)$ time, with no possibility of conflict.

Proof sketch composes three structural facts:
(1) content-addressed ids (@sec:structure) make node identity decidable by hash equality (O(1));
(2) immutability (D3, @sec:atomic) means a given id corresponds to one fixed record — no version disagreement is possible;
(3) DAG-by-construction (@sec:acyclicity) means any subset of $V$ closed under the edge-reference relation is itself a DAG; closure costs O(|E|).

Each set op produces a node-id subset; closing under reference-traversal yields a well-formed instance.]

=== Cheap Forks

#todo[Corollary: forking is divergence in the node-id set; content blobs are shared via the addressed pool. Storage cost of $N$ forks of a graph $G$ is $O(|V_G|)$ in metadata plus $O(1)$ in the content pool.]

=== Coordination-Free Merge

#todo[Corollary: convergence is $union$. The Ranke-Graph satisfies the join-semilattice condition for CRDTs (@shapiro2011crdt). No coordination protocol, no conflict resolution, no merge algorithm beyond hash-set union.]

=== Operations and Composability

#todo[The Set Algebra Theorem above is the *operational definition* of the ADT's four binary operations. The proof gives the rules: each operation produces a node-id subset by hash-set algebra, then closes under reference-traversal to form a well-formed instance. Worked example: per-project ingestion as throwaway sub-graphs. Spin up an isolated graph for project X's ingestion; on success $"main" := "main" union "project"$; on failure drop the project graph. Selective rollback uses $\\$. Cross-fork agreement uses $inter$. Disagreement diffing uses $triangle.stroked.small$. Strictly stronger guarantee than Git: no merge conflict can ever occur. (Any read or write operation on a Ranke-Graph — whether through a library, a server, or a query layer — composes from these four; the ADT does not prescribe an interface, only the operations it must support.)]

#dref[D6, this section]

== The Semantic Reading <sec:semantic-reading>

#todo[Disambiguate throughout: $"RG"$ here is shorthand for $"RG"_h$ (a hash-rooted instance), not for $cal(U)$. The two readings are over the $V_h$, $E_h$ of one instance. After §4.6 lands, switch notation: $"RG"_h$ and $("RG"_h)^S$.]

The Ranke-Graph admits two readings of the same $V$ and $E$:

- the *structural reading* $"RG" = (V, E)$ — every edge runs reference $arrow.r$ owning claim (older $arrow.r$ newer); acyclic; Merkle-secured (@sec:acyclicity, @sec:merkle).
- the *semantic reading* $"RG"^S$ — the same $V$ and $E$, with `relation/*` edges reoriented by their `relation_direction` field. Edges of class `derivation/*` and `contribution/*` are unchanged.

For a node $v$, let $op("class")(v)$ denote the first segment of $op("type")(v)$ (@sec:classes). For an edge $e$ with $op("class")(e) = "relation"$, let $op("rdir")(e) in {+1, -1}$ denote `relation_direction` (@sec:relation-direction).

*Observation.* $"RG"$ and $"RG"^S$ share the same $V$ and $E$ as record sets; as directed graphs they differ only in the orientation of `relation/*` edges. In $"RG"^S$, each `relation/*` edge $e$ (owned by relation node $r$, referencing $t$) is oriented:

- $t arrow.r r$ if $op("rdir")(e) = +1$,
- $r arrow.r t$ if $op("rdir")(e) = -1$.

All other edges are invariant.

*Properties.*

- The two readings are bijective on $V$ and $E$, and switching is computable in $O(|E|)$.
- Provenance traversal — `derivation/*` and `contribution/*` edges — is identical in both readings; no sign logic is ever needed for it.
- $"RG"^S$ admits cycles (e.g. _"Bob knows Alice"_ together with _"Alice knows Bob"_); $"RG"$ does not.
- The structural theorems (@sec:acyclicity, @sec:merkle, @sec:crdt) hold on the underlying $V$ and $E$; both readings inherit them.

*The semantic graph as subgraph.* The semantic graph $"SG"$ — the entity-and-relation portion typically queried by knowledge-graph consumers — is the subgraph of $"RG"^S$ induced by

$ V_("SG") = {v in V : op("class")(v) in {"entity", "relation"}}, quad E_("SG") = {e in E : op("class")(e) = "relation"}. $

$"SG"$ is a subgraph of $"RG"^S$, not a separate structure or a derived view. Reified relation nodes remain as hubs, preserving $N : N$ relations, partially-specified relations, and per-entity attributes (a common pattern: RDF reification, Wikidata statements with qualifiers).

== Auth-Scoped Visibility and Verifiable Partial Views

#todo[Disambiguate: visibility scoping operates over $cal(U)$, returning a smaller $"RG"_h$ to the user. Every user query is $(h, sigma)$ for some scope $sigma$; the server selects $"RG"_h$ from $cal(U)$ filtered by $sigma$. Re-frame this section once §4.6 lands.]

#todo[*Definition (Scope).* A scope is an indicator function $bb(1)_sigma : V arrow.r {0, 1}$, where $sigma$ identifies a subset $Sigma subset.eq V$ of scope-eligible claims; $bb(1)_sigma (v) = 1$ iff $v in Sigma$. The predicate may be expressed as a function over claim fields (with access to fields of the claim's edges); concrete syntax and operator set are implementation choices (rankedb).

*Definition (Pruned set).* For a hash-rooted instance $"RG"_h$, the pruned set is
$ "pruned"(h) := { t in V : exists e in "closure"(h, cal(U)) "with" "type"(e) = "contribution/prune" "and" "reference"(e) = t }. $

*Definition (View).* The view of $"RG"_h$ under scope $sigma$ is
$ "view"(h, sigma) := lr(("closure"(h, cal(U)) inter Sigma)) \\ "pruned"(h). $
Equivalently: take the closure, keep scope-eligible claims, subtract pruned claims.

*Property (Scope-resistance of pruning).* The pruned set is computed against the *full closure*, not the post-scope subset, so $sigma$ cannot un-prune a claim. Scope determines what is rendered; pruning determines what is renderable at all. Pruning is structural (about $cal(U)$); scope is per-viewer.

*Property (Pure function).* $"view"(h, sigma)$ is a deterministic function of $(cal(U), h, sigma)$. Caches at the implementation layer are throw-awayable and reconstructible.]

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

#todo[Formalise: a claim is visible to an observer iff all the claims it *semantically depends on* (via its references) are visible. Visibility propagates along edges that carry semantic dependency: `relation/*`, all of `derivation/*` (e.g.\ `derivation/chunk`, `derivation/transcription`), and the semantic subtypes of `contribution/*` (e.g.\ `contribution/agent`, `contribution/policy`). It does *not* propagate along the structural subtype `contribution/head` — a head depends on its referenced heads only via hash for Merkle integrity, not semantically — nor along the prescriptive subtype `contribution/prune`, whose references are excluded by design. The refinement is at the subtype level, not a class-wide rule.]

=== Compliance by Architecture

#todo[Brief paragraph: this is compliance by structure rather than by policy. The implementation in a real authentication system is the concern of a downstream paper.]

#dref[D5, this section]

== Schema-Light, Open-Ended Knowledge

#todo[Explain: the ADT prescribes no vocabulary for `type` (on nodes or edges) and no fixed schema for `content` or `fields_0..n`. A refinement may layer a content-type taxonomy on top, but the ADT itself does not commit to one. Vocabulary extension is therefore a contributor concern, not a structural change.]

#dref[D7, this section]

= Relation to Prior Work <sec:related-work>

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
