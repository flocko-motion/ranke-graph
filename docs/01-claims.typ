#import "vocabulary.typ": *

= Claims <ch:claims>

The Ranke-Graph holds one kind of record. A captured file, a summary of that
file, a person, an assertion about that person, and the note saying who did the
capturing all enter as a #gls("claim"), and the graph treats them alike. An
application that wants a distinction between data and metadata draws it in the
`type` field, never in the storage.

#concept("Claim")[
A #gls("node") together with its content and its edges, added by one
#gls("contributor") in a single atomic transaction. Its identity is the hash of
the bytes it is stored as, so a claim is fixed at the moment it exists: nothing
is appended to it afterwards, and nothing in it is edited.
]

A claim carries its own provenance. The edges it was created with cite the
earlier claims it draws on, and the contributor that added it; the hash covers
those edges along with everything else. Provenance therefore cannot be detached
from the record it describes, which is the property the whole structure is built
to keep. #dref[foundation paper §Claims]

== Identity <sec:identity>

#definition[
The identity of a claim $v$ is $op("id")(v) = H(S("env"(v)))$: the hash of the
serialized #gls("envelope"), which pairs the #gls("serialized-claim") with the
signature over it.
]

Every edge is serialized inside the node that owns it, so the hash covers each
#gls("reference") the claim makes. Each of those references is itself a hash
over its own #gls("closure"), and the recursion reaches back to an
#gls("initial-claim") along every path.

#theorem[
An id fixes a graph. Given a #gls("universe") holding the bytes, the closure of
a claim is recovered from its id alone, and no other set of claims is recovered
under that id.
]

#proof[
Reading $cal(U)(k)$ yields the envelope, whose payload names the ids it
references; reading each of those repeats the step. The walk terminates because
a reference always carries a strictly lower #gls("height"), so recovery is
determined by $k$. For uniqueness, suppose a second set were recovered under
$k$. Its head would serialize to different bytes with the same hash, which
collision-resistance of $H$ excludes.
]

Two consequences follow for anyone writing against the graph. A claim needs no
version field, because a revision is a new claim with a new id. A cache needs no
invalidation, because an id names one byte sequence for as long as the hash
holds.

== The shape of a stored claim <sec:shape>

#diagram(
  "/docs/assets/claim.svg",
  [A derived claim, the source it cites, and the contributor edge every claim
   carries. Arrows run from the claim that owns the edge to the claim it
   references, which is the direction the hash follows.],
  width: 92%,
) <fig:claim>

@fig:claim shows a `derivation/summary` claim over a captured email. Reading it
back gives the summary; following its two edges gives the email it condenses and
the contributor that wrote it. Neither traversal consults an index: the ids are
in the bytes.

The `height` field bounds that traversal in advance. A claim's height is one
more than the largest height among its references, so an initial claim carries
zero and a set of claims bounded by height is closed under references. A reader
that wants a subgraph and nothing else can therefore ask for a height range and
know what it will get. #dref[foundation paper §Nodes]

== Where the rules live <sec:rules>

This chapter describes the shape. What an implementation must enforce is stated
rule by rule in the normative specification: `V-ID` for the identity above,
`V-REF` for what an edge may point at, `V-MONO` for the ordering of
`created_at`, and `V-SIG` for the signature the envelope carries. Cite those ids
rather than restating them here, so a rule has one wording.
