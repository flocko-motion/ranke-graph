#import "../shared/template.typ": *
#import "@preview/wrap-it:0.1.1": wrap-content

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
  abstract: [*RankeDB* is a reference database service for the *Ranke-Graph*, the provenance-first data structure the foundation paper defines as an abstract data type: 
a graph of immutable, attributed claims, each carrying its own derivation and independently verifiable. 
Taking that contract as given, this paper specifies how such a graph is persisted, composed, queried, verified, and bounded for access, without weakening any guarantee the structure already proves. 
Its guiding principle is _agnosticism by adapter_: every external technology the engine relies on is reached through a contract kept small enough that no implementation is ever locked in. 
Storage is the clearest case: persistence rests on nothing more than a content-addressed store of immutable bytes, so any store of keyed bytes can serve as the ground, and deduplication, cheap forking, and replication follow from content addressing as consequences rather than features. The architecture is built up capability by capability: demonstration rather than proof.],
)

#block(
  stroke: 1pt + black,
  fill: luma(240),
  inset: 1em,
  radius: 3pt,
  width: 100%,
)[
  #text(weight: "bold", size: 1.05em)[Work in progress.] #h(0.4em)
  This document is an early working draft. Its architecture, scope, and details are under active revision and may change substantially; some passages are incomplete, provisional, or already superseded by later sections. Please do not cite.
]
#v(0.6em)

= Introduction <sec:introduction>

The *foundation paper* (@metzgernoel2026rankegraph) defines the *Ranke-Graph* as a concept and an abstract data type (ADT), built around a single unit: the *claim* — an attributed record of content, added by a contributor at a stated moment and citing the sources it derives from. Where a conventional database consolidates its sources into one current, contradiction-free state and overwrites it as understanding changes, a Ranke-Graph keeps the whole history of claims, disagreements intact — each immutable, each attributable to an author and a time, each independently verifiable. Its aim is preservation with full provenance, for the long term and across applications.

This paper specifies *RankeDB*, a reference database service that serves and manages Ranke-Graphs: taking the ADT as given, it proposes how such a graph is persisted, composed, replicated, queried, verified, and bounded for access. What follows is the architecture that answers those questions.

Data in an organisation, or a personal life, is scattered. An enterprise spreads it across separate services' data, artifacts on file servers, source in repositories, CI logs, access logs, documents, specifications, and correspondence; a household, across messengers, mailboxes, call logs, cloud photo albums, and files on local and remote drives. Each store keeps its slice in its own format — some open, like JPEG or plain text, much of it locked inside the application that wrote it.

Both applications and formats have finite lives: products are discontinued, sometimes overnight, and a format outlives its tools only if it is open and widely implemented. So the more services one depends on, the more data loss one should expect — and backups guard only the bytes: a copy is unreadable without the application version that wrote it, and rarely searchable across the application-specific shapes it preserves.

A Ranke-Graph sets out to bridge these stores. Conventional databases stay the right tool for fast persistence in live systems; a Ranke-Graph extends what they hold along two axes. In *time*, it keeps data immutable in a generic, application-independent, human-readable form that can outlive the tool that wrote it. In *breadth*, it aims to draw the scattered silos into one searchable store, where each fact carries its history — who recorded it, when, and citing what.

== Use Cases and Desired Properties <sec:use-cases>

Four use cases make the idea concrete; between them they name the properties the system must provide:

+ *Institutional Record.* An immutable, provably timestamped record of who did what and when — approvals, audits, sign-offs, operational decisions — that stands up to an outside auditor or a court. Each record is signed by its submitter, human or machine, sent automatically as the decision is taken and linked to the entities it concerns: employees, projects, customers.

+ *Software Provenance.* At release time a project's evidence is everywhere — repository snapshots, artifacts, test results, reviews, security scans, CVE triage — and a year on it is hard to reassemble. Branches are rewritten, repositories moved, history squashed; build logs expire on retention; the reasoning behind a CVE call survives only in some chat. A Ranke-Graph can bind these fragments to the release as one structured whole — a git snapshot, the CI logs, the developers' decision notes.

+ *Unified Accessible Backup.* A backup for arbitrary bytes — documents, business records, server snapshots — that stays searchable. Content addressing deduplicates identical files on its own, and an arbitrary stack of replicating storage layers keeps a copy on each, written through automatically; every item enters labelled, timestamped, and provenance-annotated, so the whole version history stays queryable and verifiable.

+ *Personal Archive.* Photos, email, and chats freed from vendor silos into one open, format-agnostic store: small, shareable adapters — Google Photos, IMAP mailboxes, cloud storage, chat histories — pull the data in, and generic formats can keep it openable for a lifetime, in applications not yet written. Linked to an AI agent, local or in the cloud, it could become a searchable memory — a 'second brain'.

All four point at one quality: a Ranke-Graph stores data as history. Every entry carries its provenance and its author, perhaps predecessors, and may reference others. Where a conventional database holds the state of a single application, a Ranke-Graph tries to hold the history and interrelation of data across many.

= Requirements <sec:requirements>

From the scope of intended use cases, and the fundamental ideas and guiding principles of the Ranke-Graph, we can now build the list of properties we require of an adequate server. We first recap the guarantees already inherited from the ADT, then extend them with the requirements that emerge from the intended use cases.

== Inherited Guarantees <sec:inherited>

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

These are given. What remains for the implementation — the requirements this paper is accountable for, and the architecture that meets them — follows.

== Guiding Principles <sec:principles>

The goal of the Ranke-Graph is to store data over a long timeframe, which requires us to revisit some of the typical trade-offs.
We should prefer maintainability and thus simplicity over performance. A system with a long lifetime *will* need refactoring, 
extensions, adaptations. A small and simple system beats a highly optimized but complex system in this discipline. 

For the same reasons we should be radically agnostic regarding the technologies used. The server should be minimal and build 
on using existing robust and open services - connected via simple adapters that make them replaceable. Minimizing the 
adapters surface keeps them small, generic and mainttainable. A minimal blob storaga adapter with just the three functions `Get(key)`, `Put(key, blobl)` and `Has(key)` can easily be realized with any storage solution from a USB Stick to a sophisticated Cloud Service. 


== Implementation Requirements <sec:requirements-impl>

From the above observerations emerges this list of requirements:

_Storage and Distribution._
- *R1 — Persistence agnosticism.* Run on a wide range of persistence backends, beholden to none.
- *R2 — Thin adapters.* Supporting a new persistence backend is easy to implement.
- *R3 — Replicability.* Copying, replicating, and backing up an archive must be simple and reliable.
- *R4 — Composability.* Persistence backends can be composed for redundancy, performance, or added capabilities.
- *R5 — Coordination.* Multiple servers accept writes to one archive and converge on a single authoritative state.
- *R6 — Deletion.* When law overrides the ADT's immutability, a claim may be deleted, but only in a documented, attributed way that records who removed it, when, and why, and leaves a verifiable gap.

_Verification and Witnessing._
- *R7 — Trustworthy timestamps.* Each claim's time is provable and its place in the total order fixed, neither open to reassignment.
- *R8 — Verification on add.* Every contribution is verified as it is added, so a valid archive remains valid.
- *R9 — Verification on demand.* Archive integrity is checkable on demand, at a depth the caller chooses.
- *R10 — Key lifecycle.* Signing keys are central to an archive's authenticity, so their rotation, revocation, and expiration are verifiably enforced by the service.
- *R11 — External witnessing.* Prove externally that the archive's entire content existed at a given moment.

_Access._
- *R12 — Filtered queries.* The archive is queryable through a conjunction of filters, with pagination and a result limit.
- *R13 — Multi-tenancy.* Each instance manages its own system accounts, separate from the user accounts of the applications built on it.
- *R14 — Access control.* A caller-supplied scope is enforced for both reads and writes, so the application layer can build fine-grained access control on top.


== Out of Scope <sec:out-of-scope>

Left to the application layer are user and identity management, user access policy, consensus or truth arbitration, and further application logic.

= Adapters and Contracts <sec:contracts>

Following the guiding principles stated above, a Hexagonal architecture (@cockburn2005hexagonal) seems to fit best. This architecture has a minimal core that expresses the pure business logic without any direct contact with external resources. Around that core is a small number of adapters, each defined as a narrow contract, each intentionally minimal, so that the technology behind it stays replaceable. 
At its centre, the core wraps the library that implements the Ranke-Graph ADT. The core adds the integration logic that connects the adapters to that library and implements the concerns the ADT leaves open: endpoints, access control, persistence, and contribution management. 

The combination and configuration of the adapters into a runable instance of ranke-db is done using a config file (@sec:configuration). Such a configuration specifies one single instance, the analog to a single Database within a e.g. Postgres service. We intentionally decided against a runtime configurable multi-instance, multi-tenant system to keep the technology simple and maintainable. A management layer for adminstering multiple such instances, configuring them, starting/stopping/monitoring them can be implemented on top of this.  

#[
  #show figure: it => grid(
    columns: (2fr, 1fr),
    column-gutter: 1.2em,
    align(center + horizon, it.body),
    align(left + horizon, text(size: 0.92em, it.caption)),
  )
  #figure(
    image("drawio/architecture.drawio.png", width: 100%),
    caption: [RankeDB as a hexagonal core wrapping the ranke-graph library: six independent adapter ports, each shown with the backends the reference implementation ships, and configuration entering as the launch artifact rather than a port.],
  ) <fig:adapters>
]

In the following sections we'll describe a few relevant details on how we implement the ADT, which is built on the core concepts of Claims (@sec:claim) as the atom of the Ranke-Graph, the Universe (@sec:universe), being the content-addressed space in which those claims are stored and the Branch Table Header (@sec:bth) that allows retrieving the graph from the Universe. Those ADT concepts are realized with the help of Blob Storage (@sec:blob) as a foundation for the Universe and the Sequencer (@sec:sequencer) for managing the Branch Table Header (BTH) under concurrent reads and writes. 

== The Claim as Atom <sec:claim>

A *claim* is the atom of the Ranke-Graph: a node with a small set of mandatory predefined fields as type, encoding, creation time, and the hash of its content bytes — together with the edges to the claims it references. Claims are addressed by their identity $op("id")(v) = "Sign"(H(S(v)))$, a signature over the hash of its canonical serialization (foundation paper §Primitives). 

The foundation paper defines an intentionally minimal set of mandatory fields. Our implementation choses to add two more fields, that are essential for the practical workings of this database implementation: 
- `valid_until` — on a *contributor* claim, beside its public key: claims with a `created_at` after that date don't pass verification and can thus not be added to the graph. This is the basis for a key rotation mechanism. 
the moment after which the engine accepts no further claims signed by that key (key lifecycle, @sec:verify).
- `delete_by` — on a claim born with a retention limit: the date past which its content may lawfully be erased (@sec:deletion).

Both are *[FREE]* extensions — the ADT neither requires nor forbids them, and a graph that omits them is still a Ranke-Graph — yet because each sits in the signed content, a claim's own signature attests its retention limit and a key's own claim attests its expiry; neither can be altered after the fact.

Operationally a claim exposes its identity, its node, its edges, and its contributor, and it encodes itself — `encode()` yields the exact bytes the store persists under `id()`, the bridge from claim to persistence:

```
Claim — a node with its edges; immutable, content-addressed

  id()                     → Id:string             its content address
  node()                   → Node                  type, encoding, created-at, content hash + size, pubkey, extensions
  edges(filters: Filter[]) → Edge[]                references to the claims it derives from — its provenance
  contributor()            → Contributor:Claim     the claim that attributes and signs it
  encode()                 → SerializedClaim:bytes canonical serialization — the bytes the store persists by id
  ...                                              closure materialization, validation
```

The edges make the claims a graph. The *closure* of a claim is the claim together with every claim reachable along its edges — its full provenance, back to the initial nodes (foundation paper §Closures). A claim carries meaning only with its closure: a single id recovers a whole closure, and a complete, mergeable state is always one.

== The Blob Store <sec:blob>

A claim, and the content it carries, live in one content-addressed store. Storing them reduces to a single thing: a *blob store* — three operations over immutable, keyed bytes.

```
Blob store — content-addressed; immutable

  put(key: Id, blob: bytes)             idempotent — a key's bytes never change
  get(key: Id)            → bytes       a missing key fails the call
  has(key: Id)            → bool        presence; drives delta sync
```

Each entry is keyed by its content address — a claim by its id, the content it carries by its hash — and the store interprets neither; to it both are opaque bytes under a key. Because keys are content addresses, a stored value cannot be stale: the key *is* the hash of the bytes, and bytes that did not produce it were never that claim. Any number of closures therefore share one store without coordination — identical claims collapse to a single key, and a claim present for one closure is present for all. Deduplication and sharing fall out of the addressing, not from any feature of the store.

This is the entire contract a backend must provide; the in-memory adapter that implements exactly these three operations (plus lifecycle) is 37 lines. Everything above them is convenience and performance.

== The Universe <sec:universe>

The reference library exposes a blob store as a typed *Universe* that reads and writes claims and content as records, decoding and encoding at the boundary, and adds the bulk reads and writes, lazy streaming of large content, and store-to-store copy and merge a working engine needs — none of it enlarging the contract. The lift is mechanical: the content operations *are* the blob primitives, the claim operations wrap them with decode and encode.

```
Universe over a Blob store — the default lift (NewBlobUniverse)

  getClaim(id: Id)                  → Claim    decodeClaim(get(id))
  putClaim(claim: Claim)                       put(claim.id(), claim.encode())
  hasClaim(id: Id)                  → bool     has(id)

  getContent(hash: Id)              → bytes    get(hash)
  putContent(hash: Id, blob: bytes)            put(hash, blob)
  hasContent(hash: Id)              → bool     has(hash)
```

`NewBlobUniverse` lifts any blob store into a full `Universe` this way for free; a backend reimplements one of these operations only when a native bulk or batch path (S3, SQL) runs faster. The shipped interface takes claims and content in bulk — `getClaims`, `putClaims`, … — so throughput comes from the adapter, never from a larger contract.

== Ranke Archive <sec:bth>

A *branch table* is the archive's index of named lines: each entry binds a name to a head, and a head is a whole Ranke-Graph — its closure, with all the provenance behind it. One entry names one entire graph. The table is itself a claim, so its revisions form a history the way claims do — each new table references the one it replaced — carrying its version history as its own provenance, never a side log. The foundation paper fixes that format (a `contribution/branches` claim with `contribution/branch` edges to each named head) and the archive $(cal(U), B_h)$ that wraps it (foundation paper §Branches, §Ranke-Archive). We don't restate it; we build it.

== Sequencer <sec:sequencer>

The implementation must supply one mechanism the ADT leaves open: the management of $B_h$. We call it the *Sequencer*. It owns the archive's single linearization point — the step at which a write becomes part of the current state. Because every claim is content-addressed, claim writes are idempotent and order-independent; $B_h$ is therefore the only value that must be serialized, and the Sequencer advances it by a compare-and-swap on a durable cell. $B_h$ is also the sole mutable value held outside $cal(U)$: all claims and branch tables are content-addressed and immutable, so this single reference constitutes the archive's entire mutable state. Its durability is consequently a correctness requirement — $cal(U)$ retains every claim, but without $B_h$ the current head, and thus the active closure, cannot be recovered.

The value the Sequencer advances to is itself an ordinary claim — the new branch-table head — and nothing about it is privileged: any contributor could mint one. Its authority comes only from being the claim $B_h$ points at, and only the Sequencer moves $B_h$, so in practice the server is the sole author of branch-management claims — and the engine enforces it, accepting head claims only from its own identity, to leave the role unambiguous. That is the consequence worth stating plainly: the server is a contributor like any other and so needs a private key of its own. It signs the head it mints once it admits the commit — which it does only when every claim absorbed is signed by a contributor already present in the closure. Two signing roles then sit side by side: application keys attest content, the server's key attests the commit (and through it the archival time of @sec:timestamp), and the engine never holds an application's key.

```
BranchTableHead — the durable cell the Sequencer advances

  load()       → Id  id of the current branch-table claim (none → empty archive)
  save(id: Id)       compare-and-swap to the new present
```

Because the loss or corruption of $B_h$ would be unrecoverable, the reference implementation keeps it as an append-only history rather than a single overwritten cell — every committed $B_h$ is retained. A head is sound only if its branch-table closure is fully present and verifies (@sec:verify); should a silent persistence failure leave the latest head pointing at a state that is not wholly durable, recovery rolls back to the most recent $B_h$ that verifies. Since $cal(U)$ only ever grows, an older head's closure was complete when committed and cannot have lost claims since, so rolling back costs at most the most recent unconfirmed writes, not the whole archive. Commit order secures it from the other side: a write makes its claims — and the new branch table — durable in the source of truth before the Sequencer advances $B_h$.

Keeping the sequenced step this small is where performance and redundancy come from. Since everything but the final commit is order-independent, a replica can prepare a whole side branch — many claims — warm its caches, and feed them into the source-of-truth universe, all off the critical path; merging that work into the main graph is then a *single* claim added at the Sequencer, one compare-and-swap. Two servers advancing the same $B_h$ fork and reconcile by union (a CRDT join, foundation paper §Distributability). The reference implementation keeps the plain single-Sequencer path, but the structure invites the prepared-branch optimization when throughput demands it.

A Ranke Archive composes the two — `Archive(universe: Universe, head: BranchTableHead)` — and its richer views (`Branch`, `BranchTable`, and their histories) are read-only projections over the claim chain, exactly as the typed `Universe` projects over the blob store. With the universe, the Sequencer that guards $B_h$, and the projections over them, the world is ready; the rest of the chapter is the engine that serves it.

#todo[Lead. This chapter builds the engine up the way the foundation paper builds the data structure up: from the archive and its Sequencer, add one capability at a time, each discharging a requirement (@sec:requirements-impl). Spine — storage layer → stack → replicate → coordinate → compose → verify and witness → query → access.]

== Storage Layer <sec:atomic>

A storage layer is an adapter on the content-addressed contract of @sec:blob — those few operations, nothing more — and that smallness is what makes the engine beholden to no technology. The minimal adapter is a few dozen lines: the in-memory backend is a `map` behind `get`, `put`, and `has`. So a new backend is a weekend's work, anything that stores bytes under a key qualifies — a `map`, a directory, a SQL table, an S3 bucket — and the reference library ships a range of them already, which turns "runs on anything" from a claim into a file listing. Performance is opt-in: a backend may implement the bulk and native paths of @sec:universe and declare the capability, while the floor stays the same few calls. _Discharges R1 and R2._

#todo[Show the in-memory or filesystem adapter inline (~a dozen lines) as the visible R2 proof; recap the serialization choices once — CBOR Deterministic, IPFS multihash, Ed25519 — pointing to the foundation paper rather than re-deriving.]

What a layer should *hold* is the engine's one opinion above the bytes, in a place the ADT deliberately keeps none. The foundation stores bytes under an encoding tag and is indifferent to which; a store meant to outlive its own software cannot afford that indifference, because the format decides whether the bytes still open in 30 years. So the default is to preserve each original exactly as received and keep a *generic-format extract* beside it — the same content re-encoded into a widely-implemented, well-documented format, the kind memory institutions converge on (the Library of Congress's recommended-formats and sustainability work is the reference, @locformats). Originals carry fidelity, extracts carry longevity; an application may keep one, the other, or both, so this is a default, not a rule — mark it *[FREE / default]*.

#todo[Detail the default vocabulary folded in here — the `source/*` and `derivation/*` subtypes and MIME-style encodings — and note SQLite's place on the LoC recommended list. A per-adapter `max_content_len` lets a size-limited layer hold only small claims while larger blobs fall through to a layer below — the partial-layer mechanism of @sec:composition.]

== Stacking Storage <sec:stack>

A single layer is the floor; a *stack* is layers ordered ground-to-top, the ground authoritative and every layer above it a cache. A read is *read-through*: it asks the top layer and, on a miss, falls to the next layer down, filling each layer it passed on the way back up, so hot claims migrate toward the top. A write is *write-through*: it lands in the ground — the source of truth — and populates the layers above. The ground is authoritative for one structural reason: read-through terminates there, so a claim absent from the ground is absent from the archive.

Cache coherence, the usual hard part of a layered store, is trivial here because the keys are content addresses. A cached blob cannot be stale — its key *is* the hash of its bytes, so the bytes either match the key or were never that claim — so eviction is always safe, and any upper layer may be dropped and rebuilt from the layer below with no invalidation protocol. A cache that cannot go stale needs no coherence.

#todo[Figure: vertical stack diagram (adapt drawio/layers.svg) — ground = truth at the bottom, caches above, read-through arrows falling on a miss and filling upward, write-through arrows. Two example stacks side by side, e.g. `S3 | S3-local | neo4j` and `S3 | local-FS | in-memory`.]

_Discharges R4 (composability)._

== Replicating Storage <sec:replication>

Replication is not a separate mechanism; it is what a *complete* layer already is. A layer that holds the whole archive, once filled, is a full live copy — so durability becomes a matter of adding one. A new complete layer fills either by write-through as fresh claims arrive or, in one pass, by a full read-through sweep — the same traversal `verify` uses (@sec:verify) — after which it tracks the archive for as long as it stays in the stack.

This collapses three operations usually built separately into one act. *Backup* is a complete layer kept off-site; *replication* is a complete layer in another region, filled and then live; *portable export* is a complete layer on a detachable medium — a SQLite file you copy and carry. Each is the same thing: add a layer. Redundancy is then one line of configuration rather than a subsystem, and because every layer is content-addressed, a copy verifies against the original by id alone, with no trust placed in the transport that carried it.

_Discharges R3 (replicability)._

== Coordinating Storage <sec:coordinate>

A single Sequencer is one writer. Coordination lets many servers accept writes to one archive without surrendering the single head that keeps its state unambiguous.

Each server runs as a *subsequencer*: it accepts writes locally and accumulates them as a side branch off the critical path — the prepared-branch path of @sec:sequencer — feeding the claims into the source-of-truth universe as it goes, so the only act left at commit is to mint one head. It then merges that branch up to the central Sequencer and rebases on the latest $B_h$ it returns. The central Sequencer remains the single linearization point; between merges the subsequencers diverge, and when two merge concurrently they fork into two heads that the next merge consolidates — additive reconciliation by union (a CRDT join, foundation paper §Distributability), so no write is rejected and none is lost. Because nearly all the work is local and parallel and only the brief merge touches the central point, write throughput scales out while the archive keeps its single head. The reference implementation runs one sequencer and leaves the hierarchy's depth — subsequencers beneath subsequencers — open as a direction.

_Discharges R5._

== Composition <sec:composition>

Layers need not be whole, and the ground need not be single. A layer may be *partial*: it declares a `max_content_len`, and a write larger than that falls through to the layer below — so a Cypher/GQL store can hold the small claims it indexes well while large blobs live beneath it. The stack loses nothing as long as one layer accepts content of any size; that *complete-ground* rule is the single invariant a stack must satisfy.

The ground that satisfies it may itself be *composite* — several backends behind a routing layer, complete as a system though no single backend is. That is the seam through which geographic distribution and read-scaling enter: a router over regional object stores, each partial, complete in aggregate. And it generalises, because a stack is itself a `Universe` (@sec:universe) — composition is closure under the interface, so a layer may be another stack, a partition that routes by a claim property (the erasability split of @sec:deletion is one), or a remote archive reached through a `rest` adapter, nesting without limit. The reference implementation keeps a single ground and notes the rest as the room the contract leaves.

#todo[Figure or worked example: a composite ground — `(S3-EU | S3-US) -> router` — beneath a `neo4j` index layer, illustrating partial layers and the complete-ground rule.]

== Deletion <sec:deletion>

Append-only is one storage choice, not a law of the system: the engine can erase a claim's content — bytes and all — and leave its structure to explain the gap. Two kinds of erasure call for this, and because they are different facts they are recorded differently.

_Planned_ deletion is intrinsic — a `deleteBy` date the claim carries in its signed content from creation, the retention schedule a record is born with (keep seven years, then destroy). It is a property of the claim, as immutable as the rest of it.

_Requested_ deletion is extrinsic. A later demand to forget a claim cannot be written into it — the claim is immutable — so the request is recorded as its own new claim: an erasure record that references the target and documents who asked and when. Forgetting thus becomes an event with provenance, not a silent edit.

Routing follows erasability. A _partition_ composer — itself a Universe over two child Universes, like any other composition — sends erasable claims (those carrying a `deleteBy`) to a mutable partition and the rest to an add-only one. Only a mutable-partition claim can be erased, by either route; a claim with no `deleteBy` is permanent by choice, and the add-only store never holds a claim it could not lawfully erase.

Mutability propagates upward: any layer above a mutable partition must itself be mutable, or an add-only cache would leak erasable data past its date. Each mutable layer runs a daily date-based purge — dropping a claim once its `deleteBy` has passed or an erasure record demands it — and since both triggers are themselves claims, every layer reaches the same verdict without coordination.

Erasure leaves a scar, by design. An edge that references a claim carrying `deleteBy` copies that date into itself — one hop, no cascade — so when the content is purged the edge remains and records that something was here and lawfully went. Verification reads the gap correctly: completeness (@sec:verify) holds when every reference is present or tombstoned, so erasure is never taken for corruption. It is the physical counterpart to the foundation's `contribution/prune`, which hides a claim behind an id-only stub; deletion removes the bytes and leaves the edge — both absence with an explanation.

_Discharges R6._

== Timestamping <sec:timestamp>

A claim asserts when it was made, and the engine keeps that assertion both ordered and bounded. One rule orders it and caps it from above: a claim may reference only claims of strictly lower `(timestamp, id)`. A short, server-witnessed transaction window bounds it from below. Together — the rule, the window, and the server's signature on each merge — they need nothing written into the store to mark time, and no persistent transaction record.

Two clocks, one soft and one hard. A claim's `created_at` is the contributor's self-asserted authoring time, carried in the signed content; it is _soft_ — forgeable, never trusted, and not the date of whatever the claim describes (a 2010 email ingested today is stamped today). _Archival_ time, when the archive accepted the claim, is _hard_, and it is not a separate field: it is the timestamp of the server-signed merge that first absorbed the claim. The contributor asserts; only the archive witnesses.

Ordering is `(timestamp, id)`, the id a universal tiebreak — so duplicate timestamps need no rule, and the order is total and deterministic by value.

The ceiling falls out for free: the merge is itself a claim under the rule, and it references the claims it commits, so each sits below the merge's signed time — nothing can be postdated past the server's real clock. The floor is where a transaction earns its keep. A write opens a transaction against the server, which returns an ephemeral token — a JWT or macaroon, _not_ a claim — carrying a floor (the server's clock at the open) and a short validity window (seconds to minutes). The client builds its batch offline, stamping each claim honestly against what it cites, and submits under the token; the server admits the batch only if every timestamp lies between the token's floor and its own clock at submission, then merges atomically and records that witnessed window in the signed merge. The token never enters the store — it is operational state, discarded at commit — so nothing transient is immortalised; what persists is the server's signed attestation that the batch was authored within `[t_open, t_commit]`.

The window also closes the one gap the rule leaves alone. A dangling root that references nothing recent has no lower claim to lift it, so monotonicity by itself could not stop it self-asserting a low `created_at` — only expose the lie beside the honest archival time. The transaction floor refuses it outright: root or not, every claim in a batch is bounded below by the witnessed `t_open`. Concurrency, by contrast, needs no guard: two writers produce two heads, which the next merge consolidates (contradiction by addition), so no write is rejected for conflict and none is lost.

The chain of signed merges is, by construction, a transparency log — each references the prior, each timestamped and signed, the shape of RFC 3161 timestamping or Certificate Transparency, falling out of "the head update is a claim." Verifying it is foundational, not the server's privilege: anyone holding the data re-checks a merge's signature, its chain to the prior merge, and monotonicity across the closure, offline. _Minting_ — witnessing the real time, signing the merge, advancing the head — is the server's job and the only part that needs its key.

Distinct from all of this is _height_: `height(c) = 1 + max` over a claim's references (roots at 0), a Lamport-style logical clock read straight from the DAG — causal depth, not chronology, and an index recomputable from structure rather than a primitive. An implementation may order by `(height, id)` where causal order is wanted, verifiable by recomputation.

_Discharges R7._

== Verification and Witnessing <sec:verify>

The build closes the trust story: contributions are checked as they are written, the whole archive is checkable on demand, and an external witness anchors it in time.

_Verification on add (R8)._ Every contribution is checked as it is written — its signature and id chain verified against its contributor's key before the merge commits. Key lifecycle rides the same check, and it is expressed entirely in claims, needing no addition to the foundation's schema. A key carries a `validUntil` beside its pubkey — a scheduled expiry after which the engine refuses new claims signed by it. Early revocation is the on-demand counterpart: a newer contributor _revision_ claim names the keys it retires with `expiry` edges (one revision can retire many at once), and may instead, or also, `supersede` a predecessor to continue the identity under a fresh key. A key's effective end is the earliest of its `validUntil` and any `expiry` edge pointing at it; validity is judged at the claim's witnessed time (@sec:timestamp), forward-only — everything signed while the key was live stays valid, and the contributor claim is kept forever as the verification anchor. A revision is admitted only when it carries a valid signature from a contributor authorized to manage contributors (@sec:authority); `expiry` and `supersede` are the engine's reserved reading over the foundation's open edge mechanism, not new schema. Because it is all claims, a server follows the `supersede` chain to the current revision on its own, advancing which identity it signs as without manual intervention, and the full key history is auditable and verifiable offline. The application sets policy (who may retire whom); the engine enforces. _Discharges R8 and R10._

#todo[This passage now answers two requirements — R8 (a contribution is verified on add) and R10 (key lifecycle: rotation, revocation, expiration). Split the key-lifecycle half into its own subsection discharging R10 when this chapter is tamed.]

#todo[Open detail: the precise authorization rule — which signatures may create, `supersede`, or `expire` a contributor, and how it chains to the create-contributor right (@sec:authority). To be specified with the contributor-rights model.]

_Verification on demand (R9)._ Integrity is checkable at any time, at a depth the caller chooses, as a generic server operation that needs no per-backend work: read through the closure of a head and recompute as much of it as asked. Three depths answer three questions. *Completeness* asks only whether every referenced claim and content blob is present — a `has` sweep, the cheapest. *Record correctness* re-canonicalises each claim, recomputes its id chain, and checks the signatures, proving the records authentic and unmodified. *Full content* additionally re-hashes every blob, proving the bytes intact down to the last byte of the largest file. Cost rises with depth and with how much of the closure the caller scopes in, and because the check reads through the stack it warms the upper layers as it goes — verification doubles as cache priming. _Discharges R9._

_External witnessing (R11)._ Verification proves the archive internally consistent; witnessing anchors it to the outside world. Publishing a head's hash to an external time-stamp authority (RFC 3161) records that the head — and, because the head commits to its whole closure, every claim beneath it — existed at that moment; two such anchors bracket everything between them in real time, regardless of any self-asserted `created_at`. The engine already keeps an internal transparency log for free — the chain of signed merges (@sec:timestamp) — so external witnessing is the independent, third-party overlay upon it. The reference implementation exposes it through a plugin interface: it ships one authority binding and leaves the rest to the deployment. _Discharges R11._

== Filtered Queries <sec:query>

A read is a *filtered query*: the closure of a head, narrowed by a conjunction of filters and capped by a result limit.

Filters are declarative *data*, not predicates in code — values that can be inspected, composed, and checked. The foundation paper fixes the fundamental filter vocabulary, a total order over claims (by `created_at`, then id), and the result limit; the reference evaluation is a linear scan over the closure that keeps the claims matching every filter and truncates in order. That naive query is deliberately simple, and it is the _verifiable reference_: RankeDB reimplements it over indexes for speed and must pass a shared query-conformance suite, so the fast path is measured against the simple one rather than trusted in its place.

Filters compose by conjunction only — _conjunctive monotonicity_: adding a filter can only narrow a result, never widen it, so for fundamental filters $F$ and any further filters $G$, $"result"(F and G) subset.eq "result"(F)$. A backend may implement a _superset_ of the vocabulary — for example GQL capabilities through a Cypher-capable layer — but a superset filter can only further restrict what the fundamentals admit; it can never re-admit what they excluded. Union is a different construct, not a combination of filters; where a backend offers it the shared floor no longer applies, and that boundary is kept sharp.

Because filters are data, a result is checkable even for a query the reference cannot itself evaluate. Split the query's filters into understood and not-understood; using only the shared vocabulary, verify that every returned claim satisfies every fundamental conjunct and that the result is a subset of the fundamental-only query under the limit. Verification is then a partial oracle whose strength scales with the number of fundamental conjuncts a query carries — a pure-superset query is checkable only as a subset of the corpus under the cardinality limit.

Membership is the robust guarantee, surviving any superset; ordering is fragile, since a backend that imposes its own ranking selects a different first-$N$ than the fundamental order. The contract follows the honest line: limit and ordering are fully verifiable for a pure-fundamental query; once a superset ordering is in play, verification drops to set membership and cardinality, not which $N$ survived the limit.

_Discharges R12._

== Access <sec:access>

What remains is to bound who may read and write — and to keep that bound separate from who *authored* what.

*Access control (R14).* A *scope* supplied by the application and enforced by the server bounds every read and write: a base posture — `allow-all` or `deny-all` — followed by an ordered list of wildcard exceptions over field and edge names and types. The scope is bound to the authenticated account, not chosen per request, and there is no path to widen it from inside a request; an application builds whatever role model it needs by issuing accounts with different scopes. Reads honour the scope without breaking verifiability: an out-of-scope reference is returned as a hash-only stub rather than dropped, so the visible subgraph still Merkle-verifies — the same shape as the foundation's pruned views — while the withheld content stays undisclosed. _Discharges R14._

Authentication is the other half, and deliberately not the same half. A connecting service authenticates with a shared secret — a token or JWT — for *access*; signing *claims* stays with the application, which holds the contributor keys, and the engine only verifies those signatures at write. Two roles kept apart: the access credential says which scope a caller may exercise, the contributor key says whose claim this is — and the server's own signing identity (@sec:sequencer), which attests commits rather than content, is a third, distinct again.

#todo[Draft capture — this section and the three that follow record the serving-and-deployment redesign: hexagonal core, the engine/server split, endpoints, configuration as launch artifact, the single-binary process model. It supersedes most of the *Infrastructure* chapter below: the orchestrator, control-plane, and topology material collapses into @sec:deployment, and @sec:config / @sec:secrets / @sec:rotation / @sec:authority / @sec:keyholder / @sec:tokens fold into @sec:configuration. @sec:access and @sec:engine-server now overlap and must be merged. The *Sequencer* (@sec:sequencer) still needs its own reframe: the branch-table head (BTH) is the _id_ (not a hash) of the current branch-table claim — the key without which $cal(U)$ is unreadable — and the sequencer is the adapter that advances it under concurrency without losing it; how it persists that state is the implementation's choice, not the contract's. To be reconciled paragraph by paragraph.]

== The Engine and the Server <sec:engine-server>

RankeDB divides into two layers along the mechanism/policy line. The *engine* is the foundation paper's reference library: it expresses a graph — claims, the operations over them, and the scope-and-prune mechanism (foundation paper §Scoping) — over the driven ports of @sec:blob and @sec:universe together with the sequencer (@sec:sequencer). It is identity- and tenant-blind: it produces a view from an indicator σ but never decides which σ a caller is owed. The *server* is RankeDB proper: it makes one graph engine a reachable, access-bounded, multi-tenant service — authenticating callers, binding each service account to a scope, routing to the universe a caller may reach, and assembling the whole from configuration. Embedding the engine in-process is the limiting case: a single owner, no other principal, hence no access decision to make and no server at all (@sec:deployment).

This is why access control is the server's and never an endpoint's: were it bound to a protocol, every new endpoint would be a fresh way around it. Authentication — credential to identity — varies by door and belongs to the endpoint (@sec:endpoints); authorisation — identity to scope, enforced on every read and write — is uniform beneath all doors and belongs to the engine. The scopes themselves are service-account configuration, provisioned once and effectively static; the fast-changing, per-end-user access an application needs is built on top, and stays out of scope (@sec:access).

== Endpoints <sec:endpoints>

An *endpoint* is a driving port: a client calls in through it. It is two adapters composed — a *transport* (the wire protocol) and an *authenticator* (credential to identity) — written *transport ⊕ authenticator* and chosen per endpoint: REST with a JWT, MCP with a macaroon, a local socket with the *anonymous* authenticator. The reference binding is REST over HTTP, with an OpenAPI contract from which a client and its documentation are generated *[FREE]*; MCP and MQTT are anticipated, not built. HTTP is the durable, ubiquitous default rather than a hedge — the protocol counterpart of the open, durable formats the longevity argument favours (@sec:longevity) — so it is committed to, not abstracted behind a swap-out port for its own sake. The variation that earns the endpoint port is the *consumers*: an application over REST, an agent over MCP, a device over MQTT, an operator over a local socket.

Every authenticator yields an *account* — JWT from a verified token claim, the anonymous authenticator from a configured default — whose grants live in the configuration; authentication varies by endpoint, authorisation is uniform beneath all of them (@sec:engine-server). One instance may expose several endpoints at once — different doors into one universe — and because the authenticator binds per endpoint, the doors may carry different trust: a local socket whose anonymous account is the owner (presence on the host is the credential — never a network port) beside a public REST door that demands a token. Serving every consumer of a universe through one multi-door instance is what keeps it a *single* sequencer: the alternative — an instance per consumer type — would split one universe across several writers and pull in the coordination of foundation paper §Distributability (requirement R5), the advanced case avoided by default (@sec:deployment).

== Configuration <sec:configuration>

Configuration is authored, not integrated, so it needs no adapter and admits no variation worth abstracting: it is the *launch artifact*, a single JSON document an instance reads to assemble itself. A value in it is either a literal or a *reference* — `vault(name)`, resolved from a configured secret store, or `env(VAR)`, read from the environment — so a configuration can be wholly secret-free, every credential resolved at launch from outside the file. The one credential that cannot indirect is the secret store's own, which a literal (encrypted, below) or an `env()` covers; secret-zero collapses to that single root.

Encryption follows content, not policy. A reference-only file holds no secret and may be plaintext — committable, reviewable, the production default; a file carrying an inline literal secret is age-encrypted, its key supplied at launch from a source the operator chooses (`prompt`, `stdin`, `env:VAR`, `file:path`), never as a literal on the command line. The tooling warns rather than forbids, and only where it matters — when an inline secret would be written unencrypted — naming the field and pointing at both remedies (encrypt, or move it to `vault()` / `env()`).

One library serves de/serialization (including age), validation, reference resolution, and editing. *Validation* is secret-free and offline — schema and semantics only, so a configuration can be authored and checked without reaching any backend — while *resolution* (fetching references, connecting) happens only at launch. The runtime that loads a configuration and the tooling that authors it are the same library, and indeed the same binary: `ranke-db`, with `run` to serve and `config` / `tui` to author — so the build that validates on write is, by construction, the build that loads on run, and no version can drift between writer and reader.

== Deployment <sec:deployment>

A `ranke-db` instance is one process serving one configuration. The process boundary is the design, not an accident of packaging: it hands supervision to the operating system, which an in-process design cannot match. A hung instance can be killed — a Go goroutine cannot be — memory and CPU are accounted per instance, restarts are independent, and a listening socket can be handed in by the platform (socket activation). Supervision is therefore the platform's — systemd, a container runtime, a scheduler — and the instance carries no runtime dependency on any control plane: it reads its configuration and serves. The process boundary is also the isolation boundary: an instance holds only its own configuration's secrets and backends, so a compromise reaches no other tenant.

This yields a ladder of deployments over one set of building blocks: *embedded* — the engine library linked in-process, no server (@sec:engine-server); *standalone* — one `ranke-db` instance, configure and serve, supervised by the platform; *many* — independent instances, one universe each or several universes to a process, supervised the same way. Two things are deliberately *not* part of RankeDB. A *gateway* — a single public endpoint with TLS and routing — is mature, independent infrastructure placed in front (a reverse proxy), never built here. An *orchestrator* — a console for editing configurations and launching instances — is an application built on RankeDB's own surfaces (the configuration library, the management interface), buildable later precisely because no instance depends on it, and not a component of the database. The boundary holds because nothing inside reaches out for either.

= Infrastructure <sec:infrastructure>

#todo[Capture chapter — collects the deployment and operational exploration (topologies, secrets, keys, authority, the air-gapped keyholder, delegation). Mostly deployment detail rather than core architecture; refine, trim, or relocate downstream once the engine chapter settles.]

The architecture is one design; how it is deployed is a separate and free choice. The same mechanisms — the universe stack, the Sequencer, content-addressed claims — run unchanged from a single process on a laptop to a distributed fleet with an air-gapped key authority. The topology is configuration, not a redesign. This chapter captures the shapes RankeDB can take and the operational concerns they raise: secrets, keys, and the authority that issues them.

== From one node to a fleet <sec:topologies>

A single server is the whole system collapsed into one process: it is the Sequencer, holds one long-lived key, and runs forever once enabled. A fleet is the same architecture with the roles spread out — a central Sequencer and replicas that prepare work off the critical path and merge it up in a single commit (@sec:sequencer, @sec:coordinate). Concurrent commits simply fork into two heads that the next merge consolidates, so scaling out never costs a rejected write or a lost update. One scales by adding replicas, never by switching designs; the single-server case is just the fleet with no replicas.

#todo[Figure: the three shapes side by side — single node; central Sequencer + replicas; distributed central-protection (isolated central, user-facing replicas).]

== Configuration and assembly <sec:config>

A running instance is defined entirely by a *configuration*, and the configuration is itself read through an adapter — Postgres is only one way to hold it, alongside a YAML file or a flat directory. It is not passive storage: it is the assembly that binds the other adapters into a system — which storage layers compose the stack, which secret store holds the keys, which contributor the sequencer signs as, which archives exist and who may reach them. Given a configuration the server instantiates those adapters and runs, so *launching a config is launching the service*. This completes a symmetry of three pluggable adapter classes: *storage* (where claims live), the *secret store* (keys and credentials), and the *configuration store* (the assembly itself). The one thing a configuration cannot describe is how to reach itself, so that lives outside as a minimal bootstrap directive — _use config adapter X with arguments Y_ — from which the server loads the configuration and constructs all the rest. That directive is tiny and can be secret-free (a file path, or a connection string authenticated by platform identity rather than an embedded password), which makes the server binary generic: the same executable everywhere, pointed at one config. With file-based adapters throughout, an instance is a single process with no external dependency; Postgres, a vault, and object storage enter only when a deployment asks for them. And the configuration store composes like the rest: a _partition_ adapter can mount one child for server settings, another for accounts, another for the archives and their stacks — the same Composite pattern that stacks storage layers, since every adapter class is closed under it.

== Secrets and keys <sec:secrets>

Connection details and private keys never live in the control-plane database; Postgres holds only *references* to them. The secrets themselves sit behind a *secret-store adapter*, a sibling of the storage adapters with the same capability-declaring shape: `get(ref)` for credentials and `sign(keyRef, digest)` for keys, with a `file` adapter as the dumb baseline for tests and single-node, and Vault, OpenBao, or a cloud KMS as adapters that sign *without ever exposing the key*. There is no single signing key: each Ranke Archive configures its own server-side contributor, so `keyRef` selects that archive's identity, and a server serving many archives holds none of them — it asks the store to sign.

#todo[The `SecretStore` interface and capability declaration; optional dynamic short-lived backend credentials (Vault minting ephemeral database or object-store users); secret-zero solved by platform identity (Kubernetes ServiceAccount, cloud IAM role), never a stored password.]

== Key lifecycle and rotation <sec:rotation>

A contributor claim carries a `validUntil` beside its pubkey (@sec:verify): the key may sign new claims until that date, after which the engine refuses them — forward-only, the claim itself kept forever as the verification anchor. This makes *short-lived* keys practical. The strongest form holds the key only in memory: a server requests its key at startup, never writes it to disk, and requests a fresh one on every restart; the new-key contributor claim *disables* the prior, so the server's identity is a chain of session keys, at most one live at a time. Rotation splits cleanly across the two channels already present — the public contributor claim propagates to every replica through ordinary read-through, while only the private key needs the secret-store side-channel — and a head is valid only if its key was live at the claim's witnessed time, checkable offline.

== The authority hierarchy <sec:authority>

Authority forms a three-tier chain, a certificate hierarchy expressed entirely as claims. A *super admin* — the initial node, the archive's founding identity — holds the right to create contributors and is used rarely: to enable a server once, or to revoke it. A *keyholder* it enables mints and rotates the working keys. A *sequencer* uses those keys to mint heads but holds no power to create others, and *replicas* hold only ephemeral session keys. A tier is defined by one thing: whether it holds the create-contributor right, the single capability anchored at the database level — everything finer is application scope (@sec:access). Because that right is carried in signed claims chaining back to the initial node, the archive describes its own authority structure, auditable and verifiable offline. Exposure runs opposite to authority: the more a node can do, the less it is reachable.

#todo[The bootstrap sequence in full: the admin enables a server by committing a contributor claim bearing its pubkey and a new $B_h$ referencing it; before that the server can only accept fully-signed external commits, after it self-mints. Two write modes — server-minted (the normal path) and externally-fully-signed (bootstrap, and the standing admin escape hatch).]

== The air-gapped keyholder <sec:keyholder>

Splitting the keyholder from the sequencer is what lets the dangerous authority leave the network entirely. Minting keys is periodic, so the keyholder need not serve requests: it wakes on a schedule, mints the next short-lived keys, *pushes* the public contributor claims into the archive and the private keys into the secret stores, and goes dark — push-only, non-addressable, air-gapped or time-gapped as the deployment wants. The create-contributor authority then has no inbound attack surface at all, while the online sequencer holds only short-lived, non-minting keys. It is the offline-root-CA pattern made operational: scheduled issuance rather than a yearly ceremony. The keyholder stays one-directional by keeping its own issuance ledger — what it last minted — so it never needs to read the live archive; and its downtime is not the archive's, since the sequencer runs on its current key until `validUntil` and need only receive the next overlapping batch before then. The one dial is how often the air-gapped box wakes against how long its keys live.

== Transactions, tokens, and delegation <sec:tokens>

A write is wrapped in a transaction whose token is a *stateless* credential — a macaroon or an HMAC-signed token, verified by signature against the secret store's key rather than by lookup. It therefore needs no table in Postgres and survives both restart and cluster failover: any node holding the key validates a token any other issued. The token carries a floor (the server's clock at the open) and a short validity window; at commit the server admits the batch only if every timestamp falls within it, witnessing that the work was authored in `[t_open, t_commit]` (@sec:timestamp). Retry is safe and the client's responsibility — content-addressing makes the whole transaction idempotent — and a lapsed window simply means rebuilding it with fresh timestamps.

#todo[*Delegation — a direction, not the reference implementation.* Where a central server must be shielded from traffic, macaroons let it witness coarsely and rarely: it issues a long-window token to a replica, which *attenuates* it — caveats only narrow — into per-user tokens. The central-witnessed time bound then holds without trusting the replica at all; precision (window width) trades against central load. The subsequencer of @sec:coordinate is this token carrying a height or branch scope.]

== Cloud and operations <sec:cloud>

#todo[The managed-building-block deployment: managed Postgres as the control plane, object storage as the durable ground, a KMS or Vault as the secret-store adapter, an optional managed graph database as a Cypher-capable layer. The distributed central-protection shape: central Sequencer and keyholder network-isolated, user-facing replicas in front. The operational shell — container images, compose files for single-node, orchestration manifests for a fleet, run scripts — and how a stack's composition (@sec:composition) maps onto it.]


= Data Longevity <sec:longevity>

#todo[Reframe as user-facing guidance: a recommendation on _how to use_ the system (favour durable, open formats), not an engine property. Consider retitling (e.g. "Choosing Durable Formats"). Tie the SQLite note back to the storage adapters at @sec:atomic.]

Storing data longer than the typical life cycle of an application or single project requires the data to be *available* after that life cycle
and *readable* after the original application or service is discontinued. This is a challenge that libraries and archives traditionally face
and for which they developed strategies.

#wrap-content(
  [#figure(
    table(
      columns: 3,
      align: (left, center, center),
      inset: (x: 0.8em, y: 0.35em),
      stroke: 0.5pt + gray,
      table.header([*Format*], [*Introduced*], [*Standardised*]),
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
    caption: [Introduction and standardisation years for common open formats.],
  ) <fig:formats>],
  [
    Longevity rests on an asymmetry between products and formats. Services are short-lived, but fundamental formats endure — most in daily use for years before any standard ossified them, and still readable long after the tools that produced them are gone. The more open and widely implemented a format, the longer its life: the gap between introduction and standardisation — CSV waited 33 years — shows the working form long preceding the formal one, and WAV's base format endures with no formal standard of its own.

    Mature players read every codec ever shipped, so even video, for all its churn, stays openable decades on. Memory institutions reach the same conclusion: the Library of Congress maintains recommended-format and format-sustainability guidance favouring open, well-documented formats for long-term preservation.
  ],
  align: right,
)

#todo[Dig deeper into the Library of Congress "Recommended Formats Statement" and "Sustainability of Digital Formats" — an independent, institutional study of the same format-longevity question and strong corroboration for this section. Cite it; note SQLite's place on their recommended list when storage adapters are discussed (@sec:atomic).]


= Conformance <sec:conformance>

#todo[RankeDB builds on the foundation paper's ADT reference library (Go, soon Python), adding the server, the storage-layer adapters, and the admin layer. Conformance here is _adapter conformance_: an adapter satisfies the content-addressed contract (@sec:atomic) and declares its capability and `max_content_len`; give the adapter test battery. ADT-level conformance (serialization determinism, id chains, closure/scope/prune semantics) is inherited from the foundation paper's binary conformance suite.]

= Related Work <sec:related>

#todo[Engine-flavoured prior art only; the foundation paper carries the conceptual lineage. Datomic (@hickey2012datomic) and Fluree (@fluree) as immutable stores; TerminusDB (@terminusdb) as a versioned graph; IPFS/IPLD (@ipfs) and git as content-addressed Merkle stores; restic/borg/Perkeep as CAS backup; SPADE and Quit Store as split-store / git-backed provenance; Neo4j and FalkorDB as graph engines used as layers; the tiered-storage / cache-hierarchy literature. Distinctive composition: a pluggable stack of content-addressed stores, ground = truth, upper layers cache / redundancy / capability.]

= Conclusion <sec:conclusion>

#todo[The engine is built, not asserted: from the atomic store, each added capability discharges a requirement, through R14. A composition of established parts — content-addressed storage, cache hierarchies, signature identity, CRDT merge — arranged so the ground store holds the claims and every layer above is a rebuildable derivation. The same primitives carry the opaque end (backup) and the rich end (second brain). We invent nothing; we compose.]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
