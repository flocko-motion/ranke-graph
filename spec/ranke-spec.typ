// spec/ranke-spec.typ — the Ranke Normative Specification.
//
// A companion document to the Ranke-Graph paper series, and the artifact an
// implementation FOLLOWS. The papers say WHAT and WHY in prose meant to be
// read once; this document says exactly what an implementation MUST do, rule by
// rule, in a form meant to be read repeatedly and cited precisely.
//
//   * The papers are the concept. They govern meaning; this spec must never
//     contradict them. Where it seems to, the foundation paper (Paper 01)
//     wins for ADT rules, Paper 02 for RankeDB rules.
//   * A JSON Schema, the conformance suite, and the reference implementation
//     are PROJECTIONS of this document: the schema checks the shapes named
//     here, each conformance case exercises a rule id here, the code enforces
//     them. None of those is a reading source; this is.
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
// The contribution/diff chain between branch tables — the archive's head history.
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
database, RankeDB. It exists because neither the papers, a JSON Schema, nor the
conformance suite is both *precise* and *readable*: the papers argue the design
but do not enumerate every rule; a schema checks field shapes but not the value
constraints, cross-claim invariants, or algorithms that decide validity; and the
conformance suite is an oracle — it tells an implementer *that* something is
wrong, never *which rule* and *why*. The rules live, exhaustively and in
sentences, only here.

It is *concept work*, and belongs in the papers' repository rather than in any
implementation: an implementation needs a fixed reference to follow, and cannot
serve as its own. This document is that fixed reference.

Status: draft. The Verification chapter (@sec:verification) is written; the
remaining chapters (@sec:remaining) are named but not yet written. Sections are
added rule by rule, each one grounded in the papers.

= How to Read This <sec:conventions>

*Normative keywords.* *MUST*, *MUST NOT*, *SHOULD*, *SHOULD NOT*, and *MAY* are
used as in RFC 2119. A *MUST* is a conformance condition: an implementation that
violates it is non-conformant, and a violating claim is rejected.

*Rule ids and tiers.* Each rule carries a stable id and a tier:

#rule("V-…", FORCED)[An *ADT rule* (`V` for validity/verification). Mandated by
the abstract data type in the foundation paper; *portable* — every conformant
Ranke implementation, database or not, enforces it identically. Changing one
changes the data structure.]

#rule("R-…", FREE)[A *RankeDB rule* (`R`). A choice RankeDB makes that the ADT
leaves open. Another implementation of the ADT *MAY* decide differently; a
conformant *RankeDB* MUST follow it.]

This FORCED / FREE split is the spec's spine: it tells a reader, and a second
implementer, exactly which rules are the immovable floor and which are RankeDB's
policy on top of it. It mirrors the same tagging used in Paper 02.

*Relation to the other artifacts.* A JSON Schema realises the *shapes* named in
these rules (which fields exist, their types); the conformance suite (Paper 02
§Conformance) supplies an executable case for rules whose effect is observable
through the API, each case citing the rule id it exercises; the reference
implementation enforces all of them. If any projection disagrees with this
document, the projection is wrong.

= The Reference Archive <sec:fixture>

Every example in this specification is stated against one small, fixed archive,
defined here once. Later chapters point at its claims by *symbolic* label
(`src₁`, `bt₂`, …) rather than by real id, because a real id is
$"Sign"(H(S(v)))$ — opaque. The labels are a reading convenience; the archive's
authoritative structure is the claim listing in @tbl:archive.

This same archive seeds the conformance suite (Paper 02 §Conformance). There it
is materialised into real serializations and its actual hashes are pinned as the
expected values; here it is narrated in labels and pictures. The two are one
fixture in two registers — which is what lets a verification or query example
read as prose while remaining exactly what the oracle asserts. It has a *single
source*; neither register may fork from the other.

The archive holds two content branches over a four-revision branch-table chain:

- *`project_x`* — a provenance chain: a captured `source` (`src₁`), a `derivation`
  built from it (`der₁`), and a later revision (`der₃`) extending the branch —
  its current head.
- *`master`* — a small semantic graph: two `entity` claims (`ent₁`, `ent₂`)
  joined by a `relation` (`rel₁`) and a `derivation` report over it (`der₂`),
  then extended by a follow-up note (`der₄`) — its current head.

The fourth revision `bt₃` advances *both* branch heads in one contribution
(`project_x` → `der₃`, `master` → `der₄`), showing that a branch is extended by
appending a claim over its previous head and repointing its `contribution/branch`
edge. The branches also overlap in exactly one place: `der₂` in `master` cites
`src₁` in `project_x` (the red edge below) — the single cross-branch reference the
access rules (`R-ACCESS`) and, later, limiting-claim propagation (`R-LIMIT-PROP`)
are demonstrated against.

#figure(
  caption: [The reference archive at head `bt₃`. Nodes are claims, tinted by
  class. Solid black edges are reference edges — `derivation` provenance and
  `relation/*` edges (the latter labelled `from`/`to` by their
  `relation_direction`). Blue edges are the `contribution/diff` chain between
  branch-table revisions — the archive's head history. Dotted edges are
  `contribution/branch`, naming each branch's current head. The red edge is the
  one cross-branch reference. The faint grey lines are the `contribution/contributor`
  edges: content claims to `c_alice`, branch tables to `c_seq` — the Sequencer,
  which alone signs them — and `c_alice` to `c_seq`, the archive's initial node.],
  diagram(spacing: (12mm, 10mm), node-stroke: 0.5pt, node-inset: 5pt, {
    // branch-table chain (archive head is bt3), trailing left of the branches
    node((0, 0),    $"bt"_0$, name: <bt0>, fill: tint.contribution)
    node((0.95, 0), $"bt"_1$, name: <bt1>, fill: tint.contribution)
    node((1.9, 0),  $"bt"_2$, name: <bt2>, fill: tint.contribution)
    node((2.85, 0), $"bt"_3$, name: <bt3>, fill: tint.contribution)
    // the two current branch heads
    node((1.9, 1.3), $"der"_3$, name: <d3>, fill: tint.derivation)
    node((3.7, 1.3), $"der"_4$, name: <d4>, fill: tint.derivation)
    // earlier head of each branch
    node((1.9, 2.6), $"der"_1$, name: <d1>, fill: tint.derivation)
    node((3.7, 2.6), $"der"_2$, name: <d2>, fill: tint.derivation)
    // content roots
    node((1.9, 3.9), $"src"_1$, name: <s1>, fill: tint.source)
    node((3.7, 3.9), $"rel"_1$, name: <r1>, fill: tint.relation)
    // entities
    node((3.2, 5.1), $"ent"_1$, name: <e1>, fill: tint.entity)
    node((4.2, 5.1), $"ent"_2$, name: <e2>, fill: tint.entity)
    // contributors: c_seq (the Sequencer — initial node, signs the branch
    // tables) and c_alice (content author, registered under c_seq)
    node((0.5, 6.4), $c_"seq"$,   name: <cs>, fill: tint.contribution)
    node((2.6, 6.4), $c_"alice"$, name: <ca>, fill: tint.contribution)

    // provenance / branch-table structure
    edge(<bt1>, <bt0>, "-|>", [diff], stroke: diff-stroke)
    edge(<bt2>, <bt1>, "-|>", [diff], stroke: diff-stroke)
    edge(<bt3>, <bt2>, "-|>", [diff], stroke: diff-stroke)
    edge(<bt1>, <d1>,  "-|>", dash: "dotted")
    edge(<bt2>, <d2>,  "-|>", dash: "dotted")
    edge(<bt3>, <d3>,  "-|>", [`project_x`], dash: "dotted")
    edge(<bt3>, <d4>,  "-|>", [`master`], dash: "dotted")
    edge(<d3>, <d1>,   "-|>", [`derivation`])
    edge(<d4>, <d2>,   "-|>", [`derivation`])
    edge(<d1>, <s1>,   "-|>", [`derivation`])
    edge(<d2>, <r1>,   "-|>", [`derivation`])
    edge(<d2>, <s1>,   "-|>", [xref], stroke: 1pt + rgb("#dc2626"))
    edge(<r1>, <e1>,   "-|>", [from])
    edge(<r1>, <e2>,   "-|>", [to])
    // contribution/contributor (faint): content claims to c_alice, branch
    // tables to c_seq (the Sequencer signs them), and c_alice under c_seq.
    for c in (<s1>, <d1>, <d3>, <d2>, <d4>, <r1>, <e1>, <e2>) { edge(c, <ca>, "-|>", stroke: ctr-stroke) }
    for c in (<bt0>, <bt1>, <bt2>, <bt3>) { edge(c, <cs>, "-|>", stroke: ctr-stroke) }
    edge(<ca>, <cs>, "-|>", stroke: ctr-stroke)
  }),
) <fig:archive>

The listing is authoritative. `created_at` is monotone along every reference
(`V-MONO`); `c_alice`'s key window covers every date it signs (`R-KEYWIN`); the
`name` on a `contribution/branch` edge is its branch label.

#figure(
  caption: [The reference archive as a claim listing. Edges are written
  `target (edge class)`; the `contribution/contributor` edge is abbreviated
  #emph[ctr]. The archive head is `bt₂`.],
  table(
    columns: (auto, auto, auto, 1fr),
    align: (left, left, left, left),
    inset: (x: 6pt, y: 3pt),
    stroke: 0.4pt + gray,
    table.header([*label*], [*type*], [*`created_at`*], [*edges*]),
    [`c_seq`],  [`contribution/contributor`], [2026-01-05], [— (initial node; the Sequencer; `pubkey` in content)],
    [`c_alice`],[`contribution/contributor`], [2026-01-20], [`c_seq` (ctr); `pubkey`, `pubkey_valid_from` 2026-01-20, `pubkey_expires_after` 2026-12-31 in content],
    [`src_1`],  [`source/document`],   [2026-02-03], [`c_alice` (ctr)],
    [`der_1`],  [`derivation/summary`],[2026-02-04], [`src_1` (derivation), `c_alice` (ctr)],
    [`ent_1`],  [`entity/person`],     [2026-03-01], [`c_alice` (ctr)],
    [`ent_2`],  [`entity/org`],        [2026-03-01], [`c_alice` (ctr)],
    [`rel_1`],  [`relation/employment`],[2026-03-02],[`ent_1` (relation, from), `ent_2` (relation, to), `c_alice` (ctr)],
    [`der_2`],  [`derivation/report`], [2026-03-05], [`rel_1` (derivation), `src_1` (derivation, #text(fill: rgb("#dc2626"))[xref]), `c_alice` (ctr)],
    [`der_3`],  [`derivation/revision`],[2026-04-01], [`der_1` (derivation), `c_alice` (ctr)],
    [`der_4`],  [`derivation/note`],   [2026-04-01], [`der_2` (derivation), `c_alice` (ctr)],
    [`bt_0`],   [`contribution/branches`], [2026-01-05], [`c_seq` (ctr); empty table],
    [`bt_1`],   [`contribution/branches`], [2026-02-05], [`bt_0` (diff), `der_1` (branch #emph[name] `project_x`), `c_seq` (ctr)],
    [`bt_2`],   [`contribution/branches`], [2026-03-06], [`bt_1` (diff), `der_2` (branch #emph[name] `master`), `c_seq` (ctr)],
    [`bt_3`],   [`contribution/branches`], [2026-04-02], [`bt_2` (diff), `der_3` (branch #emph[name] `project_x`), `der_4` (branch #emph[name] `master`), `c_seq` (ctr)],
  ),
) <tbl:archive>

Each branch-table revision is one contribution — one merge — and each carries its
own content: `bt₀` initialises the archive (the Sequencer's initial node and the
empty table); `bt₁` adds `project_x`, contributing `src₁` and `der₁` (and pulling
in `c_alice` by reference); `bt₂` adds `master`, contributing `ent₁`, `ent₂`,
`rel₁`, and `der₂`; `bt₃` extends *both* branches, contributing `der₃` and `der₄`.
Each revision restates only its delta — `bt₂` repoints just `master`, carrying
`project_x` forward unchanged, while `bt₃` repoints both — so materialising the
chain back to `bt₀` yields the current table $\{$`project_x` → `der₃`,
`master` → `der₄`$\}$ (`V-MATERIALISE`).

The archive has two contributors. `c_seq` is the *Sequencer's* contributor claim
and the archive's *initial node* — its `pubkey` in its own content (`V-SIG`); the
Sequencer holds the matching private key and signs every branch-table claim, and
only the Sequencer may (Paper 02 §Sequencer). `c_alice` is the content author: its
`contribution/contributor` edge resolves to the initial node `c_seq`, its `pubkey`
and key window live in its own content, and it signs the eight content claims. A
reserved *system branch* and a limiting claim (to exercise `R-LIMIT-PROP`) would
enter as a further revision; they are deferred to keep the fixture focused.

= Verification <sec:verification>

*Verification* decides whether a set of claims is a well-formed Ranke-Graph and,
in RankeDB, whether a contribution may merge. It is a single recomputation over
a closure: the ADT rules (@sec:v-adt) establish that the graph *is* a
Ranke-Graph; the RankeDB rules (@sec:v-rankedb) add the policy a contribution
must satisfy to enter the archive. The same pass runs in two settings — as a
*gate* on every contribution, and as a *full audit* re-run at any time over a
head id and a Universe alone (Paper 02 §Verification and Witnessing).

== The verification pass <sec:v-pass>

Given a head id $k$ and a Universe $cal(U)$, verification walks the closure
$"closure"(k, cal(U))$ — each claim reached by following its edges to their
references — and checks every rule below against every claim on the walk. Because
identity is recursive over the closure (Paper 01 §Merkle DAG), recomputing one
claim's id transitively witnesses every claim beneath it; a single pass therefore
establishes integrity and authenticity together (Paper 01 §Verifiability). The
walk terminates at initial nodes (@sec:v-adt, *V-ROOT*), and is finite and
acyclic by construction. A claim that fails any *MUST* rule fails verification;
in the contribution setting (@sec:v-rankedb) that rejects the whole contribution
(Paper 02 §Sequencer).

== ADT rules — the portable floor <sec:v-adt>

These hold for any Ranke-Graph, in any implementation. They are the definition
of *valid* (Paper 01 §Validity, §Verifiability).

#rule("V-ID", FORCED)[Every claim's stored id MUST recompute:
$op("id")(v) = "Sign"(H(S(v)))$ for a node, $op("id")(e) = H(S(e))$ for an edge.
$S$ MUST be the canonical serialization (deterministic, complete,
self-delimiting) and $H$ the declared, self-describing hash. Because $S(v)$
covers the node's whole `edges` field, recomputing a node's id also fixes every
edge it owns. (Paper 01 §Primitives, §Verifiability)]

#rule("V-SIG", FORCED)[The signature carried in $op("id")(v)$ MUST verify against
the contributor public key: the `pubkey` reached through $v$'s
`contribution/contributor` edge, or — when $v$ is an initial node — the `pubkey`
in $v$'s own content. Under the *identity* Sign choice (empty pubkey) this check
trivially succeeds. (Paper 01 §Identity and Authenticity)]

#rule("V-CONTENT", FORCED)[If a claim declares content, it MUST carry both
`content_size` (its exact byte length) and `encoding` (its media type). Inline
content lives in `content`; external content is referenced by `content_hash`,
and the referenced bytes in $cal(U)$ MUST hash to it: $H(c) = $ `content_hash`.
A claim MUST NOT carry both `content` and `content_hash`. (Paper 01 §Content,
§Verifiability)]

#rule("V-REF", FORCED)[Every edge's `reference` MUST resolve to a claim present
in the closure, and MUST reference a *claim* — never an edge. An unresolved
reference makes the graph merely an arbitrary graph, not a Ranke-Graph. (Paper 01
§Edges, §Relations, §Validity)]

#rule("V-ROOT", FORCED)[Every claim MUST either be an *initial node* (no
references) or carry a `contribution/contributor` edge whose closure resolves to
one or more initial nodes. A graph missing an initial node is invalid. Multiple
initial nodes are admitted (a federated merge of independent lines). (Paper 01
§Ranke-Graph, §Validity, §Provenance)]

#rule("V-MONO", FORCED)[A claim MUST NOT predate what it references:
`created_at`$(v) gt.eq max$ `created_at`$(u)$ over every reference $u$ of $v$.
With *V-ID* this makes edges run from earlier claims to later ones, so the
closure is acyclic. (Paper 01 §Claims, §Merkle DAG)]

#rule("V-ATOMIC", FORCED)[A claim is created in one atomic transaction and is
sealed at creation: its node's id covers every edge created with it, and nothing
may be added to the claim afterward. Each node and each edge belongs to exactly
one claim. (Paper 01 §Claims)]

#rule("V-MATERIALISE", FORCED)[A claim carrying a `contribution/diff` edge
restates only its delta; its full content is the materialisation of the diff
chain applied over the referenced predecessor, recursively to a base claim.
Verification applies to the materialised claim. (Paper 01 §Claims, §Branches)]

== RankeDB rules — added policy <sec:v-rankedb>

RankeDB enforces every *V-* rule above and adds the following. Each is a choice
the ADT leaves open; together they are what a contribution must satisfy to merge
(Paper 02 §Sequencer, §Timestamping, §Keyrotation, §Cross Branch Propagation).

#rule("R-BASE", FREE)[Every claim added in a contribution MUST be dated
`created_at`$lt.eq t$, where $t$ is the contribution's base time — the server
time stamped when the contribution was opened against head $k$, the pair $(k,t)$
(Paper 02 §Sequencer, step 2).]

#rule("R-CEIL", FREE)[A claim merged by the server MUST NOT be dated later than
the server's own clock at merge. This ceiling, with *V-MONO*, prevents
future-dating; judging whether a date is otherwise *plausible* is out of scope
and left to client applications. (Paper 02 §Timestamping)]

#rule("R-KEYWIN", FREE)[A claim MUST verify against a contributor key that is
valid at the claim's `created_at`. A key's validity is the closed window from
`pubkey_valid_from` through `pubkey_expires_after` (both RFC 3339, both optional)
on the contributor claim; a claim dated strictly after `pubkey_expires_after`
fails verification. Rotation adds a further contributor claim with a later
window; windows MAY overlap. (Paper 02 §Contributor Keys Life Cycle)]

#rule("R-RESERVED", FREE)[A contribution from a system account MUST NOT contain
*limiting claims* (`contribution/delete`, `contribution/expiry`) or *branch-table*
claims (`contribution/branches`): these types are minted by the Sequencer alone.
A system account MAY only commit a *request* for one (e.g. an
`expires_after_request` edge), which the Sequencer honours, subject to access
policy, when it advances the head. (Paper 02 §Sequencer, §Contributor Keys Life
Cycle)]

#rule("R-CLOSED", FREE)[Before verification a contribution MUST be *closed*: each
claim's references are followed, drawing in every referenced claim outside the
contribution — from another branch or the wider Universe — together with the
limiting claims against it, recursively, until every path reaches a claim already
in the base's closure. Drawing in a branch-external claim requires read access to
its branch (*R-ACCESS*). (Paper 02 §Sequencer, step 3)]

#rule("R-LIMIT-PROP", FREE)[A limitation MUST NOT be lost across branches: when a
contribution adds a claim that is the target of a limiting claim, the Sequencer
MUST add that limiting claim to the same branch in the same contribution. A limit
thus stays attached to its target wherever the target is referenced. (Paper 02
§Cross Branch Propagation)]

#rule("R-PERSIST", FREE)[The sealed contribution's whole closure MUST be durably
present in the Universe — stored and propagated across the storage layers —
*before* the head advances $k arrow.r k'$. A head therefore never commits to a
claim that failed to persist. (Paper 02 §Sequencer, step 5)]

#rule("R-SEAL", FREE)[Once verified, a contribution is *sealed*: its contents are
fixed and admit no further addition or removal. By immutability, whatever
verified against the base stays valid however long it waits before merging.
(Paper 02 §Sequencer, step 4)]

#rule("R-ACCESS", FREE)[A contribution to a branch requires *C* (contribute)
access to it; reads require *R*; overlaying an existing claim requires *U*;
purging bytes requires *D* on every branch holding the claim. Access by head id
alone, bypassing the branch table, is *privileged* and granted only over the
reserved `$universe` target, to which only *R* applies. (Paper 02 §Access
Control)]

= RankeQL (RQL) <sec:rql>

A read is a *RankeQL* query — a declarative value of the data type `Query` fixed
below, independent of any programming language and of the wire encoding that
carries it (JSON is the standard representation; see `output.encoding`). RQL is
entirely a RankeDB construct — the ADT defines no query language — so this whole
chapter is `[FREE]`. Its blocks and their roles are Paper 02 §Filtered Reads;
this chapter fixes the type.

A query is evaluated in a fixed logical order: (1) `select` generates the result
set, (2) `where` filters it, (3) `order` sorts it, (4) `limit` truncates it,
(5) `output` shapes and encodes each surviving claim. An optimised engine may
reorder or lower these steps as long as the delivered result set is identical;
the native reference engine is the oracle (§Filtered Reads, §Conformance).

== The query type <sec:rql-type>

Field names ending in `?` are optional; `|` lists the allowed values or forms;
`[T]` is a list of `T`. `Id`, `Claim`, `bytes`, and `duration` are the ambient
domains of @sec:fixture.

#[
#show raw: set text(size: 0.82em)
```
Query = {
  select:     Select
  where?:     Where          // absent -> no filter
  output:     Output
  order?:     Order          // absent -> order by (created_at, id)
  limit:      Limit
  execution:  Execution
}

Select = {                   // a generator: scope, root, traversal
  branch:  string            // "$universe" | "$archive" | a branch name
  claim?:  Id                // root in the scope; required iff branch = "$universe"
  path?:   [PathStep]        // absent/empty -> the full outward closure of the root
}

PathStep = {                 // follow typed edges to a bounded depth
  edges?:  [string]          // edge-class globs "class/sub"; leading "-" excludes
  dir?:    "provenance" | "uses" | "connections"    // default "provenance"
  depth?:  int               // max hops; 0 -> unbounded for this step
  nodes?:  [string]          // endpoint node-class globs; leading "-" excludes
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
  detail?:       "id" | "claim" | "path"            // default "claim"
  materialized?: bool        // resolved claim | stored original
  content?:      int         // max inlined content bytes per claim; 0 -> none
  overflow?:     "cutoff" | "omit" | "reference"    // content past `content`
  encoding?:     "json" | "cbor"                    // default "json"
}

Order = { field: string, desc?: bool }              // absent -> (created_at, id)

Limit = { results?: int, time?: duration }          // each 0 -> unbounded

Execution = {
  layer?:  string            // pin one storage layer; empty -> backend chooses
  report?: "info" | "debug" | "trace"               // absent -> no report
}
```
]

== `select` — scope, root, traversal <sec:rql-select>

- `branch` is the mandatory *scope*. A real branch name confines the query to that
  branch's closure, rooted at its current head. Two reserved names widen it:
  `$archive` confines to the whole Ranke-Archive — the closure of the branch-table
  header — and `$universe` applies no confinement. An empty `branch` is not
  allowed. (`$archive` extends the reserved `$`-targets of §Access, which names
  `$universe` and `$branches`.)
- `claim` is the *root* in the scope. It is required under `$universe` — there is
  no head to default to — and optional otherwise, defaulting to the scope's
  current head (the branch head, or the branch-table header under `$archive`).
  `$universe` is privileged and requires the `$universe` grant (`R-ACCESS`).
- `path` is the *traversal*: an ordered list of steps. Each `PathStep` follows a
  set of typed `edges` (globs over `class/sub`, a leading `-` excluding a type) in
  direction `dir` — `provenance` (outgoing, toward references; the default), `uses`
  (incoming), or `connections` (either) — to at most `depth` hops (`0` meaning
  unbounded for that step), optionally constraining the endpoint to `nodes` types.
  An absent or empty `path` returns the full outward closure of the root
  (foundation paper §Closures).

== `where` — the filter <sec:rql-where>

`where` is a boolean tree. Each node is exactly one of the `and` / `or` / `not`
combinators over sub-trees, or a *leaf* naming a `field` and a `test`. A
`Comparison` applies exactly one operator to the field: `eq`, `ne`, `lt`, `le`,
`gt`, `ge`, `in` (set membership), or `glob` (shell-style wildcard). Within a
`where`, `or` is boolean; across generators it unions whole result sets.

== `output` — result shape and encoding <sec:rql-output>

- `detail` — `id` (the id alone), `claim` (the reached claim; the default), or
  `path` (the whole route to it, root first).
- `materialized` — deliver a claim overlaid by a `contribution/diff` chain either
  *resolved* (the materialised claim, `V-MATERIALISE`) or as its *stored* original
  (the diff claim as written). §Filtered Reads step 5 materialises, so absent
  means resolved. (The field is a RankeDB addition; the paper's `output` block
  does not list it.)
- `content` — the maximum content bytes inlined per claim; `0` (the default)
  inlines none, carrying only `content_hash` (foundation paper §Content).
- `overflow` — how content exceeding `content` is handled: `cutoff` (truncate),
  `omit` (drop it), or `reference` (a `content_hash` stub in its place).
- `encoding` — the serialised form of each claim: `json` (the default; content
  base64-encoded) or `cbor` (binary; the original id-defining bytes). It is
  orthogonal to `materialized` — either form may be `json` or `cbor`.

== `order`, `limit`, `execution` <sec:rql-bounds>

`order` sorts the result set by `field`, ascending unless `desc`; absent, results
order by `(created_at, id)`, claims lacking the field last. `limit` bounds the
read — `results` caps the claim count, `time` the execution budget — each `0`
meaning unbounded. To page, carry the last row's order key into a `where` on the
next request.

`execution` controls where the query runs and how it reports. `layer` pins one
named storage/execution layer instead of letting the backend choose by
capability. `report` sets a verbosity — `info` (high-level stages), `debug`
(routing and lowering), or `trace` (per-claim detail); absent, none is produced.

== Results and streaming <sec:rql-results>

A query yields an ordered stream of results, each shaped by `output` and delivered
one at a time in the query's order:

#[
#show raw: set text(size: 0.82em)
```
QueryResult = {              // one reached claim, shaped by Output
  id:       Id               // always present
  claim?:   Claim            // absent when detail = "id"
  path?:    [Claim]          // present only when detail = "path" (root first)
  content?: bytes            // present only when output.content > 0; truncated per overflow
}
```
]

After the last result — and only if `execution.report` was set — the stream
carries a final *report* record: the layer that served the query, the query it was
lowered to (the Cypher/GQL text, or `native`), and per-stage timings. It is typed
distinctly from result claims so a reader never mistakes it for data.

= Remaining chapters <sec:remaining>

The normative surface beyond verification is to be written here, each chapter in
the same form — sentences, ids, FORCED/FREE tiers, grounded in the papers:

- *Serialization and identity* — the canonical $S$, the hash $H$, the signature
  scheme, and the alias table, at the precision the reference implementation
  fixes them (Paper 01 §Primitives).
- *Taxonomy and well-formedness* — the fixed node and edge classes, and the
  structural constraints each imposes (e.g. a `relation/*` node's edges land on
  `entity/*` claims and carry `relation_direction`) (Paper 01 §Type Vocabulary,
  §Relations).
- *Wire encoding and endpoints* — request and response formats and the
  authentication surface (Paper 02 §Endpoints and Authentication).

Until a chapter is written, the cited paper section governs.
