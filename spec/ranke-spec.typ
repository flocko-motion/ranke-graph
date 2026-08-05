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
  #grid(columns: (8.5em, 1fr), column-gutter: 0.6em,
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

Where a subject warrants a family of its own, the `R` is followed by a category
prefix: `R-C…` for contributions, `R-A…` for access, `R-D…` for deletion, and
`R-Q…` for the query language.

*Examples.* Every example in this specification is stated against the reference
archive (@sec:fixture) with labelled claims e.g. `src₁`, `bt₂`.

= Graph Verification <sec:verification>

*Verification* decides whether a set of claims is a *valid* Ranke-Graph and,
in RankeDB, whether a contribution may be admitted to an existing archive. The ADT
rules (@sec:v-adt) decide validity, and every one is FORCED — portable to any Ranke
implementation. The rest are RankeDB's own: contributions (@sec:v-contribution),
deletion (@sec:v-deletion), and access (@sec:v-access). (foundation paper
§Verifiability, RankeDB paper §Verification and Witnessing)

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

== Contribution rules <sec:v-contribution>

A *contribution* is a set of claims added to the archive in one transaction: all of
them, or none. Its procedure is fixed by the RankeDB paper §Sequencer in six steps,
whose numbers the rule ids below carry:

1. *Opening* — the base $(k, t)$ is taken.
2. *Adding* — the contribution's claims are added.
3. *Completing* — it is closed over its references.
4. *Verifying* — every claim is checked against the base, and the contribution
   sealed.
5. *Persisting* — its whole closure is stored durably.
6. *Merging* — the Sequencer contributes a new branch table claim referencing the
   contribution's head claims, and the archive's head advances, $k arrow.r k'$.

Step 1's access check is the `R-A…` family of @sec:v-access.

#rule("R-C1BASE", FREE)[Opening a contribution takes its *base* $(k, t)$: $k$ the
archive's current head, $t$ the current system time. (RankeDB paper §Sequencer,
step 1)]

#rule("R-C2DATE", FREE)[Every claim added in a contribution MUST be dated
`created_at`$lt.eq t$, the base time. Since $t$ precedes the merge, no claim can be
future-dated. (RankeDB paper §Sequencer, step 2; §Timestamping)]

#rule("R-C2TYPE", FREE)[A contribution from a system account MUST NOT contain
*limiting claims* (`contribution/delete`, `contribution/expiry`) or *branch-table*
claims (`contribution/branches`): these types are created by the Sequencer alone.
A system account MAY commit a *request* instead — a
`contribution/expires_after_request` or `contribution/delete_request` edge — which the
Sequencer honours at merge (`R-C6REQUEST`). (RankeDB paper §Sequencer, step 2;
§Contributor Keys Life Cycle)]

#rule("R-C3CLOSE", FREE)[Before verification a contribution MUST be *closed*: each
claim's references are followed, drawing in every referenced claim outside the
contribution — from another branch or the wider Universe — recursively, until every
path reaches a claim already in the base's closure. Drawing in a branch-external
claim requires read access to its branch (*R-ABRANCH*) and carries its limiting
claims with it (`R-C3LIMIT`). (RankeDB paper §Sequencer, step 3)]

#rule("R-C3LIMIT", FREE)[A branch that holds a claim MUST also hold every limiting
claim against it — a `contribution/delete` or `contribution/expiry` naming it as
target. (RankeDB paper §Cross Branch Propagation)]

#rule("R-C4KEY", FREE)[Each claim MUST be dated within the validity of the key it is
signed under — the `pubkey` of the contributor it references, valid as `R-DEXPIRY`
defines. (RankeDB paper §Sequencer, step 4)]

#rule("R-C4SEAL", FREE)[Once verified, a contribution is *sealed*: its contents are
fixed and admit no further addition or removal. By immutability, whatever
verified against the base stays valid however long it waits before merging.
(RankeDB paper §Sequencer, step 4)]

#rule("R-C5PERSIST", FREE)[The sealed contribution's whole closure MUST be durably
present in the Universe — stored and propagated across the storage layers —
*before* the Sequencer merges it. (RankeDB paper §Sequencer, step 5)]

#rule("R-C6MERGE", FREE)[Every branch table MUST hold its predecessor in provenance,
so the chain from the archive's head reaches the initial table unbroken (foundation
paper §Ranke-Archive). Its `contribution/branch` edges MUST name, for each branch
they bind, the head claims of the contribution merged there. (RankeDB paper
§Sequencer, step 6)]

#rule("R-C6REQUEST", FREE)[Every request a merged contribution carries (`R-C2TYPE`)
MUST produce its limiting claim in the same merge. That claim MUST carry the same
`created_at` as the branch table (`V-MONO` admits equality), and a
`pubkey_expires_after` it sets MUST fall no earlier than that date. Every claim
already in the archive stays valid, and so does every claim in a contribution still
open, whose base time precedes the merge (`R-C1BASE`). (RankeDB paper §Sequencer,
step 6; §Contributor Keys Life Cycle)]

#rule("R-C6SIGN", FREE)[Every claim the Sequencer creates (`R-C2TYPE`) MUST carry a
`contribution/contributor` edge naming the contributor claim configured as the
Sequencer's identity. (RankeDB paper §Sequencer)]

== Deletion rules <sec:v-deletion>

Deletion takes two forms (RankeDB paper §Deletion). A *planned* deletion is intrinsic:
the claim carries its own `delete_by` date from creation, and a sweep deletes it when
due. A *requested* deletion is extrinsic and retroactive: a later limiting claim names
the target, and the Sequencer carries it out. Each leaves an explained gap of its own
kind, which is what lets verification pass over either (`R-DGAP`).

#rule("R-DPLANNED", FREE)[A *planned* deletion is a `delete_by` date carried in a claim's
signed content from creation. Every edge referencing that claim MUST copy the date, so
the gap stays explained wherever the claim is reached. (RankeDB paper §Deletion)]

#rule("R-DREQUEST", FREE)[A *requested* deletion is documented by a `contribution/delete`
claim: a node of that class carrying a `contribution/delete` edge to its *target*, the
deleted claim. A system account requests a deletion (`R-C2TYPE`); the Sequencer carries
it out (`R-C6REQUEST`). (RankeDB paper §Deletion)]

#rule("R-DGAP", FREE)[Verification MUST pass over a graph holding a physically deleted
claim when — and only when — an *explained gap* covers it: a `contribution/delete` mark
against it (`R-DREQUEST`), or a copied `delete_by` (`R-DPLANNED`). Without such a gap,
the missing claim fails `V-REF`. (RankeDB paper §Deletion)]

#rule("R-DEXPIRY", FREE)[A contributor's key is valid within the closed window from
`pubkey_valid_from` through `pubkey_expires_after` (both RFC 3339, both optional) on
the contributor claim; a contributor carrying neither is valid at any date. A
`contribution/expiry` edge against that contributor carries an earlier
`pubkey_expires_after` and moves the end of the window to it. That edge is carried
either by a `contribution/expiry` claim or by the `contribution/contributor` claim
introducing the successor key, and `R-C3LIMIT` keeps that claim in every branch
reaching the contributor. (RankeDB paper §Contributor Keys Life Cycle, §Cross Branch
Propagation)]

== Access rules <sec:v-access>

The `R-A…` family of access rules governs reads, contributions, and administration
(RankeDB paper §Access Control).

#rule("R-AGRANT", FREE)[A *grant* is a triple: a system account, a target, and the
rights it holds there, written as the letters *C*, *R*, *U*, and *D*. Accounts and
their grants are fixed in the configuration; a target is a branch-name glob or a
reserved `$`-prefixed target. Every operation requires its letter on its target, and the rules
below fix what each letter does at each target.]

#rule("R-ABRANCH", FREE)[On a branch: *C* contributes a claim, *R* reads, *U* requests
an early expiry (`R-DEXPIRY`), and *D* requests a deletion — the `contribution/delete`
mark and the physical removal that follows (`R-DREQUEST`). *U* and *D* are each
required on every branch reaching the claim, since a limiting claim propagates to all
of them (`R-C3LIMIT`).]

#rule("R-ATABLE", FREE)[On `$branches`, the branch tables: *C* adds a new branch to the
table, *R* reads it, and *D* soft-deletes a branch by creating a new table that omits it.]

#rule("R-AUNIVERSE", FREE)[On `$universe`: *R* alone, and *privileged* — a head id
bypasses the branch table, so it reaches any graph the Universe holds.]

= RankeQL (RQL) <sec:rql>

A read is a *RankeQL* (RQL) query: a declarative value of the data type `Query` fixed
below. RQL is RankeDB's own — a query language over the Ranke-Graph, introduced in the
RankeDB paper §Filtered Reads — and the ADT defines no query language, so this whole
chapter is `[FREE]`.

RQL's capabilities are a subset of Cypher and of the ISO standard it converges on, the
Graph Query Language (GQL), and a query is designed to transform directly into a Cypher
query that executes efficiently on Neo4j. 

RQL is natively expressed in JSON, which is well known and has robost encoders and encoders
in many languages. 

== The query type <sec:rql-type>

This chapter fixes the type, what each field's values *mean*, and the value an omitted
field takes. `select` is the only required field; every other default is stated with
the type below, so a caller may rely on it.

Field names ending in `?` are optional, and each carries its default; `|` lists the
allowed values or forms; `[T]` is a list of `T`. An `Id` is a claim id in textual form:
multibase base32 of the self-describing payload, matching `^b[a-z2-7]+$`. A `duration`
is a decimal sequence with unit suffixes — `ns`, `us`, `ms`, `s`, `m`, `h`, as in `5s`
or `1m30s` — where the bare `0` means unbounded. A `Claim` is a claim record as
`output` carries it (@sec:rql-output).

#[
#show raw: set text(size: 0.82em)
```
Query = {
  select:     Select
  where?:     Where          // absent -> no filter
  output?:    Output         // absent -> every axis at its default
  order?:     Order          // absent -> natural (created_at, id)
  limit?:     Limit          // absent -> unbounded
  execution?: Execution      // absent -> backend picks the layer, no report
}

Select = {                   // a generator: scope, closure, start, traversal
  branch:  string            // "$universe" | "$archive" | a branch name
  head?:   Id                // narrows to closure(head); required under "$universe"
  claim?:  Id                // walk start in the closure; absent -> unanchored
  path?:   [PathStep]        // absent -> the full outward closure of the frontier
}

PathStep = {                 // follow typed edges for min..max hops
  edges?:  [string]          // "class/sub" globs, "-" excludes; absent -> any edge
  dir?:    "provenance" | "uses" | "connections"    // absent -> "provenance"
  min?:    int               // fewest hops; absent -> 1; 0 -> yields its start too
  max?:    int               // most hops; 0 or absent -> unbounded
  nodes?:  [string]          // yielded node globs, "-" excludes; absent -> any node
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
  shape?:    "single" | "path"                      // elements | routes; absent -> "single"
  detail?:   "id" | "graph" | "claims"              // absent -> "id"
  form?:     "original" | "materialized"            // as written | resolved; absent -> "original"
  content?:  {                                      // inline content per claim; absent -> none
    max:      int                                   // cap in bytes
    overflow: "cutoff" | "omit" | "reference"       // handling past max
  }
  encoding?: "json" | "cbor"                        // text (base64) | binary; absent -> "json"
}

Order    = [OrderKey]      // sort keys in priority order; ties -> natural (created_at, id)
OrderKey = {
  field:    string
  compare?: "numeric" | "lexical"   // absent -> the field's own domain
  dir?:     "asc" | "desc"          // absent -> "asc"
}

Limit = { results?: int, time?: duration }          // each 0 -> unbounded

Execution = {
  layer?:  string            // pin one storage layer
  report?: "info" | "debug" | "trace"               // optional execution report
}
```
]


#rule("R-QEVAL", FREE)[A query is evaluated in a fixed logical order: (1) `select`
generates the result set, (2) `where` filters it, (3) `order` sorts it, (4)
`limit.results` truncates it, (5) `output` shapes and encodes the result set. The fields
`limit.time` and `execution` configure the engine that runs the query, leaving its logic
untouched. An engine MAY reorder or translate these steps, provided the delivered result set
is identical to what this order produces; the native reference engine is the oracle for
conformance testing. (RankeDB paper §Filtered Reads, §Conformance)]

== `select` — the generator <sec:rql-select>

The `select` block is the *generator*. It answers two questions, and its fields divide
along them: *which graph is read*, and optionally *where a traversal starts* — the
*frontier*, the set of claims a walk starts from, either the single claim `claim` defines
or every claim in the closure when it names none.

`path` is a series of steps, and a walk takes them in order without leaving the graph
read. A `provenance` step follows references outward; a `uses` step runs the other way,
to the claims that cite the current one.

#rule("R-QSCOPE", FREE)[`branch` defines the *scope*: the graph within which the query is
executed. Only that graph is read. A branch name confines the query to that branch's
closure, `$archive` to the whole Ranke-Archive, and `$universe` to the closure of the
`head` it requires (`R-QHEAD`). An empty `branch` MUST be rejected. The scope is what a
grant is held against (`R-AGRANT`).]

#rule("R-QHEAD", FREE)[`head` fixes the *closure* read: the query sees the intersection
of the scope's graph and $"closure"("head", cal(U))$, so a `head` narrows a query. Under
`$universe` it is *required* and MAY name any claim the Universe holds; under every other
scope it is *optional*.]

#rule("R-QANCHOR", FREE)[`claim` *anchors* the frontier at the single claim it names,
which MUST lie inside the closure. Absent, the frontier is every claim in the closure
and the path is *unanchored*.]

An anchored generator asks what one claim reaches; an unanchored one asks where a
shape occurs, which is Cypher's `MATCH` with and without a bound variable. Both are
bounded alike by the closure, and unanchored with no step names the closure itself.

#rule("R-QSTEPS", FREE)[A `PathStep` states the conditions one section of a path MUST
satisfy. `edges` bounds the walk: every hop MUST follow an edge whose `type` is listed.
`nodes` bounds the answer: a step yields a claim only when its node's `type` is listed,
whatever the nodes it crossed to reach it. Both take globs over `class/sub`, a leading `-`
excluding a type, and filter only when given. Exclusion decides: a type matching an
excluded pattern is refused whatever the included patterns say, and a list of exclusions
alone admits every other type. `dir` sets the traversal direction:
`provenance` (outgoing, towards references, and the default), `uses` (incoming), or
`connections` (either). `min` and `max` bound the hops
a step takes: an absent `min` is 1, `min: 0` also yields the frontier it starts from, and
a `max` of `0` or an absent `max` leaves the step unbounded. A `min` above a bounded `max`
MUST be rejected. An absent `path` returns the full outward closure of the frontier
(foundation paper §Closures).]

The two zeros of `R-QSTEPS` differ because each has only one useful sense: a step of
at most zero hops would move nothing, so `max: 0` means unbounded, while `min: 0`
yields the starting set alongside what lies beyond it.

#rule("R-QFRONTIER", FREE)[A `path` is a sequence of steps over *frontiers*, each frontier
a *set* of claims. The first is the claim `claim` anchors, or every claim in the closure
when it names none (`R-QANCHOR`); each step's yield is the frontier the next step starts
from (`R-QSTEPS`). Membership is all a frontier carries, so a result MUST NOT depend on
the route by which a claim entered one. The no-repeat rule — a walk does not revisit a
claim — holds within a single step and resets at each boundary, so a later step MAY
re-cross a claim or re-traverse an edge an earlier step used.]

This is the one place RQL departs from Cypher, whose single-trail reading with
whole-path edge-uniqueness drops results `R-QFRONTIER` admits; the RankeDB
paper §Filtered Reads works the case through.

*(Planned.)* When a query returns a route (`shape: path`), a caller may want to
constrain the route's *shape* — no repeated edges, or no repeated nodes. A future
opt-in modifier on a path or step will expose the ISO GQL path modes (`WALK`,
`TRAIL`, `ACYCLIC`, `SIMPLE`); the default remains `R-QFRONTIER` above.

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
that claim's closure (`R-C3CLOSE`) and retain it, so a claim later deleted keeps the
height it entered with (`R-DGAP`).]

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
which a layer that indexes the field answers as a range lookup.

In the reference archive the contributors sit at 1 (`c_seq`, an initial node) and 2
(`c_alice`, `c_alice2`, `c_bob`); `src₁` and `src₂` at 3; `der₁`, `der₂` and `del₁`
at 4; `der₃` and the entities at 5; `rel₁` at 6; `der₄` at 7; `der₅` at 8; and the
archive head `bt₅` at 10. A bound of `le: 4` over `master` therefore keeps `src₁`,
`der₂` and the contributor claims, leaving `ent₁`/`ent₂` (5), `rel₁` (6) and the
head `der₄` (7) outside it.

Height measures derivation structure: it answers 'up to $h$ levels of derivation above
the sources'. A claim contributed today at a low height — a fresh source, or a derivation
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
results. `form` is a property of the values, which is what makes it orthogonal to
`detail` and `encoding`.

Materialisation resolves field values only. A claim's id, contributor, signature
and `created_at` are always its own, whatever a diff chain supplies for its other
fields — a diff claim is an ordinary claim, and every rule of @sec:v-adt applies to
it as stored. So verification runs against the stored claim, never a materialised
view.

#rule("R-QCANON", FREE)[The combination `detail: claims` + `form: original` +
`encoding: cbor` MUST reproduce the canonical serialization $S(v)$ the id is
computed over (foundation paper §Primitives). It is the only output form directly
verifiable against the id.]

== `order`, `limit`, `execution` — sort, bounds, and engine <sec:rql-bounds>

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

#rule("R-QLAYER", FREE)[`execution.layer` pins the query to one named storage or
execution layer, and an empty name MUST be rejected. Absent, the backend chooses by
capability. The choice reaches execution alone: the result set MUST be identical
whichever layer serves it (`R-QEVAL`).]

`report` sets a verbosity — `info` (high-level stages), `debug` (routing and
translation), or `trace` (per-claim detail).

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
query, the query it was translated to (the Cypher/GQL text, or `native`), and per-stage
timings. It MUST be typed distinctly from result claims, so a reader never mistakes
it for data.]

== Translation to Cypher <sec:rql-cypher>

A query translates to a single Cypher statement, which is what lets a graph database
serve it natively. This section fixes that translation. It defines no meaning of its
own: a translated query answers exactly what the rules above define, and the native
reference engine settles any disagreement (`R-QEVAL`).

#rule("R-QCYPHER", FREE)[A translation MUST deliver the result set this chapter defines,
in the order it defines. Where a translated query and the native engine disagree, the
translation is the defect.]

#rule("R-QCCLAUSE", FREE)[Block by block: `select` translates to a `MATCH`, bound to a
variable when `claim` anchors it; `where` to a `WHERE` over the endpoint; `order` to an
`ORDER BY` carrying the `(created_at, id)` tie-break (`R-QSORT`); `limit.results` to a
`LIMIT`; and `output.detail` to the `RETURN` projection — the id alone, or the node with
its labels and outgoing edges. The remaining fields stay outside the statement:
`output`'s `form`, `content`, and `encoding`, `limit.time`, and `execution` (`R-QEVAL`).]

#rule("R-QCSTEP", FREE)[A `PathStep` translates to a variable-length segment in its
`dir`, `*min..max`, an absent or `0` `max` leaving it unbounded. Its `edges` and `nodes`
globs translate to full-match conditions on that segment's relationship and node, and an
absent list imposes no condition (`R-QSTEPS`).]

#rule("R-QCFRONTIER", FREE)[A `path` MUST translate to one `MATCH` per step, each
carrying the previous step's endpoints forward as a distinct set. Cypher's edge-uniqueness
holds within a single pattern, so the step boundary is what resets it, as `R-QFRONTIER`
requires. A `path` translated as one continuous pattern drops results the frontier
pipeline returns.]

#rule("R-QCSCOPE", FREE)[However a translation confines a query — a walk from the scope's
head, or an index the backend maintains — the confined set MUST equal the scope's graph
(`R-QSCOPE`), and a reverse step MUST reach no claim outside it (`R-QHEAD`).]

= Remaining chapters <sec:remaining>

The normative surface beyond verification is to be written here, each chapter in
the same form — sentences, ids, FORCED/FREE tiers, grounded in the papers:

- *Serialization and identity* — the canonical $S$, the hash $H$, the signature
  scheme, and the alias table, decided here: the choices an implementation must
  make to reproduce a byte-identical serialization, stated as decisions
  (foundation paper §Primitives).
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

#todo[*The schema's authority over this chapter.* While the RankeQL chapter is under
review, the published query schema governs a query's shape and the chapter follows it
(@sec:rql). Settle the chapter, then restore the schema to what every artifact built
from this document is: a projection that checks the shapes stated here.]

#todo[*Whole-route uniqueness for a path shape.* `R-QFRONTIER` resets edge-uniqueness at
every step boundary, `shape: path` included, and `R-QCFRONTIER` requires a translation to
match. A route assembled that way may re-cross an edge, which GQL calls a `WALK`; the
stricter readings are `TRAIL`, `ACYCLIC`, and `SIMPLE` (@sec:rql-select). Decide whether a
path shape keeps the `WALK` reading, and if not, whether the stricter one is a mode the
caller asks for or the only reading available.]

#todo[*Which route a path shape returns.* `R-QOUTPUT` says a `path` yields routes without
fixing how many per endpoint. Decide whether an endpoint reached by several routes yields
one — the shortest, ties broken node-by-node on `(created_at, id)` — or all of them.]

#todo[*Which edge holds the predecessor.* `R-C6MERGE` requires the new branch table
to hold the previous one in its provenance, and foundation paper §Ranke-Archive
requires the same. §Branches names only `contribution/diff` as the link, and permits
a revision that restates the whole table — which carries no diff edge. Fix the edge
that holds the predecessor when the revision restates the whole table. (Taxonomy and
well-formedness)]

#todo[*The closed `contribution/*` subtype set.* Fix its exact members and their
names: whether the deletion marker is `delete`, as foundation paper §Type Vocabulary
and `R-DREQUEST` have it; whether `expiry` is a member, which `R-C2TYPE` and RankeDB
paper §Contributor Keys Life Cycle assume; and the request edges a system account uses
to ask for each — `contribution/expires_after_request` and
`contribution/delete_request` — which the papers name only for expiry, and without the
class prefix. The set is closed, so the membership is normative, unlike the
open subtypes of the other classes. (Taxonomy and well-formedness)]

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
defined once in this annex. Chapters above point at its claims by *symbolic* label
(`src₁`, `bt₂`, …), a reading convenience: a real id is $"Sign"(H(S(v)))$, and
opaque. The claim listing in @tbl:archive is the archive's authoritative structure.

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
(`R-C4KEY`). `c_bob` is a third author, with his own key window.

Both forms of deletion (RankeDB paper §Deletion) appear. `src₂` carries a `delete_by`
date, a *planned* deletion (`R-DPLANNED`); `der₅`'s edge to it copies that date, so
the schedule travels with the reference, no propagation needed. `del₁` is a
*requested* deletion (`R-DREQUEST`): a `contribution/delete` claim naming `src₁` as
its target, created by the Sequencer and held in the reserved system branch
`$system` — the archive's internal index of limiting claims, read at startup for
fast lookup by target (RankeDB paper §Cross-Branch). Because `src₁` is reached from
every content branch, the delete propagates to each (`R-C3LIMIT`); verification
then accepts the explained gap (`R-DGAP`).

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
(`V-MONO`); each contributor's key window covers the dates it signs (`R-C4KEY`);
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
records the requested deletion, where the Sequencer creates `del₁` and opens
`$system` over it. Every revision restates only its delta, so materialising back to
`bt₀` yields the current table: `project_x` → `der₃`, `master` → `der₄`,
`review` → `der₅`, `$system` → `del₁`.

Every claim signs under the initial node `c_seq`, the Sequencer, which alone
signs branch tables and limiting claims (`R-C2TYPE`, `V-SIG`). The content
authors are Alice — two keys, `c_alice` and its rotation `c_alice2` — and Bob
(`c_bob`), each a `contribution/contributor` resolving to `c_seq`. For legibility
the fixture keeps `del₁` only in `$system`; `R-C3LIMIT` places a reference to
it in every content branch that reaches `src₁`. The papers leave the system
branch's name open: `$system` is this document's choice.
