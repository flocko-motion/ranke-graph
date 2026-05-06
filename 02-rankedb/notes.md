# P1 — Working notes

*Moved from `01-ranke-graph/notes.md` on 2026-05-04 — taxonomy was scoped out of P0 (it is not load-bearing for the ADT) and lives here, as opinionated implementation choice for the records use case (email, chat, voice messages, etc.).*

---

## Content Type Taxonomy

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

## Predicate-Filtered Views (auth-scope and beyond)

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
          e.type ∈ prune/*
          and e.target = t }
```

Single walk over the closure. Collect prune-targets and evaluate scope
predicate independently against the *original closure*; then subtract both.
Order matters in edge cases: pruning is *scope-resistant*. If the scope
predicate would filter a prune-claim itself, the prune's *effect* still
applies (the target stays excluded); only the prune-claim's *content* is
hidden from the user. Pruning is a structural decision about $\mathcal{U}$;
scope is per-viewer.

This means the auth-scope cache mechanism handles pruning for free — the same
walk that lazy-fills the scoped graph also sweeps `prune/*` edges. No separate
infrastructure needed.

---

## Branches

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

The foundation paper commits to: every $\text{RG}_h$ has a single root $h$.
Throwaway snapshots maintain this — each branch advance generates a fresh
snapshot claim whose `evidence/head` edges name all currently-open heads;
the branch updates to point at the snapshot. Implementations must handle
concurrent writes:

**Strategy A — Sequenced writes.** A single-writer constraint per branch
prevents multi-head states from arising at all. Each append happens against
the current single head, which then advances via a fresh snapshot.
Simplest; throughput-bound at the writer.

**Strategy B — Merge-snapshots on demand.** Concurrent appends produce
multiple heads transiently in $\mathcal{U}$. On branch advance / read-of-branch,
the implementation generates a snapshot with `evidence/head` edges to all
current heads. Concurrent throughput high; brief multi-head intervals
tolerated.

**Strategy C — Auto-snapshot at commit.** Every appender (atomically) appends
its claim AND generates a snapshot whose `evidence/head` edges name the
post-append head set. Requires careful concurrency control to avoid stale
head sets racing against just-committed claims; commit retries on
concurrent-modification likely.

All three preserve the foundation invariant; they trade throughput, latency,
and coordination cost differently.

## `evidence/head` storage in Neo4j

Open implementation question to benchmark — note that as `evidence/*` edges,
they are uniform with other `evidence/*` edges at the parser level; the
distinction (topological vs semantic) is in the subtype:

**Option Ia — first-class Neo4j edges.** Stored like any other `evidence/*`
edge; Cypher queries for semantic content filter them out via
`WHERE NOT type = 'evidence/head'`. Pro: full structural uniformity, easy
DAG validation. Con: filter overhead on every semantic query.

**Option Ib — node property.** Store the head hashes as a list property on
the snapshot node (`heads: [hash, hash, ...]`); reconstruct edge form only
for DAG validation / hash recomputation. Pro: semantic queries automatically
clean (no filter); lighter storage. Con: violates "everything is edges"
uniformity at the storage layer; DAG validation walks property-not-edges.

Foundation-equivalent; pick by benchmarking. Note that (Ib) is structurally
equivalent to (Ia) — a list-of-hashes-on-a-node is isomorphic to a set of
edges with `target=hash`. Same data, different storage shape.

## Storage discipline: the writes-only-in-𝒰 rule

The principle that decided the auth-scope architecture (and the rejected
"scope-as-node" exploration):

> $\mathcal{U}$ contains only *write events with provenance* — claims made by a
> contributor at a moment in time, with reasoning, frozen forever. Everything
> driven by *read-time semantics* belongs in Postgres.

Applied:

- **In $\mathcal{U}$:** ordinary claims, prune-claims (snapshots with
  `prune/*` edges — genuine write events: a contributor decided to mark
  hashes unresolvable, with reasons and provenance).
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
