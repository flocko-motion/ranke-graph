// spec/ranke-spec.typ — the Ranke Normative Specification.
//
// A companion document to the Ranke-Graph paper series, and the artifact an
// implementation FOLLOWS. The papers say WHAT and WHY in prose meant to be
// read once; this document says exactly what an implementation MUST do, rule by
// rule, in a form meant to be read repeatedly and cited precisely.
//
//   * The papers are the concept. They govern meaning; this spec must never
//     contradict them. Where it seems to, the foundation paper wins for ADT
//     rules, the RankeDB paper for RankeDB rules.
//   * A machine-readable schema, a conformance suite, and an implementation are
//     PROJECTIONS of this document: a schema checks the shapes named here, each
//     conformance case exercises a rule id here, the code enforces them. None is
//     a reading source; this is. Where one disagrees with this document, one of
//     the two is a defect — decide which and fix it, rather than letting both
//     stand. So never cite a file built from this one: name the role, not the
//     artifact.
//
// Every normative statement carries a stable id (V-ID, R-CEIL, …). Ids never
// change meaning: retire an id rather than repurpose it, so a conformance case
// or a code comment citing "R-CEIL" means the same thing forever.
//
// Compile:  typst compile --root .. ranke-spec.typ

#set document(title: "Ranke — Normative Specification")
#set page(paper: "a4", margin: (x: 2.5cm, top: 2.5cm, bottom: 3cm), numbering: "1")
#set text(size: 10.5pt, lang: "en")
#set par(justify: true, leading: 0.55em)
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => { set text(size: 1.25em, weight: "bold"); block(above: 1.4em, below: 0.7em, it) }
#show heading.where(level: 2): it => { set text(size: 1.1em, weight: "bold"); block(above: 1.1em, below: 0.5em, it) }
#show heading.where(level: 3): it => { set text(weight: "bold"); block(above: 0.9em, below: 0.4em, it) }

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// Class tints for the reference-archive diagram (@sec:fixture). One colour per
// node class, echoed in the figure legend so the picture teaches the taxonomy.
#let tint = (
  source:       rgb("#dbeafe"),
  derivation:   rgb("#dcfce7"),
  entity:       rgb("#ffedd5"),
  relation:     rgb("#f3e8ff"),
  contribution: rgb("#e5e7eb"),
)
// Faint style for the contribution/contributor edge every claim carries.
#let ctr-stroke = 0.35pt + rgb("#b3b3b3")
// The branch-table chain: each table holds its predecessor in provenance.
#let diff-stroke = 1pt + rgb("#2563eb")

// A normative rule: a tagged, numbered statement. `id` is the stable citation
// handle; `tier` is FORCED (ADT-mandated, portable across implementations) or
// FREE (a RankeDB choice). Rendered as a hanging label so the rules scan.
#let rule(id, tier, body) = block(above: 0.6em, below: 0.6em, inset: (left: 0.2em))[
  #grid(columns: (5.5em, 1fr), column-gutter: 0.6em,
    [#text(weight: "bold")[#id] \ #text(size: 0.78em, fill: rgb("#666"))[#tier]],
    [#body])
]
#let FORCED = "FORCED"
#let FREE = "FREE"

// An open decision: a detail this document must fix before the chapter that
// owns it can be written. Deliberately loud — an unresolved TODO is a hole in
// the normative surface, not a note.
#let todo(body) = block(
  above: 0.6em, below: 0.6em, inset: 6pt, radius: 2pt,
  width: 100%, fill: rgb("#fff7ed"), stroke: 0.5pt + rgb("#fdba74"),
)[#text(size: 0.94em)[*TODO* — #body]]

#align(center)[
  #text(size: 1.55em, weight: "bold")[Ranke — Normative Specification] \
  #v(0.3em)
  #text(size: 0.95em, style: "italic")[The rules an implementation must follow] \
  #v(0.2em)
  #text(size: 0.85em, style: "italic")[Companion to the Ranke-Graph paper series — draft]
]
#v(1.2em)

= Purpose and Status <sec:purpose>

This document is the normative reference for the Ranke-Graph and its reference
database, RankeDB. While the papers _Ranke-Graph: A Provenance-First Data
Structure_ and _RankeDB: Serving the Ranke-Graph_ lay the foundation and describe
the mechanisms — cited below as the *foundation paper* and the *RankeDB paper* —
this specification adds the exhaustive detail and design decisions required for a
full implementation.

= How to Read This <sec:conventions>

*Normative keywords.* *MUST*, *MUST NOT*, *SHOULD*, *SHOULD NOT*, and *MAY* are
used as in RFC 2119. A *MUST* is a conformance condition: an implementation that
violates it is non-conformant, and a violating claim is rejected.

*Rule ids and tiers.* Each rule carries a stable id and a tier:

#rule("V-…", FORCED)[A rule of the *abstract data type* (ADT) the foundation paper
defines (`V` for validity/verification); *portable* — every conformant Ranke
implementation, database or not, enforces it identically. Changing one changes the
data structure.]

#rule("R-…", FREE)[A *RankeDB rule* (`R`). A choice RankeDB makes that the ADT
leaves open. Another implementation of the ADT *MAY* decide differently; a
conformant *RankeDB* MUST follow it.]

Where a chapter's subject warrants a family of its own, the `R` is followed by a
category prefix e.g. `R-Q…` for rules regarding the RankeDB query language.

*Examples.* Every example in this specification is stated against the reference
archive (@sec:fixture) with labelled claims e.g. `src₁`, `bt₂`.

= Graph Verification <sec:verification>

*Verification* decides whether a set of claims is a *valid* Ranke-Graph and,
in RankeDB, whether a contribution may merge into an existing archive. The ADT
rules (@sec:v-adt) decide validity; the RankeDB rules (@sec:v-rankedb) add what a
contribution must satisfy to merge (foundation paper
§Verifiability, RankeDB paper §Verification and Witnessing).

Given a Ranke-Archive, verification walks the closure of its head — every claim
reached by following edges to their references — and checks each against the rules
below. An archive carrying a claim that fails any *MUST* rule fails verification.
A contribution merges only if the archive stays valid with it applied (RankeDB
paper §Sequencer).

== ADT rules <sec:v-adt>

These hold for any Ranke-Graph, in any implementation. They are the definition
of *valid* (foundation paper §Validity, §Verifiability).

#rule("V-TYPE", FORCED)[Every node and every edge MUST carry a `type` whose
`class` is one of the fixed set: `source`, `derivation`, `entity`, `relation`, or
`contribution` for a node; `derivation`, `relation`, or `contribution` for an edge.
The subtype is open vocabulary. (foundation paper §Nodes, §Edges, §Type
Vocabulary)]

#rule("V-REF", FORCED)[Every edge's `reference` MUST resolve to a claim present
in the closure, and MUST reference a *claim* — never an edge. (foundation paper
§Edges, §Relations, §Validity)]

#rule("V-ROOT", FORCED)[Every claim MUST either be an *initial node* — one with
no references — or carry a `contribution/contributor` edge. Several initial nodes
are admitted, as a federated merge of independent lines produces. (foundation
paper §Ranke-Graph, §Validity, §Provenance)]

#rule("V-CONTENT", FORCED)[If a claim declares content, it MUST carry both
`content_size` (its exact byte length) and `encoding` (its media type). Inline
content lives in `content`; external content is referenced by `content_hash`,
and the referenced bytes in $cal(U)$ MUST hash to it: $H(c) = $ `content_hash`.
A claim MUST NOT carry both `content` and `content_hash`. (foundation paper §Content,
§Verifiability)]

#rule("V-ID", FORCED)[Every claim's stored id MUST recompute:
$op("id")(v) = "Sign"(H(S(v)))$ for a node, $op("id")(e) = H(S(e))$ for an edge.
$S$ MUST be the canonical serialization (deterministic, complete,
self-delimiting) and $H$ the declared, self-describing hash. Since $S(v)$ covers
the node's whole `edges` field, one recomputation fixes the node and every edge it
owns. (foundation paper §Primitives, §Verifiability)]

#rule("V-SIG", FORCED)[The signature in $op("id")(v)$ MUST verify against the
contributor's `pubkey` — reached through $v$'s `contribution/contributor` edge, or,
when $v$ is an initial node, in $v$'s own content. Where no `pubkey` is set, the
signature scheme is *identity*, $"Sign"(h) = h$. (foundation paper §Primitives,
§Identity and Authenticity)]

#rule("V-MONO", FORCED)[Every claim MUST carry `created_at`, the UTC time it was
added, and MUST NOT predate what it references:
`created_at`$(v) gt.eq max$ `created_at`$(u)$ over every reference $u$ of $v$.
(foundation paper §Nodes, §Claims, §Merkle DAG)]

== RankeDB rules — added policy <sec:v-rankedb>

RankeDB enforces every *V-* rule above and adds the following. Each is a choice
the ADT leaves open; together they are what a contribution must satisfy to merge
(RankeDB paper §Sequencer, §Timestamping, §Keyrotation, §Cross Branch Propagation).

#rule("R-BASE", FREE)[Every claim added in a contribution MUST be dated
`created_at`$lt.eq t$, where $t$ is the contribution's base time — the server
time stamped when the contribution was opened against head $k$, the pair $(k,t)$
(RankeDB paper §Sequencer, step 2).]

#rule("R-CEIL", FREE)[A claim merged by the server MUST NOT be dated later than
the server's own clock at merge. This ceiling, with *V-MONO*, prevents
future-dating; judging whether a date is otherwise *plausible* is out of scope
and left to client applications. (RankeDB paper §Timestamping)]

#rule("R-KEYWIN", FREE)[A claim MUST verify against a contributor key that is
valid at the claim's `created_at`. A key's validity is the closed window from
`pubkey_valid_from` through `pubkey_expires_after` (both RFC 3339, both optional)
on the contributor claim; a claim dated strictly after `pubkey_expires_after`
fails verification. Rotation adds a further contributor claim with a later
window; windows MAY overlap. (RankeDB paper §Contributor Keys Life Cycle)]

#rule("R-RESERVED", FREE)[A contribution from a system account MUST NOT contain
*limiting claims* (`contribution/delete`, `contribution/expiry`) or *branch-table*
claims (`contribution/branches`): these types are minted by the Sequencer alone.
A system account MAY only commit a *request* for one (e.g. an
`expires_after_request` edge), which the Sequencer honours, subject to access
policy, when it advances the head. (RankeDB paper §Sequencer, §Contributor Keys Life
Cycle)]

#rule("R-CLOSED", FREE)[Before verification a contribution MUST be *closed*: each
claim's references are followed, drawing in every referenced claim outside the
contribution — from another branch or the wider Universe — together with the
limiting claims against it, recursively, until every path reaches a claim already
in the base's closure. Drawing in a branch-external claim requires read access to
its branch (*R-ACCESS*). (RankeDB paper §Sequencer, step 3)]

#rule("R-LIMIT-PROP", FREE)[A limitation MUST NOT be lost across branches: when a
contribution adds a claim that is the target of a limiting claim, the Sequencer
MUST add that limiting claim to the same branch in the same contribution. A limit
thus stays attached to its target wherever the target is referenced. (RankeDB paper
§Cross Branch Propagation)]

#rule("R-PERSIST", FREE)[The sealed contribution's whole closure MUST be durably
present in the Universe — stored and propagated across the storage layers —
*before* the head advances $k arrow.r k'$. A head therefore never commits to a
claim that failed to persist. (RankeDB paper §Sequencer, step 5)]

#rule("R-SEAL", FREE)[Once verified, a contribution is *sealed*: its contents are
fixed and admit no further addition or removal. By immutability, whatever
verified against the base stays valid however long it waits before merging.
(RankeDB paper §Sequencer, step 4)]

#rule("R-ACCESS", FREE)[A contribution to a branch requires *C* (contribute)
access to it; reads require *R*; overlaying an existing claim requires *U*;
deleting bytes requires *D* on every branch holding the claim. Access by head id
alone, bypassing the branch table, is *privileged* and granted only over the
reserved `$universe` target, to which only *R* applies. Within a scope the
grant covers the whole of it: naming a closure inside that scope, or starting a
walk anywhere within it (@sec:rql-select), confers no access the scope's own grant
does not already carry. (RankeDB paper §Access Control)]

#rule("R-DELMARK", FREE)[A *requested* deletion MUST be documented by a
`contribution/delete` claim: a node of class `contribution/delete` carrying a
`contribution/delete` edge to the deleted claim (its *target*). It is a limiting
claim — minted by the Sequencer (`R-RESERVED`) and propagated across branches
(`R-LIMIT-PROP`). `contribution/delete` is both a node and an edge class (foundation paper
§Type Vocabulary); mandating the *node* is what guarantees a deletion always leaves
a typed, documented gap. (RankeDB paper §Deletion)]

#rule("R-DELBY", FREE)[A *planned* deletion is a `delete_by` date carried in a
claim's signed content. Every edge referencing that claim MUST copy the
`delete_by` date, so once the bytes are deleted the gap stays explained wherever
the claim is reached — no limiting claim and no cross-branch propagation are
involved. (RankeDB paper §Deletion)]

#rule("R-GAP", FREE)[Verification MUST still pass over a graph whose claims were
deleted, accepting a target's absent bytes when — and only when — an *explained
gap* covers it: a `contribution/delete` mark against it (`R-DELMARK`), or a copied
`delete_by` (`R-DELBY`). An unexplained missing reference fails `V-REF`. (RankeDB paper
§Deletion)]

= RankeQL (RQL) <sec:rql>

A read is a *RankeQL* query: a declarative value of the data type `Query` fixed
below, independent of any programming language and of the wire encoding that
carries it. RQL is entirely a RankeDB construct — the ADT defines no query
language — so this whole chapter is `[FREE]`. Its blocks and their roles are those
of the RankeDB paper §Filtered Reads.

RQL is a subset of Cypher and the ISO standard it converges on, the Graph Query
Language (GQL), so reading a construct as its Cypher counterpart is usually right:
anchored and unanchored generators are `MATCH` with and without a bound variable, a
step's `min`/`max` is `*min..max`. The one departure is the frontier pipeline
(`R-QFRONTIER`).

This chapter fixes the type and what each field's values *mean*. Defaulting for
omitted fields is an implementation and binding concern. A query that depends on a
particular behaviour — a materialised result, a `cbor` encoding, a traversal
direction — must state it explicitly.

#rule("R-QEVAL", FREE)[A query is evaluated in a fixed logical order: (1) `select`
generates the result set, (2) `where` filters it, (3) `order` sorts it, (4) `limit`
truncates it, (5) `output` shapes and encodes each surviving claim. An engine MAY
reorder or lower these steps, provided the delivered result set is identical to
what this order produces; the native reference engine is the oracle. (RankeDB paper
§Filtered Reads, §Conformance)]

== The query type <sec:rql-type>

Field names ending in `?` are optional; `|` lists the allowed values or forms;
`[T]` is a list of `T`. `Id`, `Claim`, `bytes`, and `duration` are the ambient
domains of @sec:fixture.

#[
#show raw: set text(size: 0.82em)
```
Query = {
  select:     Select
  where?:     Where          // optional filter
  output:     Output
  order?:     Order          // optional re-sort
  limit:      Limit
  execution:  Execution
}

Select = {                   // a generator: scope, closure, start, traversal
  branch:  string            // "$universe" | "$archive" | a branch name
  head?:   Id                // the closure read; required iff branch = "$universe"
  claim?:  Id                // anchor in the closure; absent -> the closure entire
  path?:   [PathStep]        // absent -> the full outward closure of the frontier
}

PathStep = {                 // follow typed edges for min..max hops
  edges?:  [string]          // edge-class globs "class/sub"; leading "-" excludes
  dir?:    "provenance" | "uses" | "connections"    // outgoing | incoming | either
  min?:    int               // fewest hops; absent -> 1; 0 -> yields its start too
  max?:    int               // most hops; 0 -> unbounded for this step
  nodes?:  [string]          // yielded node-class globs; leading "-" excludes
}

Where =                      // exactly one form per node
    { and: [Where] }
  | { or:  [Where] }         // combines filters; across generators, unions result sets
  | { not: Where }
  | { field: string, test: Comparison }             // leaf

Comparison =                 // exactly one operator
    { eq|ne|lt|le|gt|ge: value }
  | { in: [value] }          // set membership
  | { glob: string }         // shell-style wildcard

Output = {
  shape?:    "single" | "path"                      // list of single elements | list of paths
  detail?:   "id" | "graph" | "claims"              // per element: id | graph | full claims
  form?:     "original" | "materialized"            // field values: as written | resolved
  content?:  {                                      // inline content per claim; absent -> none
    max:      int                                   // cap in bytes
    overflow: "cutoff" | "omit" | "reference"       // handling past max
  }
  encoding?: "json" | "cbor"                        // text (base64 content) | binary
}

Order    = [OrderKey]      // sort keys in priority order; ties -> natural (created_at, id)
OrderKey = {
  field:    string
  compare?: "numeric" | "lexical"   // how values compare (collation)
  dir?:     "asc" | "desc"          // direction
}

Limit = { results?: int, time?: duration }          // each 0 -> unbounded

Execution = {
  layer?:  string            // pin one storage layer
  report?: "info" | "debug" | "trace"               // optional execution report
}
```
]

== `select` — closure and walk <sec:rql-select>

A generator answers two separate questions, and the fields divide along them.
*Which graph is read* — the closure, fixed by `head`. *Where the reading starts* —
the *frontier* `path` walks from: one point inside that closure when `claim` anchors
it; naming none leaves `path` to match anywhere in the closure.

The two are independent because a walk runs in both directions. A `provenance`
step follows references outward, and every claim it can reach is inside the
closure of wherever it started. A `uses` step runs the other way, to the claims
that *cite* the current one, and those lie *above* the start: the answer is
whatever cites it — within the graph under consideration. So the closure is what
decides a reverse step's result, and naming a start point cannot substitute for
it. In the reference archive, `der₅` (`review`) cites `der₄` (`master`): a `uses`
step from `der₄` returns `der₅` under `$archive`, and nothing under `master`,
whose closure does not hold `der₅`. Same start claim, two closures, two answers.

#rule("R-QSCOPE", FREE)[`branch` is the mandatory *scope*. A real branch name
confines the query to that branch; `$archive` confines it to the whole
Ranke-Archive; `$universe` applies no confinement. An empty `branch` MUST be
rejected. The scope is what a grant is held against (`R-ACCESS`), and `$universe`
is privileged. (`$archive` extends the reserved `$`-targets of §Access, which names
`$universe` and `$branches`.)]

#rule("R-QHEAD", FREE)[`head` fixes the *closure* read: the query sees
$"closure"("head", cal(U))$ and nothing outside it. It is *required* under
`$universe`, which confines nothing and so offers no head to fall back on, and
*optional* under every other scope, where the scope's own head serves — the
branch's head, or the branch-table header under `$archive`. Given explicitly under
a branch or `$archive`, it MUST resolve to a claim within that scope's closure, so
it narrows a query and can never widen it past the grant. Under `$universe` it MAY
name any claim the Universe holds.]

#rule("R-QANCHOR", FREE)[`claim` *anchors* the walk at one claim, which MUST lie
inside the closure; a `claim` outside it is rejected. Absent, the path is
*unanchored*, matching wherever it fits in the closure. Either way the anchor moves
where reading begins, never what is visible: reachability within the closure is the
check, so no right beyond the scope's *R* is involved.]

#rule("R-QHOPS", FREE)[A `PathStep` follows a set of typed `edges` (globs over
`class/sub`, a leading `-` excluding a type) in direction `dir` — `provenance`
(outgoing, towards references), `uses` (incoming), or `connections` (either) — and
yields every claim it reaches at between `min` and `max` hops from its starting
set, optionally constrained to `nodes` types. `edges` gates every hop; `nodes`
gates the claims a step yields, never those it passes through. An absent `min` is
1; `min: 0` also yields the starting set. A `max` of `0`, or an absent `max`,
leaves the step unbounded. A `min` above a bounded `max` MUST be rejected. An
absent `path` returns the full outward closure of the frontier (foundation paper
§Closures).]

An anchored generator asks what one claim reaches; an unanchored one asks where a
shape occurs, which is Cypher's `MATCH` with and without a bound variable. Both are
bounded alike by the closure, and unanchored with no step names the closure itself.

The two zeros of `R-QHOPS` differ because each has only one useful sense: a step of
at most zero hops would move nothing, so `max: 0` means unbounded, while `min: 0`
yields the starting set alongside what lies beyond it.

#rule("R-QFRONTIER", FREE)[A `path` is a *frontier pipeline*. Each step is an
*independent* bounded walk that starts from the *set* of endpoints the previous step
produced — the first step from the anchor, or from every claim in the closure when
the path is unanchored — and its own endpoints become the next step's starting set.
The no-repeat rule (a walk does not revisit a node) applies *within a single step*
and *resets* at each step boundary, so a later step MAY re-cross a claim or
re-traverse an edge an earlier step used. A result MUST NOT depend on how the
frontier was reached.]

This is the one place RQL departs from Cypher, whose single-trail reading with
whole-path edge-uniqueness drops results a frontier pipeline returns; the RankeDB
paper §Filtered Reads works the case through.

*(Planned.)* When a query returns a route (`detail: path`), a caller may want to
constrain the route's *shape* — no repeated edges, or no repeated nodes. A future
opt-in modifier on a path or step will expose the ISO GQL path modes (`WALK`,
`TRAIL`, `ACYCLIC`, `SIMPLE`); the default remains the frontier pipeline above.

== `height` — the level a claim sits at <sec:rql-height>

Every claim sits at a *height*: the length of the longest reference chain from it
down to an initial node — height in the graph-theoretic sense, over the directed
acyclic graph the claims form. It is the level a claim occupies above the sources
its provenance rests on.

#rule("R-HEIGHT", FREE)[A claim's height is
$ "height"(v) = max({"height"(u) : u in "refs"(v)} union {0}) + 1 $
over the claims $u$ that $v$ references. An initial node references nothing and so
sits at height 1; every height is therefore $gt.eq 1$, which leaves `0` free to
mean *unbounded* as it does for a step's `max` or a `limit`. Height is a function
of the claim's closure alone, hence determined by $op("id")(v)$
(foundation paper §Merkle DAG): every Universe holding the claim computes the same value,
and appending to the
archive never changes one. RankeDB MUST compute a claim's height while it verifies
that claim's closure (`R-CLOSED`) and retain it, so a claim whose bytes are later
deleted keeps the height it entered with (`R-GAP`).]

Height is strictly *decreasing* along every reference — $"height"(u) <
"height"(v)$ for each reference $u$ of $v$ — so it is a topological rank of the
graph. A height assignment therefore exists only for an acyclic graph: a cycle
would need a strictly decreasing chain of integers bounded below by 1. Computing
height is thus a cycle check, and needs no appeal to hashing or to `created_at`.

#rule("R-HEIGHT-FIELD", FREE)[Height is a *derived field* named `height`, which a
`where` leaf and an `order` key may name like any field a claim carries
(@sec:rql-where, @sec:rql-bounds). Its values are integers and compare
`numeric`ally.]

The field earns its place three times over. A comparison of heights is a cheap
necessary condition for ancestry, so it prunes before any traversal. Because every
reference sits strictly lower than the claim citing it, a result bounded by
`{field: "height", test: {le: h}}` is closed under references: a kept claim's
references are kept too. That filter alone therefore yields a valid Ranke-Graph,
reaching $h$ levels of derivation above its sources, where a filter on any other
field yields an arbitrary set. And a bound on it is one integer comparison per claim,
which a layer that indexes the field answers as a range rather than a traversal.

In the reference archive the contributors sit at 1 (`c_seq`, an initial node) and 2
(`c_alice`, `c_alice2`, `c_bob`); `src₁` and `src₂` at 3; `der₁`, `der₂` and `del₁`
at 4; `der₃` and the entities at 5; `rel₁` at 6; `der₄` at 7; `der₅` at 8; and the
archive head `bt₅` at 10. A bound of `le: 4` over `master` therefore keeps `src₁`,
`der₂` and the contributor claims, leaving `ent₁`/`ent₂` (5), `rel₁` (6) and the
head `der₄` (7) outside it.

Height is a level in the derivation structure, not a clock. It answers 'up to $h$
levels of derivation above the sources' exactly, and 'the branch as it stood' not at
all. A claim contributed today at a low height — a fresh source, or a derivation
directly over one — satisfies a low bound as readily as the oldest claim in the
archive. A read of a past state pins that past `head`, whose closure is immutable;
a read at a past *time* filters `created_at`.

== `where` — the filter <sec:rql-where>

`where` is a boolean tree. Each node is exactly one of the `and` / `or` / `not`
combinators over sub-trees, or a *leaf* naming a `field` and a `test`. A
`Comparison` applies exactly one operator to the field: `eq`, `ne`, `lt`, `le`,
`gt`, `ge`, `in` (set membership), or `glob` (shell-style wildcard). Within a
`where`, `or` is boolean; across generators it unions whole result sets.

== `output` — result shape and encoding <sec:rql-output>

#rule("R-QOUTPUT", FREE)[`output` shapes each result along five orthogonal axes.
*`shape`*: `single` (a list of the reached endpoints, one element each) or `path` (a
list of routes, each running outward from the frontier claim its walk began at).
*`detail`*: `id` (the id, or the ids along a path), `graph` (nodes joined by the
edges between them, `n-(e)-n`), or `claims` (the full claim for each node — the node
with *all* its outgoing edges, `-(e)-n-(e)-n`). *`form`*: `original` (values as
written, a diff-overlaid claim's delta) or `materialized` (values with any
`contribution/diff` chain resolved over the predecessor it references, recursively
to a base claim). *`content`*: a pair, `max`
capping the bytes inlined per claim and `overflow` handling anything past the cap —
`cutoff` (truncate), `omit` (drop it), or `reference` (a `content_hash` stub);
absent, no content is inlined and a claim carries only `content_hash` (foundation
paper §Content). *`encoding`*: `json` (text, content base64-encoded) or `cbor`
(binary), carrying the same information either way.]

A claim always carries every outgoing edge of its node (foundation paper §Claims),
so `claims` is richer than the `graph` view, which shows only the edges linking
results. `form` is a property of the values rather than the structure, which is what
makes it orthogonal to `detail` and `encoding`.

Materialisation resolves field values only. A claim's id, contributor, signature
and `created_at` are always its own, whatever a diff chain supplies for its other
fields — a diff claim is an ordinary claim, and every rule of @sec:v-adt applies to
it as stored. So verification runs against the stored claim, never a materialised
view.

#rule("R-QCANON", FREE)[The combination `detail: claims` + `form: original` +
`encoding: cbor` MUST reproduce the canonical serialization $S(v)$ the id is
computed over (foundation paper §Primitives). It is the only output form directly
verifiable against the id.]

== `order`, `limit`, `execution` <sec:rql-bounds>

#rule("R-QSORT", FREE)[`order` is a list of sort keys applied in priority order.
Each key names a `field`, a `compare` — how its values are ordered, `numeric` or
`lexical` — and a `dir`, `asc` or `desc`. Claims lacking a key's field sort last.
The archive's natural `(created_at, id)` order (RankeDB paper §Timestamping) breaks any
remaining ties, and applies alone when `order` is absent, so the sort MUST always
resolve to a total order.]

Because the order is total, paging is stable: carry the last row's key into a
`where` on the next request.

#rule("R-QLIMIT", FREE)[`limit` bounds the read: `results` caps the claim count and
`time` the execution budget, each `0` meaning unbounded. A read cut short by either
bound is a complete answer to the query as bounded, not an error.]

`execution` controls where the query runs and how it reports. `layer` pins the
query to one named storage/execution layer; without it the backend chooses by
capability. `report` sets a verbosity — `info` (high-level stages), `debug`
(routing and lowering), or `trace` (per-claim detail).

== Results and streaming <sec:rql-results>

A query yields an ordered stream, one element at a time in the query's order. Each
element is, per `output.shape`, a `single` reached endpoint or a `path` (its
route, start-first); `output.detail` sets how each node within it is carried:

#[
#show raw: set text(size: 0.82em)
```
Result =                // one stream element, per output.shape
    Element             //   shape = "single": a reached endpoint
  | [Element]           //   shape = "path": its route, start-first

Element =               // set by output.detail (field values per output.form)
    Id                  //   "id":     the id
  | Graph               //   "graph":  node + linking edges  (n-(e)-n)
  | Claim               //   "claims": node + all its edges  (-(e)-n-(e)-n)
// a Graph/Claim inlines content per content.{max, overflow}
```
]

#rule("R-QREPORT", FREE)[When, and only when, `execution.report` is set, the stream
carries one final *report* record after the last element: the layer that served the
query, the query it was lowered to (the Cypher/GQL text, or `native`), and per-stage
timings. It MUST be typed distinctly from result claims, so a reader never mistakes
it for data.]

= Remaining chapters <sec:remaining>

The normative surface beyond verification is to be written here, each chapter in
the same form — sentences, ids, FORCED/FREE tiers, grounded in the papers:

- *Serialization and identity* — the canonical $S$, the hash $H$, the signature
  scheme, and the alias table, decided here: the choices an implementation must
  make to reproduce a byte-identical serialization, stated as decisions rather
  than as code (foundation paper §Primitives).
- *Taxonomy and well-formedness* — the fixed node and edge classes, and the
  structural constraints each imposes (e.g. a `relation/*` node's edges land on
  `entity/*` claims and carry `relation_direction`) (foundation paper §Type Vocabulary,
  §Relations).
- *Wire encoding and endpoints* — request and response formats and the
  authentication surface (RankeDB paper §Endpoints and Authentication).

Until a chapter is written, the cited paper section governs.

= Open decisions <sec:open>

Details this document must fix, each a decision no other layer may make for it.
Until one is settled, the rule or chapter it belongs to is incomplete, and an
implementation is free where the specification is silent.

#todo[*The closed `contribution/*` subtype set.* Fix its exact members and their
names: whether the deletion marker is `delete`, as foundation paper §Type Vocabulary and
`R-DELMARK` have it, or another name; and whether `expiry` is a member, which
`R-RESERVED` and RankeDB paper §Contributor Keys Life Cycle assume. The set is closed,
so the membership is normative, unlike the open subtypes of the other classes.
(Taxonomy and well-formedness)]

#todo[*Whether `height` is carried or derived.* @sec:rql-height states it as a
derived field a query may name. If instead it is carried in the node record it
falls inside $S(v)$ — signed, and part of $op("id")(v)$ — and a rule MUST then
require the carried value to equal the computed one, since otherwise a contributor
can assert a level its references do not support. Decide which, and add that
consistency rule if carried — checking a carried height against the recursion also
checks the closure for cycles. (`R-HEIGHT`, `R-HEIGHT-FIELD`)]

#todo[*Whether `contribution/branch` is a node type.* foundation paper §Type Vocabulary
calls the branch entry edge-only — an edge naming a branch in a `name` field and
referencing its head. Decide whether a `contribution/branch` *node* also exists
and, if so, what it carries beyond that. (Taxonomy and well-formedness)]

#todo[*The omit half of a diff.* Overlay is defined, and only overlay: a diff claim
restates what differs. Dropping an inherited edge or field is not expressible by
restatement, so decide how a diff *removes* one — which fields name the dropped
set, and how materialisation applies them — or rule the removal out. The chapter
that owns claim semantics owns this definition; @sec:rql-output states only what a
query needs of it. (foundation paper §Claims, Taxonomy and well-formedness)]

= Annex — The Reference Archive <sec:fixture>

Every example in this specification is stated against one small, fixed archive,
defined once in this annex. The chapters above point at its claims by *symbolic*
label (`src₁`, `bt₂`, …) rather than by real id, because a real id is
$"Sign"(H(S(v)))$ — opaque. The labels are a reading convenience; the archive's
authoritative structure is the claim listing in @tbl:archive.

This annex is also the source for the fixture a conformance suite (RankeDB paper
§Conformance) runs on: there the same archive is materialised into real
serializations and its hashes pinned as the expected values, where here it is
narrated in labels and pictures. One fixture in two registers is what lets a
verification or query example read as prose while remaining what the oracle
asserts, and the direction is one-way — a materialisation follows this annex,
never the reverse.

The archive holds three content branches over a six-revision branch-table chain,
plus the reserved system branch:

- *`project_x`* — a provenance chain: a `source` (`src₁`), a `derivation` from it
  (`der₁`), and a later revision (`der₃`), its head.
- *`master`* — a semantic graph, following the analysis direction of
  §Taxonomy: a `derivation` (`der₂`) *extracts* from `src₁`, the entities it
  resolved cite it (`ent₁` person, `ent₂` org $arrow.r$ `der₂`), and a `relation`
  reifies how they relate (`rel₁` employment $arrow.r$ `ent₁`, `ent₂`). Its head
  `der₄` runs the *other* way — a *distillation* summary that condenses the
  cluster (`der₄` $arrow.r$ `rel₁`; foundation paper §Levels of Distillation).
- *`review`* — Bob's branch: a `derivation/review` (`der₅`) over `master`'s `der₄`
  and over a `source` Bob captured (`src₂`), its head.

The author keys sign under the Sequencer's initial node `c_seq`. `c_alice`'s first
key carries a `pubkey_expires_after` date; when it lapses, Alice *rotates* into a
fresh key — a second `contribution/contributor`, `c_alice2`, with its own
`pubkey_valid_from` overlapping the old window (RankeDB paper §Keyrotation). `der₃` and
`der₄`, dated after the first key lapsed, are signed by `c_alice2`; her earlier
claims by `c_alice`. A claim dated outside a key's window fails verification
(`R-KEYWIN`). `c_bob` is a third author, with his own key window.

Both forms of deletion (RankeDB paper §Deletion) appear. `src₂` carries a `delete_by`
date, a *planned* deletion (`R-DELBY`); `der₅`'s edge to it copies that date, so
the schedule travels with the reference, no propagation needed. `del₁` is a
*requested* deletion (`R-DELMARK`): a `contribution/delete` claim naming `src₁` as
its target, minted by the Sequencer and held in the reserved system branch
`$system` — the archive's internal index of limiting claims, read at startup for
fast lookup by target (RankeDB paper §Cross-Branch). Because `src₁` is reached from
every content branch, the delete propagates to each (`R-LIMIT-PROP`); verification
then accepts the explained gap (`R-GAP`).

A Ranke-Archive is a single graph and its branches are only subgraphs, so a claim
may reference one in another branch as a matter of course — `der₂` (`master`)
references `src₁` (`project_x`), and `der₅` (`review`) references `der₄`
(`master`), both ordinary `derivation` edges.

#figure(
  caption: [The reference archive at head `bt₅`. Nodes are claims, tinted by
  class. Solid black edges are reference edges — `derivation`, `relation/*`
  (labelled `from`/`to`), and `del₁`'s `contribution/delete` edge to the deleted
  `src₁`. Blue edges are the branch-table chain, each table referencing its
  predecessor. Dotted edges
  are `contribution/branch`, naming each branch's current head, including the
  reserved `$system` branch that indexes limiting claims. The faint grey lines are
  the `contribution/contributor` edges — every claim to its contributor: content
  to `c_alice` or `c_bob`, branch tables and `del₁` to `c_seq` (the Sequencer),
  and `c_alice`/`c_bob` to the initial node `c_seq`.],
  diagram(spacing: (10mm, 9mm), node-stroke: 0.5pt, node-inset: 4pt, {
    // branch-table chain (archive head bt5), across the top
    node((0, 0),   $"bt"_0$, name: <bt0>, fill: tint.contribution)
    node((0.9, 0), $"bt"_1$, name: <bt1>, fill: tint.contribution)
    node((1.8, 0), $"bt"_2$, name: <bt2>, fill: tint.contribution)
    node((2.7, 0), $"bt"_3$, name: <bt3>, fill: tint.contribution)
    node((3.6, 0), $"bt"_4$, name: <bt4>, fill: tint.contribution)
    node((4.5, 0), $"bt"_5$, name: <bt5>, fill: tint.contribution)
    // current branch heads: project_x, master, review, $system
    node((1.3, 1.4), $"der"_3$, name: <d3>, fill: tint.derivation)
    node((3.0, 1.4), $"der"_4$, name: <d4>, fill: tint.derivation)
    node((4.6, 1.4), $"der"_5$, name: <d5>, fill: tint.derivation)
    node((5.8, 1.4), $"del"_1$, name: <dl>, fill: tint.contribution)
    // master runs deep: der_4 -> rel_1 -> {ent} -> der_2 -> src_1 (analysis direction)
    node((1.3, 2.6), $"der"_1$, name: <d1>, fill: tint.derivation)
    node((3.0, 2.6), $"rel"_1$, name: <r1>, fill: tint.relation)
    node((4.6, 2.6), $"src"_2$, name: <s2>, fill: tint.source)
    node((2.5, 3.7), $"ent"_1$, name: <e1>, fill: tint.entity)
    node((3.5, 3.7), $"ent"_2$, name: <e2>, fill: tint.entity)
    node((3.0, 4.8), $"der"_2$, name: <d2>, fill: tint.derivation)
    node((1.3, 6.0), $"src"_1$, name: <s1>, fill: tint.source)
    // contributors
    node((0.4, 7.2), $c_"seq"$,    name: <cs>,  fill: tint.contribution)
    node((2.0, 7.2), $c_"alice"$,  name: <ca>,  fill: tint.contribution)
    node((3.4, 7.2), $c_"alice2"$, name: <ca2>, fill: tint.contribution)
    node((4.8, 7.2), $c_"bob"$,    name: <cb>,  fill: tint.contribution)

    // branch-table chain — each table holds its predecessor
    edge(<bt1>, <bt0>, "-|>", stroke: diff-stroke)
    edge(<bt2>, <bt1>, "-|>", stroke: diff-stroke)
    edge(<bt3>, <bt2>, "-|>", stroke: diff-stroke)
    edge(<bt4>, <bt3>, "-|>", stroke: diff-stroke)
    edge(<bt5>, <bt4>, "-|>", stroke: diff-stroke)
    // contribution/branch — each revision's head
    edge(<bt1>, <d1>, "-|>", dash: "dotted")
    edge(<bt2>, <r1>, "-|>", dash: "dotted")
    edge(<bt3>, <d3>, "-|>", [`project_x`], dash: "dotted")
    edge(<bt3>, <d4>, "-|>", [`master`], dash: "dotted")
    edge(<bt4>, <d5>, "-|>", [`review`], dash: "dotted")
    edge(<bt5>, <dl>, "-|>", [`$system`], dash: "dotted")
    // reference edges: source <- derivation <- entities <- relation (analysis),
    // and der_4 a distillation summary of the relation cluster
    edge(<d1>, <s1>, "-|>")
    edge(<d3>, <d1>, "-|>")
    edge(<d2>, <s1>, "-|>")
    edge(<e1>, <d2>, "-|>")
    edge(<e2>, <d2>, "-|>")
    edge(<r1>, <e1>, "-|>", [from])
    edge(<r1>, <e2>, "-|>", [to])
    edge(<d4>, <r1>, "-|>")
    edge(<d5>, <d4>, "-|>")
    edge(<d5>, <s2>, "-|>")
    edge(<dl>, <s1>, "-|>")
    // contribution/contributor (faint): every claim to its contributor
    for c in (<s1>, <d1>, <d2>, <r1>, <e1>, <e2>) { edge(c, <ca>, "-|>", stroke: ctr-stroke) }
    for c in (<d3>, <d4>) { edge(c, <ca2>, "-|>", stroke: ctr-stroke) }
    for c in (<s2>, <d5>) { edge(c, <cb>, "-|>", stroke: ctr-stroke) }
    for c in (<bt0>, <bt1>, <bt2>, <bt3>, <bt4>, <bt5>, <dl>) { edge(c, <cs>, "-|>", stroke: ctr-stroke) }
    for c in (<ca>, <ca2>, <cb>) { edge(c, <cs>, "-|>", stroke: ctr-stroke) }
  }),
) <fig:archive>

The listing is authoritative. `created_at` is monotone along every reference
(`V-MONO`); each contributor's key window covers the dates it signs (`R-KEYWIN`);
the `name` on a `contribution/branch` edge is its branch label.

#figure(
  caption: [The reference archive as a claim listing. Edges are written
  `target (edge class)`; the `contribution/contributor` edge is abbreviated
  #emph[ctr]. The archive head is `bt₅`.],
  table(
    columns: (auto, auto, auto, 1fr),
    align: (left, left, left, left),
    inset: (x: 6pt, y: 3pt),
    stroke: 0.4pt + gray,
    table.header([*label*], [*type*], [*`created_at`*], [*edges*]),
    [`c_seq`],  [`contribution/contributor`], [2026-01-05], [— (initial node; the Sequencer; `pubkey` in content)],
    [`c_alice`], [`contribution/contributor`], [2026-01-20], [`c_seq` (ctr); `pubkey`, `pubkey_valid_from` 2026-01-20, `pubkey_expires_after` 2026-03-31 in content (Alice's first key)],
    [`c_alice2`],[`contribution/contributor`], [2026-03-20], [`c_seq` (ctr); `pubkey`, `pubkey_valid_from` 2026-03-20 in content (Alice's rotated key)],
    [`c_bob`],   [`contribution/contributor`], [2026-05-01], [`c_seq` (ctr); `pubkey`, `pubkey_valid_from` 2026-05-01, `pubkey_expires_after` 2026-11-30 in content],
    [`src_1`],  [`source/document`],     [2026-02-03], [`c_alice` (ctr)],
    [`der_1`],  [`derivation/summary`],  [2026-02-04], [`src_1` (derivation), `c_alice` (ctr)],
    [`der_2`],  [`derivation/extraction`],[2026-02-20], [`src_1` (derivation), `c_alice` (ctr)],
    [`ent_1`],  [`entity/person`],       [2026-03-01], [`der_2` (derivation), `c_alice` (ctr)],
    [`ent_2`],  [`entity/org`],          [2026-03-01], [`der_2` (derivation), `c_alice` (ctr)],
    [`rel_1`],  [`relation/employment`], [2026-03-02], [`ent_1` (relation, from), `ent_2` (relation, to), `c_alice` (ctr)],
    [`der_3`],  [`derivation/revision`], [2026-04-01], [`der_1` (derivation), `c_alice2` (ctr)],
    [`der_4`],  [`derivation/summary`],  [2026-04-01], [`rel_1` (derivation), `c_alice2` (ctr)],
    [`src_2`],  [`source/log`],        [2026-05-08], [`c_bob` (ctr); `delete_by` 2027-05-08 in content],
    [`der_5`],  [`derivation/review`], [2026-05-10], [`der_4` (derivation), `src_2` (derivation; edge copies `delete_by`), `c_bob` (ctr)],
    [`del_1`],  [`contribution/delete`],[2026-06-01], [`src_1` (contribution/delete), `c_seq` (ctr); limiting claim, in `$system`],
    [`bt_0`],   [`contribution/branches`], [2026-01-05], [`c_seq` (ctr); empty table],
    [`bt_1`],   [`contribution/branches`], [2026-02-05], [`bt_0` (diff), `der_1` (branch #emph[name] `project_x`), `c_seq` (ctr)],
    [`bt_2`],   [`contribution/branches`], [2026-03-06], [`bt_1` (diff), `rel_1` (branch #emph[name] `master`), `c_seq` (ctr)],
    [`bt_3`],   [`contribution/branches`], [2026-04-02], [`bt_2` (diff), `der_3` (branch #emph[name] `project_x`), `der_4` (branch #emph[name] `master`), `c_seq` (ctr)],
    [`bt_4`],   [`contribution/branches`], [2026-05-11], [`bt_3` (diff), `der_5` (branch #emph[name] `review`), `c_seq` (ctr)],
    [`bt_5`],   [`contribution/branches`], [2026-06-02], [`bt_4` (diff), `del_1` (branch #emph[name] `$system`), `c_seq` (ctr)],
  ),
) <tbl:archive>

Each branch-table revision is one contribution. `bt₀` initialises the archive
(`c_seq` and the empty table); `bt₁` adds `project_x` (`src₁`, `der₁`); `bt₂` adds
`master`, with the extraction `der₂`, the entities `ent₁`/`ent₂`, and the relation
`rel₁` (its head). `bt₃` extends both, contributing `der₃` and `der₄`, the latter
distilling `master`'s cluster, both signed by Alice's rotated key `c_alice2`. `bt₄`
adds `review`, registering `c_bob` and contributing `src₂` and `der₅`, and `bt₅`
records the requested deletion, where the Sequencer mints `del₁` and opens
`$system` over it. Every revision restates only its delta, so materialising back to
`bt₀` yields the current table: `project_x` → `der₃`, `master` → `der₄`,
`review` → `der₅`, `$system` → `del₁`.

Every claim signs under the initial node `c_seq`, the Sequencer, which alone
signs branch tables and limiting claims (`R-RESERVED`, `V-SIG`). The content
authors are Alice — two keys, `c_alice` and its rotation `c_alice2` — and Bob
(`c_bob`), each a `contribution/contributor` resolving to `c_seq`. For legibility
the fixture keeps `del₁` only in `$system`; `R-LIMIT-PROP` places a reference to
it in every content branch that reaches `src₁`. The papers leave the system
branch's name open: `$system` is this document's choice.
