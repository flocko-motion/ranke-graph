// shared/glossary.typ — canonical terminology for the Ranke paper series.
//
// SINGLE SOURCE OF TRUTH for shared vocabulary. Each term is defined once,
// here, and tagged with the paper that introduces it. Rendered per paper via
// the `glossarium` package (https://typst.app/universe/package/glossarium).
//
// ── Usage in a paper ────────────────────────────────────────────────────
//   #import "../shared/glossary.typ": *
//   #show: paper.with( ... )     // template first
//   #show: use-glossary          // then enable glossary term handling
//   ...
//   In prose, reference a term with   #gls("sequencer")   (plural: #glspl("branch")).
//   Print this paper's own terms in an appendix with:
//     = Glossary <sec:glossary>
//     #glossary-appendix("02")
//
// ── Reference policy (so a per-paper "used terms" appendix stays honest) ──
//   * FIRST use of a term in a paper: always #gls — this both renders the
//     long form and creates the anchor the appendix lists (show-all: false
//     prints only terms referenced at least once).
//   * RE-USE after a gap (new section, or a few pages on): #gls again, so a
//     reader landing there has a nearby link back to the definition.
//   * Dense local re-use (same paragraph): plain text is fine — avoid clutter.
//
// ── Compile notes ────────────────────────────────────────────────────────
//   * Pinned to glossarium 0.5.10, verified compiling with typst 0.15.
//     NOTE: glossarium ≤ 0.5.1 SILENTLY DROPS every entry under typst 0.15
//     ("block may not occur inside of a paragraph") — keep ≥ 0.5.10.
//   * All package-specific calls (make-glossary, register-glossary,
//     print-glossary, gls, glspl) are isolated in the ADAPTER block. If a
//     future version renames a function or field, the fix is confined there —
//     the ENTRY DATA and the papers stay untouched.
// ─────────────────────────────────────────────────────────────────────────

#import "@preview/glossarium:0.5.10"

// Term-reference helpers (used both in prose and inside entry descriptions,
// so they are bound before `entries`).
#let gls   = glossarium.gls
#let glspl = glossarium.glspl

// ── ENTRY DATA: the canonical vocabulary. Edit freely; API-independent. ───
// Fields: key (stable id used by #gls), short (how it renders), long
// (optional expansion for first use / abbreviations), description, group
// (drives per-paper appendix + section heading; MUST contain "01" or "02").
#let entries = (

  // ═══════════ Paper 01 — Ranke-Graph (foundation) ═══════════
  (key: "claim", short: "claim", group: "01 · Ranke-Graph",
   description: [A node together with its content and its `edges`; the atom of the Ranke-Graph, created in one atomic transaction and addressed by its `id`. (foundation paper §Claims)]),

  (key: "node", short: "node", group: "01 · Ranke-Graph",
   description: [The record carrying a claim's fields — `type`, `encoding`, `created_at`, content, `edges`. (foundation paper §Nodes)]),

  (key: "edge", short: "edge", group: "01 · Ranke-Graph",
   description: [A typed link from the claim that owns it to the claim it references. (foundation paper §Edges)]),

  (key: "reference", short: "reference", group: "01 · Ranke-Graph",
   description: [The claim an edge points at — the target of provenance traversal. (foundation paper §Edges)]),

  (key: "contributor", short: "contributor", group: "01 · Ranke-Graph",
   description: [The actor — human, program, or agent — whose work brings a claim into the graph. Operationally distinct from an #gls("entity"). (foundation paper §Taxonomy)]),

  (key: "source", short: "source", group: "01 · Ranke-Graph",
   description: [Node class `source/*`: an external data artifact captured into the graph. (foundation paper §Type Vocabulary)]),

  (key: "derivation", short: "derivation", group: "01 · Ranke-Graph",
   description: [Node and edge class `derivation/*`: a claim built from other claims, and the provenance edges citing them. (foundation paper §Type Vocabulary)]),

  (key: "entity", short: "entity", group: "01 · Ranke-Graph",
   description: [Node class `entity/*`: an identifiable thing in the world. (foundation paper §Taxonomy)]),

  (key: "relation", short: "relation", group: "01 · Ranke-Graph",
   description: [Node class `relation/*`: a reified assertion about how entities relate, carrying `relation_direction` edges. (foundation paper §Relations)]),

  (key: "ranke-graph", short: "Ranke-Graph", group: "01 · Ranke-Graph",
   description: [A Merkle DAG of attributed claims; the provenance-first data structure the series is built on. (foundation paper §Ranke-Graph)]),

  (key: "universe", short: "Universe", group: "01 · Ranke-Graph",
   description: [$cal(U)$, a content-addressed set containing serialized claims (each under its id $k$, $cal(U)(k)$) and their externalized content (each under its hash $h$, $cal(U)(h)$); ids and hashes never collide. Any Ranke-Graph is a subset; other archives may share $cal(U)$ unseen. Monotone: entries accumulate, never change. (foundation paper §Universe)]),

  (key: "rg-instance", short: "Ranke-Graph instance", group: "01 · Ranke-Graph",
   description: [$"RG"_k := "closure"(k, cal(U))$, the subset of the Universe reachable from a head id $k$. (foundation paper §Universe, §Closures)]),

  (key: "closure", short: "closure", group: "01 · Ranke-Graph",
   description: [The transitive set of claims reachable from a claim by following its edges to their references. (foundation paper §Closures)]),

  (key: "initial-node", short: "initial node", group: "01 · Ranke-Graph",
   description: [A claim with no references; a root at which provenance traversal terminates. (foundation paper §Ranke-Graph)]),

  (key: "id", short: "id", group: "01 · Ranke-Graph",
   description: [$op("id")(v) = "Sign"(H(S(v)))$: a claim's content address — a signature over the hash of its canonical serialization; written $k$ where a bare id is needed. (foundation paper §Primitives)]),

  (key: "type", short: "type", group: "01 · Ranke-Graph",
   description: [A claim's `type`: a #gls("class") from a fixed set together with an open #gls("subtype"), e.g. `source/conversation`. (foundation paper §Nodes, §Type Vocabulary)]),

  (key: "class", short: "class", group: "01 · Ranke-Graph",
   description: [The fixed, closed part of a #gls("type") — one of `source`, `derivation`, `entity`, `relation`, `contribution`. (foundation paper §Type Vocabulary)]),

  (key: "subtype", short: "subtype", group: "01 · Ranke-Graph",
   description: [The open-vocabulary part of a #gls("type"), defined by applications without changing the ADT. (foundation paper §Open-Ended Vocabulary)]),

  (key: "contribution-class", short: [`contribution/*`], group: "01 · Ranke-Graph",
   description: [Node and edge #gls("class") for claims about contributors and their actions on the graph — `contributor`, `head`, `branches`, `branch`, `diff`, `delete`, `expiry`. (foundation paper §Type Vocabulary)]),

  (key: "branch", short: "branch", group: "01 · Ranke-Graph",
   description: [A name resolving to a closure, anchored by a `contribution/head` claim. (foundation paper §Branches)]),

  (key: "branch-table", short: "branch table", group: "01 · Ranke-Graph",
   description: [A `contribution/branches` claim indexing the archive's branches — each edge names one branch and references its head — chained to its predecessor as provenance. (foundation paper §Branches)]),

  (key: "ranke-archive", short: "Ranke-Archive", group: "01 · Ranke-Graph",
   description: [$"RA"_k$, a Ranke-Graph whose head $cal(U)(k)$ is a branch-table claim; the tuple $(cal(U), k)$ of the Universe and a head id. Adding yields a new tuple $(cal(U)', k')$ — nothing is mutated. (foundation paper §Ranke-Archive)]),

  (key: "consolidating-head", short: "consolidating head", group: "01 · Ranke-Graph",
   description: [A `contribution/head` claim with edges to every open head, gathering them into a single head. (foundation paper §Consolidation)]),

  (key: "valid", short: "valid", group: "01 · Ranke-Graph",
   description: [Structural well-formedness — `id` recomputes, references resolve, the construction rules hold. A technical property, not a judgement on content. (foundation paper §Validity)]),

  (key: "verify", short: "verify", group: "01 · Ranke-Graph",
   description: [The verification of a graph's validity: recompute each `id` $= "Sign"(H(S(v)))$ and confirm the construction rules hold — integrity and authenticity checked in one pass. (foundation paper §Verifiability)]),

  (key: "anchoring", short: "anchoring", group: "01 · Ranke-Graph",
   description: [Witnessing a head externally — e.g. an RFC 3161 authority — to fix its closure in time. The word is reserved for this external sense. (foundation paper §Anchoring)]),

  // ═══════════ Paper 02 — RankeDB ═══════════
  (key: "rankedb", short: "RankeDB", group: "02 · RankeDB",
   description: [The reference database service that serves and manages Ranke-Graphs over interchangeable, content-addressed backends.]),

  (key: "sequencer", short: "Sequencer", group: "02 · RankeDB",
   description: [RankeDB's mechanism for maintaining a Ranke-Archive's head under concurrent contributions: it verifies, persists, then advances the head id $k$. (§Sequencer)]),

  (key: "envelope", short: "envelope", group: "02 · RankeDB",
   description: [The container in which one contribution is assembled and verified against a fixed base before it is sealed and merged. (§Sequencer)]),

  (key: "base", short: "base", group: "02 · RankeDB",
   description: [The fixed point an #gls("envelope") is drawn against: the current archive (head id $k$) and the stamped time $t$, written $(k, t)$. (§Sequencer)]),

  (key: "contribution", short: "contribution", group: "02 · RankeDB",
   description: [The set of claims committed to a branch in one merge. Distinct from the `contribution/*` node and edge class of the foundation paper. (§Sequencer)]),

  (key: "limiting-claim", short: "limiting claim", group: "02 · RankeDB",
   description: [A claim restricting use of another — a purge (`contribution/delete`) or an early key-expiry (`contribution/expiry`). Minted only by the Sequencer and propagated across branches. (§Cross Branch Propagation)]),

  (key: "blob-store", short: "blob store", group: "02 · RankeDB",
   description: [A content-addressed byte store with `get` / `put` / `has`; the ground any RankeDB #gls("universe") rests on. (§Blob Store)]),

  (key: "stamp", short: "stamp", group: "02 · RankeDB",
   description: [Fixing an envelope's reference time $t$, so every contributed claim satisfies `created_at` $lt.eq t$. (§Sequencer)]),

  (key: "seal", short: "seal", group: "02 · RankeDB",
   description: [Closing an envelope so its verified contents admit no further addition or removal; by immutability, what was valid at the base stays valid however long the envelope waits. (§Sequencer)]),

)


// ── Adapter block: the only place that knows glossarium's API. Defined
//    AFTER `entries` so the closures capture it. If the installed glossarium
//    version renames a function or field, fix it here only. ────────────────

// Enable term handling for a document and register every entry so #gls /
// #glspl resolve. Wrap the paper body with `#show: use-glossary`.
#let use-glossary(body) = {
  show: glossarium.make-glossary
  glossarium.register-glossary(entries)
  body
}

// Print the glossary for a paper, including the vocabulary it inherits from
// earlier papers (Paper 02 lists 01 + 02, so every #gls target has a label).
// Used only if a paper opts to carry an in-line appendix.
#let glossary-appendix(code) = glossarium.print-glossary(
  entries.filter(e => e.group.slice(0, 2) <= code),
)

// Print every term — for the standalone, series-wide glossary document.
// show-all: true so terms appear even though nothing #gls-references them here;
// back-references disabled (no page-number clutter in a standalone reference).
// (The per-paper appendix above uses the default, printing only used terms.)
#let glossary-full() = glossarium.print-glossary(
  entries, show-all: true, disable-back-references: true,
)
