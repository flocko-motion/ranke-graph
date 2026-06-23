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

The foundation paper proposes an ADT built around the abstract idea of 'attributed claims'. 
This paper takes that as given and settles what an abstract type can leave open but a running store cannot: how the claims are indexed for query, and whether their bytes still open in thirty years. This paper specifies RankeDB, a reference database service that stores and serves *Ranke Archives* as defined in the foundation paper. It proposes an 
architecture, a modular persistence stack, read and write paths, a query model, and an authentication model. 

*Formats outlive products.* The foundation paper is deliberately format-agnostic: its ADT stores bytes under an encoding tag and cares nothing for which. A store meant to last decades must care — what a format _is_ decides whether its bytes still open. Services are sold or shut down; open, widely-implemented formats endure (@sec:use-cases). Memory institutions reach the same conclusion from the other side: the Library of Congress publishes sustainability assessments and a recommended-formats list (@locformats) spanning hundreds of formats — text, image, audio, moving image, archive — favouring the open and well-documented. RankeDB keeps the ADT's indifference in the store and adds an opinion above it (@sec:atomic): preserve originals as given, with generic-format extracts beside them.


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

#todo[Dig deeper into the Library of Congress "Recommended Formats Statement" and "Sustainability of Digital Formats" — an independent, institutional study of the same format-longevity question and strong corroboration for this section. Cite it; note SQLite's place on their recommended list when storage adapters are discussed (@sec:atomic).]

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
- *G2 — Thin adapters.* Supporting a new persistence backend is easy to implement.
- *G3 — Composability.* Persistence composes from mixable, layered backends.
- *G4 — Replicability.* Copying, replicating, and backing up an archive is cheap.

_Database Access._
- *G5 — Query interface.* The archive is queryable through filters and a result limit.
- *G6 — Access control.* A caller-supplied scope is enforced for both reads and writes.

_Content Verification and Witnessing._
- *G7 — Verification on add.* The validity of any contributions is automatically verified on addition and supports key rotation, revokation, or expiration.
- *G8 — Verification on demand.* Archive integrity is checkable on demand, at a depth the caller chooses.
- *G9 — Time-stamp witnessing.* Prove externally that the archive's entire content existed at a given moment.

The database knows service accounts, their access rights, persistence stacks and Ranke Archives as content; *non-goals*, left to the application layer, are user and identity management, user access policy, consensus or truth arbitration, and further application logic. The architecture (@sec:architecture) is built up to meet G1–G9 capability by capability — demonstration rather than proof.


= Architecture <sec:architecture>

A Ranke Archive consists of claims; each claim is persisted in content-addressed storage, and the content bytes it carries are stored content-addressed too. The fundamental building block of the system is therefore the storage of a single claim.

A *claim* is an attributed record — a node bearing a type, an encoding, a creation time, the hash of its content, and a set of edges to the claims it was derived from — addressed by its id, $op("id")(v) = "Sign"(H(S(v)))$: a signature over the hash of its canonical serialization, so the id fixes both the record and its author (foundation paper §Primitives). Its content bytes are held separately, addressed by their own hash and size.

```
Claim — a node with its edges; immutable, content-addressed

  id()            → Id            its content address
  node()          → Node          its own data: type, encoding, created-at, content hash + size, pubkey
  edges(…filters) → Edge[]        references to the claims it derives from — its provenance
  contributor()   → Contributor   the claim that attributes and signs it
  encode()        → bytes         canonical serialization — the bytes the store persists by id

  ...                             closure materialization, validation
```

The edges make the claims a graph. The *closure* of a claim is the claim together with every claim reachable along its edges — its full provenance, back to the initial nodes (foundation paper §Closures). A claim carries meaning only with its closure: a single id recovers a whole closure, and a complete, mergeable state is always one.

All claims of a closure (that includes their content bytes) are stored in a common *Universe*. Any number of closures can 

We define the interface of a storage adapter as:

```
Universe — a storage adapter; bulk and content-addressed

  getClaims(ids: Id[])             → Claim[]    positional; a missing id fails the call
  putClaims(claims: Claim[])                    idempotent
  hasClaims(ids: Id[])             → bool[]     presence; drives delta sync

  getContents(refs: ContentRef[])  → bytes[]
  putContents(blobs: ContentBlob[])             idempotent
  hasContents(hashes: Id[])        → bool[]

  ...                                           copy/merge, streaming, lifecycle — derived from the above
```

These six bulk primitives are the architectural contract. Every derived operation folded into the `…` — store-to-store copy and merge (the basis of stacking and replication), a streaming read for large content, lifecycle, and single-item wrappers — ships with a shared default built on the six, so a backend inherits the lot for a fast start and reimplements one only when a worthwhile speedup justifies the work. The reference library provides these defaults with filesystem and in-memory adapters in its `adapter` package, and renders the contract as a Go interface (Go now, Python next).

#todo[Lead. This chapter builds the engine up the way the foundation paper builds the data structure up: start from the atomic store, then add one capability at a time, discharging a design goal (@sec:goals) at each step. Spine — atomic store → stack → replicate → compose → archive → access → verify and witness.]

== The Atomic Store <sec:atomic>

A RankeDB instance reduces to one storage engine behind one small API: store and fetch bytes by key.

#todo[Show the atomic write — hash content, serialize, sign, store — and the filesystem adapter inline (~a dozen lines) as the G2 proof. Claims, ids, and closure are defined at the chapter opening; don't repeat them here. Note the serialization choices once (CBOR Deterministic, IPFS multihash, Ed25519).]

_Discharges G1, G2._ #todo[G1 — the engine assumes only a store of bytes addressed by a key; anything from a USB stick to Amazon S3 qualifies. G2 — that API _is_ the adapter contract, so a new backend is those three calls; show the filesystem adapter inline (~a dozen lines) as proof the contract is tiny.]

#todo[What the store holds, opinionated defaults (fold former §Default Type Vocabulary and §Generic-Format Extracts here): the `source/*` and `derivation/*` default subtypes, MIME-style encodings, and the practice of keeping a generic-format extract beside each original. Mark *[FREE / default]*.]

== Stacking <sec:stack>

One engine becomes a _stack_: layers ordered ground-to-top, the ground authoritative, upper layers caches.

#todo[Define the stack and its read paths: read-through (a miss falls to the next layer down and fills on the way back), write-through (or write-ground-then-fill). Cache coherence is trivial — content-addressed bytes are never stale, eviction is always safe, and any upper layer drops and rebuilds from below. The ground is the source of truth because read-through terminates there.]

#todo[Figure: vertical stack diagram (adapt drawio/layers.svg) — ground = truth at the bottom, caches above, read-through arrows down on miss filling up, write arrows. Two example stacks side by side (`S3 | S3-local | neo4j`, `S3 | local-FS | in-memory`).]

_Discharges G3 (composability)._

== Replication <sec:replication>

A _complete_ layer, once filled, is a full live copy of the archive — so durability is a matter of adding one.

#todo[A complete layer added to the stack fills by write-through, or in one pass by a full read-through (the same sweep `verify` uses, @sec:verify). Backup, replication, and portable export then collapse to one operation — add a layer: a remote store, a second region, a detachable SQLite file. Redundancy is one line of configuration.]

_Discharges G4 (replicability)._

== Composition <sec:composition>

Layers need not be whole or single.

#todo[Partial layers: each declares a `max_content_len`; larger writes fall through, so a Cypher/GQL layer can hold only small claims (~8 kB) while blobs live below. The complete-ground rule: one layer accepts content of any size, so the stack loses nothing. A complete layer may be _composite_ — several backends behind a routing layer, complete as a system — which admits geographic distribution and read-scaling. Note this as a direction; the reference implementation keeps a single ground.]

== The Archive <sec:archive>

The stack holds the universe; an _archive_ adds the one mutable thing.

#todo[An archive is its universe (in the stack) plus a single mutable hash $B_h$, the id of its current branch table (foundation paper §Archive). Branches, heads, and the branch table are themselves claims in the universe; the admin layer (PostgreSQL, in the reference implementation) holds only accounts, the archive registry (name → $B_h$ → stack), stack configuration, and rights. Reads and writes name a *branch*, resolved through $B_h$ to a head; raw-id access is operator-only.]

#todo[Concurrency: the owning server is the sole *sequencer* — it advances $B_h$ by compare-and-swap, so the archive keeps a single head. Concurrency-safety is then free: content-addressing makes claim writes idempotent and order-independent; only the one pointer is sequenced. Two servers advancing the same archive fork, and reconcile by union (a CRDT join; foundation paper §Distributability).]

== Access <sec:access>

With the archive in place, the access goals layer on.

#todo[*Query interface (G5).* A REST API on every stack — closure/provenance reads, writes, `verify`, each carrying a scope; a `/gql` endpoint when a Cypher/GQL-capable layer is in the stack. Every read resolves to $"closure"(h, cal(U))$ under scope and prune in one read-through sweep, exposed through filters and a result limit so any read is bounded. Coarse-first progressive disclosure is then an application strategy over filters and limit, not a built-in. _Discharges G5._]

#todo[*Access control (G6).* A scope supplied by the application and enforced by the server bounds reads and writes — a base `allow-all`/`deny-all` plus ordered wildcard exceptions over field/edge names and types. The scope is bound to the authenticated account, not chosen at request time; no elevation path. Verifiable partial views: out-of-scope references appear as hash-only stubs, Merkle-verifiable without disclosure. _Discharges G6._]

#todo[*Key lifecycle (G7).* Rotation, revocation, and expiry as contributor-replacement claims; the server refuses new claims signed by a retired key, forward-only — past claims stay valid. The application sets policy (who may retire whom); the engine enforces. _Discharges G7._]

#todo[Authentication: a connecting service authenticates with a shared secret (token/JWT) for access; claim signing stays with the application, the engine only verifies signatures at write. Two roles, kept separate.]

== Verification and Witnessing <sec:verify>

The build closes with two checks — one internal, one external.

#todo[*Verification on demand (G8) — comes cheap.* A generic server operation, no per-backend work: read-through the closure of $h$ and recompute the id chain at a chosen depth — completeness (every reference and blob present), record correctness (signatures and id chain), or full content (rehash every blob). Tiered cost; warms caches as a side effect. _Discharges G8._]

#todo[*Time-stamp witnessing (G9) — likely a plugin.* Publish the head hash to an external timestamp authority (RFC 3161); because the head commits to the whole closure, one timestamp attests the archive's full content at a moment. Probably a plugin interface — state what the reference implementation provides and leave the rest open. _Discharges G9._]

= Conformance <sec:conformance>

#todo[RankeDB builds on the foundation paper's ADT reference library (Go, soon Python), adding the server, the storage-layer adapters, and the admin layer. Conformance here is _adapter conformance_: an adapter satisfies the content-addressed contract (@sec:atomic) and declares its capability and `max_content_len`; give the adapter test battery. ADT-level conformance (serialization determinism, id chains, closure/scope/prune semantics) is inherited from the foundation paper's binary conformance suite.]

= Related Work <sec:related>

#todo[Engine-flavoured prior art only; the foundation paper carries the conceptual lineage. Datomic (@hickey2012datomic) and Fluree (@fluree) as immutable stores; TerminusDB (@terminusdb) as a versioned graph; IPFS/IPLD (@ipfs) and git as content-addressed Merkle stores; restic/borg/Perkeep as CAS backup; SPADE and Quit Store as split-store / git-backed provenance; Neo4j and FalkorDB as graph engines used as layers; the tiered-storage / cache-hierarchy literature. Distinctive composition: a pluggable stack of content-addressed stores, ground = truth, upper layers cache / redundancy / capability.]

= Conclusion <sec:conclusion>

#todo[The engine is built, not asserted: from the atomic store, each added capability discharges a goal, through G9. A composition of established parts — content-addressed storage, cache hierarchies, signature identity, CRDT merge — arranged so the ground store holds the claims and every layer above is a rebuildable derivation. The same primitives carry the opaque end (backup) and the rich end (second brain). We invent nothing; we compose.]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
