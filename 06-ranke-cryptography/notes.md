# Paper 06 — Cryptography, Governance, and Audit on the Ranke-Graph

*Working notes. Captures the material developed during conversation on
2026-05-04 / 2026-05-07. Out-of-scope for paper 01 (the ADT) because all of
it is application-level — but the application patterns it enables are
significant enough to deserve their own treatment.*

---

## Premise

The Ranke-Graph ADT is enough machinery to express a complete trust posture
without any structural addition. This paper describes the patterns:

- **Cryptographic attestation** — signatures as claims, web of trust by
  structure, key rotation as chain of attestations.
- **In-graph governance** — policies as claims; the graph contains the
  rules for what may be added to it.
- **Full historical auditability** — anyone can replay; violations become
  claims; self-healing through accumulation, never editing.
- **Operator-independent trust** — the operator collapses to commodity
  storage + commodity gatekeeper; trust is structural, not procedural.

All of it is application-level on top of the ADT defined in paper 01.

---

## The unifying recursion

The §2 *everything is knowledge* principle from paper 01 applies up the
stack:

| Layer | What is a claim |
|---|---|
| Data | the original claim itself |
| Attribution | signatures are claims |
| Governance | policies are claims |
| Audit | validity attestations are claims |

Each layer uses the same primitive — a claim with provenance, content,
signature, anchored in snapshots — applied one level up. Nothing in this
paper is a new structural mechanism; everything composes from the ADT.

---

## 1. Signatures as claims

**Mechanism.** Add `pubkey` to the content of contributor identity nodes.
Introduce a normal claim type — e.g. `contribution/signature` — with a
`contribution/*` edge to the signing contributor and an `evidence/*` edge
to the hash being signed; its content carries the signature bytes.

The signature is *on a separate claim*, not a field of the signed claim.
Same reason `parent` is omitted from edge records (paper 01 §4.2):
otherwise `H(S(v))` would depend on `sign(H(S(v)))`, no fixed point.

**Cross-attestation = web of trust by structure.** Bob signing Alice's
claim is a `contribution/signature` claim from Bob targeting Alice's hash.
Multiple signatures on one hash → cumulative attestation; queryable as
"find all `contribution/signature` claims with `evidence/*` to *h*."
Multi-sig (CRA's vendor + distributor pattern), peer review, *n*-of-*m*
signing — all the same machinery. Web-of-trust paths emerge as subgraphs of
the substrate, traversable like any other.

**Key rotation = chain of attestations.** A new `pubkey` claim signed by
the previous pubkey forms a continuity proof. An attacker holding an old
retired key cannot rotate to a new one; only the current legitimate holder
can. Specific rotation rules (latest-valid, *n*-of-*m* approval) are
application-level over the structural primitive.

---

## 2. Policies as claims

**A policy claim** — e.g. type `contributor/policy` — describes admission
rules: what kinds of claims may be added; which signatures are required;
which contributors are authorized. It is a normal claim with provenance:
signed by an authoring contributor, traceable, anchored in snapshots,
immutable once written.

**Unified governance rule.** A graph's governance is determined by the
policy claims reachable from its head. This single rule covers every case
with no exceptions:

- *Fresh graph* (founded by a contributor's genesis claim): empty history,
  no policy claims yet, admission predicate trivial.
- *Forked from h*: inherits the policies reachable from *h*.
- *Merged into h_T*: the target's policies govern admission of the result.

There is no "sandbox mode" or special graph type. All graphs are RG_h;
what differs is what's reachable from *h*.

**Bootstrap.** The graph's first claim is a contributor identity node — the
founding contributor — with their pubkey in content (or as a follow-on
claim signed by the genesis). They author the first policy claim, which
describes the rules going forward, including who else can author policy.
From there the system enforces itself.

**Self-amending constitution.** Policy claims are themselves subject to the
policy that authorizes them. A new policy is admitted only if the *current*
policy permits it (typically: signed by a contributor in role "admin").
Constitutional coherence is structural, not procedural.

---

## 3. Validity is a function of a graph

**Validity is not a property a graph "has" — it is a function applied to
a (graph, policy) pair.**

```
valid(G, policy) := policy applied to G returns true
```

Three implications:

1. **Invalid graphs are structurally well-formed.** They have content,
   hashes, edges, provenance — they just don't satisfy some policy.
   "Invalid" is *contextual to the policy in effect*, not a corruption
   state.

2. **Merge and validation are separate operations.** The merge itself is
   `result = target ∪ incoming` (with closure) — pure structural composition,
   always succeeds, always produces a hash. Validation is a *separate*
   function that can be applied to any graph at any time.

3. **The application layer decides what to do with the validity answer.**
   "Only valid graphs get publicly anchored," "only valid graphs feed
   downstream pipelines," "invalid graphs get retried with backoff" — all
   application policies. The structural primitive is just *validity is
   queryable*.

The same validity function runs at:

- *Construction* — client checks their work-in-progress.
- *Merge* — server checks proposed result.
- *Audit* — auditor replays history.
- *Anchor* — application decides whether to publish externally.
- *Read* — consumer filters which subgraphs to trust.

Same function, different moments, application chooses what to do with the
answer.

---

## 4. Merge as composition; validation as separate

```
1. compute:      result = target ∪ incoming   (always succeeds, produces a hash)
2. evaluate:     valid(result, target.policy) (deterministic, anyone can run)
3. application:  branches[main] := H(result) iff valid    (application choice)
                 OR retry / debug / queue / escalate
                 OR ignore
```

The result hash is reportable in either case. Two parties independently
proposing the same merge get the same hash. A failed merge gives the
rejecting party a hash to quote; the proposing party can debug, retry,
escalate, or appeal against that named proposal.

**Pubkeys live in the target's history, not in the incoming graph.** A
signature on incoming claim *c* verifies against a pubkey claim that is
already authorized in the target (or whose authorization chain is being
added in this same merge AND satisfies the target's "who can authorize
pubkeys" rule). An unauthorized contributor smuggling in their own pubkey
claim doesn't help them — the target's policy only recognizes pubkeys that
trace back to authorized authority.

**Worked workflow.**

1. Client creates a fresh RG_h0 — no policy applies (empty history).
   Note: when the client's claims reference nodes in the target by hash,
   policy claims reachable from those targets are part of the closure;
   the work-in-progress graph may be invalid against them during construction.
   That is fine — invalid graphs may exist.
2. Client adds claims; each is signed using a privkey whose pubkey is
   registered in the target's history.
3. Client checks `valid(work_in_progress, target.policy)` locally.
4. When valid, client proposes a boolean merge with the target.
5. Target evaluates `valid(target ∪ incoming, target.policy)`.
6. If valid: target's branch pointer advances to the new hash.
   If invalid: rejection; the proposed-but-rejected hash is named as the
   artefact.

The server holds no private keys, no out-of-band policy config, and no
admission logic external to the graph. Two servers running against the
same substrate enforce the same rules without any synchronisation, because
the rules are *in* the substrate.

---

## 5. Full historical auditability

The same `valid(G, policy)` function the server runs at merge time, anyone
can run later — a v2 server, an auditor, a regulator with access to a
snapshot. Walk the substrate chronologically, find the policy that was
reachable from each transition's head, replay the validation. Disagreements
identify violations.

**Self-healing through more claims, never editing.**

A discovered violation does not trigger retroactive editing (immutability
forbids it). Self-healing happens through additional claims:

- An *observation* claim flags the violation, signed by the auditor.
- A *prune* claim marks the offending claim unresolvable in views derived
  from the audit.
- A *new policy* claim patches the gap going forward.

The original violating claim stays in the substrate — provenance of the
bug itself is preserved. Consumers who trust the auditor's prune get the
corrected view; those who don't can ignore it.

**Validity attestations as claims.** An auditor walks *G*, computes
validity, and writes a `validity/attestation` claim asserting "I evaluated
*H(G)* against policy *P_hash* at time *t* and result was true/false."
This claim is signed, anchored, and itself queryable. Multiple auditors
agreeing on validity strengthens trust without coordination.

---

## 6. The complete operator-independence picture

Five distinct trust properties, each lifted out of the operator's hands
and into the structure:

| Property | Mechanism |
|---|---|
| Integrity | hashes + Merkle DAG (paper 01 §5.2) |
| Temporal | snapshots + external anchoring (paper 01 §5.3) |
| Authenticity | signed-by claims via contributor pubkeys |
| Governance | policies as claims; admission predicate over the graph |
| Enforcement verifiability | replay against the same graph; violations become claims |

The operator collapses to *commodity storage + commodity gatekeeper*:
replaceable, auditable, structurally constrained. The operator can be
wrong, malicious, absent, or legally compelled — none of these break the
trust posture. A graph can be cloned to new infrastructure, ownership can
transfer, the original company can dissolve — every signed, anchored,
hash-verified, policy-validated claim remains independently verifiable
forever.

---

## 7. Compliance angle

Most regulatory regimes require demonstrable, tamper-evident logs of
*both* (a) data changes and (b) policy/authorization changes. Most
production systems produce these as best-effort logs from the same
operator who could edit them. The Ranke-Graph produces them by
construction:

- **CRA** (Cyber Resilience Act): cryptographic attribution of vendor +
  distributor on every artefact.
- **eIDAS**: qualified electronic signatures, long-term validation.
- **SOC 2**: tamper-evident audit trail of access and policy changes.
- **ISO 27001**: information security management with provable controls.
- **GDPR Art. 30**: records of processing activities, immutable.
- **HIPAA audit trail**: who accessed what, when, under which authorization.

Each falls out of the same primitives.

---

## 8. Application-level vs ADT-level (qualities, not commitments)

This paper makes specific recommendations; none are part of the ADT.

- *Signing schemes*: Ed25519, BLS, post-quantum candidates — implementation
  choice.
- *Policy DSLs*: predicate languages with their own canonicalisation —
  implementation choice.
- *Attestation policies*: single-sig vs *n*-of-*m* vs role-thresholded —
  application convention.
- *Rotation rules*: latest-valid, *n*-of-*m* approval, time-bounded —
  application convention.
- *Validity-attestation cadence*: continuous, on-demand, periodic —
  application choice.

The ADT enables the patterns by making everything a claim; specific
conventions live in implementations. Qualities-not-commitments throughout.

---

## Open questions

- *Revocation semantics.* When a key is compromised retroactively, what
  about claims signed before the compromise? Application-level decisions
  about trust horizons.
- *Policy conflict resolution.* Two policy claims reachable from the same
  head that contradict each other — does the latest win, or the most
  restrictive, or do we require explicit supersession?
- *Cross-graph attestation.* If Alice's identity exists in graph A and
  Bob's exists in graph B, how do they sign each other's claims? Probably
  by referencing across `cal(U)` boundaries via hash, but the practical
  ergonomics need work.
- *Snapshot frequency vs anchoring frequency.* Anchoring is expensive
  (publishing to external medium); snapshots are cheap. What's the right
  cadence for each? Application-level but worth a recommendation.
- *Validity caching.* Re-evaluating policy on every read is wasteful if
  the graph hasn't changed. Cache strategies that compose with the
  immutability guarantees.

---

## Status

Notes only — not yet drafted. Framework material is solid; needs
fleshing out with concrete examples, proof sketches for the validity-as-
function decomposition, and a careful walk-through of one realistic
deployment.
