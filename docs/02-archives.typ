#import "vocabulary.typ": *

= Archives and branches <ch:archives>

A #gls("ranke-archive") is a Ranke-Graph whose head claim is a
#gls("branch-table"): a claim naming every #gls("branch") the archive holds,
each of its edges pointing at that branch's current head. The archive is the
pair of the #gls("universe") and that head id, and adding to it produces a new
pair rather than changing the old one.

An id that named an archive last year still names it today. That is what lets a
reference to an archive appear in a report, a signature, or a court filing and
stay meaningful: the reader resolves the id and gets the archive as it stood,
whatever has been written since. #dref[foundation paper §Ranke-Archive]

== Branching <sec:branching>

#corollary[
Forking costs one entry. A branch is one edge in the branch table, naming the
branch and pointing at the head it starts from, so a fork is $O(1)$ however much
history it inherits.
]

Two branches that share history share storage as well. Their #glspl("closure")
overlap wherever they cite the same claims, and identical claims carry identical
ids, so the shared part is stored once. Copying a branch costs nothing until the
copy diverges, and then it costs only what diverged.

A revision of the branch table need not restate every entry. Carrying a
`contribution/diff` edge, it records the changed entries alone, and a reader
materialises the full table by overlaying the diff chain back to the empty table
the archive started from.

== Recovering an archive <sec:recovery>

Recovery takes one id and a universe holding the bytes. Walk the closure of the
head, check each claim against the rules of @sec:integrity below, and the result
is either the archive as it was written or a named claim that failed.

Nothing else is needed: no catalogue, no manifest, no schema registry. A
universe spread across more than one store serves recovery as well as a single
store does, because a claim is found by its hash and a hash says nothing about
where the bytes sit.

== Integrity <sec:integrity>

Three checks decide a claim, and running all three over a closure decides the
archive. Recompute the hash over the stored bytes and compare it with the id
that names them. Verify the envelope's signature against the contributor's
public key. Where the claim declares external content, hash those bytes and
compare with `content_hash`.

#todo[Retention for a branch that no longer heads anything is unsettled. The
rules wait on the RankeDB paper's treatment of deletion, and this section will
cite them rather than invent a second answer.]
