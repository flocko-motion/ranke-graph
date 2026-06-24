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

RankeDB sits one level above the ADT and one below any application: it supplies simple, enforceable building blocks, and the application decides whether and why to use them.

Above the goals sits one guiding principle — _agnosticism by adapter_. Every external technology the engine touches — the storage that holds claims, the secrets that guard them, the configuration that assembles the system — is reached through a thin, exchangeable adapter, so RankeDB is bound to no product or vendor and any part can be swapped. The only fixed thing is the small contract each adapter satisfies, and composability follows from it for free, since a small uniform contract is closed under composition. The principle is real only in proportion to how _small_ that contract is: an adapter that takes a hundred thousand lines is exchangeable in name only — no one ever rewrites it — so the floor is kept trivial, and performance lives in _optional_ parts of the interface that a capable backend may implement and declare, never weighing on the minimum. Storage is the template (@sec:atomic): a few-line blob store is the entire requirement, while native bulk and batch paths are opt-in. The goals below are the concrete capabilities; this is the stance they share — G1 and G2 are it made concrete for storage, and the secret and configuration stores extend it unchanged.

The design goals divide into three groups.

_Storage._
- *G1 — Storage agnosticism.* Run on a wide range of storage backends, beholden to none.
- *G2 — Thin adapters.* Supporting a new persistence backend is easy to implement.
- *G3 — Composability.* Persistence composes from mixable, layered backends.
- *G4 — Replicability.* Copying, replicating, and backing up an archive is cheap.
- *G10 — Coordination.* Multiple servers accept writes to one archive and reconcile to a single head.
- *G12 — Deletion.* Claims in mutable storage are deleted on a planned retention date or a requested one, purged by date with an edge left to explain the absence; add-only storage is permanent by choice.

_Content Verification and Witnessing._
- *G7 — Verification on add.* The validity of any contributions is automatically verified on addition and supports key rotation, revokation, or expiration.
- *G8 — Verification on demand.* Archive integrity is checkable on demand, at a depth the caller chooses.
- *G11 — Trustworthy timestamps.* Each claim's self-asserted time is bounded by a server-witnessed transaction window — provable time and a definite total order, with no reassignment.
- *G9 — External Witnessing.* Prove externally that the archive's entire content existed at a given moment.

_Database Access._
- *G5 — Filtered queries.* The archive is queryable through filters and a result limit.
- *G6 — Access control.* A caller-supplied scope is enforced for both reads and writes.


The database knows service accounts, their access rights, persistence stacks and Ranke Archives as content; *non-goals*, left to the application layer, are user and identity management, user access policy, consensus or truth arbitration, and further application logic. The architecture (@sec:architecture) is built up to meet G1–G12 capability by capability — demonstration rather than proof.


= Architecture <sec:architecture>

To implement the database, we first build the Ranke Archive it serves; only then do we expose it through an API as a single service.

== Ranke Archive <sec:ranke-archive> 


A Ranke Archive consists of claims; each claim is persisted in content-addressed storage, and the content bytes it carries are stored content-addressed too. The fundamental building block of the system is therefore the storage of a single claim.

A *claim* is an attributed record — a node bearing a type, an encoding, a creation time, the hash of its content, and a set of edges to the claims it was derived from — addressed by its id, $op("id")(v) = "Sign"(H(S(v)))$: a signature over the hash of its canonical serialization, so the id fixes both the record and its author (foundation paper §Primitives). Its content bytes are held separately, addressed by their own hash and size.

```
Claim — a node with its edges; immutable, content-addressed

  id()                     → Id:string             its content address
  node()                   → Node                  its own data: type, encoding, created-at, content hash + size, pubkey
  edges(filters: Filter[]) → Edge[]                references to the claims it derives from — its provenance
  contributor()            → Contributor:Claim     the claim that attributes and signs it
  encode()                 → SerializedClaim:bytes canonical serialization — the bytes the store persists by id
  ...                                              closure materialization, validation
```

The edges make the claims a graph. The *closure* of a claim is the claim together with every claim reachable along its edges — its full provenance, back to the initial nodes (foundation paper §Closures). A claim carries meaning only with its closure: a single id recovers a whole closure, and a complete, mergeable state is always one.

All claims — and the content they carry — live in one content-addressed store. Storing them reduces to a single thing: a *blob store* — three operations over immutable, keyed bytes.

```
Blob store — content-addressed; immutable

  put(key: Id, blob: bytes)             idempotent — a key's bytes never change
  get(key: Id)            → bytes       a missing key fails the call
  has(key: Id)            → bool        presence; drives delta sync
```

Each is keyed by its content address — a claim by its id, the content it carries by its hash — and the store interprets neither; to it both are opaque bytes under a key. Because keys are content addresses, any number of closures share one store without coordination: identical claims collapse to a single key, and a claim present for one closure is present for all.

This is the entire theoretical contract, and the whole of what a backend must provide; the in-memory adapter that implements exactly these three operations (plus lifecycle) is 37 lines. Everything above them is convenience and performance optimization for bulk operations. The reference library exposes this store as a typed `Universe` that decodes serialized claims into records (`getClaims`), batches reads and writes in bulk, streams large content lazily with its size, and copies and merges store-to-store — crucial to a working engine, none of it enlarging the contract. `NewBlobUniverse` lifts any blob store into a full `Universe` for free, and a backend reimplements one of those operations only when a native bulk path (S3 batch, SQL bulk) runs faster.

The lift is mechanical — the content operations *are* the blob primitives, the claim operations wrap them with decode and encode:

```
Universe over a Blob store — the default lift (NewBlobUniverse)

  getClaim(id: Id)                  → Claim    decodeClaim(get(id))
  putClaim(claim: Claim)                       put(claim.id(), claim.encode())
  hasClaim(id: Id)                  → bool     has(id)

  getContent(hash: Id)              → bytes    get(hash)
  putContent(hash: Id, blob: bytes)            put(hash, blob)
  hasContent(hash: Id)              → bool     has(hash)
```

The shipped interface takes these in bulk — `getClaims`, `putClaims`, … — so a backend can use a native batch path: throughput, not a larger contract.

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

#todo[Lead. This chapter builds the engine up the way the foundation paper builds the data structure up: from the archive and its Sequencer, add one capability at a time, each discharging a design goal (@sec:goals). Spine — storage layer → stack → replicate → coordinate → compose → verify and witness → query → access.]

== Storage Layer <sec:atomic>

A RankeDB instance reduces to one storage engine behind one small API: store and fetch bytes by key.

#todo[Show the atomic write — hash content, serialize, sign, store — and the filesystem adapter inline (~a dozen lines) as the G2 proof. Claims, ids, and closure are defined at the chapter opening; don't repeat them here. Note the serialization choices once (CBOR Deterministic, IPFS multihash, Ed25519).]

_Discharges G1, G2._ #todo[G1 — the engine assumes only a store of bytes addressed by a key; anything from a USB stick to Amazon S3 qualifies. G2 — that API _is_ the adapter contract, so a new backend is those three calls; show the filesystem adapter inline (~a dozen lines) as proof the contract is tiny.]

#todo[What the store holds, opinionated defaults (fold former §Default Type Vocabulary and §Generic-Format Extracts here): the `source/*` and `derivation/*` default subtypes, MIME-style encodings, and the practice of keeping a generic-format extract beside each original. Mark *[FREE / default]*.]

== Stacking Storage <sec:stack>

One engine becomes a _stack_: layers ordered ground-to-top, the ground authoritative, upper layers caches.

#todo[Define the stack and its read paths: read-through (a miss falls to the next layer down and fills on the way back), write-through (or write-ground-then-fill). Cache coherence is trivial — content-addressed bytes are never stale, eviction is always safe, and any upper layer drops and rebuilds from below. The ground is the source of truth because read-through terminates there.]

#todo[Figure: vertical stack diagram (adapt drawio/layers.svg) — ground = truth at the bottom, caches above, read-through arrows down on miss filling up, write arrows. Two example stacks side by side (`S3 | S3-local | neo4j`, `S3 | local-FS | in-memory`).]

_Discharges G3 (composability)._

== Replicating Storage <sec:replication>

A _complete_ layer, once filled, is a full live copy of the archive — so durability is a matter of adding one.

#todo[A complete layer added to the stack fills by write-through, or in one pass by a full read-through (the same sweep `verify` uses, @sec:verify). Backup, replication, and portable export then collapse to one operation — add a layer: a remote store, a second region, a detachable SQLite file. Redundancy is one line of configuration.]

_Discharges G4 (replicability)._

== Coordinating Storage <sec:coordinate>

A single Sequencer is one writer; coordination lets many servers accept writes to one archive without giving up its single head.

#todo[Each server runs as a _subsequencer_: it accepts writes locally and accumulates a side branch off the critical path (the prepared-branch path of @sec:sequencer), then merges that branch up to the central Sequencer and rebases on the latest $B_h$. The central Sequencer stays the single linearization point; concurrent merges fork into two heads that the next merge consolidates (additive — no rejected write, no lost update). Most write work is local and parallel; only the periodic merge touches the central point, so write throughput scales out while the archive keeps one head. The reference implementation keeps a single sequencer and leaves the hierarchy depth open.]

_Discharges G10._

== Composition <sec:composition>

Layers need not be whole or single.

#todo[Partial layers: each declares a `max_content_len`; larger writes fall through, so a Cypher/GQL layer can hold only small claims (~8 kB) while blobs live below. The complete-ground rule: one layer accepts content of any size, so the stack loses nothing. A complete layer may be _composite_ — several backends behind a routing layer, complete as a system — which admits geographic distribution and read-scaling. Note this as a direction; the reference implementation keeps a single ground.]

== Deletion <sec:deletion>

Append-only is one storage choice, not a law of the system: the engine can erase a claim's content — bytes and all — and leave its structure to explain the gap. Two kinds of erasure call for this, and because they are different facts they are recorded differently.

_Planned_ deletion is intrinsic — a `deleteBy` date the claim carries in its signed content from creation, the retention schedule a record is born with (keep seven years, then destroy). It is a property of the claim, as immutable as the rest of it.

_Requested_ deletion is extrinsic. A later demand to forget a claim cannot be written into it — the claim is immutable — so the request is recorded as its own new claim: an erasure record that references the target and documents who asked and when. Forgetting thus becomes an event with provenance, not a silent edit.

Routing follows erasability. A _partition_ composer — itself a Universe over two child Universes, like any other composition — sends erasable claims (those carrying a `deleteBy`) to a mutable partition and the rest to an add-only one. Only a mutable-partition claim can be erased, by either route; a claim with no `deleteBy` is permanent by choice, and the add-only store never holds a claim it could not lawfully erase.

Mutability propagates upward: any layer above a mutable partition must itself be mutable, or an add-only cache would leak erasable data past its date. Each mutable layer runs a daily date-based purge — dropping a claim once its `deleteBy` has passed or an erasure record demands it — and since both triggers are themselves claims, every layer reaches the same verdict without coordination.

Erasure leaves a scar, by design. An edge that references a claim carrying `deleteBy` copies that date into itself — one hop, no cascade — so when the content is purged the edge remains and records that something was here and lawfully went. Verification reads the gap correctly: completeness (@sec:verify) holds when every reference is present or tombstoned, so erasure is never taken for corruption. It is the physical counterpart to the foundation's `contribution/prune`, which hides a claim behind an id-only stub; deletion removes the bytes and leaves the edge — both absence with an explanation.

_Discharges G12._

== Timestamping <sec:timestamp>

A claim asserts when it was made, and the engine keeps that assertion both ordered and bounded. One rule orders it and caps it from above: a claim may reference only claims of strictly lower `(timestamp, id)`. A short, server-witnessed transaction window bounds it from below. Together — the rule, the window, and the server's signature on each merge — they need nothing written into the store to mark time, and no persistent transaction record.

Two clocks, one soft and one hard. A claim's `created_at` is the contributor's self-asserted authoring time, carried in the signed content; it is _soft_ — forgeable, never trusted, and not the date of whatever the claim describes (a 2010 email ingested today is stamped today). _Archival_ time, when the archive accepted the claim, is _hard_, and it is not a separate field: it is the timestamp of the server-signed merge that first absorbed the claim. The contributor asserts; only the archive witnesses.

Ordering is `(timestamp, id)`, the id a universal tiebreak — so duplicate timestamps need no rule, and the order is total and deterministic by value.

The ceiling falls out for free: the merge is itself a claim under the rule, and it references the claims it commits, so each sits below the merge's signed time — nothing can be postdated past the server's real clock. The floor is where a transaction earns its keep. A write opens a transaction against the server, which returns an ephemeral token — a JWT or macaroon, _not_ a claim — carrying a floor (the server's clock at the open) and a short validity window (seconds to minutes). The client builds its batch offline, stamping each claim honestly against what it cites, and submits under the token; the server admits the batch only if every timestamp lies between the token's floor and its own clock at submission, then merges atomically and records that witnessed window in the signed merge. The token never enters the store — it is operational state, discarded at commit — so nothing transient is immortalised; what persists is the server's signed attestation that the batch was authored within `[t_open, t_commit]`.

The window also closes the one gap the rule leaves alone. A dangling root that references nothing recent has no lower claim to lift it, so monotonicity by itself could not stop it self-asserting a low `created_at` — only expose the lie beside the honest archival time. The transaction floor refuses it outright: root or not, every claim in a batch is bounded below by the witnessed `t_open`. Concurrency, by contrast, needs no guard: two writers produce two heads, which the next merge consolidates (contradiction by addition), so no write is rejected for conflict and none is lost.

The chain of signed merges is, by construction, a transparency log — each references the prior, each timestamped and signed, the shape of RFC 3161 timestamping or Certificate Transparency, falling out of "the head update is a claim." Verifying it is foundational, not the server's privilege: anyone holding the data re-checks a merge's signature, its chain to the prior merge, and monotonicity across the closure, offline. _Minting_ — witnessing the real time, signing the merge, advancing the head — is the server's job and the only part that needs its key.

Distinct from all of this is _height_: `height(c) = 1 + max` over a claim's references (roots at 0), a Lamport-style logical clock read straight from the DAG — causal depth, not chronology, and an index recomputable from structure rather than a primitive. An implementation may order by `(height, id)` where causal order is wanted, verifiable by recomputation.

_Discharges G11._

== Verification and Witnessing <sec:verify>

The build closes the trust story: contributions are checked as they are written, the whole archive is checkable on demand, and an external witness anchors it in time.

_Verification on add (G7)._ Every contribution is checked as it is written — its signature and id chain verified against its contributor's key before the merge commits. Key lifecycle rides the same check, and it is expressed entirely in claims, needing no addition to the foundation's schema. A key carries a `validUntil` beside its pubkey — a scheduled expiry after which the engine refuses new claims signed by it. Early revocation is the on-demand counterpart: a newer contributor _revision_ claim names the keys it retires with `expiry` edges (one revision can retire many at once), and may instead, or also, `supersede` a predecessor to continue the identity under a fresh key. A key's effective end is the earliest of its `validUntil` and any `expiry` edge pointing at it; validity is judged at the claim's witnessed time (@sec:timestamp), forward-only — everything signed while the key was live stays valid, and the contributor claim is kept forever as the verification anchor. A revision is admitted only when it carries a valid signature from a contributor authorized to manage contributors (@sec:authority); `expiry` and `supersede` are the engine's reserved reading over the foundation's open edge mechanism, not new schema. Because it is all claims, a server follows the `supersede` chain to the current revision on its own, advancing which identity it signs as without manual intervention, and the full key history is auditable and verifiable offline. The application sets policy (who may retire whom); the engine enforces. _Discharges G7._

#todo[Open detail: the precise authorization rule — which signatures may create, `supersede`, or `expire` a contributor, and how it chains to the create-contributor right (@sec:authority). To be specified with the contributor-rights model.]

#todo[*Verification on demand (G8) — comes cheap.* A generic server operation, no per-backend work: read-through the closure of $h$ and recompute the id chain at a chosen depth — completeness (every reference and blob present), record correctness (signatures and id chain), or full content (rehash every blob). Tiered cost; warms caches as a side effect. _Discharges G8._]

#todo[*Time-stamp witnessing (G9) — likely a plugin.* Publish the head hash to an external timestamp authority (RFC 3161); because the head commits to the whole closure, one timestamp attests the archive's full content at a moment. Probably a plugin interface — state what the reference implementation provides and leave the rest open. _Discharges G9._]

== Filtered Queries <sec:query>

A read is a *filtered query*: the closure of a head, narrowed by a conjunction of filters and capped by a result limit.

Filters are declarative *data*, not predicates in code — values that can be inspected, composed, and checked. The foundation paper fixes the fundamental filter vocabulary, a total order over claims (by `created_at`, then id), and the result limit; the reference evaluation is a linear scan over the closure that keeps the claims matching every filter and truncates in order. That naive query is deliberately simple, and it is the _verifiable reference_: RankeDB reimplements it over indexes for speed and must pass a shared query-conformance suite, so the fast path is measured against the simple one rather than trusted in its place.

Filters compose by conjunction only — _conjunctive monotonicity_: adding a filter can only narrow a result, never widen it, so for fundamental filters $F$ and any further filters $G$, $"result"(F and G) subset.eq "result"(F)$. A backend may implement a _superset_ of the vocabulary — for example GQL capabilities through a Cypher-capable layer — but a superset filter can only further restrict what the fundamentals admit; it can never re-admit what they excluded. Union is a different construct, not a combination of filters; where a backend offers it the shared floor no longer applies, and that boundary is kept sharp.

Because filters are data, a result is checkable even for a query the reference cannot itself evaluate. Split the query's filters into understood and not-understood; using only the shared vocabulary, verify that every returned claim satisfies every fundamental conjunct and that the result is a subset of the fundamental-only query under the limit. Verification is then a partial oracle whose strength scales with the number of fundamental conjuncts a query carries — a pure-superset query is checkable only as a subset of the corpus under the cardinality limit.

Membership is the robust guarantee, surviving any superset; ordering is fragile, since a backend that imposes its own ranking selects a different first-$N$ than the fundamental order. The contract follows the honest line: limit and ordering are fully verifiable for a pure-fundamental query; once a superset ordering is in play, verification drops to set membership and cardinality, not which $N$ survived the limit.

_Discharges G5._

== Access <sec:access>

What remains is to bound who may read and write.

#todo[*Access control (G6).* A scope supplied by the application and enforced by the server bounds reads and writes — a base `allow-all`/`deny-all` plus ordered wildcard exceptions over field/edge names and types. The scope is bound to the authenticated account, not chosen at request time; no elevation path. Verifiable partial views: out-of-scope references appear as hash-only stubs, Merkle-verifiable without disclosure. _Discharges G6._]

#todo[Authentication: a connecting service authenticates with a shared secret (token/JWT) for access; claim signing stays with the application, the engine only verifies signatures at write. Two roles, kept separate.]

= Infrastructure <sec:infrastructure>

#todo[Capture chapter — collects the deployment and operational exploration (topologies, secrets, keys, authority, the air-gapped keyholder, delegation). Mostly deployment detail rather than core architecture; refine, trim, or relocate downstream once the engine chapter settles.]

The architecture is one design; how it is deployed is a separate and free choice. The same mechanisms — the universe stack, the Sequencer, content-addressed claims — run unchanged from a single process on a laptop to a distributed fleet with an air-gapped key authority. The topology is configuration, not a redesign. This chapter captures the shapes RankeDB can take and the operational concerns they raise: secrets, keys, and the authority that issues them.

== From one node to a fleet <sec:topologies>

A single server is the whole system collapsed into one process: it is the Sequencer, holds one long-lived key, and runs forever once enabled. A fleet is the same architecture with the roles spread out — a central Sequencer and replicas that prepare work off the critical path and merge it up in a single commit (@sec:sequencer, @sec:coordinate). Concurrent commits simply fork into two heads that the next merge consolidates, so scaling out never costs a rejected write or a lost update. One scales by adding replicas, never by switching designs; the single-server case is just the fleet with no replicas.

#todo[Figure: the three shapes side by side — single node; central Sequencer + replicas; distributed central-protection (isolated central, user-facing replicas).]

== Configuration and assembly <sec:config>

A running instance is defined entirely by a *configuration*, and the configuration is itself read through an adapter — Postgres is only one way to hold it, alongside a YAML file or a flat directory. It is not passive storage: it is the assembly that binds the other adapters into a system — which storage layers compose the stack, which secret store holds the keys, which contributor the sequencer signs as, which archives exist and who may reach them. Given a configuration the server instantiates those adapters and runs, so *launching a config is launching the service*. This completes a symmetry of three pluggable adapter classes: **storage** (where claims live), the **secret store** (keys and credentials), and the **configuration store** (the assembly itself). The one thing a configuration cannot describe is how to reach itself, so that lives outside as a minimal bootstrap directive — _use config adapter X with arguments Y_ — from which the server loads the configuration and constructs all the rest. That directive is tiny and can be secret-free (a file path, or a connection string authenticated by platform identity rather than an embedded password), which makes the server binary generic: the same executable everywhere, pointed at one config. With file-based adapters throughout, an instance is a single process with no external dependency; Postgres, a vault, and object storage enter only when a deployment asks for them. And the configuration store composes like the rest: a _partition_ adapter can mount one child for server settings, another for accounts, another for the archives and their stacks — the same Composite pattern that stacks storage layers, since every adapter class is closed under it.

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


= Conformance <sec:conformance>

#todo[RankeDB builds on the foundation paper's ADT reference library (Go, soon Python), adding the server, the storage-layer adapters, and the admin layer. Conformance here is _adapter conformance_: an adapter satisfies the content-addressed contract (@sec:atomic) and declares its capability and `max_content_len`; give the adapter test battery. ADT-level conformance (serialization determinism, id chains, closure/scope/prune semantics) is inherited from the foundation paper's binary conformance suite.]

= Related Work <sec:related>

#todo[Engine-flavoured prior art only; the foundation paper carries the conceptual lineage. Datomic (@hickey2012datomic) and Fluree (@fluree) as immutable stores; TerminusDB (@terminusdb) as a versioned graph; IPFS/IPLD (@ipfs) and git as content-addressed Merkle stores; restic/borg/Perkeep as CAS backup; SPADE and Quit Store as split-store / git-backed provenance; Neo4j and FalkorDB as graph engines used as layers; the tiered-storage / cache-hierarchy literature. Distinctive composition: a pluggable stack of content-addressed stores, ground = truth, upper layers cache / redundancy / capability.]

= Conclusion <sec:conclusion>

#todo[The engine is built, not asserted: from the atomic store, each added capability discharges a goal, through G9. A composition of established parts — content-addressed storage, cache hierarchies, signature identity, CRDT merge — arranged so the ground store holds the claims and every layer above is a rebuildable derivation. The same primitives carry the opaque end (backup) and the rich end (second brain). We invent nothing; we compose.]

#bibliography("../shared/sources.bib", style: "association-for-computing-machinery")
