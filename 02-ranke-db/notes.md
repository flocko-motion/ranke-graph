# P2 / RankeDB — Consolidated notes

*Merged 2026-05-07 from `notes.md`, `quotes.md`, `technical-notes.md`, `todo.md`. Content reorganized by topic; no edits or removals. The paper draft itself lives in `rankedb.md` and was not touched.*

---

# Part A — Quotes & external source material

*From `quotes.md`. External quotes used as raw material for Part 1 of the paper.*

"LLMs strip provenance from knowledge. Systematically, architecturally and by design. And in so doing, AI systems are creating a form of knowledge network decay that degrades the knowledge infrastructures that human civilization rely upon." [talisman2026](sources/talisman2026provenance)

"The concept, first formalized by Giorgio Cencetti in 1939, captures the essence of the critical importance of provenance: knowledge does not exist as isolated units. It exists in structured relationships, and those relationships are themselves carriers of meaning. Destroy the relationships and intelligibility is lost." [talisman2026](sources/talisman2026provenance)

"The historian Peter Burke, in *What is the History of Knowledge?* (2016), situates this principle within a broader intellectual context. Burke argues that to qualify as 'knowledge,' items of information must be discovered, analyzed, and systematized—what he calls, *Verwissenschaftlichen*, the shift towards a more scientific approach. Burke posits that knowledge is not raw data. It is information that has been processed through systems of verification, classification, and contextual placement. The mechanisms of that processing—and their history—are themselves a form of knowledge. Burke further argues that even the idea of scientific objectivity—'an attempt to separate knowledge from the knower'—has a history. Provenance is how we preserve the record of that processing. Without it, we collapse knowledge back into unverified assertion." [talisman2026](sources/talisman2026provenance)

"The quest for knowledge rather than mere information is the crux of the study of archives… All the key words applied to archival records—provenance, respect des fonds, context, evolution, inter-relationships, order—imply a sense of understanding, of 'knowledge,' rather than the merely efficient retrieval of names, dates, subjects, or whatever, all devoid of context, that is 'information.'" — Council on Library and Information Resources, via [talisman2026](sources/talisman2026provenance)

"Suzanne Briet, librarian, historian and poet, in her 1951 manifesto *What Is Documentation?*, argued that a document is not simply a text — it is any piece of evidence organized to represent or prove something. An antelope in the wild is not a document. An antelope cataloged in a zoo, with a record of its capture, its species classification, its provenance of origin — that is a document. The act of documentation is what transforms raw existence into knowledge that can be evaluated, transmitted, and trusted. Without the record, there is no evidence. Without evidence, there is no knowledge — only assertion." — via [talisman2026](sources/talisman2026provenance)

"Patrick Wilson, writing on cognitive authority in *Second-Hand Knowledge* (1983), made a complementary point: we accept most of what we know not through direct experience but on the authority of others. The question is never simply what is claimed but who claims it, on what basis and the source of the claim. Wilson argued that the credibility of knowledge relies upon our ability to trace the lineage of information or a claim. And tracing works to their sources requires infrastructure and knowledge." — via [talisman2026](sources/talisman2026provenance)

"Subject headings and classification systems organize knowledge into retrievable, navigable structures so that a researcher can move from a question to a source, from a source to its author and to that author's citations. Every layer of this system is provenance infrastructure — designed to make knowledge findable and evaluable. In library science, provenance is documentation. It is the chain of custody that connects a claim to its source, a source to its author, and an author to the context in which they produced knowledge. This chain is the mechanism by which knowledge becomes trustworthy. Large language models break this chain by design." [talisman2026](sources/talisman2026provenance)

*Note: RankeDB's positioning — rebuild the provenance chain LLMs break, using LLMs as workers, for LLMs as consumers. The tool that severed provenance becomes the tool that restores it, inside an architecture that refuses to let it strip the chain.*

"Science, industry, and society are being revolutionized by radical new capabilities for information sharing, distributed computation, and collaboration offered by the World Wide Web. This revolution promises dramatic benefits but also poses serious risks due to the fluid nature of digital information. One important cross-cutting issue is managing and recording provenance, or metadata about the origin, context, or history of data." — Cheney, Chong, Foster, Seltzer & Vansummeren (OOPSLA 2009), via [talisman2026](sources/talisman2026provenance)

*Note: Provenance was identified as a cross-cutting research priority in computer science two decades before LLMs broke it at scale. The irony: the discipline had the theoretical groundwork ready when the problem arrived, but the architectural integration — provenance as substrate rather than annotation — was never built. RankeDB picks up that thread.*

*Scope note (important — must be stated explicitly in Part 1):*

*RankeDB does not aim to solve global provenance. It targets personal up to small-enterprise scale: individual archives, project teams, small organizations. At this scale, the sources are largely self-trusted — your own email, your own chats, your bank statements, your photos, your team's documents. The trust problem is about preserving the chain from things you already trust, not establishing trust across an adversarial public.*

*Where RankeDB does NOT go: Wikipedia-scale consensus, web-scale retrieval, public scientific record. Those are different problems with different failure modes (adversarial editors, commercial stakes, peer review, citation networks). Trying to solve them all at once is what killed the Semantic Web.*

*Why this matters architecturally: at personal/project scale, the auto-verifiable domain is usually close to the whole domain, and the bounded-verification model works. At global scale the unverifiable case dominates, and a different architecture is needed. RankeDB is tuned for the former and honest about it.*

---

# Part B — Positioning & design stance

*From `quotes.md`. Design notes for Part 1 of the paper.*

## Design notes for paper 1, Part 1: two principles, one stance

### Provenance and consensus are orthogonal problems

Knowledge graphs have been trying to solve two different problems with one system: provenance (who said what, traceable back to sources) and consensus (what should we agree is true). These are orthogonal.

- **Provenance** is an *attribution* problem: who said what, when, on what basis, derived from what. Solvable by construction — just do not throw the chain away. RankeDB is a provenance database.
- **Consensus (common truth)** is a *social* problem: getting multiple observers to agree on what to trust. Requires voting, authority hierarchies, negotiation, peer review, time. Wikipedia solves it at scale with enormous human effort. The Semantic Web tried to pre-solve it via global ontology and failed.
- **Absolute truth** is philosophically incoherent — no one can have it, so drop it from the design.

The Semantic Web's failure is not that its ontology was too ambitious. It is that it tried to pre-bake consensus into the substrate, which was a category error. RankeDB separates the two: provenance is handled rigorously as a database problem, consensus is left to the layer above, where humans, applications, and time can work on it. This separation is the core contribution.

RankeDB stores *attributed claims*. Every node in the graph is a communicative act by someone, at some time, in some context. "Napoleon was born in 1769" is not a fact in RankeDB — it is Wikipedia's claim, or your history textbook's claim, or your grandfather's claim. The graph stores the claim, the claimer, the context, and the provenance. It does not store "the truth" about Napoleon. What consumers do with the claims is their business.

Consequences:

- **Contradiction is normal, not a bug.** Two nodes can claim opposite things; both stay in the graph; both carry their provenance.
- **Conviction replaces certainty.** A claim is not "true" or "false" — it has a conviction score based on corroborating sources, their authority, and who is asking.
- **The same claim can mean different things** depending on who said it, when, and to whom. Context is preserved, not abstracted away.
- **There is no "ground truth" layer.** Level 0 is the archive of communicative acts, not an archive of how the world is.
- **Ontology emerges per-perspective**, not globally. My understanding of who "Bob" is may differ from yours, and that is fine — the graph holds both.

Consensus workers, if an application wants them, are implemented on top of the substrate: they produce `classification/consensus` or `observation/consensus` nodes that aggregate views with their own provenance. But the database itself makes no consensus decisions. *We do not refuse common truth, we defer it to the consumers and provide the substrate that makes it possible.* Consumers who want consensus can build it. Consumers who want to preserve dissent can preserve it. Consumers who want to pick a single perspective can do that too.

This is the constructive stance. RankeDB is not rejecting truth — it is identifying a conflation the field has been stuck on for 30 years and fixing it. Consensus is downstream of provenance, not part of it. You cannot have meaningful consensus without attribution, but you *can* have meaningful attribution without consensus. One is the foundation; the other is a choice built on top.

### Bounded scope: personal to small-enterprise

The separation of provenance from consensus becomes tractable at personal up to small-enterprise scale: individual archives, project teams, small organizations. At this scale, the provenance problem is solvable *and* the consensus problem is small enough to defer comfortably.

- **Consensus is not needed** for most questions. I do not need to agree with anyone else about what my mother said in her email. I just need to preserve what she said.
- **Ontology is bounded.** The entities that matter in my life are finite. Resolving "who is Bob" across 200 conversations is tractable. Resolving "who is Bob" across all humans named Bob on Earth is not.
- **Trust is pre-established.** I already trust my own sources. The question is not "is this source trustworthy?" but "did I capture what it said faithfully?"
- **Adversarial resistance shrinks.** My archive is mine. The threat model is "do not lose it, do not corrupt it," not "prevent millions of attackers from poisoning consensus."
- **Context is preserved by proximity.** All the documents that matter to me are about me, my work, my circle. Context stays intact because the scope stays intact.

Where RankeDB does *not* go: Wikipedia-scale consensus, web-scale retrieval, public scientific record. Those are different problems with different failure modes (adversarial editors, commercial stakes, peer review, citation networks). Trying to solve them is what killed the Semantic Web.

"RankeDB does not scale to Wikipedia" is not a weakness — it is a deliberate scope. Wikipedia-scale is the wrong target. The right target is the scale where the problem is solvable *and* the solution is actually useful to an individual. A knowledge graph about my life and work is more valuable to me than Wikipedia, because it is mine, it is complete, and it preserves context that global systems strip.

### The two principles enable each other

The separation of provenance from consensus and the bounded scope are not two separate design decisions — they are one coherent stance.

- You can only afford to defer consensus if you have bounded the scale to one where the consumers who build on top can actually handle it. At global scale you would drown in contradictions with no human process to resolve them.
- You cannot justify bounded scope without the provenance/consensus separation — if you believed a single global truth layer was the goal, you would have to aim for global, because partial truth is incoherent.

Each enables the other. Together they define what RankeDB is:

**RankeDB stores attributed claims; common truth is what consumers build on top when they want it.**

This is paper 1's thesis in one sentence. The rest of the paper — the three levels, the taxonomy, the invariants, the rebuild guarantee, the under-prescription principle — all fall out as the structural consequences of these two commitments.

*Note: RankeDB aligns with Wilson's cognitive authority framing and Briet's documentation thesis: the database does not care about the antelope itself, only about who said what about the antelope, when, and on what basis. This is a deliberate departure from Berners-Lee's Semantic Web vision, which tried to ground meaning in global concept definitions. RankeDB treats the communicative act as primary.*

---

## Comparison: Karpathy's LLM Wiki (April 2026)

*From `quotes.md`.*

Karpathy's LLM Wiki (gist 442a6bf, 5000+ stars) proposes a three-layer pattern: immutable raw sources, an LLM-maintained wiki of markdown files, and a schema document. The LLM incrementally builds and maintains entity pages, summaries, cross-references, and contradiction flags. The core insight — compounding knowledge vs. stateless RAG — is the same as RankeDB's.

**What it validates:** the need for persistent, structured, LLM-maintained knowledge that compounds over time rather than being re-derived on every query. Karpathy's "LLM does bookkeeping, human does thinking" is RankeDB's worker model. His immutable raw sources are L0. His wiki is L1+L2 collapsed into flat markdown.

**What it's missing — and what the comments are already discovering:**

- **No provenance.** Wiki pages are updated in place. You cannot trace a claim back through its derivation chain to the source that produced it. Karpathy's log.md records *when* things were ingested, not *how* a claim was derived.
- **Destructive consolidation.** Entity pages get overwritten. When the LLM "updates" a page with new information, the old synthesis is silently replaced. The contradiction Karpathy says the system "flags" gets resolved at write time by the LLM, with no record of what was there before. Git history is the only safety net.
- **No content type taxonomy.** Everything is "a markdown page." No distinction between fact, summary, classification, observation. No way for downstream consumers to filter by derivation type.
- **Schema as instruction, not architecture.** Karpathy relies on a CLAUDE.md file telling the LLM how to behave. RankeDB's invariants are enforced by the API — the system *refuses* to create a node without provenance, regardless of what the LLM wants to do.
- **The comments prove the gap.** Within days, users are independently reinventing RankeDB's invariants ad-hoc: access control via capability tokens, contamination firewalls, verify-before-assert hooks, file locking, contradiction callouts with claim types (source/analysis/unverified/gap). One commenter (redmizt) built 13 architectural extensions on top of flat files to solve problems that RankeDB's three invariants (immutability, acyclicity, mandatory provenance) prevent by construction.

**The key failure mode:** Karpathy writes "noting where new data contradicts old claims" — but his wiki overwrites the old claims when it updates entity pages. This is exactly the destructive consolidation §3.2 argues against. The LLM quietly resolves contradictions at write time, with no provenance, no record of the prior belief, and no way to recover if the resolution was wrong.

**Positioning for paper 1:** Karpathy's LLM Wiki validates the need for the pattern RankeDB proposes while demonstrating exactly the failure modes that RankeDB's invariants prevent. It is the "vibe wiki" — compelling at small scale with an engaged human, but structurally unable to preserve the derivation history that makes knowledge trustworthy. RankeDB is what you get when you take the same insight and refuse to cut corners on provenance.

---

# Part C — Core architecture (Merkle-DAG, heads)

*From `technical-notes.md`. Captured from design discussion, April 2026. Implementation-level architecture extending §2, §3, §7.3 of the paper.*

## Atomic Node+Edge Creation

Nodes are always created atomically together with their edges in a single transaction. Every node creation has:
- **n input edges** (provenance: "derived from these nodes")
- **0..m output edges** (semantics: "relates to these nodes", primarily in L2)
- **1 worker attribution** (who/what produced this)
- **1 content blob** (the actual payload)

Both input and output edges are created at node creation time and are immutable thereafter.

**Two perspectives on the same graph:**
- Ignore output edges → always a DAG (the provenance subgraph). Acyclic by construction because input edges can only point to already-existing nodes.
- Follow output edges too → cycles possible (semantic traversal). "A knows B, B knows A" works because each relation node has output edges to the entities it connects.

This applies uniformly across all levels. L0 nodes have input edges (parent) and no output edges. L1 nodes have input edges (provenance) and rarely output edges. L2 relation nodes have input edges (provenance to the evidence that supports the relation) AND output edges (the semantic relation itself).

The DAG property holds for the input-edge subgraph. Always. Everywhere. Output edges add semantic richness without touching Merkle integrity.

---

## Everything is Content-Addressed (Merkle-DAG)

Every ID in the system is a hash. No sequences, no UUIDs.

**Edge hash:**
```
edge_hash = H(
  source_node_hash  +
  target_node_hash  +
  relation_type     +
  direction         +    // input or output
  ...
)
```

**Node hash = hash of all fields, including edge hashes and content hash:**
```
node_hash = H(
  content_hash      +    // hash of the blob in S3
  content_type      +    // e.g. source/conversation
  encoding          +    // e.g. text/eml
  input_edges[]     +    // array of input edge hashes
  output_edges[]    +    // array of output edge hashes
  created_at        +
  worker_id         +
  ...
)
```

**Why this is a Merkle-DAG:** A node hashes its input edges. Each input edge references its source node by hash. That source node hashes its own input edges. Recursively down to L0 roots (which have no inputs, or a single parent). Change a single node anywhere in the graph → its hash changes → all nodes that reference it as input would have a different hash → inconsistency is immediately detectable.

---

## Heads as the Cut Line

Periodically, a **head claim** is created. Its `contribution/head` edges reference all currently-open heads plus the previous head. Its hash witnesses the entire graph state at that point in time.

```
Head_N = H(
  content_hash: H("head at 2026-04-20T23:45:00Z")
  contribution/head edges: [head_1, head_2, ..., head_n, head_N-1]
)
```

The chain of heads forms a hashchain: each head includes the previous head's hash as a `contribution/head` reference. This gives a linear, ordered sequence of graph states.

**Publishing:** The head hash can be published to any external timestamping service — e.g. in the New York Times or a public ledger (Haber & Stornetta, 1991) — to provide third-party proof of graph state at a given point in time.

---

## Three Properties That Usually Conflict

| Property | Mechanism |
|---|---|
| **Immutable** | Append-only DAG, content-addressed nodes |
| **Manipulation-proof** | Merkle-DAG + head hashchain + blockchain notarization |
| **Prune-friendly** | Everything above the last published head is prunable |

**Heads are the boundary between immutable and mutable:**
- Everything *below* a published head is irrevocable — the hash is in the blockchain, the Merkle-DAG witnesses every node.
- Everything *above* the last head is workspace — experimental workers run here, buggy runs get pruned here.

**Purge becomes trivial:** "Prune everything since head N" is a single operation. Fork from head N, rebuild with improved workers.

**Publish cadence is policy, not architecture:** How often heads are published determines the balance between manipulation-proofing and prune flexibility. Daily? After each audit cycle? After each release? Application-layer decision.

---

## Hash Function Agnosticism

Paper 1 uses `H(x)` to denote the cryptographic hash function, not a specific algorithm. The reference implementation uses SHA-256, but the architecture does not depend on it. The hash algorithm should be configurable, and node IDs could carry a type prefix (e.g. `sha256:a3f2...`) to allow coexistence of different hash functions during migration.

Reference: Haber & Stornetta (1991), "How to Time-Stamp a Digital Document" — the foundational paper on cryptographic timestamping, cited by Satoshi (2008). They demonstrated the concept by publishing hash digests in the New York Times.

---

# Part D — Storage architecture

## Storage Architecture: Dark S3 + Slim Postgres

*From `technical-notes.md`.*

### S3 is dark storage
- Nobody lists S3. No `ListBucket`, no enumeration. Access is always by hash: GET/PUT/HEAD.
- Workers never touch S3. They call the API, which handles storage internally.
- Defining invariant: *if it's not in Postgres, it's not there.* Postgres is the sole discovery path.
- Storage abstraction is minimal: any backend supporting content-addressed GET/PUT/HEAD works.

### Postgres holds the entire graph
All nodes (L0 and L1) live in Postgres as rows with metadata, hash, and size. The graph topology (all edges) is in Postgres. S3 holds only byte payloads.

### Postgres is a tunable text cache over S3
- `content_cached` is a `text` column — only text content is cached, never binary.
- Cache eligibility determined by encoding: `WHERE encoding LIKE 'text/%'`.
- Threshold is a runtime config knob. Raise → background fill. Lower → background evict.
- Content-addressed means cache invalidation is impossible — pure LRU.

### Per-node fields
- `content_hash` — H(content), points at S3 blob, also the node ID
- `content_size` — bytes, for cache policy queries
- `content_type` — e.g. `source/conversation`
- `encoding` — MIME-style, e.g. `text/eml`, `image/png`
- `content_cached` — nullable `text`, inlined content when policy allows
- `input_edges[]` — array of edge hashes (provenance)
- `output_edges[]` — array of edge hashes (semantic relations)
- `created_at`, `worker_id`, `origin`, `original_name`, `parent`, etc.

---

## Implementation note: storage distribution

*From `quotes.md`.*

L0 and L1 are both in Postgres as *nodes with metadata and edges*. Only the raw blobs of source artifacts go to S3. The split is:

- **Postgres** = the graph (all nodes + all edges, L0 and L1). Content_type, encoding, origin, parent, provenance — everything that makes the graph queryable.
- **S3** = blob store (raw bytes only, keyed by SHA-256 hash). Referenced by L0 source nodes but not part of graph traversal.
- **FalkorDB** = the semantic index (L2 projection).

This means "one graph, three regions" is correct architecturally, not just philosophically: the regions span storage boundaries but the graph is one thing. Any node in Postgres can point to its blob in S3 (if it is a source) or to other nodes (if it is derived). The API treats it all as one data structure.

The L0 tree invariant ("each source node has at most one parent") is enforced in Postgres, where the edges actually live. S3 does not need to know about the tree — it is just a content-addressed blob store.

Update §4.1 during next pass to reflect this cleaner mental model:

- **§4.1.1** should describe S3 as *the blob store*, not as Level 0. Blobs referenced by hash.
- **§4.1.2** should describe Postgres as holding *the entire graph structure* — L0 source nodes with blob references, L1 derived nodes, and all provenance edges between them. The node authority for the whole DAG, not just Level 1.
- **§4.1.3** FalkorDB remains the L2 semantic graph projection.

The storage split is about *byte payload* (S3 for blobs, Postgres for metadata and structure), not about *logical level*. L0 and L1 share the same Postgres tables because they share the same graph.

---

## Implementation note: dark storage + content-addressed blob pool

*From `quotes.md`.*

Refinement of the storage distribution. S3 is pure content-addressed dark storage — nobody lists it, nobody browses it. The API is the only door. All access patterns reduce to GET/PUT/HEAD by hash.

**Ingest is to the API, always.** Workers never touch S3 or Postgres directly. The API:

1. Computes the hash of the incoming blob.
2. Idempotently PUTs to S3 (no-op if hash is already there).
3. Creates a Postgres node with metadata and the hash pointing at the S3 blob.

Workers don't need S3 credentials. Workers don't know S3 exists. That is what "dark storage" means — it is hidden backend infrastructure, not part of any ACL surface.

**Defining invariant:** *if it is not in Postgres, it is not there.* Postgres is the complete index of what exists. An orphaned S3 blob (somehow present without a Postgres node) is unreachable through the API. Content-addressed storage means orphans are benign — they take space but can't be referenced. GC is optional: a Postgres query that finds hashes in S3 not referenced by any node.

**L1 blobs go to S3 too.** Summaries, normalized conversations, OCR text, transcripts, extracted fact text — all are content blobs. They get the same treatment as L0 blobs: content-addressed in S3, referenced by hash in Postgres. This keeps Postgres slim.

**The rule: Postgres = graph topology + metadata + indices. S3 = content.**

What stays in Postgres:
- Graph structure (nodes + edges)
- Small queryable metadata (content_type, encoding, origin, timestamps, parent, tags, conviction scores, validity windows)
- Full-text search indices (tsvector; see caveat below)
- Vector embeddings (pgvector — small, derived)

What goes to S3:
- L0 source bytes (original artifacts)
- L1 normalized content (conversation text, OCR, transcripts)
- L1 derived content (summaries, fact text, entity descriptions)

**Caching at the API level.** Content-addressed means cache invalidation is impossible by construction — content at hash X is content at hash X, forever. Pure LRU. Three-tier: API process memory → local disk → S3. Reloads are deterministic, eviction is safe. Hot working set is typically small.

**Caveats:**
- Full-text search wants text in the same row as the tsvector. Probably store extracted text in Postgres for indexing *and* in S3 as canonical blob. tsvector plus plain text is cheap; it keeps text search self-contained.
- Vector embeddings are tiny, stay in Postgres with pgvector.

**Consequences:**
- Postgres rows become uniform: metadata + hash, a few hundred bytes each. The graph fits in RAM at personal/project scale.
- Backup asymmetry: Postgres is small and frequent; S3 is bulky and occasional.
- Forking Postgres stays cheap — one S3 blob pool, many graph instances. Experiments, A/B tests, development branches, all share the same content.
- Storage abstraction is minimal — S3, R2, Backblaze, IPFS, local filesystem, anything that supports content-addressed GET/PUT/HEAD. Swapping backends is trivial because the interface is small.

**Supersedes earlier thinking** about ACL-split between ingest workers and backend (where ingest workers had S3 `PutObject`). Under dark storage, *no worker ever touches S3*. The API is the only S3 client.

---

## Implementation note: Postgres as tunable cache over S3

*From `quotes.md`.*

Refinement: content duplication in Postgres is not an architectural commitment but a runtime cache policy. The threshold (what size of blob gets cached inline) is a config knob that can be raised or lowered at runtime without data loss.

**Every node carries fields related to content:**
- `content_hash` — SHA-256 pointing at the blob in S3 (canonical storage)
- `content_size` — size in bytes, for policy queries
- `encoding` — format identifier; used to determine cache eligibility (see below)
- `content_cached` — `text` column holding inlined text content, NULL if not cached or not text

**Encoding is MIME-style: `class/format`.** Borrowed directly from HTTP's Content-Type convention. The top-level class indicates what kind of content it is; the subtype indicates the specific format:

```
text/eml          text/chatgpt       text/whatsapp
text/normalized   text/markdown      text/plain       text/json
image/png         image/jpeg         image/heic
audio/wav         audio/mp3
video/mp4
application/pdf   application/dkb-csv
```

**Cache eligibility falls out of the naming scheme:**

```sql
WHERE encoding LIKE 'text/%'
```

Anything with prefix `text/` is cacheable. Everything else is S3-only. No hardcoded enum, no lookup table, no `is_text_content` column. The policy is expressed in the naming convention. New text encodings (`text/rss`, `text/ical`) become cacheable automatically. New binary encodings (`image/avif`) stay in S3 automatically.

**Bonus:** the encoding field becomes self-describing for consumers. An API endpoint serving the blob can set the HTTP `Content-Type` header directly — no translation needed. A worker dispatching by content type knows the handler family from the class prefix.

**The threshold is cache-fill policy.** Raise from 8 KB to 32 KB: a background pass fills the cache for eligible (text) nodes.

```sql
SELECT id, content_hash, content_size FROM nodes
WHERE content_size <= 32768
  AND encoding LIKE 'text/%'
  AND content_cached IS NULL;
```

Lower from 32 KB to 8 KB: a background pass evicts.

```sql
SELECT id FROM nodes
WHERE content_size > 8192 AND content_cached IS NOT NULL;
```

**Properties:**
- Policy is queryable (SQL shows exactly what is cached).
- Policy is reversible (raise/lower threshold is just fill/evict; S3 always holds canonical content).
- Multiple policies can coexist (cache summaries always, cache conversations under 32 KB, never cache transcripts — each a WHERE clause).
- Per-node pinning is easy (a `pin` flag column). Hot content above threshold can be pinned.
- Partial cache is safe. API falls back to S3 on miss. No correctness dependency on cache state.
- Cost/performance tuning is live. Adjust threshold under memory or latency pressure. No downtime.

**Schema suggestion:** split the cache from the main nodes table. A lean `nodes` table with metadata + hash + size. A separate `node_content_cache` table keyed by hash. Two wins:
1. Cache operations don't cause page I/O or row locking on graph metadata.
2. Deduplication by hash — if multiple nodes reference the same blob (possible with content-addressing), they share a single cache entry.

**Binary content is never in Postgres.** A PNG stays in S3. Its text interpretation (OCR output) is a separate derived node with its own hash, its own `encoding: text`, its own cache row. The graph naturally distinguishes the binary source from its textual interpretation — both preserved with provenance. SQL never operates on binary bytes, only on their text derivations.

**Summary:** S3 is canonical, stores all content (text and binary). Postgres is a tunable cache over text content only, plus the graph structure itself. Cache eligibility is determined by encoding. Binary encodings never cache. Text encodings cache up to a runtime-tunable size threshold. Text search operates on cached text. Binary content access always goes through S3. Nothing is lost by changing the threshold because S3 is always the source of truth.

---

# Part E — Branching, forking, single-head maintenance

## Branching Over Shared Storage

*From `technical-notes.md`.*

### One S3 blob pool per branch, with read-through

```
S3 main (append-only, published, notarized)
  ↑ read-through fallback
S3 dev (own bucket, only new blobs)
  ↑ read-through fallback
S3 experiment (own bucket, only new blobs)
```

Each branch has its own Postgres instance (or schema) AND its own S3 bucket. Read-through: branch S3 miss → falls through to main S3. Transparent to the API.

### Main S3 grows only at merge

Side branches accumulate blobs in their own S3. Main S3 is never polluted by experimental work. At merge (head publish), missing hashes are copied from side S3 to main S3. Content-addressed means: no duplicate possible, no conflict possible. Pure append.

### Purge = delete side storage

Drop the Postgres branch. Delete the side S3 bucket. Main is untouched. No orphan scan needed.

### Dev workflow (Git-like)

1. Publish head N → blockchain notarization
2. Fork from head N → new Postgres + new S3 bucket (with read-through to main S3)
3. Run experimental workers → new nodes in branch, new blobs in branch S3
4. Evaluate results
5. Good → merge to main: copy Postgres rows, copy missing S3 blobs to main S3
6. Bad → drop branch: delete Postgres, delete S3 bucket. Zero cost.

### Merge is trivial
Nodes are content-addressed. Transferring a node from dev to main means: copy the Postgres row (the hash is the same because the content is the same). Copy the S3 blob if main S3 doesn't have it yet. No conflict resolution needed as long as the inputs exist in the target branch — and they do, because both branches forked from the same head.

### The layering

| Layer | Main | Side Branch |
|---|---|---|
| Blockchain | Head hashes | — |
| Postgres | Production graph | Fork from head N |
| S3 | All published blobs | Only new blobs, read-through to main |

---

## Branches

*From `notes.md`.*

A branch is a named, mutable Postgres pointer to a head hash:

```
branches table:
  name              -- e.g. "main", "experiment/q2-redaction"
  current_head_hash -- mutable pointer
  owner / acl
```

User queries can hand in either a hash or a branch name; branch names resolve
to their `current_head_hash` via Postgres lookup, then the server proceeds
with `(h, scope)` materialization as usual.

**Branches are pure metadata — not part of the ADT.** The structural
abstraction is `RG_h` (hash-rooted). Branches are user convenience for
tracking "the current head" of an evolving graph, and for avoiding
unwanted divergence among independent appenders.

**No structural lineage.** Branches do *not* carry parent-branch pointers.
Every hash already pulls its full provenance closure from $\mathcal{U}$, so
branch-level lineage tracking would be redundant.

**Cache implications:**

- Cache content is keyed by `(h, scope_id)`, branch-agnostic.
- Long-running cached views may use the branch name as a *refresh trigger*:
  "branch X advanced from `h_old` to `h_new`, extend my cache from `h_new`."
  That's a cache strategy concern, not a structural input.

---

## Single-head maintenance strategies

*From `notes.md`.*

The foundation paper commits to: every $\text{RG}_h$ has a single root $h$.
The head mechanism maintains this — each branch advance generates a fresh
head claim whose `contribution/head` edges name all currently-open heads;
the branch updates to point at the new head. Implementations must handle
concurrent writes:

**Strategy A — Sequenced writes.** A single-writer constraint per branch
prevents multi-head states from arising at all. Each append happens against
the current single head, which then advances via a fresh head claim.
Simplest; throughput-bound at the writer.

**Strategy B — Merge-heads on demand.** Concurrent appends produce
multiple open heads transiently in $\mathcal{U}$. On branch advance / read-of-branch,
the implementation generates a head claim with `contribution/head` edges to all
currently-open heads. Concurrent throughput high; brief multi-head intervals
tolerated.

**Strategy C — Auto-head at commit.** Every appender (atomically) appends
its claim AND generates a head claim whose `contribution/head` edges name the
post-append open-head set. Requires careful concurrency control to avoid stale
head sets racing against just-committed claims; commit retries on
concurrent-modification likely.

All three preserve the foundation invariant; they trade throughput, latency,
and coordination cost differently.

## `contribution/head` storage in Neo4j

*From `notes.md`.*

Open implementation question to benchmark — note that as `contribution/*` edges,
they are uniform with other `contribution/*` edges at the parser level; the
distinction (structural vs other) is in the subtype:

**Option Ia — first-class Neo4j edges.** Stored like any other `contribution/*`
edge; Cypher queries for semantic content filter them out via
`WHERE NOT type = 'contribution/head'`. Pro: full structural uniformity, easy
DAG validation. Con: filter overhead on every semantic query.

**Option Ib — node property.** Store the open-head hashes as a list property on
the head claim (`heads: [hash, hash, ...]`); reconstruct edge form only
for DAG validation / hash recomputation. Pro: semantic queries automatically
clean (no filter); lighter storage. Con: violates "everything is edges"
uniformity at the storage layer; DAG validation walks property-not-edges.

Foundation-equivalent; pick by benchmarking. Note that (Ib) is structurally
equivalent to (Ia) — a list-of-hashes-on-a-node is isomorphic to a set of
edges with `target=hash`. Same data, different storage shape.

---

# Part F — Auth scope, predicate-filtered views

## Predicate-Filtered Views (auth-scope and beyond)

*From `notes.md`.*

**Mechanism:** for each filter predicate, maintain a materialized Neo4j graph
containing only the claims that satisfy the predicate. Named after the
canonicalized predicate. Standalone graph — no filter applied at query time.

The predicate is any equation over node or edge fields — `role = analyst`,
`type != secret`, `project = foo`, etc. Auth-scoping is one instance:
the predicate encodes "what this auth identity is allowed to see".

**Population:** lazy, read-through. On first access (or on a miss for a hash
not yet in the scoped graph), the server walks the master graph from the
requested hash, applies the predicate, and fills the missing reachable
subset into the scoped graph. Subsequent reads hit the scoped graph directly.

**Garbage collection:** scoped graphs are pure caches. Idle for *n* days →
delete. Reconstructible at any time from master + predicate.

**Cardinality:** cost is bounded by the number of distinct *active*
predicates, not by the number of users. RBAC fits naturally — one scoped
graph per role. Per-user predicates are the same mechanism but multiply
cache count by |users|.

**Storage layers:**

- **Neo4j** holds the master graph and the scoped-graph caches.
- **Postgres** holds the administrative/access/user layer:
  - Auth-scope registry — `(scope_id, predicate_expression)`.
  - User-to-scope mapping — `(user_id, scope_id)` for RBAC.
  - Scope-to-Neo4j-graph mapping — `(scope_id, neo4j_graph_name)`.

Postgres is the mutable management state; Neo4j holds the immutable claim
graph plus its derived caches.

**Cache key — content-addressed:** `scope_id = H(canonical(predicate))`. The
scoped Neo4j graph is *named by* its predicate's hash, not by a free-form
identifier. Consequence: editing a predicate produces a different `scope_id`,
which is structurally a different (empty) cache — no invalidation logic
needed. Old scoped graphs become orphans on predicate change and are eligible
for GC. Same content-addressing trick the master graph uses on its claims,
applied one layer up to the cache itself.

**Scope DSL (leaf predicates):** simple expression language over node fields:
`= != < > ≤ ≥ ∃ ∧ ∨ ¬`. Canonicalized as an AST encoded in CBOR Deterministic
to match the rest of the ADT's serialization. Different surface syntaxes that
canonicalize to the same AST yield the same `scope_id`.

The leaf predicate composes with the visibility-propagation rule from D5
(a node is visible iff it satisfies the leaf predicate AND all its provenance
ancestors are visible). The DSL doesn't need traversal operators — propagation
is handled by the structural rule on top of the leaf filter.

**Server-enforced scope (security guarantee):** the user does not specify a
scope at query time. Auth identity → role → `scope_id` (Postgres lookup);
server applies the `scope_id` automatically. There is no "request elevated
scope" path — elevation means a different role assignment, which means a
different `scope_id`, which means a different cache. No escape hatch. Visibility
is a structural property, not a policy property.

**Vocabulary vs. binding:**

- *Vocabulary* — what scopes *exist* as definable filters. Stored in Postgres
  (`auth_scopes` table or equivalent), keyed by `scope_id`.
- *Binding* — which scope is *forced onto* each user. Stored in Postgres as
  `(role, scope_id)` and `(user, role)` mappings.

The vocabulary alone is not a security boundary; without binding enforcement,
a user could pick the most permissive scope. Binding is mandatory; vocabulary
is the menu the binding picks from.

**Combined view materialization (one sweep, P-then-S):** for a query
`(h, scope)`, the visible set is

```
closure(h, U)
  ∩ scope.predicate                 -- auth filter (extrinsic)
  ∖ { t : ∃ e ∈ closure with        -- prune filter (intrinsic)
          e.type = contribution/prune
          and e.reference = t }
```

Single walk over the closure. Collect prune-references and evaluate scope
predicate independently against the *original closure*; then subtract both.
Order matters in edge cases: pruning is *scope-resistant*. If the scope
predicate would filter a prune-claim itself, the prune's *effect* still
applies (the reference stays excluded); only the prune-claim's *content* is
hidden from the user. Pruning is a structural decision about $\mathcal{U}$;
scope is per-viewer.

This means the auth-scope cache mechanism handles pruning for free — the same
walk that lazy-fills the scoped graph also sweeps `contribution/prune` edges.
No separate infrastructure needed.

---

## Auth-Scoped Visibility and Merkle Compatibility

*From `technical-notes.md`.*

Auth-scoped visibility (§3.4: a node derived from a confidential source is automatically confidential) is *compatible* with the Merkle-DAG, not in conflict with it.

A user receives a verifiable subgraph: full nodes with content for everything in scope. For branches outside their scope, they see only the hash — enough to verify the integrity of their own subgraph, but no content access. This is exactly how Merkle proofs work in other systems: you don't need the entire tree, only the hashes of the branches you can't see, to verify the branches you can see.

```
[hash_only] ← confidential node, user sees only hash
     ↓
[full node] ← derived, user has access
     ↓
[full node] ← user has access
```

The user can verify: "my subgraph is intact, it builds on a node with hash X whose content I don't know." Integrity is provable without transparency. Only the server sees everything.

This means auth scoping and Merkle integrity are complementary: the Merkle structure is what *enables* verifiable partial views, rather than conflicting with them.

---

# Part G — Storage discipline (writes-only-in-𝒰)

*From `notes.md`.*

The principle that decided the auth-scope architecture (and the rejected
"scope-as-node" exploration):

> $\mathcal{U}$ contains only *write events with provenance* — claims made by a
> contributor at a moment in time, with reasoning, frozen forever. Everything
> driven by *read-time semantics* belongs in Postgres.

Applied:

- **In $\mathcal{U}$:** ordinary claims, prune-claims (claims with
  `contribution/prune` edges — genuine write events: a contributor decided to
  mark references unresolvable, with reasons and provenance).
- **In Postgres:** scope predicates, role-to-scope bindings, user-to-role
  mappings, branch heads, materialized-view caches, access logs.

Test: *is X a write event with provenance — a contributor's decision recorded
at a moment, immutable from then on?* If yes, it goes in $\mathcal{U}$. If
it's admin configuration, runtime state, or read-time derivable, it goes in
Postgres.

Reads happen orders of magnitude more often than writes; recording every
read-side concern as an immutable claim would balloon $\mathcal{U}$ with
operational bookkeeping unrelated to knowledge. This rule keeps the substrate
clean.

**What this is NOT:** predicate-filtered views are *visibility filtering*,
not pruning. The scoped graph contains no prune-claims; the master claims it
omits are simply absent from the view. Pruning is a separate mechanism
(claims that mark targets as unresolvable in a given view) and composes with
predicate filtering rather than replacing it.

**Status in `ranke-graph`:** the foundation paper establishes only that
subgraph views over the master are well-formed (§6.4 hash-set algebra). The
predicate-filtered cache is a `rankedb` mechanism for serving such views.

---

# Part H — Content Type Taxonomy

*From `notes.md`. Originally moved from `01-ranke-graph/notes.md` on 2026-05-04 — taxonomy was scoped out of P0 (it is not load-bearing for the ADT) and lives here, as opinionated implementation choice for the records use case (email, chat, voice messages, etc.).*

Three-part identifier: `content_type` + `encoding`.

- `content_type` = `category/type` (RankeDB-defined categories, application-extendable types)
- `encoding` = MIME-style `class/format` (application-defined, tells the parser how to read `content`)

### Source types (Level 0)
- `source/conversation` — communicative act with sender/receiver
- `source/media` — perceptual capture, content opaque until processed
- `source/record` — machine/objective observation of world-state
- `source/data` — structured information (defined by exclusion)
- `source/bulk` — container of other sources

### Derivation types (Level 1 — the cognitive layer)
Every L1 node is a thought — the output of a worker interpreting the graph.

**Resolved forms:** `conversation/*`, `image/*`, `video/*`
**Cognitive derivations:** `classification/*`, `observation/*`, `summary/*`, `fact/*`

### Encoding
MIME-style: `text/eml`, `image/png`, `audio/wav`, `application/pdf`.

### Design principle
*Few types, many encodings.* The diversity of the world lives in encodings, not in the type system. Each encoding is a micro-project: a parser.

---

# Part I — Operations: workers, purging, use cases

## Design note: buggy workers, blast radius, and purging

*From `quotes.md`.*

When a worker has a bug, the provenance chain gives you the complete blast radius instantly: every node produced by that worker run (identified by run ID), and every node derived from those nodes, all the way down the DAG. No guessing, no auditing, no "which pages did the LLM touch last Tuesday?"

Two responses:

- **Non-destructive invalidation.** Mark the run's outputs as invalidated. They stay in the graph (immutability preserved) but consumers filter them out. Downstream nodes that depended on them are automatically suspect — their provenance chain passes through invalidated nodes. A replacement worker re-runs on the same sources and produces new nodes alongside the old ones.
- **Destructive purge.** Administrative operation outside the knowledge model. Creates a cropped copy of the graph with the affected branch removed. The original graph should be backed up before purging — the purge is irreversible by design, and the backup preserves the full history for forensic or developmental purposes.

Purging is especially valuable during development: run an experimental worker, inspect the results, purge if they are bad, re-run with improvements. The sources are untouched. The fix is an append on a clean graph, not a migration on a corrupted one.

This is the concrete operational advantage of provenance + immutability + worker run IDs over the "just use git" approach. In a flat-file wiki, a buggy LLM run silently corrupts pages and you have no way to know which pages were touched or what downstream conclusions were built on them. In RankeDB, the DAG *is* the audit trail. The rebuild guarantee (§3.5) means that after purging, the improved worker re-runs on the same L0 sources and the affected branch regenerates cleanly.

Strengthens §3.2 (immutability), §3.5 (rebuild guarantee), §5 (workers), and §7.2 (reprocessing without migration). Also a strong contrast point with Karpathy's LLM Wiki — where the equivalent operation is "revert the whole git repo and hope you find the right commit."

---

## Security Compliance Use Case

*From `technical-notes.md`.*

This architecture is a natural fit for security compliance provenance: recording all security scans, tool configurations, AI analyses with full prompt/response history, and user decisions as a forensically dense, searchable graph.

Key mappings:
- `source/bulk` → SAST/DAST scan report
- `source/record` → individual scan finding, tool config, ruleset version
- `source/conversation` → AI security review with full prompt/response trail
- `source/data` → CVE snapshot, dependency list, SBOM
- `classification/entity` → identified risk, affected component, responsible person
- `observation/contradiction` → Tool A says "safe", Tool B says "critical" — both stay
- `fact/*` → "Vulnerability X marked resolved on date Y by person Z"

Automated peer review through claim decomposition:
- AI analysis → worker decomposes into individual claims → each claim a `fact/claim` node → dedicated challenge agent per claim → produces `observation/challenge` node (confirmed, refuted, or unverifiable with reasoning)

The Merkle-DAG + heads + external timestamping makes the entire audit trail manipulation-proof. In a liability case, the graph proves: we scanned with *this* tool in *this* version with *these* rules, *this* person made *this* decision based on *this* AI analysis with *this* prompt, and the graph had *this* state at *this* time (externally witnessed).

---

# Part J — Reading notes & TODOs per paper section

*From `todo.md`. Extracted from `rankedb.md` to keep the main draft clean. Use for the quote / citation knock-out session.*

## Under 1. The Problem: Knowledge Without Provenance

> **TODO — Write §1 opening (1–2 paragraphs).** State the thesis of Part I: traditional knowledge graphs optimize for *current truth* and treat provenance as metadata; this was defensible in an era of expensive storage and limited query capacity; it is untenable in a regime where knowledge is read and written by machines at scale.
> Introduce the three movements (archival tradition → CS priority → LLM rupture) without yet arguing them.
> Source material: `quotes.md`, Talisman, Ranke.
> Close with a one-line preview of §1.4's resolution.


## Under 1.1 The Archival Tradition

> **TODO — Scaffold §1.1 from `quotes.md`.** The archival profession already understood — for 180 years — that knowledge stripped of its derivation chain decays into hearsay.
> RankeDB is not inventing this insight; it is operationalizing it in a regime the archivists did not live to see.
> Intended arc of the subsection:
>
> - **Ranke** (1795–1886): every claim traces to a critically examined primary source; the discipline of attribution as the foundation of historiography.
> - **Cencetti / *respect des fonds*** (1841): the archival principle that records must be kept in the order and context of their origin — provenance as the organizing principle of memory itself.
> - **Briet** (1951, *Qu'est-ce que la documentation?*): documentation as evidence; the object is not the thing but the trace it leaves.
> - **Wilson** (1968, *Two Kinds of Power*): the bibliographic control problem — the difference between having information and being able to trust it.
> - **Burke** (*A Social History of Knowledge*): knowledge as a historically contingent product of institutions that *ratify* claims through attribution chains.
> - **CLIR / digital preservation**: the modern reframing of provenance as the precondition for long-term trust in digital evidence.
>
> Close with: the archivists spent two centuries working out what it means to preserve the chain of attribution.
> None of them had to contend with a generation of machines that could write faster than the chain could be maintained — but they left the discipline in place for those who would.


## Under 1.2 The CS Priority That Was Never Operationalized

> **TODO — Scaffold §1.2.** Computer science identified provenance as a first-class concern — and built robust machinery for it — but never integrated it as the substrate of a knowledge graph.
> The building blocks are mature; the architectural composition is the gap.
> Intended arc:
>
> - **Cheney (2009).** Provenance as a first-class concern for scientific workflows and database systems. The tooling was built; the KG integration was not.
> - **Pérez, Rubio & Sáenz-Adán (2018, *Knowledge and Information Systems*).** Systematic review of 105 provenance systems; six-dimensional taxonomy (general aspects, data capture, data access, subject, storage, non-functional). Evidence that the components exist — the integration with knowledge representation is what is missing. Cited via [talisman2026](sources/talisman2026provenance). **Priority: H.**
> - **Sikos & Seneviratne (2020). Data Science and Engineering.** *RDF "inherently lacks the mechanism to attach provenance data."* Named graphs, reification, RDF-star, singleton properties, nanopubs — each a workaround, none a substrate. `read_2.pdf`. **Priority: H.**
> - **Takan (2023, PeerJ).** *"Although the issue of immutability in data structures has been frequently studied, there is no research on immutability in knowledge graphs."* `read_2.pdf`. **Priority: H.**
> - **Dibowski (2024, FOIS, Bosch Research).** *"A problem that has not yet adequately been solved for KGs is the traceability and provenance of changes… KGs typically contain the current snapshot of data valid at a certain moment in time only."* `read_2.pdf`. **Priority: M.**
> - **Figay (2025). "When Knowledge Graphs Fail, It's Not the Ontology — It's the Epistemology"** (Medium). Enterprise KGs fail because teams conflate data / information / facts / inferences / unknowns — precisely the conflation RankeDB's three levels separate. `read.pdf`. **Priority: M.**
> - **PDF2's five-angle framing:** the gap has been identified independently from (1) KG engineering, (2) LLM/AI provenance, (3) scientific reproducibility, (4) enterprise AI governance, (5) content addressability for AI. Five fields arrived at the same unmade proposal.
>
> Close with the "groundwork was ready but never assembled" line: the parts have been on the shelf for two decades.
> What has been missing is a design that puts them in the right order.


## Under 1.3 The Rupture: Machines Reading and Writing at Scale

> **TODO — Scaffold §1.3 from `quotes.md` and Talisman.** The old oversight — provenance treated as annotation — was tolerable when knowledge was written by humans at human speed.
> It collapses when knowledge is read and written by machines at scale.
> Intended arc:
>
> - **Talisman (Feb 2026). "Where Provenance Ends, Knowledge Decays."** Substack. Traces provenance from 1841 *respect des fonds* through Semantic Web to LLMs. Key quote: *"LLMs strip provenance from knowledge — systematically, architecturally, and by design."* RAG addresses retrieval-level provenance while *"leaving the deeper layer entirely unattributed."* Closest existing articulation of RankeDB's motivation; proposes no technical design. `read_2.pdf`. **Priority: H — lift framing.**
> - **Vibe citing.** The phenomenon of plausible-looking citations generated without a verifiable chain — the visible symptom of a substrate that does not demand attribution.
> - **Knowledge network decay / doom loop.** Models trained on the outputs of earlier models, with provenance severed at every generation; the cumulative effect on the integrity of the knowledge commons.
> - **Berners-Lee as foil.** The Semantic Web's promise was machine-readable knowledge; its unmade promise was machine-traceable provenance. What arrived in the LLM era was the opposite: massive scale, zero attribution.
>
> Close with: the severity of the rupture is what changes the calculus.
> Before: provenance-as-substrate would have been a nice-to-have.
> After: it is the minimum response.


## Under 1.4 Convergence: A Foundation, Not a Feature

> **TODO — Write §1.4 closing.** The three movements converge.
> The archival tradition had the insight; the CS literature has the components; the machine-reading/writing era makes the gap urgent.
> A provenance-first foundation is not a refinement — it is the shape that emerges when the three are taken seriously at once.
> Part II describes the foundation; the follow-up papers present the first generation of application that tests whether the philosophy-derived foundation actually bears load.
> The paper is therefore a falsifiable bet: if the assumptions hold, later generations of workers and applications will keep building on the same base; if they do not, the foundation was misjudged.
> Either way, what this paper owes is the argument for why *this* shape is the right one to try.


## Under 2.1 Everything Is Knowledge

> **TODO — Reading for §2.1 (epistemological tradition + the architectural inversion):**
>
> *Two threads to weave in here:*
> *(a) The intellectual lineage of "everything is knowledge" — PDF1 traces a tradition from 1979 TMSes to 2026 AI memory papers that RankeDB sits squarely inside; no existing PKG has operationalized it.*
> *(b) The architectural inversion as the core novelty — PDF2 is entirely dedicated to documenting this as the genuine research gap. **Read PDF2 in full before rewriting this section.** Its opening claim is the spine of this paper:*
>
> > *"No existing system — academic or production — fully implements an architecture where an immutable, append-only provenance DAG serves as the primary data structure for a knowledge system. This represents a real and well-documented research gap, not a solved problem repackaged."*
>
> > *"In every existing system surveyed, the knowledge graph is primary and provenance is secondary metadata attached to it. RankeDB proposes the reverse."*
>
> **Sources — epistemological tradition:**
>
> - **Doyle, J. (1979). "A Truth Maintenance System."** *Artificial Intelligence.* JTMS — dependency network of beliefs and justifications; traces conclusions to premises; propagates revision through the network. **RankeDB's direct intellectual ancestor.** `read.pdf`. **Priority: H.**
> - **de Kleer, J. (1986). "An Assumption-Based TMS."** ATMS extends JTMS to maintain all alternative assumption sets simultaneously — conceptually parallel to RankeDB's add-only preservation of multiple states of belief. `read.pdf`. **Priority: H.**
> - **Alchourrón, Gärdenfors & Makinson (1985). AGM framework.** Formal postulates for rational belief change (expansion, revision, contraction). See SEP entry `plato.stanford.edu/entries/logic-belief-revision/`. `read.pdf`. **Priority: M.**
> - **"Graph-Native Cognitive Memory for AI Agents: Formal Belief Revision Semantics for Versioned Memory Architectures"** (2025-2026, arXiv 2603.17244). Applies AGM postulates to a Neo4j-based memory architecture for AI agents — proves graph memory operations can satisfy formal belief revision axioms. **Closest published work to RankeDB's epistemological framing**, targets AI agent memory rather than personal cognition. `read.pdf`. **Priority: H.**
> - **Carneades argumentation framework.** Varying proof standards per statement — direct analog to per-entity conviction levels. `read.pdf`. **Priority: L.**
> - **ASPIC+ framework.** Strict vs defeasible inference with three attack types (undermining premises, rebutting conclusions, undercutting rule applicability). `read.pdf`. **Priority: L.**
> - **AKReF (2025, arXiv 2506.00713).** Constructs argumentation knowledge graphs from text using ASPIC+. Heterogeneous graphs with argument nodes and attack/support edges. `read.pdf`. **Priority: L.**
> - *PDF1 observation:* the phrase *"thoughts as provenance"* — where synthesized knowledge generates semantic edges whose provenance the thought becomes — **appears genuinely unique**. No other system explicitly frames the act of thinking as evidence generation. Make this explicit here. **Priority: H.**
>
> **Sources — architectural inversion contrast:**
>
> - **RDF-star (being standardized as RDF 1.2).** Embedded triples: `<<:bob :knows :alice>> :source :wikipedia`. ~50% data volume reduction vs classical reification (Ontotext benchmarks, GraphDB 11.2 docs). *Still an annotation mechanism, not a derivation chain system — sharpen this contrast.* `read.pdf` + `read_2.pdf`. **Priority: M.**
> - **Named graphs (Carroll et al. 2005, ACM 1060745.1060835).** Foundational RDF provenance mechanism. W3C Provenance WG (2011) explicitly documented the granularity mismatch: named graphs operate at document level, triple-level requires verbose singleton graphs, derived triples have no natural provenance "home." `read.pdf`. **Priority: M.**
> - **Palantir Foundry.** Tracks complete dataset-level lineage from raw ingestion through all transformations with interactive DAG visualization. **Dataset-level, not fact-level** — sharpen the contrast. `read.pdf`. **Priority: L.**
> - **Google Knowledge Vault (2014) / NELL (CMU).** Per-fact confidence and extraction source tracking, but no complete transformation lineage. `read.pdf`. **Priority: L.**
> - **UaG — Uncertainty-Aware Graph (CIKM 2024).** Conformal prediction in KG-LLM reasoning; uses uncertainty to **guide** reasoning paths. *PDF1: "the closest academic work to RankeDB's provenance as query direction."* `read.pdf`. **Priority: M — elevates the "provenance guides query behavior" claim beyond mere filtering.**
> - **Dagstuhl survey (2024) on uncertainty in KG construction.** Documents how confidence scores propagate through construction pipelines. Facebook's KG removes facts below confidence thresholds. Treats provenance as a filter, not as substrate — sharpen distinction. `read.pdf`. **Priority: L.**


## Under 2.2 Immutability and Accumulation

> **TODO — Reading for §2.2 (immutability as foundational principle):**
>
> - **Helland, P. (2015). "Immutability Changes Everything."** *CIDR 2015.* Already in references. Key quotes to lift: *"accountants don't use erasers"* and *"the truth is the log; the database is a cache of a subset of the log."* **PDF2 explicitly notes: "No subsequent work has explicitly applied Helland's thesis to knowledge graphs, despite its enormous influence on event sourcing and distributed systems."** RankeDB would be the first. `read_2.pdf`. **Priority: H.**
> - **Nelson, T. (1960-present). Project Xanadu.** Specified immutable, add-only content space where documents are lists of pointers to regions in an "ever-growing" store; transclusion maintains *"visible provenance to the source"*; every connection bidirectional. **PDF2: "arguably the direct ancestor of what RankeDB proposes."** Cautionary lesson: Xanadu's refusal to compromise prevented adoption while the simpler Web prevailed. `read_2.pdf`. **Priority: H — currently missing from §6, must add.**
> - **Hickey, R. (2012). Datomic.** Already cited. PDF2 nuance to add: Datomic captures the *temporal* dimension of knowledge (what changed, when) but **not the *epistemic* dimension** (how knowledge was derived, from what evidence, by what process). `read_2.pdf`. **Priority: M.**
> - **Records in Contexts (RiC-O v1.1, May 2025, ICA).** International Council on Archives standard. Describes archival world as *"a graph of interconnected things"*; models `rico:ProvenanceRelation` as first-class OWL relation type. Archival profession's 180-year-old *respect des fonds* principle rendered as a knowledge graph standard — a conceptual ancestor of RankeDB from a completely different intellectual tradition. `read_2.pdf`. **Priority: M — adds archival-theory legitimacy, currently missing.**
> - **Google Always-On Memory Agent (March 2026, open-source).** The explicit opposite of RankeDB. ConsolidateAgent runs every 30 minutes, merging duplicates and dropping information to *"mimic how the human brain processes information during sleep."* No vector DB, no embeddings — the LLM reads, thinks, and writes structured memory into SQLite, making the **LLM the truth arbiter**. RankeDB's motto inversion: *"the graph is the truth, the LLM translates."* `read.pdf`. **Priority: H — cite explicitly as anti-RankeDB in §7.1 contrast.**
> - **XTDB (formerly CruxDB).** Append-only log with native bitemporal support. Rare precedent for add-only temporal database. `read.pdf`. **Priority: L.**
> - **DefraDB / Arweave.** Content-addressable distributed storage with immutability guarantees — check how they handle provenance. `read_2.pdf`. **Priority: L.**


## Under 2.3 Under-Prescription: A Base for Evolution

> **TODO — Reading for §2.3 (reprocessing vs migration — GraphRAG family comparison):**
>
> The GraphRAG landscape is the cleanest contrast point for RankeDB's reprocessing property.
>
> - **Edge et al. (April 2024). "From Local to Global: A Graph RAG Approach to Query-Focused Summarization."** Microsoft Research foundational GraphRAG paper. LLM entity/relation extraction + Leiden community detection + pre-built community summaries. `read.pdf`. **Priority: M.**
> - **DRIFT Search (Microsoft, October 2024).** Combines global and local retrieval with iterative refinement. Reference: microsoft.com/en-us/research/blog/introducing-drift-search. `read.pdf`. **Priority: L.**
> - **LazyGraphRAG (Microsoft, November 2024).** Reduces indexing costs to **0.1% of full GraphRAG** via NLP-based extraction instead of LLM summarization. lianpr.com/en/news/detail/3224. `read.pdf`. **Priority: L — cite as efficiency-trades-history example.**
> - The crucial pattern: **all GraphRAG variants require full reprocessing when the extractor improves.** Contrast explicitly with RankeDB's append semantics.


## Under 3. Architecture

> **TODO — Reading for §2 (three-layer architecture precedents):**
>
> - **Enterprise Knowledge consultancy (2024-2025). "Graph Analytics in the Semantic Layer: An Architectural Framework for Knowledge Intelligence."** Documents a "three-graph architecture": metadata graphs (lineage, ownership) / knowledge graphs (ontology-backed entities) / analytics graphs (pattern detection). *Key distinction: operates three graph types in parallel, whereas RankeDB arranges three layers sequentially.* `read.pdf`. **Priority: M.**
> - **IntuitionLabs (2025) biotech/pharma KG pattern.** Data lake → semantic integration (graph DB) → service layer. Closer to RankeDB's sequential flow. `read.pdf`. **Priority: L.**
> - **Ant Group OpenSPG/KGFabric (VLDB 2024).** Industrial-scale integration of property graph performance with semantic constraints; **98% storage reduction vs Neo4j** via hybrid compression. `read.pdf`. **Priority: L — cite for scale validation.**
> - **SPADE (SRI International).** Provenance auditing system storing derivation chains in Neo4j OR Postgres, abstracting over both through its QuickGrail query language (ACM Queue 3476885). *The closest direct analog to RankeDB's split-store approach at the implementation level (cf. §4), though RankeDB treats the split as pure implementation detail.* `read.pdf`. **Priority: H — must cite in §6, currently missing.**
> - **dbt Semantic Layer, Cube.dev, AtScale.** Analytics semantic layer tradition — abstraction over warehouse data into business metrics. January 2026 **Open Semantic Interchange (OSI)** spec supported by 40+ companies (Snowflake, Salesforce, Databricks). Shares DNA with transformation lineage but at dataset level, not per-fact. `read.pdf`. **Priority: L.**


## Under 6. Related Work

> **TODO — §6 is currently under-cited relative to PDF1 (8 research areas) and PDF2 (5 closest systems + 5-angle gap).
> New subsections to add: Quit Store, Blue Brain Nexus, SPADE, Fluree detail, Xanadu, Helland, RiC-O, PROV-AGENT, Bitemporal KGs (AeonG/BiTRDF), Personal Knowledge Graph community (Balog/Stavanger), JTMS/ATMS/AGM, Senzing, Tools-for-Thought lineage.
> See per-subsection TODOs below.**


## Under 6.1 Temporal Knowledge Graphs: Graphiti/Zep

> **TODO — Reading for §6.1 (Graphiti/Zep expansion):**
>
> - **"Graphiti: Knowledge Graph Memory for AI Agents"** (Rasmussen et al., arXiv 2501.13956, January 2025). **Read in full before finalizing §6.1.** `read_2.pdf`. **Priority: H.**
> - `read.pdf` and `read_2.pdf` detail to add:
>   - **94.8% on the DMR benchmark**, P95 retrieval latency **300ms**.
>   - Three-layer architecture paralleling RankeDB: episodic subgraph (raw events) / semantic subgraph (extracted facts) / community subgraph.
>   - Uses the **same graph databases RankeDB specifies** (Neo4j OR FalkorDB).
>   - Bi-temporal `t_valid`/`t_invalid` fields; old facts *"invalidated, not deleted."*
>   - **55-60% architectural overlap** with RankeDB (PDF2 estimate).
>   - *Key differentiator:* Graphiti performs **destructive entity summary updates** (arXiv 2501.13956 explicit). This is the precise distinction RankeDB maintains.
>   - Graphiti's **"non-lossy" design philosophy** is PDF2's identified "closest articulation" of RankeDB's accumulation bet — but Graphiti still consolidates at entity level.
> - **Priority: H — Graphiti is the single most important comparison in the paper.**


## Under 6.2 Versioned Knowledge Bases: TerminusDB

> **TODO — Reading for §6.2 (TerminusDB expansion):**
>
> - **Mendel-Gleason et al. TerminusDB technical paper.** Already in references. Read before finalizing §6.2.
> - `read_2.pdf` detail to add:
>   - Origin: Trinity College Dublin, Horizon 2020 ALIGNED project (owlapps 62518551).
>   - Uses append-only **succinct data structures with delta encoding**.
>   - Every transaction creates a new immutable layer.
>   - **~75-80% architectural overlap with RankeDB — highest of all surveyed systems.**
>   - Missing: no content-addressable blob store for raw artifacts; no concept of transformation workers or AI processors as first-class participants; foundational structure is a *versioned RDF graph*, not a provenance DAG; tracks *what* changed but not *why or how knowledge was derived*.
> - **Priority: H.**


## Under 6.3 Immutable Databases: Datomic and Fluree

> **TODO — Reading for §6.3 (Datomic/Fluree expansion + Helland):**
>
> - **Helland, P. (2015). "Immutability Changes Everything."** CIDR 2015. `cidrdb.org/cidr2015/Papers/CIDR15_Paper16.pdf` + ACM Queue 2884038. **Read in full — this is the theoretical foundation of RankeDB's §2.2.** Core quotes: *"accountants don't use erasers"*, *"the truth is the log; the database is a cache of a subset of the log."* **PDF2 explicitly: "No subsequent work has explicitly applied Helland's thesis to knowledge graphs, despite its enormous influence."** RankeDB is the first. `read_2.pdf`. **Priority: H.**
> - **Nubank case study.** Engineers applied Datomic to microservice dependency graphs and used the phrase *"immutable knowledge databases"* — closest vernacular antecedent for RankeDB's framing. `read_2.pdf`. **Priority: L.**
> - `read_2.pdf` Fluree detail: founded 2017, supports RDF + JSON-LD + SPARQL + SHACL validation. Every update cryptographically chained, enabling time-travel and verifiable data history. **PDF2: "perhaps the closest *production database* to the RankeDB vision."** But Fluree's immutability operates at the transactional ledger level, not at the level of a provenance DAG tracking derivation chains. No separate content-addressable blob store. AI/ML processors not modeled as first-class graph participants. **Priority: M.**
> - Datomic nuance from PDF2: captures the *temporal* dimension (what changed, when) but **not the *epistemic* dimension** (how knowledge was derived, from what evidence, by what process). This is the distinction RankeDB introduces. **Priority: M.**


## Under 6.4 W3C PROV-DM

> **TODO — Reading for §6.4 (PROV-DM expansion):**
>
> - **Sikos & Seneviratne (2020). "Provenance-Aware Knowledge Representation: A Survey of Data Models and Contextualized Knowledge Graphs."** *Data Science and Engineering.* **Already in references. Read in full — this is the canonical survey of every RDF-provenance workaround.** Key finding: *RDF "inherently lacks the mechanism to attach provenance data"* — reviews named graphs, reification, RDF-star, singleton properties, nanopublications, finds none fully satisfactory. `read_2.pdf`. **Priority: H.**
> - `read.pdf` PROV-O adoption data: **OpenCitations tracks over 2 billion citations using PROV-O**; 2025 Nature Scientific Data paper aligned PROV-O with the ISO-standard Basic Formal Ontology (BFO). `read.pdf`. **Priority: M.**
> - **Carroll et al. (2005).** *"Named Graphs, Provenance and Trust"* (ACM 10.1145/1060745.1060835). Foundational paper establishing named graphs for provenance. W3C Provenance Working Group (2011) documented the granularity mismatch. `read.pdf`. **Priority: M.**
> - **RDF-star / PROV-STAR as bolt-on provenance.** PDF2 gap table: "Nanopubs are flat collections; PROV-STAR is a bolt-on." Contrast with RankeDB's substrate approach. `read_2.pdf`. **Priority: M.**
> - **PROV-AGENT (Souza et al., IEEE e-Science 2025, arXiv 2508.02866).** First provenance framework for AI agent workflows; extends W3C PROV with agent-specific metadata. *Operates within traditional workflow orchestration rather than proposing a provenance-first architecture.* `read_2.pdf`. **Priority: M — currently missing from §6, must add.**


## Under 6.5 Nanopublications

> **TODO — Reading for §6.5 (Nanopublications expansion):**
>
> - **Kuhn & Dumontier (2014). "Trusty URIs."** ESWC 2014. Already in references. Read for the content-addressability mechanism (cryptographic hash URIs).
> - `read_2.pdf` detail: over **10 million nanopublications** exist, primarily in life sciences. Each nanopub contains three named RDF graphs: assertion, provenance, publication info. **Priority: M.**
> - **2025 extension: "Nanopublications with Knowledge Provenance"** (International Journal of Digital Libraries, Springer s00799-025-00431-x). Extends with trust networks where multiple agents assign truth values on a 0-1 scale — *parallel to RankeDB's conviction levels, though at scientific publication level rather than personal knowledge.* `read.pdf`. **Priority: M — add to references.**


## Under 6.6 TODO: Additional prior art (currently missing from §6, must add)

> **TODO — §6.6.1 Quit Store (AKSW Leipzig):**
>
> - SPARQL 1.1 endpoint backed entirely by Git. RDF named graphs stored as canonicalized N-Quads in Git's SHA-1 content-addressed object store. Automatic W3C PROV-O generation from commit metadata. `quit blame` for per-statement provenance.
> - **~60-65% architectural overlap with RankeDB — second-closest in PDF2.**
> - Literally uses Git's Merkle DAG as storage layer for a KG with provenance.
> - Missing: only structured RDF (not raw artifacts like PDFs); academic prototype with performance limitations; provenance derived from version control metadata, not an explicit derivation DAG.
> - Reference: ScienceDirect S1570826818300416; CEUR-WS Vol-1824 mepdaw_paper_2.pdf. `read_2.pdf`. **Priority: H.**

> **TODO — §6.6.2 Blue Brain Nexus (EPFL):**
>
> - Open-source neuroscience data management platform. Semantic Web Journal 2023. W3C PROV as provenance backbone, SHACL validation, event-sourced streaming architecture. Explicitly treats *"provenance as a first-class citizen."*
> - PDF2: *"deserves special mention as the closest working knowledge platform with provenance aspirations. Even here, the knowledge graph is primary and provenance enriches it — the architectural inversion remains unmade."*
> - Reference: ResearchGate 330751750. `read_2.pdf`. **Priority: M.**

> **TODO — §6.6.3 SPADE (SRI International):**
>
> - Provenance auditing system storing derivation chains in Neo4j OR Postgres, abstracting over both through its QuickGrail query language.
> - **Only existing system with split-store architecture analogous to RankeDB's FalkorDB + Postgres.**
> - Reference: ACM Queue 3476885. `read.pdf`. **Priority: H — currently missing.**

> **TODO — §6.6.4 Project Xanadu (Nelson, 1960-present):**
>
> - Specified immutable, add-only content space; documents as lists of pointers to regions in an ever-growing store; transclusion maintains visible provenance to source; bidirectional connections.
> - **PDF2: "arguably the direct ancestor of what RankeDB proposes — append-only content-addressable storage with provenance as the organizing principle."**
> - Cautionary lesson: Xanadu's refusal to compromise on its complete vision prevented adoption while the simpler WWW prevailed.
> - References: Grokipedia entry on Project Xanadu; WebProNews coverage. `read_2.pdf`. **Priority: H — currently missing.**

> **TODO — §6.6.5 Records in Contexts (RiC-O v1.1, May 2025, ICA):**
>
> - International Council on Archives standard. Describes archival world as *"a graph of interconnected things."*
> - Models `rico:ProvenanceRelation` as first-class OWL relation type for linked data.
> - Archival profession's **180-year-old *respect des fonds* principle** rendered as a knowledge graph standard.
> - Intellectual ancestor from an entirely different tradition than CS. `read_2.pdf`. **Priority: M.**

> **TODO — §6.6.6 Bitemporal Knowledge Graphs: AeonG, BiTRDF, XTDB, OSTRICH:**
>
> - **Chekol et al. (2018)** explicitly identified the bitemporal KG gap: Wikidata uses only valid time, NELL uses only transaction time (ACM 3184558.3191637).
> - **AeonG (Anselma et al., ADBIS 2025).** Extends property graphs with explicit bitemporal timestamps on every element — **9.74% performance overhead** (Università di Torino). Reference: Springer 978-3-032-05281-0_15. **Priority: M.**
> - **BiTRDF (MDPI Mathematics 2025).** Adds both temporal dimensions to RDF. Reference: MDPI 2227-7390/13/13/2109. **Priority: M.**
> - **XTDB (formerly CruxDB).** Append-only log with native bitemporal support — precedent in temporal databases, rare in KG systems. **Priority: L.**
> - **OSTRICH (Taelman et al., Journal of Web Semantics 2018).** Versioned RDF triple store with append-only delta ingestion, three query types across versions (ScienceDirect S1570826818300404). **Priority: L.**
> - **Key framing for RankeDB §6.6.6:** RankeDB achieves **emergent bitemporality through architectural composition** (valid time on L2 edges, transaction time via L1 DAG) — architecturally simpler than explicit bitemporal annotations. `read.pdf`. **Priority: M — this is a distinctive selling point worth a dedicated subsection.**

> **TODO — §6.6.7 Event Sourcing as KG substrate:**
>
> - **Telicent CORE platform.** Event-driven KG using Apache Kafka as the event log backbone, with events flowing through topics into RDF format and multiple derived stores (graph, search, vector). Reference: telicent.io/news/event-driven-knowledge-graphs.
> - **TMForum "Atomic Events" model.** Append-only EAV events with timestamps for building temporal KGs.
> - **Key distinction:** event sourcing stores a *linear sequence* of events per aggregate; a provenance DAG captures a *richer graph* of derivation relationships. **No published work frames event sourcing specifically as a knowledge management pattern.** `read_2.pdf`. **Priority: L.**

> **TODO — §6.6.8 Personal Knowledge Graphs (academic community):**
>
> - **Balog, K. (University of Stavanger).** "Personal Knowledge Graphs: A Research Agenda." ICTIR 2019. Foundational paper.
> - **"An Ecosystem for Personal Knowledge Graphs"** (ScienceDirect 2024, S2666651024000044). Survey defining PKGs around data ownership by single individual and personalized service delivery.
> - **PKG API (WWW Companion 2024, ACM 3589335.3651247).** Proposes RDF-based PKG vocabulary with provenance and access rights.
> - **PDF1 observation:** PKG academic community primarily targets **recommendation and personalization** — not the **cognitive augmentation** RankeDB pursues. RankeDB's position is distinct from the Balog line of work. `read.pdf`. **Priority: M — framing.**

> **TODO — §6.6.9 Truth Maintenance & Belief Revision (intellectual ancestors):**
>
> - **Doyle, J. (1979). JTMS.** *Artificial Intelligence.* Dependency network for beliefs and justifications. **Direct ancestor of RankeDB's provenance model.** `read.pdf`. **Priority: H.**
> - **de Kleer, J. (1986). ATMS.** Maintains all alternative assumption sets simultaneously. **Closest to RankeDB's add-only preservation of competing beliefs.** `read.pdf`. **Priority: H.**
> - **AGM (1985).** Formal postulates for belief change. JSTOR 41487515. `read.pdf`. **Priority: M.**
> - **"Graph-Native Cognitive Memory for AI Agents"** (arXiv 2603.17244, 2025-2026). Applies AGM to Neo4j AI memory. **Closest published work to RankeDB epistemology.** `read.pdf`. **Priority: H.**
> - This section would elevate RankeDB's intellectual lineage beyond database systems to include 45 years of AI knowledge representation work.


## Under 6.7 The Identified Gap

> **TODO — Reading for §6.7 (rewrite with PDF2's 5-angle gap framing):**
>
> PDF2 documents the gap being identified from **five independent research angles**, none of which propose the integrated solution.
> Use this as the structural spine of §6.7:
>
> 1. **Knowledge graph engineering.** Sikos (2020), Takan (2023, PeerJ, *"no research on immutability in knowledge graphs"*), Dibowski (FOIS 2024). All document that provenance in KGs is fundamentally unsolved.
> 2. **LLM / AI provenance.** 2025 Frontiers in Computer Science survey on KG-LLM fusion identifies *"unclear knowledge provenance"* as a key challenge. PROV-AGENT (Souza et al. IEEE e-Science 2025) is the first provenance framework for AI agent workflows.
> 3. **Scientific reproducibility.** **72-83% of researchers acknowledge a reproducibility crisis** (SEC.gov/files/ctf-written-input-knowledge-provenance-protocol-kpp). REPRODUCE-ME ontology (2022), Knowledge Provenance Protocol (KPP 2025) — both DAG-based but domain-specific.
> 4. **Enterprise AI governance.** Amazon Bedrock AgentCore (2025) adopted append-only memory patterns marking outdated memories INVALID rather than deleting. Bolt-on solution.
> 5. **Content addressability for AI.** ISPE article (Jan 2026) advocates content-addressable storage for AI knowledge management, predicts *"AI copilots with built-in provenance: every answer cites the exact CIDs used."* Closest industry-perspective articulation.
>
> - **ICLR 2026 Workshop on Memory for LLM-Based Agentic Systems (MemAgents).** Explicitly calls for research on *"provenance-aware retrieval"* and *"structured memory access control."* **Community recognition of the open problem.** OpenReview U51WxL382H; arXiv 2603.10062. `read_2.pdf`. **Priority: H — cite as evidence that the gap is recognized in 2026 by the top ML venue.**
>
> **Priority: H — this section should become the longest in §6.**
>
> **Property-by-property novelty table (from PDF2 §5):** copy this table directly into §6.7:
>
> | RankeDB Property | Closest Existing System | What's Missing |
> |---|---|---|
> | Content-addressable immutable blob store (SHA256) | IPFS/IPLD, Git, DefraDB | Not integrated with KG layers |
> | Provenance DAG as primary data structure | **Nothing** — all systems treat provenance as secondary | **The core architectural inversion** |
> | Semantic graph with per-edge provenance to DAG | Nanopubs, RDF-star + PROV-STAR | Nanopubs flat; PROV-STAR bolt-on |
> | Strictly append-only, no destructive operations | Datomic, Fluree, Arweave | Not combined with KG + provenance DAG |
> | AI/LLM as just one type of graph processor | PROV-AGENT (2025) | Tracks agent provenance within workflows, not provenance-first |
> | Three-layer architecture (blobs → DAG → semantic graph) | **No system combines all three** | **The unified architecture is novel** |


## Under 7.1 The Context Window Bet

> **TODO — Reading for §7.1 (accumulation vs destructive consolidation — map the opposition):**
>
> PDF1's LLM-driven KG construction section (§7) is **the single most useful source for this subsection**.
> It explicitly places RankeDB at one extreme of a spectrum and Google's Always-On Memory Agent at the other.
>
> - **Google Always-On Memory Agent (March 2026, open-source).** **The anti-RankeDB.** ConsolidateAgent runs every 30 minutes, explicitly merging duplicates and dropping information to *"mimic how the human brain processes information during sleep."* No vector DB, no embeddings — LLM as truth arbiter. References: digit.in/features/general/googles-new-ai-agent-remembers-everything; elephaant.com/blog/google-always-on-memory-agent-vector-db-alternative-2026. `read.pdf`. **Priority: H — cite as explicit counter-design.**
> - **Graphiti "non-lossy" design philosophy** (getzep.com 2025 report). PDF2: *"the closest articulation"* of RankeDB's accumulation bet — but Graphiti still performs destructive entity summary updates. The closest ally; not quite an ally. `read_2.pdf`. **Priority: H.**
> - **Microsoft GraphRAG.** Community summaries are regenerated rather than appended, replacing old versions. Extraction not fully reproducible. Reference: microsoft.com/en-us/research/blog/graphrag-unlocking-llm-discovery-on-narrative-private-data. `read.pdf`. **Priority: M.**
> - **LightRAG (EMNLP 2025).** Entity deduplication merges identical entities with **no history preservation.** lightrag.github.io. `read.pdf`. **Priority: M.**
> - **EDC Framework (Zhang & Soh 2024).** Canonicalization phase explicitly consolidates schema components. `read.pdf`. **Priority: L.**
> - **iText2KG / ATOM (AuvaLab 2025).** Dual-time modeling preserves temporal metadata, but performs entity merging. github.com/AuvaLab/itext2kg. `read.pdf`. **Priority: M.**
> - **Collaborative Memory (arXiv 2505.18279).** Each memory fragment carries immutable provenance attributes — partial alignment with RankeDB. `read.pdf`. **Priority: M.**
> - **Amazon Bedrock AgentCore (2025).** Append-only memory: marks outdated memories INVALID instead of deleting. Bolt-on solution. `aws.amazon.com/blogs/machine-learning/building-smarter-ai-agents-agentcore-long-term-memory-deep-dive`. `read_2.pdf`. **Priority: L.**
>
> *PDF1 key framing to use verbatim:* *"No existing system matches RankeDB's full specification: add-only storage, content-addressable immutable raw sources, no destructive consolidation, conviction-based entity resolution instead of hard merges, and complete inferential history preservation.
> RankeDB's commitment to immutability is more extreme than any published system."*


## Under 7.2 Toward a CRDT-Compatible Architecture

> **TODO — Reading for §7.3 (CRDT connection — currently 1 paragraph, PDF2 says this may be the MOST significant unexplored implication of RankeDB):**
>
> PDF2's §3 "Adjacent architectural concepts" closes with:
>
> > *"A deep and underexplored connection exists between CRDTs and provenance DAGs.
> Shapiro et al.'s foundational CRDT work (2011) formally proved that an add-only monotonic DAG is a CRDT.
> Byzantine Fault Tolerant CRDTs use Merkle-DAGs (hash graphs representing causal partial order among updates) that are structurally identical to content-addressed provenance graphs.
> This connection is **entirely unexploited** in the knowledge management literature — a CRDT-based provenance DAG would enable truly decentralized, coordination-free knowledge management with automatic merge, which may be the most significant unexplored implication of the RankeDB architecture."*
>
> **Consider elevating §7.3 from a single paragraph to its own major section, or spin it off as a companion paper.**
>
> - **Shapiro, Preguiça, Baquero & Zawirski (2011). "Conflict-Free Replicated Data Types."** *Proceedings of the 13th International Symposium on Stabilization, Safety, and Security of Distributed Systems (SSS 2011).* Springer 978-3-642-24550-3_29. **Foundational paper. Formally proves: add-only monotonic DAG is a CRDT.** `read_2.pdf`. **Priority: H — must cite.**
> - **Byzantine Fault Tolerant CRDTs with Merkle-DAGs.** PDF2: "structurally identical to content-addressed provenance graphs." Reference: jzhao.xyz/thoughts/CRDT. `read_2.pdf`. **Priority: H.**
> - **IPFS / IPLD.** Content-addressable DAG substrate used in distributed systems — check how they handle epistemic layer (they don't, but understand the primitives). `read_2.pdf §5 table`. **Priority: M.**
> - **DefraDB.** Content-addressable immutable blob store with knowledge graph aspirations. `read_2.pdf §5 table`. **Priority: L.**
> - **Arweave.** Strictly append-only, no destructive operations, permanent storage. dolthub.com/blog/2022-03-21-immutable-database. `read_2.pdf §5 table`. **Priority: L.**
