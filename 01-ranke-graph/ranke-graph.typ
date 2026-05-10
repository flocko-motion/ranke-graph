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

+ _Alice likes apples._
+ _Alice wrote Bob an email saying she likes apples._
+ _A file exists, attributed to Alice by its headers, that appears to be a copy of an email to Bob in which Alice claims to like apples._

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

A _claim_ in the Ranke-Graph is an attributed record — a piece of content added by a contributor at a specified moment in time. Source claims are external artifacts ingested into the graph; derived claims are built from existing claims, citing their references. Formal definition: @sec:claims.

This paper defines the Ranke-Graph as an abstract data type (ADT) — the minimum contract an implementation must satisfy to preserve a graph of attributed claims.

#todo[Self-review: verify that §5 explicitly returns to and validates the three-statements framing — that the paper demonstrates why storing at "the third layer" (attributed claims) yields the emergent properties. Without this payoff, the §1 hook lands without follow-through.]

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

This richness can overwhelm an extraction algorithm — flooding it with contradicting claims and long provenance traces. The Ranke-Graph supports _levels of detail_, realised through a class taxonomy (@sec:types): summary nodes that condense complex clusters, up to a semantic abstraction layer that expresses the distilled claims extracted from sources. The full provenance trace back to the source remains available on request.

Levels of distillation are what make the Ranke-Graph tractable for any agent or user operating under finite context — every agent has bounded context, every human reader has bounded attention. The pattern is iterative: fetch at high abstraction (just the relation types, say), narrow to the interesting candidates, request more detail on those (conviction values, reasoning content, then provenance edges, then source content), repeat. Each round is bounded; the full graph is reachable but never demanded all at once. A short answer at a coarse level is not _incomplete_ — it is the right slice for a query that doesn't need finer grain. The agent or user decides when to descend.

=== Taxonomy

Five concepts populate the graph. On the provenance side: *sources* (artifacts captured from outside the graph), *contributors* (humans, programs, or LLM agents that add nodes), and *derivations* (interpretations of existing nodes — classifications, summaries, fact extractions, entity resolutions). On the semantic side: *entities* (identifiable things in the world) and *relations* (reified assertions about how entities stand in relation to one another).

Contributors and entities are deliberately separate. A *contributor* is operational — the actor whose work brought a claim into the graph. An *entity* is semantic — a thing the graph holds claims about. The same real-world person may appear in both roles: as a contributor who adds claims, and as an entity referenced by relations. They *can* be linked by a claim asserting the connection — but they never share a node.


== A Vision

The Ranke-Graph is a substrate for systems just becoming possible — AI assistants whose answers trace to source records, agents that revisit and revise their reasoning chains, archives that survive external scrutiny. The ADT defined here is the foundation for such systems: deliberately _under-prescribed_, preserving claims with their full derivation while leaving retrieval, reasoning, and synthesis to systems built on top.

Such systems can evolve on the same data: selecting views that fit, contributing new derivations, marking, criticising or disproving earlier contributions. The graph accumulates; the history is complete, but filterable and queryable. Retrieval systems select what they deem most useful.

= Desiderata <sec:desiderata>

Following the motivation in @sec:introduction, we state the obligations any Ranke-Graph must satisfy. The seven items are independent — together they characterise the contract. Additional emergent properties — including idempotency of writes, external anchoring, the full set algebra, and the bijection between structural and semantic readings — follow as consequences (see @sec:emergent).

The desiderata describe what is required; the choice of how to satisfy them is open.

*D1. Immutability — no claim is ever modified or deleted.* Once recorded, no claim is modified or deleted by any subsequent operation. Revisions and corrections are themselves new claims that reference what they revise.

*D2. Provenance — every claim has a path back to its sources.* For every claim recorded in the archive, there exists an explicit, queryable path from the claim to the artifacts on which it depends, through every intermediate derivation.

*D3. Verifiability — integrity is provable from the structure.* Any past state of the graph is provable to a third party from the structure alone, without reliance on the operator.

*D4. Scoped Visibility — visibility propagates along references and admits scoping.* Visibility of a claim follows from the visibility of the claims it references, and can be scoped as required.

*D5. Distributability — replicas converge without coordination.* Independent replicas of the archive may evolve concurrently and converge to a common state without coordination, and without conflict resolution beyond merging the recorded claims of each replica.

*D6. Semantic Relations — rich relations can be expressed.* Claims of the form _"these entities stand in this relation"_ are recorded as single attributable units. The structure supports binary, $n$-ary, symmetric, and fuzzy-relation cases without requiring a separate construct for each.

*D7. Open-Ended Vocabulary — vocabulary is unbounded.* The vocabulary admitted by the structure is unbounded; new kinds may be added without modifying the structure or migrating existing data.

= The Data Structure <sec:structure>

The Ranke-Graph is a Merkle DAG (Directed Acyclic Graph) and a semantic graph, with a single node type (@sec:nodes) and a single edge type (@sec:edges) — acyclic by the atomic creation rule (@sec:claims), Merkle by content-addressed hashing, semantic by the direction tag on edges (@sec:semantic-claims), provenance-and-knowledge by a small fixed content-class taxonomy (@sec:types). From this definition, the structural consequences emerge (@sec:emerges).

== Primitives <sec:primitives>

Let $S$ be a canonical serialization mapping any object (node or edge) to bytes. It must be deterministic (same record → same bytes), complete (every field contributes), and self-delimiting (parsing recovers the record exactly).

Let $H$ be a cryptographic hash function. It must be collision-resistant and self-describing.

Any satisfying choice is acceptable — CBOR Deterministic (RFC 8949 §4.2) for $S$ and IPFS multihash for $H$ are well-known examples, adopted by the reference implementations. 

Identity is the composition: $op("id")(v) = H(S(v))$ for nodes, $op("id")(e) = H(S(e))$ for edges.

== Content <sec:content>

Content-hash-addressed storage holds any content $c$ as bytes, addressed by $H(c)$.

== Nodes <sec:nodes>

```
node = {
  type:         string (class/subtype, e.g. "source/conversation"),
  content_hash: H(content),
  encoding:     string (MIME media type, e.g. "message/rfc822"),
  created_at:   timestamp (UTC),
  edges:        set of owned edge ids,
  ...:          additional implementation-defined fields
}
```

- `type` follows the convention in @sec:types: `class` is from a fixed set, `subtype` open vocabulary.
- `encoding` is a MIME media type (@freed2013rfc6838) — e.g.~`text/plain`, `image/png`, `message/rfc822`.
- `content_hash` commits to the content bytes; stored in content-hash-addressed storage.
- `created_at` is the UTC timestamp the claim was added — *not* the time of its origin.
- Extension fields participate in $S$ like any other field, so proofs (@sec:verifiability and onward) apply uniformly.

== Edges <sec:edges>

```
edge = {
  reference:    id of referenced claim,
  type:         string (class/subtype, e.g. "relation/family"),
  content:      string,
  ...:          additional implementation-defined fields
}
```

Edges point from the `reference` claim to the node owning the edge. For types see @sec:types.

== Claims <sec:claims>

A *claim* is a node together with its content and the edges in its `edges` set. Each node or edge belongs to exactly one claim. A claim is created in a single atomic transaction; nothing can be added afterward. The node's hash covers every edge created with it, so $op("id")(v)$ is final at creation time.

== Relations (Semantic Claims) <sec:semantic-claims>

Provenance requires acyclicity — content addressing has no fixed point in a graph with cycles. But knowledge typically lives in a *semantic graph* where cycles are common: _Alice — knows → Bob_, paired with _Bob — ignores → Alice_.

A relation is itself a claim with a `relation/*` node and `relation/*` edges to `entity/*` claims.#footnote[This is the pattern known as *reification*; see RDF 1.0's `rdf:Statement` (@lassila1999rdf). The schema in @sec:edges constrains an edge's `reference` to a claim — never another edge — so relations cannot be encoded as plain edges between entities.] Its edges have a `relation_direction` field with values `from=1` or `to=-1`. All-`from` or all-`to` expresses a symmetric relation between the referenced entities — e.g., `are_friends`.

The *semantic reading* of a graph inverts each `relation/*` edge's direction if `relation_direction = -1`. The regular *structural reading* is acyclic; the _semantic reading_ admits cycles (formalized in @sec:bijection).

== Ranke-Graph <sec:ranke-graph>

A *Ranke-Graph* (RG) is a set of claims forming a graph. An RG is _valid_ if it contains a unique `contribution/contributor` node with no references — the *initial node* — every other claim carries a `contribution/contributor` edge, and all references recursively resolve to the initial node (@sec:types).

== Universe <sec:universe>

$cal(U)$ — the *universe* — is the set of all claims, addressed by id. Every *Ranke-Graph instance* $"RG"_h$ in $cal(U)$, addressed by a head id $h$ (@sec:head), is a subset
$"RG"_h subset.eq cal(U)$.

== Closures <sec:head>

Given $cal(U)$ and an id $h$, the instance $"RG"_h := "closure"(h, cal(U))$ is the transitive closure of claims reachable from $h$ by following each edge to its reference. The id alone suffices to recover it.

== Branches <sec:branches>

A *branch* is a name resolving to a closure, anchored by a `contribution/head` claim. A *branch table* is a `contribution/branches` claim with `contribution/branch` references to all contained branches and optionally a `contribution/branches` edge to the previous revision of that table. Both are stored in $cal(U)$ with $B_h$ being the id of the current branch table.

The branch table's history is itself a chain of `contribution/branches` claims, thus having full provenance.

== Ranke-Archive <sec:archive>

A *Ranke-Archive* is the tuple $(cal(U), B_h)$ — with $B_h$ being the mutable marker pointing at the latest branch table. From this, all branches, their history and all their graphs can be derived. Multiple archives can share $cal(U)$; each with its own $B_h$.

A new archive is created by writing the initial node and an empty `contribution/branches` claim referenced as $B_h$.

Ranke puts the universe into an archive.

= Discharging the Desiderata <sec:emerges>

== Validity <sec:validity>

An $"RG"_h$ is *valid* when it satisfies the construction rules of @sec:ranke-graph. Every $"RG"_h$ produced via those rules is therefore valid by construction — validity is structural, not a check, even for pruned graphs: prune-claims follow the same rules. Queries that honor those markers may hide claims from a viewer, but the underlying graph stays valid and complete. An invalid graph — broken construction, missing initial node, unresolved references — is structurally just an arbitrary graph $G$, not a Ranke-Graph.

== Consolidation <sec:consolidate>

When an RG has multiple open heads — after independent appends, scoping, pruning, or set operations — a single new head can consolidate them. Define
$ "consolidate"("RG") := "closure"(h_("new"), cal(U)) $
where $h_("new")$ is a new `contribution/head` claim with `contribution/head` edges to every currently-open head of RG, contributed by the operator. If RG already has a single open head, $"consolidate"("RG") = "RG"$.

An RG is *consolidated* when it already has a single head:
$ op("isConsolidated")("RG") <=> "RG" = "consolidate"("RG"). $

== Merkle DAG <sec:merkle>

Every valid $"RG"_h$ is a *Merkle DAG* (@bftcrdtmerkle, @ipfs): the atomic creation rule (@sec:claims) makes edges run from earlier claims to later ones, and identity $op("id")(v) = H(S(v))$ makes each claim's id recursive over the ids of every claim in its closure (@sec:primitives).

*Standing assumption.* The structure rests on *collision-resistance of $H$* — no two distinct byte sequences hash to the same value. Standard cryptographic hash functions (SHA-256, SHA-3, BLAKE3) are widely treated as collision-resistant in practice; mitigation is the implementer's choice of $H$.

Under this assumption, standard Merkle-DAG properties hold without further proof: the structure is acyclic; manipulation of any ancestor changes the descendant's id; identical claims produce identical ids. Subsequent sections invoke these as established.

== Immutability <sec:immutability>

Closure from $h$ is deterministic (@sec:head); under collision-resistance of $H$ (@sec:merkle), modifying $S(v)$ produces a different claim, not a modification. With monotonicity of $cal(U)$ (@sec:universe), recovery from $h$ yields the same $"RG"_h$ forever.

#dref[D1, this section]

== Idempotency <sec:idempotency>

By the Merkle-DAG structure, identical claims produce identical ids; under collision-resistance, identical ids imply identical claims. Writes are idempotent; deduplication is free.

#dref[D1, this section]

== Provenance <sec:provenance>

By the Merkle-DAG structure (@sec:merkle), reference traversal from any claim in $"RG"_h$ is acyclic and finite, terminating at the *initial node* (@sec:ranke-graph). Querying a node's provenance is therefore in $O(n)$.

Pruning (@sec:pruning) is a query-time access layer; the underlying chain in $"RG"_h$ stays complete.

#dref[D2, this section]

== Verifiability <sec:verifiability>

The Merkle-DAG id chain (@sec:merkle) witnesses *record* integrity, its embedded `content_hash` field witnesses the content bytes. Recursively computing the id of any $"RG"_h$ including the recalculation of each `content_hash` thus verifies the integrity of the full Ranke-Graph.

== Scoping <sec:scoping>

Scoping selects a sub-RG of $"RG"_h$ via an indicator $sigma : "RG"_h -> {0, 1}$. A claim $v$ is in scope when $sigma(v) = 1$ and every claim $v$ references is in scope — σ propagates through the closure. This allows creating a valid, consolidated subgraph of $"RG"_h$ that e.g. contains only the claims derived from the contributions of a specific contributor, or related to a specific project.

The in-scope claims form a set closed under references; consolidate them (@sec:consolidate) into $"RG"_(h_s)$. The result is a valid Ranke-Graph (@sec:validity): recursion reaches the initial node, full provenance, no prune edges. Incremental updates are cheap — apply $sigma$ to claims appended to the main line _after_ the timestamp of $"RG"_(h_s)$, merge with the previous selection, mint a new head.

== Pruning <sec:pruning>

Pruning allows creating partial views that hide arbitrary claims by referencing those by an edge of type `contribution/prune` - the immutable way of deletion by addition.

$op("pruned")(v in "RG"_h) <=>$ some `contribution/prune` edge inside $"closure"(h, cal(U))$ references $v$.

Pruning is a structural directive; implementations enforce it by hiding pruned claims from viewers. This requires that direct id-based access be operator-only — prune edges expose the ids of hidden claims, so users could otherwise bypass pruning by fetching them directly. Users access via branch names; the operator controls which heads they can reach.

An indicator $pi : "RG"_h -> {0, 1}$ marks visibility. Consolidate (@sec:consolidate) the heads with $pi = 1$ and add `contribution/prune` edges to claims with $pi = 0$ on the resulting head $h_p$:
$ "RG"_(h_p) := "closure"(h_p, cal(U)). $

A pruned view is not a valid Ranke-Graph (@sec:validity): provenance recursion halts at pruned claims, allowing Merkle integrity verification (@sec:merkle) for the visible claims only; pruned claims appear as id-only via `contribution/prune` edges, attesting existence without revealing content.

#dref[D4, this section]

== Set Algebra <sec:set-algebra>

Two set operations over RG node-id sets produce valid sub-RGs by virtue of content-determined ids (@sec:merkle): matching ids ARE the same claim, so set membership is well-defined and decidable by hash equality.

=== Union ($A union B$) <sec:union>

Every claim in either RG. Both inputs are closed under references, so the union is closed. Consolidate (@sec:consolidate) → valid sub-RG. 

=== Intersection ($A inter B$) <sec:intersection>

Claims in both RGs. Both inputs are valid (@sec:validity), so each contains every claim's full provenance. If $v in A inter B$, $v$'s provenance is in both $A$ and $B$ — hence in $A inter B$ — so the intersection is closed under references. No removed claim can be a provenance ancestor of a claim that stays. Consolidate (@sec:consolidate) → valid sub-RG, no pruning needed.

=== Subset Removal ($A \\ B$, $A triangle.stroked.small B$) <sec:removal>

Define a pruning indicator $pi$ so that $pi(v) = 0$ for claims to remove and apply pruning (@sec:pruning) — the result is a pruned view, not a valid sub-RG.

== Distributability <sec:distributability>

Two replicas of a Ranke-Archive converge by union (@sec:set-algebra) — the join-semilattice condition for Conflict-Free Replicated Data Types (@shapiro2011crdt). Replicas can write independently and reconcile by exchanging claim ids; every replica reaches the same state regardless of partition order.

#dref[D5, this section]

== Semantic Relations <sec:bijection>

A Ranke-Graph admits two readings of the same $V$ and $E$:

- *Structural reading*: edges run reference $arrow.r$ owner (older $arrow.r$ newer). Acyclic; Merkle-secured.
- *Semantic reading*: same $V$ and $E$, with `relation/*` edges directed by their `relation_direction`: `from` runs entity $arrow.r$ relation, `to` runs relation $arrow.r$ entity.

Provenance traversal (`derivation/*`, `contribution/*`) is identical in both. The structural reading is acyclic; the semantic admits cycles (e.g. _Alice knows Bob_, _Bob ignores Alice_).

#dref[D6, this section]

== Open-Ended Vocabulary <sec:vocabulary>

`class/*` is open vocabulary: applications add subtypes (`relation/family`, `source/conversation`, `derivation/transcription`, …) without modifying the ADT. Content schemas and extension fields are likewise application-defined; tools pass through what they do not recognize.

#dref[D7, this section]

= Additional Emergent Properties <sec:emergent>

Properties that follow from the structure beyond the desiderata. Each subsection cross-references the §5 chapter from which it emerges.

== Forks <sec:forks>

*Emerges from @sec:branches.* Forking is a new branch entry pointing at $h$ — $O(1)$.

== Backup <sec:hash-backup>

*Emerges from @sec:merkle + @sec:verifiability.* A single id $h$ recovers and verifies $"RG"_h$ from any replica of $cal(U)$.

== Anchoring <sec:anchoring>

*Emerges from @sec:hash-backup.* Publishing $h$ externally — e.g. to a public ledger or a newspaper#footnote[Surety LLC, founded by Haber and Stornetta on the construction of @haber1991, published weekly hash digests in the NYT classifieds for over a decade; archived papers witness the hashes at publication.] — witnesses $"closure"(h, cal(U))$ at the moment of publication.

== Cryptographic Attestation <sec:attestation>

Application-layer patterns built on the structural foundation, without ADT extension. *Emerges from @sec:immutability and @sec:verifiability.*

=== Signatures as Claims <sec:signatures>

A contributor's pubkey can live in the content of a `contribution/contributor` claim. Signed-by relationships can be recorded as separate `contribution/signature` claims referencing the signed claim's id — they cannot be a field on the signed claim itself, since the signature would have to be computed over an id that in turn is computed including the signature. Multi-sig, web-of-trust, and key rotation are then patterns over normal claims.

=== Trust Posture

If an implementation realizes the patterns above, the ADT provides the structural foundation for:

- *Integrity*: @sec:merkle, @sec:verifiability
- *Temporal*: @sec:anchoring
- *Authenticity*: @sec:signatures

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

#todo[An add-only monotonic DAG is provably a Conflict-Free Replicated Data Type (@shapiro2011crdt) — it can be replicated across distributed nodes and always merged into a consistent state without coordination. This connection between provenance DAGs and CRDTs appears unexplored in the literature; we develop it formally in @sec:distributability and as related work here.]

== The Identified Gap

No existing system combines all of: (a) a content-addressable immutable source archive, (b) an append-only Provenance DAG as the primary data structure, (c) a semantic graph as a materialised view with per-edge provenance, (d) verifiable partial views under structural auth-scoping, (e) CRDT-compatible merge of independent replicas, and (f) natural-language relations with emergent ontology.
Each component has mature prior art; the architectural composition is novel.

= Conclusion

#todo[A small structure, a long list of consequences. Forward pointers to the implementation paper (working title _RankeDB_) and to subsequent work on workers, retrieval, and orchestration.]

#todo[Closing paragraph: reference implementations of the ADT in Go and Python accompany this paper. A binary conformance suite — example graphs and operations with expected hashes — accompanies them and makes conformance to the ADT decidable for any implementation.]

= Type Vocabulary <sec:types>

The five concepts of @sec:everything-is-knowledge are encoded as five node classes and three edge classes; subtype vocabulary is open.

*Node classes:*

- *`source/*`* — an external data artifact.
- *`derivation/*`* — a claim built from other claims as inputs.
- *`entity/*`* — an identifiable thing in the world.
- *`relation/*`* — a node representing a relation among entities.
- *`contribution/*`* — a claim about contributors or their actions on the RG.
- *`contribution/head`* — consolidates currently-open content claims (see @sec:head)

*Edge classes:*

- *`derivation/*`* — provenance edges that cite the inputs a claim was derived from.
- *`relation/*`* — relation edges of a relation node (carry `relation_direction`).
- *`contribution/*`* — edges referencing a contribution that shaped the owning claim. The ADT defines five subtypes:
  - *`contribution/contributor`* — names the contributor of a claim
  - *`contribution/head`* — consolidates currently-open content claims (see @sec:head)
  - *`contribution/branches`* — names a branch table; from a branch table, points to the previous table in its history (see @sec:branches)
  - *`contribution/branch`* — edge-only; from a branch table, names one active branch (the branch name lives in the edge's `content`) and references its current head (see @sec:branches)
  - *`contribution/prune`* — view-modifying; excludes a reference from views containing the claim

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
