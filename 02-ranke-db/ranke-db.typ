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


= Introduction <sec:introduction>

The *foundation paper* (@metzgernoel2026rankegraph) defines the *Ranke-Graph* as a concept and an abstract data type (ADT), built around a single unit: the *claim*, an attributed record of content, added by a contributor at a stated moment and citing the sources it derives from. Where a conventional database consolidates its sources into one current, contradiction-free state and overwrites it as understanding changes, a Ranke-Graph keeps the whole history of claims, disagreements intact: each immutable, each attributable to an author and a time, each independently verifiable. Its aim is preservation with full provenance, for the long term and across applications.

This paper specifies *RankeDB*, a reference database service that serves and manages Ranke-Graphs: taking the ADT as given, it proposes how such a graph is persisted, composed, replicated, queried, verified, and bounded for access. What follows is the architecture that answers those questions.

Data in an organisation, or a personal life, is scattered. An enterprise spreads it across separate services' data, artifacts on file servers, source in repositories, CI logs, access logs, documents, specifications, and correspondence; a household, across messengers, mailboxes, call logs, cloud photo albums, and files on local and remote drives. Each store keeps its slice in its own format: some open, like JPEG or plain text, much of it locked inside the application that wrote it.

Both applications and formats have finite lives: products are discontinued, sometimes overnight, and a format outlives its tools only if it is open and widely implemented. So the more services one depends on, the more data loss one should expect, and backups guard only the bytes: a copy is unreadable without the application version that wrote it, and rarely searchable across the application-specific shapes it preserves.

A Ranke-Graph sets out to bridge these stores. Conventional databases stay the right tool for fast persistence in live systems; a Ranke-Graph extends what they hold along two axes. In *time*, it keeps data immutable in a generic, application-independent, human-readable form that can outlive the tool that wrote it. In *breadth*, it aims to draw the scattered silos into one searchable store, where each fact carries its history: who recorded it, when, and citing what.

== Use Cases and Desired Properties <sec:use-cases>

Four use cases make the idea concrete; between them they name the properties the system must provide:

+ *Institutional Record.* An immutable, provably timestamped record of who did what and when (approvals, audits, sign-offs, operational decisions) that stands up to an outside auditor or a court. Each record is signed by its submitter, human or machine, sent automatically as the decision is taken and linked to the entities it concerns: employees, projects, customers.

+ *Software Provenance.* At release time a project's evidence is everywhere (repository snapshots, artifacts, test results, reviews, security scans, CVE triage), and a year on it is hard to reassemble. Branches are rewritten, repositories moved, history squashed; build logs expire on retention; the reasoning behind a CVE call survives only in some chat. A Ranke-Graph can bind these fragments to the release as one structured whole: a git snapshot, the CI logs, the developers' decision notes.

+ *Unified Accessible Backup.* A backup for arbitrary bytes (documents, business records, server snapshots) that stays searchable. Content addressing deduplicates identical files on its own, and an arbitrary stack of replicating storage layers keeps a copy on each, written through automatically; every item enters labelled, timestamped, and provenance-annotated, so the whole version history stays queryable and verifiable.

+ *Personal Archive.* Photos, email, and chats freed from vendor silos into one open, format-agnostic store: small, shareable adapters (Google Photos, IMAP mailboxes, cloud storage, chat histories) pull the data in, and generic formats can keep it openable for a lifetime, in applications not yet written. Linked to an AI agent, local or in the cloud, it could become a searchable memory: a 'second brain'.

All four point at one quality: a Ranke-Graph stores data as history. Every entry carries its provenance and its author, perhaps predecessors, and may reference others. Where a conventional database holds the state of a single application, a Ranke-Graph tries to hold the history and interrelation of data across many.

= Requirements <sec:requirements>

From the scope of intended use cases, and the fundamental ideas and guiding principles of the Ranke-Graph, we can now build the list of properties we require of an adequate server. We first recap the guarantees already inherited from the ADT, then extend them with the requirements that emerge from the intended use cases.

== Inherited Guarantees <sec:inherited>

The foundation paper already proves, for any Ranke-Graph, its desiderata D1–D9: provenance, immutability, identity and authenticity, temporality, verifiability, semantic relations, open vocabulary, partial views, and distributability. RankeDB inherits them by implementing the ADT faithfully (see the foundation paper for the definitions); what remains follows: the requirements this paper is accountable for, and the architecture that meets them.

== Guiding Principles <sec:principles>

The goal of the Ranke-Graph is to store data over a long timeframe, which requires us to revisit some of the typical trade-offs.
We should prefer maintainability and thus simplicity over performance. A system with a long lifetime *will* need refactoring, 
extensions, adaptations. A small and simple system beats a highly optimised but complex system in this discipline. 

For the same reasons we should be agnostic regarding the technologies used. The server should be minimal and build
on using existing, reliable, open services - connected via simple adapters that make them replaceable. Minimising the
adapters surface keeps them small, generic, and maintainable. A minimal blob storage adapter with just the three functions `Get(key)`, `Put(key, blob)` and `Has(key)` can easily be realised with any storage solution from a USB Stick to a sophisticated Cloud Service. 


== Implementation Requirements <sec:requirements-impl>

From the above observations emerges this list of requirements:

_Storage and Distribution._
- *R1: Persistence agnosticism.* Runs on any keyed byte store. (@sec:blob, @sec:universe)
- *R2: Thin adapters.* A new backend is trivial to adapt. (@sec:contracts, @sec:blob)
- *R3: Replicability.* Copying and replicating an archive is simple and reliable. (@sec:composition)
- *R4: Composability.* Backends compose for redundancy, performance, or capability. (@sec:composition)
- *R5: Coordination.* Many writers converge on one authoritative state. (@sec:coordinate)
- *R6: Deletion.* Deletion documented, attributed, and leaves a verifiable gap. (@sec:deletion)

_Verification and Witnessing._
- *R7: Trustworthy timestamps.* Claims timestamps are formally verified. (@sec:timestamp)
- *R8: Verification on add.* Every contribution is verified as it enters. (@sec:verify)
- *R9: Verification on demand.* Integrity is checkable any time, to any depth. (@sec:verify)
- *R10: External witnessing.* Archive's past state externally provable. (@sec:verify)
- *R11: Key lifecycle.* Key rotation, revocation, and expiry supported. (@sec:keyrotation)

_Access._
- *R12: Multi-tenancy.* Isolation between data of multiple accounts. (@sec:access)
- *R13: Access control.* Scoped access for system accounts. (@sec:access)
- *R14: Filtered reads.* Expressive filters, with pagination and a result limit. (@sec:query)


== Out of Scope <sec:out-of-scope>

Left to the application layer are user and identity management, user access policy, consensus or truth arbitration, and further application logic.

= Architecture <sec:contracts>

Following the guiding principles stated above, a Hexagonal architecture (@cockburn2005hexagonal) seems to fit best. This architecture has a minimal core that expresses the pure business logic without any direct contact with external resources. Around that core is a small number of adapters, each defined as a narrow contract, each intentionally minimal, so that the technology behind it stays replaceable. 
At its centre, the core wraps the library that implements the Ranke-Graph ADT. The core adds the integration logic that connects the adapters to that library and implements the concerns the ADT leaves open: endpoints, access control, persistence, and contribution management. 

#[
  #show figure: it => grid(
    columns: (2fr, 1fr),
    column-gutter: 1.2em,
    align(center + horizon, it.body),
    align(left + horizon, text(size: 0.92em, it.caption)),
  )
  #figure(
    placement: auto,
    image("drawio/architecture.drawio.png", width: 100%),
    caption: [RankeDB as a hexagonal core wrapping the ranke-graph library: six independent adapter ports, each shown with the backends the reference implementation ships, and configuration entering as the launch artifact rather than a port.],
  ) <fig:adapters>
]

Choosing this architecture is the answer to R2: every port is a narrow contract: the blob store has three functions (@sec:blob), the Sequencer three (@sec:sequencer). Supporting a new backend is therefore a small adapter, and the reference implementation's adapters can be read at a glance. _Discharges R2._

The combination and configuration of the adapters into a runnable instance of ranke-db is done using a config file. Such a configuration specifies one single instance, the analogue to a single Database within e.g. a Postgres service. One statically defined instance per configuration keeps the technology simple and maintainable; a management layer for administering multiple such instances (configuring them, and starting, stopping, or monitoring them) can be implemented on top of this.

This split is a useful razor for deciding what belongs where. The Ranke-Graph holds *content*: claims and their provenance, the record of what happened, preserved in the archive. The configuration holds this deployment's *policy and wiring*: which adapters are bound, where secrets are resolved, and which accounts may do what. When it is unclear where something belongs, the razor decides: a fact the archive should preserve is content and goes in the graph; an operational choice of this particular server is policy and goes in the configuration. Access rights are the clarifying case: _who may read or write which branches_ describes the server, not the world, and so lives in the configuration, never in the graph.


A RankeDB instance is launched by running the binary with a configuration as launch artifact. The configuration contains the full instructions which adapters to mount to the core, including the full parametrisation. Field values in the configuration can be either literal ("field":"value"), references to environment variables resolved at runtime (`"field":"env(VARNAME)"`) or references to key-vault entries ("field":"vault(KEYNAME)") fetched from the key-vault defined in the same configuration at runtime. The configuration is json encoded and optionally age-encrypted (?? reference to age?). While encrypted configuration allows secrets to be stored in the config (convenient for personal or single user projects), env and vault approaches allow secret-less parametrised configuration that can be integrated into enterprise infrastructure. 


= Implementation <sec:datastructure>

This chapter builds the Ranke-Graph from the atom up. Its core concepts are claims (@sec:claim), the atom of the Ranke-Graph; the Universe (@sec:universe), the content-addressed space in which those claims are stored; and the branch-table head (@sec:bth), which retrieves a graph from the Universe. They are realised over the Blob Store (@sec:blob), the foundation of the Universe, and the Sequencer (@sec:sequencer), which manages the branch-table head under concurrent reads and writes.

== The Claim as Atom <sec:claim>

A *claim* is the atom of the Ranke-Graph: a node with a small set of mandatory fields predefined by the ADT, e.g. `type`, `encoding`, `created_at` and `content_hash`, together with the edges to the claims that it references. Custom fields can be set as needed for the use case, which we do to fulfil the requirements for key lifecycle and deletion. Claims are addressed by their identity $op("id")(v) = "Sign"(H(S(v)))$, a signature over the hash of its canonical serialization (foundation paper §Primitives). 

The datatype for a claim is thus:

```
Claim — a node with its edges; immutable, content-addressed

  id()                     → Id:string             its content address
  node()                   → Node                  type, encoding, created-at, content hash + size, pubkey, extensions
  edges(filters: Filter[]) → Edge[]                references to the claims it derives from — its provenance
  contributor()            → Contributor:Claim     the claim that attributes and signs it
  encode()                 → SerializedClaim:bytes canonical serialization — the bytes the store persists by id
  ...                                              closure materialization, validation
```

The edges make the claims a graph. The *closure* of a claim is the claim together with every claim reachable along its edges (foundation paper §Closures). 

== The Blob Store <sec:blob>

As each claim is serializable to a blob and addressable by its deterministic id just as all the claims that it references via its edges, the whole graph can be stored in a Blob Store using each claim's id as the storage key. 

We define the interface for such a blob storage as: 

```
Blob store — content-addressed; immutable

  put(key: Id, blob: bytes)             idempotent — a key's bytes never change
  get(key: Id)            → bytes       a missing key fails the call
  has(key: Id)            → bool        presence; drives delta sync
```

This is the minimal interface a storage solution must implement to serve as a RankeDB storage layer. The minimalism of the interface 
satisfies R1: such an adapter is trivial to write for any backend that stores bytes under a key, and the reference implementation already ships a range of them, so persistence agnosticism follows. 


== The Universe <sec:universe>

The reference library implements the ADT specified *Universe* as a typed interface to an underlying Blob Store. A *Universe* reads and writes claims and content as records, decoding and encoding at the boundary. While the implementation of a Blob Store is enough to construct a Universe, 
by wrapping a Blob Store instance in the default implementation of *Universe* using the `NewBlobUniverse` constructor. An adapter can opt to implement additional bulk, streaming, and querying operations, making the adapter faster under large queries. Due to the optionality and granularity of such performance improving additions, R1 stays satisfied. 


```
Universe — typed interface over a blob store (NewBlobUniverse provides the defaults below)

  getClaims(ids: Id[])              → Claim[]   map  decodeClaim(get(id))
  putClaims(claims: Claim[])                    each put(c.id(), c.encode())
  hasClaims(ids: Id[])              → bool[]    map  has(id)
  getContents(hashes: Id[])         → bytes[]   map  get(hash)
  putContents(items: [Id, bytes][])             each put(hash, blob)
  hasContents(hashes: Id[])         → bool[]    map  has(hash)
  streamContent(hash: Id)           → (Stream, len)   buffers get(hash); native streams
```

== Composing Universes <sec:composition>

RankeDB can persist its data across many storage backends at once. The guiding principle of long-term perspective requires both redundancy and technology agnosticism. RankeDB therefore allows composing Universe instances into arbitrarily complex storage stacks.

This is achieved using composition primitives that themselves implement only the Universe interface. The stacking primitive takes a list of Universe instances together with per-layer configuration defining their read-through and write-through behaviour: marking each as eager or lazy, or capping it with a size threshold in bytes, so a fast in-memory layer need not store gigabytes of binary content. The stack receives read and write requests through the shared Universe interface and routes them to the embedded instances according to its composition logic (@fig:storage, left).

The partition primitive routes each read and write request to one of several Universe instances (@fig:storage, right). The reference implementation uses `mod n` to choose which of the `n` instances handles a given `id`.

#figure(
  placement: auto,
  image("drawio/architecture-storage stack.drawio.png", width: 75%),
  caption: [Two storage compositions. *Left:* a three-layer stack: a write descends, each *eager* layer storing it and each *lazy* layer passing it through; a read descends likewise and, on a miss, fills the lazy layers on the way back up. *Right:* a partition beneath an eager cache, routing each claim by `id mod 2` to one of two shards that together hold the whole archive.],
) <fig:storage>

A third primitive, *UniverseBranch*, routes by the branch a claim is accessed through. This leads to redundant storage in multiple backends for claims that are referenced in multiple branches, but also allows for physical separation of branches, which is useful for multi-tenancy configurations (@sec:access).

Arbitrary replication strategies can be modelled from the provided composition primitives, or from additional ones. To force full replication, we configure the appropriate stack and run a verification pass over a closure: reading and verifying each claim it contains triggers the composition's replication.

_Discharges R3 (replicability)._

Beyond storage, a layer may offer a *query engine* the planner can target. The stacking primitive surfaces the most capable engine among its layers, and RankeDB lowers each read to it (@sec:query), falling back to the native filter when no layer offers more. The current implementation wraps Neo4j (@neo4j), whose `cypher` (@francis2018cypher) — converging on the standardised `gql` (@iso39075gql) — ranks above the native filter. A layer thus contributes not only durability but capability, and a query's meaning is unchanged by which layer answers it.

Direct access to a layer sits outside this boundary. A client holding a backing store's own credentials — Neo4j, Postgres, a filesystem — can read and write it directly, with that platform's full power and none of RankeDB's scoping or verification. This is a demarcation, not a gap: RankeDB enforces its rules on requests that pass through it, and the substrate remains whatever it is. Where the guarantees must hold, the substrate credentials are withheld and only RankeDB is exposed.

_Discharges R4 (composability)._

== Deletion <sec:deletion>

The ADT describes an immutable, append-only data structure, yet some use cases require deleting claims — by legal requirement or administrative choice. RankeDB therefore defines a convention for removing a claim: the deletion is documented in claims that remain in the graph, so the gap is explained.

_Planned_ deletion is intrinsic: a `deleteBy` date the claim carries in its signed content from creation. Every edge referencing the claim copies that date, so the gap stays explained once the claim is purged. A claim carrying `deleteBy` is replicated only into layers configured to allow deletion; a purge removes expired claims at an interval set in the configuration.

_Requested_ deletion is extrinsic: a later demand to forget a claim is recorded as a new claim that references the target and explains the gap.

Verification must still pass for a graph whose claims were deleted under these rules, which requires extending the foundation's verification algorithm. We add a callback to the algorithm that decides these cases.

#todo[Revisit for rigidity — deletion has the same shape as key expiry (@sec:keyrotation) and needs the same treatment. A requested-deletion claim points _at_ its target, so like a `limit`/expiry it is not in the provenance of graphs that reference the deleted claim; it must be propagated to *every* graph affected by the deletion via the base limiting-claim-propagation mechanism (to be described in @sec:access, shared with key expiry), or a sibling graph would still resolve the claim it should no longer see. Cross-tenant edge case to work out: if tenant A imports a claim from tenant B and then deletes it — or expires B's contributor — the substrate _permits_ the operation (it is just another limiting claim in A's closure), yet contributors stand for B's users, so governing who may do this is application policy, not an engine right. Clarify the boundary: what the substrate allows vs. what the application must gate. This confirms that *importing is more powerful than it looks* — it pulls a foreign subgraph into A's control surface, where A's own limiting claims can then act on it.]

_Discharges R6._


== Branch Table Head <sec:bth>

The foundation paper defines a *branch table* as the archive's index of named graphs, each entry pointing at the latest head claim of one. The branch table is itself a claim, and its edges are the references. Whenever any referenced graph gains claims, a new branch table is created, referencing the previous one as provenance. The *branch-table head* (BTH) is the `id` of the latest branch-table claim. A BTH together with a *Universe* holding all the claims it recursively references, the tuple (Universe, BTH), is a *Ranke-Archive*. 

The foundation paper fixes the format of the branch table to be a `contribution/branches` typed claim with `contribution/branch` typed edges referencing each head, the name of that reference stored in each edge's `content`.


== Sequencer <sec:sequencer>

The foundation paper calls the BTH the *mutable marker* (its value advances each time the archive's current state changes) but leaves the management of that marker open (foundation paper §Ranke-Archive). The *Sequencer* is RankeDB's mechanism for it: maintaining the BTH under concurrent reads and writes from many clients. 

Because the BTH is the key to reading a Ranke-Graph out of the Universe, it must not be lost: a corrupted BTH, or one pointing at a claim that failed to persist in the storage backend, leaves the graph unretrievable. The claims remain in the Universe, but finding the right head among the millions of claims of the many graphs that may share it would be cumbersome at best, and impossible on a storage backend without enumeration. For that reason the reference implementation keeps the *history* of the BTH, not just the latest, so that a failed storage write (a claim that did not persist) can be recovered by rolling the BTH back to the last working state. 

```
Sequencer  

  bth(n: int)       → Id of the latest (n=0) or a historical (n<0) branch table 
  bthLen()      → length of the BTH history
  add(id: Id)   → append a new id to the top of the history
```

The Sequencer is the central mechanism that receives every contribution a client wants to add to a Ranke-Archive. After verifying it, the Sequencer creates a new branch-table claim referencing both the new claim and, as its predecessor, the branch table the BTH points at; it then advances the BTH to the new branch table. 
A single step can absorb any number of claims, and each claim carries its whole referenced closure into the graph. 
So the Sequencer merges large batches with little work and is no bottleneck. 
The cost lies in the verification that precedes the merge, which parallelises easily because it runs over an immutable structure. 

Every branch-table claim the Sequencer creates needs a valid contributor claim and signature, so the Sequencer must be registered in the graph as a contributor and hold a private key. That key, and the signing itself, are provided by the Vault and Signer adapters. 


== Scaling Writes <sec:coordinate>

As we showed above, a single Sequencer can add an arbitrary number of new claims in a single contribution, each added claim merging a whole new subgraph into the archive. The merge itself is therefore cheap and handles large traffic well, provided contributions are committed as subgraphs rather than one by one. The cost lies in preparing such bulk commits: the claims must be written into the storage stack to guarantee persistence before the BTH advances, and they must be verified: recalculating the hashes of the claims and their potentially large content bytes, and checking the signatures expressed in their id.

So if scaling should ever become necessary, we propose distributing the *verification* workload across trusted servers while keeping the Sequencer a single centralised instance, kept isolated from regular clients. Such verification servers could verify the submitted claims, feed them into the persistence layers, and bundle many contributions under a single signed claim attesting to the verification performed. Those bulk contributions would then be committed to the centralised Sequencer, which would recognise the trusted verifiers' signatures and commit the claims provided. The updated BTH would be pushed back to the trusted servers, which could then serve the latest state of the archive. The storage layers would replicate the newly added claims automatically through the composition mechanism described above; they need only share a common authoritative layer to resolve any claim.

The mechanism could be implemented as a Sequencer adapter configured to verify, bundle, and commit to the central sequencing server.

_Discharges R5._

== Timestamping <sec:timestamp>

At the database layer a claim's `created_at` is part of its content. The Ranke-Graph aims to provide *formal* verifiability, not to verify the facts a claim states, so judging the plausibility of a creation date is out of scope. Two things about that date are checkable nonetheless. First, monotonicity: a claim may not be dated earlier than any claim it references. Second, a ceiling: a claim merged by the server may not be dated later than the server's internal clock, which prevents future-dating.

Responsibility for plausibility lies with the applications acting as clients: they own the content domain and judge what counts as acceptable information.

As a side effect, the tuple `(created_at, id)` gives a total order over all claims in the graph.

_Discharges R7._

== Verification and Witnessing <sec:verify>

The ADT reference implementation provides a verification mechanism we can use to formally verify the graph; extensions to it were discussed above in @sec:deletion. On add it acts as a gate: only verified claims enter the archive. But software can carry errors and storage can be mutated, so the same mechanism is run as a full pass at any time to assure the archive's continued integrity: any closure can be formally verified from a head id and a storage Universe alone.

The strong collision resistance of cryptographic hashes guarantees that the closure retrieved for a head id is identical, whichever Universe serves it.

This property lets the current BTH of a Ranke-Archive be witnessed externally by a notary, a trusted counterparty, an RFC 3161 time-stamp authority (@rfc3161), a public transparency log, or a public ledger (@gipp2015). Because the BTH commits to the entire closure, a single anchor fixes the whole archive in time, and two anchors bracket everything added between them, regardless of any self-asserted `created_at`.

== Contributor Keys Life Cycle <sec:keyrotation>

The ADT specifies that each contributor has a `pubkey`, which is used to check the signatures on the claims created by that contributor. How those claims map to application or even real world users is up to the application layer; within RankeDB they are mere cryptographic entities.

The ADT intentionally doesn't define a key expiry or rotation mechanism, to leave those degrees of freedom to the implementation. For RankeDB we model a key lifetime mechanism fulfilling requirement R11.

For *planned expiry* we add an optional field `pubkey_expires` (RFC 3339) to the contributor claim, storing the expiry date-time of that key. Any claim with `created_at` greater than or equal to that expiry date fails verification.

For *overlapping rotation* we add a new contributor claim with a new pubkey to the graph. That doesn't invalidate the existing one, which expires at its set date, while introducing the new one. For *non-overlapping rotation* we create a new contributor claim that carries a `contribution/diff` edge with updated `pubkey` and `pubkey_expires` fields to the previous one. That construct expresses that the previous claim was valid up to the `created_at` date of the diff claim, which then took over.

*Early expiry* in an immutable ADT is only possible by adding a further claim that asserts an earlier expiry date, overriding the original. Such a claim points _at_ the contributor rather than being part of its provenance, so it is a *limiting* claim and must be propagated to every branch holding the contributor (see @sec:crossbranch), otherwise the contributor would lose its early expiry there.

We express the early expiry with a claim of type `contribution/contributor` and an edge of type `contribution/diff` with field `pubkey_expires` defining the new expiry date (must be greater than or equal to `created_at` of the new claim, and lower than the previous expiry date).

The problem separates into two parts. For *write access* we keep a central register for the whole archive in which all expiries are stored, so the Sequencer can block any new contribution from an expired contributor. For *documentation* (ensuring every graph contains the full expiry history of its contributors) we rely on the limiting-claim propagation of @sec:crossbranch.

It's worth pointing out here that the task of the Ranke-Graph is to *document what happened*, the task of RankeDB is to *maintain a valid state under additions*, and the task of the application is to *validate the quality of the content* added. For instance, if a claim were ever signed with an expired key, the graph would still be technically intact, documenting exactly what happened in its content, and that content would expose that an invalid signature was admitted at the RankeDB level.

== Access Control <sec:access>

Access Control in RankeDB is expressed as system accounts defined in the configuration that each have a set of grants. Each grant allows one system account a set of rights to one or more branches within the Ranke-Archive. We encode access rights with the letters CRUDA, the classic CRUD with an additional A for "admin". *C* allows contributing claims to the target branch, *R* read access, *U* allows updating existing claims by overlaying them with claims containing `contribution/diff` edges (e.g. @sec:keyrotation), *D* allows deleting claims, and since a physical purge removes bytes from the shared Universe, deleting a claim held in several branches requires *D* on every branch that holds it (see @sec:crossbranch) and *A* allows the creation of new branches as well as hiding existing ones by creating a new BTH that omits them. The target branch for each grant is given as a glob. 

Example: `webapp CR foo_*, provisioner A foo_*` allows `provisioner` to create branch `foo_bar` and `webapp` to read and contribute to it.

Please note, that R access to one branch B_1 and C access  to another branch B_2 allows referencing a claim from B_1 in B_2, effectively importing the full closure of the referenced claim (plus additional diff claims referencing the closure) into B_2. This can be useful for e.g. maintaining a master branch gathering details from multiple projects while keeping each project isolated in its own branch. For details on cross-branch references and propagation see @sec:crossbranch.

A query names a *branch* as the handle for _which_ Ranke-Graph to read. This is what lets RankeDB enforce the grants above and sequence concurrent writes. The foundation paper, however, defines a Ranke-Graph as _any_ tuple `(Universe, id)`, so a graph can also be addressed by a head id directly, bypassing the branch table. We treat such access as *privileged*: given only a head id it can read any graph the Universe holds. It is nonetheless indispensable: restoring a backup, for instance, may begin with nothing but a Universe and a head id kept outside RankeDB. We expose it as a grant over the reserved branch name `$universe`; because `$` is illegal in ordinary branch names, no glob can match it and the privilege is never conferred by accident. Only *R* applies: with no branch and no Sequencer behind it, nothing can be written to the Universe this way.

Using this primitive we can model *tenancy* as a configuration pattern. A *tenant* is a set of grants $G_t subset.eq G$ over a set of branches $B_t subset.eq B$ such that no grant in $G_t$ grants access to a branch outside $B_t$, and no grant outside $G_t$ grants access to a branch in $B_t$. Equivalently, $B_t$ is reachable only through $G_t$ and $G_t$ reaches only $B_t$: the tenant's grants and branches form a closed, isolated block.

Tenants might be different projects of a single individual kept separate, different teams within a company working on different projects, or different customers of a SaaS server renting leases on a shared backend. They share the same infrastructure: a single RankeDB instance serving a single Ranke-Archive through a single Sequencer. If they need stronger separation than configuration can provide, it is advisable to run separate RankeDB instances over separate storage backends.

To use a system account, a request authenticates as one through an endpoint's authenticator (@sec:endpoints); the account's grants then decide access.

_Discharges R12._


== Cross Branch Propagation <sec:crossbranch>

A property of the ADT is that when a claim from one branch is referenced in a contribution to another branch, the full closure is imported along as the provenance of that claim. It also requires importing *some* of the claims *pointing at* that claim. This "some" requires precision: we can differentiate between *additive* claims that contribute content to the archive and *limiting* claims that document the removal of something. Those are key expiry or rotation claims (@sec:keyrotation) and deletion notes explaining the absence of claims (@sec:deletion).

RankeDB must guarantee that a key marked as expired or a claim marked as deleted keeps that property across all branches in which it might appear.

To fulfil this guarantee, we must, at creation time, first add those limiting claims to *all* branches that contain the limited claim; second, we must include them whenever a limited claim is imported into another branch by referencing it.

Whether a system account may reference claims from other branches is configured using grants (see @sec:access). An account can import a claim from a source branch into a target branch only if it holds both R (read) access to the source and C (create) access to the target. To keep claims from spanning branches in the first place, so no cross-branch propagation is ever needed, configure tighter-scoped system accounts, each with access to only a specific branch. The reference implementation offers a macaroon-based *attenuation* mechanism that derives tighter-scoped access tokens from wider ones at runtime. This is ideal for enforcing branch separation from the application layer without provisioning a large number of system accounts in RankeDB.


== Filtered Reads <sec:query>

A read against RankeDB is a tree-structured *query* expressible as a JSON object. `select` blocks are *generators* that define result sets of claims; `where` blocks are *filters* that select subsets from those results; `and`, `or` and `not` combine comparisons by boolean logic, and `or` also unions whole result sets. Generators may select any claims within the access scope of the system account used.

A `select` generator specifies a starting point and follows edges from it. `select.branch` roots at a branch's current head and confines the query to that branch; `select.claim` optionally roots at a different claim id within the branch; `select.claim` without a branch is a privileged action using any claim in the _universe_ as starting point (@sec:access). 
`select.path` specifies the traversal: a sequence of *steps* each naming the `edges` it follows, a `dir` — `provenance` (outgoing, the default), `uses` (incoming), or `connections` (either) — a `depth` bounding its hops, and optionally the `nodes` its endpoint may be. `edges` and `nodes` are both type lists; a leading `-` on an entry excludes that type. Without `path`, a generator follows every edge outward, unbounded — the full closure (foundation paper §Closures). 

#[
#show raw: set text(size: 0.66em)
#figure(
  placement: auto,
  grid(
    columns: (1fr, 1fr),
    column-gutter: 0.8em,
    align: top,
    ```json
    "path": [ {"edges": ["derivation/*"],
               "nodes": ["source/*"]} ],
    "format": "claim"
    ```,
    ```json
    "path": [ {"edges": ["relation/family"],
               "dir": "connections", "depth": 4,
               "nodes": ["entity/person"]},
              {"edges": ["derivation/*"],
               "nodes": ["source/*"]} ],
    "format": "path"
    ```,
  ),
  caption: [Two `path` generators, each choosing a `format`. *Left:* the derivation chain to the `source` claims a release rests on. *Right:* two chained steps — a semantic family neighbourhood (`connections` along `relation/family`, either direction, up to four hops, landing on `entity/person`), then each entity's `derivation` provenance to the `source` claims they derived from — returned as full `path`s.],
) <fig:paths>
]

`select.format` sets how much each result carries: `claim`, the reached claim alone, is the default; `path` the whole route.

A `where` is a boolean tree of *comparisons*. Each comparison tests one field with `eq`, `ne`, `lt`, `le`, `gt`, `ge`, `in` (membership in a set) or `glob` (shell-style wildcard); `and`, `or` and `not` combine them. Controls in `limit` bound the read: `results` caps the number of claims, `content` the returned bytes per claim (`overflow` choosing whether an over-large claim is cut off or omitted), and `time` the query's execution, cancelled when exceeded. Results come back in the total order `(created_at, id)` unless a named `order` of `{field, dir}` sorts by another field instead, claims lacking it sorting last. To page, a client carries the last row's order key — `(created_at, id)`, or `(field, id)` under a named `order` — into a `where` on the next request.

@fig:reads shows one read: the declarative form the client sends (left) and the Cypher RankeDB lowers it to on a Cypher/GQL-capable stack (right).

#[
#show raw: set text(size: 0.66em)
#figure(
  placement: auto,
  grid(
    columns: (1fr, 1fr),
    column-gutter: 0.8em,
    align: top,
    ```json
    {
      "query": {
        "select": {"branch": "project_x",
                   "path": [{"edges": ["derivation/*"],
                             "depth": 3}]},
        "where": {"type": {"glob": "source/*"}},
        "limit": {"results": 200,
                  "content": "4kb",
                  "overflow": "cutoff",
                  "time": "5s"}
      }
    }
    ```,
    ```cypher
    // branch project_x → head 9f2c…e7a1
    MATCH p = (root {id: '9f2c…e7a1'})
              -[:references*0..3]->(c:Claim)
     WHERE all(e IN relationships(p)
               WHERE e.type =~ 'derivation/.*')
       AND c.type =~ 'source/.*'
     RETURN c
     ORDER BY c.created_at DESC,
              c.id DESC
     LIMIT 200
    ```,
  ),
  caption: [A declarative query (left) and its transformation for a specific backend, e.g. Cypher (right).],
) <fig:reads>
]

Queries are declarative and backend agnostic. RankeDB lowers them to whichever execution engine the storage stack offers, ranked by capability: a Cypher/GQL-capable layer (@sec:composition) is preferred over the built-in native graph walk, which is simple, the reference for conformance tests, but not performance optimised. 

The logical execution order is: 1) generate the full result set 2) filter it 3) sort it 4) limit it to the requested output length. This order is easy to implement but not performant. Optimised execution may divert from this order as long as the result set stays identical. The conformance suite in the RankeDB implementation allows comparing the reference implementation against more performant execution engine. An `execution` block with fields as `execution.layer` (explicit selection of layer to execute the query) and `execution.trace` (detailled  output on how the query was executed) help comparing execution engines. 


_Discharges R14._

== Endpoints and Authentication <sec:endpoints>

Reads and contributions are submitted via endpoints, receiving client requests in an endpoint-specific format, and passing them to the core as internal function calls, to then return the results as output in the endpoint-specific format. Auth tokens need to be fetched from the endpoint-specific fields and passed to the core together with the function call, allowing it to match the request against the system account's access rights (@sec:access).

RankeDB implements two endpoint adapters: *REST/HTTP* (OpenAPI) for webapps and *MCP/HTTP* for agents. Both carry the full read-and-contribute surface — REST as `POST /query` and `POST /contribute`, MCP as agent tools. REST also pins a small subset of the query language as `GET` routes — `GET /{branch}/head`, `GET /{branch}/claim/{id}`, `GET /$universe/claim/{id}` — reachable from a browser or `curl` without JSON, and HTTP-cacheable: the by-id form immutably, branch reads with revalidation.

Both adapters support every authentication mechanism (NoAuth, JWT, API Key, Macaroons); 
Multiple endpoint adapters may be configured, exposing the instance on several ports, addresses, or protocols.

= Data Longevity <sec:longevity>

Every part of RankeDB follows the principle of technological agnosticism, so that a user's archive can endure for years while the technology around it evolves — storage backends replaced, new protocols added, clients and use cases changing. What must not change is the archive's *accessibility*, and architecture alone cannot secure that. This section offers best practices for _how_ to store data so it remains usable years from now.

Accessibility splits in two: content must be *available* — RankeDB can serve it from storage — and *readable* — the client can decode its format. Availability is the server's concern; readability falls to the application layer, which should favour open, widely-implemented, long-lived encodings over proprietary or application- and project-specific ones.

This is a challenge that libraries and archives traditionally face
and for which they developed strategies.

#figure(
  placement: auto,
  grid(
    columns: (auto, auto),
    column-gutter: 1.5em,
    align: top,
    table(
      columns: 3,
      align: (left, center, center),
      inset: (x: 0.8em, y: 0.35em),
      stroke: 0.5pt + gray,
      table.header([*Format*], [*Intr.*], [*Std.*]),
      [ASCII],        [1963], [1972],
      [CSV],          [1972], [2005],
      [WAV (audio)],  [1991], [—],
      [HTML],         [1991], [1995],
      [UTF-8 text],   [1992], [1996],
    ),
    table(
      columns: 3,
      align: (left, center, center),
      inset: (x: 0.8em, y: 0.35em),
      stroke: 0.5pt + gray,
      table.header([*Format*], [*Intr.*], [*Std.*]),
      [JPEG],         [1992], [1994],
      [MPEG (video)], [1993], [1993],
      [PDF],          [1993], [2008],
      [JSON],         [2001], [2006],
      [Markdown],     [2004], [2014],
    ),
  ),
  caption: [Introduction (Intr.) and standardisation (Std.) years for common open formats.],
) <fig:formats>

The more open and widely implemented a format, the longer its life. The list in @fig:formats was derived from the _Library of Congress_ recommendations (@locformats) on encodings to use for long-term archival.

= Conformance <sec:conformance>

The RankeDB repository ships a conformance suite: it runs a series of commits and queries against a running instance's API and asserts the results against reference values — those the native engine produces. Run against any server configuration, it validates that any composition of adapters or execution engines, current or future, reproduces them.

= Related Work <sec:related>

#todo[Engine-flavoured prior art only; the foundation paper carries the conceptual lineage. Datomic (@hickey2012datomic) and Fluree (@fluree) as immutable stores; TerminusDB (@terminusdb) as a versioned graph; IPFS/IPLD (@ipfs) and git as content-addressed Merkle stores; restic/borg/Perkeep as CAS backup; SPADE and Quit Store as split-store / git-backed provenance; Neo4j and FalkorDB as graph engines used as layers; the tiered-storage / cache-hierarchy literature. Distinctive composition: a pluggable stack of content-addressed stores, ground = truth, upper layers cache / redundancy / capability.]

= Conclusion <sec:conclusion>

RankeDB takes the Ranke-Graph as given and shows how to serve it, capability by capability. From a content-addressed store of immutable bytes, each requirement (R1–R14) is met by one adapter or primitive: a Universe over any blob store, a composition of stacked and partitioned stores, a Sequencer advancing the branch-table head, a declarative query lowered to whichever engine the stack offers, access bounded by grants over branches. Every part is established; the arrangement is the contribution.

In that arrangement, the ground store holds the claims; every layer above — a cache, a replica, a query engine — is a rebuildable derivation, reached through a contract small enough to swap. Content addressing gives deduplication, cheap forking, and replication. The engine persists, composes, queries, and bounds access; truth and policy live above it, in the graph and the application.

The same primitives serve both ends of the use cases: the opaque backup and the searchable, provenance-annotated archive are the same store, differently read. Reference implementations in Go and Python, and a conformance suite that pins any composition to the native engine's results, make the contract checkable. What an archive needs to outlive its tools — open formats, redundant storage, a specification small enough to reimplement — it now has.

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
