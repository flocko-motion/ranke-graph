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

  // ═══════════ The foundation paper — Ranke-Graph ═══════════
  (key: "claim", short: "claim", group: "01 · Ranke-Graph",
   description: [A node together with its content and its `edges`; the atom of the Ranke-Graph, created in one atomic transaction and addressed by its `id`. (foundation paper §Claims)]),

  (key: "serialized-claim", short: "serialized claim", group: "01 · Ranke-Graph",
   description: [$S(v)$, a #gls("claim") as canonical bytes: the node's fields with every owned edge inline. It is the payload an #gls("envelope") carries, and the form a read returns where verification is not the point. (foundation paper §Primitives)]),

  (key: "envelope", short: "envelope", group: "01 · Ranke-Graph",
   description: [$"env"(v)$, a #gls("claim") as it is stored: the #gls("serialized-claim") paired with the signature over it. The archive holds it under its #gls("id"), which is the hash of these bytes, so the signature it carries cannot be detached from the claim it attests. (foundation paper §Primitives)]),

  (key: "node", short: "node", group: "01 · Ranke-Graph",
   description: [The record carrying a claim's fields — `type`, `encoding`, `created_at`, `height`, content, `edges`. (foundation paper §Nodes)]),

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
   description: [Node class `relation/*`: an assertion about how entities relate, held as a claim of its own so it carries an author, provenance, and a direction the semantic reading may invert. Its `relation_direction` edges bind the entities. Reification applies to this class; an edge of any other class relates the two claims it runs between and stands as an edge. (foundation paper §Relations)]),

  (key: "ranke-graph", short: "Ranke-Graph", group: "01 · Ranke-Graph",
   description: [A Merkle DAG of attributed claims; the provenance-first data structure the series is built on. (foundation paper §Ranke-Graph)]),

  (key: "universe", short: "Universe", group: "01 · Ranke-Graph",
   description: [$cal(U)$, a content-addressed set containing #glspl("envelope") (each under its id $k$, $cal(U)(k)$) and externalised content (each under its hash $h$, $cal(U)(h)$). Both keys are hashes over the bytes they name, so one keyspace serves both and identical bytes are one entry. Any Ranke-Graph is a subset; other archives may share $cal(U)$ unseen. Monotone: entries accumulate, never change. (foundation paper §Universe)]),

  (key: "rg-instance", short: "Ranke-Graph instance", group: "01 · Ranke-Graph",
   description: [$"RG"_k := "closure"(k, cal(U))$, the subset of the Universe reachable from a head id $k$. (foundation paper §Universe, §Closures)]),

  (key: "closure", short: "closure", group: "01 · Ranke-Graph",
   description: [The transitive set of claims reachable from a claim by following its edges to their references. (foundation paper §Closures)]),

  (key: "initial-claim", short: "initial claim", group: "01 · Ranke-Graph",
   description: [A claim with no references; a root at which provenance traversal terminates. (foundation paper §Ranke-Graph)]),

  (key: "id", short: "id", group: "01 · Ranke-Graph",
   description: [$op("id")(v) = H(S("env"(v)))$: a claim's content address, the hash of the #gls("envelope") the archive stores; written $k$ where a bare id is needed. Recomputing it takes the stored bytes and $H$, while the signature those bytes carry establishes authorship. (foundation paper §Primitives)]),

  (key: "height", short: "height", group: "01 · Ranke-Graph",
   description: [A mandatory node field: $"height"(v) = max({"height"(u) + 1 : u in "refs"(v)} union {0})$, the longest path from the claim following references, an #gls("initial-claim") carrying 0. Determined by the claim's #gls("id"), strictly rising along every reference, so a set bounded by height is closed under references. (foundation paper §Nodes)]),

  (key: "type", short: "type", group: "01 · Ranke-Graph",
   description: [A node's or an edge's `type`: a #gls("class") from a fixed set together with an open #gls("subtype"), e.g. `source/conversation`. (foundation paper §Nodes, §Type Vocabulary)]),

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

  (key: "branch-table-chain", short: "branch-table chain", group: "01 · Ranke-Graph",
   description: [The chain of #glspl("branch-table") from an archive's current head back to the initial empty table, each holding its predecessor in provenance, so it carries every state the archive has held. Called the *spine* colloquially, and in the reference implementation. Distinct from the Sequencer's head history, which is the sequence of branch-table #gls("id")s it keeps outside the graph. (foundation paper §Branches, §Ranke-Archive)]),

  (key: "ranke-archive", short: "Ranke-Archive", group: "01 · Ranke-Graph",
   description: [$"RA"_k$, a Ranke-Graph whose head $cal(U)(k)$ is a branch-table claim; the tuple $(cal(U), k)$ of the Universe and a head id. Adding yields a new tuple $(cal(U)', k')$ — nothing is mutated. (foundation paper §Ranke-Archive)]),

  (key: "head-index", short: "head index", group: "01 · Ranke-Graph",
   description: [The second address scheme $op("id")_"seq"(i, s) := H(i, s)$, keyed on a #gls("history-seed") $s$, naming the `contribution/history` claim recorded at step $i$ — computable without already knowing the archive's current head. (foundation paper §Head Index)]),

  (key: "history-seed", short: "history seed", group: "01 · Ranke-Graph",
   description: [An arbitrary value $s$ chosen once, when a history begins, with no meaning beyond avoiding collision with another history's seed; the second input to #gls("head-index")'s $op("id")_"seq"(i, s)$. (foundation paper §Head Index)]),

  (key: "consolidating-head", short: "consolidating head", group: "01 · Ranke-Graph",
   description: [A `contribution/head` claim with edges to every open head, gathering them into a single head. (foundation paper §Consolidation)]),

  (key: "valid", short: "valid", group: "01 · Ranke-Graph",
   description: [Structural correctness — `id` recomputes, references resolve, the construction rules hold. A technical property, not a judgement on content. (foundation paper §Validity)]),

  (key: "verify", short: "verify", group: "01 · Ranke-Graph",
   description: [The verification of a graph's validity: recompute each `id` $= "Sign"(H(S(v)))$ and confirm the construction rules hold — integrity and authenticity checked in one pass. (foundation paper §Verifiability)]),

  (key: "anchoring", short: "anchoring", group: "01 · Ranke-Graph",
   description: [Witnessing a head externally — e.g. an RFC 3161 authority — to fix its closure in time. The word is reserved for this external sense. (foundation paper §Anchoring)]),

  // ═══════════ The RankeDB paper ═══════════
  (key: "rankedb", short: "RankeDB", group: "02 · RankeDB",
   description: [The reference database service that serves and manages Ranke-Graphs over interchangeable, content-addressed backends.]),

  (key: "sequencer", short: "Sequencer", group: "02 · RankeDB",
   description: [RankeDB's mechanism for maintaining a Ranke-Archive's head under concurrent contributions: it verifies, persists, then advances the head id $k$. (§Sequencer)]),

  (key: "base", short: "base", group: "02 · RankeDB",
   description: [The fixed point a contribution is opened against: the current archive (head id $k$) and the stamped time $t$, written $(k, t)$. (§Sequencer)]),

  (key: "contribution", short: "contribution", group: "02 · RankeDB",
   description: [A set of claims added to the archive in one transaction, all of them or none — opened against a base, verified and sealed, then merged as a unit. Distinct from the `contribution/*` node and edge class of the foundation paper. (§Sequencer)]),

  (key: "frontier", short: "frontier", group: "02 · RankeDB",
   description: [The set of claims a `path` step starts from. The first frontier is the anchor claim, or every claim in the #gls("closure") when the path is unanchored; each step's yield is the next step's frontier. (§Filtered Reads)]),

  (key: "limiting-claim", short: "limiting claim", group: "02 · RankeDB",
   description: [A claim restricting use of another — a deletion (`contribution/delete`) or an early key-expiry (`contribution/expiry`). Minted only by the Sequencer and propagated across branches. (§Cross Branch Propagation)]),

  (key: "blob-store", short: "blob store", group: "02 · RankeDB",
   description: [A content-addressed byte store with `get` / `put` / `has`; the ground any RankeDB #gls("universe") rests on. (§Blob Store)]),

  (key: "stamp", short: "stamp", group: "02 · RankeDB",
   description: [Fixing a contribution's reference time $t$, so every contributed claim satisfies `created_at` $lt.eq t$. (§Sequencer)]),

  (key: "seal", short: "seal", group: "02 · RankeDB",
   description: [Closing a contribution so its verified contents admit no further addition or removal; by immutability, what was valid at the base stays valid however long it waits before merging. (§Sequencer)]),

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
// earlier papers (the RankeDB paper lists both groups, so every #gls target
// has a label).
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

// The appendix a handbook prints (shared/handbook.typ), with the pages each term
// was named on.
//
// show-all: true, and that is the point rather than a preference. An entry's
// description names further terms with #gls, so printing only the referenced
// ones adds references, which print more entries, which add more references. A
// document naming three terms does not settle within Typst's five layout
// attempts, and the count it stops on is whatever run five reached. Printing all
// 39 fixes the set before the first run, so it converges — and every #gls in a
// chapter finds its label, whichever terms the chapter happens to use.
#let glossary-handbook() = glossarium.print-glossary(entries, show-all: true)
