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

// ─────────────────────────────────────────────────────────────────────
// Notation (follows the foundation paper). U is a content-addressed k/v store:
// U(k) is the claim at id k = Sign(H(S(v))); U(h) is content at hash h = H(c).
// RG_k := closure(k, U) is the graph rooted at head id k; RA_k is the
// Ranke-Archive rooted at k, tuple (U, k). A later archive is a new tuple
// (U', k') — the Sequencer *advances* the head id, nothing is mutated.
// "branch-table header (BTH)" is just an archive's head claim U(k).
// ─────────────────────────────────────────────────────────────────────

#show: paper.with(
  title:    "RankeDB: Serving the Ranke-Graph",
  author:   "Florian Metzger-Noel",
  date:     "2026-06-22",
  status:   "draft",
  abstract: [*RankeDB* is a reference database service for the *Ranke-Graph*, the provenance-first data structure the foundation paper defines as an abstract data type: 
a graph of immutable, attributed claims, each carrying its own derivation and independently verifiable. 
Taking that contract as given, this paper specifies how such a graph is persisted, composed, queried, verified, and bounded for access, without weakening any guarantee the structure already proves. 
Its guiding principle is _agnosticism by adapter_: every external technology the engine relies on is reached through a contract kept small enough that no implementation is ever locked in. 
Storage is the clearest case: persistence rests on nothing more than a content-addressed store of immutable bytes, so any store of keyed bytes can serve as the ground, and deduplication, cheap forking, and replication follow from content addressing as consequences rather than features. The architecture is built up capability by capability: demonstration rather than proof.],
)


= Introduction <sec:introduction>

The *foundation paper* (@metzgernoel2026rankegraph) defines the *Ranke-Graph* as a concept and an abstract data type (ADT), built around a single unit: the *claim*, an attributed record of content, added by a contributor at a stated moment and citing the sources it derives from. Where a conventional database consolidates its sources into one current, contradiction-free state and overwrites it as understanding changes, a Ranke-Graph keeps the whole history of claims, disagreements intact: each immutable, each attributable to an author and a time, each independently verifiable. Its aim is preservation with full provenance, for the long term and across applications.

This paper specifies *RankeDB*, a reference database service that serves and manages Ranke-Graphs: taking the ADT as given, it proposes how such a graph is persisted, composed, replicated, queried, verified, and bounded for access. What follows is the architecture that answers those questions.#footnote[A companion glossary collects this series' terminology for reference (@rankeglossary).]

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

The foundation paper already proves, for any Ranke-Graph, its desiderata D1–D8: provenance, immutability, identity and authenticity, temporality, verifiability, semantic relations, open vocabulary, and distributability. RankeDB inherits them by implementing the ADT faithfully (see the foundation paper for the definitions); what remains follows: the requirements this paper is accountable for, and the architecture that meets them.

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
    caption: [RankeDB as a hexagonal core wrapping the ranke-graph library: six independent adapter ports, each shown with the backends RankeDB ships, and configuration entering as the launch artifact rather than a port.],
  ) <fig:adapters>
]

Choosing this architecture is the answer to R2: every port is a narrow contract: the blob store has three functions (@sec:blob), the Sequencer's persistence adapter three (@sec:Sequencer). Supporting a new backend is therefore a small adapter, and RankeDB's adapters can be read at a glance. _Discharges R2._

The combination and configuration of the adapters into a runnable instance of ranke-db is done using a config file. Such a configuration specifies one single instance, the analogue to a single Database within e.g. a Postgres service. One statically defined instance per configuration keeps the technology simple and maintainable; a management layer for administering multiple such instances (configuring them, and starting, stopping, or monitoring them) can be implemented on top of this.

This split is a useful razor for deciding what belongs where. The Ranke-Graph holds *content*: claims and their provenance, the record of what happened, preserved in the archive. The configuration holds this deployment's *policy and wiring*: which adapters are bound, where secrets are resolved, and which accounts may do what. When it is unclear where something belongs, the razor decides: a fact the archive should preserve is content and goes in the graph; an operational choice of this particular server is policy and goes in the configuration. Access rights are the clarifying case: _who may read or write which branches_ describes the server, not the world, and so lives in the configuration, never in the graph.


A RankeDB instance is launched by running the binary with a configuration as launch artifact. The configuration contains the full instructions which adapters to mount to the core, including the full parametrisation. Field values in the configuration can be either literal ("field":"value"), references to environment variables resolved at runtime (`"field":"env(VARNAME)"`) or references to key-vault entries ("field":"vault(KEYNAME)") fetched from the key-vault defined in the same configuration at runtime. The configuration is json encoded and optionally age-encrypted (@age). While encrypted configuration allows secrets to be stored in the config (convenient for personal or single user projects), env and vault approaches allow secret-less parametrised configuration that can be integrated into enterprise infrastructure. 


= Implementation <sec:datastructure>

This chapter builds the Ranke-Graph from the atom up. Its core concepts are claims (@sec:claim), the atom of the Ranke-Graph; the Universe (@sec:universe), the content-addressed space in which those claims are stored, realised over the Blob Store (@sec:blob); and the Sequencer (@sec:Sequencer), which advances a Ranke-Archive's head under concurrent reads and writes.

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
  ...                                              closure materialization, verification
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
satisfies R1: such an adapter is trivial to write for any backend that stores bytes under a key, and RankeDB already ships a range of them, so persistence agnosticism follows. 


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

The partition primitive routes each read and write request to one of several Universe instances (@fig:storage, right). RankeDB uses `mod n` to choose which of the `n` instances handles a given `id`.

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

The ADT is immutable and append-only, yet a legal requirement or an administrative choice can force a claim's bytes to be removed. RankeDB purges the bytes while leaving an explained gap in their place, so the removal is documented rather than silent. Deletion takes two forms.

_Planned_ deletion is intrinsic: a `delete_by` date the claim carries in its signed content from creation. Every edge referencing the claim copies that date, so once the bytes are purged the gap stays explained wherever the claim is reached — the schedule travels with each reference, and no propagation is needed. A claim carrying `delete_by` is replicated only into layers configured to allow deletion; a purge removes due claims at an interval set in the configuration.

_Requested_ deletion is extrinsic: a later claim whose `contribution/delete` edge names the target by id (foundation paper §Types), documenting the gap once the bytes are purged. It is a limiting claim, so @sec:crossbranch carries it to any branch that references the target.

Verification must still pass for a graph whose claims were purged, which extends the foundation's verification algorithm with a callback that accepts an explained gap — a `contribution/delete` reference, or a copied `delete_by` date — in place of the missing bytes.

Deletion right is a *D* grant per branch (@sec:access). As a delete reaches every branch that holds the claim, configure access rights with tenancy in mind. 

_Discharges R6._


== Sequencer <sec:Sequencer>

The foundation paper defines how an archive advances under addition: a contribution takes the tuple $(cal(U), k)$ to a new $(cal(U)', k')$ with $cal(U) subset.eq cal(U)'$, superseding the head id $k$ rather than mutating it (§Ranke-Archive). The *Sequencer* is RankeDB's mechanism realising the archive's advance, maintaining the sequence of head ids $k_0, k_1, dots, k_n$ — its latest $k_n$ the head read from and appended to — under concurrent reads from and writes to its branches by many clients, and guarding the *structural* validity invariant by verifying every contribution before it merges.
A corrupted head id, or one pointing at a claim that failed to persist in the storage backend, would leave the graph unretrievable. The claims remain in the Universe, but finding the right head among millions of claims can be costly or even impossible without enumeration. For that reason the RankeDB _Sequencer_ keeps the *history* of the head, not just the latest, thus allowing rollbacks to previous states. That history is held in the Sequencer's *persistence adapter* — a narrow port with three operations: read the latest or an earlier head, its length, and append.

At the claim level, that advance is the foundation's construction: a set $C$, each claim created atomically (§Claims), gathered under a new consolidating head, yields $"RG"_(k') = "closure"(k', cal(U)')$ with $cal(U) subset.eq cal(U)'$, $C subset.eq cal(U)'$, $"RG"_k subset.eq "RG"_(k')$, and $"valid"("RG"_k) arrow.r.double "valid"("RG"_(k'))$ by construction (§Consolidation, §Validity). A single such addition can merge any number of claims, and each claim carries its whole referenced closure into the graph.  

As adding an arbitrarily large set of claims (the _"contribution"_) can be time-consuming, we must process contributions in parallel while upholding the validity invariant. We propose the following procedure:

1) Opening: a contribution is opened against the current archive $"RA"_k$ and stamped with the current time $t$; the pair $(k, t)$ is its _base_. It requires contribute access to the target branch.
2) Adding: the contribution's claims are added, each checked to be dated `created_at` $<= t$ and to use no type reserved to the Sequencer — limiting and branch-table claims are the Sequencer's alone.
3) Completing: the contribution is _closed_ — each claim's references are followed, drawing in any referenced claim outside it (from another branch of the archive or the wider Universe) together with their limiting claims (@sec:crossbranch), recursively, until every path reaches a claim already in the base's closure. Read access to all branch-external claims is required. 
4) Verifying: every claim in the closed contribution is verified against the base, and the contribution _sealed_: its contents fixed, so by immutability whatever verified stays valid however long it waits. In practice completion and verification run as one traversal — the walk that follows a claim's references also checks it.
5) Persisting: the sealed contribution is written to the Universe — content addressing stores only the claims and content not already present — and propagated across the storage layers (@sec:composition), so its whole closure is durably present before the head advances.
6) Merging: the Sequencer references the contribution's head claim(s) in a new branch-table claim and advances the head, $k arrow.r k'$; the contribution becomes part of the target branch from that moment.

Any step failing results in the rejection of the contribution. 

Step 1 needs to be executed by the sequencing thread, but is compute cheap as it merely returns the current head id $k$ and the system time. Steps 2-5 can be done concurrently due to the immutable add-only nature of the archive. Step 6 is the only step that actually advances the archive head and must be executed by the sequencing thread. It can merge an arbitrary number of contributions in a single operation, a new branch-table claim referencing any number of new head claims. So the Sequencer merges large batches with little work and doesn't become a bottleneck.
Every branch-table claim the Sequencer creates needs a valid contributor claim and signature, so the Sequencer must be registered in the graph as a contributor and hold a private key. That key, and the signing itself, are provided by the Vault and Signer adapters. 

Limiting claims can be created by the Sequencer only; system accounts merely commit _requests_ for them. An early-expiry request — an `expires_after_request` edge — causes the Sequencer, if access policy permits, to mint a `contribution/expiry` claim carrying a `pubkey_expires_after` no earlier than the new head's date, so that every already-committed claim stays valid. This happens as part of step 6.

The cost lies in the verification that precedes the merge, which parallelises easily because it runs over an immutable structure. 

== Scaling Writes <sec:coordinate>

That verification — steps 2–5, separable from the cheap central steps 1 and 6 — can be distributed should scaling ever demand it. Trusted worker servers verify submitted claims, feed them into the persistence layers, and bundle many contributions under a single signed claim attesting to the verification performed. The central Sequencer commits those bulk contributions, recognising the trusted verifiers' signatures, and advances the head — pushing the updated $k$ back to the workers to serve. The storage layers replicate the new claims automatically through the composition mechanism (@sec:composition), needing only a shared authoritative layer to resolve any claim. The workers are themselves adapters, so the core is unchanged.

_Discharges R5._

== Timestamping <sec:timestamp>

At the database layer a claim's `created_at` is part of its content. The Ranke-Graph aims to provide *formal* verifiability, not to verify the facts a claim states, so judging the plausibility of a creation date is out of scope. Two things about that date are checkable nonetheless. First, monotonicity: a claim may not be dated earlier than any claim it references. Second, a ceiling: a claim merged by the server may not be dated later than the server's internal clock, which prevents future-dating.

Responsibility for plausibility lies with the applications acting as clients: they own the content domain and judge what counts as acceptable information.

As a side effect, the tuple `(created_at, id)` gives a total order over all claims in the graph.

_Discharges R7._

== Verification and Witnessing <sec:verify>

The ADT reference implementation provides a verification mechanism we can use to formally verify the graph; extensions to it were discussed above in @sec:deletion. On add it acts as a gate: only verified claims enter the archive. But software can carry errors and storage can be mutated, so the same mechanism is run as a full pass at any time to assure the archive's continued integrity: any closure can be formally verified from a head id and a storage Universe alone.

The strong collision resistance of cryptographic hashes guarantees that the closure retrieved for a head id is identical, whichever Universe serves it.

This property lets the current head of a Ranke-Archive be witnessed externally by a notary, a trusted counterparty, an RFC 3161 time-stamp authority (@rfc3161), a public transparency log, or a public ledger (@gipp2015). Because the head commits to the entire closure, a single anchor fixes the whole archive in time, and two anchors bracket everything added between them, regardless of any self-asserted `created_at`.

== Contributor Keys Life Cycle <sec:keyrotation>

The ADT specifies that each contributor has a `pubkey`, which is used to check the signatures on the claims created by that contributor. How those claims map to application or even real world users is up to the application layer; within RankeDB they are mere cryptographic entities.

The ADT provides the vocabulary for expiry — the `contribution/expiry` edge (foundation paper §Types) — but leaves the key-lifetime mechanism (validity windows, rotation, enforcement) to the implementation. For RankeDB we model that mechanism, fulfilling requirement R11.

For *planned expiry* we add an optional field `pubkey_expires_after` (RFC 3339) to the contributor claim: the last date-time at which that key is valid, so any claim with `created_at` strictly after it fails verification. To rotate into a new key at expiry, we just add another contributor with field `pubkey_valid_from` (RFC 3339) — a key's validity being the closed window from `pubkey_valid_from` through `pubkey_expires_after`; the two can exist independently and even overlap.

*Early expiry* is achieved by pointing a `contribution/expiry` edge at the target contributor, carrying a `pubkey_expires_after` date-time before the planned one. The claim carrying that edge must be either a `contribution/expiry` claim, or a new `contribution/contributor` claim introducing the successor key. This is a limiting claim, propagated across branches by @sec:crossbranch.

== Access Control <sec:access>

Access Control in RankeDB is expressed as system accounts defined in the configuration that each have a set of grants. Each grant allows one system account a set of rights to one or more branches within the Ranke-Archive. We encode access rights with the classic *CRUD* letters. *C* allows contributing claims to the target branch, *R* read access, *U* updating existing claims by overlaying them with newer versions (e.g. @sec:keyrotation), and *D* deleting claims; since a physical purge removes bytes from the shared Universe, deleting a claim held in several branches requires *D* on every branch that holds it (see @sec:crossbranch). The target of each grant is given as a glob.

Example: `webapp CR foo_*, provisioner C $branches` allows `provisioner` to create branches such as `foo_bar` and `webapp` to read and contribute to them.

Please note, that R access to one branch $B_1$ and C access to another branch $B_2$ allows referencing a claim from $B_1$ in $B_2$, effectively importing the full closure of the referenced claim into $B_2$. This can be useful for e.g. maintaining a master branch gathering details from multiple projects while keeping each project isolated in its own branch. For details on cross-branch references and propagation see @sec:crossbranch.

A query names a *branch* as the handle for _which_ Ranke-Graph to read. This is what lets RankeDB enforce the grants above and sequence concurrent writes. The foundation paper, however, defines a Ranke-Graph as _any_ tuple `(Universe, id)`, so a graph can also be addressed by a head id directly, bypassing the branch table. We treat such access as *privileged*: given only a head id it can read any graph the Universe holds. It is nonetheless indispensable: restoring a backup, for instance, may begin with nothing but a Universe and a head id kept outside RankeDB. We expose it as a grant over the reserved target `$universe`; because `$` is illegal in ordinary branch names, no glob can match a `$`-name and the privilege is never conferred by accident. Only *R* applies to `$universe`: with no branch and no Sequencer behind it, nothing is written to the Universe this way.

`$universe` is one of a family of reserved `$`-targets that expose the archive's administrative surfaces through the same CRUD grants. `$branches` grants act on the branch table itself: *C* creates a branch, *R* enumerates the table, *U* repoints an entry, *D* hides a branch by contributing a new archive head that omits it — the authority the retired *A* once carried, now separable into create, read, override, and hide. A `$`-target names a single server-wide surface, so a grant over it is a highly privileged access right.

Using scoped branch grants, *multi-tenancy* is as a configuration pattern rather than a concept RankeDB defines. Arrange the grants so that a group of branches is reachable only through a group of grants that in turn reach only those branches: the two form a closed, isolated block, which we call a *tenant*. Such a block holds no `$`-target grant, since each of those reaches server-wide, beyond the block; its branches are provisioned by a central operator holding `$branches`.

Tenants might be different projects of a single individual kept separate, different teams within a company working on different projects, or different customers of a SaaS server renting leases on a shared backend. They share the same infrastructure: a single RankeDB instance serving a single Ranke-Archive through a single Sequencer. If they need stronger separation than configuration can provide, it is advisable to run separate RankeDB instances over separate storage backends.

Within a single instance, RankeDB can also derive tighter-scoped access tokens from wider ones at runtime through a macaroon-based *attenuation* mechanism, enforcing branch boundaries from the application layer without provisioning a large number of system accounts.

To use a system account, a request authenticates as one through an endpoint's authenticator (@sec:endpoints); the account's grants then decide access.

_Discharges R12._


== Cross Branch Propagation <sec:crossbranch>

A *limiting claim* documents that another claim is restricted in use — its bytes deleted (@sec:deletion), or a contributor's key expired early (@sec:keyrotation). It points at the claim it restricts, its *target*. If a limited claim is now referenced from another branch, we have to make sure that the limiting claim is also referenced, so that the limitation is not lost in that other branch. 

This _cross branch propagation_ is an *operational* requirement coming from the design decision made by RankeDB, that a claim limited in one branch should be limited in all branches. This decision is taken to avoid conflicts when cross referencing claims between branches. 

To achieve this, RankeDB references every limiting claim from a reserved *system branch*.
Whenever a limiting claim is contributed to any branch, the Sequencer references it here too. 
At startup the Sequencer reads that branch in full and builds an in-memory lookup of limiting claims by target. 
Each contribution commits as the delta of claims effectively added to a branch; the Sequencer matches the delta against the lookup and, for any added claim that is a target, adds the limiting claims against it to the same branch as part of the same contribution. A limit thus stays attached to its target wherever it is referenced. The Sequencer enforces further contribution rules that keep arbitrary claims from propagating into other branches.


== Filtered Reads <sec:query>

A read against RankeDB is a query in *RankeQL* (RQL) — a tree-structured object expressible as JSON. This section gives its conceptual shape; the full grammar and evaluation semantics are fixed by the Ranke normative specification @rankespec. `select` blocks are *generators* that define result sets of claims; `where` blocks are *filters* that select subsets from those results; `and`, `or` and `not` combine comparisons by boolean logic, and `or` also unions whole result sets. Generators may select any claims within the access scope of the system account used.

A `select` generator specifies a starting point and follows edges from it. `select.branch` roots at a branch's current head and confines the query to that branch; `select.claim` optionally roots at a different claim id within the branch; `select.claim` without a branch is a privileged action using any claim in the _universe_ as starting point (@sec:access). 
`select.path` specifies the traversal: a sequence of *steps* each naming the `edges` it follows, a `dir` — `provenance` (outgoing, the default), `uses` (incoming), or `connections` (either) — a `depth` bounding its hops, and optionally the `nodes` its endpoint may be. `edges` and `nodes` are both type lists; a leading `-` on an entry excludes that type. Without `path`, a generator follows every edge outward, unbounded — the full closure (foundation paper §Closures).

A multi-step `path` is a *frontier pipeline*: each step is an independent bounded walk starting from the set of claims the previous step reached, and the no-repeat rule (a walk does not revisit a node) applies within a step only, resetting at each boundary — so a later step may re-cross an edge or claim an earlier step used. This must be stated because reading the steps as one continuous trail with whole-path edge-uniqueness — the default of Cypher and similar engines — drops results: stepping from a `derivation` to the `source` it cites and then back (`dir: uses`) to the derivations citing that source should return that derivation, yet a single-trail reading returns nothing, having "used up" the shared edge. The result must not depend on how the frontier was reached. (A later opt-in modifier may additionally constrain a returned route's shape — the ISO GQL `WALK`/`TRAIL`/`ACYCLIC`/`SIMPLE` modes; the frontier pipeline remains the default.)

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
    "output": {"detail": "claim"}
    ```,
    ```json
    "path": [ {"edges": ["relation/family"],
               "dir": "connections", "depth": 4,
               "nodes": ["entity/person"]},
              {"edges": ["derivation/*"],
               "nodes": ["source/*"]} ],
    "output": {"detail": "path"}
    ```,
  ),
  caption: [Two `path` generators, each choosing an output `detail`. *Left:* the derivation chain to the `source` claims a release rests on. *Right:* two chained steps — a semantic family neighbourhood (`connections` along `relation/family`, either direction, up to four hops, landing on `entity/person`), then each entity's `derivation` provenance to the `source` claims they derived from — returned as full `path`s.],
) <fig:paths>
]

A `where` is a boolean tree of *comparisons*. Each comparison tests one field with `eq`, `ne`, `lt`, `le`, `gt`, `ge`, `in` (membership in a set) or `glob` (shell-style wildcard); `and`, `or` and `not` combine them.

`output` shapes each result: `detail` sets how much it carries — `id`, `claim`, or `path` (the whole route); `content` caps inlined content bytes per claim (`false`, the default, carries none); `overflow` defines how to handle oversized content — `cutoff`, `omit`, or `reference`; `encoding` fixes the wire serialization — `json-seq` (@rfc7464, the default), a text sequence with content base64-encoded, or `cbor-seq` (@rfc8742), binary.

`limit` bounds the read: `results` caps the claim count, `time` the execution. Results order by `(created_at, id)` unless a named `order` of `{field, dir}` sorts otherwise, claims lacking the field last; to page, carry the last row's order key into a `where` on the next request.

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
        "output": {"content": "4kb",
                   "overflow": "cutoff",
                   "encoding": "cbor-seq"},
        "limit": {"results": 200, "time": "5s"}
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

The logical execution order is: 1) generate the full result set 2) filter it 3) sort it 4) limit it to the requested output length 5) materialise each result into the requested `output`. This order is easy to implement but not performant; optimised execution may divert from it as long as the result set stays identical. An `execution` block tunes and inspects this: `execution.layer` selects a layer explicitly; `execution.report` appends a final *report* record to the result stream — the layer that processed the query, the query it was lowered to (the Cypher/GQL text, or `native`), and per-step timings in milliseconds — typed distinctly from the result claims. The conformance suite compares the native reference against more performant engines.


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

The RankeDB repository ships a conformance suite: it runs a series of commits and queries against a running instance's API and asserts the results against reference values — those the native engine produces. Run against any server configuration, it confirms that any composition of adapters or execution engines, current or future, reproduces them.

= Evaluation <sec:evaluation>

#todo[Placeholder — empirical evaluation to be written once the reference implementation stabilises. Conformance (@sec:conformance) shows the compositions agree; this section should show they *perform*, turning the asserted discharges of R1, R3, R4, R5, and R14 into measured ones.]

== Setup
#todo[Backends under test (native blob store on local disk, S3, a Neo4j-backed layer); hardware; dataset(s) and their claim/content size distribution; how a single declarative query or contribution is replayed across configurations.]

== Storage Backends: Throughput and Latency
#todo[Blob-store `get`/`put`/`has` across S3 vs local vs a stacked cache+shard composition; cost of the write-through/read-fill paths. Substantiates R1 (persistence agnosticism), R4 (composability).]

== Query Engines: Native Walk vs Cypher/GQL
#todo[The same declarative query lowered to the native graph walk vs the Neo4j Cypher/GQL layer; latency against traversal depth and result size; confirms "a query's meaning is unchanged by which layer answers it" (@sec:composition). Substantiates R14.]

== Sequencer Throughput
#todo[Merge cost against contribution (batch) size; contributions/second; the verification-before-merge cost and how it parallelises. Substantiates R5 (coordination) and the "no bottleneck" claim (@sec:coordinate).]

== Replication Cost
#todo[Overhead of the composition primitives (stack, partition, UniverseBranch); the full-replication verification pass over a closure. Substantiates R3 (replicability).]

== Discussion
#todo[Which discharges the numbers turn from asserted to shown; where the native reference trades performance for simplicity; limits of the evaluation.]

= Related Work <sec:related>

The concepts behind the Ranke-Graph, and their lineage, belong to the foundation paper; this section places RankeDB among the running systems it draws on. RankeDB composes established storage mechanisms to serve the abstract data type, and so to close the gap the foundation paper names: a digital datastore built on the analogue principles of the archival tradition — attributed claims forming an unbroken chain of references in authorship and content, rather than a current state updated in place. 

The closest systems in intent are immutable and versioned databases and dedicated provenance stores. Datomic (@hickey2012datomic) records time-stamped facts and queries the past as readily as the present; Fluree (@fluree) keeps a semantic graph over an immutable ledger; TerminusDB (@terminusdb) versions a graph with git-like branches. SPADE (@spade) audits provenance across distributed systems, and Quit Store (@quitstore) keeps git-backed, PROV-annotated RDF. All share the refusal to overwrite. Each, though, is a single engine that versions or annotates a knowledge base; RankeDB instead serves the foundation paper's ADT — where provenance is the record, not an annotation on one — over interchangeable backends, and takes its identity from content-addressed hashing rather than an internal log.

The parts themselves are standard. Its ground is a store of immutable bytes addressed by content, as in IPFS and IPLD (@ipfs), git, and content-addressed backup; any keyed-byte store can serve as it (@sec:composition). 

Established, performant graph engines such as Neo4j (@neo4j) act as an acceleration layer, giving fast access to the archive. The hexagonal core behind minimal adapters (@cockburn2005hexagonal) is the borrowed pattern underlying the whole architecture. 

Each of these supplies one capability — immutability, content addressing, graph query — that RankeDB uses as a part. The contribution is the composition: a stack of content-addressed stores serving a provenance-first ADT, its ground the claims and every layer above a rebuildable derivation.

= Conclusion <sec:conclusion>

RankeDB implements the abstract data type of the foundation paper as a working server. We have tried to build it in the spirit of the Ranke-Graph: on a content-addressed store of immutable bytes, reached through minimal adapters that keep every backend replaceable, so the archive outlives the technologies that serve it; the engine persists, composes, queries, and bounds access, while content and policy remain with the graph and the application. Each requirement (R1–R14) set out in @sec:requirements is met by a corresponding design decision. The contribution is a working reference server that realises the ADT faithfully on interchangeable, established parts.

What comes next is up to the users: real archival applications built on this foundation, inheriting the qualities it provides.

#v(1em)
#text(size: 0.92em)[*Acknowledgements.* This paper was prepared with the assistance of AI tools (Claude Opus 4.6–4.8, Anthropic).]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
