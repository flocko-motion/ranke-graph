#import "../shared/template.typ": *

// ─────────────────────────────────────────────────────────────────────
// Language conventions (not rendered)
//
// British English throughout (writer-style PASSES.md, Pass 1).
//
// Kept as US / CS-conventional forms by deliberate exception:
//   - "artifact" (not "artefact"): established usage across CS and
//     digital-archival literature.
//   - "serialization" (not "serialisation"): CS technical term; standard
//     libraries, RFCs, and CS academic literature use -ize.
//
// First-level quotation marks: single ('…'); double for nested ("…").
//
// Cross-paper references: refer to the foundation paper (01-ranke-graph)
// in prose as "the foundation paper"; its sections as "(foundation paper
// §Name)". Keep references to other papers in the series out of the text —
// RankeDB's scope is the engine. Vocabulary follows the foundation paper:
// claims, contributors (the actors that add claims), the node classes
// source/derivation/entity/relation/contribution, and the identity
// id(v) = Sign(H(S(v))). The old L0/L1/L2 "levels" framing from the
// working notes is retired in favour of the foundation paper's class taxonomy.
//
// Convention: passages are tagged [FORCED] where the ADT dictates the
// behaviour and [FREE] where RankeDB makes an implementation choice that a
// conforming system may make differently.
//
// Golden rule: describe what a thing IS, never what it is not. Avoid
// defining by negation or absence.
//
// Terminology: every layer stores the graph, so 'graph layer' carries no
// information — write 'Cypher/GQL-capable layer' (e.g. neo4j) when a
// layer's query capability is what is meant. The ADT reference library
// (Go, soon Python) belongs to the foundation paper; this paper builds on it.
// ─────────────────────────────────────────────────────────────────────

#show: paper.with(
  title:    "RankeDB: Serving the Ranke-Graph",
  author:   "Florian Metzger-Noel",
  date:     "2026-06-22",
  status:   "scaffold",
  abstract: todo[One paragraph. RankeDB realizes the Ranke-Graph (defined as an abstract data type in the foundation paper) as a running database service. Where the foundation paper fixes _what_ must be preserved, this paper fixes _how_ to serve it efficiently while holding every invariant. The central architectural move: each Ranke Archive is persisted across a _stack_ of pluggable storage layers — object store, filesystem, graph database, in-memory index — whose bottom layer is the source of truth (read-through terminates there) and whose upper layers are rebuildable caches. Because claims are content-addressed, cache coherence is free and any supported engine can occupy the bottom. From this, the operational properties (deduplication, cheap forking, replication-as-caching) emerge as consequences. Close by naming: service-level authentication (a shared secret between application and database), a universal REST interface with a GQL endpoint where a Cypher/GQL-capable layer is in the stack, CRDT replication, and storage-layer conformance. RankeDB builds on the ADT reference library introduced in the foundation paper (Go, soon Python). To be written after the body settles.],
)

= Introduction <sec:introduction>

[Todo] a short introduction to what Ranke-Graph and Ranke Archive is. Hint at broad scope of possible use cases, as RG serves  a universal need when documenting/building an archive.

A Ranke Archive stores knowledge for the long term under a fixed set of guarantees: it is application-independent and format-agnostic; every claim is immutable and attributable to an author and a creation time; integrity is independently provable; and records are readable by humans and machines alike. Where many database designs maintain a single consolidated state — contradiction-free, overwritten as understanding changes — that represents the current truth, a Ranke Archive preserves the history of claims about the world, each made by an identified author and citing sources held in the archive. Such claims may contradict one another and may change over time; the archive keeps every version, with its disagreements intact. The goal is preservation with full provenance. 

The foundation paper (@metzgernoel2026rankegraph) defines the Ranke-Graph as an abstract data type accompanied by a reference implementation in Go. 

This paper specifies RankeDB, a reference database service that stores and serves *Ranke Archives* as defined in the foundation paper. It proposes an 
architecture, a modular persistence stack, read and write paths, a query model, and an authentication model. 

Analysing these use cases yields a set of desired properties, which the body then checks against the architecture. 

= An Epistemological Slice <sec:epistemology>

[Note: this is way to wordy - a condensed version should be written as an onramp]
The foundation paper opened from the archival tradition — Ranke, _respect des fonds_, Briet — and argued that provenance is the knowledge itself. This paper opens from the adjacent, epistemological slice of the same thought, because it is what motivates the storage model directly.

#todo[Write @sec:epistemology as ~1.5 pages. Source material: notes.md Part A (Talisman, Briet, Wilson, Burke, Cencetti, Cheney 2009) and Part B (the provenance/consensus stance). Do not repeat the foundation paper's archival argument; take the epistemological cut. Cite @talisman2026provenance; pull Briet/Wilson via it. The arc below.]

== Provenance and Consensus Are Orthogonal <sec:orthogonal>

Knowledge systems have long conflated two problems. *Provenance* — who said what, when, on what basis, derived from what — is an attribution problem, solvable by construction: do not throw the chain away. *Consensus* — what observers should agree to treat as true — is a social problem, requiring authority, negotiation, time. *Absolute truth* is incoherent as a stored object and is dropped from the design. The Semantic Web's error was to pre-bake consensus into the substrate; RankeDB handles provenance rigorously as a data problem and defers consensus to the layer above.

#todo[Develop: RankeDB stores _attributed claims_ — communicative acts by someone, at some time, in some context. "Napoleon was born in 1769" is not a fact in the store; it is some source's claim. Consequences (lift from notes Part B): contradiction is normal, not a bug; conviction replaces certainty; the same claim means different things by context; there is no ground-truth layer; ontology emerges per perspective, not globally. Keep the "we do not refuse common truth, we defer it to consumers and provide the substrate" line.]

== The Epistemology Is the Cache Hierarchy <sec:epistemology-architecture>

This is the bridge to the architecture, and the paper's organizing claim:

#concept[Interpretation is downstream of attribution.][Semantic interpretation and consensus are computed _from_ the attributed claims, never prior to them. The architecture honours this directly: the authoritative store — the bottom of the stack (@sec:two-planes) — holds the append-only claims, and every queryable _interpretation_ of them (a semantic-graph projection, a consensus view, a fast index) is a _derived, rebuildable_ layer above it, always recomputable and never itself the ground. Provenance sits at the foundation; interpretation is cache.]

#todo[Make the payoff explicit and forward-reference @sec:architecture: a graph-database projection of the semantic reading is _an interpretation_, hence an upper-layer cache; a consensus view is _an interpretation_, hence a cache; the durable claims at the bottom of the stack are the ground truth. This is why the topology in §4 puts a durable store at the bottom and derived views above it. Tie back to Helland's "the truth is the log; the database is a cache of a subset of the log" (@helland2015immutability), with the nuance that here the bottom _is_ a real store, not an abstraction.]


== Use Cases and Desired Properties <sec:use-cases>

A Ranke Archive is a unifying archive for long-term preservation. It sits between two familiar poles. On one side, operational infrastructure — git, CI pipelines, test systems, documentation, employee databases — is powerful day to day but fragmented across many systems, and free to mutate or disappear. On the other, classical backup — tape, cold storage — is durable but inert: fit for emergency reconstruction, rather than everyday use. A Ranke Archive may occupy the middle: as durable and tamper-evident as cold storage, yet as queryable and live as the systems it preserves — one store to trust for decades and use every day.

Possible use cases for a Ranke Archive include:

+ *Institutional Record.* An immutable, manipulation-resistant, provably timestamped record of who did what and when — approvals, audits, sign-offs, and operational decisions — anchored so it stands up to an outside auditor or a court.
+ *Software Provenance.* One store binding a project's otherwise-scattered outputs — build-time repository snapshots, release artifacts, test results, code reviews, security scans, and CVE triage — into one structured whole. While git's branches and tags can be rewritten or deleted, a Ranke Archive keeps a snapshot bound to its artifacts and results.
+ *Unified Accessible Backup.* A deduplicating, verifiable, content-addressed store of arbitrary bytes — structured, labelled, timestamped, provenance-annotated, and queryable across its whole version history. 
+ *Personal Archive.* Personal photos, email, and chats freed from vendor silos into a single application-independent, format-agnostic store — so a lifetime of memory outlives the services that produced it. Services are sold, shut down, or quietly change formats; an open archive with small, shareable adapters — Google Photos, IMAP mailboxes, cloud storage, chat histories — keeps the data usable in any application. Bound to an agent, the same archive becomes a second brain.

Across all four, the archive carries more than its records: a semantic layer of entities and relations — CVEs, contributors, customers, repositories, test runs — sits over them, turning the archive into a queryable knowledge graph that answers cross-entity questions such as _which releases came from this repository?_ or _which reviews did this engineer sign off?_ The cases share one shape across domains and scales, the personal archive being the same machinery at personal scale.

#imageonside(
  [
    Longevity rests on an asymmetry between products and formats. Services are short-lived, but fundamental formats endure — most in daily use for years before any standard ossified them, and still readable long after the tools that produced them are gone. The more open and widely implemented a format, the longer its life: the gap between introduction and standardization — CSV waited thirty-three years — shows the working form long preceding the formal one, and WAV endures with no formal standard at all.
  ],
  table(
    columns: 3,
    align: (left, center, center),
    inset: (x: 0.8em, y: 0.35em),
    stroke: 0.5pt + gray,
    table.header([*Format*], [*Introduced*], [*Standardized*]),
    [Plain text (ASCII)], [1963], [1972],
    [CSV],                [1972], [2005],
    [WAV (audio)],        [1991], [—],
    [HTML],               [1991], [1995],
    [UTF-8 text],         [1992], [1996],
    [JPEG],               [1992], [1994],
    [MPEG (video)],       [1993], [1993],
    [PDF],                [1993], [2008],
    [JSON],               [2001], [2006],
    [Markdown],           [2004], [2014],
  ),
  bottomtext: [
    Mature players read every codec ever shipped, so even video, for all its churn, stays openable decades on. Memory institutions reach the same conclusion: the Library of Congress maintains recommended-format and format-sustainability guidance favouring open, well-documented formats for long-term preservation.
  ],
)

#todo[Dig deeper into the Library of Congress "Recommended Formats Statement" and "Sustainability of Digital Formats" — an independent, institutional study of the same format-longevity question and strong corroboration for this section. Cite it; note SQLite's place on their recommended list when storage adapters are discussed (@sec:layer-contract).]

=== Inherited Guarantees <sec:inherited>

The use cases demand familiar properties — faithful records, verifiable history, clear attribution, openness. The foundation paper already proves these for any Ranke-Graph, as its desiderata D1–D9; RankeDB inherits them by implementing the ADT faithfully:

- *D1 — Provenance.* Every claim references what it builds on and has a path back to its sources.
- *D2 — Immutability.* Claims are append-only; each persists unchanged.
- *D3 — Identity and authenticity.* Every claim has a named author whose authorship is verifiable.
- *D4 — Temporality.* Every claim's time of existence is provably bounded.
- *D5 — Verifiability.* Integrity is independently verifiable.
- *D6 — Semantic relations.* Relations between entities can be expressed.
- *D7 — Open vocabulary.* Applications define their own categories and content schemas.
- *D8 — Partial views.* A view can expose a chosen subset of claims.
- *D9 — Distributability.* The structure supports distributed use.

These are given. What remains for the implementation — the design goals this paper is accountable for, and the architecture that meets them — follows.

=== Design Goals <sec:goals>

RankeDB sits one level above the ADT and one below any application: it supplies simple, enforceable building blocks, and the application decides whether and why to use them. The design goals divide into three groups.

_Storage._
- *G1 — Storage agnosticism.* Run on a wide range of storage backends, beholden to none.
- *G2 — Easy adapters.* Supporting a new backend is cheap.
- *G3 — Composability.* Persistence composes from mixable, layered backends.
- *G4 — Replicability.* Copying, replicating, and backing up an archive is cheap.

_Access._
- *G5 — Query interface and bounded reads.* The archive is queryable, and reads can be bounded for finite consumers.
- *G6 — Access control.* A caller-supplied scope is enforced for both reads and writes.
- *G7 — Key lifecycle.* A contributor's key can be rotated, revoked, or expired.

_Verification and witnessing._
- *G8 — Verification on demand.* Integrity is checkable on demand, at a depth the caller chooses.
- *G9 — Time-stamp witnessing.* Prove externally that the archive's entire content existed at a given moment.

The engine knows accounts, rights, archives, and stacks; *non-goals*, left to the application layer, are user and identity management, access policy, consensus or truth arbitration, and application logic. @sec:serving demonstrates — rather than proves — that the architecture meets G1–G9.

= From ADT to System: Design Tenets <sec:tenets>

#todo[Short section (~1 page) stating the invariants the implementation holds itself to. Each tenet gets a paragraph.]

== The Mutable/Immutable Boundary <sec:boundary>

Everything in the universe $cal(U)$ is immutable and content-addressed (foundation paper §Universe) — the branch table, branches, and heads among the claims. The _only_ mutable state is (a) the admin layer — service accounts, the archive registry, storage-stack configuration, and rights — and (b) per archive, the single hash $B_h$ that points at its current branch table (foundation paper §Archive). An archive is thus its universe plus one moving hash; advancing it swaps that hash. Drawing the boundary this sharply is what makes backup, forking, and replication cheap: the bulk is append-only and self-verifying; one pointer moves. *[FORCED]* by the ADT; the placement of the boundary is *[FREE]*.

== Dark Storage <sec:dark-storage>

No client enumerates storage. Every access is by id: `GET`/`PUT`/`HEAD` against a hash. Contributors never hold storage credentials; they speak to the service, which is the only storage client. Defining invariant: _if it is not reachable from a marker, it is not there_ — an unreferenced blob is benign (it occupies space but cannot be addressed), so garbage collection is optional. *[FREE]*, but load-bearing for the auth model (@sec:auth).

== The Database Documents; It Does Not Decide <sec:documents>

RankeDB authenticates the services that connect to it, records the signed claims they submit, and enforces the visibility scope bound to each. Signatures _document_ who contributed (the foundation paper makes authorship structural); scope _documents_ what a viewer may see. Decisions of truth — which claims are correct, which contributors are authoritative, what a reader should believe — live above the engine, in the application layer. This is the implementation-level reading of the foundation paper's closing principle. RankeDB therefore offers *mechanisms* — enforceable building blocks such as access control, key lifecycle, and time-stamp witnessing that an application opts into; the policy of who may do what, and why, stays above the engine.

= Architecture <sec:architecture>

This is the core of the paper.

== Admin Layer and Storage Stack <sec:two-planes>

RankeDB separates a small, mutable *admin layer* from the large, immutable *universe* held in a storage stack.

The *admin layer* is a relational store (the reference implementation uses PostgreSQL). It holds operational state only: service accounts and their secrets; the *archive registry* — each archive's name, its single $B_h$ hash, and its assigned stack; the configuration and connection details of each storage layer; and the rights that bind an account to read, write, or administer a set of archives and stacks. Branch tables, branches, and heads live in $cal(U)$ as claims; the admin layer keeps only the one $B_h$ pointer per archive. Erase it and every claim remains, entire, in the stack — accounts, configuration, and pointers are what is lost. *[FREE]*

The *storage stack* holds the universe: per archive, an ordered stack of storage layers containing $cal(U)$ — every claim, the branch table and heads among them.

#concept[Storage stack][A Ranke Archive is persisted across a _storage stack_: an ordered list of layers $ell_0, ell_1, …, ell_k$, from ground ($ell_0$) to top ($ell_k$). The archive's universe $cal(U)$ — its set of claims — lives in these layers. The ground layer $ell_0$ is the _source of truth_: read-through (@sec:through) terminates there, so it is authoritative and must be durable; whichever supported engine sits at the bottom holds the canonical claims. Each layer above it is a _derived layer_, populated by write-through and read-through, serving as cache, redundancy, or added query capability (@sec:layer-roles). A user may define any number of archives, each with its own stack — for example `S3-remote | S3-local | neo4j` or `S3-remote | local-FS | in-memory`. Each layer names a supported technology and its connection details.]

#todo[Figure: a vertical stack diagram (reuse / adapt drawio/layers.svg) showing ground = truth at the bottom, caches above, read-through arrows going down on miss and filling up, write arrows. Show two example stacks side by side to make "composable / modular" concrete.]

== The Layer Contract <sec:layer-contract>

Every layer, whatever its technology, must satisfy one minimal contract: content-addressed storage and retrieval of claims by id — `PUT(id, bytes)`, `GET(id)`, `HEAD(id)`. Because ids are content-derived (foundation paper §Primitives), this interface is enough to store, deduplicate, and verify the entire graph.

A layer also declares the *maximum content length* it will hold. A write larger than that limit falls through to the next layer down, so a layer may be _partial_, holding only the size range it serves well — a Cypher/GQL-capable layer, for example, may cap content at a few kilobytes (the reference implementation uses 8 kB for neo4j), staying fast and query-focused while large blobs live in the object store beneath.

One layer must be *complete*: the ground layer accepts content of any size, so the stack as a whole loses nothing. A complete layer may itself be _composite_ — several backends presented as one, such as geographically distributed object stores addressed through a routing layer — provided it is complete as a system. A performance layer can thus shard or route across backends while still standing as the source of truth.

Capabilities above that contract are _additive and negotiated by technology_:

- a Cypher/GQL-capable layer (neo4j) serves the semantic reading natively and unlocks the GQL query endpoint (@sec:query);
- an object store or filesystem layer provides the minimal contract: durable content-addressed storage;
- an in-memory layer provides speed for a hot working set.

The client-facing query surface for an archive is therefore a function of its stack (@sec:query): the REST interface always, and the /gql endpoint when a Cypher/GQL-capable layer is in the stack. The adapter set is open — additional technologies are new modules implementing the contract. *[FREE]*; the minimal contract is *[FORCED]* by the need to recompute ids.

#todo[Enumerate the supported adapters and their declared capabilities in a table: technology | durability | query | max content length | typical position. Ship: filesystem (baseline — show it inline, ~a dozen lines, as proof the contract is tiny), in-memory (cache/test), S3-compatible (R2, Backblaze, MinIO), Redis (KV cache tier), SQLite, neo4j (GQL; ~8 kB content cap), IPFS (native CAS). SQLite is motivated by the Library of Congress recommended-formats endorsement and enables a concrete use — *export any archive as a single file*. The adapter set is open; a new adapter is a module implementing the contract.]

== Layer Roles: Cache, Redundancy, Capability <sec:layer-roles>

An upper layer earns its place in three ways, and one layer may serve several at once:

- *Cache* — a faster or nearer store that absorbs reads, such as an in-memory or local layer above a remote ground.
- *Redundancy* — a write-through layer holds a full live copy of the claims, so it is at once a replica and a backup. Adding a durable store as a mid-layer turns on backup: write-through populates it, and content-addressing guarantees the copy is exact. This reduces use case (3) to a configuration change.
- *Capability* — a Cypher/GQL-capable layer adds the `/gql` endpoint (@sec:layer-contract).

#todo[Spell out the redundancy role with the `S3 | S3 | neo4j` example: the middle S3 is a write-through backup target that fills automatically. Connect to @sec:distribution — a write-through replica _is_ the replication story.]

#todo[Briefly note (out of scope for the reference implementation) richer stack shapes: a layer with alternative parallel servers offering routing paths, e.g. `(S3-root) | (S3-US, S3-Europe) | (neo4j-local)`, where geographic mid-layer servers carry read load and spare the root. A scaling direction the stack model admits, deliberately left for later.]

== Read-Through, Write-Through, Verification <sec:through>

*Reads* are read-through: a query hits the top layer; on a miss it falls to the next layer down, and the recovered claims fill the layers it passed. *Writes* are either write-through (write every layer) or write-to-ground-then-read-through (write $ell_0$, let subsequent reads populate caches) — a per-archive policy. *Verification* read-throughs every claim in a closure to recompute its id chain (@sec:verify); as a side effect it fully warms every cache. *[FREE]*

== Cache Coherence Is Trivial <sec:coherence>

Content-addressing removes the hardest part of a cache hierarchy: invalidation. The bytes at id $h$ are the bytes at $h$ forever, so a cached claim can never be stale. Cache fill is a pure function; eviction is always safe; the policy reduces to plain LRU. Any upper layer can be dropped and rebuilt from below at any time with no loss of truth — the ground always suffices to repopulate it. *[FORCED]* by content-addressing (foundation paper §Immutability, §Idempotency).

#todo[State the consequence cleanly: every layer _above_ the ground is literally a cache — droppable and rebuildable from below — while the ground layer is the durable truth. Cross-reference @sec:epistemology-architecture: a semantic-graph projection is one such rebuildable upper-layer cache, never the source of truth.]

= Claims and Blobs <sec:representation>

== Representing Claims and Edges <sec:claim-rep>

#todo[Recap the foundation paper's node/edge schema only as far as the implementation needs it (keep the recap minimal). node = (type, content_hash, encoding, created_at, edges); edge = (reference, type, content). id(v) = Sign(H(S(v))). Serialization S = CBOR Deterministic (RFC 8949 §4.2); H = IPFS multihash (self-describing); Sign = Ed25519 / ECDSA-RFC6979. Self-describing hash and signature are what give crypto-agility for use case (1) — show a multihash/multicodec id can name its own algorithm, so the store can hold claims under several schemes during a decades-long migration.]

== Content Blobs <sec:blobs>

Content bytes are stored whole, addressed by $H(c)$: a blob is a single object, however large. Identical content resolves to one id and is therefore stored once — deduplication is intrinsic to addressing by hash. How a source is divided into claims is the application's decision (@sec:documents); the store holds whatever claims it is given. *[FREE]*

== Default Type Vocabulary <sec:default-types>

The foundation paper keeps the subtype vocabulary open. RankeDB ships a small _default_ set of subtypes for the common records case (conversations, media, records, structured data, bulk containers) alongside the cognitive derivations (classification, observation, summary, fact), so a fresh stack is immediately useful and applications extend from a sensible base. This is one of the few concrete choices, at this paper's altitude, that the foundation paper leaves to implementations.

#todo[Pull the opinionated taxonomy from notes Part H: the `source/*` and `derivation/*` default subtypes, the encoding convention (MIME-style `class/format`, e.g. `text/eml`, `image/png`, `application/pdf`), and the 'few types, many encodings' principle. Present as RankeDB defaults, application-extensible. Mark *[FREE / default]*.]

== Recommended Practice: Generic-Format Extracts <sec:extracts>

The format asymmetry of @sec:use-cases shapes how best to fill an archive: keep each original in whatever format it arrived, and store a generic-format extract beside it — Markdown or plain text for documents, JSON for structured data. The extract is a derivation claim citing its source, so the long-lived generic copy carries full provenance back to the original; when the original's format lapses, the extract still opens. This is application-layer guidance — the store holds whatever claims it is given (@sec:blobs). *[FREE]*

== Two Readings, Two Indexes <sec:readings>

#todo[Map the foundation paper's structural vs semantic readings onto layers. The structural (provenance, acyclic, Merkle) reading is served by any layer (it is reachability over derivation/contribution edges). The semantic (relation, possibly cyclic) reading is served natively by a Cypher/GQL-capable layer or by in-engine traversal over a minimal stack. Same claim set, two traversal indexes. Note: the semantic projection is a cache (@sec:coherence), rebuildable from the claims.]

= The Write Path <sec:write>

== Atomic Claim Creation <sec:atomic-write>

#todo[A claim (node + content + its edges) is created in one atomic transaction; id is final at creation (foundation paper §Claims). Describe the API call and what the service does: compute $H(c)$, PUT content, compute $S(v)$, $H$, sign → id, write the claim through the stack, update the marker. Monotonicity check: $"created_at"(v) >= max("created_at"(u))$ over references. [FORCED].]

== Idempotency and Deduplication <sec:dedup>

#todo[Writes are idempotent by id: re-PUTting an existing claim is a no-op; identical content yields one blob. Deduplication is free and coordination-free (foundation paper §Idempotency). [FORCED]. This is the backbone of use case (3).]

== Concurrency: The Single Sequencer <sec:single-head>

An archive advances by one mutable hash, $B_h$ (@sec:boundary). The server that owns an archive is its sole *sequencer*: concurrent write requests are serialized at the atomic swap of $B_h$, so the archive always has a single head. Two servers advancing the same archive are two sequencers; unaware of each other, they fork — reconciled later by union (@sec:distribution).

#todo[Detail the commit: append the claim(s) to the stack (content-addressed, idempotent), write the new branch-table claim, then compare-and-swap $B_h$, retrying on a losing CAS. This is the whole of concurrency control — one pointer, one sequencer — superseding the multi-strategy framing in the working notes. [FREE].]

== Branch Markers, Pruning, Forking <sec:markers>

#todo[Branch advance updates the branch table ($B_h$); a branch is a name → head (foundation paper §Branches), now an in-graph `contribution/*` claim, held in the graph rather than a Postgres row (correct the stale notes here). Pruning = appending contribution/prune claims (foundation paper §Pruning). Forking = a new branch entry pointing at an existing head — O(1) (foundation paper §Forks). All three are ordinary writes plus a marker move. Mention purge (drop a branch + its non-shared blobs) as the destructive admin escape hatch; the workflow itself sits in the application layer.]

= The Read Path and Query Model <sec:read>

== One Primitive: Closure Under Scope and Prune <sec:closure>

Every read reduces to one operation: materialize $"closure"(h, cal(U))$ filtered by a visibility scope and the prune set, in a single read-through sweep.

#todo[Give the combined-view formula from notes Part F: closure(h) ∩ scope.predicate ∖ prune-referenced. One walk; collect prune references and evaluate the scope predicate against the original closure; subtract both. State the P-then-S ordering subtlety (pruning is scope-resistant: a pruned reference stays excluded even if the prune-claim itself is out of scope; only the prune-claim's content is hidden). This single primitive serves ordinary reads, audit reads (use case 2/4 = closure + time/contributor filter), and partial views.]

== Progressive Disclosure <sec:disclosure>

#todo[The foundation paper's "levels of distillation" as a read mechanism for bounded-context consumers (use case 1, agents). The read API returns at a coarse level (relation types, summaries) and drills down on request (conviction, reasoning, provenance edges, source content). Each round is bounded; the full graph is reachable but never demanded at once. The engine provides the mechanism; the _strategy_ for choosing levels sits in the application layer.]

== The verify Operation <sec:verify>

#todo[Define `verify(h)`: read-through the closure of $h$ and recompute the id chain — for each claim recompute $S(v)$, $H$, and check $op("id")(v) = "Sign"(H(S(v)))$, and recompute each `content_hash`. One recomputation checks record integrity and authorship together (foundation paper §Verifiability). State complexity ($O(n)$ over the closure) and the side effect (warms every cache, @sec:through). Use cases (2) and (4) lean on this; the trust posture built atop it sits above the engine.]

== Query Interfaces <sec:query>

RankeDB exposes two client interfaces; which are available follows from the stack:

- A *simple REST API*, available on every stack. It serves the closure/provenance reads of @sec:closure, the write operations of @sec:write, and `verify` (@sec:verify), and carries the scope predicate (@sec:scope-dsl) as a parameter. It reduces to the minimal layer contract plus in-engine traversal.
- A `/gql` endpoint, available when a Cypher/GQL-capable layer (neo4j) is in the stack. It serves GQL pattern queries over the semantic reading, pushed down to that layer.

The REST interface covers every stack; a Cypher/GQL-capable layer adds the /gql endpoint on top. *[FREE]*

= The Scope Predicate DSL <sec:scope-dsl>

Both interfaces of @sec:query share one small filter language: the scope predicate that fixes what a viewer may see.

#todo[From notes Part F. A small expression language over node/edge fields: = ≠ < > ≤ ≥ ∃ ∧ ∨ ¬. Canonicalized to an AST encoded in CBOR Deterministic (same serialization as the ADT). The leaf predicate composes with the structural visibility-propagation rule: a claim is visible iff it satisfies the predicate AND all its provenance ancestors are visible — so the DSL needs no traversal operators. Content-addressed: scope_id = H(canonical(predicate)); editing a predicate yields a different scope_id, hence a different (empty) cache (mirror of @sec:coherence one layer up).]

#todo[Add one worked REST read example (closure + scope predicate) and one GQL example over the semantic reading, grounding the two interfaces of @sec:query. The semantic surface is GQL as the Cypher/GQL-capable layer provides it; the structural surface is the REST API.]

= Authentication and Visibility <sec:auth>

== Service Authentication and Signature Verification <sec:service-auth>

RankeDB's authentication governs _access_. A connecting service — an application talking to the database — presents a shared secret (a bearer token, JWT, or equivalent) and receives the read/write access bound to it, as a conventional database authenticates a connecting service. The admin layer (@sec:two-planes) holds the account registry and the binding from an authenticated secret to its rights and scope (@sec:scope-enforce). End-user identity and authorization belong to the application layer.

Claim authorship is handled where the content lives: the application signs each claim, holding its own private keys (foundation paper §Authenticity). RankeDB's part in signing is verification — on write it recomputes $op("id")(v) = "Sign"(H(S(v)))$ and admits the claim only when the signature checks, so every stored claim is valid by construction. Access secrets govern who may speak to the database; signatures govern who authored a claim; the two stay independent. Multi-sig and web-of-trust are application patterns; *key lifecycle* (rotation, revocation, expiry) is a building block RankeDB enforces — a contributor-replacement claim retires a key, and the database refuses new claims signed by it thereafter, while *who* may retire *whom* stays application policy. *[FREE]* for access; write-time verification is *[FORCED]* by validity.

#todo[Keep the two roles crisp: (1) connection secret → access (read/write), held in the admin layer; (2) claim signature → authorship, produced by the application and verified by the database at write time. Make the database-role analogy precise: secret → role → privileges, mirrored as token → role → scope.]

== Server-Enforced Access <sec:scope-enforce>

A scope bounds both reads and writes, and the client does not choose it at request time: an authenticated identity resolves through the admin layer to its scope, which the server applies.

#todo[Define the scope config format: a base policy (`allow-all` or `deny-all`) plus an ordered list of exceptions matching field/edge names and types with wildcards, separately for read and write. Relate it to the predicate DSL of @sec:scope-dsl (the config is the operator-facing surface; the predicate is what it canonicalizes to). From notes Part F: no elevation path — a different scope is a different binding, hence a different (content-addressed) cache. Vocabulary (what scopes exist) vs binding (which scope is forced on whom); binding is mandatory.]

== Verifiable Partial Views <sec:partial-views>

#todo[From notes "Auth-Scoped Visibility and Merkle Compatibility". A scoped reader gets full content for in-scope claims and hash-only stubs for out-of-scope references — enough to verify the integrity of their own subgraph without seeing hidden content, exactly as a Merkle proof reveals sibling hashes without revealing their content. Auth scoping and Merkle integrity are complementary: the Merkle structure is what _enables_ verifiable partial views. This is the security payoff and a distinctive property.]

= Distribution and Replication <sec:distribution>

== Layers Are Replication <sec:layers-replication>

#todo[The stack model already _is_ replication: a write-through mid-layer is a live replica (@sec:layer-roles), so `S3 | S3 | neo4j` already runs a backup. Caching, redundancy, and replication are one mechanism here. Make this the framing for the section.]

== Convergence as Set Union (CRDT) <sec:crdt>

#todo[From the foundation paper §Distributability. Idempotent writes + content-addressed ids make a universe a join-semilattice; two replicas converge by union, regardless of partition order — a CRDT (@shapiro2011crdt, @bftcrdtmerkle). Sync = exchange of ids + transfer of missing claims (read-through across replicas). The one non-trivial bit is marker reconciliation (branch heads): resolved by minting a head claim over both heads (@sec:single-head). Federation = union of universes → multi-root RG.]

= Conformance <sec:conformance>

#todo[RankeDB builds on the foundation paper's ADT reference library (Go, soon Python), adding the server, the storage-layer adapters, and the admin layer. Conformance here is _adapter conformance_: any storage-layer adapter must satisfy the content-addressed contract (@sec:layer-contract) and declare its query capability; give the adapter test battery. ADT-level conformance — serialization determinism, id chains, closure/scope/prune semantics — is inherited from the foundation paper's binary conformance suite; reference it here rather than restate it.]

= Related Work <sec:related>

#todo[Engine-flavoured prior art only; the foundation paper carries the conceptual prior art (provenance vocabularies, TMS, archival theory). Cover, briefly: Datomic (@hickey2012datomic) and Fluree (@fluree) as immutable stores; TerminusDB (@terminusdb) as a versioned graph; IPFS/IPLD (@ipfs) and git as content-addressed Merkle stores; restic/borg/Perkeep as CAS backup systems (use case 3 precedent); SPADE and Quit Store as split-store / git-backed provenance engines; Neo4j and FalkorDB as the graph engines used as layers; the tiered-storage / cache-hierarchy literature for the stack model. The distinctive composition: a pluggable stack of content-addressed stores whose ground layer is the source of truth and whose upper layers serve as cache, redundancy, or query capability.]

= Serving the Use Cases <sec:serving>

#todo[Mirror the foundation paper's 'Discharging the Desiderata', informally — prose, no theorems. Revisit the design goals G1–G9 (@sec:goals) and show the architecture meets each:
- G1–G2 storage agnosticism, easy adapters ← the minimal layer contract (@sec:layer-contract).
- G3 composability ← the pluggable, ordered stack (@sec:layer-contract, @sec:layer-roles).
- G4 replicability ← read/write-through plus a full `verify` filling a complete layer (@sec:through, @sec:verify).
- G5 query interface and bounded reads ← REST/GQL (@sec:query) + progressive disclosure (@sec:disclosure).
- G6 access control ← server-enforced scope over reads and writes (@sec:scope-enforce) + verifiable partial views (@sec:partial-views).
- G7 key lifecycle ← contributor-replacement claims, enforced at write (@sec:service-auth).
- G8 verification on demand ← `verify` at chosen depth (@sec:verify).
- G9 time-stamp witnessing ← publishing the head hash to a timestamp authority (@sec:markers); since the head commits to the whole closure, one external timestamp attests the archive's full content as of that moment.
Note a free consequence, not a goal: concurrency safety — content-addressing makes concurrent claim writes idempotent and order-independent, leaving only the single archive pointer to sequence (@sec:single-head); independent servers fork and reconcile by union (@sec:crdt).
Then one line per named use case (institutional record = verify + witness; software provenance = bulk claims + attribution; backup = add a redundant layer; personal archive = portability + semantic reading + progressive disclosure). Keep it demonstration, lighter than the foundation paper's proofs.]

= Conclusion <sec:conclusion>

#todo[Tie back to the epistemological bridge (@sec:epistemology-architecture) and the design goals (@sec:goals). The architecture is a composition of established parts — content-addressed storage, cache hierarchies, signature-based identity, CRDT merge — arranged so that the ground store holds the claims and every layer above it is a rebuildable derivation — cache, redundancy, or interpretation. The same primitives carry the opaque end (backup) and the rich end (second brain). We invent nothing; we compose.]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
